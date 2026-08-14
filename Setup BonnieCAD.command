#!/bin/zsh
# One-time macOS setup for BonnieCAD (Chrome + Flutter web).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

export PATH="$HOME/flutter/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"
TOOLS_HOME="${HOME}/.local/share/bon-cad-tools"
FLUTTER_HOME="${TOOLS_HOME}/flutter"

echo ""
echo "========================================"
echo "  BonnieCAD - one-time macOS setup"
echo "========================================"
echo ""
echo "Installs what is needed to run BonnieCAD in Chrome."
echo "No Xcode or Visual Studio required."
echo ""

# ---- Chrome ----
if [[ -d "/Applications/Google Chrome.app" ]] || command -v google-chrome >/dev/null 2>&1; then
  echo "[OK] Google Chrome found"
else
  echo "[..] Chrome not found."
  if command -v brew >/dev/null 2>&1; then
    echo "     Installing via Homebrew (cask)..."
    brew install --cask google-chrome
    echo "[OK] Chrome installed"
  else
    echo "[!!] Install Chrome from https://www.google.com/chrome/"
    echo "     then run this setup again."
    echo ""
    osascript -e 'display alert "Chrome required" message "Install Google Chrome, then run Setup BonnieCAD.command again." as critical' >/dev/null 2>&1 || true
    exit 1
  fi
fi

# ---- Flutter ----
if command -v flutter >/dev/null 2>&1; then
  FLUTTER_BIN="$(command -v flutter)"
  echo "[OK] Flutter on PATH: $FLUTTER_BIN"
elif [[ -x "${FLUTTER_HOME}/bin/flutter" ]]; then
  export PATH="${FLUTTER_HOME}/bin:$PATH"
  echo "[OK] Flutter: ${FLUTTER_HOME}/bin/flutter"
else
  echo "[..] Flutter not found. Downloading stable SDK (one-time, ~1 GB)..."
  echo "     Location: ${FLUTTER_HOME}"
  echo ""
  if ! command -v git >/dev/null 2>&1; then
    echo "[!!] Git is required. Install Xcode CLT: xcode-select --install"
    echo "     or install Git, then re-run setup."
    osascript -e 'display alert "Git required" message "Install Git (xcode-select --install), then run setup again." as critical' >/dev/null 2>&1 || true
    exit 1
  fi
  mkdir -p "${TOOLS_HOME}"
  rm -rf "${FLUTTER_HOME}"
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "${FLUTTER_HOME}"
  export PATH="${FLUTTER_HOME}/bin:$PATH"
  echo "[OK] Flutter downloaded"
fi

echo ""
echo "[..] flutter config / precache (first time can take several minutes)..."
flutter config --no-analytics >/dev/null 2>&1 || true
flutter precache --web
echo ""
echo "[..] Getting BonnieCAD packages..."
cd "${ROOT}/app"
if [[ ! -f pubspec.yaml ]]; then
  echo "[!!] Could not find app/pubspec.yaml"
  exit 1
fi
flutter pub get

# Ensure launcher is executable
chmod +x "${ROOT}/Open BonnieCAD.command" 2>/dev/null || true
chmod +x "${ROOT}/Setup BonnieCAD.command" 2>/dev/null || true

# Remember project root (Desktop shortcut / future opens)
mkdir -p "${TOOLS_HOME}"
printf '%s\n' "${ROOT}" > "${TOOLS_HOME}/project-root"

# ---- Desktop shortcut ----
DESKTOP="${HOME}/Desktop"
if [[ ! -d "${DESKTOP}" ]]; then
  DESKTOP="$(osascript -e 'POSIX path of (path to desktop folder)' 2>/dev/null | sed 's:/*$::' || true)"
fi
SHORTCUT=""
if [[ -n "${DESKTOP}" && -d "${DESKTOP}" ]]; then
  SHORTCUT="${DESKTOP}/BonnieCAD.command"
  cat > "${SHORTCUT}" <<EOF
#!/bin/zsh
# Desktop shortcut — created by Setup BonnieCAD.command
exec "${ROOT}/Open BonnieCAD.command"
EOF
  chmod +x "${SHORTCUT}"
  # Clear quarantine so double-click works without an extra Gatekeeper dance when possible
  xattr -d com.apple.quarantine "${SHORTCUT}" 2>/dev/null || true
  echo "[OK] Desktop shortcut: ${SHORTCUT}"
else
  echo "[..] Desktop folder not found — skip shortcut (use Open BonnieCAD.command in the project folder)"
fi

echo ""
echo "========================================"
echo "  Setup complete!"
echo "========================================"
echo ""
if [[ -n "${SHORTCUT}" ]]; then
  echo "Desktop shortcut:  BonnieCAD.command"
fi
echo "Project launcher:  Open BonnieCAD.command"
echo "Leave the Terminal window open while you use the app."
echo ""
echo "[..] Starting BonnieCAD now..."
osascript -e 'display notification "Starting BonnieCAD…" with title "BonnieCAD setup complete"' >/dev/null 2>&1 || true

# Open in a new Terminal window so this setup window can finish cleanly
open "${ROOT}/Open BonnieCAD.command"
