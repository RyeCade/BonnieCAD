import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/vec2.dart';
import '../../render/document_painter.dart';
import '../../tools/editor_controller.dart';
import '../../tools/select_tool.dart';
import '../../tools/tool.dart';
import '../../tools/wall_tool.dart';

class EditorCanvas extends StatefulWidget {
  const EditorCanvas({super.key, required this.controller});

  final EditorController controller;

  @override
  State<EditorCanvas> createState() => _EditorCanvasState();
}

class _EditorCanvasState extends State<EditorCanvas> {
  final FocusNode _focusNode = FocusNode();

  EditorController get c => widget.controller;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Vec2? _lockOrigin() {
    final tool = c.activeTool;
    if (tool is WallTool) return tool.startPoint;
    if (tool is SelectTool) return tool.endpointLockOrigin;
    return null;
  }

  ToolPointerEvent _event(PointerEvent e, {required bool primary}) {
    final screen = e.localPosition;
    final world = c.viewport.screenToWorld(screen);
    final snapped = c.snapWorld(world, lockOrigin: _lockOrigin());
    return ToolPointerEvent(
      screen: screen,
      world: world,
      snapped: snapped,
      buttons: e.buttons,
      isPrimary: primary,
      shift: HardwareKeyboard.instance.isShiftPressed,
      ctrl: HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed,
      space: c.spaceHeld,
    );
  }

  void _zoomAt(Offset local, double factor) {
    c.viewport.zoomAt(local, factor);
    c.refresh();
  }

  void _onPointerSignal(PointerSignalEvent signal) {
    if (signal is PointerScaleEvent) {
      // Trackpad pinch (macOS / Windows Precision Touchpad).
      final s = signal.scale;
      if (s > 0 && s.isFinite) {
        _zoomAt(signal.localPosition, s);
      }
      return;
    }
    if (signal is PointerScrollEvent) {
      final dy = signal.scrollDelta.dy;
      if (dy == 0) return;
      // Scroll / Ctrl+scroll / trackpad wheel → zoom (CAD default).
      final factor = dy > 0 ? 0.9 : 1.1;
      _zoomAt(signal.localPosition, factor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final handled = c.handleKeyDown(event);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: MouseRegion(
          cursor: SystemMouseCursors.precise,
          onHover: (e) {
            if (c.spaceHeld) return;
            c.activeTool.pointerMove(c, _event(e, primary: false));
          },
          child: GestureDetector(
            onTapDown: (_) => _focusNode.requestFocus(),
            // Two-finger pan is space/middle-mouse; scale is handled above.
            child: Listener(
              onPointerDown: (e) {
                _focusNode.requestFocus();
                final middle = e.buttons & kMiddleMouseButton != 0;
                if (middle || c.spaceHeld) {
                  c.isPanning = true;
                  c.lastPanScreen = e.localPosition;
                  return;
                }
                c.activeTool.pointerDown(
                  c,
                  _event(e, primary: e.buttons == kPrimaryButton),
                );
              },
              onPointerMove: (e) {
                if (c.isPanning && c.lastPanScreen != null) {
                  final delta = e.localPosition - c.lastPanScreen!;
                  c.viewport.panByScreen(delta);
                  c.lastPanScreen = e.localPosition;
                  c.refresh();
                  return;
                }
                c.activeTool.pointerMove(
                  c,
                  _event(e, primary: e.buttons == kPrimaryButton),
                );
              },
              onPointerUp: (e) {
                if (c.isPanning) {
                  c.isPanning = false;
                  c.lastPanScreen = null;
                  return;
                }
                c.activeTool.pointerUp(
                  c,
                  _event(e, primary: true),
                );
              },
              onPointerCancel: (_) {
                c.isPanning = false;
                c.lastPanScreen = null;
              },
              child: ListenableBuilder(
                listenable: c.canvasListenable,
                builder: (context, _) {
                  return CustomPaint(
                    isComplex: true,
                    willChange: true,
                    painter: DocumentPainter(
                      document: c.document,
                      viewport: c.viewport,
                      selectedIds: Set.of(c.selectedIds),
                      previewWall: c.previewWall,
                      previewDimension: c.previewDimension,
                      snapPoint: c.snapPoint,
                      cursorWorld: c.cursorWorld,
                      measureLabel: c.measureLabel,
                      measureLabelAt: c.measureLabelAt,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
