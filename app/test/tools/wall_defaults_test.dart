import 'package:bon_cad/core/vec2.dart';
import 'package:bon_cad/domain/commands.dart';
import 'package:bon_cad/domain/wall.dart';
import 'package:bon_cad/geometry/snap.dart';
import 'package:bon_cad/tools/editor_controller.dart';
import 'package:bon_cad/tools/tool.dart';
import 'package:bon_cad/tools/wall_tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ToolPointerEvent _tap(Vec2 p) => ToolPointerEvent(
      screen: Offset.zero,
      world: p,
      snapped: SnapResult(point: p, kind: SnapKind.none),
      buttons: 1,
      isPrimary: true,
    );

void main() {
  test('next wall reuses chosen thickness and color', () {
    final c = EditorController();
    c.document.walls.add(
      Wall(id: 'w0', a: const Vec2(0, 0), b: const Vec2(100, 0)),
    );

    c.pushCommand(
      SetWallThicknessCommand(wallId: 'w0', thickness: 5.5),
    );
    c.pushCommand(
      SetEntityStyleCommand(
        entityId: 'w0',
        entityKind: StyleEntityKind.wall,
        colorValue: 0xFFC62828,
      ),
    );

    expect(c.defaultWallThickness, 5.5);
    expect(c.defaultWallColorValue, 0xFFC62828);

    c.setTool(ToolId.wall);
    final tool = c.activeTool as WallTool;
    tool.pointerDown(c, _tap(const Vec2(0, 0)));
    tool.pointerDown(c, _tap(const Vec2(80, 0)));

    final added = c.document.walls.last;
    expect(added.id, isNot('w0'));
    expect(added.thickness, 5.5);
    expect(added.colorValue, 0xFFC62828);
    expect(c.selectedIds, {added.id});
  });

  test('clearing wall color clears default for next wall', () {
    final c = EditorController();
    c.document.walls.add(
      Wall(
        id: 'w0',
        a: const Vec2(0, 0),
        b: const Vec2(100, 0),
        colorValue: 0xFFC62828,
      ),
    );
    c.defaultWallColorValue = 0xFFC62828;

    c.pushCommand(
      SetEntityStyleCommand(
        entityId: 'w0',
        entityKind: StyleEntityKind.wall,
        clearColor: true,
      ),
    );

    expect(c.defaultWallColorValue, isNull);
  });
}
