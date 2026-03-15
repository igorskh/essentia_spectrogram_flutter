// This is a basic Flutter integration test.
//
// Since integration tests run in a full Flutter application, they can interact
// with the host side of a plugin implementation, unlike Dart unit tests.
//
// For more information about Flutter integration tests, please see
// https://flutter.dev/to/integration-testing
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:essentia_spectrogram_flutter/essentia_spectrogram_flutter.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

void printMemory(String label) {
  final mb = (ProcessInfo.currentRss / 1024 / 1024).toStringAsFixed(2);
  // ignore: avoid_print
  print('[$label] RSS: ${mb}MB');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('getPlatformVersion test', (WidgetTester tester) async {
    final EssentiaSpectrogramFlutter plugin = EssentiaSpectrogramFlutter();
    final String? version = await plugin.getPlatformVersion();
    // The version string depends on the host platform running the test, so
    // just assert that some non-empty string is returned.
    expect(version?.isNotEmpty, true);
  });

  testWidgets('readAndComputeMelSpectrogram from wav test', (
      WidgetTester tester,
      ) async {
    printMemory("before EssentiaFlutter");
    final EssentiaSpectrogramFlutter plugin = EssentiaSpectrogramFlutter();
    printMemory("after EssentiaFlutter");

    final outPath = p.join(
      (await getTemporaryDirectory()).path,
      'waveform.wav',
    );
    final audioFile = File(outPath);
    await audioFile.writeAsBytes(
      (await rootBundle.load('assets/test_large_96k.wav')).buffer.asUint8List(),
    );

    final sampleRate = 44100;

    for (var i = 0; i < 10; i++) {
      printMemory("before $i");
      var spec = await plugin.readAndComputeMelSpectrogram(
        filePath: outPath,
        sampleRate: sampleRate,
        frameSize: 2048,
        hopSize: 256,
        numBands: 50,
        maxChunkSize: sampleRate * 5,
      );
      expect(spec.length, greaterThan(0));
      printMemory("after $i");
    }
  });

  testWidgets('readAndComputeMelSpectrogram from mp3 test', (
      WidgetTester tester,
      ) async {
    final EssentiaSpectrogramFlutter plugin = EssentiaSpectrogramFlutter();

    final outPath = p.join(
      (await getTemporaryDirectory()).path,
      'waveform.mp3',
    );
    final audioFile = File(outPath);
    await audioFile.writeAsBytes(
      (await rootBundle.load('assets/test_44k.mp3')).buffer.asUint8List(),
    );

    final sampleRate = 44100;
    final numBands = 50;
    var spec = await plugin.readAndComputeMelSpectrogram(
      filePath: outPath,
      sampleRate: sampleRate,
      frameSize: 2048,
      hopSize: 256,
      numBands: numBands,
      maxChunkSize: sampleRate * 5,
    );

    expect(spec.length, greaterThan(0));
    expect(spec[0].length, equals(numBands));
  });
}
