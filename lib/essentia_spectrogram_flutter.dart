
import 'essentia_spectrogram_flutter_platform_interface.dart';

class EssentiaSpectrogramFlutter {
  Future<String?> getPlatformVersion() {
    return EssentiaSpectrogramFlutterPlatform.instance.getPlatformVersion();
  }
    Future<String?> returnVersion() {
    return EssentiaSpectrogramFlutterPlatform.instance.returnVersion();
  }

  Future<List<List<double>>> computeMelSpectrogram({
    required List<double> audioSamples,
    required int sampleRate,
    required int frameSize,
    required int hopSize,
    required int numBands,
    int? maxChunkSize,
    int? minFreq,
    int? maxFreq,
  }) {
    return EssentiaSpectrogramFlutterPlatform.instance.computeMelSpectrogram(
      audioSamples: audioSamples,
      sampleRate: sampleRate,
      frameSize: frameSize,
      hopSize: hopSize,
      numBands: numBands,
      maxChunkSize: maxChunkSize,
      minFreq: minFreq,
      maxFreq: maxFreq,
    );
  }

  Future<List<double>> readAudioFile({
    required String filePath,
  }) {
    return EssentiaSpectrogramFlutterPlatform.instance.readAudioFile(
      filePath: filePath,
    );
  }

  /// Reads an audio file and computes its mel spectrogram in one operation.
  /// This is more memory-efficient than reading the entire file first.
  Future<List<List<double>>> readAndComputeMelSpectrogram({
    required String filePath,
    required int sampleRate,
    required int frameSize,
    required int hopSize,
    required int numBands,
    int? maxChunkSize,
    int? minFreq,
    int? maxFreq,
  }) {
    return EssentiaSpectrogramFlutterPlatform.instance.readAndComputeMelSpectrogram(
      filePath: filePath,
      sampleRate: sampleRate,
      frameSize: frameSize,
      hopSize: hopSize,
      numBands: numBands,
      maxChunkSize: maxChunkSize,
      minFreq: minFreq,
      maxFreq: maxFreq,
    );
  }
}
