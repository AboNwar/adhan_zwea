@echo off
REM رفع المشروع إلى GitHub (أغلق Cursor/VS Code أو أي برنامج يستخدم Git ثم شغّل هذا الملف)
cd /d "%~dp0.."

if exist ".git\index.lock" (
    del /f ".git\index.lock"
    echo Removed index.lock
)

git add -A
if errorlevel 1 (
    echo Failed: git add. Close other programs using this folder and try again.
    exit /b 1
)

git status
echo.
set /p MSG="Enter commit message (or press Enter for default): "
if "%MSG%"=="" set "MSG=Update: adhan_zwea - notifications, silent mode, scripts, docs"

git commit -m "%MSG%"
if errorlevel 1 (
    echo Nothing to commit or commit failed.
    exit /b 1
)

git push origin main
if errorlevel 1 (
    echo Push failed. Check your internet and GitHub login.
    pause
    exit /b 1
)
echo.
echo Done. Pushed to https://github.com/AboNwar/adhan_zwea
pause
