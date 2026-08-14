import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../core/units.dart';
import '../core/vec2.dart';
import '../domain/command.dart';
import '../domain/commands.dart';
import '../domain/dimension.dart';
import '../domain/document.dart';
import '../domain/floor.dart';
import '../domain/furniture.dart';
import '../domain/history.dart';
import '../domain/opening.dart';
import '../domain/text_label.dart';
import '../domain/wall.dart';
import '../domain/wall_fixture.dart';
import '../geometry/snap.dart';
import '../persistence/document_codec.dart';
import '../render/viewport.dart';
import 'dimension_tool.dart';
import 'furniture_tool.dart';
import 'opening_tool.dart';
import 'select_tool.dart';
import 'text_tool.dart';
import 'tool.dart';
import 'wall_tool.dart';

class EditorController extends ChangeNotifier {
  EditorController() {
    document = Document.empty();
    history = History();
    viewport = CadViewport(scale: 2.5);
    snapEngine = SnapEngine();
    _tools = {
      ToolId.select: SelectTool(),
      ToolId.wall: WallTool(),
      ToolId.door: OpeningTool(OpeningType.door),
      ToolId.window: OpeningTool(OpeningType.window),
      ToolId.dimension: DimensionTool(),
      ToolId.furniture: FurnitureTool(),
      ToolId.text: TextTool(),
    };
    activeToolId = ToolId.wall;
    _tools[activeToolId]!.onActivate(this);
  }

  /// Canvas/status-only updates (pointer move, pan, zoom) — not full chrome.
  final ChangeNotifier canvasListenable = ChangeNotifier();

  late Document document;
  late History history;
  late CadViewport viewport;
  late SnapEngine snapEngine;
  late Map<ToolId, EditorTool> _tools;

  ToolId activeToolId = ToolId.select;
  final Set<String> selectedIds = {};
  String? activeCatalogId;

  Wall? previewWall;
  (Vec2, Vec2)? previewDimension;
  Vec2? snapPoint;
  Vec2? cursorWorld;
  /// Live size callout while resizing (e.g. door width).
  String? measureLabel;
  Vec2? measureLabelAt;
  String statusMessage = 'Draw walls to start your floor plan';
  String lengthBuffer = '';

  bool dirty = false;
  String? fileName;
  bool spaceHeld = false;
  bool isPanning = false;
  Offset? lastPanScreen;

  static const snapTolerancePx = 12.0;
  static const zoomFactor = 1.15;

  EditorTool get activeTool => _tools[activeToolId]!;

  double get zoomPercent => (viewport.scale / 2.5) * 100;

  void setTool(ToolId id) {
    if (id == activeToolId) return;
    activeTool.cancel(this);
    activeTool.onDeactivate(this);
    activeToolId = id;
    activeTool.onActivate(this);
    previewWall = null;
    previewDimension = null;
    lengthBuffer = '';
    statusMessage = activeTool.statusHint;
    notifyListeners();
  }

  void setActiveCatalogId(String id) {
    activeCatalogId = id;
    setTool(ToolId.furniture);
    notifyListeners();
  }

  double get snapToleranceWorld =>
      viewport.screenPixelsToWorld(snapTolerancePx);

  SnapResult snapWorld(
    Vec2 raw, {
    Vec2? lockOrigin,
    String? ignoreWallId,
  }) {
    return snapEngine.snap(
      doc: document,
      raw: raw,
      toleranceWorld: snapToleranceWorld,
      lockOrigin: lockOrigin,
      ignoreWallId: ignoreWallId,
    );
  }

  void setActiveFloor(String floorId) {
    if (document.floorById(floorId) == null) return;
    if (document.activeFloorId == floorId) return;
    activeTool.cancel(this);
    document.activeFloorId = floorId;
    selectedIds.clear();
    previewWall = null;
    previewDimension = null;
    lengthBuffer = '';
    statusMessage = 'Floor: ${document.activeFloor.name}';
    final b = document.bounds();
    if (b != null) {
      viewport.fitToBounds(b.min, b.max);
    }
    dirty = true;
    notifyListeners();
  }

  void addFloor() {
    final n = document.floors.length + 1;
    final floor = Floor(
      id: document.idGen.next('fl'),
      name: 'Floor $n',
    );
    pushCommand(AddFloorCommand(floor));
    selectedIds.clear();
    statusMessage = 'Floor: ${floor.name}';
  }

  void renameFloor(String floorId, String name) {
    final f = document.floorById(floorId);
    if (f == null) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == f.name) return;
    pushCommand(
      RenameFloorCommand(
        floorId: floorId,
        fromName: f.name,
        toName: trimmed,
      ),
    );
  }

  void removeFloor(String floorId) {
    if (document.floors.length <= 1) return;
    final floor = document.floorById(floorId);
    if (floor == null) return;
    final index = document.floors.indexWhere((f) => f.id == floorId);
    final fallback = document.floors.firstWhere((f) => f.id != floorId);
    final snapshot = floor.clone();
    pushCommand(
      RemoveFloorCommand(
        floor: snapshot,
        index: index,
        fallbackActiveId: fallback.id,
      ),
    );
    selectedIds.clear();
    statusMessage = 'Floor: ${document.activeFloor.name}';
  }

  void pushCommand(Command command) {
    history.push(command, document);
    dirty = true;
    notifyListeners();
  }

  void undo() {
    if (history.undo(document)) {
      dirty = true;
      selectedIds.clear();
      notifyListeners();
    }
  }

  void redo() {
    if (history.redo(document)) {
      dirty = true;
      selectedIds.clear();
      notifyListeners();
    }
  }

  void newDocument() {
    document = Document.empty();
    history.clear();
    selectedIds.clear();
    dirty = false;
    fileName = null;
    previewWall = null;
    previewDimension = null;
    statusMessage = 'New plan';
    notifyListeners();
  }

  void loadFromText(String text, {String? name}) {
    document = DocumentCodec.decode(text);
    history.clear();
    selectedIds.clear();
    dirty = false;
    fileName = name ?? document.name;
    statusMessage = 'Opened ${document.name}';
    final b = document.bounds();
    if (b != null) {
      viewport.fitToBounds(b.min, b.max);
    }
    notifyListeners();
  }

  String encodeDocument() => DocumentCodec.encode(document);

  void markSaved({String? name}) {
    if (name != null) fileName = name;
    dirty = false;
    statusMessage = 'Saved';
    notifyListeners();
  }

  void deleteSelection() {
    if (selectedIds.isEmpty) return;
    final walls = document.walls
        .where((w) => selectedIds.contains(w.id))
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
        .toList();
    final wallIds = walls.map((w) => w.id).toSet();
    final openings = document.openings
        .where(
          (o) => selectedIds.contains(o.id) || wallIds.contains(o.wallId),
        )
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
        .toList();
    final fixtures = document.wallFixtures
        .where(
          (f) => selectedIds.contains(f.id) || wallIds.contains(f.wallId),
        )
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
        .toList();
    final dims = document.dimensions
        .where((d) => selectedIds.contains(d.id))
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
        .toList();
    final furn = document.furniture
        .where((f) => selectedIds.contains(f.id))
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
        .toList();
    final texts = document.texts
        .where((t) => selectedIds.contains(t.id))
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
        .toList();
    if (walls.isEmpty &&
        openings.isEmpty &&
        dims.isEmpty &&
        furn.isEmpty &&
        fixtures.isEmpty &&
        texts.isEmpty) {
      return;
    }
    pushCommand(
      RemoveEntitiesCommand(
        walls: walls,
        openings: openings,
        dimensions: dims,
        furniture: furn,
        wallFixtures: fixtures,
        texts: texts,
      ),
    );
    selectedIds.clear();
  }

  void fitView() {
    final b = document.bounds();
    if (b == null) {
      viewport.pan = Vec2.zero;
      viewport.scale = 2.5;
    } else {
      viewport.fitToBounds(b.min, b.max);
    }
    notifyListeners();
  }

  void zoomIn() => _zoomBy(zoomFactor);

  void zoomOut() => _zoomBy(1 / zoomFactor);

  void _zoomBy(double factor) {
    final focus = cursorWorld != null
        ? viewport.worldToScreen(cursorWorld!)
        : Offset(viewport.size.width / 2, viewport.size.height / 2);
    viewport.zoomAt(focus, factor);
    notifyListeners();
  }

  void setLayerVisible(String layerId, bool visible) {
    pushCommand(SetLayerVisibilityCommand(layerId: layerId, visible: visible));
  }

  void setDisplayUnits(DisplayUnitSystem system) {
    document.displayUnits = system;
    dirty = true;
    notifyListeners();
  }

  void setStatus(String msg) {
    if (statusMessage == msg) return;
    statusMessage = msg;
    // Status bar listens to canvas; avoid rebuilding toolbar/side panel.
    refresh();
  }

  /// Fast path for pointer move / pan / zoom — canvas + status only.
  void refresh() {
    canvasListenable.notifyListeners();
  }

  /// Full chrome rebuild (selection, tools, document edits already via pushCommand).
  void notifyUi() => notifyListeners();

  @override
  void notifyListeners() {
    super.notifyListeners();
    canvasListenable.notifyListeners();
  }

  @override
  void dispose() {
    canvasListenable.dispose();
    super.dispose();
  }

  /// Optional shell actions (file menu) — set by [AppShell].
  VoidCallback? onNewDocument;
  VoidCallback? onOpenDocument;
  VoidCallback? onSaveDocument;
  VoidCallback? onSaveDocumentAs;

  bool handleKeyDown(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.space) {
        spaceHeld = false;
        return true;
      }
      return false;
    }

    final key = event.logicalKey;
    // Ctrl (Windows/Linux) and Cmd (macOS) both count as the primary modifier.
    final primary = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    if (key == LogicalKeyboardKey.space) {
      spaceHeld = true;
      return true;
    }

    // File shortcuts (Cmd/Ctrl+N/O/S)
    if (primary && key == LogicalKeyboardKey.keyN) {
      onNewDocument?.call();
      return true;
    }
    if (primary && key == LogicalKeyboardKey.keyO) {
      onOpenDocument?.call();
      return true;
    }
    if (primary && key == LogicalKeyboardKey.keyS) {
      if (shift) {
        onSaveDocumentAs?.call();
      } else {
        onSaveDocument?.call();
      }
      return true;
    }

    if (primary && key == LogicalKeyboardKey.keyZ && !shift) {
      undo();
      return true;
    }
    if (primary &&
        (key == LogicalKeyboardKey.keyY ||
            (key == LogicalKeyboardKey.keyZ && shift))) {
      redo();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      activeTool.cancel(this);
      lengthBuffer = '';
      refresh();
      return true;
    }
    if ((key == LogicalKeyboardKey.delete ||
            key == LogicalKeyboardKey.backspace) &&
        lengthBuffer.isEmpty) {
      deleteSelection();
      return true;
    }

    // Zoom shortcuts (before length entry so - isn't eaten when buffer empty)
    if (lengthBuffer.isEmpty) {
      if (key == LogicalKeyboardKey.equal ||
          key == LogicalKeyboardKey.numpadAdd ||
          (primary && key == LogicalKeyboardKey.equal)) {
        zoomIn();
        return true;
      }
      if (key == LogicalKeyboardKey.minus ||
          key == LogicalKeyboardKey.numpadSubtract) {
        zoomOut();
        return true;
      }
    }

    if (_isLengthKey(key)) {
      final ch = _keyToChar(key);
      if (ch != null) {
        lengthBuffer += ch;
        refresh();
        return true;
      }
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (lengthBuffer.isNotEmpty && activeTool is WallTool) {
        (activeTool as WallTool).commitLength(this, lengthBuffer);
        lengthBuffer = '';
        refresh();
        return true;
      }
    }
    if (key == LogicalKeyboardKey.backspace && lengthBuffer.isNotEmpty) {
      lengthBuffer = lengthBuffer.substring(0, lengthBuffer.length - 1);
      refresh();
      return true;
    }

    if (!primary) {
      switch (key) {
        case LogicalKeyboardKey.keyV:
          setTool(ToolId.select);
          return true;
        case LogicalKeyboardKey.keyW:
          setTool(ToolId.wall);
          return true;
        case LogicalKeyboardKey.keyD:
          setTool(ToolId.door);
          return true;
        case LogicalKeyboardKey.keyE:
          setTool(ToolId.window);
          return true;
        case LogicalKeyboardKey.keyM:
          setTool(ToolId.dimension);
          return true;
        case LogicalKeyboardKey.keyB:
          setTool(ToolId.furniture);
          return true;
        case LogicalKeyboardKey.keyT:
          setTool(ToolId.text);
          return true;
        case LogicalKeyboardKey.keyF:
          fitView();
          return true;
        default:
          break;
      }
    }

    return activeTool.keyDown(this, event);
  }

  bool _isLengthKey(LogicalKeyboardKey key) {
    return (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
            key.keyId <= LogicalKeyboardKey.digit9.keyId) ||
        (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
            key.keyId <= LogicalKeyboardKey.numpad9.keyId) ||
        key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal ||
        key == LogicalKeyboardKey.quote ||
        key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.slash;
  }

  String? _keyToChar(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.period ||
        key == LogicalKeyboardKey.numpadDecimal) {
      return '.';
    }
    if (key == LogicalKeyboardKey.quote) return "'";
    if (key == LogicalKeyboardKey.slash) return '"';
    if (key == LogicalKeyboardKey.minus) return '-';
    if (key.keyId >= LogicalKeyboardKey.digit0.keyId &&
        key.keyId <= LogicalKeyboardKey.digit9.keyId) {
      return String.fromCharCode(
        48 + (key.keyId - LogicalKeyboardKey.digit0.keyId),
      );
    }
    if (key.keyId >= LogicalKeyboardKey.numpad0.keyId &&
        key.keyId <= LogicalKeyboardKey.numpad9.keyId) {
      return String.fromCharCode(
        48 + (key.keyId - LogicalKeyboardKey.numpad0.keyId),
      );
    }
    return null;
  }
}
