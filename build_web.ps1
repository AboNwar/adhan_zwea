# بناء نسخة الويب لتعمل بدون إنترنت (PWA)
# - تحزيم محرك CanvasKit محلياً بدل تحميله من إنترنت جوجل
# - تفعيل التخزين المؤقت offline-first عبر service worker
flutter build web --release --no-web-resources-cdn --pwa-strategy=offline-first

Write-Host ""
Write-Host "تم البناء. الملفات في: build/web" -ForegroundColor Green
Write-Host "ارفع محتويات مجلد build/web للاستضافة." -ForegroundColor Green
