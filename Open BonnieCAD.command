#!/bin/zsh
# Double-click this file in Finder to open BonnieCAD in Chrome.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}/app"

TOOLS_HOME="${HOME}/.local/share/bon-cad-tools"
FLUTTER_HOME="${TOOLS_HOME}/flutter"
export PATH="$HOME/flutter/bin:${FLUTTER_HOME}/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

if [[ ! -f pubspec.yaml ]]; then
  osascript -e 'display alert "BonnieCAD folder incomplete" message "Could not find app/pubspec.yaml next to this launcher." as critical' >/dev/null 2>&1 || true
  echo "Could not find app/pubspec.yaml"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  osascript -e 'display alert "Flutter not found" message "Double-click Setup BonnieCAD.command once, then try Open again.\n\nOr install Flutter and put it on your PATH." as critical' >/dev/null 2>&1 || true
  echo "Flutter not found. Run Setup BonnieCAD.command first."
  exit 1
fi

if [[ ! -d "/Applications/Google Chrome.app" ]] && ! command -v google-chrome >/dev/null 2>&1; then
  osascript -e 'display alert "Chrome not found" message "Install Google Chrome or run Setup BonnieCAD.command." as critical' >/dev/null 2>&1 || true
  echo "Chrome not found."
  exit 1
fi

echo "Starting BonnieCAD in Chrome…"
echo "(Leave this window open while you use the app. Close it or press Ctrl+C to stop.)"
echo ""

# Upgrade Flutter when this is the Setup-managed SDK (skip PATH-only installs).
FLUTTER_BIN="$(command -v flutter)"
if [[ "${FLUTTER_BIN:A}" == "${FLUTTER_HOME:A}/bin/flutter" ]]; then
  echo "[..] Checking for Flutter updates…"
  if ! flutter upgrade --verify-only >/dev/null 2>&1; then
    echo "[..] Updating Flutter (may take a few minutes)…"
    flutter upgrade || echo "[!!] Flutter upgrade failed — continuing with current SDK."
    flutter precache --web || true
  else
    echo "[OK] Flutter is up to date"
  fi
fi

echo "[..] Getting BonnieCAD packages…"
flutter pub get
exec flutter run -d chrome
