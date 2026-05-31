@echo off
REM Run Flutter clean + pub get. Uses Flutter from PATH or from first argument.
REM Example: flutter_here.bat
REM Example: flutter_here.bat C:\flutter

REM Flutter on Windows needs PowerShell in PATH (flutter tool invokes it)
set "PSPATH="
if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" set "PSPATH=C:\Windows\System32\WindowsPowerShell\v1.0"
if exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" set "PSPATH=%SystemRoot%\System32\WindowsPowerShell\v1.0"
if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "PSPATH=%ProgramFiles%\PowerShell\7"
if defined PSPATH set "PATH=%PSPATH%;%SystemRoot%\System32;%PATH%"

set "FLUTTER_DIR=%~1"
if "%FLUTTER_DIR%"=="" set "FLUTTER_DIR=%FLUTTER_ROOT%"
if "%FLUTTER_DIR%"=="" if exist "%~dp0flutter_path.txt" set /p FLUTTER_DIR=<"%~dp0flutter_path.txt"

if defined FLUTTER_DIR (
    if exist "%FLUTTER_DIR%\bin\flutter.bat" (
        set "PATH=%FLUTTER_DIR%\bin;%PATH%"
        echo Using Flutter from: %FLUTTER_DIR%\bin
    ) else (
        echo Flutter folder not found: %FLUTTER_DIR%
        echo Use the folder that CONTAINS the bin folder (e.g. C:\flutter)
        echo Example: scripts\flutter_here.bat C:\flutter
        exit /b 1
    )
)

cd /d "%~dp0.."
where flutter >nul 2>&1
if errorlevel 1 (
    echo Flutter not found. Pass your Flutter folder as first argument:
    echo   scripts\flutter_here.bat C:\path\to\flutter
    echo Use the folder that contains the "bin" folder with flutter.bat inside.
    exit /b 1
)
flutter clean
flutter pub get
echo Done.
