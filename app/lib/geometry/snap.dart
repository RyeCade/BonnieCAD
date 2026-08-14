import '../core/vec2.dart';
import '../domain/document.dart';
import '../domain/wall.dart';
import 'segment.dart';

enum SnapKind { grid, endpoint, midpoint, nearestOnWall, none }

enum AngleLockMode { free, ortho, deg45, deg15 }

class SnapResult {
  const SnapResult({
    required this.point,
    required this.kind,
    this.wallId,
  });

  final Vec2 point;
  final SnapKind kind;
  final String? wallId;
}

class SnapEngine {
  SnapEngine({
    this.gridEnabled = true,
    this.endpointEnabled = true,
    this.midpointEnabled = true,
    this.nearestWallEnabled = true,
    this.angleLockMode = AngleLockMode.ortho,
  });

  bool gridEnabled;
  bool endpointEnabled;
  bool midpointEnabled;
  bool nearestWallEnabled;
  AngleLockMode angleLockMode;

  double? get lockStepDegrees => switch (angleLockMode) {
        AngleLockMode.free => null,
        AngleLockMode.ortho => 90,
        AngleLockMode.deg45 => 45,
        AngleLockMode.deg15 => 15,
      };

  /// [toleranceWorld] is snap radius in world inches.
  SnapResult snap({
    required Document doc,
    required Vec2 raw,
    required double toleranceWorld,
    Vec2? lockOrigin,
    String? ignoreWallId,
  }) {
    var point = raw;
    final step = lockStepDegrees;
    if (step != null && lockOrigin != null) {
      point = angleLock(lockOrigin, point, step);
    }

    SnapResult? best;
    var bestDist = toleranceWorld;

    void consider(Vec2 candidate, SnapKind kind, {String? wallId}) {
      final d = point.distanceTo(candidate);
      if (d <= bestDist) {
        bestDist = d;
        best = SnapResult(point: candidate, kind: kind, wallId: wallId);
      }
    }

    if (endpointEnabled || midpointEnabled || nearestWallEnabled) {
      for (final wall in doc.walls) {
        if (wall.id == ignoreWallId) continue;
        if (!doc.isLayerVisible(wall.layerId)) continue;
        if (endpointEnabled) {
          consider(wall.a, SnapKind.endpoint, wallId: wall.id);
          consider(wall.b, SnapKind.endpoint, wallId: wall.id);
        }
        if (midpointEnabled) {
          consider(wall.midpoint, SnapKind.midpoint, wallId: wall.id);
        }
        if (nearestWallEnabled) {
          final seg = Segment(wall.a, wall.b);
          final closest = seg.closestPointOnSegment(point);
          consider(closest, SnapKind.nearestOnWall, wallId: wall.id);
        }
      }
    }

    if (best != null) return best!;

    if (gridEnabled && doc.gridSize > 0) {
      final g = doc.gridSize;
      final gx = (point.x / g).round() * g;
      final gy = (point.y / g).round() * g;
      final gridPt = Vec2(gx, gy);
      if (point.distanceTo(gridPt) <= toleranceWorld) {
        return SnapResult(point: gridPt, kind: SnapKind.grid);
      }
      return SnapResult(point: gridPt, kind: SnapKind.grid);
    }

    return SnapResult(point: point, kind: SnapKind.none);
  }

  /// Find wall under point within tolerance.
  Wall? hitTestWall(Document doc, Vec2 world, double toleranceWorld) {
    Wall? best;
    var bestDist = toleranceWorld;
    for (final wall in doc.walls) {
      if (!doc.isLayerVisible(wall.layerId)) continue;
      final half = wall.thickness / 2;
      final d = Segment(wall.a, wall.b).distanceToPoint(world);
      final limit = mathMax(toleranceWorld, half + 2);
      if (d <= limit && d <= bestDist) {
        bestDist = d;
        best = wall;
      }
    }
    return best;
  }
}

double mathMax(double a, double b) => a > b ? a : b;
