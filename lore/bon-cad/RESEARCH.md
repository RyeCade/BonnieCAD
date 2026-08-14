# Research: BonnieCAD — 2D Housing Blueprint App

> **Researched:** 2026-07-19  
> **Updated:** 2026-08-07 (Mac/Windows parity: setup both OSes, save cancel, shortcuts, pinch zoom)  
> **Context:** Greenfield 2D housing-blueprint editor. Originally framed as iOS + Windows; **shipping surface is Flutter Web (Chrome)** so day-to-day use needs no Xcode/VS.  
> **Project:** bon-cad

## Summary

BonnieCAD is a 2D floor-plan / housing-blueprint editor for DIY homeowners. Hard constraints: **2D only**, **housing blueprints**, **simple local tooling**, **open without a terminal when possible**.

Winning architecture: **document model** (`floors[]` each owning walls/openings/dims/furniture/fixtures/texts; shared layers) + **command/history** + **viewport canvas** (world inches, pan/zoom, grid, angle lock). Implemented under `app/lib/` with pure-Dart domain code. Schema **v3**.

**Stack:** Flutter. **Primary run target: web (Chrome)**; Edge fallback on Windows. Launchers: `Setup`/`Open BonnieCAD.command` (macOS), `Setup`/`Open BonnieCAD.bat` (Windows). Native platform folders optional.

Shipped: zoom UI/keys + trackpad pinch, opening resize grips + width presets, door swing (L/R × in/out), live size callouts, per-entity color/stroke + Custom picker, furniture library, multi-floor, text labels, Free/90/45°/15° lock, canvas-only refresh, Cmd/Ctrl file shortcuts, correct save-cancel on desktop (D10–D32).

## Key Findings

### 1. Workspace state (current)

- Path: repo root `bon-cad/`
- Git repo; Flutter app in `app/`
- Platforms: `web/` (primary), `windows/`, `ios/`, `macos/` (optional)
- Launchers at root: `Setup`/`Open BonnieCAD.command` (macOS), `Setup`/`Open BonnieCAD.bat` (Windows)
- Lore: `lore/bon-cad/{RESEARCH,DECISIONS,PLAN}.md`
- Tests: `dart analyze` clean; `flutter test` passing (including codec v2 + furniture history)
- Document schema: **v3** (floors, texts; furniture/wallFixtures/style from v2)

### 2. Platform requirement implications

| Target | Implication | Status |
|--------|-------------|--------|
| **Web / Chrome** | Only Flutter + browser; file picker download/upload | **Primary — works** |
| Windows desktop | VS “Desktop C++” workload; MSIX optional | Code present, not required daily |
| iOS / macOS | Full Xcode + simulators | Code present; **user does not want Xcode dependency** |
| Shared product | One document model + tools; shell/file I/O must avoid `dart:io` for web | Implemented |

Touch vs mouse still matters if native mobile returns later; web/desktop share mouse + keyboard shortcuts.

### 3. Stack comparison (for 2D CAD canvas)

| Stack | iOS | Windows | Canvas strength | Notes |
|-------|-----|---------|-----------------|-------|
| **Flutter** | Yes (Impeller/Metal) | Yes (stable desktop) | Excellent CustomPainter / scene graph | Single codebase; MSIX via `msix` package; good for custom drawing apps |
| **.NET MAUI + SkiaSharp** | Yes | Yes (strong) | Strong Skia | Best if team is C#-first; native controls; canvas still custom |
| **React Native + Skia** | Yes | Weak/immature desktop | Good on mobile | Poor fit for first-class Windows desktop CAD |
| **Tauri 2 / Electron + Canvas/WebGL** | Tauri mobile immature | Excellent desktop | Good (Canvas2D/WebGL) | Desktop-first; iOS parity risky for v1 |
| **Dual native** (SwiftUI + WinUI) | Best native | Best native | Best per platform | 2× cost; only if max native polish required |
| **Qt / C++** | Possible | Excellent | Excellent | Heavy native toolchain; slower iteration |

**Recommendation for research baseline:** Flutter, unless the team standardizes on C#/.NET.

Flutter desktop specifics (from Flutter docs):
- Windows runner is a small C++ Win32 host; customize via `windows/runner`
- Distribution: MSIX (`msix` pub package), zip + VC++ redist, or Microsoft Store
- Impeller is the only iOS renderer (Skia removed on iOS); designed for stable frame rates
- FFI (`dart:ffi`, `win32` package) for deep Windows APIs if needed later

### 4. CAD application architecture (domain)

Standard layers for a 2D architectural editor:

```
┌─────────────────────────────────────────┐
│  UI Shell (tools, panels, menus)        │
├─────────────────────────────────────────┤
│  Interaction (gestures, keys, tools)    │
├─────────────────────────────────────────┤
│  Commands + History (undo/redo)         │
├─────────────────────────────────────────┤
│  Document Model (entities, layers)      │
├─────────────────────────────────────────┤
│  Geometry / Snap / Constraints          │
├─────────────────────────────────────────┤
│  Viewport (camera, grid, render)        │
└─────────────────────────────────────────┘
```

**Document model (housing-focused):**
- `Project` → one or more `Floor` / `Level`
- `Wall` — centerline or baseline polyline + thickness + height (height unused in 2D draw but useful for door/window defaults)
- `Opening` — Door / Window / Opening hosted on a wall (offset along wall, width, swing/type)
- `Room` — optional; often derived from closed wall loops rather than drawn directly
- `Dimension` — linear annotations bound to points/entities
- `Text` / `Label`
- `Layer` — visibility, lock, color
- `Block` / `Symbol` — later (furniture, fixtures)

**Commands:** every mutation is a command object (`AddWall`, `MoveEntity`, `SetProperty`) applied to the document and pushed on an undo stack. This is non-negotiable for CAD UX.

**Coordinates:** store geometry in **real-world units** (e.g. millimeters or inches as canonical float), not pixels. Viewport maps world → screen via scale + pan + DPI.

**Snap system (MVP):**
- Grid snap
- Endpoint / midpoint / nearest-on-wall
- Orthogonal mode (0/90° or configurable angle lock)
- Optional: angle snap (15°/45°)

### 5. Essential features for residential blueprints

**MVP (ship-worthy floor plan):**
1. New / open / save project (app-native JSON)
2. Pan, zoom, fit-to-view
3. Grid + scale bar / unit display
4. Draw wall (thickness, orthogonal, snap)
5. Edit wall (move endpoints, length entry)
6. Place door / window on wall
7. Select, move, delete
8. Linear dimensions
9. Undo / redo
10. Layers (at least Walls, Openings, Dimensions, Annotations)
11. Export PNG and/or PDF for sharing
12. Imperial and/or metric units

**v1.1 / later:**
- Multi-floor
- Room detection + labels + area
- Furniture library
- DXF import/export (interchange with AutoCAD/LibreCAD)
- SVG export
- Property inspector polish
- Apple Pencil pressure (iPad)
- Templates (typical room sizes, door schedules)

**Explicitly out of scope (per product brief):** 3D view, BIM, MEP, structural analysis, photoreal rendering.

### 6. Reference products & open source

| Project | Stack | Relevance |
|---------|-------|-----------|
| [OpenPlan3D / open3dFloorplan](https://github.com/theLodgeBots/open3dFloorplan) | SvelteKit + Three.js (web) | Feature checklist: wall snap, doors/windows, dimensions, multi-export, multi-floor |
| [Gridsnap](https://gridsnap.app/) | Web editor | Millimeter precision, wall thickness, auto dimensions, PDF/PNG |
| LibreCAD | C++ / Qt | Full 2D CAD; heavier than needed but good snap/layer reference |
| Sweet Home 3D | Java | Consumer floor-plan UX (walls + furniture); less “CAD precise” |
| 2DFloorPlanner (Java student projects) | Swing canvas | Simple grid + room placement patterns |

OpenPlan3D feature list is a practical MVP mirror: click walls + corner snap, doors/windows, orthogonal mode, undo, grid snap, imperial/metric, PNG/SVG/DXF/PDF/JSON export.

### 7. File formats

| Format | Role | Priority |
|--------|------|----------|
| **Native JSON** (versioned schema) | Authoritative project file | P0 |
| **PNG** | Quick share / markup | P0 |
| **PDF** | Printable plan sheet | P0 or P1 |
| **SVG** | Vector share | P1 |
| **DXF** | Interchange with AutoCAD ecosystem | P1/P2 |
| DWG | Proprietary Autodesk | Avoid unless licensed SDK |

Native JSON should be human-debuggable, schema-versioned (`"schemaVersion": 1`), and include units metadata.

Example shape (illustrative):

```json
{
  "schemaVersion": 1,
  "name": "Main Floor",
  "units": "inch",
  "gridSize": 6,
  "layers": [{ "id": "walls", "name": "Walls", "visible": true }],
  "walls": [
    {
      "id": "w1",
      "layerId": "walls",
      "a": { "x": 0, "y": 0 },
      "b": { "x": 240, "y": 0 },
      "thickness": 4.5
    }
  ],
  "openings": [
    {
      "id": "d1",
      "type": "door",
      "wallId": "w1",
      "offset": 36,
      "width": 32,
      "swing": "leftIn"
    }
  ],
  "dimensions": [],
  "texts": []
}
```

### 8. Input model (iOS vs Windows)

| Input | Windows | iOS |
|-------|---------|-----|
| Primary pointer | Mouse | Touch |
| Precision | High (cursor) | Lower (finger); optional stylus later |
| Pan | MMB / Space+drag / scroll | Two-finger drag |
| Zoom | Wheel / Ctrl+wheel | Pinch |
| Shortcuts | Full keyboard (W wall, D door, Ctrl+Z) | Limited; tool palette primary |
| Numeric entry | Type length while drawing | Sheet/modal or on-screen keypad |

Design tools so **the same tool state machine** accepts pointer events from either source; only gesture mapping differs.

### 9. Suggested monorepo / app structure (Flutter baseline)

```
bon-cad/
  lore/bon-cad/          # plans, research, decisions
  app/                   # Flutter application
    lib/
      main.dart
      app.dart
      core/                # units, math, ids
      domain/              # entities, document, commands
      geometry/            # snap, intersections, polygons
      render/              # viewport, painters, layers
      tools/               # wall, select, dimension, pan
      persistence/         # json codec, file IO
      ui/                  # shell, toolbars, panels, dialogs
    test/
    integration_test/
  docs/                  # optional user-facing later
```

Keep **domain pure Dart** (no Flutter imports) so geometry/commands are unit-testable without a widget tree.

### 10. Phased delivery strategy

| Phase | Goal | Outcome |
|-------|------|---------|
| 0 | Foundations | Repo, Flutter app, CI stubs, lore |
| 1 | Canvas shell | Viewport, grid, pan/zoom, empty document |
| 2 | Walls | Draw/edit walls + snap + undo |
| 3 | Openings | Doors/windows hosted on walls |
| 4 | Annotate | Dimensions, labels, layers visibility |
| 5 | Files | Save/load JSON, export PNG/PDF |
| 6 | Polish | iOS gestures, Windows shortcuts, packaging |

## API Reference / Technical Details

### Flutter Windows packaging (summary)

- Dev: `flutter run -d windows`
- Release: `flutter build windows`
- MSIX: `msix` package on pub.dev
- Ship folder needs exe + `flutter_windows.dll` + `data/` + VC++ redistributables if not using MSIX/Store

### iOS release notes

- Requires Apple Developer account for device/TestFlight/App Store
- Impeller only on iOS — design for GPU path; avoid pathological overdraw on dense plans
- File access via document picker / app sandbox; use `file_picker` / `path_provider` patterns

### Geometry precision

- Prefer double-precision world coords
- Snap tolerance in **screen pixels** converted to world units via current zoom
- Avoid accumulating float error on repeated transforms; store absolute endpoints

## Code Examples

### Viewport transform (conceptual)

```dart
Offset worldToScreen(Offset world, Viewport v) =>
    Offset(
      (world.dx - v.pan.dx) * v.scale + v.size.width / 2,
      (world.dy - v.pan.dy) * v.scale + v.size.height / 2,
    );

Offset screenToWorld(Offset screen, Viewport v) =>
    Offset(
      (screen.dx - v.size.width / 2) / v.scale + v.pan.dx,
      (screen.dy - v.size.height / 2) / v.scale + v.pan.dy,
    );
```

### Command pattern (conceptual)

```dart
abstract class Command {
  void execute(Document doc);
  void undo(Document doc);
}

class History {
  final _undo = <Command>[];
  final _redo = <Command>[];

  void push(Command c, Document doc) {
    c.execute(doc);
    _undo.add(c);
    _redo.clear();
  }
}
```

## Gotchas & Edge Cases

1. **Wall joining:** T-junctions and corners need merge/cleanup rules or walls look broken at joins.
2. **Openings as wall hosts:** Moving/resizing a wall must clamp hosted doors/windows (implemented on endpoint move).
3. **Closed loops vs open walls:** Room area needs polygonization — deferred.
4. **Unit conversion:** Canonical inches; convert only at UI (`core/units.dart`).
5. **Touch hit-testing:** Expand pick tolerance if/when mobile returns.
6. **High entity counts:** Spatial index later if plans grow.
7. **Undo granularity:** One gesture = one command (drag end commits one move command).
8. **Web file UX:** No real filesystem paths — use `file_picker` with bytes; Save triggers download.
9. **`dart:io` breaks web:** Never import `dart:io` in shared lib code. Use `persistence/file_io.dart`.
10. **file_picker 11.x:** Use `FilePicker.pickFiles` / `FilePicker.saveFile` — not `FilePicker.platform.*`.
11. **Xcode / VS not optional for native:** macOS/iOS need Xcode; Windows desktop needs VS C++. Prefer web for zero-toolchain open.
12. **Widget tests:** `ListTile` inside colored `Container` fails material ink asserts — wrap side panel in `Material`. Menu `Row` overflows narrow test surface — use horizontal `ListView`.
13. **Y-up world / Y-down screen:** Viewport flips Y in `worldToScreen` / `screenToWorld`.
14. **Not AutoCAD-compatible on day one:** DXF deferred.

## Related Resources

| Resource | URL | Notes |
|----------|-----|-------|
| Flutter web | https://docs.flutter.dev/platform-integration/web | Primary run target |
| Flutter desktop | https://flutter.dev/multi-platform/desktop | Optional native |
| Flutter Windows build | https://docs.flutter.dev/platform-integration/windows/building | MSIX if packaging later |
| file_picker | https://pub.dev/packages/file_picker | Open/save bytes (v11 static API) |
| pdf package | https://pub.dev/packages/pdf | PDF export |
| OpenPlan3D features | https://openplan3d.com/features | Feature checklist |
| Gridsnap | https://gridsnap.app/ | Web floor-plan reference |
| LibreCAD | https://librecad.org/ | Classic 2D CAD |

## Implementation map (as built)

| Area | Path |
|------|------|
| Units / Vec2 / Ids | `app/lib/core/` |
| Document, walls, openings, dims, furniture, wall fixtures, catalog, commands, history | `app/lib/domain/` |
| Snap + segments | `app/lib/geometry/` |
| Viewport + painter (walls, openings, furniture symbols, electrical) | `app/lib/render/` |
| Tools (wall, select, opening, dimension, furniture) | `app/lib/tools/` |
| JSON codec schema v2 + file_picker I/O | `app/lib/persistence/` |
| Shell + canvas UI (library panel, style editor, zoom buttons) | `app/lib/ui/` |
| Entry | `app/lib/main.dart` |
| macOS double-click launcher | `Open BonnieCAD.command` (repo root) |
| Windows setup + launcher | `Setup BonnieCAD.bat`, `Open BonnieCAD.bat` (repo root) |

## How to open the app

| OS | Action |
|----|--------|
| macOS | Double-click `Open BonnieCAD.command` |
| Windows | Once: `Setup BonnieCAD.bat` · then: `Open BonnieCAD.bat` |
| Terminal | `cd app && flutter pub get && flutter run -d chrome` |

No Xcode. No Visual Studio for web. Chrome + Flutter only.

### Windows setup details (learned)

- Flutter installed to `%LOCALAPPDATA%\bon-cad-tools\flutter` via `git clone -b stable --depth 1`.
- Chrome/Git via `winget` when present; otherwise script points at download URLs.
- `flutter precache --web` before first run reduces first-launch pain.
- Git install may require a **new shell** before `git`/`flutter` resolve on PATH.
- SmartScreen blocks unsigned bat — user education in README, not code signing (yet).

## Feature plan (2026-07-19) — shipped

User requested: (1) zoom, (2) door/window size, (3) custom line width/color, (4) furniture/fixtures.

| Request | Solution | Key files |
|---------|----------|-----------|
| Zoom | Menu +/−, keys `+`/`=`/`-`, scroll retained, % in status | `editor_controller.dart`, `app_shell.dart` |
| Opening size | On-canvas end grips; width presets in panel; `SetOpeningGeometryCommand` / `SetOpeningWidthCommand`; min 12" | `select_tool.dart`, `commands.dart`, `app_shell.dart` |
| Door swing | `DoorSwing` L/R × in/out; panel chips; painter hinge at correct end + quarter-arc from latch | `opening.dart`, painter, `SetOpeningSwingCommand` |
| Live size label | `measureLabel` + `measureLabelAt` while grip-resizing openings (and wall preview length) | `editor_controller.dart`, painter, `select_tool.dart` |
| Line color/width | Optional `colorValue` / `strokeWidth`; layer fallback; swatches + Custom; selection keeps entity color | entity models, `SetEntityStyleCommand`, `_StyleEditor` |
| Furniture | 28-item catalog; free `FurnitureItem` + wall `WallFixture`; tool B + library chips | `furniture_catalog.dart`, `furniture_tool.dart`, painter symbols |
| Canvas perf | `refresh()` → `canvasListenable` only; `notifyUi()` / `notifyListeners()` for chrome | `editor_controller.dart`, `editor_canvas.dart`, `_StatusBar` |

Schema: **`schemaVersion: 3`**. v1/v2 load as single Main floor; furniture/style fields optional.

### Architecture lessons (feature work)

1. **Command granularity:** live drag mutates document, pointer-up reverts + pushes one command (same pattern as wall endpoints). Furniture resize may push size + translate.
2. **Style inheritance:** paint order entity override → layer color. Selection uses grips, not a forced blue override (so DIY color edits are visible while selected). Walls keep inch thickness; strokeWidth is for openings/dims/furniture outlines.
3. **Catalog vs instances:** catalog is static data (`FurnitureCatalogEntry`); instances store catalogId + geometry so defaults can change without rewriting saves.
4. **Wall-hosted vs free:** electrical uses wallId+offset like openings; beds/tubs use origin+rotation+W×D. Don't force one model.
5. **Procedural symbols:** switch on `FurnitureDrawStyle` in painter — enough for DIY readability without SVG packs.
6. **Zoom keys vs length entry:** `-` is both zoom-out and length minus; only treat as zoom when `lengthBuffer` is empty.
7. **Hit testing:** furniture OBB via inverse-rotate to local; openings along wall segment + thickness pad; fixtures by point on wall.
8. **Door paint:** hinge from swing (left = wall start / right = wall end); leaf open 90° along wall normal (in/out sign); arc from latch edge to leaf tip. Width change with right hinge keeps latch end fixed (`SetOpeningWidthCommand`).
9. **UI rebuild cost:** pointer move must not rebuild toolbar/side panel. Split listenable: canvas+status on `refresh()`, full shell on selection/commands/`notifyUi()`.
10. **Windows vs doors:** same width grips, presets (different defaults), color/stroke, measure label. Swing UI is door-only.

## Gotchas (extended — launchers & features)

15. **Double-click launchers:** put scripts at **repo root** with spaces in names users understand (`Open BonnieCAD.bat`).
16. **`.command` executable bit:** git may or may not preserve `+x`; document `chmod +x` if needed.
17. **Flutter not on PATH (Windows):** Open.bat must look at `%LOCALAPPDATA%\bon-cad-tools\flutter\bin` before failing.
18. **Schema bumps:** always accept older `schemaVersion` and fill defaults; never require users to hand-edit JSON.
19. **Delete selection:** must snapshot furniture + wallFixtures into `RemoveEntitiesCommand` or undo loses them.
20. **Export bounds:** include furniture corners and fixture positions or crops cut symbols off PNG/PDF.

## Open Questions (remaining)

1. Host static web build (GitHub Pages / any static host) vs only `flutter run` / launchers?
2. When/if to invest in Windows MSIX or iOS again?
3. Room areas, DXF priority? (multi-floor shipped)
4. Offline PWA installability?
5. ~~Full color picker vs preset swatches only?~~ → swatches + Custom shipped
6. Code-sign Windows `.bat` / ship a small native stub to avoid SmartScreen?
7. Bundle a portable Flutter zip instead of git clone for offline Windows setup?
8. Typed width entry for openings (like wall length buffer)?

## Resolved (from preflight)

| Question | Answer |
|----------|--------|
| Primary user | DIY homeowner |
| Stack | Flutter |
| Units | Inches canonical; ft/in default display |
| Surface | Web first (revised from Windows→iOS) |
| Multi-floor v1 | No |
| Product name | BonnieCAD |
| Cloud | No — local files only |
