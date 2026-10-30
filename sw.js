/* Service Worker لنسخة الويب: تخزين التطبيق والمواقيت للعمل دون إنترنت بعد أول زيارة */
const CACHE_NAME = 'adhan-zwea-offline-v2';

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) =>
      cache.addAll([
        './',
        './index.html',
        './manifest.json',
        './flutter_bootstrap.js',
        './favicon.png',
        './icons/Icon-192.png',
        './icons/Icon-512.png',
      ]).catch(() => undefined)
    )
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((key) => key !== CACHE_NAME)
          .map((key) => caches.delete(key))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cached) => {
      const networkFetch = fetch(event.request)
        .then((response) => {
          if (response && response.ok) {
            const copy = response.clone();
            caches.open(CACHE_NAME).then((cache) => {
              cache.put(event.request, copy);
            });
          }
          return response;
        })
        .catch(() => cached);

      // أثناء عدم الاتصال: استخدم الكاش، وإلا حدّث من الشبكة وخزّن
      return cached || networkFetch;
    })
  );
});
