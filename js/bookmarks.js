/* ================================================================
   bookmarks.js — Reading position tracker for KJV Strong's Bible
   ================================================================
   Target: Android 2.3 WebKit (Kindle Fire D01E)
   ES3 compatible — no let/const/arrow functions

   Features:
     - Auto-saves reading position on scroll (throttled to every 3s)
     - Saves on link/button click (captures position before navigation)
     - Shows "Resume reading" prompt on index.html
     - Graceful fallback: localStorage → cookie → window.name

   Depends on: window._kjvStore (created by fontsize.js if loaded
   first, or created here if bookmarks.js loads first)
   ================================================================ */

(function () {

    /* ── Storage abstraction (shared via window._kjvStore) ──────── */
    /* Identical to fontsize.js — whichever loads first creates it  */

    if (!window._kjvStore) {
        window._kjvStore = (function () {
            var _ls = false;
            var _ck = false;

            try {
                window.localStorage.setItem("_kjv_test", "1");
                window.localStorage.removeItem("_kjv_test");
                _ls = true;
            } catch (e) { }

            if (!_ls) {
                try {
                    document.cookie = "_kjv_test=1";
                    _ck = (document.cookie.indexOf("_kjv_test=1") !== -1);
                    document.cookie = "_kjv_test=;expires=Thu, 01 Jan 1970 00:00:00 GMT";
                } catch (e) { }
            }

            return {
                get: function (key) {
                    var i, c, parts, pair;
                    if (_ls) {
                        try {
                            var val = window.localStorage.getItem(key);
                            if (val !== null) { return val; }
                        } catch (e) { }
                    }
                    if (_ck) {
                        parts = document.cookie.split(";");
                        for (i = 0; i < parts.length; i++) {
                            c = parts[i].replace(/^\s+/, "");
                            if (c.indexOf(key + "=") === 0) {
                                return decodeURIComponent(c.substring(key.length + 1));
                            }
                        }
                    }
                    parts = (window.name || "").split("|");
                    for (i = 0; i < parts.length; i++) {
                        pair = parts[i].split("=");
                        if (pair[0] === key) { return pair[1] || null; }
                    }
                    return null;
                },
                set: function (key, val) {
                    var i, parts, found, newParts, d;
                    if (_ls) {
                        try { window.localStorage.setItem(key, val); return; }
                        catch (e) { }
                    }
                    if (_ck) {
                        d = new Date();
                        d.setTime(d.getTime() + 315360000000);
                        document.cookie = key + "=" + encodeURIComponent(val) +
                            ";expires=" + d.toUTCString() + ";path=/";
                        return;
                    }
                    parts = (window.name || "").split("|");
                    found = false;
                    newParts = [];
                    for (i = 0; i < parts.length; i++) {
                        if (parts[i].split("=")[0] === key) {
                            newParts.push(key + "=" + val);
                            found = true;
                        } else if (parts[i]) { newParts.push(parts[i]); }
                    }
                    if (!found) { newParts.push(key + "=" + val); }
                    window.name = newParts.join("|");
                }
            };
        })();
    }

    var store = window._kjvStore;
    var KEY_URL = "kjv_bm_url";
    var KEY_SCROLL = "kjv_bm_scroll";
    var KEY_TITLE = "kjv_bm_title";

    /* ── Helper: cross-browser scroll position ─────────────────── */

    function getScrollTop() {
        return document.documentElement.scrollTop || document.body.scrollTop || 0;
    }

    /* ── Helper: cross-browser addEventListener ────────────────── */

    function addEvent(el, type, fn) {
        if (el.addEventListener) {
            el.addEventListener(type, fn, false);
        } else if (el.attachEvent) {
            el.attachEvent("on" + type, fn);
        }
    }

    /* ── Detect page type ──────────────────────────────────────── */

    var pagePath = window.location.pathname || "";
    var pageFile = pagePath.substring(pagePath.lastIndexOf("/") + 1);
    var isIndex = (pageFile === "index.html" || pageFile === "" || pageFile === "/");
    var isChapter = (pagePath.indexOf("/books/") !== -1);

    /* ── Chapter pages: save reading position ──────────────────── */

    if (isChapter) {
        /* Extract a nice title from the page <title> or <h1> */
        var pageTitle = "";
        var h1 = document.getElementsByTagName("h1");
        if (h1.length > 0) {
            pageTitle = h1[0].innerText || h1[0].textContent || "";
        }
        if (!pageTitle) {
            pageTitle = document.title || "";
        }

        /* Build a relative URL that works from index.html's perspective.
           The page URL might be:
             file:///data/local/tmp/books/01-Gen/3.html
           We need to store:
             books/01-Gen/3.html
           Extract from the path by finding /books/ */
        var relUrl = "";
        var booksIdx = pagePath.indexOf("/books/");
        if (booksIdx !== -1) {
            relUrl = pagePath.substring(booksIdx + 1); /* "books/01-Gen/3.html" */
        }

        /**
         * Saves the current scroll position. Called on throttled
         * scroll and on link click.
         */
        function savePosition() {
            if (!relUrl) { return; }
            var scroll = getScrollTop();
            store.set(KEY_URL, relUrl);
            store.set(KEY_SCROLL, String(scroll));
            store.set(KEY_TITLE, pageTitle);
        }

        /* ── Save on scroll (throttled to every 3 seconds) ─────── */
        /* More reliable than beforeunload on old Android WebKit    */

        var lastSave = 0;

        addEvent(window, "scroll", function () {
            var now = new Date().getTime();
            if (now - lastSave < 3000) { return; }
            lastSave = now;
            savePosition();
        });

        /* ── Save on any link/button click (catches navigation) ── */

        addEvent(document, "click", function (e) {
            var target = e.target || e.srcElement;
            /* Walk up to find if an <a> was clicked */
            while (target && target.tagName !== "A" && target.tagName !== "BUTTON") {
                target = target.parentNode;
            }
            if (target && (target.tagName === "A" || target.tagName === "BUTTON")) {
                savePosition();
            }
        });

        /* ── Also try beforeunload as a belt-and-suspenders ─────── */
        /* May not fire on old Android, but costs nothing to try     */

        try {
            window.onbeforeunload = function () {
                savePosition();
                return undefined; /* Don't show a confirmation dialog */
            };
        } catch (e) { /* Some old WebKit throws on setting this */ }

        /* ── Save immediately on load (in case user just arrived) ─ */

        savePosition();

        /* ── Restore scroll position if returning to same page ──── */
        /* Small delay lets the browser finish layout first          */

        var savedUrl = store.get(KEY_URL);
        var savedScroll = store.get(KEY_SCROLL);
        if (savedUrl && relUrl === savedUrl && savedScroll) {
            var scrollTarget = parseInt(savedScroll, 10);
            if (scrollTarget > 0) {
                setTimeout(function () {
                    window.scrollTo(0, scrollTarget);
                }, 100);
            }
        }
    }

    /* ── Index page: show resume prompt ────────────────────────── */

    if (isIndex) {
        var bmUrl = store.get(KEY_URL);
        var bmTitle = store.get(KEY_TITLE);

        if (bmUrl && bmTitle) {
            /* Build the resume prompt and insert at top of page */
            var prompt = document.createElement("div");
            prompt.className = "resume-prompt";

            var link = document.createElement("a");
            link.href = bmUrl;
            link.appendChild(document.createTextNode("Resume: " + bmTitle));

            prompt.appendChild(link);

            /* Insert before the first child of body, or after h1 */
            var body = document.body;
            if (body.firstChild) {
                body.insertBefore(prompt, body.firstChild);
            } else {
                body.appendChild(prompt);
            }
        }
    }

})();
