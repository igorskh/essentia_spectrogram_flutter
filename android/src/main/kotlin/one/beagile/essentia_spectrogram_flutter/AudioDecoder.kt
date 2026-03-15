package one.beagile.essentia_spectrogram_flutter

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import java.nio.ByteBuffer
import java.nio.ByteOrder

object AudioDecoder {
    fun decodeAudioFile(context: Context, filePath: String): FloatArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(filePath)

        var audioTrackIndex = -1
        var mediaFormat: MediaFormat? = null

        for (i in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(i)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
            if (mime.startsWith("audio/")) {
                audioTrackIndex = i
                mediaFormat = format
                break
            }
        }

        check(audioTrackIndex >= 0) { "No audio track found in: $filePath" }
        requireNotNull(mediaFormat)

        extractor.selectTrack(audioTrackIndex)

        val mime = mediaFormat.getString(MediaFormat.KEY_MIME)!!
        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(mediaFormat, null, null, 0)
        codec.start()

        // Use a list of primitive arrays to avoid boxing java.lang.Short
        val floatChunks = mutableListOf<FloatArray>()
        var totalSamples = 0
        
        val bufferInfo = MediaCodec.BufferInfo()
        var inputEOS = false
        var outputEOS = false

        while (!outputEOS) {
            // --- Feed compressed data ---
            if (!inputEOS) {
                val inputIndex = codec.dequeueInputBuffer(10_000L)
                if (inputIndex >= 0) {
                    val inputBuffer = codec.getInputBuffer(inputIndex)!!
                    val sampleSize = extractor.readSampleData(inputBuffer, 0)

                    if (sampleSize < 0) {
                        codec.queueInputBuffer(
                            inputIndex, 0, 0, 0L,
                            MediaCodec.BUFFER_FLAG_END_OF_STREAM
                        )
                        inputEOS = true
                    } else {
                        codec.queueInputBuffer(
                            inputIndex, 0, sampleSize,
                            extractor.sampleTime, 0
                        )
                        extractor.advance()
                    }
                }
            }

            // --- Drain decoded PCM ---
            var outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
            while (outputIndex >= 0) {
                if (bufferInfo.size > 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)!!
                    outputBuffer.order(ByteOrder.LITTLE_ENDIAN)
                    
                    val shortBuffer = outputBuffer.asShortBuffer()
                    val sampleCount = bufferInfo.size / 2
                    val floatChunk = FloatArray(sampleCount)
                    
                    // Direct conversion to normalized float avoids storing shorts twice
                    for (i in 0 until sampleCount) {
                        floatChunk[i] = shortBuffer.get() / 32768.0f
                    }
                    
                    floatChunks.add(floatChunk)
                    totalSamples += sampleCount
                }

                // Check for end of stream flag on the output buffer
                if ((bufferInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                    outputEOS = true
                }

                codec.releaseOutputBuffer(outputIndex, false)
                
                // Only loop draining if we aren't done
                if (!outputEOS) {
                    outputIndex = codec.dequeueOutputBuffer(bufferInfo, 0L)
                } else {
                    break
                }
            }
        }

        codec.stop()
        codec.release()
        extractor.release()

        // Flatten the chunks into a single FloatArray efficiently
        val fullData = FloatArray(totalSamples)
        var offset = 0
        for (chunk in floatChunks) {
            chunk.copyInto(fullData, offset)
            offset += chunk.size
        }

        return fullData
    }
}