import 'dart:convert';

import '../core/ids.dart';
import '../core/units.dart';
import '../domain/dimension.dart';
import '../domain/document.dart';
import '../domain/floor.dart';
import '../domain/furniture.dart';
import '../domain/layer.dart';
import '../domain/opening.dart';
import '../domain/text_label.dart';
import '../domain/wall.dart';
import '../domain/wall_fixture.dart';

class DocumentCodec {
  static const schemaVersion = 3;

  static String encode(Document doc) {
    final map = {
      'schemaVersion': schemaVersion,
      'name': doc.name,
      'units': 'inch',
      'displayUnits': doc.displayUnits.name,
      'gridSize': doc.gridSize,
      'idCounter': doc.idGen.counter,
      'activeFloorId': doc.activeFloorId,
      'layers': doc.layers.map((l) => l.toJson()).toList(),
      'floors': doc.floors.map((f) => f.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  static Document decode(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    final version = map['schemaVersion'] as int? ?? 1;
    if (version > schemaVersion) {
      throw FormatException(
        'Unsupported BonnieCAD schema version $version (max $schemaVersion)',
      );
    }

    final layers = (map['layers'] as List? ?? [])
        .map((e) => Layer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    if (layers.isEmpty) {
      return Document.empty(name: map['name'] as String? ?? 'Untitled Plan');
    }

    final List<Floor> floors;
    String activeFloorId;

    if (version >= 3 && map['floors'] is List && (map['floors'] as List).isNotEmpty) {
      floors = (map['floors'] as List)
          .map((e) => Floor.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      activeFloorId = map['activeFloorId'] as String? ?? floors.first.id;
      if (floors.every((f) => f.id != activeFloorId)) {
        activeFloorId = floors.first.id;
      }
    } else {
      final walls = (map['walls'] as List? ?? [])
          .map((e) => Wall.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final openings = (map['openings'] as List? ?? [])
          .map((e) => Opening.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final dimensions = (map['dimensions'] as List? ?? [])
          .map(
            (e) =>
                LinearDimension.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final furniture = (map['furniture'] as List? ?? [])
          .map(
            (e) =>
                FurnitureItem.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final wallFixtures = (map['wallFixtures'] as List? ?? [])
          .map(
            (e) => WallFixture.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList();
      final texts = (map['texts'] as List? ?? [])
          .map((e) => TextLabel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      floors = [
        Floor(
          id: 'fl1',
          name: 'Main',
          walls: walls,
          openings: openings,
          dimensions: dimensions,
          furniture: furniture,
          wallFixtures: wallFixtures,
          texts: texts,
        ),
      ];
      activeFloorId = 'fl1';
    }

    final displayName = map['displayUnits'] as String? ?? 'imperial';
    final display = DisplayUnitSystem.values.firstWhere(
      (e) => e.name == displayName,
      orElse: () => DisplayUnitSystem.imperial,
    );

    final idCounter = map['idCounter'] as int? ??
        maxNumericSuffix([
          ...floors.map((f) => f.id),
          for (final floor in floors) ...[
            ...floor.walls.map((w) => w.id),
            ...floor.openings.map((o) => o.id),
            ...floor.dimensions.map((d) => d.id),
            ...floor.furniture.map((f) => f.id),
            ...floor.wallFixtures.map((f) => f.id),
            ...floor.texts.map((t) => t.id),
          ],
        ]);

    final doc = Document(
      name: map['name'] as String? ?? 'Untitled Plan',
      gridSize: (map['gridSize'] as num?)?.toDouble() ?? 6.0,
      displayUnits: display,
      layers: layers,
      floors: floors,
      activeFloorId: activeFloorId,
      idGen: IdGen(idCounter),
    );
    doc.ensureDefaultLayers();
    return doc;
  }
}
