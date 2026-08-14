import '../core/ids.dart';
import '../core/units.dart';
import '../core/vec2.dart';
import 'dimension.dart';
import 'floor.dart';
import 'furniture.dart';
import 'layer.dart';
import 'opening.dart';
import 'text_label.dart';
import 'wall.dart';
import 'wall_fixture.dart';

class Document {
  Document({
    required this.name,
    required this.layers,
    required this.floors,
    required this.activeFloorId,
    this.gridSize = 6.0,
    this.displayUnits = DisplayUnitSystem.imperial,
    IdGen? idGen,
  }) : idGen = idGen ?? IdGen();

  String name;
  double gridSize;
  DisplayUnitSystem displayUnits;
  final List<Layer> layers;
  final List<Floor> floors;
  String activeFloorId;
  final IdGen idGen;

  static Document empty({String name = 'Untitled Plan'}) {
    final layers = [
      Layer(id: 'walls', name: 'Walls', colorValue: 0xFF212121),
      Layer(id: 'openings', name: 'Openings', colorValue: 0xFF1565C0),
      Layer(id: 'dimensions', name: 'Dimensions', colorValue: 0xFF2E7D32),
      Layer(id: 'annotations', name: 'Annotations', colorValue: 0xFF6A1B9A),
      Layer(id: 'furniture', name: 'Furniture', colorValue: 0xFF5D4037),
      Layer(id: 'electrical', name: 'Electrical', colorValue: 0xFFF9A825),
    ];
    const floorId = 'fl1';
    return Document(
      name: name,
      layers: layers,
      floors: [Floor(id: floorId, name: 'Main')],
      activeFloorId: floorId,
      gridSize: 6.0,
      displayUnits: DisplayUnitSystem.imperial,
    );
  }

  Floor? floorById(String id) {
    for (final f in floors) {
      if (f.id == id) return f;
    }
    return null;
  }

  Floor get activeFloor {
    final f = floorById(activeFloorId);
    if (f != null) return f;
    if (floors.isEmpty) {
      throw StateError('Document has no floors');
    }
    activeFloorId = floors.first.id;
    return floors.first;
  }

  List<Wall> get walls => activeFloor.walls;
  List<Opening> get openings => activeFloor.openings;
  List<LinearDimension> get dimensions => activeFloor.dimensions;
  List<FurnitureItem> get furniture => activeFloor.furniture;
  List<WallFixture> get wallFixtures => activeFloor.wallFixtures;
  List<TextLabel> get texts => activeFloor.texts;

  Layer? layerById(String id) {
    for (final l in layers) {
      if (l.id == id) return l;
    }
    return null;
  }

  Wall? wallById(String id) {
    for (final w in walls) {
      if (w.id == id) return w;
    }
    return null;
  }

  Opening? openingById(String id) {
    for (final o in openings) {
      if (o.id == id) return o;
    }
    return null;
  }

  LinearDimension? dimensionById(String id) {
    for (final d in dimensions) {
      if (d.id == id) return d;
    }
    return null;
  }

  FurnitureItem? furnitureById(String id) {
    for (final f in furniture) {
      if (f.id == id) return f;
    }
    return null;
  }

  WallFixture? wallFixtureById(String id) {
    for (final f in wallFixtures) {
      if (f.id == id) return f;
    }
    return null;
  }

  TextLabel? textById(String id) {
    for (final t in texts) {
      if (t.id == id) return t;
    }
    return null;
  }

  bool isLayerVisible(String layerId) => layerById(layerId)?.visible ?? true;

  void ensureDefaultLayers() {
    void addIfMissing(String id, String name, int color) {
      if (layerById(id) == null) {
        layers.add(Layer(id: id, name: name, colorValue: color));
      }
    }

    addIfMissing('furniture', 'Furniture', 0xFF5D4037);
    addIfMissing('electrical', 'Electrical', 0xFFF9A825);
    addIfMissing('annotations', 'Annotations', 0xFF6A1B9A);
  }

  void reindexIds() {
    final all = <String>[
      ...floors.map((f) => f.id),
      for (final floor in floors) ...[
        ...floor.walls.map((w) => w.id),
        ...floor.openings.map((o) => o.id),
        ...floor.dimensions.map((d) => d.id),
        ...floor.furniture.map((f) => f.id),
        ...floor.wallFixtures.map((f) => f.id),
        ...floor.texts.map((t) => t.id),
      ],
    ];
    idGen.ensureAtLeast(maxNumericSuffix(all));
  }

  ({Vec2 min, Vec2 max})? bounds() {
    if (walls.isEmpty &&
        dimensions.isEmpty &&
        furniture.isEmpty &&
        wallFixtures.isEmpty &&
        texts.isEmpty) {
      return null;
    }
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;

    void consider(Vec2 p) {
      if (p.x < minX) minX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.x > maxX) maxX = p.x;
      if (p.y > maxY) maxY = p.y;
    }

    for (final w in walls) {
      consider(w.a);
      consider(w.b);
    }
    for (final d in dimensions) {
      consider(d.p1);
      consider(d.p2);
    }
    for (final f in furniture) {
      for (final c in f.worldCorners()) {
        consider(c);
      }
    }
    for (final fx in wallFixtures) {
      final w = wallById(fx.wallId);
      if (w != null) consider(w.pointAt(fx.offset));
    }
    for (final t in texts) {
      consider(t.origin);
    }
    return (min: Vec2(minX, minY), max: Vec2(maxX, maxY));
  }

  Document clone() {
    return Document(
      name: name,
      gridSize: gridSize,
      displayUnits: displayUnits,
      layers: layers.map((l) => l.copyWith()).toList(),
      floors: floors.map((f) => f.clone()).toList(),
      activeFloorId: activeFloorId,
      idGen: IdGen(idGen.counter),
    );
  }
}
