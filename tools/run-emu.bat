@echo off
REM Launches an Android emulator with optimal flags for Flutter dev.
REM Usage:
REM   tools\run-emu.bat                       -> launches Pixel_8_Pro (default)
REM   tools\run-emu.bat flutter_emulator      -> launches the named AVD
REM   tools\run-emu.bat -cold                 -> cold boot Pixel_8_Pro (skip snapshot)
REM   tools\run-emu.bat flutter_emulator -cold-> cold boot the named AVD
REM   tools\run-emu.bat -list                 -> lists available AVDs

setlocal

set "EMU=C:\Android\Sdk\emulator\emulator.exe"
if not exist "%EMU%" (
  echo [run-emu] Emulator not found at %EMU%
  exit /b 1
)

if /I "%~1"=="-list" (
  "%EMU%" -list-avds
  exit /b 0
)

set "AVD=flutter_fast"
set "EXTRA="

:parse
if "%~1"=="" goto launch
if /I "%~1"=="-cold" (
  set "EXTRA=%EXTRA% -no-snapshot-load"
  shift
  goto parse
)
set "AVD=%~1"
shift
goto parse

:launch
echo [run-emu] Launching %AVD%  (GPU mode from config.ini, fast-boot, no-boot-anim)
if not "%EXTRA%"=="" echo [run-emu] Extra flags:%EXTRA%
start "Android Emulator - %AVD%" "%EMU%" -avd %AVD% -no-boot-anim -netfast%EXTRA%

endlocal
