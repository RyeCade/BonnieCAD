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
      'Click to start a wall, click again to finish. Type length + Enter. Esc cancel.';

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
        thickness: 4.5,
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
      c.setStatus('Click end point (orthogonal on). Type length + Enter.');
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
      thickness: 4.5,
      layerId: 'walls',
    );
    c.pushCommand(AddWallCommand(wall));
    _start = end;
    c.previewWall = null;
    c.setStatus('Wall added. Click next point or Esc to stop.');
  }
}
