# BonnieCAD

2D housing blueprint editor for DIY homeowners. Built with Flutter.

| | |
|--|--|
| **Run target** | **Web (Chrome)** — no Xcode, no Visual Studio |
| **Units** | Inches stored · ft/in or metric display |
| **Files** | `.boncad` JSON schema v3 (download/upload) · Code view |
| **Features** | Multi-floor, walls, doors/windows, dimensions, text labels, furniture library, per-entity style, angle lock, undo |
| **Lore** | `lore/bon-cad/` — RESEARCH, DECISIONS, PLAN |

## Open the app

### macOS

1. **First time only:** double-click **`Setup BonnieCAD.command`**  
   - Checks for Chrome (offers Homebrew install if missing)  
   - Uses Flutter on PATH, or clones stable into `~/.local/share/bon-cad-tools/flutter`  
   - Runs `flutter precache --web` and `flutter pub get`  
   - Puts **BonnieCAD** on your **Desktop** and **starts the app**
2. **Every time:** double-click the Desktop **BonnieCAD** shortcut (or **`Open BonnieCAD.command`** in this folder)

First open of a `.command` file: if macOS blocks it, right-click → **Open** → **Open**.

Leave the Terminal window open while you use the app. Close it or press Ctrl+C to stop.

### Windows

1. **First time only:** double-click **`Setup BonnieCAD.bat`**  
   - Installs **Chrome** and **Git** if missing (via `winget` when available)  
   - Clones Flutter **stable** into `%LOCALAPPDATA%\bon-cad-tools\flutter`  
   - Runs `flutter precache --web` and `flutter pub get`  
   - Puts **BonnieCAD** on your **Desktop** and **starts the app**  
2. **Every time:** double-click the Desktop **BonnieCAD** shortcut (or **`Open BonnieCAD.bat`** in this folder)  
   - Prefers Chrome; falls back to **Edge** if Chrome is missing

Leave the black console window open while you use the app. Close it or press Ctrl+C to stop.

If Windows SmartScreen warns on the `.bat` files: **More info** → **Run anyway**.  
If Git was just installed and Flutter still isn’t found: close the window, open a **new** Command Prompt, and run setup again (PATH refresh).

### Terminal (any OS)

```bash
cd app
flutter pub get
flutter run -d chrome
```

Requirements: Flutter 3.24+, Chrome (or Edge on Windows). **No Visual Studio / Xcode** for the web app.

### Optional native targets (extra tooling — not required)

```bash
flutter run -d windows   # needs Windows + Visual Studio C++ workload
flutter run -d macos     # needs full Xcode
flutter run -d ios       # needs Xcode + simulator/device
```

These platform folders exist for later; **daily use is web only** (see DECISIONS D4, D8, D16, D32).

## Shortcuts

| Key | Action |
|-----|--------|
| W | Wall tool |
| D | Door |
| E | Window |
| M | Dimension |
| B | Furniture library tool |
| T | Text label |
| V | Select |
| F | Fit view |
| + / = | Zoom in |
| − | Zoom out (when not typing a length) |
| Ctrl/Cmd+N | New |
| Ctrl/Cmd+O | Open |
| Ctrl/Cmd+S | Save |
| Ctrl/Cmd+Shift+S | Save As |
| Ctrl/Cmd+Z | Undo |
| Ctrl/Cmd+Y | Redo |
| Esc | Cancel current tool action |
| Delete | Delete selection |
| Space+drag / middle-mouse | Pan |
| Scroll / trackpad pinch | Zoom |

Menu bar also has **+ / −** zoom buttons. Tooltips show the shortcuts.

**Editing tips**
- Select a door/window → drag **end grips** along the wall to resize (min 12"); live width label shows on canvas.
- Side panel for openings: **width presets**, door **swing** (L/R in/out), **color** swatches + Custom, stroke.
- Side panel also: **Floors** (add/rename/delete), **Library**, wall thickness, furniture rotation/size.
- Toolbar angle modes: **Free / 90 / 45° / 15°** (wall draw + endpoint drag).
- Outlets / switches / wall lights: pick from Library → click a **wall**.
- Free furniture (tub, toilet, bed, …): pick from Library → click the plan; drag to move; corner grips to resize.
- While drawing a wall, type a length (`12'6"`, `120`, `3m`) and press **Enter**.
- Narrow windows stack the side panel under the canvas (Mac/Windows resize-friendly).

## Project layout

```
bon-cad/
  Setup BonnieCAD.command   # macOS one-time install
  Open BonnieCAD.command    # macOS double-click launcher
  Setup BonnieCAD.bat       # Windows one-time install
  Open BonnieCAD.bat        # Windows double-click launcher
  README.md
  lore/bon-cad/           # RESEARCH, DECISIONS, PLAN
  app/                    # Flutter package
    lib/
      core/               # units, ids, vec2
      domain/             # document, walls, openings, furniture, commands, history
      geometry/           # snap, segments
      render/             # viewport, painter
      tools/              # wall, select, opening, dimension, furniture
      persistence/        # JSON codec + file_picker I/O (no dart:io)
      ui/                 # shell + canvas
    web/                  # Flutter web host
    macos/ windows/ ios/  # optional native shells
```

## Tests

```bash
cd app && flutter test && dart analyze
```

## What we learned

### Platform & tooling
- Prefer **web (Chrome)** when you don’t want Xcode/VS on the critical path to open the app.
- Native folders (`windows/`, `ios/`, `macos/`) can stay in the repo for later; they must not block daily run.
- Users want **double-click launchers**, not “open Terminal and type flutter”. Ship OS scripts next to the project root.
- **Windows setup** can self-bootstrap: `winget` for Chrome/Git + `git clone` Flutter stable into `%LOCALAPPDATA%`. No admin Visual Studio needed for web.
- **macOS setup** mirrors Windows: local Flutter under `~/.local/share/bon-cad-tools` when PATH has none; Chrome via Homebrew cask optional.
- After installing Git via winget, **PATH may not update** until a new shell — setup should say so clearly.
- macOS `.command` files need `chmod +x`; Gatekeeper may require right-click → Open once.
- Windows SmartScreen often flags unsigned `.bat` — document **More info → Run anyway**.
- On Windows without Chrome, **Edge** is a workable Flutter web device fallback.

### Flutter web / desktop gotchas
- Don’t use `dart:io` `File` paths in shared code — breaks web. Use `file_picker` **bytes** (`persistence/file_io.dart`).
- `file_picker` **11.x** uses `FilePicker.pickFiles` / `FilePicker.saveFile` (not `.platform`).
- **Save cancel:** desktop returns `null` path on cancel — do **not** mark dirty cleared. Web may return null after download; treat web null as success.
- Keep domain/commands **pure Dart** for unit tests without a widget tree.
- Y-up world vs Y-down screen: flip Y in viewport transforms; negate furniture rotation when painting.
- Widget tests: wrap side panels in `Material`; avoid overflow in narrow menu `Row`s (use horizontal `ListView`).
- Trackpad **pinch** is `PointerScaleEvent`; wheel is `PointerScrollEvent` — handle both for Mac/Windows.
- Primary modifier = **Control or Meta** so shortcuts work on both OSes.
- Narrow layouts: stack side panel under canvas instead of crushing both.

### Product / CAD model
- Canonical storage: **inches**. Convert only at UI (`core/units.dart`).
- Every mutation should be a **command** on a history stack (undo/redo is non-negotiable).
- Openings and electrical fixtures are **wall-hosted** (wallId + offset); furniture is **free-standing** (origin, rotation, W×D).
- Doors: `DoorSwing` (L/R × in/out); paint hinge at correct end; arc from latch. Windows share width/color, not swing.
- Wall **thickness** is structural (world inches). Decorative **strokeWidth** is optional screen px; **colorValue** optional per entity, else layer color. Selection uses grips — don’t force a selection color over entity color.
- Schema must be **versioned**. v3 floors+texts; v2 furniture/style; v1 still loads.
- Furniture symbols can be **procedural 2D** (rects/ovals) — no image asset pack required for a useful DIY library.
- Scroll zoom alone is not discoverable enough — add **buttons + keyboard** even when wheel works.
- Opening resize grips + width presets + live measure label beat place-time-only defaults.
- **Perf:** pointer move must use a canvas-only listenable (`refresh()`), not full shell `notifyListeners()`.

Details: `lore/bon-cad/RESEARCH.md`, `DECISIONS.md` (D1–D32), `PLAN.md`.
