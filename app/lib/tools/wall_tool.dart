import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/commands.dart';
import '../domain/wall.dart';
import '../geometry/segment.dart';
import 'editor_controller.dart';
import 'tool.dart';

class WallTool extends EditorTool {
  Vec2? _start;

  Vec2? get startPoint => _start;

  @override
  ToolId get id => ToolId.wall;

  @override
  String get name => 'Wall';

  @override
  String get statusHint =>
      'Click start, click end. Shift+click jumps start (no wall). Type feet (10.5=10′6″) + Enter. Esc cancel.';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void cancel(EditorController c) {
    _start = null;
    c.previewWall = null;
    c.snapPoint = null;
    c.setStatus(statusHint);
  }

  @override
  void pointerMove(EditorController c, ToolPointerEvent e) {
    c.cursorWorld = e.point;
    c.snapPoint = e.snapped.point;

    if (_start != null) {
      c.previewWall = Wall(
        id: 'preview',
        a: _start!,
        b: e.point,
        thickness: c.defaultWallThickness,
        colorValue: c.defaultWallColorValue,
      );
      final len = _start!.distanceTo(e.point);
      final label = Units.format(len, c.document.displayUnits);
      final buf = c.lengthBuffer.isEmpty ? '' : '  entry: ${c.lengthBuffer}';
      c.statusMessage = 'Wall length $label$buf';
    } else {
      c.previewWall = null;
    }
    c.refresh();
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    if (_start == null) {
      _start = e.point;
      c.setStatus(
        'Click end (or Shift+click to jump start). Type feet (10.5=10′6″) + Enter.',
      );
      c.refresh();
      return;
    }

    // Shift+click: abandon current segment and start a new wall here.
    if (e.shift) {
      _start = e.point;
      c.previewWall = null;
      c.lengthBuffer = '';
      c.setStatus(
        'New start. Click end (or Shift+click to jump again).',
      );
      c.refresh();
      return;
    }

    _commit(c, e.point);
  }

  void commitLength(EditorController c, String raw) {
    if (_start == null) return;
    final inches = Units.parseLength(raw);
    if (inches == null || inches <= 0) {
      c.setStatus('Could not parse length: $raw');
      return;
    }
    final toward = c.cursorWorld ?? (_start! + const Vec2(1, 0));
    final step = c.snapEngine.lockStepDegrees;
    final locked = step == null
        ? toward
        : angleLock(_start!, toward, step);
    final endExact = pointAtLength(_start!, locked, inches);
    _commit(c, endExact);
  }

  void _commit(EditorController c, Vec2 end) {
    if (_start == null) return;
    if (_start!.distanceTo(end) < 0.5) {
      c.setStatus('Wall too short');
      return;
    }
    final wall = Wall(
      id: c.document.idGen.next('w'),
      a: _start!,
      b: end,
      thickness: c.defaultWallThickness,
      layerId: 'walls',
      colorValue: c.defaultWallColorValue,
    );
    c.pushCommand(AddWallCommand(wall));
    c.selectedIds
      ..clear()
      ..add(wall.id);
    _start = end;
    c.previewWall = null;
    c.setStatus(
      'Wall added. Click next point, Shift+click to jump start, or Esc.',
    );
  }
}
