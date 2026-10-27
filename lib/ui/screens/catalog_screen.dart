import 'package:flutter/material.dart';

import '../../models/device_definition.dart';
import '../port_style.dart';
import '../widgets/port_details_sheet.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.device});

  final DeviceDefinition device;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo de puertos')),
      body: ListView(
        children: [
          for (final face in device.faces) ...[
            ListTile(
              title: Text(
                face.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              subtitle: Text(face.hint),
            ),
            for (final port in device.ports.where((p) => p.face == face.id))
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: portColor(port),
                  foregroundColor: Colors.white,
                  child: Icon(portIcon(port), size: 20),
                ),
                title: Text('${port.label} · ${port.name}'),
                subtitle: Text(
                  port.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: port.verified
                    ? null
                    : const Tooltip(
                        message: 'Pendiente de validar',
                        child: Icon(Icons.help_outline, color: Colors.amber),
                      ),
                onTap: () => showPortDetails(context, device, port),
              ),
            const Divider(),
          ],
        ],
      ),
    );
  }
}
