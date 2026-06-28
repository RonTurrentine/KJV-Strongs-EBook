/*
 * KJV Strong's Bible with Concordance
 * Copyright (C) 2026 Ron Turrentine
 * https://github.com/RonTurrentine/KJV-Strongs-EBook
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

/* ================================================================
   fontsize.js — Increase/Decrease font size for KJV Strong's Bible
   ================================================================
   Target: Android 2.3 WebKit (Kindle Fire D01E)
   ES3 compatible — no let/const/arrow functions/forEach

   Storage fallback chain (for file:// URLs where localStorage
   is blocked):
     1. localStorage  (works on http://, blocked on file://)
     2. cookies       (may work on file:// in some WebKit builds)
     3. window.name   (persists across same-tab navigation)
     4. in-memory     (lost on tab close, but buttons still work)

   Exposes globally:
     window.increaseFontSize()   — steps up one size (if not at max)
     window.decreaseFontSize()   — steps down one size (if not at min)
     window.updateFontButtons()  — syncs button disabled/enabled state

   Expected HTML:
     <button class="btn" id="font-increase"
             onclick="increaseFontSize()">A&#8593;</button>
     <button class="btn" id="font-decrease"
             onclick="decreaseFontSize()">a&#8595;</button>

   Expected CSS:
     .btn-disabled { opacity: 0.4; color: #555; cursor: default; }
   ================================================================ */

(function () {

    /* ============================================================
       Storage abstraction (shared via window._kjvStore)
       ============================================================
       Identical to the copy in bookmarks.js. Whichever script
       loads first creates the object; the other reuses it.        */

    if (!window._kjvStore) {
        window._kjvStore = (function () {
            var _ls = false;
            var _ck = false;

            /* Test localStorage */
            try {
                window.localStorage.setItem("_kjv_test", "1");
                window.localStorage.removeItem("_kjv_test");
                _ls = true;
            } catch (e) { /* blocked on file:// */ }

            /* Test cookies */
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

                    /* 1. localStorage */
                    if (_ls) {
                        try {
                            var val = window.localStorage.getItem(key);
                            if (val !== null) { return val; }
                        } catch (e) { }
                    }

                    /* 2. Cookie */
                    if (_ck) {
                        parts = document.cookie.split(";");
                        for (i = 0; i < parts.length; i++) {
                            c = parts[i].replace(/^\s+/, "");
                            if (c.indexOf(key + "=") === 0) {
                                return decodeURIComponent(c.substring(key.length + 1));
                            }
                        }
                    }

                    /* 3. window.name */
                    parts = (window.name || "").split("|");
                    for (i = 0; i < parts.length; i++) {
                        pair = parts[i].split("=");
                        if (pair[0] === key) {
                            return pair[1] || null;
                        }
                    }

                    return null;
                },

                set: function (key, val) {
                    var i, parts, found, newParts, d;

                    /* 1. localStorage */
                    if (_ls) {
                        try {
                            window.localStorage.setItem(key, val);
                            return;
                        } catch (e) { }
                    }

                    /* 2. Cookie (10-year expiry) */
                    if (_ck) {
                        d = new Date();
                        d.setTime(d.getTime() + 315360000000);
                        document.cookie = key + "=" + encodeURIComponent(val) +
                            ";expires=" + d.toUTCString() + ";path=/";
                        return;
                    }

                    /* 3. window.name */
                    parts = (window.name || "").split("|");
                    found = false;
                    newParts = [];
                    for (i = 0; i < parts.length; i++) {
                        if (parts[i].split("=")[0] === key) {
                            newParts.push(key + "=" + val);
                            found = true;
                        } else if (parts[i]) {
                            newParts.push(parts[i]);
                        }
                    }
                    if (!found) { newParts.push(key + "=" + val); }
                    window.name = newParts.join("|");
                }
            };
        })();
    }

    var store = window._kjvStore;

    /* ============================================================
       Font size logic
       ============================================================ */

    var SIZES = ["font-small", "font-normal", "font-large", "font-xlarge"];
    var MIN_IDX = 0;
    var MAX_IDX = SIZES.length - 1;
    var DEFAULT_SIZE = "font-normal";
    var KEY = "kjv_fontsize";

    /* -- Class helpers ------------------------------------------  */

    function addClass(el, cls) {
        if (el.className.indexOf(cls) === -1) {
            el.className = el.className + " " + cls;
        }
    }

    function removeClass(el, cls) {
        el.className = el.className
            .replace(new RegExp("\\s*\\b" + cls + "\\b", "g"), "");
    }

    /* -- Get current size index ---------------------------------  */

    function getCurrentIndex() {
        var cls = document.body.className || "";
        for (var i = 0; i < SIZES.length; i++) {
            if (cls.indexOf(SIZES[i]) !== -1) {
                return i;
            }
        }
        /* No font-* class found — treat as default (font-normal) */
        return 1;
    }

    /* -- Apply a size by index ----------------------------------  */

    function applySize(idx) {
        /* Clamp to valid range */
        if (idx < MIN_IDX) { idx = MIN_IDX; }
        if (idx > MAX_IDX) { idx = MAX_IDX; }

        var sizeClass = SIZES[idx];

        /* Remove any existing font-* class from body */
        var cls = document.body.className || "";
        cls = cls.replace(/\bfont-\w+\b/g, "");
        cls = cls.replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");

        /* Apply the new class */
        document.body.className = cls + " " + sizeClass;

        /* Persist */
        store.set(KEY, sizeClass);

        /* Update button states */
        window.updateFontButtons();
    }

    /* ============================================================
       Public API
       ============================================================ */

    /**
     * Steps up one font size. No-op if already at maximum.
     */
    window.increaseFontSize = function () {
        var idx = getCurrentIndex();
        if (idx < MAX_IDX) {
            applySize(idx + 1);
        }
    };

    /**
     * Steps down one font size. No-op if already at minimum.
     */
    window.decreaseFontSize = function () {
        var idx = getCurrentIndex();
        if (idx > MIN_IDX) {
            applySize(idx - 1);
        }
    };

    /**
     * Updates the increase/decrease buttons to reflect current state.
     * Adds .btn-disabled class and sets disabled attribute when at
     * the min or max size. Removes them otherwise.
     *
     * Called automatically after every size change and on page load.
     * Can also be called manually if buttons are dynamically created.
     */
    window.updateFontButtons = function () {
        var idx = getCurrentIndex();
        var btnInc = document.getElementById("font-increase");
        var btnDec = document.getElementById("font-decrease");

        if (btnInc) {
            if (idx >= MAX_IDX) {
                addClass(btnInc, "btn-disabled");
                btnInc.disabled = true;
            } else {
                removeClass(btnInc, "btn-disabled");
                btnInc.disabled = false;
            }
        }

        if (btnDec) {
            if (idx <= MIN_IDX) {
                addClass(btnDec, "btn-disabled");
                btnDec.disabled = true;
            } else {
                removeClass(btnDec, "btn-disabled");
                btnDec.disabled = false;
            }
        }
    };

    /* ============================================================
       Initialization — runs immediately on script load
       ============================================================ */

    /* Apply saved preference (or default) */
    var saved = store.get(KEY);
    if (saved) {
        /* Validate that the saved value is one of our known sizes */
        var valid = false;
        for (var j = 0; j < SIZES.length; j++) {
            if (SIZES[j] === saved) {
                valid = true;
                break;
            }
        }
        if (valid) {
            applySize(j);
        } else {
            /* Invalid saved value — reset to default */
            applySize(1);
        }
    } else {
        /* No saved value — apply default and set button states */
        window.updateFontButtons();
    }

})();

/* ================================================================
   Strong's Links Toggle — show/hide all lemma badges
   ================================================================ */

(function () {

    var store = window._kjvStore;
    var KEY   = "kjv_strongs_hidden";

    /* SVG eye icons — open and with clean diagonal strikethrough */
    var ICON_SHOW = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/></svg>';
    var ICON_HIDE = '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/><line x1="3" y1="3" x2="21" y2="21"/></svg>';

    function setStrongsVisible(visible) {
        var body = document.body;
        if (visible) {
            body.className = body.className.replace(/\s*\bstrongs-hidden\b/g, "");
        } else {
            if (body.className.indexOf("strongs-hidden") === -1) {
                body.className = body.className + " strongs-hidden";
            }
        }
        /* Legacy standalone icon button, if present on the page */
        var btn = document.getElementById("strongs-toggle");
        if (btn) {
            btn.innerHTML = visible ? ICON_SHOW : ICON_HIDE;
            btn.title     = visible ? "Hide Strong\u2019s links" : "Show Strong\u2019s links";
        }
        /* Dropdown row state text */
        var stateText = document.getElementById("strongs-state-text");
        if (stateText) {
            stateText.innerHTML = visible ? "Shown" : "Hidden";
        }
        store.set(KEY, visible ? "1" : "0");
    }

    window.toggleStrongs = function () {
        var hidden = document.body.className.indexOf("strongs-hidden") !== -1;
        setStrongsVisible(hidden);
    };

    /* Restore saved preference on page load */
    var saved = store.get(KEY);
    if (saved === "0") {
        setStrongsVisible(false);
    } else {
        /* Default visible — set icon and state text */
        var btn = document.getElementById("strongs-toggle");
        if (btn) {
            btn.innerHTML = ICON_SHOW;
            btn.title = "Hide Strong\u2019s links";
        }
        var stateText = document.getElementById("strongs-state-text");
        if (stateText) {
            stateText.innerHTML = "Shown";
        }
    }

})();

/* ================================================================
   Hamburger Settings Menu — toggle, click-outside-close, Escape
   ================================================================ */

(function () {

    var settingsDropdown = document.getElementById("settings-dropdown");
    var hamburgerBtn = document.getElementById("hamburger-btn");
    var menuOpen = false;

    window.toggleSettingsMenu = function () {
        if (!settingsDropdown) { return; }
        menuOpen = !menuOpen;
        settingsDropdown.style.display = menuOpen ? "block" : "none";
    };

    function closeMenu() {
        menuOpen = false;
        if (settingsDropdown) { settingsDropdown.style.display = "none"; }
    }

    /* Close on click outside */
    if (document.addEventListener) {
        document.addEventListener("click", function (e) {
            if (!menuOpen || !settingsDropdown) { return; }
            var target = e.target || e.srcElement;
            var inside = false;
            var node = target;
            while (node) {
                if (node === settingsDropdown || node === hamburgerBtn) {
                    inside = true;
                    break;
                }
                node = node.parentNode;
            }
            if (!inside) { closeMenu(); }
        }, false);
    }

    /* Close on Escape (stacks with any existing keydown handlers
       via addEventListener rather than overwriting onkeydown) */
    function handleEscape(e) {
        e = e || window.event;
        var key = e.keyCode || e.which;
        if (key === 27 && menuOpen) {
            closeMenu();
        }
    }

    if (document.addEventListener) {
        document.addEventListener("keydown", handleEscape, false);
    } else if (document.attachEvent) {
        document.attachEvent("onkeydown", handleEscape);
    }

    /* Kindle section of the dropdown only shows on localhost */
    var kindleSection = document.getElementById("settings-kindle-section");
    if (kindleSection) {
        var isLocalhostMenu = (window.location.hostname === "localhost"
                            || window.location.hostname === "127.0.0.1");
        if (!isLocalhostMenu) {
            kindleSection.style.display = "none";
        }
    }

})();


/* ================================================================
   Keyboard Shortcuts
   ================================================================
   Ctrl+]  ->  increaseFontSize()
   Ctrl+[  ->  decreaseFontSize()
   H       ->  toggleStrongs() (no modifier key)

   SAFETY: bails if focus is inside a text input/textarea/select/
   contenteditable, so typing in the note modal or search boxes
   is never interrupted.
   ================================================================ */

(function () {

    function isTypingContext() {
        var el = document.activeElement;
        if (!el) { return false; }
        var tag = el.tagName ? el.tagName.toUpperCase() : "";
        if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") { return true; }
        if (el.isContentEditable) { return true; }
        return false;
    }

    function handleShortcuts(e) {
        e = e || window.event;
        var key = e.keyCode || e.which;

        /* Ctrl+] (221) -> increase font */
        if (e.ctrlKey && key === 221) {
            if (e.preventDefault) { e.preventDefault(); } else { e.returnValue = false; }
            if (typeof window.increaseFontSize === "function") {
                window.increaseFontSize();
            }
            return;
        }

        /* Ctrl+[ (219) -> decrease font */
        if (e.ctrlKey && key === 219) {
            if (e.preventDefault) { e.preventDefault(); } else { e.returnValue = false; }
            if (typeof window.decreaseFontSize === "function") {
                window.decreaseFontSize();
            }
            return;
        }

        /* H (72), no modifiers -> toggle Strong's */
        if (key === 72 && !e.ctrlKey && !e.altKey && !e.metaKey && !e.shiftKey) {
            if (isTypingContext()) { return; }
            if (typeof window.toggleStrongs === "function") {
                window.toggleStrongs();
            }
        }
    }

    if (document.addEventListener) {
        document.addEventListener("keydown", handleShortcuts, false);
    } else if (document.attachEvent) {
        document.attachEvent("onkeydown", handleShortcuts);
    }

})();
