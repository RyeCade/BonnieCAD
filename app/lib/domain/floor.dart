import 'dimension.dart';
import 'furniture.dart';
import 'opening.dart';
import 'text_label.dart';
import 'wall.dart';
import 'wall_fixture.dart';

class Floor {
  Floor({
    required this.id,
    required this.name,
    List<Wall>? walls,
    List<Opening>? openings,
    List<LinearDimension>? dimensions,
    List<FurnitureItem>? furniture,
    List<WallFixture>? wallFixtures,
    List<TextLabel>? texts,
  })  : walls = walls ?? [],
        openings = openings ?? [],
        dimensions = dimensions ?? [],
        furniture = furniture ?? [],
        wallFixtures = wallFixtures ?? [],
        texts = texts ?? [];

  final String id;
  String name;
  final List<Wall> walls;
  final List<Opening> openings;
  final List<LinearDimension> dimensions;
  final List<FurnitureItem> furniture;
  final List<WallFixture> wallFixtures;
  final List<TextLabel> texts;

  Floor clone() {
    return Floor(
      id: id,
      name: name,
      walls: walls
          .map(
            (w) => Wall(
              id: w.id,
              a: w.a,
              b: w.b,
              thickness: w.thickness,
              layerId: w.layerId,
              colorValue: w.colorValue,
              strokeWidth: w.strokeWidth,
            ),
          )
          .toList(),
      openings: openings
          .map(
            (o) => Opening(
              id: o.id,
              type: o.type,
              wallId: o.wallId,
              offset: o.offset,
              width: o.width,
              swing: o.swing,
              layerId: o.layerId,
              colorValue: o.colorValue,
              strokeWidth: o.strokeWidth,
            ),
          )
          .toList(),
      dimensions: dimensions
          .map(
            (d) => LinearDimension(
              id: d.id,
              p1: d.p1,
              p2: d.p2,
              offset: d.offset,
              layerId: d.layerId,
              colorValue: d.colorValue,
              strokeWidth: d.strokeWidth,
            ),
          )
          .toList(),
      furniture: furniture
          .map(
            (f) => FurnitureItem(
              id: f.id,
              catalogId: f.catalogId,
              origin: f.origin,
              width: f.width,
              depth: f.depth,
              rotationRad: f.rotationRad,
              layerId: f.layerId,
              colorValue: f.colorValue,
              strokeWidth: f.strokeWidth,
            ),
          )
          .toList(),
      wallFixtures: wallFixtures
          .map(
            (f) => WallFixture(
              id: f.id,
              type: f.type,
              wallId: f.wallId,
              offset: f.offset,
              scale: f.scale,
              layerId: f.layerId,
              colorValue: f.colorValue,
              strokeWidth: f.strokeWidth,
            ),
          )
          .toList(),
      texts: texts
          .map(
            (t) => TextLabel(
              id: t.id,
              origin: t.origin,
              text: t.text,
              rotationRad: t.rotationRad,
              fontSizePx: t.fontSizePx,
              layerId: t.layerId,
              colorValue: t.colorValue,
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'walls': walls.map((w) => w.toJson()).toList(),
        'openings': openings.map((o) => o.toJson()).toList(),
        'dimensions': dimensions.map((d) => d.toJson()).toList(),
        'furniture': furniture.map((f) => f.toJson()).toList(),
        'wallFixtures': wallFixtures.map((f) => f.toJson()).toList(),
        'texts': texts.map((t) => t.toJson()).toList(),
      };

  factory Floor.fromJson(Map<String, dynamic> json) => Floor(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Floor',
        walls: (json['walls'] as List? ?? [])
            .map((e) => Wall.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        openings: (json['openings'] as List? ?? [])
            .map((e) => Opening.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        dimensions: (json['dimensions'] as List? ?? [])
            .map(
              (e) =>
                  LinearDimension.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        furniture: (json['furniture'] as List? ?? [])
            .map(
              (e) =>
                  FurnitureItem.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        wallFixtures: (json['wallFixtures'] as List? ?? [])
            .map(
              (e) => WallFixture.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        texts: (json['texts'] as List? ?? [])
            .map((e) => TextLabel.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}
