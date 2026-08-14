import '../domain/commands.dart';
import '../domain/furniture.dart';
import '../domain/furniture_catalog.dart';
import '../domain/wall_fixture.dart';
import '../geometry/segment.dart';
import 'editor_controller.dart';
import 'tool.dart';

class FurnitureTool extends EditorTool {
  @override
  ToolId get id => ToolId.furniture;

  @override
  String get name => 'Furniture';

  @override
  String get statusHint =>
      'Pick an item in the library, then click to place. B';

  @override
  void onActivate(EditorController c) {
    final entry = FurnitureCatalog.byId(c.activeCatalogId ?? '');
    if (entry == null) {
      c.setStatus('Choose an item from the furniture library');
    } else if (entry.wallHosted) {
      c.setStatus('Click a wall to place ${entry.name}');
    } else {
      c.setStatus('Click to place ${entry.name}');
    }
  }

  @override
  void pointerDown(EditorController c, ToolPointerEvent e) {
    if (!e.isPrimary) return;
    final entry = FurnitureCatalog.byId(c.activeCatalogId ?? '');
    if (entry == null) {
      c.setStatus('Choose an item from the furniture library first');
      return;
    }

    if (entry.wallHosted) {
      _placeWallFixture(c, e, entry);
    } else {
      _placeFurniture(c, e, entry);
    }
  }

  void _placeFurniture(
    EditorController c,
    ToolPointerEvent e,
    FurnitureCatalogEntry entry,
  ) {
    final item = FurnitureItem(
      id: c.document.idGen.next('f'),
      catalogId: entry.id,
      origin: e.point,
      width: entry.defaultWidth,
      depth: entry.defaultDepth,
      layerId: 'furniture',
    );
    c.pushCommand(AddFurnitureCommand(item));
    c.selectedIds
      ..clear()
      ..add(item.id);
    c.setStatus('${entry.name} placed');
  }

  void _placeWallFixture(
    EditorController c,
    ToolPointerEvent e,
    FurnitureCatalogEntry entry,
  ) {
    final tol = c.snapToleranceWorld * 2;
    final wall = c.snapEngine.hitTestWall(c.document, e.world, tol);
    if (wall == null) {
      c.setStatus('Click on a wall to place ${entry.name}');
      return;
    }
    final seg = Segment(wall.a, wall.b);
    final along = seg.distanceAlongFromA(e.world).clamp(0.0, wall.length);
    final fixture = WallFixture(
      id: c.document.idGen.next('e'),
      type: WallFixture.typeFromCatalogId(entry.id),
      wallId: wall.id,
      offset: along,
      layerId: 'electrical',
    );
    c.pushCommand(AddWallFixtureCommand(fixture));
    c.selectedIds
      ..clear()
      ..add(fixture.id);
    c.setStatus('${entry.name} placed');
  }
}
