package one.beagile.essentia_spectrogram_flutter

import android.content.Context
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import java.nio.ByteBuffer
import java.nio.ByteOrder

object AudioDecoder {
    /**
     * Decodes any audio file (MP3, AAC, WAV, OGG, FLAC, etc.) into
     * a FloatArray of normalized PCM samples in the range [-1.0, 1.0].
     *
     * @param context   Android context
     * @param filePath  Absolute path to the audio file
     * @return FloatArray of waveform amplitude values
     */
    fun decodeAudioFile(
        context: Context,
        filePath: String
    ): FloatArray {
        val extractor = MediaExtractor()
        extractor.setDataSource(filePath)

        // Find the first audio track
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

        val pcmSamples = mutableListOf<Short>()
        val bufferInfo = MediaCodec.BufferInfo()
        var isEOS = false

        while (!isEOS) {
            // --- Feed compressed data into the decoder ---
            val inputIndex = codec.dequeueInputBuffer(10_000L)
            if (inputIndex >= 0) {
                val inputBuffer: ByteBuffer = codec.getInputBuffer(inputIndex)!!
                val sampleSize = extractor.readSampleData(inputBuffer, 0)

                if (sampleSize < 0) {
                    // End of stream
                    codec.queueInputBuffer(
                        inputIndex, 0, 0, 0L,
                        MediaCodec.BUFFER_FLAG_END_OF_STREAM
                    )
                    isEOS = true
                } else {
                    codec.queueInputBuffer(
                        inputIndex, 0, sampleSize,
                        extractor.sampleTime, 0
                    )
                    extractor.advance()
                }
            }

            // --- Drain decoded PCM output ---
            var outputIndex = codec.dequeueOutputBuffer(bufferInfo, 10_000L)
            while (outputIndex >= 0) {
                val outputBuffer: ByteBuffer = codec.getOutputBuffer(outputIndex)!!
                outputBuffer.order(ByteOrder.LITTLE_ENDIAN)

                // Android MediaCodec always outputs 16-bit PCM by default
                while (outputBuffer.remaining() >= 2) {
                    pcmSamples.add(outputBuffer.short)
                }

                codec.releaseOutputBuffer(outputIndex, false)
                outputIndex = codec.dequeueOutputBuffer(bufferInfo, 0L)
            }
        }

        // Cleanup
        codec.stop()
        codec.release()
        extractor.release()

        // Convert 16-bit PCM shorts -> normalized floats [-1.0, 1.0]
        val fullData = FloatArray(pcmSamples.size) { i ->
            pcmSamples[i] / 32768.0f
        }

        return fullData
    }
}