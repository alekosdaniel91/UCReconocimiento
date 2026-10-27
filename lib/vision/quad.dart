import 'dart:math' as math;
import 'dart:ui';

/// Four corners in text-relative order (top-left, top-right, bottom-right,
/// bottom-left), so "down" follows the text even when the unit is rotated.
class Quad {
  const Quad(this.tl, this.tr, this.br, this.bl);

  factory Quad.fromRect(Rect r) =>
      Quad(r.topLeft, r.topRight, r.bottomRight, r.bottomLeft);

  factory Quad.fromPoints(List<Offset> points) {
    if (points.length != 4) {
      throw ArgumentError('Se esperaban 4 esquinas, hay ${points.length}');
    }
    return Quad(points[0], points[1], points[2], points[3]);
  }

  /// Quad covering a run of words on the same line, from [first] to [last].
  factory Quad.span(Quad first, Quad last) =>
      Quad(first.tl, last.tr, last.br, first.bl);

  final Offset tl;
  final Offset tr;
  final Offset br;
  final Offset bl;

  List<Offset> get points => [tl, tr, br, bl];

  Offset get center => (tl + tr + br + bl) / 4;

  double get height => ((bl - tl).distance + (br - tr).distance) / 2;

  double get width => ((tr - tl).distance + (br - bl).distance) / 2;

  Offset get down {
    final v = ((bl - tl) + (br - tr)) / 2;
    final d = v.distance;
    return d == 0 ? const Offset(0, 1) : v / d;
  }

  Rect get bounds {
    final xs = points.map((p) => p.dx);
    final ys = points.map((p) => p.dy);
    return Rect.fromLTRB(
      xs.reduce(math.min),
      ys.reduce(math.min),
      xs.reduce(math.max),
      ys.reduce(math.max),
    );
  }

  /// Region below this quad (in text orientation), [gap] and [depth] being
  /// multiples of this quad's height.
  Quad below({required double gap, required double depth}) {
    final h = height;
    final start = down * (gap * h);
    final end = down * ((gap + depth) * h);
    return Quad(bl + start, br + start, br + end, bl + end);
  }

  Quad map(Offset Function(Offset) f) => Quad(f(tl), f(tr), f(br), f(bl));

  Quad lerpTo(Quad other, double t) => Quad(
    Offset.lerp(tl, other.tl, t)!,
    Offset.lerp(tr, other.tr, t)!,
    Offset.lerp(br, other.br, t)!,
    Offset.lerp(bl, other.bl, t)!,
  );

  bool contains(Offset p) => (Path()..addPolygon(points, true)).contains(p);

  Path toPath() => Path()..addPolygon(points, true);

  @override
  String toString() => 'Quad($tl, $tr, $br, $bl)';
}
