import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'essentia_spectrogram_flutter_platform_interface.dart';

/// An implementation of [EssentiaSpectrogramFlutterPlatform] that uses method channels.
class MethodChannelEssentiaSpectrogramFlutter extends EssentiaSpectrogramFlutterPlatform {
    /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('essentia_spectrogram_flutter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<String?> returnVersion() async {
    final version = await methodChannel.invokeMethod<String>('returnVersion');
    return version;
  }

  @override
  Future<List<List<double>>> computeMelSpectrogram({
    required List<double> audioSamples,
    required int sampleRate,
    required int frameSize,
    required int hopSize,
    required int numBands,
    int? maxChunkSize,
    int? minFreq,
    int? maxFreq,
  }) async {
    final samples = Float32List.fromList(audioSamples);

    final arguments = {
      'audioSamples': samples,
      'sampleRate': sampleRate,
      'frameSize': frameSize,
      'hopSize': hopSize,
      'numBands': numBands,
      'minFreq': minFreq ?? 0,
      'maxFreq': maxFreq ?? (sampleRate / 2).floor(),
      'maxChunkSize': maxChunkSize ?? sampleRate * 10,
    };

    final result = await methodChannel
        .invokeMethod<List<dynamic>>('computeMelSpectrogram', arguments);

    // Convert the result to List<List<double>>
    return (result ?? []).map((band) {
      return (band as List<dynamic>).map((value) => value as double).toList();
    }).toList();
  }

  @override
  Future<List<double>> readAudioFile({
    required String filePath
  }) async {
    final result = await methodChannel.invokeMethod<List<dynamic>>(
      'readAudioFile',
      {'filePath': filePath},
    );

    // Convert the result to List<double>
    return (result ?? []).map((value) => value as double).toList();
  }

  @override
  Future<List<List<double>>> readAndComputeMelSpectrogram({
    required String filePath,
    required int sampleRate,
    required int frameSize,
    required int hopSize,
    required int numBands,
    int? maxChunkSize,
    int? minFreq,
    int? maxFreq,
  }) async {
    final arguments = {
      'filePath': filePath,
      'sampleRate': sampleRate,
      'frameSize': frameSize,
      'hopSize': hopSize,
      'numBands': numBands,
      'minFreq': minFreq ?? 0,
      'maxFreq': maxFreq ?? (sampleRate / 2).floor(),
      'maxChunkSize': maxChunkSize ?? sampleRate * 10,
    };

    final result = await methodChannel
        .invokeMethod<List<dynamic>>('readAndComputeMelSpectrogram', arguments);

    // Convert the result to List<List<double>>
    return (result ?? []).map((band) {
      return (band as List<dynamic>).map((value) => value as double).toList();
    }).toList();
  }
}
