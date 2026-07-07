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

const CACHE_VERSION = "kjv-cache-2e536807d8cba1ce08fe5aa4eff82f331289570e";
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

/* Tracks in-progress bulk-download jobs so they can be cancelled
   mid-flight via a "cancel-job" message from the page. */
var activeJobs = {};

self.addEventListener("message", function (event) {
    var data = event.data;
    if (!data) { return; }

    if (data.type === "cancel-job") {
        var job = activeJobs[data.jobId];
        if (job) { job.cancelled = true; }
        return;
    }

    if (data.type !== "cache-urls") { return; }

    var urls = data.urls || [];
    var jobId = data.jobId || "default";
    var reportEvery = data.reportEvery || 25;
    var client = event.source;
    var jobState = { cancelled: false };
    activeJobs[jobId] = jobState;

    /* event.waitUntil tells the browser this event isn't finished yet,
       so it won't terminate the service worker mid-download for being
       "idle". This only works if the promise passed to it doesn't
       resolve until the ENTIRE job is done — so cacheNext() must
       properly return/chain every step below, not just fire-and-forget. */
    var jobPromise = caches.open(CACHE_VERSION).then(function (cache) {
        var done = 0;
        var total = urls.length;

        function reportProgress(complete, cancelled) {
            if (client && (complete || cancelled || done % reportEvery === 0 || done === total)) {
                client.postMessage({ type: "cache-progress", jobId: jobId, done: done, total: total, complete: !!complete, cancelled: !!cancelled });
            }
        }

        function cacheNext(i) {
            if (jobState.cancelled) {
                delete activeJobs[jobId];
                reportProgress(false, true);
                return Promise.resolve();
            }
            if (i >= urls.length) {
                delete activeJobs[jobId];
                reportProgress(true, false);
                return Promise.resolve();
            }
            /* Resume support: if this URL is already cached (e.g. from
               an earlier, interrupted run of this same download), skip
               straight past it instead of re-fetching. */
            return cache.match(urls[i]).then(function (existing) {
                if (existing) {
                    done++;
                    reportProgress(false, false);
                    return cacheNext(i + 1);
                }
                return fetch(urls[i]).then(function (resp) {
                    if (resp && resp.status === 200) {
                        return cache.put(urls[i], resp).then(function () {
                            done++;
                            reportProgress(false, false);
                            return cacheNext(i + 1);
                        });
                    }
                    done++;
                    reportProgress(false, false);
                    return cacheNext(i + 1);
                }).catch(function () {
                    done++;
                    reportProgress(false, false);
                    return cacheNext(i + 1);
                });
            });
        }
        return cacheNext(0);
    });

    event.waitUntil(jobPromise);
});
