import '../models/device_definition.dart';

/// Builds a Markdown installation manual draft from a device definition.
String buildManualMarkdown(DeviceDefinition device) {
  final b = StringBuffer()
    ..writeln('# Manual de instalación — ${device.fullName}')
    ..writeln();
  if (device.productCode.isNotEmpty) {
    b.writeln('Código de producto: `${device.productCode}`');
    b.writeln();
  }
  if (device.description.isNotEmpty) {
    b.writeln(device.description);
    b.writeln();
  }
  final pending = device.ports.where((p) => !p.verified).length;
  if (pending > 0) {
    b
      ..writeln(
        '> **Borrador.** $pending puertos (marcados con *) tienen la función '
        'pendiente de validar con el manual oficial del fabricante.',
      )
      ..writeln();
  }

  b
    ..writeln('## Puertos de entrada y salida')
    ..writeln();
  for (final face in device.faces) {
    final ports = device.ports.where((p) => p.face == face.id).toList();
    if (ports.isEmpty) continue;
    b
      ..writeln('### ${face.name}')
      ..writeln()
      ..writeln('| Etiqueta | Nombre | Tipo | Bornes | Descripción |')
      ..writeln('|---|---|---|---|---|');
    for (final p in ports) {
      final pins = p.pins.isEmpty ? '—' : p.pins.map((x) => x.label).join(', ');
      final name = '${p.name}${p.verified ? '' : ' *'}${p.danger ? ' ⚠' : ''}';
      b.writeln(
        '| `${p.label}` | $name | ${p.type.displayName} | $pins | '
        '${p.description.replaceAll('|', '/')} |',
      );
    }
    b.writeln();
  }

  if (device.steps.isNotEmpty) {
    b
      ..writeln('## Procedimiento de instalación')
      ..writeln();
    for (var i = 0; i < device.steps.length; i++) {
      final s = device.steps[i];
      b.writeln('${i + 1}. **${s.title}.** ${s.instruction}');
      final port = device.portById(s.portId);
      if (port != null) {
        final pin = s.pinId == null ? '' : ', borne `${s.pinId}`';
        b.writeln('   - Puerto: `${port.label}` (${port.name}$pin)');
      }
      if (s.warning != null) b.writeln('   - ⚠ ${s.warning}');
    }
    b.writeln();
  }
  return b.toString();
}
