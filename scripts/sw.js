/*
 * KJV Strong's Bible with Concordance
 * Copyright (C) 2026 Ron Turrentine
 * https://github.com/RonTurrentine/KJV-Strongs-EBook
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

/* ================================================================
   sw.js — Service Worker for offline PWA support
   ================================================================
   Strategy:
   - App shell (css/js/manifest/icons) — cache-first, cached on install
   - Bible chapter pages & dictionary pages — cache-on-visit (added to
     cache the first time they're successfully fetched while online)
   - Search page and its API calls — NEVER cached; always network,
     since it requires the live Bible SuperSearch API
   - Bulk "Download for Offline" — triggered via postMessage from the
     page; fetches and caches a whole list of URLs proactively
   ================================================================ */

const CACHE_VERSION = "kjv-cache-v1";
const APP_SHELL = [
    "/index.html",
    "/manifest.json",
    "/icon-192.png",
    "/icon-512.png",
    "/css/style.css",
    "/js/notes.js",
    "/js/fontsize.js",
    "/js/bookmarks.js",
    "/js/bible-data.js",
    "/js/sticky-header.js",
    "/BiblePencil.ico"
];

/* Never cache these — they need to always hit the network */
function isNeverCache(url) {
    return url.indexOf("/search.html") !== -1 ||
           url.indexOf("api.biblesupersearch.com") !== -1 ||
           url.indexOf("/api/") !== -1 ||
           url.indexOf("api.github.com") !== -1;
}

self.addEventListener("install", function (event) {
    event.waitUntil(
        caches.open(CACHE_VERSION).then(function (cache) {
            return cache.addAll(APP_SHELL);
        }).then(function () {
            return self.skipWaiting();
        })
    );
});

self.addEventListener("activate", function (event) {
    event.waitUntil(
        caches.keys().then(function (keys) {
            return Promise.all(
                keys.filter(function (k) { return k !== CACHE_VERSION; })
                    .map(function (k) { return caches.delete(k); })
            );
        }).then(function () {
            return self.clients.claim();
        })
    );
});

self.addEventListener("fetch", function (event) {
    var url = event.request.url;

    /* Only handle GET requests for our own origin */
    if (event.request.method !== "GET") { return; }
    if (isNeverCache(url)) { return; } /* let it hit network normally */

    event.respondWith(
        caches.match(event.request).then(function (cached) {
            if (cached) { return cached; }

            return fetch(event.request).then(function (response) {
                /* Cache-on-visit: store a copy for next time we're offline */
                if (response && response.status === 200) {
                    var responseClone = response.clone();
                    caches.open(CACHE_VERSION).then(function (cache) {
                        cache.put(event.request, responseClone);
                    });
                }
                return response;
            }).catch(function () {
                /* Offline and not cached — nothing we can do for this URL */
                return new Response(
                    "<html><body style='background:#0a0a0a;color:#ccc;font-family:sans-serif;padding:40px;text-align:center;'>" +
                    "<h2>Offline</h2><p>This page hasn't been downloaded for offline use yet.</p>" +
                    "<p><a href='/index.html' style='color:#00bcd4;'>Go to Home</a></p></body></html>",
                    { headers: { "Content-Type": "text/html" }, status: 503 }
                );
            });
        })
    );
});

/* ── Bulk download support ────────────────────────────────────────
   The page posts { type: "cache-urls", urls: [...], jobId: "..." }
   We fetch each URL and store it, reporting progress back via
   postMessage so the UI can show a progress bar.                 */

self.addEventListener("message", function (event) {
    var data = event.data;
    if (!data || data.type !== "cache-urls") { return; }

    var urls = data.urls || [];
    var jobId = data.jobId || "default";
    var client = event.source;

    caches.open(CACHE_VERSION).then(function (cache) {
        var done = 0;
        var total = urls.length;

        function cacheNext(i) {
            if (i >= urls.length) {
                if (client) {
                    client.postMessage({ type: "cache-progress", jobId: jobId, done: done, total: total, complete: true });
                }
                return;
            }
            fetch(urls[i]).then(function (resp) {
                if (resp && resp.status === 200) {
                    cache.put(urls[i], resp);
                }
                done++;
                if (client && (done % 25 === 0 || done === total)) {
                    client.postMessage({ type: "cache-progress", jobId: jobId, done: done, total: total, complete: false });
                }
                cacheNext(i + 1);
            }).catch(function () {
                done++;
                cacheNext(i + 1);
            });
        }
        cacheNext(0);
    });
});
