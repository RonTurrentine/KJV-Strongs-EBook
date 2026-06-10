/* ================================================================
   sticky-header.js — Scroll-based fixed header for KJV Bible
   ================================================================
   Target: Android 2.3 WebKit (Kindle Fire D01E)
   ES3 compatible — no let/const/arrow functions

   Replaces CSS `position: sticky` (not supported) with a
   scroll-event-driven `position: fixed` toggle.

   How it works:
     1. On load, measures the header's natural position
     2. Creates an invisible placeholder div (same height as header)
     3. On scroll, when the page scrolls past the header:
        - Adds .is-fixed class to the header (position: fixed)
        - Shows the placeholder (prevents content from jumping up)
     4. When scrolled back to top:
        - Removes .is-fixed class
        - Hides the placeholder

   Requires: .chapter-nav element in the page
   CSS class .is-fixed must be defined in style.css (it is)

   Scroll handler is throttled to ~60fps using setTimeout to
   avoid performance issues on the Kindle's limited CPU.
   ================================================================ */

(function () {

    /* ── Cross-browser helpers ─────────────────────────────────── */

    function getScrollTop() {
        return document.documentElement.scrollTop || document.body.scrollTop || 0;
    }

    function addEvent(el, type, fn) {
        if (el.addEventListener) {
            el.addEventListener(type, fn, false);
        } else if (el.attachEvent) {
            el.attachEvent("on" + type, fn);
        }
    }

    /* ── Find the header element ───────────────────────────────── */
    /* Look for .chapter-nav by tag — getElementById would require
       adding an id to the template. Walking by class name works
       since there's only one .chapter-nav per page.               */

    var headers = document.getElementsByTagName("nav");
    var header = null;
    var i;

    for (i = 0; i < headers.length; i++) {
        if (headers[i].className && headers[i].className.indexOf("chapter-nav") !== -1) {
            header = headers[i];
            break;
        }
    }

    if (!header) { return; } /* Not a chapter page — nothing to do */

    /* ── Measure the header's natural position and size ─────────── */

    var headerTop = header.offsetTop;
    var headerHeight = header.offsetHeight;

    /* ── Create the placeholder ─────────────────────────────────── */
    /* When the header goes fixed, it's removed from document flow.
       The placeholder fills the gap so content doesn't jump up.    */

    var placeholder = document.createElement("div");
    placeholder.className = "header-placeholder";
    placeholder.style.display = "none";
    placeholder.style.height = headerHeight + "px";
    placeholder.style.visibility = "hidden";
    header.parentNode.insertBefore(placeholder, header.nextSibling);

    /* ── State tracking ────────────────────────────────────────── */

    var isFixed = false;
    var ticking = false;

    /* ── The actual scroll handler ──────────────────────────────── */

    function handleScroll() {
        var scrollTop = getScrollTop();

        if (scrollTop >= headerTop && !isFixed) {
            /* Pin the header */
            header.className = header.className + " is-fixed";
            placeholder.style.display = "block";
            isFixed = true;
        }
        else if (scrollTop < headerTop && isFixed) {
            /* Unpin the header */
            header.className = header.className.replace(/\s*\bis-fixed\b/g, "");
            placeholder.style.display = "none";
            isFixed = false;
        }

        ticking = false;
    }

    /* ── Throttled scroll listener ─────────────────────────────── */
    /* Uses setTimeout since requestAnimationFrame isn't available
       on Android 2.3. 16ms ≈ 60fps cap.                          */

    addEvent(window, "scroll", function () {
        if (!ticking) {
            ticking = true;
            setTimeout(handleScroll, 16);
        }
    });

    /* ── Recalculate on orientation change ─────────────────────── */
    /* Kindle Fire can be rotated — header height may change        */

    addEvent(window, "orientationchange", function () {
        setTimeout(function () {
            /* Temporarily unfix to measure natural position */
            if (isFixed) {
                header.className = header.className.replace(/\s*\bis-fixed\b/g, "");
                placeholder.style.display = "none";
                isFixed = false;
            }
            headerTop = header.offsetTop;
            headerHeight = header.offsetHeight;
            placeholder.style.height = headerHeight + "px";
            /* Re-evaluate current scroll position */
            handleScroll();
        }, 300);
    });

    /* ── Recalculate on resize (covers font size changes) ──────── */
    /* When cycleFontSize() changes the body class, the header
       height may change. This catches that.                        */

    addEvent(window, "resize", function () {
        if (!isFixed) {
            headerTop = header.offsetTop;
        }
        headerHeight = header.offsetHeight;
        placeholder.style.height = headerHeight + "px";
    });

    /* ── Initial check (page may load already scrolled) ─────────── */

    handleScroll();

})();
