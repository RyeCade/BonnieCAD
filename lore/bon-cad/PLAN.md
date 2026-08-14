# BonnieCAD Feature Plan — Multi-floor, Text, Color Picker, Angle Snap + Opening UX

Add multi-floor documents (floor-owned geometry), free text labels, a Custom color dialog beside swatches, and replace Ortho with Free/90/45°/15° lock for wall drafting. Follow-on: door swing/size/color UX, live measure labels, canvas perf. Builds on the Flutter web app under `app/`. Decisions: D17–D31 in `DECISIONS.md`.

> **Agent Reminder:** Update this plan document to mark each step as it is completed (`[ ]` → `[/]` → `[x]`).

## Status snapshot

- Multi-floor / text / angle / color: implemented 2026-08-06
- Opening UX + perf: implemented 2026-08-07
- Schema: **v3** (v1/v2 load as Main floor)
- `dart analyze` clean · `flutter test` passing
- Run: double-click launcher or `cd app && flutter run -d chrome`

- [x] 1. Domain: Floor + Document active-floor accessors (D17, D19)
   - [x] a–f. Floor model, Document floors/activeFloorId, active-floor getters

- [x] 2. Domain: TextLabel entity (D20, D25)
   - [x] a–c. text_label.dart, floor lists, bounds

- [x] 3. Commands for floors and text (D17, D21)
   - [x] a–e. Floor/text commands, RemoveEntities texts, StyleEntityKind.text, history tests

- [x] 4. Codec schema v3 + migration (D26)
   - [x] a–e. encode floors, v1/v2 wrap Main, codec tests

- [x] 5. Angle lock mode (D23, D24)
   - [x] a–i. AngleLockMode, angleLock, wall + endpoint, UI chips, tests

- [x] 6. Text tool + selection + paint (D20, D21, D25)
   - [x] a–f. TextTool T, select/move, painter, side panel

- [x] 7. Side panel: floors (D18)
   - [x] a–e. list, add, rename, delete

- [x] 8. Custom color picker (D22)
   - [x] a–d. Custom HSV dialog, no new package

- [x] 9. Controller / painter / snap call-site sweep
   - [x] a–d. active floor accessors

- [x] 10. Quality gates and docs
   - [x] a. `dart analyze` clean
   - [x] b. `flutter test` all passing
   - [x] c. README updated
   - [x] d. RESEARCH brief update
   - [x] e. Manual Chrome smoke deferred to user

- [x] 11. Explicit non-goals (this plan)
   - [x] a–g. retained

- [x] 12. Opening edit UX (D27–D29, D31)
   - [x] a. Side-panel door swing chips + `SetOpeningSwingCommand`
   - [x] b. Width presets + `SetOpeningWidthCommand` (hinge-aware)
   - [x] c. Door painter: hinge side + arc from latch edge
   - [x] d. Live measure label + status while grip-resizing openings
   - [x] e. Angle chip label Ortho → 90
   - [x] f. Selection paint keeps entity color
   - [x] g. History tests for width/swing

- [x] 13. Canvas performance (D30)
   - [x] a. `canvasListenable` + `refresh()` canvas-only
   - [x] b. `notifyUi()` on selection / toolbar chrome changes
   - [x] c. Status bar listens to canvas listenable
   - [x] d. EditorCanvas does not rebuild Focus tree every move

- [x] 14. Mac/Windows parity (D32)
   - [x] a. `Setup BonnieCAD.command` + hardened Open (Flutter local path, Chrome check)
   - [x] b. Windows Open Edge fallback; setup notes native optional
   - [x] c. `PlanFiles.SaveResult` — desktop cancel does not mark saved
   - [x] d. Cmd/Ctrl+N/O/S/Shift+S; menu tooltips
   - [x] e. Pinch (`PointerScaleEvent`) + scroll zoom; pointer cancel
   - [x] f. Narrow layout stacks side panel; OS window `Title`
   - [x] g. `dart analyze` clean · `flutter test` passing · README/lore

## Implementation notes

### Active-floor accessors (minimize blast radius)

```dart
// Document
Floor get activeFloor => floorById(activeFloorId)!;
List<Wall> get walls => activeFloor.walls;
// commands keep: doc.walls.add(wall);
```

### Angle lock

```dart
Vec2 angleLock(Vec2 from, Vec2 to, double stepDeg) {
  final d = to - from;
  final len = d.length;
  if (len < 1e-12) return to;
  final ang = math.atan2(d.y, d.x);
  final step = stepDeg * math.pi / 180;
  final snapped = (ang / step).round() * step;
  return from + Vec2(math.cos(snapped), math.sin(snapped)) * len;
}
```

### v1/v2 → v3 decode sketch

```dart
if (version < 3) {
  floors = [Floor(id: 'fl1', name: 'Main', walls: ..., texts: [])];
  activeFloorId = 'fl1';
}
```

### Primary files

| Area | Path |
|------|------|
| Floor / text models | `app/lib/domain/floor.dart`, `text_label.dart`, `document.dart` |
| Commands | `app/lib/domain/commands.dart` |
| Codec | `app/lib/persistence/document_codec.dart` |
| Snap / angle | `app/lib/geometry/snap.dart`, `segment.dart` |
| Tools | `wall_tool.dart`, `select_tool.dart`, `text_tool.dart`, `editor_controller.dart`, `tool.dart` |
| Canvas lock origin | `app/lib/ui/editor/editor_canvas.dart` |
| UI | `app/lib/ui/shell/app_shell.dart` |
| Paint | `app/lib/render/document_painter.dart` |
| Tests | `codec_test.dart`, `history_test.dart`, `segment_test.dart` |
