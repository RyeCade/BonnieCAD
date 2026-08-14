import 'dart:math' as math;

import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/commands.dart';
import '../domain/opening.dart';
import '../domain/wall.dart';
import '../geometry/segment.dart';
import 'editor_controller.dart';
import 'tool.dart';

class SelectTool extends EditorTool {
  String? _dragWallId;
  bool _dragEndpointA = false;
  bool _draggingEndpoint = false;
  bool _draggingBody = false;
  Vec2? _dragStartWorld;
  Vec2? _endpointOriginal;
  Vec2? _wallA0;
  Vec2? _wallB0;

  // Opening resize
  String? _dragOpeningId;
  bool _dragOpeningStart = false;
  double? _openOffset0;
  double? _openWidth0;

  // Furniture
  String? _dragFurnitureId;
  bool _draggingFurniture = false;
  bool _resizingFurniture = false;
  int? _resizeCorner; // 0 BL, 1 BR, 2 TR, 3 TL
  Vec2? _furnOrigin0;
  double? _furnW0;
  double? _furnD0;

  // Wall fixture
  String? _dragFixtureId;
  double? _fixtureOffset0;

  // Text label
  String? _dragTextId;
  Vec2? _textOrigin0;

  /// Fixed opposite endpoint while dragging a wall endpoint (for angle lock).
  Vec2? get endpointLockOrigin {
    if (!_draggingEndpoint || _dragWallId == null) return null;
    // Resolved lazily via controller document in canvas — store opposite on start.
    return _endpointLockOrigin;
  }

  Vec2? _endpointLockOrigin;

  @override
  ToolId get id => ToolId.select;

  @override
  String get name => 'Select';

  @override
  String get statusHint =>
      'Click to select. Drag grips to edit. Delete to remove. V';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void cancel(EditorController c) {
    _resetDrag(c);
  }

  void _resetDrag([EditorController? c]) {
    _dragWallId = null;
    _draggingEndpoint = false;
    _draggingBody = false;
    _dragStartWorld = null;
    _endpointOriginal = null;
    _wallA0 = null;
    _wallB0 = null;
    _dragOpeningId = null;
    _openOffset0 = null;
    _openWidth0 = null;
    _dragFurnitureId = null;
    _draggingFurniture = false;
    _resizingFurniture = false;
    _resizeCorner = null;
    _furnOrigin0 = null;
    _furnW0 = null;
    _furnD0 = null;
    _dragFixtureId = null;
    _fixtureOffset0 = null;
    _dragTextId = null;
    _textOrigin0 = null;
    _endpointLockOrigin = null;
    c?.measureLabel = null;
    c?.measureLabelAt = null;
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    final tol = c.snapToleranceWorld;

    // Opening grips on selected openings
    for (final id in c.selectedIds) {
      final o = c.document.openingById(id);
      if (o == null) continue;
      final w = c.document.wallById(o.wallId);
      if (w == null) continue;
      final start = w.pointAt(o.offset);
      final end = w.pointAt(o.offset + o.width);
      if (e.world.distanceTo(start) <= tol) {
        _dragOpeningId = o.id;
        _dragOpeningStart = true;
        _openOffset0 = o.offset;
        _openWidth0 = o.width;
        return;
      }
      if (e.world.distanceTo(end) <= tol) {
        _dragOpeningId = o.id;
        _dragOpeningStart = false;
        _openOffset0 = o.offset;
        _openWidth0 = o.width;
        return;
      }
    }

    // Furniture corner grips
    for (final id in c.selectedIds) {
      final f = c.document.furnitureById(id);
      if (f == null) continue;
      final corners = f.worldCorners();
      for (var i = 0; i < corners.length; i++) {
        if (e.world.distanceTo(corners[i]) <= tol) {
          _dragFurnitureId = f.id;
          _resizingFurniture = true;
          _resizeCorner = i;
          _furnOrigin0 = f.origin;
          _furnW0 = f.width;
          _furnD0 = f.depth;
          return;
        }
      }
    }

    // Wall endpoint grips
    for (final id in c.selectedIds) {
      final w = c.document.wallById(id);
      if (w == null) continue;
      if (e.world.distanceTo(w.a) <= tol) {
        _dragWallId = w.id;
        _dragEndpointA = true;
        _draggingEndpoint = true;
        _endpointOriginal = w.a;
        _endpointLockOrigin = w.b;
        return;
      }
      if (e.world.distanceTo(w.b) <= tol) {
        _dragWallId = w.id;
        _dragEndpointA = false;
        _draggingEndpoint = true;
        _endpointOriginal = w.b;
        _endpointLockOrigin = w.a;
        return;
      }
    }

    // Openings before walls so doors/windows are selectable in-place.
    for (final o in c.document.openings.reversed) {
      if (!c.document.isLayerVisible(o.layerId)) continue;
      final w = c.document.wallById(o.wallId);
      if (w == null) continue;
      if (!c.document.isLayerVisible(w.layerId)) continue;
      if (_hitOpening(w, o, e.world, tol)) {
        if (!e.shift) c.selectedIds.clear();
        c.selectedIds.add(o.id);
        c.notifyUi();
        return;
      }
    }

    // Wall fixtures before walls
    for (final fx in c.document.wallFixtures.reversed) {
      if (!c.document.isLayerVisible(fx.layerId)) continue;
      final w = c.document.wallById(fx.wallId);
      if (w == null) continue;
      final p = w.pointAt(fx.offset);
      if (e.world.distanceTo(p) <= tol * 1.5) {
        if (!e.shift) c.selectedIds.clear();
        c.selectedIds.add(fx.id);
        _dragFixtureId = fx.id;
        _fixtureOffset0 = fx.offset;
        _dragStartWorld = e.world;
        c.notifyUi();
        return;
      }
    }

    // Furniture hit
    for (final f in c.document.furniture.reversed) {
      if (!c.document.isLayerVisible(f.layerId)) continue;
      if (f.containsPoint(e.world, pad: tol * 0.25)) {
        if (!e.shift) c.selectedIds.clear();
        c.selectedIds.add(f.id);
        _dragFurnitureId = f.id;
        _draggingFurniture = true;
        _dragStartWorld = e.world;
        _furnOrigin0 = f.origin;
        c.notifyUi();
        return;
      }
    }

    final wall = c.snapEngine.hitTestWall(c.document, e.world, tol);
    if (wall != null) {
      if (!e.shift) c.selectedIds.clear();
      c.selectedIds.add(wall.id);
      _dragWallId = wall.id;
      _draggingBody = true;
      _dragStartWorld = e.world;
      _wallA0 = wall.a;
      _wallB0 = wall.b;
      c.notifyUi();
      return;
    }

    // Text labels (screen-space-ish hit via world tol from font)
    for (final t in c.document.texts.reversed) {
      if (!c.document.isLayerVisible(t.layerId)) continue;
      final hitR = math.max(tol, c.viewport.screenPixelsToWorld(t.fontSizePx));
      if (e.world.distanceTo(t.origin) <= hitR) {
        if (!e.shift) c.selectedIds.clear();
        c.selectedIds.add(t.id);
        _dragTextId = t.id;
        _draggingFurniture = false;
        _dragStartWorld = e.world;
        _textOrigin0 = t.origin;
        c.notifyUi();
        return;
      }
    }

    // Dimensions
    for (final d in c.document.dimensions) {
      final mid = d.p1.lerp(d.p2, 0.5);
      if (e.world.distanceTo(mid) <= tol * 2) {
        if (!e.shift) c.selectedIds.clear();
        c.selectedIds.add(d.id);
        c.notifyUi();
        return;
      }
    }

    if (!e.shift) {
      c.selectedIds.clear();
      c.notifyUi();
    }
  }

  bool _hitOpening(Wall wall, Opening opening, Vec2 world, double tol) {
    final along = Segment(wall.a, wall.b).distanceAlongFromA(world);
    final pad = math.max(tol, wall.thickness * 0.5);
    if (along < opening.offset - pad || along > opening.offset + opening.width + pad) {
      return false;
    }
    final start = wall.pointAt(opening.offset);
    final end = wall.pointAt(opening.offset + opening.width);
    final dist = Segment(start, end).distanceToPoint(world);
    final reach = math.max(tol, wall.thickness * 0.75 + 4);
    return dist <= reach;
  }

  @override
  void pointerMove(EditorController c, ToolPointerEvent e) {
    c.cursorWorld = e.point;
    c.snapPoint = e.snapped.point;

    if (_dragOpeningId != null &&
        _openOffset0 != null &&
        _openWidth0 != null) {
      final o = c.document.openingById(_dragOpeningId!);
      final w = o == null ? null : c.document.wallById(o.wallId);
      if (o != null && w != null) {
        final along = Segment(w.a, w.b).distanceAlongFromA(e.world);
        const minW = 12.0;
        if (_dragOpeningStart) {
          final end = _openOffset0! + _openWidth0!;
          var start = along.clamp(0.0, end - minW);
          o.offset = start;
          o.width = end - start;
        } else {
          final start = _openOffset0!;
          var end = along.clamp(start + minW, w.length);
          o.offset = start;
          o.width = end - start;
        }
        final label = Units.format(o.width, c.document.displayUnits);
        c.measureLabel = label;
        c.measureLabelAt = w.pointAt(o.centerOffset);
        c.statusMessage =
            '${o.type == OpeningType.door ? 'Door' : 'Window'} width $label';
        c.refresh();
      }
      return;
    }

    if (_resizingFurniture &&
        _dragFurnitureId != null &&
        _furnOrigin0 != null &&
        _furnW0 != null &&
        _furnD0 != null &&
        _resizeCorner != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        final cos = math.cos(f.rotationRad);
        final sin = math.sin(f.rotationRad);
        final dx = e.world.x - _furnOrigin0!.x;
        final dy = e.world.y - _furnOrigin0!.y;
        final lx = dx * cos + dy * sin;
        final ly = -dx * sin + dy * cos;
        // Opposite corner stays fixed in local space
        final opp = switch (_resizeCorner!) {
          0 => Vec2(_furnW0! / 2, _furnD0! / 2),
          1 => Vec2(-_furnW0! / 2, _furnD0! / 2),
          2 => Vec2(-_furnW0! / 2, -_furnD0! / 2),
          _ => Vec2(_furnW0! / 2, -_furnD0! / 2),
        };
        final newW = (lx - opp.x).abs().clamp(6.0, 600.0);
        final newD = (ly - opp.y).abs().clamp(6.0, 600.0);
        final signX = lx >= opp.x ? 1.0 : -1.0;
        final signY = ly >= opp.y ? 1.0 : -1.0;
        final localCenter = Vec2(
          opp.x + signX * newW / 2,
          opp.y + signY * newD / 2,
        );
        final wx = localCenter.x * cos - localCenter.y * sin;
        final wy = localCenter.x * sin + localCenter.y * cos;
        f.width = newW;
        f.depth = newD;
        f.origin = Vec2(_furnOrigin0!.x + wx, _furnOrigin0!.y + wy);
        c.refresh();
      }
      return;
    }

    if (_draggingFurniture &&
        _dragFurnitureId != null &&
        _dragStartWorld != null &&
        _furnOrigin0 != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        final delta = e.world - _dragStartWorld!;
        f.origin = _furnOrigin0! + delta;
        c.refresh();
      }
      return;
    }

    if (_dragFixtureId != null && _fixtureOffset0 != null) {
      final fx = c.document.wallFixtureById(_dragFixtureId!);
      final w = fx == null ? null : c.document.wallById(fx.wallId);
      if (fx != null && w != null) {
        fx.offset =
            Segment(w.a, w.b).distanceAlongFromA(e.world).clamp(0.0, w.length);
        c.refresh();
      }
      return;
    }

    if (_dragTextId != null &&
        _dragStartWorld != null &&
        _textOrigin0 != null) {
      final t = c.document.textById(_dragTextId!);
      if (t != null) {
        final delta = e.world - _dragStartWorld!;
        t.origin = _textOrigin0! + delta;
        c.refresh();
      }
      return;
    }

    if (_draggingEndpoint && _dragWallId != null) {
      final w = c.document.wallById(_dragWallId!);
      if (w != null) {
        if (_dragEndpointA) {
          w.a = e.point;
        } else {
          w.b = e.point;
        }
        c.refresh();
      }
      return;
    }

    if (_draggingBody &&
        _dragWallId != null &&
        _dragStartWorld != null &&
        _wallA0 != null &&
        _wallB0 != null) {
      final delta = e.world - _dragStartWorld!;
      final w = c.document.wallById(_dragWallId!);
      if (w != null) {
        w.a = _wallA0! + delta;
        w.b = _wallB0! + delta;
        c.refresh();
      }
    }
  }

  @override
  void pointerUp(EditorController c, ToolPointerEvent e) {
    if (_dragOpeningId != null &&
        _openOffset0 != null &&
        _openWidth0 != null) {
      final o = c.document.openingById(_dragOpeningId!);
      if (o != null) {
        final toOff = o.offset;
        final toW = o.width;
        o.offset = _openOffset0!;
        o.width = _openWidth0!;
        if ((toOff - _openOffset0!).abs() > 0.01 ||
            (toW - _openWidth0!).abs() > 0.01) {
          c.pushCommand(
            SetOpeningGeometryCommand(
              openingId: _dragOpeningId!,
              fromOffset: _openOffset0!,
              fromWidth: _openWidth0!,
              toOffset: toOff,
              toWidth: toW,
            ),
          );
        } else {
          c.refresh();
        }
      }
    } else if (_resizingFurniture &&
        _dragFurnitureId != null &&
        _furnW0 != null &&
        _furnD0 != null &&
        _furnOrigin0 != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        final toW = f.width;
        final toD = f.depth;
        final toOrigin = f.origin;
        f.width = _furnW0!;
        f.depth = _furnD0!;
        f.origin = _furnOrigin0!;
        if ((toW - _furnW0!).abs() > 0.01 || (toD - _furnD0!).abs() > 0.01) {
          // Apply size then origin via translate
          c.pushCommand(
            SetFurnitureSizeCommand(
              furnitureId: _dragFurnitureId!,
              fromWidth: _furnW0!,
              fromDepth: _furnD0!,
              toWidth: toW,
              toDepth: toD,
            ),
          );
          final delta = toOrigin - _furnOrigin0!;
          if (delta.length > 0.01) {
            c.pushCommand(
              TranslateFurnitureCommand(
                furnitureId: _dragFurnitureId!,
                delta: delta,
              ),
            );
          }
        } else {
          c.refresh();
        }
      }
    } else if (_draggingFurniture &&
        _dragFurnitureId != null &&
        _furnOrigin0 != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        final delta = f.origin - _furnOrigin0!;
        f.origin = _furnOrigin0!;
        if (delta.length > 0.01) {
          c.pushCommand(
            TranslateFurnitureCommand(
              furnitureId: _dragFurnitureId!,
              delta: delta,
            ),
          );
        } else {
          c.refresh();
        }
      }
    } else if (_dragFixtureId != null && _fixtureOffset0 != null) {
      final fx = c.document.wallFixtureById(_dragFixtureId!);
      if (fx != null) {
        final to = fx.offset;
        fx.offset = _fixtureOffset0!;
        if ((to - _fixtureOffset0!).abs() > 0.01) {
          c.pushCommand(
            MoveWallFixtureCommand(
              fixtureId: _dragFixtureId!,
              fromOffset: _fixtureOffset0!,
              toOffset: to,
            ),
          );
        } else {
          c.refresh();
        }
      }
    } else if (_dragTextId != null && _textOrigin0 != null) {
      final t = c.document.textById(_dragTextId!);
      if (t != null) {
        final to = t.origin;
        t.origin = _textOrigin0!;
        if (_textOrigin0!.distanceTo(to) > 0.01) {
          c.pushCommand(
            MoveTextLabelCommand(
              textId: _dragTextId!,
              from: _textOrigin0!,
              to: to,
            ),
          );
        } else {
          c.refresh();
        }
      }
    } else if (_draggingEndpoint &&
        _dragWallId != null &&
        _endpointOriginal != null) {
      final w = c.document.wallById(_dragWallId!);
      if (w != null) {
        final to = _dragEndpointA ? w.a : w.b;
        if (_dragEndpointA) {
          w.a = _endpointOriginal!;
        } else {
          w.b = _endpointOriginal!;
        }
        if (_endpointOriginal!.distanceTo(to) > 0.01) {
          c.pushCommand(
            MoveWallEndpointCommand(
              wallId: _dragWallId!,
              moveA: _dragEndpointA,
              from: _endpointOriginal!,
              to: to,
            ),
          );
        } else {
          c.refresh();
        }
      }
    } else if (_draggingBody &&
        _dragWallId != null &&
        _dragStartWorld != null &&
        _wallA0 != null &&
        _wallB0 != null) {
      final w = c.document.wallById(_dragWallId!);
      if (w != null) {
        final delta = w.a - _wallA0!;
        w.a = _wallA0!;
        w.b = _wallB0!;
        if (delta.length > 0.01) {
          c.pushCommand(
            TranslateWallCommand(wallId: _dragWallId!, delta: delta),
          );
        } else {
          c.refresh();
        }
      }
    }
    _resetDrag(c);
  }
}
