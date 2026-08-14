import 'package:bon_cad/core/vec2.dart';
import 'package:bon_cad/domain/document.dart';
import 'package:bon_cad/domain/floor.dart';
import 'package:bon_cad/domain/furniture.dart';
import 'package:bon_cad/domain/opening.dart';
import 'package:bon_cad/domain/text_label.dart';
import 'package:bon_cad/domain/wall.dart';
import 'package:bon_cad/domain/wall_fixture.dart';
import 'package:bon_cad/persistence/document_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round trip document json v3', () {
    final doc = Document.empty(name: 'Test Home');
    doc.walls.add(
      Wall(
        id: 'w1',
        a: const Vec2(0, 0),
        b: const Vec2(240, 0),
        thickness: 4.5,
        colorValue: 0xFFC62828,
      ),
    );
    doc.openings.add(
      Opening(
        id: 'd1',
        type: OpeningType.door,
        wallId: 'w1',
        offset: 36,
        width: 32,
        strokeWidth: 2.5,
      ),
    );
    doc.furniture.add(
      FurnitureItem(
        id: 'f1',
        catalogId: 'bathtub',
        origin: const Vec2(40, 40),
        width: 60,
        depth: 30,
      ),
    );
    doc.wallFixtures.add(
      WallFixture(
        id: 'e1',
        type: WallFixtureType.outlet,
        wallId: 'w1',
        offset: 12,
      ),
    );
    doc.texts.add(
      TextLabel(
        id: 't1',
        origin: const Vec2(20, 20),
        text: 'Kitchen',
        fontSizePx: 16,
      ),
    );
    doc.floors.add(Floor(id: 'fl2', name: 'Basement'));

    final text = DocumentCodec.encode(doc);
    final loaded = DocumentCodec.decode(text);

    expect(loaded.name, 'Test Home');
    expect(loaded.floors, hasLength(2));
    expect(loaded.activeFloorId, 'fl1');
    expect(loaded.walls, hasLength(1));
    expect(loaded.walls.first.length, 240);
    expect(loaded.walls.first.colorValue, 0xFFC62828);
    expect(loaded.openings, hasLength(1));
    expect(loaded.openings.first.width, 32);
    expect(loaded.openings.first.strokeWidth, 2.5);
    expect(loaded.furniture, hasLength(1));
    expect(loaded.furniture.first.catalogId, 'bathtub');
    expect(loaded.wallFixtures, hasLength(1));
    expect(loaded.texts, hasLength(1));
    expect(loaded.texts.first.text, 'Kitchen');
    expect(loaded.layerById('furniture'), isNotNull);
    expect(loaded.layerById('electrical'), isNotNull);

    loaded.activeFloorId = 'fl2';
    expect(loaded.walls, isEmpty);
  });

  test('loads schema v1 without furniture into Main floor', () {
    const v1 = '''
{
  "schemaVersion": 1,
  "name": "Old",
  "units": "inch",
  "displayUnits": "imperial",
  "gridSize": 6,
  "idCounter": 1,
  "layers": [
    {"id": "walls", "name": "Walls", "visible": true, "locked": false, "colorValue": 4280361249}
  ],
  "walls": [],
  "openings": [],
  "dimensions": []
}
''';
    final loaded = DocumentCodec.decode(v1);
    expect(loaded.name, 'Old');
    expect(loaded.floors, hasLength(1));
    expect(loaded.floors.first.name, 'Main');
    expect(loaded.activeFloorId, 'fl1');
    expect(loaded.furniture, isEmpty);
    expect(loaded.wallFixtures, isEmpty);
    expect(loaded.texts, isEmpty);
    expect(loaded.layerById('furniture'), isNotNull);
  });

  test('loads schema v2 flat geometry into Main floor', () {
    const v2 = '''
{
  "schemaVersion": 2,
  "name": "V2 Home",
  "units": "inch",
  "displayUnits": "imperial",
  "gridSize": 6,
  "idCounter": 2,
  "layers": [
    {"id": "walls", "name": "Walls", "visible": true, "locked": false, "colorValue": 4280361249}
  ],
  "walls": [
    {"id": "w1", "a": {"x": 0, "y": 0}, "b": {"x": 100, "y": 0}, "thickness": 4.5, "layerId": "walls"}
  ],
  "openings": [],
  "dimensions": [],
  "furniture": [],
  "wallFixtures": []
}
''';
    final loaded = DocumentCodec.decode(v2);
    expect(loaded.floors.first.name, 'Main');
    expect(loaded.walls, hasLength(1));
    expect(loaded.walls.first.length, 100);
  });
}
