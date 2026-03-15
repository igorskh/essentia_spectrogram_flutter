package one.beagile.essentia_spectrogram_flutter

object NativeBridge {
    init {
        System.loadLibrary("native-bridge")
    }

    external fun returnVersion(): String;
    
    /**
     * @param audioSamples  PCM float samples [-1.0, 1.0]
     * @param sampleRate    e.g. 44100
     * @param frameSize     e.g. 1024
     * @param hopSize       e.g. 512
     * @param numBands      e.g. 40 or 128
     * @return              2D array [frames][melBands]
     */
    external fun computeMelSpectrogram(
        audioSamples: FloatArray,
        sampleRate: Int,
        frameSize: Int,
        hopSize: Int,
        numBands: Int,
        minFreq: Float,
        maxFreq: Float
    ): Array<FloatArray>
}