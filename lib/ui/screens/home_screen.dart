import 'package:flutter/material.dart';

import '../../data/device_repository.dart';
import '../../models/device_definition.dart';
import 'catalog_screen.dart';
import 'live_scan_screen.dart';
import 'manual_screen.dart';
import 'photo_scan_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.repository});

  final DeviceRepository? repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<List<DeviceDefinition>> _devices =
      (widget.repository ?? DeviceRepository()).loadAll();
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UC Reconocimiento')),
      body: FutureBuilder<List<DeviceDefinition>>(
        future: _devices,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error cargando equipos: ${snapshot.error}'),
              ),
            );
          }
          final devices = snapshot.data;
          if (devices == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final device = devices[_selected];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (devices.length > 1)
                DropdownButton<int>(
                  value: _selected,
                  isExpanded: true,
                  items: [
                    for (var i = 0; i < devices.length; i++)
                      DropdownMenuItem(
                        value: i,
                        child: Text(devices[i].fullName),
                      ),
                  ],
                  onChanged: (i) => setState(() => _selected = i ?? 0),
                ),
              _DeviceCard(device: device),
              const SizedBox(height: 16),
              _Action(
                icon: Icons.view_in_ar,
                title: 'Identificar puertos',
                subtitle: 'Cámara en vivo: resalta cada entrada y salida sobre la unidad.',
                primary: true,
                onTap: () => _open(LiveScanScreen(device: device)),
              ),
              _Action(
                icon: Icons.checklist,
                title: 'Instalación guiada',
                subtitle:
                    'Paso a paso con el puerto objetivo señalado en la cámara.',
                onTap: () =>
                    _open(LiveScanScreen(device: device, guided: true)),
              ),
              _Action(
                icon: Icons.image_search,
                title: 'Analizar foto',
                subtitle:
                    'Prueba el reconocimiento con una foto y revisa el OCR.',
                onTap: () => _open(PhotoScanScreen(device: device)),
              ),
              _Action(
                icon: Icons.list_alt,
                title: 'Catálogo de puertos',
                subtitle:
                    '${device.ports.length} puertos definidos en ${device.faces.length} laterales.',
                onTap: () => _open(CatalogScreen(device: device)),
              ),
              _Action(
                icon: Icons.menu_book,
                title: 'Borrador del manual',
                subtitle: 'Genera el manual de instalación en Markdown.',
                onTap: () => _open(ManualScreen(device: device)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _open(Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device});

  final DeviceDefinition device;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.brand.toUpperCase(), style: theme.textTheme.labelLarge),
            Text(device.name, style: theme.textTheme.headlineSmall),
            if (device.productCode.isNotEmpty)
              Text(
                'Cód. ${device.productCode}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Text(device.description),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: primary ? scheme.primaryContainer : null,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
