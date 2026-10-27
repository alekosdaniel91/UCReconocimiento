import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../models/device_definition.dart';
import '../../vision/detection_tracker.dart';
import '../../vision/mlkit_adapter.dart';
import '../../vision/port_matcher.dart';
import '../port_style.dart';
import '../widgets/port_details_sheet.dart';
import '../widgets/port_overlay.dart';
import '../widgets/step_panel.dart';

class LiveScanScreen extends StatefulWidget {
  const LiveScanScreen({super.key, required this.device, this.guided = false});

  final DeviceDefinition device;
  final bool guided;

  @override
  State<LiveScanScreen> createState() => _LiveScanScreenState();
}

class _LiveScanScreenState extends State<LiveScanScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final _tracker = DetectionTracker();
  late final PortMatcher _matcher = PortMatcher(widget.device);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  CameraController? _controller;
  CameraDescription? _camera;
  String? _error;
  bool _busy = false;
  List<PortDetection> _visible = const [];
  Size _resultSpace = const Size(1, 1);
  bool _mirrorX = false;
  double _zoom = 1;
  double _maxZoom = 1;
  bool _torch = false;
  int _stepIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _stopCamera();
    _recognizer.close();
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No se encontró ninguna cámara.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: CameraFrameInput.preferredFormat,
      );
      await controller.initialize();
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      final maxZoom = await controller.getMaxZoomLevel();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _camera = camera;
      setState(() {
        _controller = controller;
        _maxZoom = maxZoom.clamp(1, 8).toDouble();
        _zoom = 1;
        _torch = false;
        _error = null;
      });
      await controller.startImageStream(_onFrame);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = 'Error de cámara: ${e.description ?? e.code}');
      }
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _onFrame(CameraImage image) async {
    final controller = _controller;
    final camera = _camera;
    if (_busy || controller == null || camera == null) return;
    _busy = true;
    try {
      final frame = CameraFrameInput.fromCameraImage(
        image,
        camera,
        controller.value.lockedCaptureOrientation ??
            controller.value.deviceOrientation,
      );
      if (frame == null) return;
      final text = await _recognizer.processImage(frame.inputImage);
      final result = _matcher.match(ocrLinesFrom(text));
      final visible = _tracker.update(result, DateTime.now());
      if (!mounted) return;
      setState(() {
        _visible = visible;
        _resultSpace = frame.resultSpace;
        _mirrorX = frame.mirrorX;
      });
    } catch (e) {
      debugPrint('OCR error: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> _setZoom(double value) async {
    setState(() => _zoom = value);
    await _controller?.setZoomLevel(value);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_torch;
    await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
    setState(() => _torch = next);
  }

  InstallStep? get _step => widget.guided && widget.device.steps.isNotEmpty
      ? widget.device.steps[_stepIndex]
      : null;

  TargetStatus get _targetStatus {
    final port = widget.device.portById(_step?.portId);
    if (port == null) return TargetStatus.noTarget;
    if (_visible.any((d) => d.port.id == port.id)) return TargetStatus.visible;
    final face = _tracker.faceAt(DateTime.now());
    if (face != null && face != port.face) return TargetStatus.wrongFace;
    return TargetStatus.searching;
  }

  void _nextStep() {
    if (_stepIndex < widget.device.steps.length - 1) {
      setState(() => _stepIndex++);
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Instalación guiada completada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            Center(
              child: CameraPreview(
                controller,
                child: PortOverlay(
                  detections: _visible,
                  imageSize: _resultSpace,
                  mirrorX: _mirrorX,
                  targetPortId: _step?.portId,
                  targetPinId: _step?.pinId,
                  pulse: _pulse,
                  onPortTap: (d) => showPortDetails(
                    context,
                    widget.device,
                    d.port,
                    ocrText: d.rawText,
                  ),
                ),
              ),
            )
          else
            Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          SafeArea(child: _buildTopBar()),
          if (controller != null && _maxZoom > 1)
            Positioned(
              right: 4,
              top: 120,
              bottom: 280,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(
                  value: _zoom,
                  min: 1,
                  max: _maxZoom,
                  onChanged: _setZoom,
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: _step != null
                  ? StepPanel(
                      device: widget.device,
                      steps: widget.device.steps,
                      index: _stepIndex,
                      status: _targetStatus,
                      onPrevious: _stepIndex == 0
                          ? null
                          : () => setState(() => _stepIndex--),
                      onNext: _nextStep,
                    )
                  : _CoveragePanel(
                      device: widget.device,
                      seen: _tracker.everSeen,
                      visible: {for (final d in _visible) d.port.id},
                      onReset: () => setState(() {
                        _tracker.reset();
                        _visible = const [];
                      }),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final face = widget.device.faceById(_tracker.faceAt(DateTime.now()));
    final recognized = _tracker.identifiers.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Pill(
                  icon: recognized ? Icons.verified : Icons.search,
                  color: recognized ? Colors.greenAccent : Colors.white70,
                  text: recognized
                      ? widget.device.fullName
                      : 'Buscando la central…',
                ),
                if (face != null)
                  _Pill(
                    icon: Icons.view_in_ar,
                    color: Colors.cyanAccent,
                    text: face.name,
                  ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: _controller == null ? null : _toggleTorch,
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoveragePanel extends StatelessWidget {
  const _CoveragePanel({
    required this.device,
    required this.seen,
    required this.visible,
    required this.onReset,
  });

  final DeviceDefinition device;
  final Set<String> seen;
  final Set<String> visible;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Puertos identificados: ${seen.length}/${device.ports.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Reiniciar',
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, color: Colors.white70),
                ),
              ],
            ),
            const Text(
              'Toca un puerto resaltado para ver su función.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final port in device.ports)
                  _PortChip(
                    port: port,
                    state: visible.contains(port.id)
                        ? _ChipState.visible
                        : seen.contains(port.id)
                        ? _ChipState.seen
                        : _ChipState.pending,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChipState { pending, seen, visible }

class _PortChip extends StatelessWidget {
  const _PortChip({required this.port, required this.state});

  final PortDefinition port;
  final _ChipState state;

  @override
  Widget build(BuildContext context) {
    final color = portColor(port);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: switch (state) {
          _ChipState.visible => color,
          _ChipState.seen => color.withValues(alpha: 0.35),
          _ChipState.pending => Colors.transparent,
        },
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.8)),
      ),
      child: Text(
        port.label,
        style: TextStyle(
          color: state == _ChipState.pending ? Colors.white60 : Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}
