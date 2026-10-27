import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:uc_reconocimiento/models/device_definition.dart';
import 'package:uc_reconocimiento/vision/ocr_models.dart';
import 'package:uc_reconocimiento/vision/quad.dart';

DeviceDefinition loadKoolnova() => DeviceDefinition.fromJson(
  jsonDecode(File('assets/devices/koolnova_rcu_hybrid.json').readAsStringSync())
      as Map<String, dynamic>,
);

/// Builds a horizontal OCR line of [words] starting at [origin], each word
/// 10 px wide per character, 20 px tall, separated by 10 px; [transform]
/// lets tests rotate the whole line.
OcrLine line(
  List<String> words, {
  Offset origin = Offset.zero,
  Offset Function(Offset)? transform,
}) {
  final t = transform ?? (Offset p) => p;
  final elements = <OcrElement>[];
  var x = origin.dx;
  for (final w in words) {
    final r = Rect.fromLTWH(x, origin.dy, w.length * 10.0, 20);
    elements.add(OcrElement(w, Quad.fromRect(r).map(t)));
    x = r.right + 10;
  }
  return OcrLine(
    words.join(' '),
    Quad.span(elements.first.quad, elements.last.quad),
    elements,
  );
}
