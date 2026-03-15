import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

import 'package:essentia_spectrogram_flutter/essentia_spectrogram_flutter.dart';
import 'package:essentia_spectrogram_flutter/mel_spectrogram_plot.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  String _essentiaLibVersion = 'Unknown';
  String _error = "";

  List<List<double>>? spectrogramData;

  final _essentiaFlutterPlugin = EssentiaSpectrogramFlutter();

  @override
  void initState() {
    super.initState();
    initPlatformState();
    readAudioFile();
  }

  Future<void> readAudioFile() async {
    setState(() {
      _error = "";
    });
    final outPath = p.join((await getTemporaryDirectory()).path, 'waveform.wav');
    final audioFile = File(
      outPath,
    );
    try {
      await audioFile.writeAsBytes(
        (await rootBundle.load('assets/test_large_96k.wav')).buffer.asUint8List(),
      );

      final sampleRate = 44100;
      final spec = await _essentiaFlutterPlugin.readAndComputeMelSpectrogram(
        filePath: outPath,
        sampleRate: sampleRate,
        frameSize: 2048,
        hopSize: 256,
        numBands: 60,
        maxChunkSize: sampleRate * 5,
      );

      setState(() {
        spectrogramData = spec;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _essentiaFlutterPlugin.getPlatformVersion() ??
          'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    String essentiaLibVersion;
    try {
      essentiaLibVersion =
          await _essentiaFlutterPlugin.returnVersion() ??
          'Unknown platform version';
    } on PlatformException {
      essentiaLibVersion = 'Failed to get lib version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
      _essentiaLibVersion = essentiaLibVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Spectrogram Plugin Example')),
        body: Center(
          child: Column(
            children: [
              Text('Running on: $_platformVersion\n'),
              Text('Essentia Lib: $_essentiaLibVersion'),
              if (_error.isNotEmpty)
                Text(_error),
              if (spectrogramData != null)
                MelSpectrogramPlot(
                  spectrogram: spectrogramData!,
                  height: 200,
                  colorMap: ColorMap.grayscale,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
