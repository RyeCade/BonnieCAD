import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/vec2.dart';
import '../geometry/snap.dart';
import 'editor_controller.dart';

enum ToolId { select, wall, door, window, dimension, furniture, text, pan }

abstract class EditorTool {
  ToolId get id;
  String get name;
  String get statusHint;

  void onActivate(EditorController c) {}
  void onDeactivate(EditorController c) {}

  void pointerDown(EditorController c, ToolPointerEvent e) {}
  void pointerMove(EditorController c, ToolPointerEvent e) {}
  void pointerUp(EditorController c, ToolPointerEvent e) {}

  bool keyDown(EditorController c, KeyEvent e) => false;

  void cancel(EditorController c) {}
}

class ToolPointerEvent {
  ToolPointerEvent({
    required this.screen,
    required this.world,
    required this.snapped,
    required this.buttons,
    required this.isPrimary,
    this.shift = false,
    this.ctrl = false,
    this.space = false,
  });

  final Offset screen;
  final Vec2 world;
  final SnapResult snapped;
  final int buttons;
  final bool isPrimary;
  final bool shift;
  final bool ctrl;
  final bool space;

  Vec2 get point => snapped.point;
}
