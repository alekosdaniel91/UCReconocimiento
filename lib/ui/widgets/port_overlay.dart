import 'package:flutter/material.dart';

import '../../vision/port_matcher.dart';
import '../port_style.dart';

/// Maps OCR coordinates onto the widget that displays the image/preview.
class ImageToCanvas {
  const ImageToCanvas({
    required this.imageSize,
    required this.canvasSize,
    this.mirrorX = false,
  });

  final Size imageSize;
  final Size canvasSize;
  final bool mirrorX;

  Offset call(Offset p) {
    final x = p.dx * canvasSize.width / imageSize.width;
    return Offset(
      mirrorX ? canvasSize.width - x : x,
      p.dy * canvasSize.height / imageSize.height,
    );
  }

  List<PortDetection> mapAll(List<PortDetection> detections) => [
    for (final d in detections) d.map(call),
  ];
}

/// Fills the available space with an overlay for [detections] (expressed in
/// [imageSize] coordinates) and reports taps on a port.
class PortOverlay extends StatelessWidget {
  const PortOverlay({
    super.key,
    required this.detections,
    required this.imageSize,
    this.mirrorX = false,
    this.targetPortId,
    this.targetPinId,
    this.pulse,
    this.onPortTap,
  });

  final List<PortDetection> detections;
  final Size imageSize;
  final bool mirrorX;
  final String? targetPortId;
  final String? targetPinId;
  final Animation<double>? pulse;
  final ValueChanged<PortDetection>? onPortTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mapped = ImageToCanvas(
          imageSize: imageSize,
          canvasSize: constraints.biggest,
          mirrorX: mirrorX,
        ).mapAll(detections);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: onPortTap == null
              ? null
              : (details) {
                  for (final d in mapped.reversed) {
                    if (d.connector.contains(details.localPosition) ||
                        d.label.contains(details.localPosition)) {
                      onPortTap!(d);
                      return;
                    }
                  }
                },
          child: CustomPaint(
            size: constraints.biggest,
            painter: PortOverlayPainter(
              detections: mapped,
              targetPortId: targetPortId,
              targetPinId: targetPinId,
              pulse: pulse,
            ),
          ),
        );
      },
    );
  }
}

class PortOverlayPainter extends CustomPainter {
  PortOverlayPainter({
    required this.detections,
    this.targetPortId,
    this.targetPinId,
    this.pulse,
  }) : super(repaint: pulse);

  final List<PortDetection> detections;
  final String? targetPortId;
  final String? targetPinId;
  final Animation<double>? pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final guided = targetPortId != null;
    final ordered = [...detections]
      ..sort(
        (a, b) => (a.port.id == targetPortId ? 1 : 0).compareTo(
          b.port.id == targetPortId ? 1 : 0,
        ),
      );

    for (final d in ordered) {
      final isTarget = d.port.id == targetPortId;
      final dimmed = guided && !isTarget;
      final color = portColor(d.port).withValues(alpha: dimmed ? 0.35 : 1);
      final glow = isTarget ? (pulse?.value ?? 1) : 0.0;

      canvas.drawPath(
        d.label.toPath(),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      );

      final connectorPath = d.connector.toPath();
      canvas.drawPath(
        connectorPath,
        Paint()
          ..color = color.withValues(alpha: dimmed ? 0.08 : 0.22 + 0.2 * glow),
      );
      canvas.drawPath(
        connectorPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isTarget ? 3 + 3 * glow : 2
          ..color = color,
      );

      if (isTarget) _drawArrow(canvas, d, color, glow);

      for (final pin in d.pins) {
        final pinTarget = isTarget && pin.pin.id == targetPinId;
        final radius = pinTarget ? 7 + 4 * glow : 4.5;
        canvas.drawCircle(
          pin.position,
          radius + 1.5,
          Paint()..color = Colors.black54,
        );
        canvas.drawCircle(
          pin.position,
          radius,
          Paint()..color = pinTarget ? Colors.white : color,
        );
        if (!dimmed) {
          _drawText(
            canvas,
            pin.pin.label,
            pin.position + Offset(0, radius + 8),
            fontSize: 11,
            background: Colors.black87,
            color: pinTarget ? Colors.yellowAccent : Colors.white,
          );
        }
      }

      if (!dimmed) {
        _drawText(
          canvas,
          d.port.name,
          d.connector.center,
          fontSize: isTarget ? 15 : 12,
          background: color.withValues(alpha: 0.9),
          color: Colors.white,
          bold: true,
        );
      }
    }
  }

  void _drawArrow(Canvas canvas, PortDetection d, Color color, double glow) {
    final tip = d.label.center - d.label.down * (d.label.height * 0.8);
    final tail = tip - d.label.down * (d.label.height * (3 + glow));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(tail, tip, paint);
    final side = Offset(-d.label.down.dy, d.label.down.dx) * 10;
    final back = tip - d.label.down * 14;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((back + side).dx, (back + side).dy)
        ..lineTo((back - side).dx, (back - side).dy)
        ..close(),
      Paint()..color = color,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required Color background,
    required Color color,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final rect = Rect.fromCenter(
      center: center,
      width: painter.width + 10,
      height: painter.height + 4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = background,
    );
    painter.paint(canvas, rect.topLeft + const Offset(5, 2));
  }

  @override
  bool shouldRepaint(PortOverlayPainter old) =>
      old.detections != detections ||
      old.targetPortId != targetPortId ||
      old.targetPinId != targetPinId;
}
