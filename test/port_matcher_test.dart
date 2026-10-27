import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:uc_reconocimiento/vision/ocr_models.dart';
import 'package:uc_reconocimiento/vision/port_matcher.dart';

import 'helpers.dart';

void main() {
  final device = loadKoolnova();
  final matcher = PortMatcher(device);

  Set<String> ids(MatchResult r) => {for (final d in r.detections) d.port.id};

  test('recognises every label on the power/communications side', () {
    final result = matcher.match([
      line(['AUX', '2'], origin: const Offset(0, 0)),
      line(['AUX', '1'], origin: const Offset(100, 0)),
      line(['COM', 'D-', 'D+'], origin: const Offset(200, 0)),
      line(['H', 'ALR'], origin: const Offset(320, 0)),
      line(['GND', 'B-', 'A+', '+24'], origin: const Offset(400, 0)),
      line(['L', 'N'], origin: const Offset(560, 0)),
    ]);

    expect(ids(result), {'AUX1', 'AUX2', 'MODBUS', 'H_ALR', 'BUS_24', 'AC_IN'});
    expect(result.faceId, 'power');
  });

  test('recognises zones even when OCR merges them into one line', () {
    final result = matcher.match([
      line(['ZONE', '1', 'ZONE', '2', 'ZONE', '3']),
      line([
        'Z0NE',
        '4',
        'ZONE',
        'S',
        'ZONE',
        '6',
        'ZONE',
        '7',
        'ZONE',
        '8',
      ], origin: const Offset(0, 100)),
      line([
        'TX',
        'BUS',
        'RX',
        'RADIO',
        'STATUS',
      ], origin: const Offset(0, 200)),
    ]);

    expect(ids(result), {
      for (var i = 1; i <= 8; i++) 'ZONE$i',
      'LED_BUS',
      'LED_RADIO',
      'LED_STATUS',
    });
    expect(result.faceId, 'zones');

    final zone2 = result.detections.firstWhere((d) => d.port.id == 'ZONE2');
    expect(zone2.label.bounds, const Rect.fromLTRB(70, 0, 130, 20));
  });

  test('"TX BUS" is not reported as the standalone BUS connector', () {
    final result = matcher.match([
      line(['TX', 'BUS']),
    ]);
    expect(ids(result), {'LED_BUS'});

    final standalone = matcher.match([
      line(['BUS']),
    ]);
    expect(ids(standalone), {'BUS_AUX'});
  });

  test('the website on the lid is not mistaken for the Modbus COM label', () {
    final result = matcher.match([
      line(['KOOLNOVA']),
      line(['www.koolnova.com'], origin: const Offset(0, 30)),
      line(['RADIO', 'CENTRAL', 'UNIT'], origin: const Offset(0, 60)),
      line(['HYBRID'], origin: const Offset(0, 90)),
    ]);
    expect(result.detections, isEmpty);
    expect(result.identifiers, {'brand', 'family', 'model'});
    expect(result.faceId, isNull);
  });

  test('connector and pins are projected below the label', () {
    final result = matcher.match([
      line(['GND', 'B-', 'A+', '+24']),
    ]);
    final bus = result.detections.single;

    expect(bus.connector.bounds.top, greaterThan(bus.label.bounds.bottom));
    expect([for (final p in bus.pins) p.pin.id], ['GND', 'B-', 'A+', '+24']);
    expect(bus.pins.every((p) => p.fromLabel), isTrue);
    expect(bus.pin('A+')!.position.dx, closeTo(80, 0.01));
    expect(bus.pin('A+')!.position.dy, greaterThan(20));
  });

  test('fused pin text falls back to evenly spaced pins', () {
    final result = matcher.match([
      line(['COM', 'D-D+']),
    ]);
    final modbus = result.detections.single;
    expect(modbus.port.id, 'MODBUS');
    expect(modbus.pin('COM')!.fromLabel, isTrue);
    expect(modbus.pin('D-')!.fromLabel, isFalse);
    expect(
      modbus.pin('D-')!.position.dx,
      lessThan(modbus.pin('D+')!.position.dx),
    );
  });

  test('"down" follows the text when the unit is rotated 90°', () {
    // Text reading top-to-bottom: rotate (x, y) -> (-y, x).
    Offset rotate(Offset p) => Offset(-p.dy, p.dx);
    final result = matcher.match([
      line(['ZONE', '1'], transform: rotate),
    ]);
    final zone = result.detections.single;

    expect(zone.connector.center.dx, lessThan(zone.label.center.dx));
    expect(zone.connector.center.dy, closeTo(zone.label.center.dy, 0.01));
  });

  test('prefers the most specific pattern when a port matches twice', () {
    final result = matcher.match([
      line(['AC', 'IN']),
      line(['L', 'N'], origin: const Offset(0, 30)),
    ]);
    final ac = result.detections.single;
    expect(ac.port.id, 'AC_IN');
    expect(ac.rawText, 'L N');
  });

  test('falls back to the line quad when OCR returns no elements', () {
    final source = line(['AUX', '1']);
    final result = matcher.match([OcrLine(source.text, source.quad, const [])]);
    expect(ids(result), {'AUX1'});
  });
}
