import 'dart:ui';

import '../models/device_definition.dart';
import 'ocr_models.dart';
import 'quad.dart';

class PinDetection {
  const PinDetection({
    required this.pin,
    required this.position,
    required this.fromLabel,
  });

  final PinDefinition pin;
  final Offset position;

  /// True when the pin was located from its own printed text rather than
  /// estimated by splitting the label width.
  final bool fromLabel;
}

class PortDetection {
  const PortDetection({
    required this.port,
    required this.label,
    required this.connector,
    required this.pins,
    required this.rawText,
    this.patternIndex = 0,
  });

  final PortDefinition port;
  final Quad label;
  final Quad connector;
  final List<PinDetection> pins;
  final String rawText;

  /// Index of the pattern that matched; lower means a more specific match.
  final int patternIndex;

  PinDetection? pin(String? id) {
    for (final p in pins) {
      if (p.pin.id == id) return p;
    }
    return null;
  }

  PortDetection lerpTo(PortDetection next, double t) => PortDetection(
    port: next.port,
    label: label.lerpTo(next.label, t),
    connector: connector.lerpTo(next.connector, t),
    pins: [
      for (final p in next.pins)
        PinDetection(
          pin: p.pin,
          fromLabel: p.fromLabel,
          position: switch (pin(p.pin.id)) {
            final prev? => Offset.lerp(prev.position, p.position, t)!,
            null => p.position,
          },
        ),
    ],
    rawText: next.rawText,
    patternIndex: next.patternIndex,
  );

  PortDetection map(Offset Function(Offset) f) => PortDetection(
    port: port,
    label: label.map(f),
    connector: connector.map(f),
    pins: [
      for (final p in pins)
        PinDetection(
          pin: p.pin,
          position: f(p.position),
          fromLabel: p.fromLabel,
        ),
    ],
    rawText: rawText,
    patternIndex: patternIndex,
  );
}

class MatchResult {
  const MatchResult({
    required this.detections,
    required this.identifiers,
    required this.faceId,
  });

  final List<PortDetection> detections;
  final Set<String> identifiers;
  final String? faceId;
}

class _CompiledPattern {
  _CompiledPattern(this.port, this.index, this.regex);

  final PortDefinition port;
  final int index;
  final RegExp regex;
}

/// Finds the device's printed port labels in OCR output and projects where
/// the physical connector and its pins are.
class PortMatcher {
  PortMatcher(this.device)
    : _patterns =
          [
            for (final port in device.ports)
              for (var i = 0; i < port.patterns.length; i++)
                _CompiledPattern(port, i, RegExp(port.patterns[i])),
          ]..sort(
            (a, b) => b.regex.pattern.length.compareTo(a.regex.pattern.length),
          ),
      _identifiers = {
        for (final id in device.identifiers) id.id: RegExp(id.pattern),
      },
      _pinPatterns = {
        for (final port in device.ports)
          for (final pin in port.pins)
            '${port.id}/${pin.id}': RegExp(pin.pattern),
      };

  final DeviceDefinition device;
  final List<_CompiledPattern> _patterns;
  final Map<String, RegExp> _identifiers;
  final Map<String, RegExp> _pinPatterns;

  MatchResult match(List<OcrLine> lines) {
    final best = <String, PortDetection>{};
    final identifiers = <String>{};

    for (final line in lines) {
      final elements = line.elements.isEmpty
          ? [OcrElement(line.text, line.quad)]
          : line.elements;

      final buffer = StringBuffer();
      final spans = <(int, int)>[];
      for (final e in elements) {
        if (buffer.isNotEmpty) buffer.write(' ');
        final start = buffer.length;
        buffer.write(e.text.toUpperCase().trim());
        spans.add((start, buffer.length));
      }
      final text = buffer.toString();
      final used = List<bool>.filled(text.length, false);

      for (final entry in _identifiers.entries) {
        if (entry.value.hasMatch(text)) identifiers.add(entry.key);
      }

      for (final cp in _patterns) {
        for (final m in cp.regex.allMatches(text)) {
          var start = m.start;
          var end = m.end;
          while (start < end && text[start] == ' ') {
            start++;
          }
          while (end > start && text[end - 1] == ' ') {
            end--;
          }
          if (start == end) continue;
          if (used.sublist(start, end).any((u) => u)) continue;
          used.fillRange(start, end, true);

          final covered = <OcrElement>[
            for (var i = 0; i < elements.length; i++)
              if (spans[i].$1 < end && spans[i].$2 > start) elements[i],
          ];
          if (covered.isEmpty) continue;

          final detection = _buildDetection(
            cp.port,
            cp.index,
            covered,
            text.substring(start, end),
          );
          final previous = best[cp.port.id];
          if (previous == null || _isBetter(detection, previous)) {
            best[cp.port.id] = detection;
          }
        }
      }
    }

    final detections = best.values.toList();
    return MatchResult(
      detections: detections,
      identifiers: identifiers,
      faceId: _dominantFace(detections),
    );
  }

  bool _isBetter(PortDetection a, PortDetection b) {
    if (a.patternIndex != b.patternIndex) {
      return a.patternIndex < b.patternIndex;
    }
    return a.label.height > b.label.height;
  }

  PortDetection _buildDetection(
    PortDefinition port,
    int patternIndex,
    List<OcrElement> covered,
    String rawText,
  ) {
    final label = Quad.span(covered.first.quad, covered.last.quad);
    final placement = port.connector;
    final connector = label.below(gap: placement.gap, depth: placement.depth);
    final pinDrop =
        label.down * ((placement.gap + placement.depth / 2) * label.height);

    final pins = <PinDetection>[];
    final taken = <OcrElement>{};
    for (final pin in port.pins) {
      final regex = _pinPatterns['${port.id}/${pin.id}']!;
      for (final e in covered) {
        if (taken.contains(e)) continue;
        if (regex.hasMatch(e.text.toUpperCase().trim())) {
          taken.add(e);
          pins.add(
            PinDetection(
              pin: pin,
              position: e.quad.center + pinDrop,
              fromLabel: true,
            ),
          );
          break;
        }
      }
    }

    // OCR often fuses "D- D+" into one word; place missing pins by evenly
    // spacing them across the label, which matches how terminals are printed.
    final n = port.pins.length;
    for (var i = 0; i < n; i++) {
      final pin = port.pins[i];
      if (pins.any((p) => p.pin.id == pin.id)) continue;
      final t = (i + 0.5) / n;
      final top = Offset.lerp(label.tl, label.tr, t)!;
      final bottom = Offset.lerp(label.bl, label.br, t)!;
      pins.add(
        PinDetection(
          pin: pin,
          position: (top + bottom) / 2 + pinDrop,
          fromLabel: false,
        ),
      );
    }
    pins.sort(
      (a, b) => port.pins.indexOf(a.pin).compareTo(port.pins.indexOf(b.pin)),
    );

    return PortDetection(
      port: port,
      label: label,
      connector: connector,
      pins: pins,
      rawText: rawText,
      patternIndex: patternIndex,
    );
  }

  String? _dominantFace(List<PortDetection> detections) {
    final counts = <String, int>{};
    for (final d in detections) {
      counts.update(d.port.face, (c) => c + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }
}
