import '../core/vec2.dart';
import 'command.dart';
import 'dimension.dart';
import 'document.dart';
import 'floor.dart';
import 'furniture.dart';
import 'opening.dart';
import 'text_label.dart';
import 'wall.dart';
import 'wall_fixture.dart';

class AddWallCommand implements Command {
  AddWallCommand(this.wall);

  final Wall wall;

  @override
  String get label => 'Add wall';

  @override
  void execute(Document doc) {
    doc.walls.add(wall);
  }

  @override
  void undo(Document doc) {
    doc.walls.removeWhere((w) => w.id == wall.id);
    doc.openings.removeWhere((o) => o.wallId == wall.id);
    doc.wallFixtures.removeWhere((f) => f.wallId == wall.id);
  }
}

class RemoveEntitiesCommand implements Command {
  RemoveEntitiesCommand({
    this.walls = const [],
    this.openings = const [],
    this.dimensions = const [],
    this.furniture = const [],
    this.wallFixtures = const [],
    this.texts = const [],
  });

  final List<Wall> walls;
  final List<Opening> openings;
  final List<LinearDimension> dimensions;
  final List<FurnitureItem> furniture;
  final List<WallFixture> wallFixtures;
  final List<TextLabel> texts;

  @override
  String get label => 'Delete';

  @override
  void execute(Document doc) {
    final wallIds = walls.map((w) => w.id).toSet();
    doc.walls.removeWhere((w) => wallIds.contains(w.id));
    doc.openings.removeWhere(
      (o) =>
          openings.any((x) => x.id == o.id) || wallIds.contains(o.wallId),
    );
    doc.wallFixtures.removeWhere(
      (f) =>
          wallFixtures.any((x) => x.id == f.id) || wallIds.contains(f.wallId),
    );
    final dimIds = dimensions.map((d) => d.id).toSet();
    doc.dimensions.removeWhere((d) => dimIds.contains(d.id));
    final furnIds = furniture.map((f) => f.id).toSet();
    doc.furniture.removeWhere((f) => furnIds.contains(f.id));
    final textIds = texts.map((t) => t.id).toSet();
    doc.texts.removeWhere((t) => textIds.contains(t.id));
  }

  @override
  void undo(Document doc) {
    doc.walls.addAll(walls);
    doc.openings.addAll(openings);
    doc.wallFixtures.addAll(wallFixtures);
    for (final w in walls) {
      for (final o in openings) {
        if (o.wallId == w.id && !doc.openings.any((x) => x.id == o.id)) {
          doc.openings.add(o);
        }
      }
      for (final f in wallFixtures) {
        if (f.wallId == w.id && !doc.wallFixtures.any((x) => x.id == f.id)) {
          doc.wallFixtures.add(f);
        }
      }
    }
    doc.dimensions.addAll(dimensions);
    doc.furniture.addAll(furniture);
    doc.texts.addAll(texts);
  }
}

class MoveWallEndpointCommand implements Command {
  MoveWallEndpointCommand({
    required this.wallId,
    required this.moveA,
    required this.from,
    required this.to,
  });

  final String wallId;
  final bool moveA;
  final Vec2 from;
  final Vec2 to;

  @override
  String get label => 'Move wall endpoint';

  @override
  void execute(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null) return;
    if (moveA) {
      w.a = to;
    } else {
      w.b = to;
    }
    _clampOpenings(doc, w);
    _clampFixtures(doc, w);
  }

  @override
  void undo(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null) return;
    if (moveA) {
      w.a = from;
    } else {
      w.b = from;
    }
    _clampOpenings(doc, w);
    _clampFixtures(doc, w);
  }

  void _clampOpenings(Document doc, Wall w) {
    for (final o in doc.openings.where((o) => o.wallId == w.id)) {
      final maxStart = (w.length - o.width).clamp(0.0, double.infinity);
      o.offset = o.offset.clamp(0.0, maxStart);
    }
  }

  void _clampFixtures(Document doc, Wall w) {
    for (final f in doc.wallFixtures.where((f) => f.wallId == w.id)) {
      f.offset = f.offset.clamp(0.0, w.length);
    }
  }
}

class TranslateWallCommand implements Command {
  TranslateWallCommand({
    required this.wallId,
    required this.delta,
  });

  final String wallId;
  final Vec2 delta;

  @override
  String get label => 'Move wall';

  @override
  void execute(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null) return;
    w.a = w.a + delta;
    w.b = w.b + delta;
  }

  @override
  void undo(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null) return;
    w.a = w.a - delta;
    w.b = w.b - delta;
  }
}

class AddOpeningCommand implements Command {
  AddOpeningCommand(this.opening);

  final Opening opening;

  @override
  String get label =>
      opening.type == OpeningType.door ? 'Add door' : 'Add window';

  @override
  void execute(Document doc) {
    doc.openings.add(opening);
  }

  @override
  void undo(Document doc) {
    doc.openings.removeWhere((o) => o.id == opening.id);
  }
}

class SetOpeningGeometryCommand implements Command {
  SetOpeningGeometryCommand({
    required this.openingId,
    required this.fromOffset,
    required this.fromWidth,
    required this.toOffset,
    required this.toWidth,
  });

  final String openingId;
  final double fromOffset;
  final double fromWidth;
  final double toOffset;
  final double toWidth;

  @override
  String get label =>
      (fromWidth - toWidth).abs() < 0.01 ? 'Move opening' : 'Resize opening';

  @override
  void execute(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null) return;
    o.offset = toOffset;
    o.width = toWidth;
  }

  @override
  void undo(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null) return;
    o.offset = fromOffset;
    o.width = fromWidth;
  }
}

class SetOpeningWidthCommand implements Command {
  SetOpeningWidthCommand({
    required this.openingId,
    required this.width,
  });

  final String openingId;
  final double width;
  double? _previousOffset;
  double? _previousWidth;

  @override
  String get label => 'Set opening width';

  @override
  void execute(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null) return;
    final wall = doc.wallById(o.wallId);
    final wallLen = wall?.length ?? width;
    final w = width.clamp(12.0, wallLen);
    _previousOffset = o.offset;
    _previousWidth = o.width;

    final hingeLeft = o.swing == DoorSwing.leftIn || o.swing == DoorSwing.leftOut;
    if (o.type == OpeningType.door && !hingeLeft) {
      final end = o.offset + o.width;
      o.width = w;
      o.offset = (end - w).clamp(0.0, (wallLen - w).clamp(0.0, double.infinity));
    } else {
      o.width = w;
      final maxStart = (wallLen - w).clamp(0.0, double.infinity);
      o.offset = o.offset.clamp(0.0, maxStart);
    }
  }

  @override
  void undo(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null || _previousOffset == null || _previousWidth == null) return;
    o.offset = _previousOffset!;
    o.width = _previousWidth!;
  }
}

class SetOpeningSwingCommand implements Command {
  SetOpeningSwingCommand({
    required this.openingId,
    required this.swing,
  });

  final String openingId;
  final DoorSwing swing;
  DoorSwing? _previous;

  @override
  String get label => 'Set door swing';

  @override
  void execute(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null) return;
    _previous = o.swing;
    o.swing = swing;
  }

  @override
  void undo(Document doc) {
    final o = doc.openingById(openingId);
    if (o == null || _previous == null) return;
    o.swing = _previous!;
  }
}

class AddDimensionCommand implements Command {
  AddDimensionCommand(this.dimension);

  final LinearDimension dimension;

  @override
  String get label => 'Add dimension';

  @override
  void execute(Document doc) {
    doc.dimensions.add(dimension);
  }

  @override
  void undo(Document doc) {
    doc.dimensions.removeWhere((d) => d.id == dimension.id);
  }
}

class SetLayerVisibilityCommand implements Command {
  SetLayerVisibilityCommand({
    required this.layerId,
    required this.visible,
  });

  final String layerId;
  final bool visible;
  bool? _previous;

  @override
  String get label => 'Toggle layer';

  @override
  void execute(Document doc) {
    final layer = doc.layerById(layerId);
    if (layer == null) return;
    _previous = layer.visible;
    layer.visible = visible;
  }

  @override
  void undo(Document doc) {
    final layer = doc.layerById(layerId);
    if (layer == null || _previous == null) return;
    layer.visible = _previous!;
  }
}

class SetWallThicknessCommand implements Command {
  SetWallThicknessCommand({
    required this.wallId,
    required this.thickness,
  });

  final String wallId;
  final double thickness;
  double? _previous;

  @override
  String get label => 'Set wall thickness';

  @override
  void execute(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null) return;
    _previous = w.thickness;
    w.thickness = thickness;
  }

  @override
  void undo(Document doc) {
    final w = doc.wallById(wallId);
    if (w == null || _previous == null) return;
    w.thickness = _previous!;
  }
}

class SetEntityStyleCommand implements Command {
  SetEntityStyleCommand({
    required this.entityId,
    required this.entityKind,
    this.colorValue,
    this.strokeWidth,
    this.clearColor = false,
    this.clearStroke = false,
  });

  final String entityId;
  final StyleEntityKind entityKind;
  final int? colorValue;
  final double? strokeWidth;
  final bool clearColor;
  final bool clearStroke;

  int? _prevColor;
  double? _prevStroke;
  bool _hadColor = false;
  bool _hadStroke = false;

  @override
  String get label => 'Set style';

  @override
  void execute(Document doc) {
    switch (entityKind) {
      case StyleEntityKind.wall:
        final w = doc.wallById(entityId);
        if (w == null) return;
        _prevColor = w.colorValue;
        _prevStroke = w.strokeWidth;
        _hadColor = w.colorValue != null;
        _hadStroke = w.strokeWidth != null;
        if (clearColor) {
          w.colorValue = null;
        } else if (colorValue != null) {
          w.colorValue = colorValue;
        }
        if (clearStroke) {
          w.strokeWidth = null;
        } else if (strokeWidth != null) {
          w.strokeWidth = strokeWidth;
        }
      case StyleEntityKind.opening:
        final o = doc.openingById(entityId);
        if (o == null) return;
        _prevColor = o.colorValue;
        _prevStroke = o.strokeWidth;
        _hadColor = o.colorValue != null;
        _hadStroke = o.strokeWidth != null;
        if (clearColor) {
          o.colorValue = null;
        } else if (colorValue != null) {
          o.colorValue = colorValue;
        }
        if (clearStroke) {
          o.strokeWidth = null;
        } else if (strokeWidth != null) {
          o.strokeWidth = strokeWidth;
        }
      case StyleEntityKind.dimension:
        final d = doc.dimensionById(entityId);
        if (d == null) return;
        _prevColor = d.colorValue;
        _prevStroke = d.strokeWidth;
        _hadColor = d.colorValue != null;
        _hadStroke = d.strokeWidth != null;
        if (clearColor) {
          d.colorValue = null;
        } else if (colorValue != null) {
          d.colorValue = colorValue;
        }
        if (clearStroke) {
          d.strokeWidth = null;
        } else if (strokeWidth != null) {
          d.strokeWidth = strokeWidth;
        }
      case StyleEntityKind.furniture:
        final f = doc.furnitureById(entityId);
        if (f == null) return;
        _prevColor = f.colorValue;
        _prevStroke = f.strokeWidth;
        _hadColor = f.colorValue != null;
        _hadStroke = f.strokeWidth != null;
        if (clearColor) {
          f.colorValue = null;
        } else if (colorValue != null) {
          f.colorValue = colorValue;
        }
        if (clearStroke) {
          f.strokeWidth = null;
        } else if (strokeWidth != null) {
          f.strokeWidth = strokeWidth;
        }
      case StyleEntityKind.wallFixture:
        final f = doc.wallFixtureById(entityId);
        if (f == null) return;
        _prevColor = f.colorValue;
        _prevStroke = f.strokeWidth;
        _hadColor = f.colorValue != null;
        _hadStroke = f.strokeWidth != null;
        if (clearColor) {
          f.colorValue = null;
        } else if (colorValue != null) {
          f.colorValue = colorValue;
        }
        if (clearStroke) {
          f.strokeWidth = null;
        } else if (strokeWidth != null) {
          f.strokeWidth = strokeWidth;
        }
      case StyleEntityKind.text:
        final t = doc.textById(entityId);
        if (t == null) return;
        _prevColor = t.colorValue;
        _hadColor = t.colorValue != null;
        if (clearColor) {
          t.colorValue = null;
        } else if (colorValue != null) {
          t.colorValue = colorValue;
        }
    }
  }

  @override
  void undo(Document doc) {
    switch (entityKind) {
      case StyleEntityKind.wall:
        final w = doc.wallById(entityId);
        if (w == null) return;
        w.colorValue = _hadColor ? _prevColor : null;
        w.strokeWidth = _hadStroke ? _prevStroke : null;
      case StyleEntityKind.opening:
        final o = doc.openingById(entityId);
        if (o == null) return;
        o.colorValue = _hadColor ? _prevColor : null;
        o.strokeWidth = _hadStroke ? _prevStroke : null;
      case StyleEntityKind.dimension:
        final d = doc.dimensionById(entityId);
        if (d == null) return;
        d.colorValue = _hadColor ? _prevColor : null;
        d.strokeWidth = _hadStroke ? _prevStroke : null;
      case StyleEntityKind.furniture:
        final f = doc.furnitureById(entityId);
        if (f == null) return;
        f.colorValue = _hadColor ? _prevColor : null;
        f.strokeWidth = _hadStroke ? _prevStroke : null;
      case StyleEntityKind.wallFixture:
        final f = doc.wallFixtureById(entityId);
        if (f == null) return;
        f.colorValue = _hadColor ? _prevColor : null;
        f.strokeWidth = _hadStroke ? _prevStroke : null;
      case StyleEntityKind.text:
        final t = doc.textById(entityId);
        if (t == null) return;
        t.colorValue = _hadColor ? _prevColor : null;
    }
  }
}

enum StyleEntityKind { wall, opening, dimension, furniture, wallFixture, text }

class AddFurnitureCommand implements Command {
  AddFurnitureCommand(this.item);

  final FurnitureItem item;

  @override
  String get label => 'Add furniture';

  @override
  void execute(Document doc) {
    doc.furniture.add(item);
  }

  @override
  void undo(Document doc) {
    doc.furniture.removeWhere((f) => f.id == item.id);
  }
}

class TranslateFurnitureCommand implements Command {
  TranslateFurnitureCommand({
    required this.furnitureId,
    required this.delta,
  });

  final String furnitureId;
  final Vec2 delta;

  @override
  String get label => 'Move furniture';

  @override
  void execute(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.origin = f.origin + delta;
  }

  @override
  void undo(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.origin = f.origin - delta;
  }
}

class RotateFurnitureCommand implements Command {
  RotateFurnitureCommand({
    required this.furnitureId,
    required this.fromRad,
    required this.toRad,
  });

  final String furnitureId;
  final double fromRad;
  final double toRad;

  @override
  String get label => 'Rotate furniture';

  @override
  void execute(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.rotationRad = toRad;
  }

  @override
  void undo(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.rotationRad = fromRad;
  }
}

class SetFurnitureSizeCommand implements Command {
  SetFurnitureSizeCommand({
    required this.furnitureId,
    required this.fromWidth,
    required this.fromDepth,
    required this.toWidth,
    required this.toDepth,
  });

  final String furnitureId;
  final double fromWidth;
  final double fromDepth;
  final double toWidth;
  final double toDepth;

  @override
  String get label => 'Resize furniture';

  @override
  void execute(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.width = toWidth;
    f.depth = toDepth;
  }

  @override
  void undo(Document doc) {
    final f = doc.furnitureById(furnitureId);
    if (f == null) return;
    f.width = fromWidth;
    f.depth = fromDepth;
  }
}

class AddWallFixtureCommand implements Command {
  AddWallFixtureCommand(this.fixture);

  final WallFixture fixture;

  @override
  String get label => 'Add electrical';

  @override
  void execute(Document doc) {
    doc.wallFixtures.add(fixture);
  }

  @override
  void undo(Document doc) {
    doc.wallFixtures.removeWhere((f) => f.id == fixture.id);
  }
}

class MoveWallFixtureCommand implements Command {
  MoveWallFixtureCommand({
    required this.fixtureId,
    required this.fromOffset,
    required this.toOffset,
  });

  final String fixtureId;
  final double fromOffset;
  final double toOffset;

  @override
  String get label => 'Move fixture';

  @override
  void execute(Document doc) {
    final f = doc.wallFixtureById(fixtureId);
    if (f == null) return;
    f.offset = toOffset;
  }

  @override
  void undo(Document doc) {
    final f = doc.wallFixtureById(fixtureId);
    if (f == null) return;
    f.offset = fromOffset;
  }
}

class SetWallFixtureScaleCommand implements Command {
  SetWallFixtureScaleCommand({
    required this.fixtureId,
    required this.scale,
  });

  final String fixtureId;
  final double scale;
  double? _previous;

  @override
  String get label => 'Resize fixture';

  @override
  void execute(Document doc) {
    final f = doc.wallFixtureById(fixtureId);
    if (f == null) return;
    _previous = f.scale;
    f.scale = scale.clamp(0.25, 12.0);
  }

  @override
  void undo(Document doc) {
    final f = doc.wallFixtureById(fixtureId);
    if (f == null || _previous == null) return;
    f.scale = _previous!;
  }
}

class AddTextLabelCommand implements Command {
  AddTextLabelCommand(this.textLabel);

  final TextLabel textLabel;

  @override
  String get label => 'Add text';

  @override
  void execute(Document doc) {
    doc.texts.add(textLabel);
  }

  @override
  void undo(Document doc) {
    doc.texts.removeWhere((t) => t.id == textLabel.id);
  }
}

class MoveTextLabelCommand implements Command {
  MoveTextLabelCommand({
    required this.textId,
    required this.from,
    required this.to,
  });

  final String textId;
  final Vec2 from;
  final Vec2 to;

  @override
  String get label => 'Move text';

  @override
  void execute(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    t.origin = to;
  }

  @override
  void undo(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    t.origin = from;
  }
}

class SetTextLabelContentCommand implements Command {
  SetTextLabelContentCommand({
    required this.textId,
    required this.fromText,
    required this.toText,
  });

  final String textId;
  final String fromText;
  final String toText;

  @override
  String get label => 'Edit text';

  @override
  void execute(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    t.text = toText;
  }

  @override
  void undo(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    t.text = fromText;
  }
}

class SetTextLabelPropsCommand implements Command {
  SetTextLabelPropsCommand({
    required this.textId,
    this.fromFontSizePx,
    this.toFontSizePx,
    this.fromRotationRad,
    this.toRotationRad,
  });

  final String textId;
  final double? fromFontSizePx;
  final double? toFontSizePx;
  final double? fromRotationRad;
  final double? toRotationRad;

  @override
  String get label => 'Edit text props';

  @override
  void execute(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    if (toFontSizePx != null) t.fontSizePx = toFontSizePx!;
    if (toRotationRad != null) t.rotationRad = toRotationRad!;
  }

  @override
  void undo(Document doc) {
    final t = doc.textById(textId);
    if (t == null) return;
    if (fromFontSizePx != null) t.fontSizePx = fromFontSizePx!;
    if (fromRotationRad != null) t.rotationRad = fromRotationRad!;
  }
}

class AddFloorCommand implements Command {
  AddFloorCommand(this.floor);

  final Floor floor;
  String? _prevActive;

  @override
  String get label => 'Add floor';

  @override
  void execute(Document doc) {
    _prevActive = doc.activeFloorId;
    doc.floors.add(floor);
    doc.activeFloorId = floor.id;
  }

  @override
  void undo(Document doc) {
    doc.floors.removeWhere((f) => f.id == floor.id);
    if (_prevActive != null && doc.floorById(_prevActive!) != null) {
      doc.activeFloorId = _prevActive!;
    } else if (doc.floors.isNotEmpty) {
      doc.activeFloorId = doc.floors.first.id;
    }
  }
}

class RemoveFloorCommand implements Command {
  RemoveFloorCommand({
    required this.floor,
    required this.index,
    required this.fallbackActiveId,
  });

  final Floor floor;
  final int index;
  final String fallbackActiveId;
  String? _prevActive;

  @override
  String get label => 'Delete floor';

  @override
  void execute(Document doc) {
    if (doc.floors.length <= 1) return;
    _prevActive = doc.activeFloorId;
    doc.floors.removeWhere((f) => f.id == floor.id);
    if (doc.activeFloorId == floor.id) {
      doc.activeFloorId = fallbackActiveId;
    }
  }

  @override
  void undo(Document doc) {
    final i = index.clamp(0, doc.floors.length);
    doc.floors.insert(i, floor);
    if (_prevActive != null) doc.activeFloorId = _prevActive!;
  }
}

class RenameFloorCommand implements Command {
  RenameFloorCommand({
    required this.floorId,
    required this.fromName,
    required this.toName,
  });

  final String floorId;
  final String fromName;
  final String toName;

  @override
  String get label => 'Rename floor';

  @override
  void execute(Document doc) {
    final f = doc.floorById(floorId);
    if (f == null) return;
    f.name = toName;
  }

  @override
  void undo(Document doc) {
    final f = doc.floorById(floorId);
    if (f == null) return;
    f.name = fromName;
  }
}
