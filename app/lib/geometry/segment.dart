import 'dart:math' as math;

import '../core/vec2.dart';

class Segment {
  const Segment(this.a, this.b);

  final Vec2 a;
  final Vec2 b;

  double get length => a.distanceTo(b);

  Vec2 get direction => (b - a).normalized();

  Vec2 pointAtDistance(double distance) {
    final len = length;
    if (len < 1e-12) return a;
    return a.lerp(b, (distance / len).clamp(0.0, 1.0));
  }

  /// Closest point on the infinite line through A-B.
  Vec2 closestPointOnLine(Vec2 p) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-18) return a;
    final t = (p - a).dot(ab) / lenSq;
    return a + ab * t;
  }

  /// Closest point on the finite segment.
  Vec2 closestPointOnSegment(Vec2 p) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-18) return a;
    final t = ((p - a).dot(ab) / lenSq).clamp(0.0, 1.0);
    return a + ab * t;
  }

  double distanceToPoint(Vec2 p) => p.distanceTo(closestPointOnSegment(p));

  /// Parameter t in [0,1] for closest point on segment.
  double parameterOf(Vec2 p) {
    final ab = b - a;
    final lenSq = ab.lengthSquared;
    if (lenSq < 1e-18) return 0;
    return ((p - a).dot(ab) / lenSq).clamp(0.0, 1.0);
  }

  double distanceAlongFromA(Vec2 p) => parameterOf(p) * length;
}

/// Constrain [to] so the vector from [from] is axis-aligned.
Vec2 orthogonalLock(Vec2 from, Vec2 to) => angleLock(from, to, 90);

/// Snap the vector from [from] to [to] onto the nearest multiple of [stepDegrees].
Vec2 angleLock(Vec2 from, Vec2 to, double stepDegrees) {
  final d = to - from;
  final len = d.length;
  if (len < 1e-12) return to;
  if (stepDegrees <= 0) return to;
  final ang = math.atan2(d.y, d.x);
  final step = stepDegrees * math.pi / 180;
  final snapped = (ang / step).round() * step;
  return from + Vec2(math.cos(snapped), math.sin(snapped)) * len;
}

/// Constrain length from [from] toward [to] direction.
Vec2 pointAtLength(Vec2 from, Vec2 toward, double length) {
  final dir = (toward - from).normalized();
  if (dir == Vec2.zero) return from + Vec2(length, 0);
  return from + dir * length;
}

double angleDegrees(Vec2 from, Vec2 to) {
  final d = to - from;
  return math.atan2(d.y, d.x) * 180 / math.pi;
}
