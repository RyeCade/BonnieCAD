import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/commands.dart';
import '../domain/furniture.dart';
import '../domain/opening.dart';
import '../domain/wall.dart';
import '../domain/wall_fixture.dart';
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

  // Opening resize / slide
  String? _dragOpeningId;
  bool _dragOpeningStart = false;
  bool _slidingOpening = false;
  double? _openOffset0;
  double? _openWidth0;
  /// Distance from opening start to grab point; used so slide follows the pointer.
  double? _openGrabAlong0;

  // Furniture
  String? _dragFurnitureId;
  bool _draggingFurniture = false;
  bool _resizingFurniture = false;
  int? _resizeCorner; // 0 BL, 1 BR, 2 TR, 3 TL
  Vec2? _furnOrigin0;
  double? _furnW0;
  double? _furnD0;
  Vec2? _lastResizeWorld;
  /// After typing a size, ignore further mouse moves until pointer up.
  bool _sizeLocked = false;
  /// Last furniture axis: true = width (local X), false = depth (local Y).
  bool? _lastAxisWidth;
  /// Locked for this drag after clear screen-space motion.
  bool? _lockedAxisWidth;
  /// Screen position at grip pointer-down (axis lock uses screen delta).
  Offset? _resizeScreen0;
  /// Furniture rotation at resize start.
  double? _furnRot0;

  // Wall fixture — size snaps every 1/4 ft (3") while resizing
  static const fixtureSizeSnapInches = 3.0;
  String? _dragFixtureId;
  double? _fixtureOffset0;
  double? _fixtureScale0;
  bool _resizingFixture = false;

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
      'Click to select. Drag grips to edit; type size + Enter. Delete to remove. V';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void cancel(EditorController c) {
    _resetDrag(c);
  }

  bool acceptsLengthEntry(EditorController c) {
    if (_draggingEndpoint ||
        _resizingFurniture ||
        _draggingFurniture ||
        (_dragOpeningId != null &&
            !_slidingOpening &&
            _openOffset0 != null &&
            _openWidth0 != null)) {
      return true;
    }
    if (c.selectedIds.length != 1) return false;
    final id = c.selectedIds.first;
    return c.document.furnitureById(id) != null;
  }

  /// Keep status/entry text in sync while typing without moving the pointer.
  void refreshLengthEntryStatus(EditorController c) {
    if (!acceptsLengthEntry(c)) return;
    final buf = c.lengthBuffer.isEmpty ? '' : '  entry: ${c.lengthBuffer}';
    if (_draggingEndpoint && _dragWallId != null) {
      final w = c.document.wallById(_dragWallId!);
      if (w != null) {
        final label = Units.format(w.length, c.document.displayUnits);
        c.statusMessage = 'Wall length $label$buf';
      }
      return;
    }
    if ((_resizingFurniture || _draggingFurniture) &&
        _dragFurnitureId != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        final wLabel = Units.format(f.width, c.document.displayUnits);
        final dLabel = Units.format(f.depth, c.document.displayUnits);
        c.statusMessage = 'Size $wLabel × $dLabel$buf';
      }
      return;
    }
    if (_dragOpeningId != null) {
      final o = c.document.openingById(_dragOpeningId!);
      if (o != null) {
        final label = Units.format(o.width, c.document.displayUnits);
        c.statusMessage =
            '${o.type == OpeningType.door ? 'Door' : 'Window'} width $label$buf';
      }
      return;
    }
    if (c.selectedIds.length == 1) {
      final id = c.selectedIds.first;
      final f = c.document.furnitureById(id);
      if (f != null) {
        final wLabel = Units.format(f.width, c.document.displayUnits);
        final dLabel = Units.format(f.depth, c.document.displayUnits);
        c.statusMessage = 'Size $wLabel × $dLabel$buf';
      }
    }
  }

  /// Default symbol size (inches) at scale 1.0.
  static double fixtureBaseInches(WallFixtureType type) => switch (type) {
        WallFixtureType.light => 6.0,
        _ => 4.0,
      };

  static double fixtureWorldSize(WallFixture fx) =>
      (fixtureBaseInches(fx.type) * fx.scale).clamp(3.0, 48.0);

  /// Snap sticker world size to every 1/4 foot (3").
  static double snapFixtureSize(double inches) {
    final stepped =
        (inches / fixtureSizeSnapInches).round() * fixtureSizeSnapInches;
    return stepped.clamp(fixtureSizeSnapInches, 48.0);
  }

  static double scaleFromWorldSize(WallFixtureType type, double inches) {
    final base = fixtureBaseInches(type);
    final snapped = snapFixtureSize(inches);
    return (snapped / base).clamp(0.25, 12.0);
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
    _slidingOpening = false;
    _openOffset0 = null;
    _openWidth0 = null;
    _openGrabAlong0 = null;
    _dragFurnitureId = null;
    _draggingFurniture = false;
    _resizingFurniture = false;
    _resizeCorner = null;
    _furnOrigin0 = null;
    _furnW0 = null;
    _furnD0 = null;
    _lastResizeWorld = null;
    _sizeLocked = false;
    _lastAxisWidth = null;
    _lockedAxisWidth = null;
    _resizeScreen0 = null;
    _furnRot0 = null;
    _dragFixtureId = null;
    _fixtureOffset0 = null;
    _fixtureScale0 = null;
    _resizingFixture = false;
    _dragTextId = null;
    _textOrigin0 = null;
    _endpointLockOrigin = null;
    c?.measureLabel = null;
    c?.measureLabelAt = null;
    c?.lengthBuffer = '';
  }

  /// Apply typed length (decimal feet) while resizing/dragging or on selection.
  void commitLength(EditorController c, String raw) {
    final inches = Units.parseLength(raw);
    if (inches == null || inches <= 0) {
      c.setStatus('Could not parse length: $raw');
      return;
    }

    if (_draggingEndpoint &&
        _dragWallId != null &&
        _endpointLockOrigin != null) {
      final w = c.document.wallById(_dragWallId!);
      if (w == null) return;
      final toward = c.cursorWorld ??
          (_dragEndpointA ? w.a : w.b);
      final step = c.snapEngine.lockStepDegrees;
      final locked = step == null
          ? toward
          : angleLock(_endpointLockOrigin!, toward, step);
      final end = pointAtLength(_endpointLockOrigin!, locked, inches);
      if (_dragEndpointA) {
        w.a = end;
      } else {
        w.b = end;
      }
      _sizeLocked = true;
      final label = Units.format(inches, c.document.displayUnits);
      c.measureLabel = label;
      c.measureLabelAt = _endpointLockOrigin!.lerp(end, 0.5);
      c.statusMessage = 'Wall length $label';
      c.refresh();
      return;
    }

    if (_resizingFurniture &&
        _dragFurnitureId != null &&
        _furnOrigin0 != null &&
        _furnW0 != null &&
        _furnD0 != null &&
        _resizeCorner != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f == null) return;
      final world = _lastResizeWorld ?? c.cursorWorld ?? f.origin;
      _applyFurnitureSize(
        f,
        world,
        primaryInches: inches,
        controller: c,
      );
      _sizeLocked = true;
      final wLabel = Units.format(f.width, c.document.displayUnits);
      final dLabel = Units.format(f.depth, c.document.displayUnits);
      final axis = (_lastAxisWidth ?? true) ? 'W' : 'D';
      c.measureLabel = '$wLabel × $dLabel';
      c.measureLabelAt = f.origin;
      c.statusMessage = 'Size $axis $wLabel × $dLabel';
      c.refresh();
      return;
    }

    if (_draggingFurniture && _dragFurnitureId != null) {
      final f = c.document.furnitureById(_dragFurnitureId!);
      if (f != null) {
        _furnW0 ??= f.width;
        _furnD0 ??= f.depth;
        _furnOrigin0 ??= f.origin;
        _applyFurnitureSingleAxis(f, inches);
        _sizeLocked = true;
        final wLabel = Units.format(f.width, c.document.displayUnits);
        final dLabel = Units.format(f.depth, c.document.displayUnits);
        final axis = (_lastAxisWidth ?? true) ? 'W' : 'D';
        c.measureLabel = '$wLabel × $dLabel';
        c.measureLabelAt = f.origin;
        c.statusMessage = 'Size $axis $wLabel × $dLabel';
        c.refresh();
        return;
      }
    }

    if (_dragOpeningId != null &&
        !_slidingOpening &&
        _openOffset0 != null &&
        _openWidth0 != null) {
      final o = c.document.openingById(_dragOpeningId!);
      final w = o == null ? null : c.document.wallById(o.wallId);
      if (o == null || w == null) return;
      const minW = 12.0;
      final width = inches.clamp(minW, w.length);
      if (_dragOpeningStart) {
        final end = _openOffset0! + _openWidth0!;
        var start = (end - width).clamp(0.0, end - minW);
        o.offset = start;
        o.width = end - start;
      } else {
        final start = _openOffset0!;
        var end = (start + width).clamp(start + minW, w.length);
        o.offset = start;
        o.width = end - start;
      }
      _sizeLocked = true;
      final label = Units.format(o.width, c.document.displayUnits);
      c.measureLabel = label;
      c.measureLabelAt = w.pointAt(o.centerOffset);
      c.statusMessage =
          '${o.type == OpeningType.door ? 'Door' : 'Window'} width $label';
      c.refresh();
      return;
    }

    // Idle selection: single furniture item.
    if (c.selectedIds.length == 1) {
      final id = c.selectedIds.first;
      final f = c.document.furnitureById(id);
      if (f != null) {
        final fromW = f.width;
        final fromD = f.depth;
        _applyFurnitureSingleAxis(f, inches);
        c.pushCommand(
          SetFurnitureSizeCommand(
            furnitureId: f.id,
            fromWidth: fromW,
            fromDepth: fromD,
            toWidth: f.width,
            toDepth: f.depth,
          ),
        );
        final wLabel = Units.format(f.width, c.document.displayUnits);
        final dLabel = Units.format(f.depth, c.document.displayUnits);
        final axis = (_lastAxisWidth ?? true) ? 'W' : 'D';
        c.statusMessage = 'Size $axis $wLabel × $dLabel';
      }
    }
  }

  /// Change only the last-adjusted axis (default width). Other axis unchanged.
  void _applyFurnitureSingleAxis(FurnitureItem f, double inches) {
    final size = inches.clamp(6.0, 600.0);
    final useWidth = _lastAxisWidth ?? true;
    if (useWidth) {
      f.width = size;
    } else {
      f.depth = size;
    }
  }

  /// World → furniture local (relative to [origin], rotation [rot]).
  Vec2 _worldToLocal(Vec2 world, Vec2 origin, double rot) {
    final cos = math.cos(rot);
    final sin = math.sin(rot);
    final dx = world.x - origin.x;
    final dy = world.y - origin.y;
    return Vec2(dx * cos + dy * sin, -dx * sin + dy * cos);
  }

  /// Lock width vs depth from **screen** drag vs furniture axes on screen.
  void _updateAxisLockFromScreen(EditorController c, Offset screenNow) {
    if (_lockedAxisWidth != null || _resizeScreen0 == null) return;
    final rot = _furnRot0 ?? 0.0;
    final origin = _furnOrigin0 ?? Vec2.zero;
    // Unit axes in world, then to screen (Y flips via viewport).
    final o = c.viewport.worldToScreen(origin);
    final wEnd = c.viewport.worldToScreen(
      origin + Vec2(math.cos(rot), math.sin(rot)),
    );
    final dEnd = c.viewport.worldToScreen(
      origin + Vec2(-math.sin(rot), math.cos(rot)),
    );
    var wAxis = Offset(wEnd.dx - o.dx, wEnd.dy - o.dy);
    var dAxis = Offset(dEnd.dx - o.dx, dEnd.dy - o.dy);
    final wLen = wAxis.distance;
    final dLen = dAxis.distance;
    if (wLen < 1e-6 || dLen < 1e-6) return;
    wAxis = Offset(wAxis.dx / wLen, wAxis.dy / wLen);
    dAxis = Offset(dAxis.dx / dLen, dAxis.dy / dLen);

    final delta = Offset(
      screenNow.dx - _resizeScreen0!.dx,
      screenNow.dy - _resizeScreen0!.dy,
    );
    final alongW = (delta.dx * wAxis.dx + delta.dy * wAxis.dy).abs();
    final alongD = (delta.dx * dAxis.dx + delta.dy * dAxis.dy).abs();
    const lockPx = 6.0;
    if (alongW < lockPx && alongD < lockPx) return;
    // Prefer the clearer axis; require a small margin so diagonals stay free.
    if (alongW > alongD * 1.15) {
      _lockedAxisWidth = true;
      _lastAxisWidth = true;
    } else if (alongD > alongW * 1.15) {
      _lockedAxisWidth = false;
      _lastAxisWidth = false;
    }
  }

  void _applyFurnitureSize(
    FurnitureItem f,
    Vec2 world, {
    double? primaryInches,
    EditorController? controller,
    Offset? screen,
  }) {
    final rot = _furnRot0 ?? f.rotationRad;
    final cos = math.cos(rot);
    final sin = math.sin(rot);
    final origin0 = _furnOrigin0!;

    if (controller != null && screen != null && primaryInches == null) {
      _updateAxisLockFromScreen(controller, screen);
    }

    final local = _worldToLocal(world, origin0, rot);
    final lx = local.x;
    final ly = local.y;
    // Opposite corner in local space of *original* center (fixed during drag).
    final opp = switch (_resizeCorner!) {
      0 => Vec2(_furnW0! / 2, _furnD0! / 2),
      1 => Vec2(-_furnW0! / 2, _furnD0! / 2),
      2 => Vec2(-_furnW0! / 2, -_furnD0! / 2),
      _ => Vec2(_furnW0! / 2, -_furnD0! / 2),
    };
    final mouseW = (lx - opp.x).abs().clamp(6.0, 600.0);
    final mouseD = (ly - opp.y).abs().clamp(6.0, 600.0);

    final axisWidth = _lockedAxisWidth ?? _lastAxisWidth;

    double newW;
    double newD;
    if (primaryInches != null) {
      final size = primaryInches.clamp(6.0, 600.0);
      // Typed entry always hits one axis only.
      if (axisWidth ?? true) {
        newW = size;
        newD = _furnD0!;
      } else {
        newW = _furnW0!;
        newD = size;
      }
    } else if (axisWidth == null) {
      newW = mouseW;
      newD = mouseD;
    } else if (axisWidth) {
      newW = mouseW;
      newD = _furnD0!;
    } else {
      newW = _furnW0!;
      newD = mouseD;
    }

    // Signs from which side of the opposite corner the pointer is on.
    final signX = (lx - opp.x) >= 0 ? 1.0 : -1.0;
    final signY = (ly - opp.y) >= 0 ? 1.0 : -1.0;
    // When locked to one axis, keep the free corner's sign from original corner.
    final corner0 = switch (_resizeCorner!) {
      0 => Vec2(-_furnW0! / 2, -_furnD0! / 2),
      1 => Vec2(_furnW0! / 2, -_furnD0! / 2),
      2 => Vec2(_furnW0! / 2, _furnD0! / 2),
      _ => Vec2(-_furnW0! / 2, _furnD0! / 2),
    };
    final sx = axisWidth == false
        ? (corner0.x >= opp.x ? 1.0 : -1.0)
        : signX;
    final sy = axisWidth == true
        ? (corner0.y >= opp.y ? 1.0 : -1.0)
        : signY;

    final localCenter = Vec2(
      opp.x + sx * newW / 2,
      opp.y + sy * newD / 2,
    );
    final wx = localCenter.x * cos - localCenter.y * sin;
    final wy = localCenter.x * sin + localCenter.y * cos;
    f.width = newW;
    f.depth = newD;
    f.origin = Vec2(origin0.x + wx, origin0.y + wy);
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
        _slidingOpening = false;
        _openOffset0 = o.offset;
        _openWidth0 = o.width;
        c.lengthBuffer = '';
        return;
      }
      if (e.world.distanceTo(end) <= tol) {
        _dragOpeningId = o.id;
        _dragOpeningStart = false;
        _slidingOpening = false;
        _openOffset0 = o.offset;
        _openWidth0 = o.width;
        c.lengthBuffer = '';
        return;
      }
      final center = w.pointAt(o.centerOffset);
      if (e.world.distanceTo(center) <= tol) {
        _beginOpeningSlide(c, o, w, e.world);
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
          _furnRot0 = f.rotationRad;
          _lastResizeWorld = e.world;
          _resizeScreen0 = e.screen;
          _lockedAxisWidth = null;
          _lastAxisWidth = null;
          c.lengthBuffer = '';
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
        c.lengthBuffer = '';
        return;
      }
      if (e.world.distanceTo(w.b) <= tol) {
        _dragWallId = w.id;
        _dragEndpointA = false;
        _draggingEndpoint = true;
        _endpointOriginal = w.b;
        _endpointLockOrigin = w.a;
        c.lengthBuffer = '';
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
        _beginOpeningSlide(c, o, w, e.world);
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
        _fixtureScale0 = fx.scale;
        _resizingFixture = false;
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
        _furnW0 = f.width;
        _furnD0 = f.depth;
        c.lengthBuffer = '';
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

  void _beginOpeningSlide(
    EditorController c,
    Opening o,
    Wall w,
    Vec2 world,
  ) {
    _dragOpeningId = o.id;
    _slidingOpening = true;
    _openOffset0 = o.offset;
    _openWidth0 = o.width;
    _openGrabAlong0 =
        Segment(w.a, w.b).distanceAlongFromA(world) - o.offset;
    c.lengthBuffer = '';
  }

  void _slideOpeningAlongWall(Opening o, Wall w, Vec2 world) {
    final width = _openWidth0 ?? o.width;
    final grab = _openGrabAlong0 ?? width / 2;
    final along = Segment(w.a, w.b).distanceAlongFromA(world);
    final maxStart = (w.length - width).clamp(0.0, double.infinity);
    o.offset = (along - grab).clamp(0.0, maxStart);
    o.width = width;
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

    if (_sizeLocked) {
      c.refresh();
      return;
    }

    if (_dragOpeningId != null &&
        _openOffset0 != null &&
        _openWidth0 != null) {
      final o = c.document.openingById(_dragOpeningId!);
      final w = o == null ? null : c.document.wallById(o.wallId);
      if (o != null && w != null) {
        if (_slidingOpening) {
          _slideOpeningAlongWall(o, w, e.world);
          final kind = o.type == OpeningType.door ? 'Door' : 'Window';
          c.measureLabel = null;
          c.measureLabelAt = null;
          c.statusMessage = 'Move $kind along wall';
        } else {
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
          final buf =
              c.lengthBuffer.isEmpty ? '' : '  entry: ${c.lengthBuffer}';
          c.measureLabel = label;
          c.measureLabelAt = w.pointAt(o.centerOffset);
          c.statusMessage =
              '${o.type == OpeningType.door ? 'Door' : 'Window'} width $label$buf';
        }
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
        _lastResizeWorld = e.world;
        _applyFurnitureSize(
          f,
          e.world,
          controller: c,
          screen: e.screen,
        );
        final wLabel = Units.format(f.width, c.document.displayUnits);
        final dLabel = Units.format(f.depth, c.document.displayUnits);
        final buf =
            c.lengthBuffer.isEmpty ? '' : '  entry: ${c.lengthBuffer}';
        final axis = _lockedAxisWidth == null
            ? ''
            : (_lockedAxisWidth! ? 'W ' : 'D ');
        c.measureLabel = '$wLabel × $dLabel';
        c.measureLabelAt = f.origin;
        c.statusMessage = 'Size $axis$wLabel × $dLabel$buf';
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

    if (_dragFixtureId != null &&
        _fixtureOffset0 != null &&
        _dragStartWorld != null) {
      final fx = c.document.wallFixtureById(_dragFixtureId!);
      final w = fx == null ? null : c.document.wallById(fx.wallId);
      if (fx != null && w != null) {
        final anchor = w.pointAt(_fixtureOffset0!);
        final delta = e.world - _dragStartWorld!;
        final dir = w.direction;
        final normal = Vec2(-dir.y, dir.x);
        final alongDelta = delta.dot(dir);
        final offWall = delta.dot(normal).abs();
        final distFromWall = Segment(w.a, w.b).distanceToPoint(e.world);

        // Resize when leaving the wall; move when staying near it along-wall.
        if (!_resizingFixture && delta.length > c.snapToleranceWorld * 0.35) {
          _resizingFixture =
              offWall >= alongDelta.abs() * 0.6 || distFromWall > c.snapToleranceWorld;
        }

        if (_resizingFixture) {
          // Diameter from center: 2 × distance from anchor to pointer.
          final rawSize = (e.world.distanceTo(anchor) * 2).clamp(1.0, 96.0);
          final size = snapFixtureSize(rawSize);
          fx.scale = scaleFromWorldSize(fx.type, size);
          final label = Units.format(size, c.document.displayUnits);
          c.measureLabel = label;
          c.measureLabelAt = anchor;
          c.statusMessage = 'Sticker size $label (snap ¼′)';
        } else {
          fx.offset =
              Segment(w.a, w.b).distanceAlongFromA(e.world).clamp(0.0, w.length);
          c.measureLabel = null;
          c.measureLabelAt = null;
          c.statusMessage = 'Move along wall';
        }
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
        final label = Units.format(w.length, c.document.displayUnits);
        final buf =
            c.lengthBuffer.isEmpty ? '' : '  entry: ${c.lengthBuffer}';
        c.measureLabel = label;
        c.measureLabelAt = w.a.lerp(w.b, 0.5);
        c.statusMessage = 'Wall length $label$buf';
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
        final toW = f.width;
        final toD = f.depth;
        final toOrigin = f.origin;
        final fromW = _furnW0 ?? toW;
        final fromD = _furnD0 ?? toD;
        f.width = fromW;
        f.depth = fromD;
        f.origin = _furnOrigin0!;
        var changed = false;
        if ((toW - fromW).abs() > 0.01 || (toD - fromD).abs() > 0.01) {
          c.pushCommand(
            SetFurnitureSizeCommand(
              furnitureId: _dragFurnitureId!,
              fromWidth: fromW,
              fromDepth: fromD,
              toWidth: toW,
              toDepth: toD,
            ),
          );
          changed = true;
        }
        final delta = toOrigin - _furnOrigin0!;
        if (delta.length > 0.01) {
          c.pushCommand(
            TranslateFurnitureCommand(
              furnitureId: _dragFurnitureId!,
              delta: delta,
            ),
          );
          changed = true;
        }
        if (!changed) c.refresh();
      }
    } else if (_dragFixtureId != null && _fixtureOffset0 != null) {
      final fx = c.document.wallFixtureById(_dragFixtureId!);
      if (fx != null) {
        final toOff = fx.offset;
        final toScale = fx.scale;
        final fromScale = _fixtureScale0 ?? fx.scale;
        fx.offset = _fixtureOffset0!;
        fx.scale = fromScale;
        var changed = false;
        if ((toOff - _fixtureOffset0!).abs() > 0.01) {
          c.pushCommand(
            MoveWallFixtureCommand(
              fixtureId: _dragFixtureId!,
              fromOffset: _fixtureOffset0!,
              toOffset: toOff,
            ),
          );
          changed = true;
        }
        if ((toScale - fromScale).abs() > 0.001) {
          c.pushCommand(
            SetWallFixtureScaleCommand(
              fixtureId: _dragFixtureId!,
              scale: toScale,
            ),
          );
          changed = true;
        }
        if (!changed) c.refresh();
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
