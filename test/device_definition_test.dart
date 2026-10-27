import 'package:flutter_test/flutter_test.dart';
import 'package:uc_reconocimiento/manual/manual_builder.dart';
import 'package:uc_reconocimiento/models/device_definition.dart';

import 'helpers.dart';

void main() {
  test('Koolnova definition loads with all ports and steps', () {
    final device = loadKoolnova();
    expect(device.ports, hasLength(18));
    expect(device.faces.map((f) => f.id), ['zones', 'power']);
    expect(device.portById('AC_IN')!.danger, isTrue);
    for (final step in device.steps) {
      if (step.portId != null) expect(device.portById(step.portId), isNotNull);
    }
  });

  test('every label pattern is a valid regular expression', () {
    final device = loadKoolnova();
    for (final port in device.ports) {
      for (final pattern in port.patterns) {
        expect(() => RegExp(pattern), returnsNormally, reason: port.id);
      }
    }
  });

  test('rejects steps that point at unknown ports', () {
    expect(
      () => DeviceDefinition.fromJson({
        'id': 'x',
        'brand': 'b',
        'name': 'n',
        'faces': [
          {'id': 'f', 'name': 'F', 'hint': ''},
        ],
        'ports': <Object>[],
        'steps': [
          {'id': 's', 'title': 't', 'instruction': 'i', 'port': 'NOPE'},
        ],
      }),
      throwsFormatException,
    );
  });

  test('manual draft lists ports by side and the numbered procedure', () {
    final markdown = buildManualMarkdown(loadKoolnova());
    expect(
      markdown,
      contains('# Manual de instalación — Koolnova Radio Central Unit HYBRID'),
    );
    expect(markdown, contains('### Lateral de ZONAS'));
    expect(markdown, contains('| `COM D- D+` | Modbus RS485 *'));
    expect(markdown, contains('1. **Seguridad.**'));
    expect(markdown, contains('borne `L`'));
  });
}
