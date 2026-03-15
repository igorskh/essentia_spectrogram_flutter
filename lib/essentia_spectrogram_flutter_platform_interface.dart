import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'essentia_spectrogram_flutter_method_channel.dart';

abstract class EssentiaSpectrogramFlutterPlatform extends PlatformInterface {
  /// Constructs a EssentiaSpectrogramFlutterPlatform.
  EssentiaSpectrogramFlutterPlatform() : super(token: _token);

  static final Object _token = Object();

  static EssentiaSpectrogramFlutterPlatform _instance =
      MethodChannelEssentiaSpectrogramFlutter();

  /// The default instance of [EssentiaSpectrogramFlutterPlatform] to use.
  ///
  /// Defaults to [MethodChannelEssentiaSpectrogramFlutter].
  static EssentiaSpectrogramFlutterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [EssentiaSpectrogramFlutterPlatform] when
  /// they register themselves.
  static set instance(EssentiaSpectrogramFlutterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<String?> returnVersion() {
    throw UnimplementedError('returnVersion() has not been implemented.');
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
    throw UnimplementedError(
      'computeMelSpectrogram() has not been implemented.',
    );
  }

  Future<List<double>> readAudioFile({
    required String filePath,
  }) {
    throw UnimplementedError('readAudioFile() has not been implemented.');
  }

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
    throw UnimplementedError(
      'readAndComputeMelSpectrogram() has not been implemented.',
    );
  }
}
