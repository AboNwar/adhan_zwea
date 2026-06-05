# بناء APK موقّع للإصدار
if (-not (Test-Path "android/key.properties")) {
    Write-Host "ملف android/key.properties غير موجود." -ForegroundColor Red
    Write-Host "شغّل أولاً: .\setup_signing.ps1" -ForegroundColor Yellow
    exit 1
}

flutter build apk --release
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "تم البناء. الملف:" -ForegroundColor Green
    Write-Host "build\app\outputs\flutter-apk\app-release.apk" -ForegroundColor Cyan
}
