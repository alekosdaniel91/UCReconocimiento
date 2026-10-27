import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../manual/manual_builder.dart';
import '../../models/device_definition.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key, required this.device});

  final DeviceDefinition device;

  @override
  Widget build(BuildContext context) {
    final markdown = buildManualMarkdown(device);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrador del manual'),
        actions: [
          IconButton(
            tooltip: 'Copiar Markdown',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: markdown));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Manual copiado al portapapeles'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          markdown,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
        ),
      ),
    );
  }
}
