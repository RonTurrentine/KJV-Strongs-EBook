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
