import 'port_matcher.dart';

class _Track {
  _Track(this.detection, this.lastSeen);

  PortDetection detection;
  DateTime lastSeen;
}

/// Keeps detections alive briefly between OCR frames and smooths their motion
/// so the overlay does not flicker while the camera moves.
class DetectionTracker {
  DetectionTracker({
    this.hold = const Duration(milliseconds: 800),
    this.smoothing = 0.6,
    this.faceHold = const Duration(seconds: 2),
  });

  final Duration hold;

  /// Weight given to the newest observation (1 = no smoothing).
  final double smoothing;
  final Duration faceHold;

  final _tracks = <String, _Track>{};
  final _everSeen = <String>{};
  final _identifiers = <String>{};
  String? _face;
  DateTime? _faceSeen;

  Set<String> get everSeen => Set.unmodifiable(_everSeen);

  Set<String> get identifiers => Set.unmodifiable(_identifiers);

  List<PortDetection> update(MatchResult result, DateTime now) {
    for (final d in result.detections) {
      final track = _tracks[d.port.id];
      if (track == null) {
        _tracks[d.port.id] = _Track(d, now);
      } else {
        track
          ..detection = track.detection.lerpTo(d, smoothing)
          ..lastSeen = now;
      }
      _everSeen.add(d.port.id);
    }
    _identifiers.addAll(result.identifiers);
    if (result.faceId != null) {
      _face = result.faceId;
      _faceSeen = now;
    }
    _tracks.removeWhere((_, t) => now.difference(t.lastSeen) > hold);
    return visible;
  }

  List<PortDetection> get visible => [
    for (final t in _tracks.values) t.detection,
  ];

  String? faceAt(DateTime now) {
    if (_faceSeen == null || now.difference(_faceSeen!) > faceHold) {
      return null;
    }
    return _face;
  }

  void reset() {
    _tracks.clear();
    _everSeen.clear();
    _identifiers.clear();
    _face = null;
    _faceSeen = null;
  }
}
