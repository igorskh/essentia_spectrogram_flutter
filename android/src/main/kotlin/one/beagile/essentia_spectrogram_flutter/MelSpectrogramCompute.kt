package one.beagile.essentia_spectrogram_flutter

object MelSpectrogramCompute {
    /**
     * Computes mel spectrogram in chunks to optimize memory consumption.
     * 
     * @param audioSamples The complete audio samples array
     * @param sampleRate Sample rate of the audio
     * @param frameSize Size of each frame for analysis
     * @param hopSize Hop size between frames
     * @param numBands Number of mel bands to compute
     * @param maxChunkSize Maximum size of each chunk in samples
     * @return List of lists representing the mel spectrogram
     */
    fun processChunked(
        audioSamples: FloatArray,
        sampleRate: Int,
        frameSize: Int,
        hopSize: Int,
        numBands: Int,
        minFreq: Int,
        maxFreq: Int,
        maxChunkSize: Int
    ): List<List<Float>> {
        if (audioSamples.size <= maxChunkSize) {
            // If audio is small enough, process normally
            val melSpec = NativeBridge.computeMelSpectrogram(
                audioSamples,
                sampleRate,
                frameSize,
                hopSize,
                numBands,
                minFreq.toFloat(),
                maxFreq.toFloat()
            )
            return melSpec.map { it.toList() }
        }

        // Calculate overlap needed to avoid discontinuities
        // We need at least (frameSize - hopSize) samples overlap
        val minOverlap = maxOf(frameSize - hopSize, hopSize)
        val overlap = minOverlap + (hopSize - (minOverlap % hopSize)) // Align to hop size

        val allResults = mutableListOf<List<Float>>()
        var currentIndex = 0

        while (currentIndex < audioSamples.size) {
            // Calculate chunk boundaries
            val chunkStart = maxOf(0, currentIndex - overlap)
            val chunkEnd = minOf(audioSamples.size, currentIndex + maxChunkSize)
            
            // Extract chunk
            val chunkSize = chunkEnd - chunkStart
            val chunk = FloatArray(chunkSize) { i ->
                audioSamples[chunkStart + i]
            }

            // Process chunk
            val chunkResult = NativeBridge.computeMelSpectrogram(
                chunk,
                sampleRate,
                frameSize,
                hopSize,
                numBands,
                minFreq.toFloat(),
                maxFreq.toFloat()
            )

            // Calculate how much of this chunk's result to keep
            if (currentIndex == 0) {
                // First chunk: keep all results
                allResults.addAll(chunkResult.map { it.toList() })
            } else {
                // Subsequent chunks: skip overlapped portion
                val overlapFrames = (overlap + hopSize - 1) / hopSize // Frames to skip
                val validResults = chunkResult.drop(overlapFrames)
                allResults.addAll(validResults.map { it.toList() })
            }

            // Move to next chunk
            currentIndex += maxChunkSize
            
            // Log progress for debugging
            // android.util.Log.d("EssentiaPlugin", 
            //     "Processed chunk ${chunkStart}-${chunkEnd} (${chunkResult.size} frames), " +
            //     "total frames so far: ${allResults.size}")
        }

        return allResults
    }
}