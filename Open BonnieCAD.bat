@echo off
setlocal EnableExtensions
title BonnieCAD
cd /d "%~dp0"

:: Prefer project-local Flutter from Setup, then PATH
set "FLUTTER_HOME=%LOCALAPPDATA%\bon-cad-tools\flutter"
set "FLUTTER_BAT="

if exist "%FLUTTER_HOME%\bin\flutter.bat" set "FLUTTER_BAT=%FLUTTER_HOME%\bin\flutter.bat"
if not defined FLUTTER_BAT (
  where flutter >nul 2>&1
  if not errorlevel 1 (
    for /f "delims=" %%I in ('where flutter') do (
      set "FLUTTER_BAT=%%I"
      goto :flutter_found
    )
  )
)
:flutter_found

if not defined FLUTTER_BAT (
  echo.
  echo Flutter is not installed yet.
  echo.
  echo Double-click  "Setup BonnieCAD.bat"  first  ^(one-time download^).
  echo.
  pause
  exit /b 1
)

set "PATH=%FLUTTER_HOME%\bin;%PATH%"

:: Chrome preferred; Edge is a fallback Flutter web device on Windows
set "CHROME_OK="
set "EDGE_OK="
if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" set "CHROME_OK=1"
if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" set "CHROME_OK=1"
if exist "%LocalAppData%\Google\Chrome\Application\chrome.exe" set "CHROME_OK=1"
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" set "EDGE_OK=1"
if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" set "EDGE_OK=1"

set "DEVICE=chrome"
if not defined CHROME_OK (
  if defined EDGE_OK (
    set "DEVICE=edge"
    echo Chrome not found — using Microsoft Edge.
  ) else (
    echo Chrome not found. Run "Setup BonnieCAD.bat" or install Chrome, then try again.
    pause
    exit /b 1
  )
)

cd /d "%~dp0app"
if not exist "pubspec.yaml" (
  echo Could not find app\pubspec.yaml. Is this the BonnieCAD folder?
  pause
  exit /b 1
)

echo Starting BonnieCAD in %DEVICE%...
echo Leave this window open while you use the app.
echo Close it or press Ctrl+C to stop.
echo.

call "%FLUTTER_BAT%" pub get
if errorlevel 1 (
  echo.
  echo flutter pub get failed. Run "Setup BonnieCAD.bat" again.
  echo.
  pause
  exit /b 1
)

call "%FLUTTER_BAT%" run -d %DEVICE%
set "ERR=%ERRORLEVEL%"

if not "%ERR%"=="0" (
  echo.
  echo BonnieCAD exited with an error.
  echo If this is the first time on this PC, run "Setup BonnieCAD.bat".
  echo.
  pause
)
exit /b %ERR%
