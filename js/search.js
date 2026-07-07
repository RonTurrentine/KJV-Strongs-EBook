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
   search.js — KJV English word search with advanced scoping
   ================================================================
   ES3 compatible. Uses Bible SuperSearch API.
   PC-only feature — requires internet connection.
   ================================================================ */

(function () {

    var API_BASE = "https://api.biblesupersearch.com/api";
    var STATE_KEY = "kjv_search_state";

    /* ── State ─────────────────────────────────────────────────── */

    var currentQuery = "";
    var currentPage = 1;
    var lastPage = 1;
    var totalFiltered = 0;
    var filteredResults = null;   /* cached filtered array for client-side pagination */
    var lastServerData = null;    /* cached last server-paginated API response (Whole Bible mode) */
    var pageSize = 50;

    /* ── DOM refs ──────────────────────────────────────────────── */

    var inputEl  = document.getElementById("search-input");
    var statusEl = document.getElementById("search-status");
    var resultsEl = document.getElementById("search-results");
    var paginEl  = document.getElementById("search-pagination");
    var rppEl    = document.getElementById("rpp-select");
    var bookSelEl = document.getElementById("scope-book-select");

    /* ── 66-Book Mapping: API name -> folder ───────────────────── */

    var BOOK_MAP = {
        "Genesis":"01-Gen","Exodus":"02-Exod","Leviticus":"03-Lev",
        "Numbers":"04-Num","Deuteronomy":"05-Deut","Joshua":"06-Josh",
        "Judges":"07-Judg","Ruth":"08-Ruth","1 Samuel":"09-1Sam",
        "2 Samuel":"10-2Sam","1 Kings":"11-1Kgs","2 Kings":"12-2Kgs",
        "1 Chronicles":"13-1Chr","2 Chronicles":"14-2Chr","Ezra":"15-Ezra",
        "Nehemiah":"16-Neh","Esther":"17-Esth","Job":"18-Job",
        "Psalms":"19-Ps","Proverbs":"20-Prov","Ecclesiastes":"21-Eccl",
        "Song of Solomon":"22-Song","Isaiah":"23-Isa","Jeremiah":"24-Jer",
        "Lamentations":"25-Lam","Ezekiel":"26-Ezek","Daniel":"27-Dan",
        "Hosea":"28-Hos","Joel":"29-Joel","Amos":"30-Amos",
        "Obadiah":"31-Obad","Jonah":"32-Jonah","Micah":"33-Mic",
        "Nahum":"34-Nah","Habakkuk":"35-Hab","Zephaniah":"36-Zeph",
        "Haggai":"37-Hag","Zechariah":"38-Zech","Malachi":"39-Mal",
        "Matthew":"40-Matt","Mark":"41-Mark","Luke":"42-Luke",
        "John":"43-John","Acts":"44-Acts","Romans":"45-Rom",
        "1 Corinthians":"46-1Cor","2 Corinthians":"47-2Cor",
        "Galatians":"48-Gal","Ephesians":"49-Eph","Philippians":"50-Phil",
        "Colossians":"51-Col","1 Thessalonians":"52-1Thess",
        "2 Thessalonians":"53-2Thess","1 Timothy":"54-1Tim",
        "2 Timothy":"55-2Tim","Titus":"56-Titus","Philemon":"57-Phlm",
        "Hebrews":"58-Heb","James":"59-Jas","1 Peter":"60-1Pet",
        "2 Peter":"61-2Pet","1 John":"62-1John","2 John":"63-2John",
        "3 John":"64-3John","Jude":"65-Jude","Revelation":"66-Rev"
    };

    /* ── Book ID -> name (for dropdown) ────────────────────────── */

    var BOOK_LIST = [
        {id:1,name:"Genesis"},{id:2,name:"Exodus"},{id:3,name:"Leviticus"},
        {id:4,name:"Numbers"},{id:5,name:"Deuteronomy"},{id:6,name:"Joshua"},
        {id:7,name:"Judges"},{id:8,name:"Ruth"},{id:9,name:"1 Samuel"},
        {id:10,name:"2 Samuel"},{id:11,name:"1 Kings"},{id:12,name:"2 Kings"},
        {id:13,name:"1 Chronicles"},{id:14,name:"2 Chronicles"},{id:15,name:"Ezra"},
        {id:16,name:"Nehemiah"},{id:17,name:"Esther"},{id:18,name:"Job"},
        {id:19,name:"Psalms"},{id:20,name:"Proverbs"},{id:21,name:"Ecclesiastes"},
        {id:22,name:"Song of Solomon"},{id:23,name:"Isaiah"},{id:24,name:"Jeremiah"},
        {id:25,name:"Lamentations"},{id:26,name:"Ezekiel"},{id:27,name:"Daniel"},
        {id:28,name:"Hosea"},{id:29,name:"Joel"},{id:30,name:"Amos"},
        {id:31,name:"Obadiah"},{id:32,name:"Jonah"},{id:33,name:"Micah"},
        {id:34,name:"Nahum"},{id:35,name:"Habakkuk"},{id:36,name:"Zephaniah"},
        {id:37,name:"Haggai"},{id:38,name:"Zechariah"},{id:39,name:"Malachi"},
        {id:40,name:"Matthew"},{id:41,name:"Mark"},{id:42,name:"Luke"},
        {id:43,name:"John"},{id:44,name:"Acts"},{id:45,name:"Romans"},
        {id:46,name:"1 Corinthians"},{id:47,name:"2 Corinthians"},
        {id:48,name:"Galatians"},{id:49,name:"Ephesians"},{id:50,name:"Philippians"},
        {id:51,name:"Colossians"},{id:52,name:"1 Thessalonians"},
        {id:53,name:"2 Thessalonians"},{id:54,name:"1 Timothy"},
        {id:55,name:"2 Timothy"},{id:56,name:"Titus"},{id:57,name:"Philemon"},
        {id:58,name:"Hebrews"},{id:59,name:"James"},{id:60,name:"1 Peter"},
        {id:61,name:"2 Peter"},{id:62,name:"1 John"},{id:63,name:"2 John"},
        {id:64,name:"3 John"},{id:65,name:"Jude"},{id:66,name:"Revelation"}
    ];

    /* ── Category -> book_id arrays ────────────────────────────── */

    var CATEGORIES = {
        torah:         [1,2,3,4,5],
        historical:    [6,7,8,9,10,11,12,13,14,15,16,17],
        poetic:        [18,19,20,21,22],
        prophetic:     [23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39],
        gospels:       [40,41,42,43],
        acts:          [44],
        paul_church:   [45,46,47,48,49,50,51,52,53],
        paul_pastoral: [54,55,56,57],
        general:       [58,59,60,61,62,63,64,65],
        revelation:    [66]
    };

    /* ── Helpers ───────────────────────────────────────────────── */

    function escapeHtml(s) {
        return s.replace(/&/g,"&amp;").replace(/</g,"&lt;")
                .replace(/>/g,"&gt;").replace(/"/g,"&quot;");
    }

    function buildVerseLink(bookName, chapterVerse) {
        var folder = BOOK_MAP[bookName];
        if (!folder) return null;
        var p = chapterVerse.split(":");
        return "books/" + folder + "/" + p[0] + ".html#verse-" + (p[1]||"1");
    }

    function ajax(url, callback) {
        var xhr;
        try { xhr = new XMLHttpRequest(); }
        catch(e) { try { xhr = new ActiveXObject("Microsoft.XMLHTTP"); } catch(e2) { callback("No XHR",null); return; } }
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    try { callback(null, JSON.parse(xhr.responseText)); }
                    catch(e) { callback("Parse error", null); }
                } else { callback("HTTP " + xhr.status, null); }
            }
        };
        try { xhr.timeout = 30000; xhr.ontimeout = function() { callback("Timeout", null); }; } catch(e) {}
        xhr.send(null);
    }

    /* ============================================================
       Scope Logic
       ============================================================ */

    /* Returns { mode, bookIds (array or null), fetchAll (bool) }
       New simplified model (no radios):
       - If a specific book is selected in the dropdown, that wins.
       - Otherwise, union of all checked category checkboxes.
       - If nothing is selected/checked, scope is Whole Bible.       */
    function getActiveScope() {
        var bookVal = bookSelEl ? bookSelEl.value : "";
        if (bookVal) {
            return { mode: "book", bookIds: [parseInt(bookVal, 10)], fetchAll: true };
        }

        var checks = document.getElementsByTagName("input");
        var ids = [];
        var seen = {};
        for (var c = 0; c < checks.length; c++) {
            if (checks[c].type === "checkbox" && checks[c].className.indexOf("cat-check") !== -1 && checks[c].checked) {
                var cat = checks[c].value;
                if (CATEGORIES[cat]) {
                    var catIds = CATEGORIES[cat];
                    for (var d = 0; d < catIds.length; d++) {
                        if (!seen[catIds[d]]) {
                            ids.push(catIds[d]);
                            seen[catIds[d]] = true;
                        }
                    }
                }
            }
        }

        if (ids.length === 0) {
            return { mode: "whole", bookIds: null, fetchAll: false };
        }
        return { mode: "category", bookIds: ids, fetchAll: true };
    }

    function filterResults(results, bookIds) {
        if (!bookIds) return results;
        var map = {};
        for (var i = 0; i < bookIds.length; i++) map[bookIds[i]] = true;
        var out = [];
        for (var j = 0; j < results.length; j++) {
            if (map[results[j].book_id]) out.push(results[j]);
        }
        return out;
    }

    /* ============================================================
       Session State Persistence
       ============================================================
       Saves search state to sessionStorage so results survive
       navigating to a verse and coming back. Cleared when the
       tab/window closes (sessionStorage, not localStorage).
       ============================================================ */

    function getCheckedCategories() {
        var checks = document.getElementsByTagName("input");
        var cats = [];
        for (var i = 0; i < checks.length; i++) {
            if (checks[i].className.indexOf("cat-check") !== -1 && checks[i].checked) {
                cats.push(checks[i].value);
            }
        }
        return cats;
    }

    function saveSessionState() {
        try {
            var state = {
                query: currentQuery,
                currentPage: currentPage,
                lastPage: lastPage,
                pageSize: pageSize,
                bookSelectValue: bookSelEl ? bookSelEl.value : "",
                checkedCategories: getCheckedCategories(),
                rppValue: rppEl ? rppEl.value : "50",
                filteredResults: filteredResults,
                lastServerData: lastServerData
            };
            window.sessionStorage.setItem(STATE_KEY, JSON.stringify(state));
        } catch (e) { /* sessionStorage unavailable or quota exceeded - ignore */ }
    }

    function clearSessionState() {
        try { window.sessionStorage.removeItem(STATE_KEY); } catch (e) { }
    }

    function loadSessionState() {
        try {
            var raw = window.sessionStorage.getItem(STATE_KEY);
            if (!raw) { return null; }
            return JSON.parse(raw);
        } catch (e) { return null; }
    }

    /* Reapply saved UI selections (book dropdown, category checkboxes) */
    function restoreScopeUI(state) {
        if (bookSelEl) {
            bookSelEl.value = state.bookSelectValue || "";
        }

        var checks = document.getElementsByTagName("input");
        var savedCats = state.checkedCategories || [];
        for (var c = 0; c < checks.length; c++) {
            if (checks[c].className.indexOf("cat-check") !== -1) {
                var match = false;
                for (var k = 0; k < savedCats.length; k++) {
                    if (savedCats[k] === checks[c].value) { match = true; break; }
                }
                checks[c].checked = match;
            }
        }

        /* Re-sync OT/NT master checkboxes based on whether all their
           children ended up checked */
        var otMaster = document.getElementById("cat-ot-master");
        var ntMaster = document.getElementById("cat-nt-master");
        if (otMaster) {
            var otAll = true;
            for (var o = 0; o < OT_CATS.length; o++) {
                if (savedCats.indexOf ? savedCats.indexOf(OT_CATS[o]) === -1 : true) { otAll = false; }
            }
            otMaster.checked = otAll && savedCats.length > 0;
        }
        if (ntMaster) {
            var ntAll = true;
            for (var n = 0; n < NT_CATS.length; n++) {
                if (savedCats.indexOf ? savedCats.indexOf(NT_CATS[n]) === -1 : true) { ntAll = false; }
            }
            ntMaster.checked = ntAll && savedCats.length > 0;
        }

        if (rppEl && state.rppValue) {
            rppEl.value = state.rppValue;
        }

        /* Apply correct disabled/grayed state */
        window.setScopeMode();
    }

    /* Restore search input + results without re-fetching from API */
    function restoreResults(state) {
        currentQuery = state.query || "";
        currentPage = state.currentPage || 1;
        lastPage = state.lastPage || 1;
        pageSize = state.pageSize || 50;

        if (inputEl) { inputEl.value = currentQuery; }

        if (state.filteredResults) {
            filteredResults = state.filteredResults;
            renderClientPage();
        } else if (state.lastServerData) {
            renderServerResults(state.lastServerData);
        }
    }

    /* ============================================================
       Mutual Exclusivity
       ============================================================ */

    function setDisabledState(el, disabled) {
        if (!el) { return; }
        if (disabled) {
            el.disabled = true;
            el.style.opacity = "0.4";
            el.style.cursor = "not-allowed";
        } else {
            el.disabled = false;
            el.style.opacity = "";
            el.style.cursor = "";
        }
    }

    function getAllCategoryChecks() {
        var checks = document.getElementsByTagName("input");
        var out = [];
        for (var i = 0; i < checks.length; i++) {
            if (checks[i].className.indexOf("cat-check") !== -1) { out.push(checks[i]); }
        }
        return out;
    }

    /* If a book is selected, gray out all category checkboxes (and vice versa).
       Selecting a book clears any checked categories; checking a category
       clears the book dropdown. The two modes are mutually exclusive, but
       there are no more Whole/OT/NT radios to get "stuck" on. */
    window.setScopeMode = function() {
        var hasBook = bookSelEl && bookSelEl.value;
        var catChecks = getAllCategoryChecks();
        var hasCategory = false;
        for (var i = 0; i < catChecks.length; i++) {
            if (catChecks[i].checked) { hasCategory = true; break; }
        }

        if (hasBook) {
            for (var a = 0; a < catChecks.length; a++) { setDisabledState(catChecks[a], true); }
            setDisabledState(bookSelEl, false);
        } else if (hasCategory) {
            setDisabledState(bookSelEl, true);
            for (var b = 0; b < catChecks.length; b++) { setDisabledState(catChecks[b], false); }
        } else {
            /* Nothing selected — everything enabled (Whole Bible) */
            setDisabledState(bookSelEl, false);
            for (var c = 0; c < catChecks.length; c++) { setDisabledState(catChecks[c], false); }
        }
    };

    window.onBookSelected = function() {
        if (bookSelEl && bookSelEl.value) {
            /* Selecting a book clears any checked categories */
            var catChecks = getAllCategoryChecks();
            for (var i = 0; i < catChecks.length; i++) { catChecks[i].checked = false; }
            var otMaster = document.getElementById("cat-ot-master");
            var ntMaster = document.getElementById("cat-nt-master");
            if (otMaster) { otMaster.checked = false; }
            if (ntMaster) { ntMaster.checked = false; }
        }
        window.setScopeMode();
    };

    window.onCategoryChecked = function() {
        if (bookSelEl && bookSelEl.value) {
            /* Checking a category clears the book dropdown */
            bookSelEl.value = "";
        }
        window.setScopeMode();
    };

    /* OT / NT "master" checkboxes — checking one auto-checks all
       categories beneath it; unchecking it auto-unchecks them. */
    var OT_CATS = ["torah", "historical", "poetic", "prophetic"];
    var NT_CATS = ["gospels", "acts", "paul_church", "paul_pastoral", "general", "revelation"];

    function setCategoryGroup(catNames, checked) {
        var catChecks = getAllCategoryChecks();
        for (var i = 0; i < catChecks.length; i++) {
            for (var j = 0; j < catNames.length; j++) {
                if (catChecks[i].value === catNames[j]) { catChecks[i].checked = checked; }
            }
        }
    }

    window.onMasterChecked = function(which) {
        if (bookSelEl) { bookSelEl.value = ""; }
        if (which === "ot") {
            var otMaster = document.getElementById("cat-ot-master");
            setCategoryGroup(OT_CATS, otMaster ? otMaster.checked : false);
        } else if (which === "nt") {
            var ntMaster = document.getElementById("cat-nt-master");
            setCategoryGroup(NT_CATS, ntMaster ? ntMaster.checked : false);
        }
        window.setScopeMode();
    };

    window.onRppChanged = function() {
        var val = rppEl ? rppEl.value : "50";
        pageSize = (val === "all") ? 999999 : parseInt(val, 10);
        /* Re-run if we have cached results */
        if (filteredResults && filteredResults.length > 0) {
            currentPage = 1;
            renderClientPage();
            saveSessionState();
        }
    };

    /* ============================================================
       Search Execution
       ============================================================ */

    function performSearch(query, page) {
        if (!query) return;

        currentQuery = query;
        var scope = getActiveScope();
        var rppVal = rppEl ? rppEl.value : "50";
        pageSize = (rppVal === "all") ? 999999 : parseInt(rppVal, 10);

        clearSessionState();
        filteredResults = null;
        lastServerData = null;

        statusEl.innerHTML = '<p class="search-loading">Searching for &ldquo;'
            + escapeHtml(query) + '&rdquo;'
            + (scope.fetchAll ? '... this may take a moment for common words' : '')
            + '</p>';
        resultsEl.innerHTML = "";
        paginEl.innerHTML = "";

        var url = API_BASE + "?bible=kjv&search=" + encodeURIComponent(query);

        if (scope.fetchAll || rppVal === "all") {
            /* Fetch everything, filter client-side */
            url += "&page_all=true";

            ajax(url, function(err, data) {
                if (err) { showError(err); return; }
                if (!data || !data.results) { showError("Unexpected response"); return; }

                var allResults = data.results || [];
                filteredResults = filterResults(allResults, scope.bookIds);
                totalFiltered = filteredResults.length;
                currentPage = 1;
                renderClientPage();
                saveSessionState();
            });
        } else {
            /* Server-side pagination (Whole Bible, not "All") */
            currentPage = page || 1;
            url += "&page_limit=" + pageSize + "&page=" + currentPage;

            ajax(url, function(err, data) {
                if (err) { showError(err); return; }
                if (!data || !data.results) { showError("Unexpected response"); return; }
                lastServerData = data;
                renderServerResults(data);
                saveSessionState();
            });
        }
    }

    /* ── Render server-paginated results (Whole Bible mode) ──── */

    function renderServerResults(data) {
        var paging = data.paging || {};
        var total = paging.total || 0;
        lastPage = paging.last_page || 1;
        currentPage = paging.current_page || 1;

        if (total === 0) { showEmpty(); return; }

        statusEl.innerHTML = '<p class="search-results-header">'
            + total + ' result' + (total !== 1 ? 's' : '')
            + ' for &ldquo;' + escapeHtml(currentQuery) + '&rdquo;'
            + (lastPage > 1 ? ' (page ' + currentPage + ' of ' + lastPage + ')' : '')
            + '</p>';

        buildResultCards(data.results || []);
        buildServerPagination();
    }

    /* ── Render client-paginated results (filtered modes) ─────── */

    function renderClientPage() {
        if (!filteredResults) return;

        totalFiltered = filteredResults.length;
        if (totalFiltered === 0) { showEmpty(); return; }

        var effectiveSize = (pageSize >= 999999) ? totalFiltered : pageSize;
        lastPage = Math.ceil(totalFiltered / effectiveSize);
        if (currentPage > lastPage) currentPage = lastPage;
        if (currentPage < 1) currentPage = 1;

        var start = (currentPage - 1) * effectiveSize;
        var end = Math.min(start + effectiveSize, totalFiltered);
        var pageResults = filteredResults.slice(start, end);

        var notice = "";
        if (totalFiltered > 500) {
            notice = ' &mdash; consider narrowing your search scope';
        }

        statusEl.innerHTML = '<p class="search-results-header">'
            + totalFiltered + ' result' + (totalFiltered !== 1 ? 's' : '')
            + ' for &ldquo;' + escapeHtml(currentQuery) + '&rdquo;'
            + (lastPage > 1 ? ' (page ' + currentPage + ' of ' + lastPage + ')' : '')
            + notice + '</p>';

        buildResultCards(pageResults);
        buildClientPagination();
    }

    /* ── Build result cards (shared) ──────────────────────────── */

    function buildResultCards(results) {
        var html = [];
        for (var i = 0; i < results.length; i++) {
            var r = results[i];
            var bookName = r.book_name || "";
            var cv = r.chapter_verse || "";
            var verseText = "";
            try {
                var kjv = r.verses.kjv;
                for (var ch in kjv) {
                    if (!kjv.hasOwnProperty(ch)) continue;
                    for (var vs in kjv[ch]) {
                        if (!kjv[ch].hasOwnProperty(vs)) continue;
                        verseText = kjv[ch][vs].text || "";
                    }
                }
            } catch(e) { verseText = "(text unavailable)"; }

            var link = buildVerseLink(bookName, cv);
            var ref = bookName + " " + cv;

            html.push('<div class="search-result-card">');
            if (link) {
                html.push('<a href="' + link + '" class="search-result-ref">' + escapeHtml(ref) + '</a>');
            } else {
                html.push('<span class="search-result-ref">' + escapeHtml(ref) + '</span>');
            }
            html.push('<p class="search-result-text">' + escapeHtml(verseText) + '</p>');
            html.push('</div>');
        }
        resultsEl.innerHTML = html.join("");
    }

    /* ── Pagination builders ──────────────────────────────────── */

    function buildServerPagination() {
        if (lastPage <= 1) { paginEl.innerHTML = ""; return; }
        paginEl.innerHTML = '<div class="search-pagination">'
            + '<button class="btn conc-nav-btn" onclick="searchGo(1)"' + (currentPage<=1?' disabled':'') + '>BEG</button>'
            + '<button class="btn conc-nav-btn" onclick="searchPage(-1)"' + (currentPage<=1?' disabled':'') + '>&#9664; Prev</button>'
            + '<span class="conc-pg-label">Page ' + currentPage + ' of ' + lastPage + '</span>'
            + '<button class="btn conc-nav-btn" onclick="searchPage(1)"' + (currentPage>=lastPage?' disabled':'') + '>Next &#9654;</button>'
            + '<button class="btn conc-nav-btn" onclick="searchGo(' + lastPage + ')"' + (currentPage>=lastPage?' disabled':'') + '>END</button>'
            + '</div>';
    }

    function buildClientPagination() {
        if (lastPage <= 1) { paginEl.innerHTML = ""; return; }
        paginEl.innerHTML = '<div class="search-pagination">'
            + '<button class="btn conc-nav-btn" onclick="searchGoClient(1)"' + (currentPage<=1?' disabled':'') + '>BEG</button>'
            + '<button class="btn conc-nav-btn" onclick="searchPageClient(-1)"' + (currentPage<=1?' disabled':'') + '>&#9664; Prev</button>'
            + '<span class="conc-pg-label">Page ' + currentPage + ' of ' + lastPage + '</span>'
            + '<button class="btn conc-nav-btn" onclick="searchPageClient(1)"' + (currentPage>=lastPage?' disabled':'') + '>Next &#9654;</button>'
            + '<button class="btn conc-nav-btn" onclick="searchGoClient(' + lastPage + ')"' + (currentPage>=lastPage?' disabled':'') + '>END</button>'
            + '</div>';
    }

    /* ── Error / empty states ─────────────────────────────────── */

    function showError(err) {
        statusEl.innerHTML = "";
        var errStr = String(err);
        /* "Timeout", "No XHR", and "HTTP 0" are the typical signatures of
           a genuine connectivity failure (the request never reached the
           service at all) -- as opposed to "Parse error" or "Unexpected
           response", which mean the service responded but something else
           went wrong. Worth different wording since only the first case
           is actually about internet connectivity. */
        var isConnectivityFailure = (errStr === "Timeout" || errStr === "No XHR" || errStr === "HTTP 0");

        var message = isConnectivityFailure
            ? "The Bible SuperSearch service is unavailable at the moment. Please check your internet connection and try again."
            : "Something went wrong with your search. Please try again.";

        resultsEl.innerHTML = '<div class="search-error">'
            + '<p>' + message + '</p>'
            + '<p class="search-error-detail">' + escapeHtml(errStr) + '</p></div>';
        paginEl.innerHTML = "";
    }

    function showEmpty() {
        statusEl.innerHTML = "";
        resultsEl.innerHTML = '<div class="search-empty">'
            + '<p>No results found for &ldquo;' + escapeHtml(currentQuery) + '&rdquo;</p></div>';
        paginEl.innerHTML = "";
    }

    /* ============================================================
       Public Functions
       ============================================================ */

    window.doSearch = function() {
        var q = inputEl ? inputEl.value.replace(/^\s+|\s+$/g, "") : "";
        if (!q) return;
        performSearch(q, 1);
    };

    /* Server-side pagination (Whole Bible) */
    window.searchPage = function(delta) {
        var p = currentPage + delta;
        if (p < 1 || p > lastPage) return;
        performSearch(currentQuery, p);
    };
    window.searchGo = function(page) {
        if (page < 1 || page > lastPage) return;
        performSearch(currentQuery, page);
    };

    /* Client-side pagination (filtered) */
    window.searchPageClient = function(delta) {
        currentPage += delta;
        if (currentPage < 1) currentPage = 1;
        if (currentPage > lastPage) currentPage = lastPage;
        renderClientPage();
        saveSessionState();
        if (statusEl.scrollIntoView) statusEl.scrollIntoView();
    };
    window.searchGoClient = function(page) {
        currentPage = page;
        if (currentPage < 1) currentPage = 1;
        if (currentPage > lastPage) currentPage = lastPage;
        renderClientPage();
        saveSessionState();
        if (statusEl.scrollIntoView) statusEl.scrollIntoView();
    };

    /* ── Enter key ─────────────────────────────────────────────── */

    if (inputEl) {
        inputEl.onkeydown = function(e) {
            e = e || window.event;
            if ((e.keyCode || e.which) === 13) window.doSearch();
        };
    }

    /* ============================================================
       Initialization
       ============================================================ */

    /* Populate book dropdown */
    if (bookSelEl) {
        for (var i = 0; i < BOOK_LIST.length; i++) {
            var opt = document.createElement("option");
            opt.value = String(BOOK_LIST[i].id);
            opt.appendChild(document.createTextNode(BOOK_LIST[i].name));
            bookSelEl.appendChild(opt);
        }
    }

    /* Set initial scope state — restore from session if available */
    var savedState = loadSessionState();
    if (savedState && savedState.query) {
        restoreScopeUI(savedState);
        restoreResults(savedState);
    } else {
        window.setScopeMode("whole");
    }

    /* Focus input */
    if (inputEl) { try { inputEl.focus(); } catch(e) {} }

})();
