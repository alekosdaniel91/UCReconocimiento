import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/device_definition.dart';
import '../../vision/mlkit_adapter.dart';
import '../../vision/ocr_models.dart';
import '../../vision/port_matcher.dart';
import '../port_style.dart';
import '../widgets/port_details_sheet.dart';
import '../widgets/port_overlay.dart';

/// Runs the same recognition pipeline on a still photo, which makes it easy
/// to tune the label patterns against reference pictures.
class PhotoScanScreen extends StatefulWidget {
  const PhotoScanScreen({super.key, required this.device});

  final DeviceDefinition device;

  @override
  State<PhotoScanScreen> createState() => _PhotoScanScreenState();
}

class _PhotoScanScreenState extends State<PhotoScanScreen> {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _picker = ImagePicker();
  late final PortMatcher _matcher = PortMatcher(widget.device);

  Uint8List? _bytes;
  Size? _imageSize;
  List<OcrLine> _lines = const [];
  MatchResult? _result;
  bool _loading = false;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      final bytes = await file.readAsBytes();
      final decoded = await _decodeSize(bytes);
      final text = await _recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );
      final lines = ocrLinesFrom(text);
      setState(() {
        _bytes = bytes;
        _imageSize = decoded;
        _lines = lines;
        _result = _matcher.match(lines);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo analizar la imagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Size> _decodeSize(Uint8List bytes) async {
    final image = await decodeImageFromList(bytes);
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Analizar foto')),
      floatingActionButton: _bytes == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _loading ? null : () => _showSourcePicker(context),
              icon: const Icon(Icons.add_a_photo),
              label: const Text('Otra foto'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _bytes == null
          ? _EmptyState(onPick: _pick)
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                _buildImage(),
                if (result != null) ..._buildResults(result),
              ],
            ),
    );
  }

  Widget _buildImage() {
    final size = _imageSize!;
    return InteractiveViewer(
      maxScale: 6,
      child: AspectRatio(
        aspectRatio: size.width / size.height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_bytes!, fit: BoxFit.fill),
            PortOverlay(
              detections: _result?.detections ?? const [],
              imageSize: size,
              onPortTap: (d) => showPortDetails(
                context,
                widget.device,
                d.port,
                ocrText: d.rawText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResults(MatchResult result) {
    final theme = Theme.of(context);
    final found = {for (final d in result.detections) d.port.id: d};
    final face = widget.device.faceById(result.faceId);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '${found.length} de ${widget.device.ports.length} puertos identificados',
          style: theme.textTheme.titleMedium,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text(
          [
            if (face != null) 'Cara detectada: ${face.name}',
            if (result.identifiers.isNotEmpty)
              'Identificadores: ${result.identifiers.join(', ')}',
          ].join('\n'),
          style: theme.textTheme.bodySmall,
        ),
      ),
      for (final port in widget.device.ports)
        ListTile(
          dense: true,
          leading: Icon(
            found.containsKey(port.id)
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            color: found.containsKey(port.id)
                ? portColor(port)
                : theme.disabledColor,
          ),
          title: Text('${port.label} · ${port.name}'),
          subtitle: found[port.id] == null
              ? null
              : Text('OCR: "${found[port.id]!.rawText}"'),
          onTap: () => showPortDetails(
            context,
            widget.device,
            port,
            ocrText: found[port.id]?.rawText,
          ),
        ),
      ExpansionTile(
        title: Text('Texto OCR en bruto (${_lines.length} líneas)'),
        children: [
          for (final line in _lines)
            ListTile(
              dense: true,
              title: Text(line.text),
              subtitle: Text(line.elements.map((e) => '[${e.text}]').join(' ')),
            ),
        ],
      ),
    ];
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Hacer foto'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPick});

  final ValueChanged<ImageSource> onPick;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_search, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Haz o elige una foto de un lateral de la central con las etiquetas legibles.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => onPick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Hacer foto'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onPick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Elegir de la galería'),
            ),
          ],
        ),
      ),
    );
  }
}
