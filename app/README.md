# bon_cad (Flutter app)

Flutter package for **BonnieCAD**. Prefer launching from the **repo root**, not this folder alone.

## Open the app

| OS | From repo root (`bon-cad/`) |
|----|----------------------------|
| macOS | Double-click `Open BonnieCAD.command` |
| Windows | First time: `Setup BonnieCAD.bat` · then `Open BonnieCAD.bat` |
| Any | `flutter pub get && flutter run -d chrome` |

See the root [README.md](../README.md) for shortcuts, features, and lessons learned.

## Package layout

```
lib/
  core/           units, ids, vec2
  domain/         document, walls, openings, furniture, catalog, commands, history
  geometry/       snap, segments
  render/         viewport, document_painter
  tools/          wall, select, opening, dimension, furniture, editor_controller
  persistence/    document_codec (schema v2), file_io (file_picker bytes)
  ui/             app_shell, editor_canvas
  main.dart
web/              Chrome host
test/             unit + widget smoke
```

## Quality

```bash
flutter test
dart analyze
```

## Notes for contributors

- **No `dart:io`** in shared `lib/` — web target.
- Document mutations go through `domain/commands.dart` + `History`.
- New entity fields: update model JSON, `DocumentCodec` (bump schema if breaking), painter, select/delete, tests.
- Furniture catalog: `domain/furniture_catalog.dart` (data only; draw styles in `document_painter.dart`).
