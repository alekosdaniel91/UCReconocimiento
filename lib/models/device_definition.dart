enum PortType {
  power,
  communication,
  input,
  output,
  auxiliary,
  indicator;

  static PortType parse(String value) => PortType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => throw FormatException('Tipo de puerto desconocido: $value'),
  );

  String get displayName => switch (this) {
    PortType.power => 'Alimentación',
    PortType.communication => 'Comunicación',
    PortType.input => 'Entrada',
    PortType.output => 'Salida',
    PortType.auxiliary => 'Auxiliar',
    PortType.indicator => 'Indicador',
  };
}

class DeviceIdentifier {
  const DeviceIdentifier({
    required this.id,
    required this.label,
    required this.pattern,
  });

  factory DeviceIdentifier.fromJson(Map<String, dynamic> json) =>
      DeviceIdentifier(
        id: json['id'] as String,
        label: json['label'] as String,
        pattern: json['pattern'] as String,
      );

  final String id;
  final String label;
  final String pattern;
}

class DeviceFace {
  const DeviceFace({required this.id, required this.name, required this.hint});

  factory DeviceFace.fromJson(Map<String, dynamic> json) => DeviceFace(
    id: json['id'] as String,
    name: json['name'] as String,
    hint: json['hint'] as String,
  );

  final String id;
  final String name;
  final String hint;
}

class PinDefinition {
  const PinDefinition({
    required this.id,
    required this.label,
    required this.pattern,
    this.description,
  });

  factory PinDefinition.fromJson(Map<String, dynamic> json) => PinDefinition(
    id: json['id'] as String,
    label: json['label'] as String,
    pattern: json['pattern'] as String,
    description: json['description'] as String?,
  );

  final String id;
  final String label;
  final String pattern;
  final String? description;
}

/// Where the physical connector sits relative to its printed label, measured
/// in label heights along the text's "down" direction.
class ConnectorPlacement {
  const ConnectorPlacement({this.gap = 0.4, this.depth = 3.0});

  factory ConnectorPlacement.fromJson(Map<String, dynamic>? json) =>
      json == null
      ? const ConnectorPlacement()
      : ConnectorPlacement(
          gap: (json['gap'] as num?)?.toDouble() ?? 0.4,
          depth: (json['depth'] as num?)?.toDouble() ?? 3.0,
        );

  final double gap;
  final double depth;
}

class PortDefinition {
  const PortDefinition({
    required this.id,
    required this.label,
    required this.name,
    required this.face,
    required this.type,
    required this.description,
    required this.patterns,
    this.pins = const [],
    this.danger = false,
    this.verified = false,
    this.connector = const ConnectorPlacement(),
  });

  factory PortDefinition.fromJson(Map<String, dynamic> json) => PortDefinition(
    id: json['id'] as String,
    label: json['label'] as String,
    name: json['name'] as String,
    face: json['face'] as String,
    type: PortType.parse(json['type'] as String),
    description: json['description'] as String,
    patterns: (json['patterns'] as List).cast<String>(),
    pins: [
      for (final p in (json['pins'] as List? ?? const []))
        PinDefinition.fromJson(p as Map<String, dynamic>),
    ],
    danger: json['danger'] as bool? ?? false,
    verified: json['verified'] as bool? ?? false,
    connector: ConnectorPlacement.fromJson(
      json['connector'] as Map<String, dynamic>?,
    ),
  );

  final String id;
  final String label;
  final String name;
  final String face;
  final PortType type;
  final String description;
  final List<String> patterns;
  final List<PinDefinition> pins;
  final bool danger;

  /// False until the function has been checked against the official manual.
  final bool verified;
  final ConnectorPlacement connector;
}

class InstallStep {
  const InstallStep({
    required this.id,
    required this.title,
    required this.instruction,
    this.portId,
    this.pinId,
    this.warning,
  });

  factory InstallStep.fromJson(Map<String, dynamic> json) => InstallStep(
    id: json['id'] as String,
    title: json['title'] as String,
    instruction: json['instruction'] as String,
    portId: json['port'] as String?,
    pinId: json['pin'] as String?,
    warning: json['warning'] as String?,
  );

  final String id;
  final String title;
  final String instruction;
  final String? portId;
  final String? pinId;
  final String? warning;
}

class DeviceDefinition {
  const DeviceDefinition({
    required this.id,
    required this.brand,
    required this.name,
    required this.productCode,
    required this.description,
    required this.identifiers,
    required this.faces,
    required this.ports,
    required this.steps,
  });

  factory DeviceDefinition.fromJson(Map<String, dynamic> json) {
    final device = DeviceDefinition(
      id: json['id'] as String,
      brand: json['brand'] as String,
      name: json['name'] as String,
      productCode: json['productCode'] as String? ?? '',
      description: json['description'] as String? ?? '',
      identifiers: [
        for (final i in (json['identifiers'] as List? ?? const []))
          DeviceIdentifier.fromJson(i as Map<String, dynamic>),
      ],
      faces: [
        for (final f in json['faces'] as List)
          DeviceFace.fromJson(f as Map<String, dynamic>),
      ],
      ports: [
        for (final p in json['ports'] as List)
          PortDefinition.fromJson(p as Map<String, dynamic>),
      ],
      steps: [
        for (final s in (json['steps'] as List? ?? const []))
          InstallStep.fromJson(s as Map<String, dynamic>),
      ],
    );
    device._validate();
    return device;
  }

  final String id;
  final String brand;
  final String name;
  final String productCode;
  final String description;
  final List<DeviceIdentifier> identifiers;
  final List<DeviceFace> faces;
  final List<PortDefinition> ports;
  final List<InstallStep> steps;

  String get fullName => '$brand $name';

  PortDefinition? portById(String? id) {
    if (id == null) return null;
    for (final p in ports) {
      if (p.id == id) return p;
    }
    return null;
  }

  DeviceFace? faceById(String? id) {
    if (id == null) return null;
    for (final f in faces) {
      if (f.id == id) return f;
    }
    return null;
  }

  void _validate() {
    final faceIds = faces.map((f) => f.id).toSet();
    final portIds = <String>{};
    for (final p in ports) {
      if (!portIds.add(p.id)) {
        throw FormatException('Puerto duplicado: ${p.id}');
      }
      if (!faceIds.contains(p.face)) {
        throw FormatException('Cara desconocida "${p.face}" en ${p.id}');
      }
    }
    for (final s in steps) {
      final port = portById(s.portId);
      if (s.portId != null && port == null) {
        throw FormatException('Paso ${s.id}: puerto ${s.portId} no existe');
      }
      if (s.pinId != null && !port!.pins.any((pin) => pin.id == s.pinId)) {
        throw FormatException('Paso ${s.id}: pin ${s.pinId} no existe');
      }
    }
  }
}
