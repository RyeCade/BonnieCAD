import 'package:bon_cad/core/vec2.dart';
import 'package:bon_cad/domain/commands.dart';
import 'package:bon_cad/domain/document.dart';
import 'package:bon_cad/domain/floor.dart';
import 'package:bon_cad/domain/furniture.dart';
import 'package:bon_cad/domain/history.dart';
import 'package:bon_cad/domain/opening.dart';
import 'package:bon_cad/domain/text_label.dart';
import 'package:bon_cad/domain/wall.dart';
import 'package:bon_cad/domain/wall_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('undo redo wall add', () {
    final doc = Document.empty();
    final history = History();
    final wall = Wall(
      id: 'w1',
      a: const Vec2(0, 0),
      b: const Vec2(120, 0),
    );

    history.push(AddWallCommand(wall), doc);
    expect(doc.walls, hasLength(1));

    history.undo(doc);
    expect(doc.walls, isEmpty);

    history.redo(doc);
    expect(doc.walls, hasLength(1));
    expect(doc.walls.first.length, 120);
  });

  test('undo redo opening resize', () {
    final doc = Document.empty();
    final history = History();
    doc.walls.add(
      Wall(id: 'w1', a: const Vec2(0, 0), b: const Vec2(200, 0)),
    );
    doc.openings.add(
      Opening(
        id: 'd1',
        type: OpeningType.door,
        wallId: 'w1',
        offset: 20,
        width: 32,
      ),
    );

    history.push(
      SetOpeningGeometryCommand(
        openingId: 'd1',
        fromOffset: 20,
        fromWidth: 32,
        toOffset: 10,
        toWidth: 48,
      ),
      doc,
    );
    expect(doc.openings.first.width, 48);
    expect(doc.openings.first.offset, 10);

    history.undo(doc);
    expect(doc.openings.first.width, 32);
    expect(doc.openings.first.offset, 20);
  });

  test('undo redo opening slide along wall', () {
    final doc = Document.empty();
    final history = History();
    doc.walls.add(
      Wall(id: 'w1', a: const Vec2(0, 0), b: const Vec2(200, 0)),
    );
    doc.openings.add(
      Opening(
        id: 'd1',
        type: OpeningType.door,
        wallId: 'w1',
        offset: 20,
        width: 32,
      ),
    );

    final cmd = SetOpeningGeometryCommand(
      openingId: 'd1',
      fromOffset: 20,
      fromWidth: 32,
      toOffset: 80,
      toWidth: 32,
    );
    expect(cmd.label, 'Move opening');

    history.push(cmd, doc);
    expect(doc.openings.first.offset, 80);
    expect(doc.openings.first.width, 32);

    history.undo(doc);
    expect(doc.openings.first.offset, 20);
    expect(doc.openings.first.width, 32);
  });

  test('undo redo opening width and swing', () {
    final doc = Document.empty();
    final history = History();
    doc.walls.add(
      Wall(id: 'w1', a: const Vec2(0, 0), b: const Vec2(200, 0)),
    );
    doc.openings.add(
      Opening(
        id: 'd1',
        type: OpeningType.door,
        wallId: 'w1',
        offset: 20,
        width: 32,
        swing: DoorSwing.leftIn,
      ),
    );

    history.push(
      SetOpeningWidthCommand(openingId: 'd1', width: 36),
      doc,
    );
    expect(doc.openings.first.width, 36);
    expect(doc.openings.first.offset, 20);

    history.push(
      SetOpeningSwingCommand(openingId: 'd1', swing: DoorSwing.rightOut),
      doc,
    );
    expect(doc.openings.first.swing, DoorSwing.rightOut);

    history.push(
      SetOpeningWidthCommand(openingId: 'd1', width: 28),
      doc,
    );
    // Right hinge keeps the latch end fixed.
    expect(doc.openings.first.width, 28);
    expect(doc.openings.first.offset, 28);

    history.undo(doc);
    expect(doc.openings.first.width, 36);
    expect(doc.openings.first.offset, 20);

    history.undo(doc);
    expect(doc.openings.first.swing, DoorSwing.leftIn);

    history.undo(doc);
    expect(doc.openings.first.width, 32);
  });

  test('undo redo wall fixture scale', () {
    final doc = Document.empty();
    final history = History();
    doc.walls.add(
      Wall(id: 'w1', a: const Vec2(0, 0), b: const Vec2(200, 0)),
    );
    doc.wallFixtures.add(
      WallFixture(
        id: 'fx1',
        type: WallFixtureType.outlet,
        wallId: 'w1',
        offset: 40,
      ),
    );

    history.push(
      SetWallFixtureScaleCommand(fixtureId: 'fx1', scale: 1.5),
      doc,
    );
    expect(doc.wallFixtures.first.scale, 1.5);

    history.undo(doc);
    expect(doc.wallFixtures.first.scale, 1.0);

    history.redo(doc);
    expect(doc.wallFixtures.first.scale, 1.5);
  });

  test('undo redo furniture add and style', () {
    final doc = Document.empty();
    final history = History();
    final item = FurnitureItem(
      id: 'f1',
      catalogId: 'toilet',
      origin: const Vec2(10, 10),
      width: 18,
      depth: 28,
    );
    history.push(AddFurnitureCommand(item), doc);
    expect(doc.furniture, hasLength(1));

    history.push(
      SetEntityStyleCommand(
        entityId: 'f1',
        entityKind: StyleEntityKind.furniture,
        colorValue: 0xFF1565C0,
        strokeWidth: 3,
      ),
      doc,
    );
    expect(doc.furniture.first.colorValue, 0xFF1565C0);
    expect(doc.furniture.first.strokeWidth, 3);

    history.undo(doc);
    expect(doc.furniture.first.colorValue, isNull);

    history.undo(doc);
    expect(doc.furniture, isEmpty);
  });

  test('undo redo text label', () {
    final doc = Document.empty();
    final history = History();
    final label = TextLabel(
      id: 't1',
      origin: const Vec2(5, 5),
      text: 'Room',
    );
    history.push(AddTextLabelCommand(label), doc);
    expect(doc.texts, hasLength(1));

    history.push(
      SetTextLabelContentCommand(
        textId: 't1',
        fromText: 'Room',
        toText: 'Kitchen',
      ),
      doc,
    );
    expect(doc.texts.first.text, 'Kitchen');

    history.undo(doc);
    expect(doc.texts.first.text, 'Room');
    history.undo(doc);
    expect(doc.texts, isEmpty);
  });

  test('undo redo add floor', () {
    final doc = Document.empty();
    final history = History();
    expect(doc.floors, hasLength(1));

    final floor = Floor(id: 'fl2', name: 'Basement');
    history.push(AddFloorCommand(floor), doc);
    expect(doc.floors, hasLength(2));
    expect(doc.activeFloorId, 'fl2');

    history.undo(doc);
    expect(doc.floors, hasLength(1));
    expect(doc.activeFloorId, 'fl1');
  });
}

