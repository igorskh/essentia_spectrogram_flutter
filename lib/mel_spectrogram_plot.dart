import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Displays a Mel Spectrogram from a 2-D float array.
///
/// [spectrogram] is indexed as [frame][band], matching the Kotlin
/// `Array<FloatArray>` layout.  Values can be raw linear magnitudes;
/// log₁₀ scaling and normalisation are applied internally.
class MelSpectrogramPlot extends StatefulWidget {
  final List<List<double>> spectrogram;
  final double height;
  final ColorMap colorMap;

  final Color playheadColor;
  // playheadPosition, range 0 to 1
  final double? playheadPosition;

  final Function(double)? onPlayheadPositionChanged;

  const MelSpectrogramPlot({
    super.key,
    required this.spectrogram,
    this.height = 200,
    this.colorMap = ColorMap.grayscale,
    this.playheadColor = Colors.red,
    this.playheadPosition,
    this.onPlayheadPositionChanged,
  });

  @override
  State<MelSpectrogramPlot> createState() => _MelSpectrogramPlotState();
}

class _MelSpectrogramPlotState extends State<MelSpectrogramPlot> {
  double? _playheadPosition;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Bug fix: was assigning _playheadPosition to itself
    _playheadPosition = widget.playheadPosition;
  }

  @override
  void didUpdateWidget(covariant MelSpectrogramPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only accept external updates when not dragging
    if (!_isDragging && widget.playheadPosition != oldWidget.playheadPosition) {
      setState(() {
        _playheadPosition = widget.playheadPosition;
      });
    }
  }

  void _onDragUpdate(Offset localPosition, double totalWidth) {
    final newPosition = (localPosition.dx / totalWidth).clamp(0.0, 1.0);
    setState(() {
      _isDragging = true;
      _playheadPosition = newPosition;
    });
  }

  void _onDragEnd() {
    if (_playheadPosition != null) {
      widget.onPlayheadPositionChanged?.call(_playheadPosition!);
    }
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _isDragging = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Handle tapping directly on a position
          onTapDown: (details) {
            _onDragUpdate(details.localPosition, totalWidth);
            _onDragEnd();
          },
          // Handle dragging
          onHorizontalDragStart: (details) {
            _onDragUpdate(details.localPosition, totalWidth);
          },
          onHorizontalDragUpdate: (details) {
            _onDragUpdate(details.localPosition, totalWidth);
          },
          onHorizontalDragEnd: (_) => _onDragEnd(),
          onHorizontalDragCancel: _onDragEnd,
          child: Stack(
            children: [
              SizedBox(
                height: widget.height,
                width: double.infinity,
                child: _SpectrogramPainterWidget(
                  spectrogram: widget.spectrogram,
                  colorMap: widget.colorMap,
                ),
              ),
              if (_playheadPosition != null)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _PlayheadPainter(
                      _playheadPosition!,
                      widget.playheadColor,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _PlayheadPainter extends CustomPainter {
  final double playheadPosition; // 0 to 1
  final Color playheadColor;

  _PlayheadPainter(this.playheadPosition, this.playheadColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = playheadColor
      ..strokeWidth = 2.0;
    final x = playheadPosition.clamp(0, 1) * size.width;
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) =>
      old.playheadPosition != playheadPosition;
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal async-image builder + painter
// ─────────────────────────────────────────────────────────────────────────────

class _SpectrogramPainterWidget extends StatefulWidget {
  final List<List<double>> spectrogram;
  final ColorMap colorMap;

  const _SpectrogramPainterWidget({
    required this.spectrogram,
    required this.colorMap,
  });

  @override
  State<_SpectrogramPainterWidget> createState() =>
      _SpectrogramPainterWidgetState();
}

class _SpectrogramPainterWidgetState
    extends State<_SpectrogramPainterWidget> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _buildImage();
  }

  @override
  void didUpdateWidget(_SpectrogramPainterWidget old) {
    super.didUpdateWidget(old);
    if (old.spectrogram != widget.spectrogram ||
        old.colorMap != widget.colorMap) {
      _buildImage();
    }
  }

  Future<void> _buildImage() async {
    final img = await buildSpectrogramImage(
      widget.spectrogram,
      widget.colorMap,
    );
    if (mounted) setState(() => _image = img);
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return CustomPaint(
      painter: _SpectrogramPainter(image),
      child: const SizedBox.expand(),
    );
  }
}

class _SpectrogramPainter extends CustomPainter {
  final ui.Image image;
  _SpectrogramPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final src = Rect.fromLTWH(
        0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(0, 0, size.width, size.height);
    // Equivalent to ContentScale.FillBounds — stretches to fill exactly
    canvas.drawImageRect(image, src, dst, Paint());
  }

  @override
  bool shouldRepaint(_SpectrogramPainter old) => old.image != image;
}

// ─────────────────────────────────────────────────────────────────────────────
// Core bitmap builder  (mirrors buildSpectrogramBitmap exactly)
// ─────────────────────────────────────────────────────────────────────────────

/// Builds a [ui.Image] from a 2-D spectrogram array.
///
/// Mirrors the Kotlin `buildSpectrogramBitmap` logic:
///   1. log₁₀ scale with floor 1e-6
///   2. Global min/max normalisation
///   3. Y-flip so low frequencies are at the bottom
///   4. [colorMap] applied per pixel
Future<ui.Image> buildSpectrogramImage(
    List<List<double>> spectrogram,
    ColorMap colorMap,
    ) async {
  final numFrames = spectrogram.length;
  if (numFrames == 0) return _emptyImage();

  final numBands = spectrogram[0].length;
  if (numBands == 0) return _emptyImage();

  // 1. Log scale + find global min/max in one pass
  var globalMin = double.maxFinite;
  var globalMax = -double.maxFinite;

  final logSpec = List.generate(numFrames, (t) {
    return Float32List.fromList(
      List.generate(numBands, (b) {
        final v = log10(max(spectrogram[t][b], 1e-6));
        if (v < globalMin) globalMin = v;
        if (v > globalMax) globalMax = v;
        return v;
      }),
    );
  });

  final range = max(globalMax - globalMin, 1e-6);

  // 2. Fill pixel buffer — RGBA bytes, row-major, Y-flipped
  //    Width = numFrames, Height = numBands
  final pixels = Uint32List(numFrames * numBands);

  for (int t = 0; t < numFrames; t++) {
    for (int b = 0; b < numBands; b++) {
      final normalized = (logSpec[t][b] - globalMin) / range;
      final row = numBands - 1 - b; // Y-flip: low freq → bottom
      final col = t;
      pixels[row * numFrames + col] = colorMap.toArgb(normalized);
    }
  }

  // 3. Decode raw RGBA bytes → ui.Image
  final byteData = pixels.buffer.asUint8List();
  final completer = Completer<ui.Image>();

  ui.decodeImageFromPixels(
    byteData,
    numFrames, // width
    numBands,  // height
    ui.PixelFormat.rgba8888,
    completer.complete,
  );

  return completer.future;
}

Future<ui.Image> _emptyImage() async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = Colors.black,
  );
  return recorder.endRecording().toImage(1, 1);
}

double log10(double x) => log(x) / ln10;

// ─────────────────────────────────────────────────────────────────────────────
// Color maps  (mirrors heatmapColor / grayscaleColor)
// ─────────────────────────────────────────────────────────────────────────────

enum ColorMap {
  /// Black → white  (mirrors Kotlin `grayscaleColor`)
  grayscale,

  /// White → black (inverse of `grayscaleColor`, for testing)
  inverseGrayscale,

  /// Dark blue → cyan → yellow → white  (mirrors Kotlin `heatmapColor`)
  heatmap;

  /// Returns a packed RGBA int for [v] ∈ [0, 1].
  int toArgb(double v) {
    switch (this) {
      case ColorMap.grayscale:
        return _grayscaleColor(v);
      case ColorMap.heatmap:
        return _heatmapColor(v);
      case ColorMap.inverseGrayscale:
        return _inverseGrayscaleColor(v);
    }
  }
}

/// Mirrors Kotlin `grayscaleColor`: [0,1] → RGBA black→white
int _grayscaleColor(double v) {
  final f = v.clamp(0.0, 1.0);
  final c = (255 * f).toInt();
  // RGBA8888: R=c, G=c, B=c, A=255
  return (c) | (c << 8) | (c << 16) | (0xFF << 24);
}

/// Inverse grayscale: [0,1] → RGBA white→black
int _inverseGrayscaleColor(double v) {
  final f = v.clamp(0.0, 1.0);
  final c = (255 * (1.0 - f)).toInt(); // <-- invert here
  // RGBA8888: R=c, G=c, B=c, A=255
  return (c) | (c << 8) | (c << 16) | (0xFF << 24);
}

/// Mirrors Kotlin `heatmapColor`: [0,1] → RGBA dark-blue→cyan→yellow→white
int _heatmapColor(double v) {
  final f = v.clamp(0.0, 1.0);
  final r = ((255 * (f * 2.0 - 1.0).clamp(0.0, 1.0))).toInt();
  final g = ((255 * (1.0 - (2.0 * f - 1.0).abs()))).toInt();
  final b = ((255 * (1.0 - (f * 2.0 - 1.0).clamp(0.0, 1.0)))).toInt();
  // RGBA8888
  return (r) | (g << 8) | (b << 16) | (0xFF << 24);
}