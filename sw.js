/* Vom Startbildschirm aus soll die Seite auch ohne Netz etwas zeigen.
   Bewusst "Netz zuerst": Was der Server hat, gewinnt immer - so kann keine
   alte Fassung hängen bleiben. Der Zwischenspeicher springt nur ein, wenn
   gar nichts geht. Daten-Abrufe (api/, fremde Dienste) bleiben aussen vor. */
const CACHE = 'seekirchen-2';
const SCHALE = ['./', 'index.html', 'manifest.webmanifest',
                'icon-192.png', 'icon-512.png', 'apple-touch-icon.png',
                'zug.html'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SCHALE)).catch(() => {}));
  self.skipWaiting();
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys()
    .then(k => Promise.all(k.filter(n => n !== CACHE).map(n => caches.delete(n)))));
  self.clients.claim();
});
self.addEventListener('fetch', (e) => {
  const u = new URL(e.request.url);
  if (e.request.method !== 'GET' || u.origin !== location.origin) return;
  if (u.pathname.indexOf('/api/') >= 0) return;      // Daten nie aus dem Speicher
  e.respondWith(
    fetch(e.request)
      .then((r) => {
        if (r && r.ok) {
          const kopie = r.clone();
          caches.open(CACHE).then(c => c.put(e.request, kopie)).catch(() => {});
        }
        return r;
      })
      .catch(() => caches.match(e.request).then(t => t || caches.match('./')))
  );
});
