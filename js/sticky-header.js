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
   sticky-header.js — Snap-to-top header for Android 2.3 WebKit
   ================================================================
   Target: Kindle Fire D01E / Silk / Android 2.3 Gingerbread
   ES3 compatible — no let/const/arrow/forEach

   position: fixed is non-functional on this device (confirmed via
   isolated testing). This script uses position: absolute (set in
   style-kindle.css) plus a setInterval poll that updates
   header.style.top to match scrollTop, and injects a spacer div
   to push content below the header in normal document flow.

   BEHAVIOR: Due to Android 2.3 freezing JS during momentum/fling
   scrolling, the header will scroll away during an active scroll
   gesture and then "snap" back into the correct viewport position
   once scrolling stops (typically within ~100-300ms). This is the
   best achievable behavior without position: fixed support.

   On PC (style.css), .chapter-nav uses position: fixed which
   works correctly, so this script detects that via
   getComputedStyle and does nothing (no-op on PC).
   ================================================================ */

(function () {

    function getScrollTop() {
        return document.documentElement.scrollTop
            || document.body.scrollTop
            || 0;
    }

    var navs = document.getElementsByTagName("nav");
    var header = null;
    var i;

    for (i = 0; i < navs.length; i++) {
        if (navs[i].className
            && navs[i].className.indexOf("chapter-nav") !== -1) {
            header = navs[i];
            break;
        }
    }

    if (!header) { return; }

    /* If position: fixed actually works (PC), do nothing --
       the CSS already handles a true fixed header there. */
    var computedPosition = "";
    if (window.getComputedStyle) {
        computedPosition = window.getComputedStyle(header, null).position;
    } else if (header.currentStyle) {
        computedPosition = header.currentStyle.position;
    }

    if (computedPosition === "fixed") {
        return;
    }

    /* Force position: absolute (belt-and-suspenders in case CSS
       didn't apply as expected) */
    header.style.position = "absolute";
    header.style.top = "0";
    header.style.left = "0";
    header.style.width = "100%";
    header.style.zIndex = "1000";

    var headerHeight = header.offsetHeight || 90;

    /* Spacer div in normal flow pushes content below the header */
    var spacer = document.createElement("div");
    spacer.style.height = (headerHeight + 4) + "px";
    spacer.style.margin = "0";
    spacer.style.padding = "0";
    spacer.style.border = "none";
    spacer.style.visibility = "hidden";

    if (header.nextSibling) {
        header.parentNode.insertBefore(spacer, header.nextSibling);
    } else {
        header.parentNode.appendChild(spacer);
    }

    var lastScrollTop = -1;
    var lastHeight = headerHeight;

    function poll() {
        var scrollTop = getScrollTop();
        if (scrollTop === lastScrollTop) { return; }
        lastScrollTop = scrollTop;
        header.style.top = scrollTop + "px";
    }

    setInterval(poll, 100);

    /* Recheck header height every 2s (catches font size changes) */
    setInterval(function () {
        var currentHeight = header.offsetHeight;
        if (currentHeight !== lastHeight && currentHeight > 0) {
            lastHeight = currentHeight;
            headerHeight = currentHeight;
            spacer.style.height = (headerHeight + 4) + "px";
        }
    }, 2000);

    if (window.addEventListener) {
        window.addEventListener("orientationchange", function () {
            setTimeout(function () {
                headerHeight = header.offsetHeight || 90;
                lastHeight = headerHeight;
                spacer.style.height = (headerHeight + 4) + "px";
                lastScrollTop = -1;
                poll();
            }, 400);
        }, false);
    }

    poll();

})();

/* ── Anchor offset fix ─────────────────────────────────────────
   When navigating to #verse-N, the browser scrolls that element
   to the top of the viewport, but the header covers the top.
   This adjusts the scroll position after hash navigation.     */

(function () {
    function fixAnchorOffset() {
        var hash = window.location.hash;
        if (!hash) { return; }
        var el = document.getElementById(hash.replace('#', ''));
        if (!el) { return; }
        var headerEl = document.getElementsByTagName('nav')[0];
        var headerH = headerEl ? (headerEl.offsetHeight || 90) : 90;
        var elTop = el.getBoundingClientRect
            ? el.getBoundingClientRect().top + (document.documentElement.scrollTop || document.body.scrollTop)
            : el.offsetTop;
        var scrollTo = elTop - headerH - 8;
        if (document.documentElement.scrollTop !== undefined) {
            document.documentElement.scrollTop = scrollTo;
        } else {
            document.body.scrollTop = scrollTo;
        }
    }

    /* Run on load (handles direct navigation with hash) */
    setTimeout(fixAnchorOffset, 150);

    /* Run when hash changes (handles in-page anchor clicks) */
    if (window.addEventListener) {
        window.addEventListener('hashchange', function () {
            setTimeout(fixAnchorOffset, 50);
        }, false);
    }
})();
