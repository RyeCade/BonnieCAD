import '../domain/commands.dart';
import '../domain/opening.dart';
import '../geometry/segment.dart';
import 'editor_controller.dart';
import 'tool.dart';

class OpeningTool extends EditorTool {
  OpeningTool(this.type);

  final OpeningType type;

  static const defaultDoorWidth = 32.0;
  static const defaultWindowWidth = 36.0;

  @override
  ToolId get id => type == OpeningType.door ? ToolId.door : ToolId.window;

  @override
  String get name => type == OpeningType.door ? 'Door' : 'Window';

  @override
  String get statusHint => type == OpeningType.door
      ? 'Click a wall to place a door (32"). D'
      : 'Click a wall to place a window (36"). E';

  @override
  void onActivate(EditorController c) {
    c.setStatus(statusHint);
  }

  @override
  void pointerMove(EditorController c, ToolPointerEvent e) {
    c.cursorWorld = e.world;
    c.snapPoint = e.snapped.point;
    c.refresh();
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    final tol = c.snapToleranceWorld * 2;
    final wall = c.snapEngine.hitTestWall(c.document, e.world, tol);
    if (wall == null) {
      c.setStatus('Click on a wall');
      return;
    }

    final width =
        type == OpeningType.door ? defaultDoorWidth : defaultWindowWidth;
    final seg = Segment(wall.a, wall.b);
    var along = seg.distanceAlongFromA(e.world) - width / 2;
    final maxStart = (wall.length - width).clamp(0.0, double.infinity);
    along = along.clamp(0.0, maxStart);

    final opening = Opening(
      id: c.document.idGen.next(type == OpeningType.door ? 'd' : 'win'),
      type: type,
      wallId: wall.id,
      offset: along,
      width: width,
      swing: DoorSwing.leftIn,
      layerId: 'openings',
    );
    c.pushCommand(AddOpeningCommand(opening));
    c.setStatus('$name placed');
  }
}
