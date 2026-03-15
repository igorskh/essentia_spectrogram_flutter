# Essentia Spectrogram Flutter Plugin

Flutter wrapper for the [Essentia library](https://github.com/MTG/essentia) - a C++ library for audio analysis and audio-based music information retrieval.

Library uses precompiled native binaries for Android and iOS.

Library is compiled with following algorithms:
```bash
--include-algos=FrameCutter,Windowing,Spectrum,MelBands,FFT,Magnitude,TriangularBands
```

## Usage

```dart
import 'package:essentia_spectrogram_flutter/essentia_spectrogram_flutter.dart';

void main() async {
  final plugin = EssentiaSpectrogramFlutter();
  final sampleRate = 44100;
  final melSpectrogram = await plugin.readAndComputeMelSpectrogram(
    filePath: 'path/to/audio/file',
    sampleRate: sampleRate,
    frameSize: 2048,
    hopSize: 256,
    numBands: 60,
    targetSamples: sampleRate * 5,
  );

  print(melSpectrogram);
}
```