import 'package:flutter/material.dart';

import '../../models/device_definition.dart';

enum TargetStatus { noTarget, visible, wrongFace, searching }

class StepPanel extends StatelessWidget {
  const StepPanel({
    super.key,
    required this.device,
    required this.steps,
    required this.index,
    required this.status,
    required this.onPrevious,
    required this.onNext,
  });

  final DeviceDefinition device;
  final List<InstallStep> steps;
  final int index;
  final TargetStatus status;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = steps[index];
    final port = device.portById(step.portId);
    final face = device.faceById(port?.face);

    final (statusIcon, statusColor, statusText) = switch (status) {
      TargetStatus.noTarget => (
        Icons.info_outline,
        Colors.white70,
        'Paso sin puerto asociado',
      ),
      TargetStatus.visible => (
        Icons.check_circle,
        Colors.greenAccent,
        '${port!.label} localizado',
      ),
      TargetStatus.wrongFace => (
        Icons.threesixty,
        Colors.orangeAccent,
        'Gira la unidad: ${face?.hint ?? ''}',
      ),
      TargetStatus.searching => (
        Icons.search,
        Colors.white70,
        'Buscando "${port!.label}"… acerca la cámara a la etiqueta',
      ),
    };

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Paso ${index + 1}/${steps.length}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (index + 1) / steps.length,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              step.title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(step.instruction, style: const TextStyle(color: Colors.white)),
            if (step.warning != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      step.warning!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Anterior'),
                ),
                FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(
                    index == steps.length - 1 ? 'Finalizar' : 'Hecho',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
