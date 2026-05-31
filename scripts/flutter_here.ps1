# Find Flutter then run: flutter clean, flutter pub get
# Run: .\scripts\flutter_here.ps1
# Or with path: .\scripts\flutter_here.ps1 -FlutterPath "C:\flutter"
# Or set env: $env:FLUTTER_ROOT = "C:\flutter"; .\scripts\flutter_here.ps1

param([string]$FlutterPath)

$flutterBin = $null
if ($FlutterPath -and (Test-Path (Join-Path $FlutterPath "bin\flutter.bat"))) {
    $flutterBin = (Join-Path $FlutterPath "bin")
}
if (-not $flutterBin -and $env:FLUTTER_ROOT -and (Test-Path (Join-Path $env:FLUTTER_ROOT "bin\flutter.bat"))) {
    $flutterBin = (Join-Path $env:FLUTTER_ROOT "bin")
}

$possiblePaths = @(
    "C:\flutter",
    "C:\src\flutter",
    "C:\src\dev\flutter",
    "C:\dev\flutter",
    "D:\flutter",
    "E:\flutter",
    (Join-Path $env:USERPROFILE "flutter"),
    (Join-Path $env:USERPROFILE "AppData\Local\flutter"),
    (Join-Path $env:USERPROFILE "AppData\Local\flutter_sdk"),
    (Join-Path $env:USERPROFILE "fvm\default"),
    (Join-Path $env:LOCALAPPDATA "flutter"),
    (Join-Path $env:LOCALAPPDATA "flutter_sdk"),
    (Join-Path $env:ProgramFiles "flutter"),
    (Join-Path $env:ProgramFiles "flutter_sdk"),
    (Join-Path $env:ProgramFiles "Fvm" "default"),
    (Join-Path ${env:ProgramFiles(x86)} "flutter"),
    (Join-Path $env:APPDATA "flutter"),
    (Join-Path $env:APPDATA "flutter_sdk")
)

if (-not $flutterBin) {
foreach ($p in $possiblePaths) {
    if ($p -and (Test-Path (Join-Path $p "bin\flutter.bat"))) {
        $flutterBin = (Join-Path $p "bin")
        break
    }
}
}

if (-not $flutterBin) {
    $pathDirs = $env:Path -split ';'
    foreach ($d in $pathDirs) {
        if ($d -and (Test-Path (Join-Path $d "flutter.bat"))) {
            $flutterBin = $d
            break
        }
    }
}

if ($flutterBin) {
    $env:Path = "$flutterBin;$env:Path"
    Write-Host "Using Flutter from: $flutterBin"
    Set-Location (Join-Path $PSScriptRoot "..")
    & flutter clean
    & flutter pub get
    Write-Host "Done."
} else {
    Write-Host "Flutter not found in PATH or in the usual folders."
    Write-Host ""
    Write-Host "Do one of the following:"
    Write-Host "  1. Pass your Flutter folder when running this script:"
    Write-Host "     .\scripts\flutter_here.ps1 -FlutterPath ""C:\path\to\flutter"""
    Write-Host "     (Use the folder that CONTAINS the 'bin' folder with flutter.bat inside)"
    Write-Host ""
    Write-Host "  2. Or use the .bat file with the path:"
    Write-Host "     .\scripts\flutter_here.bat C:\path\to\flutter"
    Write-Host ""
    Write-Host "  3. Or add Flutter's bin folder to your system PATH (Environment Variables)."
    Write-Host ""
    Write-Host "Searched in:"
    $possiblePaths | ForEach-Object { Write-Host "  $_" }
}
