import 'dart:math' as math;

import 'package:bon_cad/core/vec2.dart';
import 'package:bon_cad/geometry/segment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('closest point on segment', () {
    const seg = Segment(Vec2(0, 0), Vec2(10, 0));
    final p = seg.closestPointOnSegment(const Vec2(5, 3));
    expect(p.x, closeTo(5, 1e-9));
    expect(p.y, closeTo(0, 1e-9));
  });

  test('orthogonal lock', () {
    final o = orthogonalLock(const Vec2(0, 0), const Vec2(10, 3));
    expect(o.y.abs(), lessThan(1e-9));
    expect(o.x, closeTo(math.sqrt(10 * 10 + 3 * 3), 1e-6));
  });

  test('angle lock 45 degrees', () {
    final nearH = angleLock(const Vec2(0, 0), const Vec2(10, 1), 45);
    expect(nearH.y.abs(), lessThan(1e-9));
    expect(nearH.x, closeTo(math.sqrt(101), 1e-6));

    final diag = angleLock(const Vec2(0, 0), const Vec2(10, 9), 45);
    expect(diag.x, closeTo(diag.y, 1e-6));
    expect(diag.length, closeTo(math.sqrt(10 * 10 + 9 * 9), 1e-6));
  });

  test('angle lock 15 degrees', () {
    final p = angleLock(const Vec2(0, 0), const Vec2(10, 0.5), 15);
    final deg = angleDegrees(const Vec2(0, 0), p);
    final nearest = (deg / 15).round() * 15.0;
    expect(deg, closeTo(nearest, 1e-6));
    expect(p.length, closeTo(math.sqrt(10 * 10 + 0.5 * 0.5), 1e-6));
  });

  test('point at length', () {
    final p = pointAtLength(const Vec2(0, 0), const Vec2(10, 0), 5);
    expect(p.x, closeTo(5, 1e-9));
    expect(p.y, closeTo(0, 1e-9));
  });
}
