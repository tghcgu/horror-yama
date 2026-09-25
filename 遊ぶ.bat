@echo off
rem Double-click to play the game (no editor).
set GODOT=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe
if not exist "%GODOT%" (
  echo Godot was not found: %GODOT%
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
