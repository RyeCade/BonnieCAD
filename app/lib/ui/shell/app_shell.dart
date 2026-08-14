import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/units.dart';
import '../../domain/commands.dart';
import '../../domain/furniture_catalog.dart';
import '../../domain/opening.dart';
import '../../geometry/snap.dart';
import '../../persistence/file_io.dart';
import '../../tools/editor_controller.dart';
import '../../tools/tool.dart';
import '../editor/editor_canvas.dart';

const _stylePalette = <int>[
  0xFF212121,
  0xFF1565C0,
  0xFF2E7D32,
  0xFFC62828,
  0xFF6A1B9A,
  0xFFEF6C00,
  0xFF00838F,
  0xFF5D4037,
  0xFFF9A825,
  0xFF455A64,
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final EditorController controller;

  @override
  void initState() {
    super.initState();
    controller = EditorController();
    controller.onNewDocument = () {
      _new();
    };
    controller.onOpenDocument = () {
      _open();
    };
    controller.onSaveDocument = () {
      _save();
    };
    controller.onSaveDocumentAs = () {
      _save(saveAs: true);
    };
  }

  @override
  void dispose() {
    controller.onNewDocument = null;
    controller.onOpenDocument = null;
    controller.onSaveDocument = null;
    controller.onSaveDocumentAs = null;
    controller.dispose();
    super.dispose();
  }

  Future<void> _new() async {
    if (controller.dirty) {
      final ok = await _confirmDiscard();
      if (!ok) return;
    }
    controller.newDocument();
  }

  Future<void> _open() async {
    if (controller.dirty) {
      final ok = await _confirmDiscard();
      if (!ok) return;
    }
    try {
      final picked = await PlanFiles.open();
      if (picked == null) return;
      controller.loadFromText(picked.text, name: picked.name);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Open failed: $e')),
      );
    }
  }

  Future<void> _save({bool saveAs = false}) async {
    try {
      final name = controller.fileName ??
          '${controller.document.name}.boncad';
      final text = controller.encodeDocument();
      final result = await PlanFiles.saveText(name, text);
      if (!result.saved) {
        controller.setStatus('Save cancelled');
        return;
      }
      final savedName = _fileNameFromPath(result.pathOrName) ?? name;
      controller.markSaved(name: savedName);
      controller.setStatus('Saved $savedName');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  static String? _fileNameFromPath(String? pathOrName) {
    if (pathOrName == null || pathOrName.isEmpty) return null;
    final normalized = pathOrName.replaceAll('\\', '/');
    final slash = normalized.lastIndexOf('/');
    return slash >= 0 ? normalized.substring(slash + 1) : pathOrName;
  }

  Future<void> _showCode() async {
    final text = controller.encodeDocument();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Plan JSON'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: SingleChildScrollView(
            child: SelectableText(
              text,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              controller.setStatus('Copied plan JSON');
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Discard changes to the current plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final title = controller.dirty
            ? 'BonnieCAD — ${controller.document.name} *'
            : 'BonnieCAD — ${controller.document.name}';
        // Keep OS window title in sync on desktop (macOS/Windows native).
        return Title(
          title: title,
          color: Theme.of(context).colorScheme.primary,
          child: Scaffold(
            body: Column(
              children: [
                _MenuBar(
                  title: title,
                  onNew: _new,
                  onOpen: _open,
                  onSave: () => _save(),
                  onSaveAs: () => _save(saveAs: true),
                  onCode: _showCode,
                  onUndo: controller.undo,
                  onRedo: controller.redo,
                  onFit: controller.fitView,
                  onZoomIn: controller.zoomIn,
                  onZoomOut: controller.zoomOut,
                ),
                _ToolBar(controller: controller),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 720;
                      final canvas =
                          EditorCanvas(controller: controller);
                      final panel = _SidePanel(
                        controller: controller,
                        compact: narrow,
                      );
                      if (narrow) {
                        return Column(
                          children: [
                            Expanded(child: canvas),
                            SizedBox(
                              height: math.min(280, constraints.maxHeight * 0.4),
                              child: panel,
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: canvas),
                          panel,
                        ],
                      );
                    },
                  ),
                ),
                _StatusBar(controller: controller),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuBar extends StatelessWidget {
  const _MenuBar({
    required this.title,
    required this.onNew,
    required this.onOpen,
    required this.onSave,
    required this.onSaveAs,
    required this.onCode,
    required this.onUndo,
    required this.onRedo,
    required this.onFit,
    required this.onZoomIn,
    required this.onZoomOut,
  });

  final String title;
  final VoidCallback onNew;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onSaveAs;
  final VoidCallback onCode;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onFit;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF2C2C2C),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Center(
              child: Text(
                'BonnieCAD',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            _menuBtn('New', onNew, tooltip: 'New (Ctrl/Cmd+N)'),
            _menuBtn('Open', onOpen, tooltip: 'Open (Ctrl/Cmd+O)'),
            _menuBtn('Save', onSave, tooltip: 'Save (Ctrl/Cmd+S)'),
            _menuBtn('Save As', onSaveAs, tooltip: 'Save As (Ctrl/Cmd+Shift+S)'),
            _menuBtn('Code', onCode),
            _menuBtn('Undo', onUndo, tooltip: 'Undo (Ctrl/Cmd+Z)'),
            _menuBtn('Redo', onRedo, tooltip: 'Redo (Ctrl/Cmd+Y)'),
            _menuBtn('Fit', onFit, tooltip: 'Fit view (F)'),
            IconButton(
              onPressed: onZoomOut,
              icon: const Icon(Icons.remove, color: Colors.white, size: 18),
              tooltip: 'Zoom out (−)',
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onZoomIn,
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              tooltip: 'Zoom in (+)',
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 12),
            Center(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuBtn(String label, VoidCallback onPressed, {String? tooltip}) {
    final btn = TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }
}

class _ToolBar extends StatelessWidget {
  const _ToolBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    final tools = <(ToolId, IconData, String)>[
      (ToolId.select, Icons.near_me_outlined, 'Select (V)'),
      (ToolId.wall, Icons.border_style, 'Wall (W)'),
      (ToolId.door, Icons.door_front_door_outlined, 'Door (D)'),
      (ToolId.window, Icons.window_outlined, 'Window (E)'),
      (ToolId.dimension, Icons.straighten, 'Dimension (M)'),
      (ToolId.furniture, Icons.chair_outlined, 'Furniture (B)'),
      (ToolId.text, Icons.text_fields, 'Text (T)'),
    ];
    final lock = controller.snapEngine.angleLockMode;
    return Material(
      elevation: 1,
      color: const Color(0xFFEEEEEE),
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          children: [
            for (final t in tools)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.$2, size: 18),
                      const SizedBox(width: 6),
                      Text(t.$3),
                    ],
                  ),
                  selected: controller.activeToolId == t.$1,
                  onSelected: (_) => controller.setTool(t.$1),
                ),
              ),
            const VerticalDivider(),
            for (final m in [
              (AngleLockMode.free, 'Free'),
              (AngleLockMode.ortho, '90'),
              (AngleLockMode.deg45, '45°'),
              (AngleLockMode.deg15, '15°'),
            ])
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  label: Text(m.$2),
                  selected: lock == m.$1,
                  onSelected: (_) {
                    controller.snapEngine.angleLockMode = m.$1;
                    controller.notifyUi();
                  },
                ),
              ),
            const SizedBox(width: 6),
            FilterChip(
              label: const Text('Grid snap'),
              selected: controller.snapEngine.gridEnabled,
              onSelected: (v) {
                controller.snapEngine.gridEnabled = v;
                controller.notifyUi();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SidePanel extends StatefulWidget {
  const _SidePanel({required this.controller, this.compact = false});

  final EditorController controller;
  final bool compact;

  @override
  State<_SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<_SidePanel> {
  bool _floorsOpen = false;
  bool _layersOpen = false;
  bool _unitsOpen = false;
  bool _libraryOpen = false;

  EditorController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final doc = controller.document;
    final selectedWall = doc.walls
        .where((w) => controller.selectedIds.contains(w.id))
        .firstOrNull;
    final selectedOpening = doc.openings
        .where((o) => controller.selectedIds.contains(o.id))
        .firstOrNull;
    final selectedDim = doc.dimensions
        .where((d) => controller.selectedIds.contains(d.id))
        .firstOrNull;
    final selectedFurn = doc.furniture
        .where((f) => controller.selectedIds.contains(f.id))
        .firstOrNull;
    final selectedFixture = doc.wallFixtures
        .where((f) => controller.selectedIds.contains(f.id))
        .firstOrNull;
    final selectedText = doc.texts
        .where((t) => controller.selectedIds.contains(t.id))
        .firstOrNull;

    return Material(
      color: const Color(0xFFFAFAFA),
      child: SizedBox(
        width: widget.compact ? double.infinity : 280,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('Tips', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              'W wall · D door · E window · M dim · B furniture · T text\n'
              'Angle: Free / 90 / 45° / 15° · floors in panel\n'
              'Scroll / pinch / + − zoom · Space+drag pan · F fit\n'
              'Cmd/Ctrl+S save · Z undo · Y redo · Type wall length + Enter',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            if (doc.walls.isEmpty) ...[
              const SizedBox(height: 12),
              Card(
                color: const Color(0xFFFFF8E1),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Get started: choose Wall and click two points to draw your first wall. Grid is 6".',
                    style: TextStyle(
                      color: Colors.brown.shade800,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
            const Divider(),
            Text('Selection', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (selectedWall != null) ...[
              Text('Wall ${selectedWall.id}'),
              Text(
                'Length: ${Units.format(selectedWall.length, doc.displayUnits)}',
              ),
              Text(
                'Thickness: ${Units.format(selectedWall.thickness, doc.displayUnits)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final t in [2.0, 2.5, 3.0, 3.5, 4.5, 5.5, 7.25])
                    ActionChip(
                      label: Text('$t"'),
                      onPressed: () {
                        controller.pushCommand(
                          SetWallThicknessCommand(
                            wallId: selectedWall.id,
                            thickness: t,
                          ),
                        );
                      },
                    ),
                ],
              ),
              _StyleEditor(
                controller: controller,
                entityId: selectedWall.id,
                kind: StyleEntityKind.wall,
                colorValue: selectedWall.colorValue,
                strokeWidth: selectedWall.strokeWidth,
                showStroke: false,
              ),
            ] else if (selectedOpening != null) ...[
              Text(
                selectedOpening.type == OpeningType.door ? 'Door' : 'Window',
              ),
              Text(
                'Width: ${Units.format(selectedOpening.width, doc.displayUnits)}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [
                  for (final w in selectedOpening.type == OpeningType.door
                      ? const [24.0, 28.0, 30.0, 32.0, 36.0]
                      : const [24.0, 30.0, 36.0, 48.0, 60.0])
                    ActionChip(
                      label: Text('${w.toStringAsFixed(0)}"'),
                      onPressed: () {
                        controller.pushCommand(
                          SetOpeningWidthCommand(
                            openingId: selectedOpening.id,
                            width: w,
                          ),
                        );
                      },
                    ),
                ],
              ),
              if (selectedOpening.type == OpeningType.door) ...[
                const SizedBox(height: 8),
                Text('Swing', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final m in [
                      (DoorSwing.leftIn, 'L in'),
                      (DoorSwing.leftOut, 'L out'),
                      (DoorSwing.rightIn, 'R in'),
                      (DoorSwing.rightOut, 'R out'),
                    ])
                      ChoiceChip(
                        label: Text(m.$2),
                        selected: selectedOpening.swing == m.$1,
                        onSelected: (_) {
                          controller.pushCommand(
                            SetOpeningSwingCommand(
                              openingId: selectedOpening.id,
                              swing: m.$1,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'Drag end grips on canvas to resize',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              _StyleEditor(
                controller: controller,
                entityId: selectedOpening.id,
                kind: StyleEntityKind.opening,
                colorValue: selectedOpening.colorValue,
                strokeWidth: selectedOpening.strokeWidth,
              ),
            ] else if (selectedFurn != null) ...[
              Text(selectedFurn.catalogEntry?.name ?? selectedFurn.catalogId),
              Text(
                'W ${Units.format(selectedFurn.width, doc.displayUnits)} × '
                'D ${Units.format(selectedFurn.depth, doc.displayUnits)}',
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final deg in [0, 90, 180, 270])
                    ActionChip(
                      label: Text('$deg°'),
                      onPressed: () {
                        final to = deg * math.pi / 180;
                        controller.pushCommand(
                          RotateFurnitureCommand(
                            furnitureId: selectedFurn.id,
                            fromRad: selectedFurn.rotationRad,
                            toRad: to,
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Size presets', style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Default'),
                    onPressed: () {
                      final e = selectedFurn.catalogEntry;
                      if (e == null) return;
                      controller.pushCommand(
                        SetFurnitureSizeCommand(
                          furnitureId: selectedFurn.id,
                          fromWidth: selectedFurn.width,
                          fromDepth: selectedFurn.depth,
                          toWidth: e.defaultWidth,
                          toDepth: e.defaultDepth,
                        ),
                      );
                    },
                  ),
                  ActionChip(
                    label: const Text('+10%'),
                    onPressed: () {
                      controller.pushCommand(
                        SetFurnitureSizeCommand(
                          furnitureId: selectedFurn.id,
                          fromWidth: selectedFurn.width,
                          fromDepth: selectedFurn.depth,
                          toWidth: selectedFurn.width * 1.1,
                          toDepth: selectedFurn.depth * 1.1,
                        ),
                      );
                    },
                  ),
                  ActionChip(
                    label: const Text('−10%'),
                    onPressed: () {
                      controller.pushCommand(
                        SetFurnitureSizeCommand(
                          furnitureId: selectedFurn.id,
                          fromWidth: selectedFurn.width,
                          fromDepth: selectedFurn.depth,
                          toWidth: (selectedFurn.width * 0.9).clamp(6, 600),
                          toDepth: (selectedFurn.depth * 0.9).clamp(6, 600),
                        ),
                      );
                    },
                  ),
                ],
              ),
              _StyleEditor(
                controller: controller,
                entityId: selectedFurn.id,
                kind: StyleEntityKind.furniture,
                colorValue: selectedFurn.colorValue,
                strokeWidth: selectedFurn.strokeWidth,
              ),
            ] else if (selectedFixture != null) ...[
              Text('Electrical: ${selectedFixture.type.name}'),
              Text(
                'Size: ${(selectedFixture.scale * 100).round()}%',
              ),
              const SizedBox(height: 6),
              Text('Size', style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 6,
                children: [
                  for (final sc in [0.75, 1.0, 1.25, 1.5, 2.0])
                    ActionChip(
                      label: Text('${(sc * 100).round()}%'),
                      onPressed: () {
                        controller.pushCommand(
                          SetWallFixtureScaleCommand(
                            fixtureId: selectedFixture.id,
                            scale: sc,
                          ),
                        );
                      },
                    ),
                  ActionChip(
                    label: const Text('+10%'),
                    onPressed: () {
                      controller.pushCommand(
                        SetWallFixtureScaleCommand(
                          fixtureId: selectedFixture.id,
                          scale: selectedFixture.scale * 1.1,
                        ),
                      );
                    },
                  ),
                  ActionChip(
                    label: const Text('−10%'),
                    onPressed: () {
                      controller.pushCommand(
                        SetWallFixtureScaleCommand(
                          fixtureId: selectedFixture.id,
                          scale: selectedFixture.scale * 0.9,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Drag along wall to reposition',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _StyleEditor(
                controller: controller,
                entityId: selectedFixture.id,
                kind: StyleEntityKind.wallFixture,
                colorValue: selectedFixture.colorValue,
                strokeWidth: selectedFixture.strokeWidth,
              ),
            ] else if (selectedDim != null) ...[
              Text('Dimension ${selectedDim.id}'),
              Text(
                'Length: ${Units.format(selectedDim.measuredLength, doc.displayUnits)}',
              ),
              _StyleEditor(
                controller: controller,
                entityId: selectedDim.id,
                kind: StyleEntityKind.dimension,
                colorValue: selectedDim.colorValue,
                strokeWidth: selectedDim.strokeWidth,
              ),
            ] else if (selectedText != null) ...[
              Text('Text label'),
              const SizedBox(height: 6),
              _TextLabelField(
                key: ValueKey(selectedText.id),
                controller: controller,
                textId: selectedText.id,
                initialText: selectedText.text,
              ),
              const SizedBox(height: 8),
              Text('Size', style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in [10.0, 12.0, 14.0, 18.0, 24.0])
                    ActionChip(
                      label: Text('${s.toInt()}px'),
                      onPressed: () {
                        controller.pushCommand(
                          SetTextLabelPropsCommand(
                            textId: selectedText.id,
                            fromFontSizePx: selectedText.fontSizePx,
                            toFontSizePx: s,
                          ),
                        );
                      },
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Rotation', style: Theme.of(context).textTheme.bodySmall),
              Wrap(
                spacing: 6,
                children: [
                  for (final deg in [0, 90, 180, 270])
                    ActionChip(
                      label: Text('$deg°'),
                      onPressed: () {
                        final to = deg * math.pi / 180;
                        controller.pushCommand(
                          SetTextLabelPropsCommand(
                            textId: selectedText.id,
                            fromRotationRad: selectedText.rotationRad,
                            toRotationRad: to,
                          ),
                        );
                      },
                    ),
                ],
              ),
              _StyleEditor(
                controller: controller,
                entityId: selectedText.id,
                kind: StyleEntityKind.text,
                colorValue: selectedText.colorValue,
                strokeWidth: null,
                showStroke: false,
              ),
            ] else
              Text(
                controller.selectedIds.isEmpty
                    ? 'Nothing selected'
                    : '${controller.selectedIds.length} selected',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            const Divider(),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Floors',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _floorsOpen,
                onExpansionChanged: (v) => setState(() => _floorsOpen = v),
                children: [
                  for (final floor in doc.floors)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      selected: floor.id == doc.activeFloorId,
                      title: Text(floor.name),
                      leading: Icon(
                        floor.id == doc.activeFloorId
                            ? Icons.layers
                            : Icons.layers_outlined,
                        size: 20,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            tooltip: 'Rename',
                            onPressed: () => _renameFloor(
                              context,
                              controller,
                              floor.id,
                              floor.name,
                            ),
                          ),
                          if (doc.floors.length > 1)
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18),
                              tooltip: 'Delete floor',
                              onPressed: () => _deleteFloor(
                                context,
                                controller,
                                floor.id,
                                floor.name,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => controller.setActiveFloor(floor.id),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: controller.addFloor,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add floor'),
                    ),
                  ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Layers',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _layersOpen,
                onExpansionChanged: (v) => setState(() => _layersOpen = v),
                children: [
                  for (final layer in doc.layers)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(layer.name),
                      value: layer.visible,
                      onChanged: (v) {
                        if (v == null) return;
                        controller.setLayerVisible(layer.id, v);
                      },
                    ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Units',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                initiallyExpanded: _unitsOpen,
                onExpansionChanged: (v) => setState(() => _unitsOpen = v),
                children: [
                  SegmentedButton<DisplayUnitSystem>(
                    segments: const [
                      ButtonSegment(
                        value: DisplayUnitSystem.imperial,
                        label: Text('ft/in'),
                      ),
                      ButtonSegment(
                        value: DisplayUnitSystem.metric,
                        label: Text('metric'),
                      ),
                    ],
                    selected: {doc.displayUnits},
                    onSelectionChanged: (s) =>
                        controller.setDisplayUnits(s.first),
                  ),
                ],
              ),
            ),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: Text(
                  'Library',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: _libraryOpen,
                onExpansionChanged: (v) => setState(() => _libraryOpen = v),
                children: [
                  for (final cat in FurnitureCategory.values) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        FurnitureCatalog.categoryLabel(cat),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final e in FurnitureCatalog.byCategory(cat))
                          ActionChip(
                            label: Text(
                              e.name,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor:
                                controller.activeCatalogId == e.id
                                    ? Colors.blue.shade100
                                    : null,
                            onPressed: () =>
                                controller.setActiveCatalogId(e.id),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _renameFloor(
    BuildContext context,
    EditorController controller,
    String floorId,
    String current,
  ) async {
    final field = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename floor'),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, field.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    field.dispose();
    if (result != null) controller.renameFloor(floorId, result);
  }

  Future<void> _deleteFloor(
    BuildContext context,
    EditorController controller,
    String floorId,
    String name,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete floor'),
        content: Text('Delete "$name" and all geometry on it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) controller.removeFloor(floorId);
  }
}

class _StyleEditor extends StatelessWidget {
  const _StyleEditor({
    required this.controller,
    required this.entityId,
    required this.kind,
    required this.colorValue,
    required this.strokeWidth,
    this.showStroke = true,
  });

  final EditorController controller;
  final String entityId;
  final StyleEntityKind kind;
  final int? colorValue;
  final double? strokeWidth;
  final bool showStroke;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text('Color', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final c in _stylePalette)
              GestureDetector(
                onTap: () {
                  controller.pushCommand(
                    SetEntityStyleCommand(
                      entityId: entityId,
                      entityKind: kind,
                      colorValue: c,
                    ),
                  );
                },
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Color(c),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorValue == c ? Colors.black : Colors.black26,
                      width: colorValue == c ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ActionChip(
              label: const Text('Layer'),
              onPressed: () {
                controller.pushCommand(
                  SetEntityStyleCommand(
                    entityId: entityId,
                    entityKind: kind,
                    clearColor: true,
                  ),
                );
              },
            ),
            ActionChip(
              label: const Text('Custom'),
              onPressed: () => _pickCustomColor(context),
            ),
          ],
        ),
        if (showStroke) ...[
          const SizedBox(height: 8),
          Text('Stroke', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final w in [1.0, 1.5, 2.0, 3.0, 4.0])
                ActionChip(
                  label: Text('${w.toStringAsFixed(w == w.roundToDouble() ? 0 : 1)}px'),
                  onPressed: () {
                    controller.pushCommand(
                      SetEntityStyleCommand(
                        entityId: entityId,
                        entityKind: kind,
                        strokeWidth: w,
                      ),
                    );
                  },
                ),
              ActionChip(
                label: const Text('Default'),
                onPressed: () {
                  controller.pushCommand(
                    SetEntityStyleCommand(
                      entityId: entityId,
                      entityKind: kind,
                      clearStroke: true,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickCustomColor(BuildContext context) async {
    var current = Color(colorValue ?? 0xFF212121);
    final result = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Custom color'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: current,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Hue', style: Theme.of(ctx).textTheme.bodySmall),
                    Slider(
                      value: HSVColor.fromColor(current).hue,
                      max: 360,
                      onChanged: (h) {
                        final hsv = HSVColor.fromColor(current);
                        setLocal(() {
                          current = hsv.withHue(h).toColor();
                        });
                      },
                    ),
                    Text('Saturation', style: Theme.of(ctx).textTheme.bodySmall),
                    Slider(
                      value: HSVColor.fromColor(current).saturation,
                      onChanged: (s) {
                        final hsv = HSVColor.fromColor(current);
                        setLocal(() {
                          current = hsv.withSaturation(s).toColor();
                        });
                      },
                    ),
                    Text('Value', style: Theme.of(ctx).textTheme.bodySmall),
                    Slider(
                      value: HSVColor.fromColor(current).value,
                      onChanged: (v) {
                        final hsv = HSVColor.fromColor(current);
                        setLocal(() {
                          current = hsv.withValue(v).toColor();
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, current),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
    if (result == null) return;
    controller.pushCommand(
      SetEntityStyleCommand(
        entityId: entityId,
        entityKind: kind,
        colorValue: result.toARGB32(),
      ),
    );
  }
}

class _TextLabelField extends StatefulWidget {
  const _TextLabelField({
    super.key,
    required this.controller,
    required this.textId,
    required this.initialText,
  });

  final EditorController controller;
  final String textId;
  final String initialText;

  @override
  State<_TextLabelField> createState() => _TextLabelFieldState();
}

class _TextLabelFieldState extends State<_TextLabelField> {
  late final TextEditingController _field;
  late String _committed;

  @override
  void initState() {
    super.initState();
    _committed = widget.initialText;
    _field = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _commit();
    _field.dispose();
    super.dispose();
  }

  void _commit() {
    final v = _field.text;
    if (v == _committed) return;
    widget.controller.pushCommand(
      SetTextLabelContentCommand(
        textId: widget.textId,
        fromText: _committed,
        toText: v,
      ),
    );
    _committed = v;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _field,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
        labelText: 'Label',
      ),
      onChanged: (v) {
        final t = widget.controller.document.textById(widget.textId);
        if (t != null) {
          t.text = v;
          widget.controller.refresh();
        }
      },
      onSubmitted: (_) => _commit(),
      onEditingComplete: _commit,
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.controller});

  final EditorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller.canvasListenable,
      builder: (context, _) {
        final cursor = controller.cursorWorld;
        final cursorText = cursor == null
            ? ''
            : 'X ${Units.format(cursor.x, controller.document.displayUnits)}  '
                'Y ${Units.format(cursor.y, controller.document.displayUnits)}';
        final entry = controller.lengthBuffer.isEmpty
            ? ''
            : '  |  length: ${controller.lengthBuffer}';
        final zoom = '  |  ${controller.zoomPercent.toStringAsFixed(0)}%';

        return Material(
          color: const Color(0xFF37474F),
          child: SizedBox(
            height: 28,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${controller.statusMessage}$entry$zoom',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    cursorText,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
