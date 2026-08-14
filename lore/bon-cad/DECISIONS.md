# BonnieCAD Decisions

Architectural and product decisions for the 2D housing-blueprint CAD app.

---

## Pending

_(none)_

---

## Decided

### D1 - [x] Primary user persona

**Context:** Precision, UI density, DXF priority, and measurement features depend on who the app is for.

**Decision:** DIY homeowner / renovator.

**Rationale:** User chose simple, forgiving UX over CAD-dense drafting. Imperial-friendly defaults, PNG/PDF share, precise-enough housing layouts — not full AutoCAD parity. Path open toward designer features later.

### D2 - [x] Cross-platform tech stack

**Context:** Greenfield; must ship a custom 2D canvas without heavy native toolchains for day-to-day dev.

**Decision:** Flutter (Dart), multi-target.

**Rationale:** Single codebase, strong CustomPainter canvas. Originally chosen for iOS + Windows; still correct after web pivot — same app runs on chrome/windows/ios from one tree.

### D3 - [x] Canonical measurement units

**Context:** Geometry must store one canonical unit; UI converts for display/entry.

**Decision:** Inches as canonical storage.

**Rationale:** US DIY housing primary; display as ft/in; optional metric display via conversion at UI boundary.

### D4 - [x] v1 device surface — REVISED 2026-07-19

**Context:** Interaction design and tooling constraints. Original choice was Windows first, then iOS.

**Original decision:** Windows first, then iOS.

**Revised decision:** **Web (Chrome) first.** Native Windows/iOS remain optional later targets.

**Rationale:**
- Dev machine is macOS without Xcode / Windows SDK. `flutter run -d macos` and iOS require full Xcode; Windows needs a Windows host + VS C++ workload.
- User explicitly does not want to depend on Xcode or other heavy third-party native toolchains to open the app.
- Flutter web launches with only Flutter + Chrome: `flutter run -d chrome`.
- Document model, tools, and canvas are platform-agnostic; native shells can return later without rewriting domain code.

### D5 - [x] Project storage model — REVISED 2026-07-19

**Context:** How users keep blueprints between sessions.

**Original decision:** Local files only (path-based `dart:io` File API).

**Revised decision:** Local files via **picker + bytes** (download/upload on web; same API works on desktop).

**Rationale:**
- `dart:io` is not available on Flutter web and broke the first web build.
- `file_picker` with `withData: true` / `bytes:` on save works across web and desktop without path-based I/O.
- Still no accounts or cloud sync. Format remains versioned `.boncad` JSON (`schemaVersion: 1`).

### D6 - [x] MVP feature cut line

**Context:** Need a shippable floor-plan editor without boiling the ocean.

**Decision:** Core CAD only for v1.

**Rationale:** Walls, doors/windows, snap, dimensions, undo, layers, native JSON + PNG/PDF. Multi-floor, room areas, DXF, and furniture deferred.

**Revised 2026-07-19:** Furniture library and per-entity styling are now in scope for the next feature plan (see D10–D15). Multi-floor, room areas, and DXF remain deferred.

### D7 - [x] Product name — REVISED 2026-08-06

**Context:** Repo is `bon-cad`; branding may differ for stores.

**Original decision:** BonCAD.

**Revised decision:** **BonnieCAD.**

**Rationale:** User preferred BonnieCAD as the product display name. Package/id remains `bon_cad` where identifiers require underscores; file extension remains `.boncad`; Windows tools path stays `%LOCALAPPDATA%\bon-cad-tools`.

### D8 - [x] Avoid dart:io in shared app code

**Context:** Web target cannot import `dart:io`.

**Decision:** Keep domain/tools free of `dart:io`. File access only through `persistence/file_io.dart` using `file_picker` bytes APIs. Controller exposes `loadFromText` / `encodeDocument` / `markSaved`.

**Rationale:** One codebase runs on chrome without conditional imports for the MVP path. Learned the hard way when first shell used `File(path).readAsString()`.

### D9 - [x] file_picker 11.x API

**Context:** Older docs show `FilePicker.platform.pickFiles`.

**Decision:** Use static API: `FilePicker.pickFiles(...)` and `FilePicker.saveFile(...)`.

**Rationale:** `file_picker` 11.0.2 removed the `.platform` getter pattern; analyzer failed until calls were updated.

### D10 - [x] Zoom controls beyond scroll

**Context:** Scroll-wheel zoom and Fit already exist (`CadViewport.zoomAt`, `EditorController.fitView`). User still wants discoverable zoom.

**Decision:** Add visible **UI zoom buttons** (+ / −) and **keyboard shortcuts** (`+`/`=` zoom in, `-` zoom out; keep `F` fit). Retain scroll zoom.

**Rationale:** Scroll alone is easy to miss on web; buttons + keys match DIY expectations without requiring pinch/touch work yet.

### D11 - [x] Door/window resize interaction

**Context:** Openings store `width` but only default sizes are applied at place time; side panel has no opening editor; select tool does not resize openings.

**Decision:** Resize via **on-canvas drag grips** at opening ends (along the host wall). Clamp so opening stays on wall. Optional numeric width in side panel can follow later if needed.

**Rationale:** User chose canvas grips over property-panel-first; matches wall endpoint editing pattern in `SelectTool`.

### D12 - [x] Per-entity stroke color and width

**Context:** Walls use real-world `thickness` + layer color; dimensions/openings use fixed screen strokes and layer color only.

**Decision:** **Per-entity optional overrides** for `colorValue` and `strokeWidth` (screen pixels for non-structural strokes; walls keep `thickness` in inches as structural width, plus optional color override). Null/absent → inherit layer defaults.

**Rationale:** User wants custom width/color on all lines without forcing every entity onto separate layers. Schema bump required (`schemaVersion: 2`).

### D13 - [x] Furniture catalog size for next ship

**Context:** PLAN step 15e previously excluded furniture. User now wants a large common set.

**Decision:** Ship a **large library (20+ symbols)** covering bath, kitchen, bedroom/living, laundry, and electrical.

**Rationale:** DIY homeowners need recognizable fixtures on plans; a tiny set would feel incomplete once placement exists. Catalog is data-driven so items can grow without new tools per type.

### D14 - [x] Furniture placement model

**Context:** Need a document model for fixtures vs wall-hosted electrical.

**Decision:** **Free-standing symbols** (center, rotation, width, depth) for furniture/fixtures; **wall-hosted electrical** (outlet, switch, light) similar to openings (wallId + offset along wall).

**Rationale:** Beds/sofas/tubs are room objects; outlets/switches belong on walls. Matches residential plan conventions.

### D15 - [x] Furniture instance sizing

**Context:** Catalog needs default real-world sizes; users may need nonstandard dimensions.

**Decision:** Each catalog type has **default W×D (inches)**; after place, user can **optionally resize** via property panel and/or corner grips.

**Rationale:** Realistic defaults for speed; optional resize for DIY flexibility without free-scale-only chaos.

### D16 - [x] Double-click launchers + Windows self-setup

**Context:** User does not want to run terminal commands to open the app. Windows users also need a path that downloads Flutter/Chrome without Visual Studio.

**Decision:**
- **macOS:** `Open BonnieCAD.command` at repo root (`chmod +x`) — runs `flutter run -d chrome` from `app/`.
- **Windows:** `Setup BonnieCAD.bat` (one-time: winget Chrome/Git if missing, `git clone` Flutter stable to `%LOCALAPPDATA%\bon-cad-tools\flutter`, precache web, pub get) + `Open BonnieCAD.bat` (every launch).
- Document SmartScreen / Gatekeeper one-time prompts in root README.

**Rationale:** DIY users open a folder and click; web target means setup need not install VS C++. Local Flutter under `%LOCALAPPDATA%` avoids requiring a global install or admin rights for the SDK itself.

**Alternatives rejected:** Shipping only README terminal steps; requiring full Flutter install docs; native Windows exe (needs VS toolchain).

### D17 - [x] Multi-floor document shape

**Context:** Document is a single flat bag of walls/openings/dims/furniture. Multi-floor needs a clear ownership model.

**Decision:** **Floor owns geometry.** `Document.floors[]`; each `Floor` holds its own walls, openings, dimensions, furniture, wallFixtures, and texts. Editor works on the **active floor** only.

**Rationale:** Matches RESEARCH (`Project → Floor`), avoids leaky `floorId` filters on every query, natural DIY “Main / Basement / 2nd”.

**Alternatives rejected:** Entities carry `floorId` (filter forever); separate documents per floor (weak single-plan UX).

### D18 - [x] Floor UI chrome

**Context:** Users need to switch and manage floors without cluttering the canvas tool bar.

**Decision:** **Side-panel floor list only** — list floors with active highlight; add / rename / delete in the panel (not canvas tabs).

**Rationale:** User preference; reuses existing right-panel patterns (layers, library). Canvas stays tool-focused.

**Alternatives rejected:** Tab bar above canvas; tabs-only without rename/delete.

### D19 - [x] Shared layers across floors

**Context:** Layers could be per-floor or document-global.

**Decision:** **Shared layers** on `Document` (visibility/lock/color apply to all floors).

**Rationale:** DIY CAD expectation; simpler codec and side panel; walls/openings still use the same layer ids.

**Alternatives rejected:** Per-floor layers; deferred per-floor overrides.

### D20 - [x] Text / label entity model

**Context:** Annotations layer exists; no text entity. Dimensions are measurement-only.

**Decision:** **Free text at a point** — `origin`, `text`, optional `rotationRad`, `fontSizePx`, `layerId` (default `annotations`), optional `colorValue`. No leader line in this pass.

**Rationale:** Enough for room names and notes; smallest useful DIY model.

**Alternatives rejected:** Leader callouts; both free text and leader.

### D21 - [x] Text place and edit UX

**Context:** Need place + edit without fighting pan/zoom on web.

**Decision:** **T tool: click to place** with default string (e.g. `Label`); **select → side-panel** edits string / size / rotation. Commands for all mutations.

**Rationale:** Matches furniture/style patterns; avoids modal dialogs and on-canvas TextField focus issues.

**Alternatives rejected:** Click-then-dialog; double-click inline edit overlay.

### D22 - [x] Full color picker UX

**Context:** `_StyleEditor` has preset swatches + Layer only.

**Decision:** Keep swatches + Layer; add **Custom** → dialog color picker. Still store ARGB `colorValue` int. Prefer built-in Flutter widgets; add `flutter_colorpicker` only if needed.

**Rationale:** One-tap presets for DIY; full hue when needed; no schema change for color itself.

**Alternatives rejected:** Picker-only (lose presets); hex field only.

### D23 - [x] Angle lock mode replaces Ortho chip

**Context:** Snap has boolean `orthogonalEnabled` + `orthogonalLock` (0°/90° only). User wants 15°/45° as well.

**Decision:** Replace Ortho filter chip with exclusive mode: **Free | Ortho | 45° | 15°**. Implement `angleLock(from, to, stepDegrees)` (Ortho = 90°).

**Rationale:** Single control is clearer than Ortho + separate Angle chips; covers free walls and common DIY diagonals.

**Alternatives rejected:** Separate Angle chip with Ortho precedence; 45°-only chip.

### D24 - [x] Angle lock applies to wall draw + endpoint drag

**Context:** Today angle lock only runs when `orthogonalOrigin` is set — wall tool start via `editor_canvas._orthoOrigin`. Endpoint drag uses `e.point` from global snap without origin.

**Decision:** Apply lock mode for **wall drawing** (including typed length commit) and **select-tool wall endpoint drag**. Not furniture, dimensions, or body-move.

**Rationale:** Walls need angled drafting; other entities stay free/grid.

**Alternatives rejected:** All snapWorld tools; wall tool only (leaves endpoint edits unlocked).

### D25 - [x] Text font size in screen pixels

**Context:** Labels must stay readable while drafting at any zoom.

**Decision:** Store **`fontSizePx`** (screen pixels). Paint like dimension text — does not scale with world zoom.

**Rationale:** DIY notes stay legible; print-to-scale text can come later if needed.

**Alternatives rejected:** World inches; world + min screen clamp.

### D26 - [x] Schema version 3 with v1/v2 migration

**Context:** Floors + texts change the JSON shape. Existing `.boncad` must still load.

**Decision:** **`schemaVersion: 3`**. Encode `floors[]` (each with geometry + texts) + shared `layers`. Decode v1/v2 flat geometry into a single floor named **Main**. Reject versions > 3.

**Rationale:** Same pattern as v1→v2 furniture load path; no broken user files.

**Alternatives rejected:** Reject older files; stay on schema 2 with optional fields only.

### D27 - [x] Door swing controls in side panel

**Context:** `DoorSwing` existed (leftIn default) but UI only showed width text; painter always hinged at wall-start.

**Decision:** Select door → chips **L in / L out / R in / R out** via `SetOpeningSwingCommand`. Painter uses left = opening start, right = opening end; in/out flips normal. Windows have no swing UI.

**Rationale:** DIY users need to flip hinge/side without re-placing; model already had the enum.

**Alternatives rejected:** Cycle button only; place-time swing picker only.

### D28 - [x] Opening width presets + hinge-aware width command

**Context:** Grip resize alone is hard for standard door sizes; right-hinge doors should keep latch fixed when width changes.

**Decision:** Side-panel width chips (doors 24–36", windows 24–60"). `SetOpeningWidthCommand` clamps to wall, min 12"; right hinge keeps end fixed, left keeps offset fixed. Grip drag still uses `SetOpeningGeometryCommand` on pointer-up.

**Rationale:** Matches wall thickness preset pattern; standard residential sizes.

**Alternatives rejected:** Typed entry only; always grow from offset regardless of hinge.

### D29 - [x] Live measure label while resizing openings

**Context:** Wall draw already shows length near cursor; opening grip resize had no on-canvas size.

**Decision:** During opening grip drag, set `measureLabel` / `measureLabelAt` (opening center) and status bar width; clear on pointer-up. Reuse painter callout used for wall preview length.

**Rationale:** Same DIY feedback as wall length; works for doors and windows.

**Alternatives rejected:** Status bar only; permanent dimension entity on every resize.

### D30 - [x] Canvas-only refresh path (perf)

**Context:** Every `pointerMove` called `notifyListeners()` → full shell rebuild (toolbar, side panel, floors list) every mouse move → lag.

**Decision:** `EditorController.canvasListenable` for canvas + status. `refresh()` notifies canvas only. Selection / tool / snap UI use `notifyUi()` (full `notifyListeners()`). Commands already notify full UI.

**Rationale:** Pointer move only needs paint + status; selection still updates property panel.

**Alternatives rejected:** Throttle/debounce only; always-full rebuild; RepaintBoundary without splitting listenables.

### D31 - [x] Selection does not override entity color

**Context:** `_resolveColor` returned fixed selection blue whenever selected, so door/window color edits looked broken until deselect.

**Decision:** Prefer entity `colorValue` (then layer) even when selected. Grips mark selection. Fall back to selection blue only when neither entity nor layer color is set.

**Rationale:** Color picker must show results immediately while editing.

**Alternatives rejected:** Selection outline stroke only; dual-color (fill + selection edge) complexity.

### D32 - [x] Mac/Windows parity hardening (launchers + in-app)

**Context:** User wants the app to “work good” on Mac and Windows end-to-end: launch, setup, shortcuts, save, trackpad, layout — not only Chrome-on-Mac-dev.

**Decision:**
- **macOS setup launcher:** `Setup BonnieCAD.command` (Chrome check / optional brew cask; Flutter PATH or `~/.local/share/bon-cad-tools/flutter`; precache web; pub get). Open script searches the same paths and points users at Setup.
- **Windows Open:** Chrome preferred, **Edge fallback** as Flutter web device.
- **Save cancel:** `PlanFiles.saveText` returns `SaveResult`; desktop null = cancelled (do not mark saved); web null after picker = treat as saved download.
- **Shortcuts:** Cmd **or** Ctrl for file (N/O/S/Shift+S), undo/redo; menu tooltips.
- **Input:** handle `PointerScaleEvent` (pinch) + scroll zoom; pointer cancel clears pan; Material scrollBehavior includes mouse/trackpad for panels.
- **Layout:** side panel stacks under canvas when width is under 720.
- **Native shells:** keep `macos/` / `windows/` titled BonnieCAD for optional native runs; daily path remains web.

**Rationale:** DIY users on both OSes should double-click, get sane errors, and have identical CAD shortcuts without Xcode/VS.

**Alternatives rejected:** Shipping only web README steps; requiring native desktop as primary; always-mark-saved on null path.

---

## Summary table

| ID | Decision |
|----|----------|
| D1 | DIY homeowner primary persona |
| D2 | Flutter (Dart) stack |
| D3 | Inches canonical storage |
| D4 | **Web (Chrome) first** (revised from Windows→iOS) |
| D5 | Local files via picker/bytes (revised from path File I/O) |
| D6 | Core CAD MVP cut line (**furniture/styling shipped in feature plan**) |
| D7 | Product name: BonnieCAD |
| D8 | No `dart:io` in shared app code |
| D9 | file_picker 11 static API |
| D10 | Zoom: UI buttons + keyboard shortcuts (+ scroll) |
| D11 | Opening resize via on-canvas grips |
| D12 | Per-entity color + stroke width overrides |
| D13 | Large furniture library (20+) |
| D14 | Free symbols + wall-hosted electrical |
| D15 | Catalog defaults + optional instance resize |
| D16 | Double-click launchers + Windows self-setup scripts |
| D17 | Floor owns geometry; edit active floor only |
| D18 | Floor list in side panel (add/rename/delete) |
| D19 | Shared layers across floors |
| D20 | Free text labels at a point (no leader) |
| D21 | T tool click-place; side-panel edit |
| D22 | Swatches + Custom color dialog |
| D23 | Lock mode Free / Ortho / 45° / 15° (UI label Ortho → **90**) |
| D24 | Angle lock: wall draw + endpoint drag |
| D25 | Label fontSize in screen px |
| D26 | schemaVersion 3; v1/v2 → single Main floor |
| D27 | Door swing chips; hinge-correct paint |
| D28 | Opening width presets; hinge-aware SetOpeningWidth |
| D29 | Live measure label on opening resize |
| D30 | canvasListenable refresh vs full notifyUi |
| D31 | Selection keeps entity color (grips show selection) |
| D32 | Mac/Windows parity: setup on both, Edge fallback, save cancel, Cmd/Ctrl, pinch zoom, narrow layout |
