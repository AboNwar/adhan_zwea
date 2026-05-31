@echo off
REM عرض الأجهزة المتصلة عبر adb (بدون إضافة adb إلى PATH)
REM يبحث في مسارات Android SDK الشائعة

set "ADB="
if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if exist "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" set "ADB=%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if exist "%ANDROID_HOME%\platform-tools\adb.exe" set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"

if not defined ADB (
    echo adb not found. Install Android SDK Platform-Tools:
    echo https://developer.android.com/studio/releases/platform-tools
    echo Or install Android Studio - it includes adb in:
    echo   %%LOCALAPPDATA%%\Android\Sdk\platform-tools\
    exit /b 1
)

echo Using: %ADB%
echo.
"%ADB%" devices
