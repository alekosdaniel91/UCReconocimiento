import 'dart:ui';

import 'quad.dart';

/// Engine-agnostic OCR output so the matching logic can be unit tested
/// without ML Kit.
class OcrElement {
  const OcrElement(this.text, this.quad);

  final String text;
  final Quad quad;
}

class OcrLine {
  const OcrLine(this.text, this.quad, this.elements);

  final String text;
  final Quad quad;
  final List<OcrElement> elements;
}

class OcrFrame {
  const OcrFrame({
    required this.imageSize,
    required this.lines,
    this.mirrorX = false,
  });

  /// Size of the coordinate space the quads are expressed in.
  final Size imageSize;
  final List<OcrLine> lines;
  final bool mirrorX;
}
