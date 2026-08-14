@echo off
setlocal EnableExtensions EnableDelayedExpansion
title BonnieCAD Setup (Windows)
cd /d "%~dp0"

echo.
echo ========================================
echo   BonnieCAD - one-time Windows setup
echo ========================================
echo.
echo This installs what is needed to run BonnieCAD in Chrome.
echo No Visual Studio or Xcode required.
echo.

:: ---- Chrome ----
set "CHROME="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles%\Google\Chrome\Application\chrome.exe"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME=%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME=%LocalAppData%\Google\Chrome\Application\chrome.exe"

if defined CHROME (
  echo [OK] Google Chrome found
) else (
  echo [..] Chrome not found. Trying winget install...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo [!!] winget not available. Install Chrome from:
    echo     https://www.google.com/chrome/
    echo     Then run this setup again.
    goto :fail
  )
  winget install -e --id Google.Chrome --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo [!!] Chrome install failed. Install manually, then re-run setup.
    goto :fail
  )
  echo [OK] Chrome installed
)

:: ---- Git (needed to download Flutter) ----
where git >nul 2>&1
if errorlevel 1 (
  echo [..] Git not found. Trying winget install...
  where winget >nul 2>&1
  if errorlevel 1 (
    echo [!!] Install Git from https://git-scm.com/download/win
    echo     then re-run this setup.
    goto :fail
  )
  winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
  if errorlevel 1 (
    echo [!!] Git install failed. Install from https://git-scm.com/download/win
    goto :fail
  )
  :: Refresh PATH for this session
  set "PATH=%ProgramFiles%\Git\cmd;%ProgramFiles(x86)%\Git\cmd;%PATH%"
  where git >nul 2>&1
  if errorlevel 1 (
    echo [!!] Git installed but not on PATH yet.
    echo     Close this window, open a NEW Command Prompt, and run setup again.
    goto :fail
  )
  echo [OK] Git installed
) else (
  echo [OK] Git found
)

:: ---- Flutter ----
set "FLUTTER_HOME=%LOCALAPPDATA%\bon-cad-tools\flutter"
set "FLUTTER_BAT=%FLUTTER_HOME%\bin\flutter.bat"

where flutter >nul 2>&1
if not errorlevel 1 (
  for /f "delims=" %%I in ('where flutter') do (
    set "FLUTTER_BAT=%%I"
    goto :flutter_ready
  )
)

if exist "%FLUTTER_BAT%" goto :flutter_ready

echo [..] Flutter not found. Downloading stable SDK (one-time, ~1 GB)...
echo     Location: %FLUTTER_HOME%
echo.

if not exist "%LOCALAPPDATA%\bon-cad-tools" mkdir "%LOCALAPPDATA%\bon-cad-tools"
if exist "%FLUTTER_HOME%" rmdir /s /q "%FLUTTER_HOME%" 2>nul

git clone https://github.com/flutter/flutter.git -b stable --depth 1 "%FLUTTER_HOME%"
if errorlevel 1 (
  echo [!!] Failed to download Flutter.
  echo     Check internet connection and try again.
  goto :fail
)

:flutter_ready
echo [OK] Flutter: %FLUTTER_BAT%
set "PATH=%FLUTTER_HOME%\bin;%PATH%"

echo.
echo [..] Running flutter doctor / precache (first time can take several minutes)...
call "%FLUTTER_BAT%" config --no-analytics >nul 2>&1
call "%FLUTTER_BAT%" precache --web
if errorlevel 1 (
  echo [!!] flutter precache failed.
  goto :fail
)

echo.
echo [..] Getting BonnieCAD packages...
cd /d "%~dp0app"
if not exist "pubspec.yaml" (
  echo [!!] Could not find app\pubspec.yaml
  goto :fail
)
call "%FLUTTER_BAT%" pub get
if errorlevel 1 (
  echo [!!] flutter pub get failed.
  goto :fail
)

:: Remember project root for tools / shortcuts
if not exist "%LOCALAPPDATA%\bon-cad-tools" mkdir "%LOCALAPPDATA%\bon-cad-tools"
> "%LOCALAPPDATA%\bon-cad-tools\project-root.txt" echo %~dp0
:: trim trailing backslash is fine; Open bat uses its own path

:: ---- Desktop shortcut ----
set "OPEN_BAT=%~dp0Open BonnieCAD.bat"
set "SHORTCUT_OK="
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$target = '%OPEN_BAT%';" ^
  "if (-not (Test-Path -LiteralPath $target)) { exit 1 };" ^
  "$desk = [Environment]::GetFolderPath('Desktop');" ^
  "if ([string]::IsNullOrWhiteSpace($desk) -or -not (Test-Path -LiteralPath $desk)) { exit 2 };" ^
  "$work = Split-Path -Parent $target;" ^
  "$lnkPath = Join-Path $desk 'BonnieCAD.lnk';" ^
  "$w = New-Object -ComObject WScript.Shell;" ^
  "$s = $w.CreateShortcut($lnkPath);" ^
  "$s.TargetPath = $target;" ^
  "$s.WorkingDirectory = $work;" ^
  "$s.WindowStyle = 1;" ^
  "$s.Description = 'Open BonnieCAD';" ^
  "$s.Save()"
if not errorlevel 1 (
  set "SHORTCUT_OK=1"
  echo [OK] Desktop shortcut: BonnieCAD.lnk
) else (
  echo [..] Could not create Desktop shortcut — use "Open BonnieCAD.bat" in the project folder
)

echo.
echo ========================================
echo   Setup complete!
echo ========================================
echo.
if defined SHORTCUT_OK (
  echo Desktop shortcut:  BonnieCAD
)
echo Project launcher:  Open BonnieCAD.bat
echo Leave the black window open while you use BonnieCAD.
echo.
echo Optional native Windows desktop ^(needs Visual Studio C++ workload^):
echo   cd app
echo   flutter run -d windows
echo.
echo [..] Starting BonnieCAD now...
start "" "%OPEN_BAT%"
echo.
echo A new window opened for the app. You can close this setup window.
echo.
pause
exit /b 0

:fail
echo.
echo Setup did not finish. Fix the messages above and try again.
echo.
pause
exit /b 1
