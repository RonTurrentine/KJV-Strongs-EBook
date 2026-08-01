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
   - App shell (css/js/manifest/icons) — cache-first, small, versioned
     by build SHA, safe to fully replace on every update
   - Bible chapter pages & dictionary pages — cache-on-visit, stored in
     a SEPARATE, unversioned, PERSISTENT cache that survives every app
     update. This split exists specifically because a person's
     downloaded-for-offline Bible/Lexicon (which can take a long time
     over WiFi) must never be silently wiped out just because the app's
     own code changed -- only the small shell cache is ever deleted on
     update, never this one.
   - Search page and its API calls — NEVER cached; always network,
     since it requires the live Bible SuperSearch API
   - Bulk "Download for Offline" — triggered via postMessage from the
     page; fetches and caches a whole list of URLs proactively
   - Updates do NOT take over automatically. A newly installed worker
     sits in the "waiting" state until the page explicitly says
     "skip-waiting" (driven by the person choosing "Update Now" in the
     update-available prompt) -- see the message handler below. Without
     this, there is no way to offer "Remind Me Later"/"Tomorrow": the
     old behavior activated (and wiped caches) the instant install
     finished, with no chance to ask first.
   ================================================================ */

const SHELL_CACHE = "kjv-shell-KJV_SHA_PLACEHOLDER";
const CONTENT_CACHE = "kjv-content";
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

function isAppShellUrl(url) {
    var pathname;
    try {
        pathname = new URL(url, self.location.origin).pathname;
    } catch (e) {
        return false;
    }
    return APP_SHELL.indexOf(pathname) !== -1;
}

/* Wraps fetch() with a hard timeout via AbortController. Without this,
   a fetch to an address that's only reachable on the home LAN (e.g.
   the phone's normal origin when away from home, with no server there
   to refuse the connection) can hang for 60+ seconds before the OS
   gives up -- which is exactly the "long pause, then Offline" pattern
   this exists to fix. `request` may be a URL string or a Request. */
function fetchWithTimeout(request, ms) {
    var controller = new AbortController();
    var timer = setTimeout(function () { controller.abort(); }, ms);
    var reqWithSignal = new Request(request, { signal: controller.signal });
    return fetch(reqWithSignal).then(function (resp) {
        clearTimeout(timer);
        return resp;
    }, function (err) {
        clearTimeout(timer);
        throw err;
    });
}

self.addEventListener("install", function (event) {
    event.waitUntil(
        caches.open(SHELL_CACHE).then(function (cache) {
            return cache.addAll(APP_SHELL);
        })
        /* No self.skipWaiting() here — see file header. */
    );
});

/* One-time migration: before this shell/content split existed, both
   lived together in a single "kjv-cache-<sha>" cache, which the OLD
   activate handler deleted wholesale on every update. The first time a
   phone updates past this version, rescue that cache's non-shell
   entries (i.e. someone's actual downloaded Bible/Lexicon pages) into
   the new persistent CONTENT_CACHE before removing it, so this one
   transition doesn't force yet another full re-download right when
   we're trying to fix exactly that problem. */
function migrateOldCombinedCache(oldCacheName) {
    return caches.open(oldCacheName).then(function (oldCache) {
        return caches.open(CONTENT_CACHE).then(function (contentCache) {
            return oldCache.keys().then(function (requests) {
                return Promise.all(requests.map(function (req) {
                    if (isAppShellUrl(req.url)) { return Promise.resolve(); }
                    return oldCache.match(req).then(function (resp) {
                        if (resp) { return contentCache.put(req, resp); }
                    });
                }));
            });
        });
    }).then(function () {
        return caches.delete(oldCacheName);
    });
}

self.addEventListener("activate", function (event) {
    event.waitUntil(
        caches.keys().then(function (keys) {
            var work = [];
            keys.forEach(function (k) {
                if (k.indexOf("kjv-cache-") === 0) {
                    work.push(migrateOldCombinedCache(k));
                } else if (k.indexOf("kjv-shell-") === 0 && k !== SHELL_CACHE) {
                    /* Previous versioned shell cache — small and
                       disposable, safe to delete immediately. */
                    work.push(caches.delete(k));
                }
                /* CONTENT_CACHE ("kjv-content") is intentionally never
                   touched here, for any reason. Wiping someone's
                   downloaded Bible/Lexicon just because the app's own
                   code changed is the entire bug this file exists to
                   fix — so nothing in this handler is allowed to
                   delete it, now or in any future edit of this file. */
            });
            return Promise.all(work);
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

    /* Stale-while-revalidate: if we have a cached copy, serve it
       INSTANTLY (offline/fast behavior is completely unchanged) -- but
       also always kick off a background fetch to refresh the cache for
       NEXT time. This matters because pure "cache-first" (the old
       strategy) ignores Cache-Control headers entirely once something is
       cached -- a page stays stale forever regardless of what the server
       says, until the cache name itself changes (which depends on a
       SHA-injection step that isn't reliably working). This way, content
       self-heals within one extra normal reload after being updated,
       without depending on that mechanism at all. */
    var targetCache = isAppShellUrl(url) ? SHELL_CACHE : CONTENT_CACHE;

    event.respondWith(
        caches.open(targetCache).then(function (cache) {
            return cache.match(event.request).then(function (cached) {
                var networkFetch = fetchWithTimeout(event.request, 8000).then(function (response) {
                    if (response && response.status === 200) {
                        cache.put(event.request, response.clone());
                    }
                    return response;
                }).catch(function () {
                    if (cached) { return cached; }
                    /* Offline and not cached — nothing we can do for this URL */
                    return new Response(
                        "<html><body style='background:#0a0a0a;color:#ccc;font-family:sans-serif;padding:40px;text-align:center;'>" +
                        "<h2>Offline</h2><p>This page hasn't been downloaded for offline use yet.</p>" +
                        "<p><a href='/index.html' style='color:#00bcd4;'>Go to Home</a></p></body></html>",
                        { headers: { "Content-Type": "text/html" }, status: 503 }
                    );
                });

                return cached || networkFetch;
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

    if (data.type === "skip-waiting") {
        /* The page's "Update Now" button (in its update-available
           prompt) is the only thing that sends this. Until it does,
           this worker just stays fully installed and idle in the
           "waiting" state — see file header. */
        self.skipWaiting();
        return;
    }

    if (data.type === "cancel-job") {
        var job = activeJobs[data.jobId];
        if (job) { job.cancelled = true; }
        return;
    }

    if (data.type !== "cache-urls") { return; }

    var urls = data.urls || [];
    var jobId = data.jobId || "default";
    var reportEvery = data.reportEvery || 25;
    var forceRefresh = !!data.forceRefresh;
    var client = event.source;
    var jobState = { cancelled: false };
    activeJobs[jobId] = jobState;

    /* event.waitUntil tells the browser this event isn't finished yet,
       so it won't terminate the service worker mid-download for being
       "idle". This only works if the promise passed to it doesn't
       resolve until the ENTIRE job is done — so cacheNext() must
       properly return/chain every step below, not just fire-and-forget. */
    var jobPromise = caches.open(CONTENT_CACHE).then(function (cache) {
        var done = 0;
        var total = urls.length;
        var failedUrls = [];

        function reportProgress(complete, cancelled) {
            if (client && (complete || cancelled || done % reportEvery === 0 || done === total)) {
                client.postMessage({
                    type: "cache-progress", jobId: jobId, done: done, total: total,
                    complete: !!complete, cancelled: !!cancelled, failed: failedUrls.length
                });
            }
        }

        /* A fetch that throws (dropped connection, DNS failure, our own
           timeout) or comes back with a non-200/non-404 status (e.g. a
           transient 500) is worth retrying -- a single WiFi hiccup
           shouldn't permanently mark a page as un-downloaded. A 404 is
           NOT retried: for the dictionary range in particular, many
           Strong's numbers simply have no entry, and that's an expected
           gap, not a failure. After MAX_ATTEMPTS, give up on this URL
           and record it as a real failure so the completion message can
           say so honestly, instead of silently claiming success. */
        var MAX_ATTEMPTS = 3;

        function fetchAndCache(i, attempt) {
            attempt = attempt || 1;
            return fetchWithTimeout(urls[i], 10000).then(function (resp) {
                if (resp && resp.status === 200) {
                    return cache.put(urls[i], resp).then(function () {
                        done++;
                        reportProgress(false, false);
                        return cacheNext(i + 1);
                    });
                }
                if (resp && resp.status === 404) {
                    done++;
                    reportProgress(false, false);
                    return cacheNext(i + 1);
                }
                return retryOrGiveUp(i, attempt);
            }).catch(function () {
                return retryOrGiveUp(i, attempt);
            });
        }

        function retryOrGiveUp(i, attempt) {
            if (attempt < MAX_ATTEMPTS) {
                return fetchAndCache(i, attempt + 1);
            }
            failedUrls.push(urls[i]);
            done++;
            reportProgress(false, false);
            return cacheNext(i + 1);
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

            if (forceRefresh) {
                /* "Refresh Offline Content": always re-fetch and
                   overwrite, even if already cached. This is how a
                   stale page (e.g. a chapter whose baked note content
                   changed on the PC after this page was first
                   downloaded) actually gets corrected -- the normal
                   resume-skip behavior below would otherwise leave it
                   untouched forever, since "already cached" and
                   "correctly up to date" aren't the same thing. */
                return fetchAndCache(i);
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
                return fetchAndCache(i);
            });
        }
        return cacheNext(0);
    });

    event.waitUntil(jobPromise);
});
