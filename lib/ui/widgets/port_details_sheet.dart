import 'package:flutter/material.dart';

import '../../models/device_definition.dart';
import '../port_style.dart';

Future<void> showPortDetails(
  BuildContext context,
  DeviceDefinition device,
  PortDefinition port, {
  String? ocrText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) =>
        PortDetails(device: device, port: port, ocrText: ocrText),
  );
}

class PortDetails extends StatelessWidget {
  const PortDetails({
    super.key,
    required this.device,
    required this.port,
    this.ocrText,
  });

  final DeviceDefinition device;
  final PortDefinition port;
  final String? ocrText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = portColor(port);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(portIcon(port)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(port.name, style: theme.textTheme.titleLarge),
                      Text(
                        'Etiqueta: ${port.label} · ${port.type.displayName}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(port.description),
            const SizedBox(height: 8),
            Text(
              'Ubicación: ${device.faceById(port.face)?.name ?? port.face}',
              style: theme.textTheme.bodySmall,
            ),
            if (port.pins.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Bornes', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pin in port.pins)
                    Chip(
                      label: Text(
                        pin.description == null
                            ? pin.label
                            : '${pin.label} · ${pin.description}',
                      ),
                    ),
                ],
              ),
            ],
            if (port.danger) ...[
              const SizedBox(height: 16),
              const _Banner(
                icon: Icons.warning_amber_rounded,
                color: Color(0xFFE53935),
                text: 'Tensión peligrosa. Trabaja siempre sin alimentación.',
              ),
            ],
            if (!port.verified) ...[
              const SizedBox(height: 12),
              const _Banner(
                icon: Icons.help_outline,
                color: Color(0xFFFFB300),
                text: 'Función pendiente de validar con el manual oficial de Koolnova.',
              ),
            ],
            if (ocrText != null) ...[
              const SizedBox(height: 12),
              Text(
                'Texto leído por OCR: "$ocrText"',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
