import 'dart:math' as math;
import 'dart:ui' show Size, Offset, Rect;

import '../core/vec2.dart';

class CadViewport {
  CadViewport({
    this.pan = Vec2.zero,
    this.scale = 2.0,
    this.size = Size.zero,
  });

  /// World-space point shown at the center of the screen.
  Vec2 pan;

  /// Pixels per world inch.
  double scale;

  Size size;

  static const minScale = 0.15;
  static const maxScale = 40.0;

  Offset worldToScreen(Vec2 world) {
    return Offset(
      (world.x - pan.x) * scale + size.width / 2,
      // Y-up world → Y-down screen
      -(world.y - pan.y) * scale + size.height / 2,
    );
  }

  Vec2 screenToWorld(Offset screen) {
    return Vec2(
      (screen.dx - size.width / 2) / scale + pan.x,
      -((screen.dy - size.height / 2) / scale) + pan.y,
    );
  }

  double screenPixelsToWorld(double pixels) => pixels / scale;

  double worldToScreenLength(double inches) => inches * scale;

  void zoomAt(Offset screenFocus, double factor) {
    final before = screenToWorld(screenFocus);
    scale = (scale * factor).clamp(minScale, maxScale);
    final after = screenToWorld(screenFocus);
    pan = pan + (before - after);
  }

  void panByScreen(Offset delta) {
    pan = Vec2(
      pan.x - delta.dx / scale,
      pan.y + delta.dy / scale,
    );
  }

  void fitToBounds(Vec2 min, Vec2 max, {double padding = 48}) {
    final w = (max.x - min.x).abs();
    final h = (max.y - min.y).abs();
    if (w < 1e-6 && h < 1e-6) {
      pan = min;
      scale = 2.0;
      return;
    }
    final availW = math.max(1.0, size.width - padding * 2);
    final availH = math.max(1.0, size.height - padding * 2);
    final sx = availW / math.max(w, 1e-6);
    final sy = availH / math.max(h, 1e-6);
    scale = math.min(sx, sy).clamp(minScale, maxScale);
    pan = Vec2((min.x + max.x) / 2, (min.y + max.y) / 2);
  }

  Rect worldRectOnScreen(Vec2 min, Vec2 max) {
    final a = worldToScreen(min);
    final b = worldToScreen(max);
    return Rect.fromPoints(a, b);
  }
}
