import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/commands.dart';
import '../domain/dimension.dart';
import 'editor_controller.dart';
import 'tool.dart';

class DimensionTool extends EditorTool {
  Vec2? _p1;

  @override
  ToolId get id => ToolId.dimension;

  @override
  String get name => 'Dimension';

  @override
  String get statusHint => 'Click first point, then second. M';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void cancel(EditorController c) {
    _p1 = null;
    c.previewDimension = null;
    c.setStatus(statusHint);
  }

  @override
  void pointerMove(EditorController c, ToolPointerEvent e) {
    c.cursorWorld = e.point;
    c.snapPoint = e.snapped.point;
    if (_p1 != null) {
      c.previewDimension = (_p1!, e.point);
      final len = _p1!.distanceTo(e.point);
      c.statusMessage =
          'Dimension ${Units.format(len, c.document.displayUnits)}';
    } else {
      c.previewDimension = null;
    }
    c.refresh();
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    if (_p1 == null) {
      _p1 = e.point;
      c.setStatus('Click second point');
      c.refresh();
      return;
    }
    if (_p1!.distanceTo(e.point) < 0.5) return;
    final dim = LinearDimension(
      id: c.document.idGen.next('dim'),
      p1: _p1!,
      p2: e.point,
      offset: 12,
      layerId: 'dimensions',
    );
    c.pushCommand(AddDimensionCommand(dim));
    _p1 = null;
    c.previewDimension = null;
    c.setStatus('Dimension added');
  }
}
