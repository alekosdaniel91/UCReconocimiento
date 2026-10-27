import 'package:flutter/material.dart';

import '../models/device_definition.dart';

Color portColor(PortDefinition port) {
  if (port.danger) return const Color(0xFFE53935);
  return switch (port.type) {
    PortType.power => const Color(0xFFE53935),
    PortType.communication => const Color(0xFF00C853),
    PortType.input => const Color(0xFFFFB300),
    PortType.output => const Color(0xFF2979FF),
    PortType.auxiliary => const Color(0xFFAA00FF),
    PortType.indicator => const Color(0xFFB0BEC5),
  };
}

IconData portIcon(PortDefinition port) => switch (port.type) {
  PortType.power => Icons.bolt,
  PortType.communication => Icons.settings_ethernet,
  PortType.input => Icons.input,
  PortType.output => Icons.output,
  PortType.auxiliary => Icons.extension,
  PortType.indicator => Icons.lightbulb_outline,
};
