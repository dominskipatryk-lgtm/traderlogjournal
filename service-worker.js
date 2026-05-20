// TraderLogJournal Service Worker v1.0
// Strategia: cache-first dla assets, network-first dla danych

const CACHE_NAME = 'tlj-v7';
const OFFLINE_URL = '/';

// Pliki do cache przy instalacji (shell aplikacji)
const PRECACHE_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  '/logo_E_120.png',
  '/logo_E_512.png',
  'https://fonts.googleapis.com/css2?family=DM+Mono:wght@400;500&family=Syne:wght@400;600;700;800&family=DM+Sans:wght@300;400;500&display=swap'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(PRECACHE_ASSETS))
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  const { request } = event;
  const url = new URL(request.url);

  // Nie cachuj requestów do Supabase, Google APIs ani Drive
  if (
    url.hostname.includes('supabase') ||
    url.hostname.includes('googleapis') ||
    url.hostname.includes('accounts.google') ||
    request.method !== 'GET'
  ) {
    return;
  }

  // Cache-first dla assets (fonts, images, js)
  if (
    request.destination === 'image' ||
    request.destination === 'font' ||
    request.destination === 'style'
  ) {
    event.respondWith(
      caches.match(request).then(cached => cached || fetch(request).then(resp => {
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(c => c.put(request, clone));
        return resp;
      }))
    );
    return;
  }

  // Network-first dla HTML — przy braku sieci zwróć cache
  event.respondWith(
    fetch(request)
      .then(resp => {
        const clone = resp.clone();
        caches.open(CACHE_NAME).then(c => c.put(request, clone));
        return resp;
      })
      .catch(() => caches.match(request).then(cached => cached || caches.match(OFFLINE_URL)))
  );
});
