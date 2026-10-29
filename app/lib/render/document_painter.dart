import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/document.dart';
import '../domain/furniture.dart';
import '../domain/furniture_catalog.dart';
import '../domain/opening.dart';
import '../domain/wall.dart';
import '../domain/wall_fixture.dart';
import '../geometry/segment.dart';
import 'viewport.dart';

class DocumentPainter extends CustomPainter {
  DocumentPainter({
    required this.document,
    required this.viewport,
    required this.selectedIds,
    this.previewWall,
    this.previewDimension,
    this.snapPoint,
    this.cursorWorld,
    this.measureLabel,
    this.measureLabelAt,
  });

  final Document document;
  final CadViewport viewport;
  final Set<String> selectedIds;
  final Wall? previewWall;
  final (Vec2, Vec2)? previewDimension;
  final Vec2? snapPoint;
  final Vec2? cursorWorld;
  final String? measureLabel;
  final Vec2? measureLabelAt;

  static const _selectedColor = Color(0xFF0D47A1);

  @override
  void paint(Canvas canvas, Size size) {
    viewport.size = size;
    _paintBackground(canvas, size);
    _paintGrid(canvas, size);
    _paintWalls(canvas);
    _paintOpenings(canvas);
    _paintFurniture(canvas);
    _paintWallFixtures(canvas);
    _paintDimensions(canvas);
    _paintTexts(canvas);
    if (previewWall != null) {
      _paintWall(canvas, previewWall!, preview: true);
      _paintPreviewWallLength(canvas, previewWall!);
    }
    if (previewDimension != null) {
      _paintDimensionLine(
        canvas,
        previewDimension!.$1,
        previewDimension!.$2,
        12,
        selected: false,
        preview: true,
        colorValue: null,
        strokeWidth: null,
      );
    }
    if (measureLabel != null && measureLabelAt != null) {
      _paintMeasureLabel(canvas, measureLabel!, measureLabelAt!);
    }
    if (snapPoint != null) _paintSnap(canvas, snapPoint!);
  }

  void _paintBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFFF7F5F0),
    );
  }

  void _paintGrid(Canvas canvas, Size size) {
    final g = document.gridSize;
    if (g <= 0 || viewport.scale * g < 4) return;

    final topLeft = viewport.screenToWorld(Offset.zero);
    final bottomRight = viewport.screenToWorld(Offset(size.width, size.height));
    final minX = math.min(topLeft.x, bottomRight.x);
    final maxX = math.max(topLeft.x, bottomRight.x);
    final minY = math.min(topLeft.y, bottomRight.y);
    final maxY = math.max(topLeft.y, bottomRight.y);

    final startX = (minX / g).floor() * g;
    final startY = (minY / g).floor() * g;

    final minor = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1.25;

    final majorEvery = g >= 12 ? 1 : (12 / g).round().clamp(1, 20);

    for (var x = startX; x <= maxX + g; x += g) {
      final i = (x / g).round();
      final a = viewport.worldToScreen(Vec2(x, minY));
      final b = viewport.worldToScreen(Vec2(x, maxY));
      canvas.drawLine(a, b, i % majorEvery == 0 ? major : minor);
    }
    for (var y = startY; y <= maxY + g; y += g) {
      final i = (y / g).round();
      final a = viewport.worldToScreen(Vec2(minX, y));
      final b = viewport.worldToScreen(Vec2(maxX, y));
      canvas.drawLine(a, b, i % majorEvery == 0 ? major : minor);
    }

    final o = viewport.worldToScreen(Vec2.zero);
    final originPaint = Paint()
      ..color = const Color(0x55C62828)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(o.dx - 12, o.dy), Offset(o.dx + 12, o.dy), originPaint);
    canvas.drawLine(Offset(o.dx, o.dy - 12), Offset(o.dx, o.dy + 12), originPaint);
  }

  Color _resolveColor({
    required bool selected,
    required bool preview,
    required String layerId,
    int? colorValue,
    int fallback = 0xFF212121,
  }) {
    // Keep entity/layer color visible while selected (grips mark selection).
    // Only fall back to selection blue when no custom color is set.
    if (selected && colorValue == null) {
      final layer = document.layerById(layerId);
      if (layer?.colorValue == null) return _selectedColor;
    }
    if (colorValue != null) {
      final c = Color(colorValue);
      return preview ? c.withValues(alpha: 0.55) : c;
    }
    final layer = document.layerById(layerId);
    final base = Color(layer?.colorValue ?? fallback);
    return preview ? base.withValues(alpha: 0.55) : base;
  }

  void _paintWalls(Canvas canvas) {
    for (final wall in document.walls) {
      if (!document.isLayerVisible(wall.layerId)) continue;
      _paintWall(canvas, wall, preview: false);
    }
  }

  void _paintWall(Canvas canvas, Wall wall, {required bool preview}) {
    final selected = selectedIds.contains(wall.id);
    final color = _resolveColor(
      selected: selected,
      preview: preview,
      layerId: wall.layerId,
      colorValue: wall.colorValue,
    );

    final a = viewport.worldToScreen(wall.a);
    final b = viewport.worldToScreen(wall.b);
    final stroke = viewport.worldToScreenLength(wall.thickness).clamp(2.0, 80.0);

    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    canvas.drawLine(a, b, paint);

    final cl = Paint()
      ..color = Colors.white.withValues(alpha: preview ? 0.35 : 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(a, b, cl);

    if (selected && !preview) {
      _paintGrip(canvas, a);
      _paintGrip(canvas, b);
    }
  }

  void _paintGrip(Canvas canvas, Offset c) {
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 8, height: 8),
      Paint()..color = const Color(0xFF1565C0),
    );
    canvas.drawRect(
      Rect.fromCenter(center: c, width: 8, height: 8),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintOpenings(Canvas canvas) {
    for (final opening in document.openings) {
      if (!document.isLayerVisible(opening.layerId)) continue;
      final wall = document.wallById(opening.wallId);
      if (wall == null) continue;
      if (!document.isLayerVisible(wall.layerId)) continue;
      _paintOpening(canvas, wall, opening);
    }
  }

  void _paintOpening(Canvas canvas, Wall wall, Opening opening) {
    final selected = selectedIds.contains(opening.id);
    final dir = wall.direction;
    final normal = Vec2(-dir.y, dir.x);
    final start = wall.pointAt(opening.offset);
    final end = wall.pointAt(opening.offset + opening.width);

    final s = viewport.worldToScreen(start);
    final e = viewport.worldToScreen(end);
    final gapPaint = Paint()
      ..color = const Color(0xFFF7F5F0)
      ..strokeWidth =
          viewport.worldToScreenLength(wall.thickness + 1).clamp(3.0, 90.0)
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;
    canvas.drawLine(s, e, gapPaint);

    final color = _resolveColor(
      selected: selected,
      preview: false,
      layerId: opening.layerId,
      colorValue: opening.colorValue,
      fallback: 0xFF1565C0,
    );
    final sw = opening.strokeWidth ?? 2.0;

    if (opening.type == OpeningType.door) {
      final hingeLeft = switch (opening.swing) {
        DoorSwing.leftIn || DoorSwing.leftOut => true,
        DoorSwing.rightIn || DoorSwing.rightOut => false,
      };
      final swingSign = switch (opening.swing) {
        DoorSwing.leftIn || DoorSwing.rightIn => 1.0,
        DoorSwing.leftOut || DoorSwing.rightOut => -1.0,
      };
      final hinge = hingeLeft ? start : end;
      final latch = hingeLeft ? end : start;
      // Open leaf: perpendicular to wall from hinge; arc runs latch → leaf tip.
      final leafEnd = hinge + normal * (opening.width * swingSign);
      final c = viewport.worldToScreen(hinge);
      final r = viewport.worldToScreenLength(opening.width);
      final toLatch = latch - hinge;
      final toLeaf = leafEnd - hinge;
      // Screen angles (Y flipped to match canvas).
      final closedAngle = math.atan2(-toLatch.y, toLatch.x);
      final openAngle = math.atan2(-toLeaf.y, toLeaf.x);
      var sweep = openAngle - closedAngle;
      while (sweep > math.pi) {
        sweep -= 2 * math.pi;
      }
      while (sweep < -math.pi) {
        sweep += 2 * math.pi;
      }
      final leafPaint = Paint()
        ..color = color
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(c, viewport.worldToScreen(leafEnd), leafPaint);
      final arcPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, sw * 0.75);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        closedAngle,
        sweep,
        false,
        arcPaint,
      );
    } else {
      final n = normal * (wall.thickness * 0.35);
      final a1 = viewport.worldToScreen(start + n);
      final b1 = viewport.worldToScreen(end + n);
      final a2 = viewport.worldToScreen(start - n);
      final b2 = viewport.worldToScreen(end - n);
      final p = Paint()
        ..color = color
        ..strokeWidth = sw;
      canvas.drawLine(a1, b1, p);
      canvas.drawLine(a2, b2, p);
      canvas.drawLine(s, e, p..strokeWidth = math.max(1.0, sw * 0.5));
    }

    if (selected) {
      _paintGrip(canvas, s);
      _paintGrip(canvas, e);
      _paintGrip(canvas, viewport.worldToScreen(wall.pointAt(opening.centerOffset)));
    }
  }

  void _paintDimensions(Canvas canvas) {
    for (final dim in document.dimensions) {
      if (!document.isLayerVisible(dim.layerId)) continue;
      _paintDimensionLine(
        canvas,
        dim.p1,
        dim.p2,
        dim.offset,
        selected: selectedIds.contains(dim.id),
        preview: false,
        colorValue: dim.colorValue,
        strokeWidth: dim.strokeWidth,
      );
    }
  }

  void _paintTexts(Canvas canvas) {
    for (final t in document.texts) {
      if (!document.isLayerVisible(t.layerId)) continue;
      final selected = selectedIds.contains(t.id);
      final color = _resolveColor(
        selected: selected,
        preview: false,
        layerId: t.layerId,
        colorValue: t.colorValue,
        fallback: 0xFF6A1B9A,
      );
      final origin = viewport.worldToScreen(t.origin);
      final tp = TextPainter(
        text: TextSpan(
          text: t.text,
          style: TextStyle(
            color: color,
            fontSize: t.fontSizePx,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      // World Y-up vs screen Y-down: negate rotation for screen.
      canvas.rotate(-t.rotationRad);
      tp.paint(canvas, Offset(0, -tp.height));
      if (selected) {
        canvas.drawRect(
          Rect.fromLTWH(-2, -tp.height - 2, tp.width + 4, tp.height + 4),
          Paint()
            ..color = _selectedColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
      canvas.restore();
      if (selected) {
        _paintGrip(canvas, origin);
      }
    }
  }

  void _paintDimensionLine(
    Canvas canvas,
    Vec2 p1,
    Vec2 p2,
    double offsetInches, {
    required bool selected,
    required bool preview,
    int? colorValue,
    double? strokeWidth,
  }) {
    final seg = Segment(p1, p2);
    if (seg.length < 1e-6) return;
    final dir = seg.direction;
    final normal = Vec2(-dir.y, dir.x);
    final o = normal * offsetInches;
    final a = p1 + o;
    final b = p2 + o;

    final color = selected
        ? _selectedColor
        : preview
            ? const Color(0xFF66BB6A)
            : _resolveColor(
                selected: false,
                preview: false,
                layerId: 'dimensions',
                colorValue: colorValue,
                fallback: 0xFF2E7D32,
              );

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth ?? 1.25
      ..style = PaintingStyle.stroke;

    final sa = viewport.worldToScreen(p1);
    final sb = viewport.worldToScreen(p2);
    final da = viewport.worldToScreen(a);
    final db = viewport.worldToScreen(b);

    canvas.drawLine(sa, da, paint);
    canvas.drawLine(sb, db, paint);
    canvas.drawLine(da, db, paint);

    _tick(canvas, da, dir, color);
    _tick(canvas, db, dir, color);

    final label = Units.format(seg.length, document.displayUnits);
    final mid = Offset((da.dx + db.dx) / 2, (da.dy + db.dy) / 2);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          backgroundColor: const Color(0xEEF7F5F0),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, mid - Offset(tp.width / 2, tp.height / 2));
  }

  void _tick(Canvas canvas, Offset at, Vec2 dir, Color color) {
    final n = Offset(-dir.y, dir.x);
    final d = Offset(dir.x, -dir.y);
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.5;
    canvas.drawLine(at + n * 4 - d * 4, at - n * 4 + d * 4, p);
  }

  void _paintFurniture(Canvas canvas) {
    for (final f in document.furniture) {
      if (!document.isLayerVisible(f.layerId)) continue;
      _paintFurnitureItem(canvas, f);
    }
  }

  void _paintFurnitureItem(Canvas canvas, FurnitureItem f) {
    final selected = selectedIds.contains(f.id);
    final color = _resolveColor(
      selected: selected,
      preview: false,
      layerId: f.layerId,
      colorValue: f.colorValue,
      fallback: 0xFF5D4037,
    );
    final sw = f.strokeWidth ?? 1.5;
    final style = f.catalogEntry?.drawStyle ?? FurnitureDrawStyle.rect;

    final center = viewport.worldToScreen(f.origin);
    final wPx = viewport.worldToScreenLength(f.width);
    final dPx = viewport.worldToScreenLength(f.depth);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    // World Y-up → screen Y-down: negate rotation for screen
    canvas.rotate(-f.rotationRad);

    final rect = Rect.fromCenter(center: Offset.zero, width: wPx, height: dPx);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    switch (style) {
      case FurnitureDrawStyle.ellipse:
      case FurnitureDrawStyle.light:
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        if (style == FurnitureDrawStyle.light) {
          canvas.drawLine(
            Offset(-wPx * 0.35, 0),
            Offset(wPx * 0.35, 0),
            stroke,
          );
          canvas.drawLine(
            Offset(0, -dPx * 0.35),
            Offset(0, dPx * 0.35),
            stroke,
          );
        }
      case FurnitureDrawStyle.roundedRect:
      case FurnitureDrawStyle.table:
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(wPx * 0.08));
        canvas.drawRRect(rrect, fill);
        canvas.drawRRect(rrect, stroke);
      case FurnitureDrawStyle.toilet:
        final bowl = Rect.fromCenter(
          center: Offset(0, dPx * 0.12),
          width: wPx * 0.7,
          height: dPx * 0.55,
        );
        final tank = Rect.fromCenter(
          center: Offset(0, -dPx * 0.32),
          width: wPx * 0.85,
          height: dPx * 0.28,
        );
        canvas.drawOval(bowl, fill);
        canvas.drawOval(bowl, stroke);
        canvas.drawRect(tank, fill);
        canvas.drawRect(tank, stroke);
      case FurnitureDrawStyle.bathtub:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(wPx * 0.12)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(wPx * 0.12)),
          stroke,
        );
        final inner = rect.deflate(math.min(wPx, dPx) * 0.12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(inner, Radius.circular(wPx * 0.1)),
          stroke,
        );
      case FurnitureDrawStyle.shower:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        canvas.drawLine(rect.topLeft, rect.bottomRight, stroke);
      case FurnitureDrawStyle.sink:
        final sinkR = RRect.fromRectAndRadius(rect, const Radius.circular(4));
        canvas.drawRRect(sinkR, fill);
        canvas.drawRRect(sinkR, stroke);
        canvas.drawOval(rect.deflate(math.min(wPx, dPx) * 0.2), stroke);
      case FurnitureDrawStyle.stove:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        final r = math.min(wPx, dPx) * 0.12;
        for (final o in [
          Offset(-wPx * 0.22, -dPx * 0.18),
          Offset(wPx * 0.22, -dPx * 0.18),
          Offset(-wPx * 0.22, dPx * 0.18),
          Offset(wPx * 0.22, dPx * 0.18),
        ]) {
          canvas.drawCircle(o, r, stroke);
        }
      case FurnitureDrawStyle.fridge:
      case FurnitureDrawStyle.cabinet:
      case FurnitureDrawStyle.washer:
      case FurnitureDrawStyle.rect:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        if (style == FurnitureDrawStyle.fridge ||
            style == FurnitureDrawStyle.washer) {
          canvas.drawLine(
            Offset(-wPx / 2, 0),
            Offset(wPx / 2, 0),
            stroke,
          );
        }
      case FurnitureDrawStyle.bed:
        canvas.drawRect(rect, fill);
        canvas.drawRect(rect, stroke);
        final head = Rect.fromLTWH(-wPx / 2, -dPx / 2, wPx, dPx * 0.18);
        canvas.drawRect(head, stroke);
      case FurnitureDrawStyle.sofa:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          stroke,
        );
        canvas.drawLine(
          Offset(-wPx / 2, -dPx * 0.25),
          Offset(wPx / 2, -dPx * 0.25),
          stroke,
        );
      case FurnitureDrawStyle.chair:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          stroke,
        );
      case FurnitureDrawStyle.outlet:
      case FurnitureDrawStyle.switchFixture:
        canvas.drawRect(rect, stroke);
    }

    canvas.restore();

    if (selected) {
      for (final corner in f.worldCorners()) {
        _paintGrip(canvas, viewport.worldToScreen(corner));
      }
    }
  }

  void _paintWallFixtures(Canvas canvas) {
    for (final fx in document.wallFixtures) {
      if (!document.isLayerVisible(fx.layerId)) continue;
      final wall = document.wallById(fx.wallId);
      if (wall == null) continue;
      _paintWallFixture(canvas, wall, fx);
    }
  }

  void _paintWallFixture(Canvas canvas, Wall wall, WallFixture fx) {
    final selected = selectedIds.contains(fx.id);
    final color = _resolveColor(
      selected: selected,
      preview: false,
      layerId: fx.layerId,
      colorValue: fx.colorValue,
      fallback: 0xFFF9A825,
    );
    // World size in inches (base × scale); drawn in real world units so ¼′ snaps show.
    final baseIn = switch (fx.type) {
      WallFixtureType.light => 6.0,
      _ => 4.0,
    };
    final sizeIn = (baseIn * fx.scale.clamp(0.25, 8.0)).clamp(3.0, 48.0);
    final half = sizeIn / 2;
    final rPx = viewport.worldToScreenLength(half).clamp(2.0, 400.0);
    final sw = (fx.strokeWidth ?? 1.75).clamp(1.0, 6.0);
    final dir = wall.direction;
    final normal = Vec2(-dir.y, dir.x);
    final p = wall.pointAt(fx.offset);
    final c = viewport.worldToScreen(p);
    final nScreen = Offset(
      viewport.worldToScreenLength(normal.x),
      -viewport.worldToScreenLength(normal.y),
    );
    final tScreen = Offset(
      viewport.worldToScreenLength(dir.x),
      -viewport.worldToScreenLength(dir.y),
    );
    Offset unit(Offset o) {
      final len = o.distance;
      if (len < 1e-6) return Offset.zero;
      return o / len;
    }

    final n = unit(nScreen) * rPx;
    final t = unit(tScreen) * rPx;
    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke;

    switch (fx.type) {
      case WallFixtureType.outlet:
        canvas.drawLine(c - t * 0.6 + n * 0.3, c - t * 0.6 - n * 0.3, paint);
        canvas.drawLine(c + t * 0.6 + n * 0.3, c + t * 0.6 - n * 0.3, paint);
        canvas.drawLine(c - t, c + t, paint);
      case WallFixtureType.switchFixture:
        canvas.drawCircle(c, rPx * 0.55, paint);
        canvas.drawLine(c, c + n * 1.1, paint);
      case WallFixtureType.light:
        canvas.drawCircle(c, rPx * 0.65, paint);
        canvas.drawLine(c - t, c + t, paint);
        canvas.drawLine(c - n, c + n, paint);
    }

    if (selected) _paintGrip(canvas, c);
  }

  void _paintPreviewWallLength(Canvas canvas, Wall wall) {
    final len = wall.length;
    if (len < 0.5) return;
    final label = Units.format(len, document.displayUnits);
    _paintMeasureLabel(canvas, label, wall.b);
  }

  void _paintMeasureLabel(Canvas canvas, String label, Vec2 at) {
    final screen = viewport.worldToScreen(at);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1565C0),
          fontSize: 13,
          fontWeight: FontWeight.w700,
          backgroundColor: Color(0xEEF7F5F0),
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(screen.dx - tp.width / 2, screen.dy - tp.height - 14),
    );
  }

  void _paintSnap(Canvas canvas, Vec2 world) {
    final c = viewport.worldToScreen(world);
    final paint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(c, 6, paint);
    canvas.drawLine(Offset(c.dx - 8, c.dy), Offset(c.dx + 8, c.dy), paint);
    canvas.drawLine(Offset(c.dx, c.dy - 8), Offset(c.dx, c.dy + 8), paint);
  }

  @override
  bool shouldRepaint(covariant DocumentPainter oldDelegate) {
    // Document/viewport are mutated in place; canvas rebuilds only when
    // canvasListenable fires, so always repaint on a new delegate.
    return true;
  }
}
