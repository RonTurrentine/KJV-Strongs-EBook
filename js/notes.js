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
   notes.js — Personal study notes for KJV Strong's Bible
   ================================================================
   Target: ES3 compatible for Android 2.3 WebKit readability,
           full editing only works on PC via localhost:8080

   On localhost (PC study mode):
     - Pencil buttons are visible and active on every verse
     - Clicking opens a modal to add/edit/delete notes
     - Notes are saved server-side and baked into the HTML

   On file:// (Kindle / offline):
     - Pencil buttons are hidden
     - Baked notes are visible (they're static HTML)
     - No editing capability

   ================================================================ */

(function () {

    /* -- Detect environment -------------------------------------  */

    var loc = window.location || {};
    var isLocalhost = (loc.hostname === "localhost"
        || loc.hostname === "127.0.0.1");
    var isFileUrl = (loc.protocol === "file:");

    /* Phone mode: browser on a phone/tablet connecting to the PC
       server over WiFi. The hostname is the PC's LAN IP, not localhost.
       In phone mode, notes go to localStorage and sync with the PC
       when connected. Pencil buttons are visible just like localhost.

       Note: this used to also require loc.port === "8080", but that
       broke once the LAN TCP proxy (start-study.ps1, port = base+1,
       e.g. 8081) became the real path phones connect through. Since
       this app is only ever served on localhost (the PC itself) or a
       LAN address (anything reaching it over WiFi), the port number
       doesn't actually matter for this decision — any non-localhost,
       non-file HTTP(S) origin is phone mode. */
    var isPhoneMode = (!isLocalhost && !isFileUrl
        && (loc.protocol === "http:" || loc.protocol === "https:"));

    /* The URL of the PC server — used for sync calls from the phone.
       On localhost (PC browser), this is just "/". On phone mode,
       it's the full http://[pc-ip]:8080/ origin we're already on. */
    var pcServerOrigin = (isLocalhost || isPhoneMode)
        ? (loc.protocol + "//" + loc.host)
        : null;

    /* Note-taking is available on PC (localhost) or phone (phone mode) */
    var canTakeNotes = (isLocalhost || isPhoneMode);

    /* Search requires a live connection to the PC server (which in turn
       proxies to the live Bible SuperSearch API) -- it can never work at
       all from a Kindle file:// origin, and on a phone it only works
       when the phone can actually currently reach the PC over WiFi.
       Hides the "Search" nav link (only present on index.html) in those
       cases; a real-time friendly error (shown by search.js if an actual
       search request fails) covers the PC case instead of a permanent
       static warning nobody asked to see every time they open the menu. */
    function setSearchVisibility(visible) {
        var btn = document.getElementById("search-nav-btn");
        if (btn) { btn.style.display = visible ? "" : "none"; }
    }

    if (isFileUrl) {
        /* Kindle: never has network access of any kind, hide immediately. */
        setSearchVisibility(false);
    }

    /* -- Extract page context from URL --------------------------  */
    /* Parses the current page path to determine book and chapter.
       Example: /books/01-Gen/1.html -> osisBook="Gen", chapter=1  */

    var osisBook = "";
    var chapterNum = 0;
    var pagePath = loc.pathname || "";

    var bookMatch = pagePath.match(/\/books\/\d+-([^\/]+)\//);
    if (bookMatch) {
        osisBook = bookMatch[1];
    }

    var chMatch = pagePath.match(/\/(\d+)\.html/);
    if (chMatch) {
        chapterNum = parseInt(chMatch[1], 10);
    }

    var isChapterPage = (osisBook !== "" && chapterNum > 0);
    var isHomePage = (pagePath === "/" || /\/index\.html$/.test(pagePath));
    var isNotesManagerPage = /\/notes-manager\.html$/.test(pagePath);

    /* -- XMLHttpRequest helper (ES3) ----------------------------  */

    function ajax(method, url, body, callback) {
        var xhr;
        try { xhr = new XMLHttpRequest(); }
        catch (e) {
            try { xhr = new ActiveXObject("Microsoft.XMLHTTP"); }
            catch (e2) { return; }
        }
        xhr.open(method, url, true);
        if (body !== null) {
            xhr.setRequestHeader("Content-Type", "application/json");
        }
        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                var data = null;
                try { data = JSON.parse(xhr.responseText); }
                catch (e) { /* not JSON */ }
                callback(xhr.status, data);
            }
        };
        xhr.send(body !== null ? body : null);
    }

    /* ============================================================
       Phone-Side Note Storage (localStorage)
       ============================================================
       On phone mode (or when PC is unreachable), notes and highlights
       are stored in the browser's localStorage so they persist between
       sessions without any server. Keys:
         "kjv-phone-notes"      → { "Gen.1.1": { text, created, updated }, ... }
         "kjv-phone-highlights" → { "Gen.1.1": "yellow", ... }
         "kjv-phone-tombstones" → { "Gen.1.1": { deleted: true, deletedAt: ... } }
         "kjv-last-sync"        → ISO timestamp of last successful sync with PC
       ============================================================ */

    var LS_NOTES      = "kjv-phone-notes";
    var LS_HIGHLIGHTS = "kjv-phone-highlights";
    var LS_TOMBSTONES = "kjv-phone-tombstones";
    var LS_LAST_SYNC  = "kjv-last-sync";
    /* Snapshot of highlights as of the last successful sync. Highlights
       are stored as plain color strings (no per-item timestamp like
       notes have), so this snapshot is how we tell "already synced"
       highlights apart from new/changed ones for the pending-count. */
    var LS_SYNCED_HIGHLIGHTS = "kjv-synced-highlights-snapshot";

    function lsGet(key) {
        try {
            var v = localStorage.getItem(key);
            return v ? JSON.parse(v) : {};
        } catch (e) { return {}; }
    }

    function lsSet(key, val) {
        try { localStorage.setItem(key, JSON.stringify(val)); return true; }
        catch (e) { return false; }
    }

    /* Phone note CRUD — all go to localStorage */

    function phoneGetNotes() { return lsGet(LS_NOTES); }

    function phoneSaveNote(ref, text, tags) {
        var notes = phoneGetNotes();
        var now = new Date().toISOString();
        notes[ref] = {
            text:    text,
            tags:    tags || [],
            created: (notes[ref] && notes[ref].created) ? notes[ref].created : now,
            updated: now
        };
        /* Remove any tombstone for this ref if re-creating */
        var tombs = lsGet(LS_TOMBSTONES);
        if (tombs[ref]) { delete tombs[ref]; lsSet(LS_TOMBSTONES, tombs); }
        lsSet(LS_NOTES, notes);
    }

    function phoneDeleteNote(ref) {
        var notes = phoneGetNotes();
        var now = new Date().toISOString();
        if (notes[ref]) { delete notes[ref]; lsSet(LS_NOTES, notes); }
        /* Record tombstone so sync knows this was a deliberate deletion */
        var tombs = lsGet(LS_TOMBSTONES);
        tombs[ref] = { deleted: true, deletedAt: now };
        lsSet(LS_TOMBSTONES, tombs);
    }

    function phoneGetHighlights() { return lsGet(LS_HIGHLIGHTS); }

    function phoneSaveHighlight(ref, color) {
        var highs = phoneGetHighlights();
        if (color) {
            highs[ref] = color;
        } else {
            delete highs[ref];
            /* tombstone for highlights uses "hl:" prefix */
            var tombs = lsGet(LS_TOMBSTONES);
            tombs["hl:" + ref] = { deleted: true, deletedAt: new Date().toISOString() };
            lsSet(LS_TOMBSTONES, tombs);
        }
        lsSet(LS_HIGHLIGHTS, highs);
    }

    /* Toast notification -------------------------------------  */

    var toastEl = null;
    var toastTimer = null;

    function createToast() {
        if (toastEl) { return; }
        toastEl = document.createElement("div");
        toastEl.className = "toast";
        toastEl.id = "toast";
        document.body.appendChild(toastEl);
    }

    function showToast(message, type) {
        createToast();
        toastEl.innerHTML = "";
        toastEl.appendChild(document.createTextNode(message));
        toastEl.className = "toast is-visible"
            + (type === "success" ? " toast-success" : "")
            + (type === "error" ? " toast-error" : "");
        if (toastTimer) { clearTimeout(toastTimer); }
        toastTimer = setTimeout(function () {
            toastEl.className = "toast";
        }, 2500);
    }

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

    /* -- Get verse text from DOM --------------------------------  */

    function getVerseText(verseNum) {
        var el = document.getElementById("verse-" + verseNum);
        if (!el) { return ""; }
        /* Get text content, stripping Strong's number badges */
        var text = el.innerText || el.textContent || "";
        /* Remove leading verse number */
        text = text.replace(/^\s*\d+\s*/, "");
        /* Trim and collapse whitespace */
        text = text.replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "");
        return text;
    }

    /* ============================================================
       Modal
       ============================================================ */

    var modal = null;
    var modalTitle = null;
    var modalVerse = null;
    var modalTextarea = null;
    var modalDeleteBtn = null;
    var currentRef = "";

    /* Highlight state */
    var highlights = {};          /* ref -> color (loaded from server) */
    var selectedColor = null;     /* currently selected in picker */
    var originalColor = null;     /* color when modal opened (for cancel revert) */
    var pickerRow = null;         /* the color picker DOM element */
    var modalTagsInput = null;    /* tags text input */
    var tagsDatalist = null;      /* <datalist> of known tags, for autocomplete */
    var lastKnownTagsMap = null;  /* lowercase -> canonical casing, refreshed each time the modal opens */
    var HL_COLORS = ["yellow", "green", "red", "blue"];
    var HL_CLASSES = { yellow: "hl-yellow", green: "hl-green", red: "hl-red", blue: "hl-blue" };

    /* Guarantees a real array, regardless of what was actually
       received: a proper array, a bare string (PowerShell's
       ConvertTo-Json infamously collapses a single-element array into
       a scalar string), or missing/null entirely. */
    function normalizeTagsArray(rawTags) {
        if (!rawTags) { return []; }
        if (Object.prototype.toString.call(rawTags) === "[object Array]") { return rawTags; }
        if (typeof rawTags === "string") { return [rawTags]; }
        return [];
    }

    /* Normalizes .tags on every note in a notes object received from
       the server, in place -- call this immediately after any GET
       /api/notes response, before the data is used anywhere else. */
    function normalizeNotesTagsInPlace(notesObj) {
        var ref;
        for (ref in notesObj) {
            if (!notesObj.hasOwnProperty(ref)) { continue; }
            if (notesObj[ref]) { notesObj[ref].tags = normalizeTagsArray(notesObj[ref].tags); }
        }
        return notesObj;
    }

    /* Normalizes a tag into a comparison key: collapses ALL whitespace
       variants (including non-breaking spaces -- \s in JS regex
       matches these too) into a single regular space, trims, and
       lowercases. Without this, two tags that look completely
       identical on screen ("New Creature" typed normally vs. via
       mobile-keyboard autocomplete, which sometimes inserts a
       non-breaking space instead of a regular one) would silently be
       treated as different tags everywhere -- the tag cloud, the
       autocomplete list, and the AND-filter matching. */
    function normalizeTagKey(tag) {
        return (tag || "").replace(/\s+/g, " ").replace(/^\s+|\s+$/g, "").toLowerCase();
    }

    /* Build a lowercase -> canonical-casing map from every tag used
       across all notes, so we can gently converge casing variants
       ("Second Coming" vs "second coming") instead of letting them
       silently fork into separate tags over time. */
    function collectKnownTagsMap(allNotes) {
        var map = {};
        var ref;
        for (ref in allNotes) {
            if (!allNotes.hasOwnProperty(ref)) { continue; }
            var noteTags = normalizeTagsArray(allNotes[ref] && allNotes[ref].tags);
            if (!noteTags.length) { continue; }
            for (var i = 0; i < noteTags.length; i++) {
                var t = noteTags[i];
                var key = normalizeTagKey(t);
                if (!map[key]) { map[key] = t; }
            }
        }
        return map;
    }

    /* Parse the comma-separated tags input into a clean array: trims
       whitespace, drops empties, de-duplicates case-insensitively
       within this input, and normalizes casing to match an existing
       known tag when one exists. */
    function parseTagsInput(rawInput, knownTagsMap) {
        var parts = (rawInput || "").split(",");
        var result = [];
        var usedKeys = {};
        for (var i = 0; i < parts.length; i++) {
            var t = parts[i].replace(/^\s+|\s+$/g, "");
            if (!t) { continue; }
            var key = normalizeTagKey(t);
            if (usedKeys[key]) { continue; }
            usedKeys[key] = true;
            result.push((knownTagsMap && knownTagsMap[key]) ? knownTagsMap[key] : t);
        }
        return result;
    }

    /* Refresh the autocomplete <datalist> to reflect the current set
       of known tags. */
    function populateTagsDatalist(knownTagsMap) {
        if (!tagsDatalist) { return; }
        tagsDatalist.innerHTML = "";
        var key;
        for (key in knownTagsMap) {
            if (!knownTagsMap.hasOwnProperty(key)) { continue; }
            var opt = document.createElement("option");
            opt.value = knownTagsMap[key];
            tagsDatalist.appendChild(opt);
        }
    }

    function createModal() {
        if (modal) { return; }

        modal = document.createElement("div");
        modal.className = "note-modal";
        modal.id = "note-modal";

        var box = document.createElement("div");
        box.className = "note-modal-box";

        modalTitle = document.createElement("h2");
        modalTitle.className = "note-modal-title";

        modalVerse = document.createElement("div");
        modalVerse.className = "note-modal-verse";

        modalTextarea = document.createElement("textarea");
        modalTextarea.className = "note-modal-textarea";
        modalTextarea.setAttribute("placeholder", "Type your study note here...");

        var hint = document.createElement("p");
        hint.className = "note-modal-hint";
        hint.innerHTML = "Tip: Use [[Book.Ch.Vs]] to link to a verse &mdash; e.g. [[John.3.16]] &nbsp; <a href=\"#\" class=\"note-picker-toggle\" id=\"note-picker-toggle\" onclick=\"toggleBookPicker(); return false;\">&#128366; Show Book List</a>";

        /* Book picker panel */
        var pickerPanel = document.createElement("div");
        pickerPanel.className = "note-book-picker";
        pickerPanel.id = "note-book-picker";
        pickerPanel.style.display = "none";

        var OT_BOOKS = [
            ["Gen","Genesis"],["Exod","Exodus"],["Lev","Leviticus"],["Num","Numbers"],
            ["Deut","Deuteronomy"],["Josh","Joshua"],["Judg","Judges"],["Ruth","Ruth"],
            ["1Sam","1 Samuel"],["2Sam","2 Samuel"],["1Kgs","1 Kings"],["2Kgs","2 Kings"],
            ["1Chr","1 Chronicles"],["2Chr","2 Chronicles"],["Ezra","Ezra"],["Neh","Nehemiah"],
            ["Esth","Esther"],["Job","Job"],["Ps","Psalms"],["Prov","Proverbs"],
            ["Eccl","Ecclesiastes"],["Song","Song of Solomon"],["Isa","Isaiah"],["Jer","Jeremiah"],
            ["Lam","Lamentations"],["Ezek","Ezekiel"],["Dan","Daniel"],["Hos","Hosea"],
            ["Joel","Joel"],["Amos","Amos"],["Obad","Obadiah"],["Jonah","Jonah"],
            ["Mic","Micah"],["Nah","Nahum"],["Hab","Habakkuk"],["Zeph","Zephaniah"],
            ["Hag","Haggai"],["Zech","Zechariah"],["Mal","Malachi"]
        ];
        var NT_BOOKS = [
            ["Matt","Matthew"],["Mark","Mark"],["Luke","Luke"],["John","John"],
            ["Acts","Acts"],["Rom","Romans"],["1Cor","1 Corinthians"],["2Cor","2 Corinthians"],
            ["Gal","Galatians"],["Eph","Ephesians"],["Phil","Philippians"],["Col","Colossians"],
            ["1Thess","1 Thessalonians"],["2Thess","2 Thessalonians"],["1Tim","1 Timothy"],
            ["2Tim","2 Timothy"],["Titus","Titus"],["Phlm","Philemon"],["Heb","Hebrews"],
            ["Jas","James"],["1Pet","1 Peter"],["2Pet","2 Peter"],["1John","1 John"],
            ["2John","2 John"],["3John","3 John"],["Jude","Jude"],["Rev","Revelation"]
        ];

        function makeBookSection(label, books) {
            var sec = document.createElement("div");
            sec.className = "note-picker-section";
            var hd = document.createElement("p");
            hd.className = "note-picker-heading";
            hd.appendChild(document.createTextNode(label));
            sec.appendChild(hd);
            var grid = document.createElement("div");
            grid.className = "note-picker-grid";
            var i;
            for (i = 0; i < books.length; i++) {
                (function(abbr, name) {
                    var btn = document.createElement("button");
                    btn.className = "note-picker-book";
                    btn.title = abbr;
                    btn.appendChild(document.createTextNode(name));
                    btn.onclick = function() { insertBookRef(abbr); return false; };
                    grid.appendChild(btn);
                })(books[i][0], books[i][1]);
            }
            sec.appendChild(grid);
            return sec;
        }

        pickerPanel.appendChild(makeBookSection("Old Testament", OT_BOOKS));
        pickerPanel.appendChild(makeBookSection("New Testament", NT_BOOKS));

        /* Tags input row, with autocomplete against existing tags */
        var tagsRow = document.createElement("div");
        tagsRow.className = "note-modal-tags-row";

        var tagsLabel = document.createElement("label");
        tagsLabel.className = "note-modal-tags-label";
        tagsLabel.appendChild(document.createTextNode("Tags:"));
        tagsRow.appendChild(tagsLabel);

        modalTagsInput = document.createElement("input");
        modalTagsInput.type = "text";
        modalTagsInput.className = "note-modal-tags-input";
        modalTagsInput.setAttribute("placeholder", "e.g. Justification, Second Coming");
        modalTagsInput.setAttribute("list", "note-tags-datalist");
        tagsRow.appendChild(modalTagsInput);

        tagsDatalist = document.createElement("datalist");
        tagsDatalist.id = "note-tags-datalist";
        tagsRow.appendChild(tagsDatalist);

        var tagsHint = document.createElement("p");
        tagsHint.className = "note-modal-tags-hint";
        tagsHint.appendChild(document.createTextNode("Comma-separated. Start typing to see tags you've already used."));
        tagsRow.appendChild(tagsHint);

        var btnRow = document.createElement("div");
        btnRow.className = "note-modal-buttons";

        var saveBtn = document.createElement("button");
        saveBtn.className = "btn btn-primary";
        saveBtn.appendChild(document.createTextNode("Save"));
        saveBtn.onclick = function () { saveNote(); };

        var cancelBtn = document.createElement("button");
        cancelBtn.className = "btn";
        cancelBtn.appendChild(document.createTextNode("Cancel"));
        cancelBtn.onclick = function () { closeNoteModal(); };

        modalDeleteBtn = document.createElement("button");
        modalDeleteBtn.className = "btn btn-danger";
        modalDeleteBtn.appendChild(document.createTextNode("Delete"));
        modalDeleteBtn.onclick = function () { deleteNote(); };

        btnRow.appendChild(saveBtn);
        btnRow.appendChild(cancelBtn);
        btnRow.appendChild(modalDeleteBtn);

        /* Color picker row */
        pickerRow = document.createElement("div");
        pickerRow.className = "hl-picker";

        var pickerLabel = document.createElement("span");
        pickerLabel.className = "hl-picker-label";
        pickerLabel.appendChild(document.createTextNode("Highlight:"));
        pickerRow.appendChild(pickerLabel);

        for (var ci = 0; ci < HL_COLORS.length; ci++) {
            (function (color) {
                var btn = document.createElement("button");
                btn.className = "hl-btn hl-btn-" + color;
                btn.setAttribute("data-color", color);
                btn.setAttribute("title", color.charAt(0).toUpperCase() + color.slice(1));
                btn.innerHTML = "&nbsp;";
                btn.onclick = function () { selectHighlightColor(color); };
                pickerRow.appendChild(btn);
            })(HL_COLORS[ci]);
        }

        var clearBtn = document.createElement("button");
        clearBtn.className = "hl-btn hl-btn-clear";
        clearBtn.setAttribute("data-color", "clear");
        clearBtn.setAttribute("title", "Remove highlight");
        clearBtn.appendChild(document.createTextNode("\u2715"));
        clearBtn.onclick = function () { selectHighlightColor(null); };
        pickerRow.appendChild(clearBtn);

        box.appendChild(modalTitle);
        box.appendChild(pickerRow);
        box.appendChild(modalVerse);
        box.appendChild(modalTextarea);
        box.appendChild(hint);
        box.appendChild(pickerPanel);
        box.appendChild(tagsRow);
        box.appendChild(btnRow);
        modal.appendChild(box);

        /* Close on backdrop click */
        modal.onclick = function (e) {
            var target = e.target || e.srcElement;
            if (target === modal) { closeNoteModal(); }
        };

        document.body.appendChild(modal);

        /* Close on Escape key */
        var oldKeydown = document.onkeydown;
        document.onkeydown = function (e) {
            e = e || window.event;
            var key = e.keyCode || e.which;
            if (key === 27 && modal.className.indexOf("is-open") !== -1) {
                closeNoteModal();
            }
            if (typeof oldKeydown === "function") { oldKeydown(e); }
        };
    }

    /* -- Open the note modal ------------------------------------  */

    window.openNoteModal = function (ref) {
        if (!canTakeNotes) { return; }

        createModal();

        currentRef = ref;

        /* Parse reference for display: Gen.1.1 -> "Genesis 1:1" */
        var parts = ref.split(".");
        var bookAbbr = parts[0] || "";
        var ch = parts[1] || "";
        var vs = parts[2] || "";
        var displayRef = bookAbbr + " " + ch + ":" + vs;

        modalTitle.innerHTML = "";
        modalTitle.appendChild(document.createTextNode("Note \u2014 " + displayRef));

        /* Get verse text from DOM */
        var verseText = getVerseText(parseInt(vs, 10));
        modalVerse.innerHTML = "";
        modalVerse.appendChild(document.createTextNode(verseText));

        /* Reset textarea */
        modalTextarea.value = "";
        modalTagsInput.value = "";
        modalDeleteBtn.style.display = "none";

        /* Set up highlight state for this verse */
        var existingColor = highlights[ref] || null;
        selectedColor = existingColor;
        originalColor = existingColor;
        updatePickerUI(selectedColor);
        previewHighlight(ref, selectedColor);

        if (isPhoneMode) {
            /* Phone mode: load from localStorage */
            var phoneNs = phoneGetNotes();
            lastKnownTagsMap = collectKnownTagsMap(phoneNs);
            populateTagsDatalist(lastKnownTagsMap);
            if (phoneNs[ref]) {
                modalTextarea.value = phoneNs[ref].text || "";
                modalTagsInput.value = (phoneNs[ref].tags || []).join(", ");
                modalDeleteBtn.style.display = "inline-block";
            }
            addClass(modal, "is-open");
            modalTextarea.focus();
        } else {
            /* PC mode: fetch from server */
            ajax("GET", pcServerOrigin + "/api/notes", null, function (status, data) {
                if (status === 200 && data) {
                    normalizeNotesTagsInPlace(data);
                    lastKnownTagsMap = collectKnownTagsMap(data);
                    populateTagsDatalist(lastKnownTagsMap);
                }
                if (status === 200 && data && data[ref]) {
                    modalTextarea.value = data[ref].text || "";
                    modalTagsInput.value = normalizeTagsArray(data[ref].tags).join(", ");
                    modalDeleteBtn.style.display = "inline-block";
                }
                addClass(modal, "is-open");
                modalTextarea.focus();
            });
        }
    };

    /* -- Close modal --------------------------------------------  */

    function closeNoteModal(skipRevert) {
        if (modal) { removeClass(modal, "is-open"); }
        /* Revert highlight preview unless we just saved */
        if (!skipRevert && currentRef && selectedColor !== originalColor) {
            previewHighlight(currentRef, originalColor);
        }
        currentRef = "";
        selectedColor = null;
        originalColor = null;
    }
    window.closeNoteModal = closeNoteModal;

    /* Insert book abbreviation at cursor in textarea */
    window.insertBookRef = function(abbr) {
        if (!modalTextarea) { return; }
        var start = modalTextarea.selectionStart;
        var end   = modalTextarea.selectionEnd;
        var val   = modalTextarea.value;
        var insert = "[[" + abbr + ".";
        modalTextarea.value = val.substring(0, start) + insert + val.substring(end);
        /* Place cursor after the inserted text */
        var pos = start + insert.length;
        modalTextarea.selectionStart = pos;
        modalTextarea.selectionEnd   = pos;
        modalTextarea.focus();
    };

    /* Toggle book picker panel visibility */
    window.toggleBookPicker = function() {
        var panel  = document.getElementById("note-book-picker");
        var toggle = document.getElementById("note-picker-toggle");
        if (!panel) { return; }
        if (panel.style.display === "none") {
            panel.style.display = "block";
            if (toggle) { toggle.innerHTML = "&#128366; Hide Book List"; }
        } else {
            panel.style.display = "none";
            if (toggle) { toggle.innerHTML = "&#128366; Show Book List"; }
        }
    };

    /* -- Save note ----------------------------------------------  */

    function saveNote() {
        var text = modalTextarea.value;
        var ref = currentRef;
        var tags = parseTagsInput(modalTagsInput.value, lastKnownTagsMap);

        if (!ref) { return; }

        /* Save highlight first (independent of note) */
        var hlColor = selectedColor;
        var hlOriginal = originalColor;
        var hlChanged = (hlColor !== hlOriginal);

        if (hlChanged) {
            if (isPhoneMode) {
                phoneSaveHighlight(ref, hlColor);
                highlights[ref] = hlColor || null;
            } else {
                if (hlColor) {
                    var hlPayload = JSON.stringify({ ref: ref, color: hlColor });
                    ajax("POST", pcServerOrigin + "/api/highlights", hlPayload, function (st) {
                        if (st === 200) { highlights[ref] = hlColor; }
                    });
                } else {
                    ajax("DELETE", pcServerOrigin + "/api/highlights/" + encodeURIComponent(ref), null, function (st) {
                        if (st === 200) { delete highlights[ref]; }
                    });
                }
            }
        }

        /* Save if there's EITHER note text OR tags -- a highlighted
           verse with tags but no written note is a legitimate thing to
           save now, not something to silently discard. */
        var hasContent = !!text || (tags && tags.length > 0);

        if (!hasContent) {
            closeNoteModal(true);
            if (hlChanged) {
                showToast("Highlight updated", "success");
            } else {
                showToast("Nothing to save", "error");
            }
            return;
        }

        if (isPhoneMode) {
            /* Phone mode: write to localStorage immediately */
            phoneSaveNote(ref, text, tags);
            closeNoteModal(true);
            updateVerseIndicator(ref, true);
            if (text) { refreshBakedNote(ref, text); } else { clearBakedNote(ref); }
            if (isNotesManagerPage && typeof window.nmRefreshAfterSave === "function") { window.nmRefreshAfterSave(ref); }
            showToast((text ? "Note saved" : "Tags saved") + " \uD83D\uDCF1 (syncs when on your PC\u2019s WiFi)", "success");
            return;
        }

        var payload = JSON.stringify({ ref: ref, text: text, tags: tags });

        ajax("POST", pcServerOrigin + "/api/notes", payload, function (status, data) {
            if (status === 200 && data && data.ok) {
                closeNoteModal(true);
                updateVerseIndicator(ref, true);
                if (text) { refreshBakedNote(ref, text); } else { clearBakedNote(ref); }
                if (isNotesManagerPage && typeof window.nmRefreshAfterSave === "function") { window.nmRefreshAfterSave(ref); }
                showToast(text ? "Note saved" : "Tags saved", "success");
            } else {
                showToast("Failed to save note", "error");
            }
        });
    }
    window.saveNote = saveNote;

    /* -- Delete note --------------------------------------------  */

    function deleteNote() {
        if (!currentRef) { return; }
        var ref = currentRef;

        if (isPhoneMode) {
            phoneDeleteNote(ref);
            closeNoteModal(true);
            updateVerseIndicator(ref, false);
            clearBakedNote(ref);
            if (isNotesManagerPage && typeof window.nmRefreshAfterSave === "function") { window.nmRefreshAfterSave(ref); }
            showToast("Note deleted \uD83D\uDCF1", "success");
            return;
        }

        ajax("DELETE", pcServerOrigin + "/api/notes/" + encodeURIComponent(ref), null,
            function (status, data) {
                if (status === 200 && data && data.ok) {
                    closeNoteModal(true);
                    updateVerseIndicator(ref, false);
                    clearBakedNote(ref);
                    if (isNotesManagerPage && typeof window.nmRefreshAfterSave === "function") { window.nmRefreshAfterSave(ref); }
                    showToast("Note deleted", "success");
                } else {
                    showToast("Failed to delete note", "error");
                }
            }
        );
    }
    window.deleteNote = deleteNote;

    /* -- Update the pencil button indicator ----------------------  */

    function updateVerseIndicator(ref, hasNote) {
        var parts = ref.split(".");
        var vs = parts[2];
        var verseP = document.getElementById("verse-" + vs);
        if (!verseP) { return; }

        var btns = verseP.getElementsByTagName("button");
        for (var i = 0; i < btns.length; i++) {
            if (btns[i].className.indexOf("note-btn") !== -1) {
                if (hasNote) {
                    addClass(btns[i], "has-note");
                } else {
                    removeClass(btns[i], "has-note");
                }
                break;
            }
        }
    }

    /* -- Update the baked note div in the DOM -------------------  */
    /* After saving, update the visible baked note immediately
       so the user doesn't need to reload the page.               */

    function refreshBakedNote(ref, text) {
        var parts = ref.split(".");
        var vs = parts[2];
        var noteDiv = document.getElementById("note-verse-" + vs);
        if (!noteDiv) { return; }

        var now = new Date();
        var dateStr = now.getFullYear() + "-"
            + pad2(now.getMonth() + 1) + "-"
            + pad2(now.getDate()) + " "
            + pad2(now.getHours()) + ":"
            + pad2(now.getMinutes());

        noteDiv.innerHTML = ""
            + '<p class="verse-note-text">'
            + linkifyVerseRefs(escapeHtml(text))
            + "</p>"
            + '<p class="verse-note-meta">Note saved: '
            + dateStr
            + "</p>";
    }

    function clearBakedNote(ref) {
        var parts = ref.split(".");
        var vs = parts[2];
        var noteDiv = document.getElementById("note-verse-" + vs);
        if (noteDiv) { noteDiv.innerHTML = ""; }
    }

    function pad2(n) {
        return n < 10 ? "0" + n : "" + n;
    }

    function escapeHtml(str) {
        return str
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/\n/g, "<br>");
    }

    var BOOK_FOLDERS = {
        "Gen":"01-Gen","Exod":"02-Exod","Lev":"03-Lev","Num":"04-Num",
        "Deut":"05-Deut","Josh":"06-Josh","Judg":"07-Judg","Ruth":"08-Ruth",
        "1Sam":"09-1Sam","2Sam":"10-2Sam","1Kgs":"11-1Kgs","2Kgs":"12-2Kgs",
        "1Chr":"13-1Chr","2Chr":"14-2Chr","Ezra":"15-Ezra","Neh":"16-Neh",
        "Esth":"17-Esth","Job":"18-Job","Ps":"19-Ps","Prov":"20-Prov",
        "Eccl":"21-Eccl","Song":"22-Song","Isa":"23-Isa","Jer":"24-Jer",
        "Lam":"25-Lam","Ezek":"26-Ezek","Dan":"27-Dan","Hos":"28-Hos",
        "Joel":"29-Joel","Amos":"30-Amos","Obad":"31-Obad","Jonah":"32-Jonah",
        "Mic":"33-Mic","Nah":"34-Nah","Hab":"35-Hab","Zeph":"36-Zeph",
        "Hag":"37-Hag","Zech":"38-Zech","Mal":"39-Mal","Matt":"40-Matt",
        "Mark":"41-Mark","Luke":"42-Luke","John":"43-John","Acts":"44-Acts",
        "Rom":"45-Rom","1Cor":"46-1Cor","2Cor":"47-2Cor","Gal":"48-Gal",
        "Eph":"49-Eph","Phil":"50-Phil","Col":"51-Col","1Thess":"52-1Thess",
        "2Thess":"53-2Thess","1Tim":"54-1Tim","2Tim":"55-2Tim","Titus":"56-Titus",
        "Phlm":"57-Phlm","Heb":"58-Heb","Jas":"59-Jas","1Pet":"60-1Pet",
        "2Pet":"61-2Pet","1John":"62-1John","2John":"63-2John","3John":"64-3John",
        "Jude":"65-Jude","Rev":"66-Rev"
    };

    function linkifyVerseRefs(text) {
        var result = "";
        var i = 0;
        while (i < text.length) {
            var open = text.indexOf("[[", i);
            if (open === -1) { result += text.substring(i); break; }
            result += text.substring(i, open);
            var close = text.indexOf("]]", open + 2);
            if (close === -1) { result += text.substring(open); break; }
            var ref = text.substring(open + 2, close);
            var parts = ref.split(".");
            if (parts.length === 3 && /^\d+$/.test(parts[1]) && /^\d+$/.test(parts[2])) {
                var bookAbbr = parts[0];
                var ch = parts[1];
                var vs = parts[2];
                var folder = BOOK_FOLDERS[bookAbbr];
                if (folder) {
                    var href = "../../books/" + folder + "/" + ch + ".html#verse-" + vs;
                    result += "<a href=\"" + href + "\" class=\"verse-note-link\">" + bookAbbr + " " + ch + ":" + vs + "</a>";
                } else {
                    result += bookAbbr + " " + ch + ":" + vs;
                }
            } else {
                result += "[[" + ref + "]]";
            }
            i = close + 2;
        }
        return result;
    }

    /* ============================================================
       Rebake Notes
       ============================================================ */

    window.rebakeNotes = function () {
        if (!isLocalhost) { return; }
        showToast("Rebaking notes...", "");

        ajax("POST", pcServerOrigin + "/api/rebake", null, function (status, data) {
            if (status === 200 && data && data.ok) {
                var msg = "Rebaked " + (data.notesRebaked || 0) + " notes, "
                        + (data.highlightsRebaked || 0) + " highlights";
                showToast(msg, "success");
            } else {
                var errMsg = (data && data.error) ? data.error : "Rebake failed";
                showToast(errMsg, "error");
            }
        });
    };

    /* ============================================================
       Export Notes
       ============================================================
       Downloads notes.json from the server as a timestamped file.
       The browser's native download mechanism handles the Save As
       dialog — no custom folder configuration needed.
       ============================================================ */

    window.exportNotes = function () {
        if (!isLocalhost) {
            showToast("Export is only available when running the study server.", "error");
            return;
        }
        var stamp = new Date().toISOString().slice(0, 10);
        var filename = "kjv-notes-" + stamp + ".json";
        var a = document.createElement("a");
        a.href = "/api/export-notes";
        a.download = "";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        showToast("Notes saved to your Downloads folder as " + filename, "success");
    };

    /* ============================================================
       Import Notes / Highlights
       ============================================================
       File picker -> read JSON client-side -> POST to preview ->
       show diff/conflict modal -> user resolves conflicts ->
       POST to commit -> rebake -> reload.
       ============================================================ */

    var importedBundle = null; /* holds the parsed file while modal is open */

    function createImportFileInput() {
        if (document.getElementById("import-file-input")) { return; }
        var input = document.createElement("input");
        input.type = "file";
        input.id = "import-file-input";
        input.accept = ".json,application/json";
        input.style.display = "none";
        input.onchange = function (e) {
            var file = e.target.files && e.target.files[0];
            if (!file) { return; }
            var reader = new FileReader();
            reader.onload = function (evt) {
                var parsed;
                try {
                    parsed = JSON.parse(evt.target.result);
                } catch (err) {
                    showToast("That file isn't valid JSON.", "error");
                    return;
                }
                importedBundle = parsed;
                requestImportPreview(parsed);
            };
            reader.onerror = function () {
                showToast("Could not read that file.", "error");
            };
            reader.readAsText(file);
            input.value = ""; /* allow re-selecting the same file later */
        };
        document.body.appendChild(input);
    }

    window.importNotes = function () {
        if (!isLocalhost) {
            showToast("Import is only available when running the study server.", "error");
            return;
        }
        createImportFileInput();
        document.getElementById("import-file-input").click();
    };

    function requestImportPreview(bundle) {
        showToast("Comparing with your current notes...", "");
        ajax("POST", pcServerOrigin + "/api/import-notes/preview", JSON.stringify(bundle), function (status, data) {
            if (status === 200 && data && data.ok) {
                showImportPreviewModal(data);
            } else {
                showToast("Could not preview import — file may be malformed.", "error");
            }
        });
    }

    function createImportModal() {
        if (document.getElementById("import-modal")) { return; }
        var modal = document.createElement("div");
        modal.id = "import-modal";
        modal.className = "import-modal";
        modal.innerHTML =
            '<div class="import-modal-box">' +
            '  <h2 class="import-modal-title">&#128229; Import Notes &amp; Highlights</h2>' +
            '  <div id="import-summary" class="import-summary"></div>' +
            '  <div id="import-conflicts" class="import-conflicts"></div>' +
            '  <div class="import-modal-btns">' +
            '    <button class="update-now-btn" id="import-apply-btn" onclick="applyImport()">Apply Import</button>' +
            '    <button class="update-later-btn" onclick="closeImportModal()">Cancel</button>' +
            '  </div>' +
            '</div>';
        document.body.appendChild(modal);
    }

    function showImportPreviewModal(data) {
        createImportModal();
        var modal = document.getElementById("import-modal");
        var summaryEl = document.getElementById("import-summary");
        var conflictsEl = document.getElementById("import-conflicts");

        var n = data.notes, h = data.highlights;
        var totalNew = n.newCount + h.newCount;
        var totalConflicts = n.conflictCount + h.conflictCount;
        var totalUnchanged = n.unchangedCount + h.unchangedCount;

        var summaryHtml = "";
        if (totalNew > 0) { summaryHtml += '<p class="import-line import-line-new">+ ' + totalNew + " new item(s) will be added</p>"; }
        if (totalConflicts > 0) { summaryHtml += '<p class="import-line import-line-conflict">&#9888; ' + totalConflicts + " conflict(s) found &mdash; choose below</p>"; }
        if (totalUnchanged > 0) { summaryHtml += '<p class="import-line import-line-same">' + totalUnchanged + " item(s) are already identical</p>"; }
        if (totalNew === 0 && totalConflicts === 0 && totalUnchanged === 0) { summaryHtml = '<p class="import-line">No notes or highlights found in that file.</p>'; }
        summaryEl.innerHTML = summaryHtml;

        var conflictsHtml = "";
        n.conflicts.forEach(function (c) {
            conflictsHtml += renderNoteConflict(c);
        });
        h.conflicts.forEach(function (c) {
            conflictsHtml += renderHighlightConflict(c);
        });
        conflictsEl.innerHTML = conflictsHtml;

        var applyBtn = document.getElementById("import-apply-btn");
        if (applyBtn) {
            applyBtn.textContent = totalNew + totalConflicts > 0
                ? "Apply Import"
                : "Nothing to Import";
            applyBtn.disabled = (totalNew + totalConflicts === 0);
        }

        addClass(modal, "is-open");
    }

    function escapeHtml(s) {
        var d = document.createElement("div");
        d.textContent = s == null ? "" : String(s);
        return d.innerHTML;
    }

    function renderNoteConflict(c) {
        var safeRef = escapeHtml(c.ref);
        return '<div class="import-conflict-row" data-ref="' + safeRef + '" data-kind="note">' +
            '  <p class="import-conflict-ref">' + safeRef + '</p>' +
            '  <label class="import-conflict-opt"><input type="radio" name="res-note-' + safeRef + '" value="imported" checked> ' +
            '    <span class="import-conflict-label">Imported:</span> <span class="import-conflict-text">' + escapeHtml(c.importedText) + '</span></label>' +
            '  <label class="import-conflict-opt"><input type="radio" name="res-note-' + safeRef + '" value="current"> ' +
            '    <span class="import-conflict-label">Keep current:</span> <span class="import-conflict-text">' + escapeHtml(c.currentText) + '</span></label>' +
            '</div>';
    }

    function renderHighlightConflict(c) {
        var safeRef = escapeHtml(c.ref);
        return '<div class="import-conflict-row" data-ref="' + safeRef + '" data-kind="highlight">' +
            '  <p class="import-conflict-ref">' + safeRef + ' (highlight)</p>' +
            '  <label class="import-conflict-opt"><input type="radio" name="res-hl-' + safeRef + '" value="imported" checked> ' +
            '    <span class="import-conflict-label">Imported:</span> <span class="import-swatch import-swatch-' + escapeHtml(c.importedColor) + '"></span></label>' +
            '  <label class="import-conflict-opt"><input type="radio" name="res-hl-' + safeRef + '" value="current"> ' +
            '    <span class="import-conflict-label">Keep current:</span> <span class="import-swatch import-swatch-' + escapeHtml(c.currentColor) + '"></span></label>' +
            '</div>';
    }

    window.closeImportModal = function () {
        var modal = document.getElementById("import-modal");
        if (modal) { removeClass(modal, "is-open"); }
        importedBundle = null;
    };

    window.applyImport = function () {
        if (!importedBundle) { return; }

        var resolutions = {};
        var rows = document.querySelectorAll(".import-conflict-row");
        for (var i = 0; i < rows.length; i++) {
            var row = rows[i];
            var ref = row.getAttribute("data-ref");
            var kind = row.getAttribute("data-kind");
            var checked = row.querySelector('input[type="radio"]:checked');
            var value = checked ? checked.value : "imported";
            var key = (kind === "highlight") ? ("hl:" + ref) : ref;
            resolutions[key] = value;
        }

        var applyBtn = document.getElementById("import-apply-btn");
        if (applyBtn) { applyBtn.disabled = true; applyBtn.textContent = "Importing..."; }

        var payload = JSON.stringify({ bundle: importedBundle, resolutions: resolutions });

        ajax("POST", pcServerOrigin + "/api/import-notes/commit", payload, function (status, data) {
            if (status === 200 && data && data.ok) {
                showToast("Imported " + data.imported + " item(s)" + (data.skipped ? ", skipped " + data.skipped : ""), "success");
                closeImportModal();
                setTimeout(function () { window.location.reload(); }, 1200);
            } else {
                showToast("Import failed.", "error");
                if (applyBtn) { applyBtn.disabled = false; applyBtn.textContent = "Apply Import"; }
            }
        });
    };

    /* ============================================================
       Sync Phone via QR Code (WiFi)
       ============================================================ */

    window.syncViaQr = function () {
        if (!isLocalhost) {
            showToast("QR sync must be triggered from the PC app.", "error");
            return;
        }

        ajax("GET", pcServerOrigin + "/api/local-url", null, function (status, data) {
            if (status === 200 && data && data.ok) {
                showQrModal(data.url);
            } else {
                var err = (data && data.error) ? data.error : "Could not detect local IP address.";
                showToast("⚠️ " + err, "error");
            }
        });
    };

    function showQrModal(url) {
        function buildModal() {
            var overlay = document.createElement("div");
            overlay.id = "qr-overlay";
            overlay.style.cssText = "position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:9999;display:flex;align-items:center;justify-content:center;";

            var box = document.createElement("div");
            box.style.cssText = "background:#1e1e2e;border:1px solid #00bcd4;border-radius:12px;padding:28px 32px;max-width:340px;width:92%;text-align:center;";

            var title = document.createElement("h3");
            title.textContent = "Sync Phone via QR Code";
            title.style.cssText = "color:#00bcd4;margin:0 0 8px;font-size:1.1rem;";

            var note = document.createElement("p");
            note.textContent = "Your phone must be on the same WiFi network as your PC app for this to work.";
            note.style.cssText = "color:#aaa;font-size:0.82rem;margin:0 0 16px;line-height:1.4;";

            var qrWrap = document.createElement("div");
            qrWrap.id = "qr-code-canvas";
            qrWrap.style.cssText = "display:flex;justify-content:center;margin-bottom:14px;background:#fff;padding:12px;border-radius:8px;";

            var urlLabel = document.createElement("p");
            urlLabel.textContent = url;
            urlLabel.style.cssText = "color:#888;font-size:0.75rem;word-break:break-all;margin:0 0 18px;";

            var closeBtn = document.createElement("button");
            closeBtn.textContent = "Close";
            closeBtn.className = "btn";
            closeBtn.onclick = function () { document.body.removeChild(overlay); };

            box.appendChild(title);
            box.appendChild(note);
            box.appendChild(qrWrap);
            box.appendChild(urlLabel);
            box.appendChild(closeBtn);
            overlay.appendChild(box);
            document.body.appendChild(overlay);

            new QRCode(qrWrap, {
                text: url,
                width: 200,
                height: 200,
                colorDark: "#000000",
                colorLight: "#ffffff",
                correctLevel: QRCode.CorrectLevel.M
            });
        }

        if (typeof QRCode !== "undefined") {
            buildModal();
        } else {
            var s = document.createElement("script");
            s.src = "https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js";
            s.onload = buildModal;
            s.onerror = function () {
                showToast("⚠️ Could not load QR library. Try visiting: " + url, "error");
            };
            document.head.appendChild(s);
        }
    }

        /* ============================================================
       Sync to Kindle
       ============================================================ */

    window.syncToKindle = function () {
        if (!isLocalhost) { return; }

        /* Show sync wait modal with minimum 2 second display */
        var syncModal = document.getElementById("sync-modal");
        if (!syncModal) {
            syncModal = document.createElement("div");
            syncModal.id = "sync-modal";
            syncModal.className = "sync-modal";
            var syncBox = document.createElement("div");
            syncBox.className = "sync-modal-box";
            var syncText = document.createElement("p");
            syncText.className = "sync-modal-text";
            syncText.innerHTML = "&#9889; Syncing to Kindle&hellip;<br><br>Please wait until sync is complete.";
            syncBox.appendChild(syncText);
            syncModal.appendChild(syncBox);
            document.body.appendChild(syncModal);
        }
        addClass(syncModal, "is-open");
        var syncStart = new Date().getTime();

        ajax("POST", pcServerOrigin + "/api/sync-kindle", null, function (status, data) {
            var elapsed = new Date().getTime() - syncStart;
            var delay = Math.max(0, 2000 - elapsed);
            setTimeout(function () {
                removeClass(syncModal, "is-open");
                if (status === 200 && data) {
                    var msg = "Pushed " + (data.pushed || 0) + " file(s) to Kindle";
                    showToast(msg, "success");
                } else {
                    var errMsg = (data && data.error) ? data.error : "Sync failed";
                    showToast(errMsg, "error");
                }
            }, delay);
        });
    };

    /* Test sync modal — calls /api/test-sync (5 second fake delay) */
    window.testSyncModal = function () {
        if (!isLocalhost) { return; }
        var syncModal = document.getElementById("sync-modal");
        if (!syncModal) {
            syncModal = document.createElement("div");
            syncModal.id = "sync-modal";
            syncModal.className = "sync-modal";
            var syncBox = document.createElement("div");
            syncBox.className = "sync-modal-box";
            var syncText = document.createElement("p");
            syncText.className = "sync-modal-text";
            syncText.innerHTML = "&#9889; Syncing to Kindle&hellip;<br><br>Please wait until sync is complete.";
            syncBox.appendChild(syncText);
            syncModal.appendChild(syncBox);
            document.body.appendChild(syncModal);
        }
        addClass(syncModal, "is-open");
        ajax("POST", pcServerOrigin + "/api/test-sync", null, function (status, data) {
            removeClass(syncModal, "is-open");
            if (status === 200 && data) {
                showToast("TEST: Pushed " + (data.pushed || 0) + " file(s)", "success");
            } else {
                showToast("TEST: Sync failed", "error");
            }
        });
    };

    /* ============================================================
       Kindle Connection Status Polling
       ============================================================ */

    function updateSyncButton(connected) {
        var btn = document.getElementById("sync-btn");
        var row = document.getElementById("sync-kindle-row");

        /* Handle legacy sync-btn in header (if present) */
        if (btn) {
            if (connected) {
                removeClass(btn, "btn-disabled");
                btn.disabled = false;
                btn.title = "Sync to Kindle";
            } else {
                addClass(btn, "btn-disabled");
                btn.disabled = true;
                btn.title = "Kindle not connected";
            }
        }

        /* Handle settings menu row */
        if (row) {
            if (connected) {
                removeClass(row, "settings-row-disabled");
                row.onclick = function () { syncToKindle(); };
                row.title = "";
            } else {
                addClass(row, "settings-row-disabled");
                row.onclick = null;
                row.title = "Not connected";
            }
        }
    }

    function pollKindleStatus() {
        ajax("GET", pcServerOrigin + "/api/kindle-status", null, function (status, data) {
            if (status === 200 && data) {
                updateSyncButton(data.connected === true);
            }
        });
    }

    /* ============================================================
       Initialization
       ============================================================ */

    /* -- Highlight helper functions ------------------------------ */

    function selectHighlightColor(color) {
        selectedColor = color;
        updatePickerUI(color);
        if (currentRef) {
            previewHighlight(currentRef, color);
        }
    }

    function updatePickerUI(activeColor) {
        if (!pickerRow) { return; }
        var btns = pickerRow.getElementsByTagName("button");
        for (var i = 0; i < btns.length; i++) {
            var btnColor = btns[i].getAttribute("data-color");
            if (btnColor === activeColor || (btnColor === "clear" && activeColor === null)) {
                addClass(btns[i], "active");
            } else {
                removeClass(btns[i], "active");
            }
        }
    }

    function applyHighlightClass(verseId, color) {
        var el = document.getElementById(verseId);
        if (!el) { return; }
        for (var i = 0; i < HL_COLORS.length; i++) {
            removeClass(el, "hl-" + HL_COLORS[i]);
        }
        if (color && HL_CLASSES[color]) {
            addClass(el, HL_CLASSES[color]);
        }
    }

    function removeHighlightClass(verseId) {
        var el = document.getElementById(verseId);
        if (!el) { return; }
        for (var i = 0; i < HL_COLORS.length; i++) {
            removeClass(el, "hl-" + HL_COLORS[i]);
        }
    }

    function previewHighlight(ref, color) {
        var vsNum = ref.split(".")[2];
        if (color) {
            applyHighlightClass("verse-" + vsNum, color);
        } else {
            removeHighlightClass("verse-" + vsNum);
        }
    }

    /* ============================================================
       Phone ↔ PC Sync System
       ============================================================
       When on phone mode (connecting to PC over WiFi):
       - Notes and highlights are stored in localStorage
       - On page load, check if PC server is reachable
       - If reachable, offer to sync (or auto-sync if no conflicts)
       - Sync uses the same conflict-resolution UI as Import Notes

       When PC server is unreachable (offline/away):
       - Notes continue saving to localStorage silently
       - Sync banner shows "offline" state
       ============================================================ */

    if (isPhoneMode || isLocalhost) {
        (function () {

            var SYNC_BANNER_ID = "phone-sync-banner";
            /* Tracks whether the "up to date, nothing pending" banner has
               already been shown once this session — used to avoid
               repeating it on every page navigation. Uses sessionStorage
               (not localStorage) so it resets on a fresh browsing session
               but persists across chapter/page navigations within one.
               Banners with something actually actionable (pending items,
               or a first-ever sync) still show every time regardless. */
            var SYNC_BANNER_SHOWN_KEY = "kjv-sync-banner-shown-session";
            /* Same idea as above, but for the "you're offline" banner —
               this was missing from the original once-per-session fix,
               which only covered the connected/up-to-date case. */
            var OFFLINE_BANNER_SHOWN_KEY = "kjv-offline-banner-shown-session";
            var pcReachable = false;
            var syncCheckDone = false;

            /* Check if the PC server is reachable */
            function checkPcReachable(cb) {
                var xhr2;
                try { xhr2 = new XMLHttpRequest(); }
                catch (e) { cb(false); return; }
                xhr2.open("GET", "/api/notes", true);
                xhr2.timeout = 6000;
                xhr2.onreadystatechange = function () {
                    if (xhr2.readyState === 4) {
                        cb(xhr2.status === 200);
                    }
                };
                xhr2.ontimeout = function () { cb(false); };
                xhr2.onerror  = function () { cb(false); };
                try { xhr2.send(null); } catch (e) { cb(false); }
            }

            /* Create the sync banner that floats at the top of the page */
            function createSyncBanner() {
                if (document.getElementById(SYNC_BANNER_ID)) { return; }
                var banner = document.createElement("div");
                banner.id = SYNC_BANNER_ID;
                banner.className = "sync-banner";
                document.body.insertBefore(banner, document.body.firstChild);
            }

            function setSyncBanner(state, detail) {
                createSyncBanner();
                var banner = document.getElementById(SYNC_BANNER_ID);
                if (!banner) { return; }
                banner.className = "sync-banner sync-banner-" + state;
                banner.innerHTML = detail;
            }

            function hideSyncBanner() {
                var banner = document.getElementById(SYNC_BANNER_ID);
                if (banner) { banner.className = "sync-banner sync-banner-hidden"; }
            }

            /* Count pending (unsynced) phone notes */
            function countPendingNotes() {
                var lastSync = localStorage.getItem(LS_LAST_SYNC) || "";
                var notes = phoneGetNotes();
                var highs = phoneGetHighlights();
                var syncedHighs = lsGet(LS_SYNCED_HIGHLIGHTS);
                var tombs = lsGet(LS_TOMBSTONES);
                var count = 0;
                var key;
                for (key in notes) {
                    if (!notes.hasOwnProperty(key)) { continue; }
                    if (!lastSync || notes[key].updated > lastSync) { count++; }
                }
                for (key in highs) {
                    if (!highs.hasOwnProperty(key)) { continue; }
                    /* Only count if this highlight is new or changed since
                       the last successful sync — not every highlight that
                       merely still exists. */
                    if (syncedHighs[key] !== highs[key]) { count++; }
                }
                for (key in tombs) {
                    if (!tombs.hasOwnProperty(key)) { continue; }
                    if (!lastSync || tombs[key].deletedAt > lastSync) { count++; }
                }
                return count;
            }

            /* Show sync available banner.
               Note: pendingCount only reflects changes made ON THE PHONE
               since the last sync — it has no way to know whether the PC
               has notes/highlights the phone doesn't have yet (e.g. the
               very first time a phone connects to a PC that already has
               notes). So "Sync Now" must always be offered, not just
               when local pendingCount > 0, or there'd be no way to pull
               down existing PC data on a fresh phone. */
            function showSyncAvailableBanner(pendingCount, neverSynced) {
                var msg = "\uD83D\uDCF6 Connected to your PC.";
                if (pendingCount > 0) {
                    msg += " <strong>" + pendingCount + " unsynced note(s)</strong> ready to sync.";
                } else if (neverSynced) {
                    msg += " Tap Sync to pull down any notes already on your PC.";
                } else {
                    msg += " Notes are up to date.";
                }
                msg += ' &nbsp;<button class="sync-banner-btn" onclick="syncWithPc()">Sync Now</button>';
                msg += ' &nbsp;<button class="sync-banner-dismiss" onclick="dismissSyncBanner()">&#10005;</button>';
                setSyncBanner("connected", msg);
            }

            window.dismissSyncBanner = function () { hideSyncBanner(); };

            /* ── Main sync function ───────────────────────────── */
            window.syncWithPc = function () {
                setSyncBanner("syncing", "\uD83D\uDD04 Syncing with PC...");

                var phoneNotes      = phoneGetNotes();
                var phoneHighlights = phoneGetHighlights();
                var phoneTombstones = lsGet(LS_TOMBSTONES);
                var lastSync        = localStorage.getItem(LS_LAST_SYNC) || "";

                var payload = JSON.stringify({
                    phoneNotes:      phoneNotes,
                    phoneHighlights: phoneHighlights,
                    phoneTombstones: phoneTombstones,
                    lastSyncAt:      lastSync
                });

                ajax("POST", pcServerOrigin + "/api/sync-notes", payload, function (status, data) {
                    if (status !== 200 || !data || !data.ok) {
                        setSyncBanner("error",
                            "\u26A0\uFE0F Sync failed. " +
                            '<button class="sync-banner-btn" onclick="syncWithPc()">Retry</button> ' +
                            '<button class="sync-banner-dismiss" onclick="dismissSyncBanner()">&#10005;</button>');
                        return;
                    }

                    if (data.conflicts && (data.conflicts.notes.length > 0 || data.conflicts.highlights.length > 0)) {
                        /* Show conflict resolution modal reusing import UI */
                        setSyncBanner("connected", "\uD83D\uDCF6 Connected — please resolve conflicts below.");
                        showSyncConflictModal(data);
                    } else {
                        /* No conflicts — apply the merged result directly */
                        applySyncResult(data, null);
                    }
                });
            };

            function applySyncResult(data, resolutions) {
                var payload = JSON.stringify({
                    resolutions: resolutions || {},
                    syncToken:   data.syncToken
                });

                ajax("POST", pcServerOrigin + "/api/sync-notes/commit", payload, function (status, result) {
                    if (status === 200 && result && result.ok) {
                        /* Update phone localStorage with merged data */
                        if (result.mergedNotes)      { lsSet(LS_NOTES,      result.mergedNotes); }
                        if (result.mergedHighlights) { lsSet(LS_HIGHLIGHTS, result.mergedHighlights); }
                        /* Snapshot the highlights as they stand right after this
                           sync, so future pending-counts only flag genuinely
                           new/changed highlights, not the same synced ones
                           over and over. */
                        lsSet(LS_SYNCED_HIGHLIGHTS, result.mergedHighlights || phoneGetHighlights());
                        /* Clear tombstones after successful sync */
                        lsSet(LS_TOMBSTONES, {});
                        /* Record sync timestamp */
                        localStorage.setItem(LS_LAST_SYNC, new Date().toISOString());
                        setSyncBanner("connected",
                            "\u2705 Sync complete! " +
                            result.imported + " item(s) updated. " +
                            '<button class="sync-banner-dismiss" onclick="dismissSyncBanner()">&#10005;</button>');
                        showToast("Synced with PC!", "success");
                    } else {
                        setSyncBanner("error",
                            "\u26A0\uFE0F Sync commit failed. " +
                            '<button class="sync-banner-btn" onclick="syncWithPc()">Retry</button>');
                    }
                });
            }

            /* Conflict resolution modal for sync (reuses import modal UI) */
            function showSyncConflictModal(data) {
                createImportModal();
                var modal = document.getElementById("import-modal");
                var summaryEl = document.getElementById("import-summary");
                var conflictsEl = document.getElementById("import-conflicts");
                var applyBtn = document.getElementById("import-apply-btn");

                var noteConflicts = data.conflicts.notes || [];
                var hlConflicts   = data.conflicts.highlights || [];

                summaryEl.innerHTML =
                    '<p class="import-line import-line-conflict">' +
                    '\u26A0\uFE0F ' + (noteConflicts.length + hlConflicts.length) +
                    ' conflict(s) found between your phone and PC notes. ' +
                    'Choose which version to keep for each:</p>';

                var conflictsHtml = "";
                noteConflicts.forEach(function (c) { conflictsHtml += renderNoteConflict(c); });
                hlConflicts.forEach(function (c)   { conflictsHtml += renderHighlightConflict(c); });
                conflictsEl.innerHTML = conflictsHtml;

                if (applyBtn) {
                    applyBtn.textContent = "Apply & Sync";
                    applyBtn.disabled = false;
                    applyBtn.onclick = function () {
                        var resolutions = {};
                        var rows = document.querySelectorAll(".import-conflict-row");
                        for (var i = 0; i < rows.length; i++) {
                            var row = rows[i];
                            var ref = row.getAttribute("data-ref");
                            var kind = row.getAttribute("data-kind");
                            var checked = row.querySelector('input[type="radio"]:checked');
                            var value = checked ? checked.value : "imported";
                            var key = (kind === "highlight") ? ("hl:" + ref) : ref;
                            resolutions[key] = value;
                        }
                        removeClass(modal, "is-open");
                        applySyncResult(data, resolutions);
                    };
                }

                addClass(modal, "is-open");
            }

            /* On page load: check PC reachability (needed everywhere, for
               Search visibility) but only show the sync banner itself on
               the Home page -- seeing "N unsynced notes" on every single
               page you navigate to was reported as frustrating/repetitive. */
            if (isPhoneMode) {
                checkPcReachable(function (reachable) {
                    pcReachable = reachable;
                    syncCheckDone = true;
                    setSearchVisibility(reachable);

                    if (!isHomePage) { return; }

                    if (reachable) {
                        var pending = countPendingNotes();
                        var neverSynced = !localStorage.getItem(LS_LAST_SYNC);
                        var alreadyShownThisSession = false;
                        try { alreadyShownThisSession = !!sessionStorage.getItem(SYNC_BANNER_SHOWN_KEY); } catch (e) { }

                        /* Always show when there's something actionable (pending
                           changes, or this phone has never synced yet). Only
                           suppress the repeat "nothing to do" banner once it's
                           already been shown this session. */
                        if (pending > 0 || neverSynced || !alreadyShownThisSession) {
                            showSyncAvailableBanner(pending, neverSynced);
                            if (pending === 0 && !neverSynced) {
                                try { sessionStorage.setItem(SYNC_BANNER_SHOWN_KEY, "1"); } catch (e) { }
                            }
                        }
                    } else {
                        var offlineAlreadyShown = false;
                        try { offlineAlreadyShown = !!sessionStorage.getItem(OFFLINE_BANNER_SHOWN_KEY); } catch (e) { }
                        if (!offlineAlreadyShown) {
                            setSyncBanner("offline",
                                "\uD83D\uDCF5 Offline mode \u2014 notes saved to your phone. " +
                                "Connect to your home WiFi to sync with your PC." +
                                ' &nbsp;<button class="sync-banner-dismiss" onclick="dismissSyncBanner()">&#10005;</button>');
                            try { sessionStorage.setItem(OFFLINE_BANNER_SHOWN_KEY, "1"); } catch (e) { }
                        }
                    }
                });
            }

        })();
    }

    /* ============================================================
       Update Check — Cross Icon Notification
       ============================================================
       On every page load (localhost only), silently checks GitHub
       for the latest commit SHA on main. If newer than the SHA
       baked into this page at generation time, shows a glowing
       gold cross icon in the header as an update notification.
       ============================================================ */

    if (isLocalhost) {
        (function () {

            /* The installed SHA is baked into each page by generate_bible.ps1
               as a meta tag: <meta name="kjv-sha" content="abc1234...">      */
            function getInstalledSha() {
                var metas = document.getElementsByTagName("meta");
                for (var i = 0; i < metas.length; i++) {
                    if (metas[i].getAttribute("name") === "kjv-sha") {
                        return metas[i].getAttribute("content") || "";
                    }
                }
                return "";
            }

            function showCrossIcon(latestSha, commitMsg) {
                var crosses = document.getElementsByClassName("update-cross");
                for (var i = 0; i < crosses.length; i++) {
                    crosses[i].title = "Update available! Click for details.";
                    addClass(crosses[i], "is-visible");
                    /* Store latest info for modal */
                    crosses[i].setAttribute("data-sha", latestSha);
                    crosses[i].setAttribute("data-msg", commitMsg || "New updates available.");
                }
            }

            function createUpdateModal() {
                if (document.getElementById("update-modal")) { return; }
                var modal = document.createElement("div");
                modal.id = "update-modal";
                modal.className = "update-modal";
                modal.innerHTML =
                    '<div class="update-modal-box">' +
                    '  <div class="update-modal-icon"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg></div>' +
                    '  <h2 class="update-modal-title">Update Available</h2>' +
                    '  <p class="update-modal-msg">A new version of KJV Strong\'s Bible is available.<br>Your Bible pages will be regenerated with the latest content.</p>' +
                    '  <p class="update-modal-commit" id="update-commit-msg"></p>' +
                    '  <div class="update-modal-progress" id="update-progress">' +
                    '    <div class="update-progress-bar-wrap"><div class="update-progress-bar" id="update-progress-bar"></div></div>' +
                    '    <span id="update-progress-detail">Starting update...</span>' +
                    '  </div>' +
                    '  <div class="update-modal-btns" id="update-btns">' +
                    '    <button class="update-now-btn" onclick="doUpdateNow()"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg> Update Now</button>' +
                    '    <button class="update-later-btn" onclick="closeUpdateModal()">Later</button>' +
                    '  </div>' +
                    '</div>';
                document.body.appendChild(modal);
            }

            window.openUpdateModal = function () {
                createUpdateModal();
                var modal = document.getElementById("update-modal");
                var msgEl = document.getElementById("update-commit-msg");
                var crosses = document.getElementsByClassName("update-cross");
                var msg = "";
                var sha = "";
                if (crosses.length > 0) {
                    msg = crosses[0].getAttribute("data-msg") || "";
                    sha = crosses[0].getAttribute("data-sha") || "";
                }
                if (msgEl) { msgEl.textContent = sha ? "Latest: " + sha.substring(0, 7) + (msg ? " — " + msg : "") : ""; }
                addClass(modal, "is-open");
            };

            window.closeUpdateModal = function () {
                var modal = document.getElementById("update-modal");
                if (modal) { removeClass(modal, "is-open"); }
            };

            window.doUpdateNow = function () {
                var btns = document.getElementById("update-btns");
                var progress = document.getElementById("update-progress");
                var bar = document.getElementById("update-progress-bar");
                var detail = document.getElementById("update-progress-detail");
                if (btns) { btns.style.display = "none"; }
                if (progress) { addClass(progress, "is-visible"); }

                var pollTimer = null;

                function poll() {
                    ajax("GET", pcServerOrigin + "/api/update-status", null, function (status, data) {
                        if (status !== 200 || !data) { return; }

                        if (bar) { bar.style.width = (data.percent || 0) + "%"; }
                        if (detail) { detail.textContent = data.detail || ""; }

                        if (data.done) {
                            if (pollTimer) { clearInterval(pollTimer); }
                            if (data.error) {
                                if (detail) { detail.textContent = "Update failed: " + (data.errorMessage || "Unknown error"); }
                                if (btns) { btns.style.display = "flex"; }
                                if (progress) { removeClass(progress, "is-visible"); }
                            } else {
                                if (detail) { detail.textContent = "Update complete! Reloading..."; }
                                if (bar) { bar.style.width = "100%"; }
                                /* Store the new SHA so that when the page reloads and
                                   re-checks GitHub, it won't show the badge again for
                                   a version we just installed. */
                                if (data.newSha) {
                                    try { sessionStorage.setItem("kjv-just-updated-sha", data.newSha); } catch (e) { }
                                }
                                setTimeout(function () {
                                    window.location.reload();
                                }, 1200);
                            }
                        }
                    });
                }

                /* Kick off the update — server responds immediately and
                   runs the actual work in a background job. We then poll
                   /api/update-status every 1.5s for live progress. */
                ajax("POST", pcServerOrigin + "/api/update", null, function (status, data) {
                    if (status === 200 && data && data.started) {
                        pollTimer = setInterval(poll, 1500);
                        poll(); /* immediate first check */
                    } else {
                        if (detail) { detail.textContent = "Could not start update."; }
                        if (btns) { btns.style.display = "flex"; }
                        if (progress) { removeClass(progress, "is-visible"); }
                    }
                });
            };

            /* Silently check GitHub for latest commit SHA */
            var installedSha = getInstalledSha();
            if (!installedSha) { return; } /* page not baked with SHA — skip */

            var xhr;
            try { xhr = new XMLHttpRequest(); }
            catch (e) { return; }

            xhr.open("GET", "https://api.github.com/repos/RonTurrentine/KJV-Strongs-EBook/commits/main", true);
            xhr.setRequestHeader("Accept", "application/vnd.github.v3+json");
            xhr.timeout = 8000;
            xhr.onreadystatechange = function () {
                if (xhr.readyState !== 4) { return; }
                if (xhr.status !== 200) { return; }
                try {
                    var data = JSON.parse(xhr.responseText);
                    var latestSha = data.sha || "";
                    var commitMsg = (data.commit && data.commit.message)
                        ? data.commit.message.split("\n")[0]
                        : "";
                    /* Suppress badge if this is the SHA we just updated to —
                       prevents the "update available" icon reappearing right
                       after an Update Now completes and the page reloads. */
                    var justUpdatedSha = "";
                    try { justUpdatedSha = sessionStorage.getItem("kjv-just-updated-sha") || ""; } catch (e) { }
                    if (justUpdatedSha && justUpdatedSha === latestSha) {
                        try { sessionStorage.removeItem("kjv-just-updated-sha"); } catch (e) { }
                        return; /* badge suppressed — we just installed this version */
                    }
                    if (latestSha && latestSha !== installedSha) {
                        showCrossIcon(latestSha, commitMsg);
                    }
                } catch (e) { /* parse error — ignore */ }
            };
            xhr.send(null);

        })();
    }

    /* ============================================================
       Download for Offline — Bulk Caching via Service Worker
       ============================================================
       Two independent downloads, each with their own button in the
       hamburger menu:
         - downloadOffline()  -> Bible chapter text only
         - downloadLexicon()  -> Strong's Hebrew + Greek dictionary only
       Only one runs at a time (starting one while the other is
       running just re-shows its progress rather than colliding).

       Progress is reported every 50 chapter pages / every 500
       dictionary pages, matching generate_bible.ps1's own build-time
       cadence. Uses the same modal chrome/CSS as the "Update
       Available" modal for a consistent look.

       Resume: the service worker checks its cache before re-fetching
       each URL, so re-running a download after an interruption (WiFi
       drop, tab closed, etc.) skips everything already saved and
       only fetches what's missing.
       ============================================================ */

    (function () {

        var bulkJob = null; /* { jobId, kind } or null when idle */
        var wakeLockRef = null;

        function requestWakeLock() {
            if (!("wakeLock" in navigator)) { return; }
            navigator.wakeLock.request("screen").then(function (lock) {
                wakeLockRef = lock;
            }).catch(function () { /* not critical — download still works without it */ });
        }

        function releaseWakeLock() {
            if (wakeLockRef) {
                try { wakeLockRef.release(); } catch (e) { }
                wakeLockRef = null;
            }
        }

        function pad4(n) {
            var s = "" + n;
            while (s.length < 4) { s = "0" + s; }
            return s;
        }

        function buildChapterUrlList() {
            var urls = [];
            /* The "Go To" navigation picker -- previously never included
               in the bulk download, so it always showed "hasn't been
               downloaded" even after a full successful download. */
            urls.push("/navigate.html");
            if (typeof BIBLE_DATA === "undefined") { return urls; }
            for (var i = 0; i < BIBLE_DATA.length; i++) {
                var book = BIBLE_DATA[i];
                for (var j = 0; j < book.chapters.length; j++) {
                    urls.push("/books/" + book.folder + "/" + (j + 1) + ".html");
                }
            }
            return urls;
        }

        function buildDictUrlList() {
            var urls = [];
            var i;
            /* Hebrew/Greek index pages -- same gap as navigate.html above,
               these are the pages the "Hebrew"/"Greek" nav buttons link to. */
            urls.push("/indexes/strongs-hebrew-index.html");
            urls.push("/indexes/strongs-greek-index.html");
            /* Strong's Hebrew: H0001-H8674, Greek: G0001-G5624. Any
               numbers without a generated page will simply 404 and be
               skipped — that doesn't throw off the percentage, since
               it's counted against attempts, not successes. */
            for (i = 1; i <= 8674; i++) {
                urls.push("/dict/hebrew/h" + pad4(i) + ".html");
            }
            for (i = 1; i <= 5624; i++) {
                urls.push("/dict/greek/g" + pad4(i) + ".html");
            }
            return urls;
        }

        function ensureModalShell() {
            if (document.getElementById("download-modal")) { return; }
            var modal = document.createElement("div");
            modal.id = "download-modal";
            modal.className = "update-modal";
            modal.innerHTML =
                '<div class="update-modal-box">' +
                '  <div class="update-modal-icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="18" viewBox="0 0 16 18" fill="currentColor"><path d="M7 0h2v10.5l3-3 1.4 1.4L8 13.3 2.6 8.9 4 7.5l3 3V0z"/><rect x="0" y="15" width="16" height="3"/></svg></div>' +
                '  <h2 class="update-modal-title" id="download-modal-title"></h2>' +
                '  <p class="update-modal-msg" id="download-modal-msg"></p>' +
                '  <div class="update-modal-progress is-visible" id="download-progress">' +
                '    <div class="update-progress-bar-wrap"><div class="update-progress-bar" id="download-progress-bar"></div></div>' +
                '    <span id="download-progress-detail">Starting download...</span>' +
                '  </div>' +
                '  <div class="update-modal-btns" id="download-btns"></div>' +
                '</div>';
            document.body.appendChild(modal);
        }

        /* Resets the modal's content for a fresh run — needed because the
           same modal shell is reused across chapters/dictionary/repeat runs. */
        function resetModalContent(title, message) {
            ensureModalShell();
            var titleEl = document.getElementById("download-modal-title");
            var msgEl = document.getElementById("download-modal-msg");
            var bar = document.getElementById("download-progress-bar");
            var detail = document.getElementById("download-progress-detail");
            var btns = document.getElementById("download-btns");
            if (titleEl) { titleEl.textContent = title; }
            if (msgEl) { msgEl.textContent = message; }
            if (bar) { bar.style.width = "0%"; }
            if (detail) { detail.textContent = "Starting download..."; }
            if (btns) {
                btns.innerHTML = '<button class="update-later-btn" id="download-cancel-btn" onclick="cancelBulkDownload()">Cancel</button>';
            }
        }

        function showDoneButton() {
            var btns = document.getElementById("download-btns");
            if (btns) {
                btns.innerHTML = '<button class="update-later-btn" onclick="closeDownloadModal()">Close</button>';
            }
        }

        window.closeDownloadModal = function () {
            var modal = document.getElementById("download-modal");
            if (modal) { removeClass(modal, "is-open"); }
        };

        window.cancelBulkDownload = function () {
            if (!bulkJob) { window.closeDownloadModal(); return; }
            var detail = document.getElementById("download-progress-detail");
            if (detail) { detail.textContent = "Cancelling..."; }
            if (navigator.serviceWorker && navigator.serviceWorker.controller) {
                navigator.serviceWorker.controller.postMessage({ type: "cancel-job", jobId: bulkJob.jobId });
            }
        };

        function runBulkDownload(kind, title, urls, reportEvery, onComplete, forceRefresh) {
            if (!("serviceWorker" in navigator)) {
                showToast("This browser doesn't support offline downloads.", "error");
                return;
            }
            if (!navigator.serviceWorker.controller) {
                showToast("Still setting up offline support — reload the page and try again in a moment.", "error");
                return;
            }

            var message = forceRefresh
                ? ("Re-downloading " + urls.length + " pages to make sure this device has the latest content " +
                   "(useful after editing notes on your PC). Stay connected to your home WiFi while this runs.")
                : ("Saving " + urls.length + " pages so this device can be used without WiFi. " +
                   "Stay connected to your home WiFi while this runs — leaving the network will interrupt the download " +
                   "(you can safely re-run it later to pick up where it left off).");

            if (bulkJob) {
                /* Something's already downloading — just re-show its modal
                   rather than starting a second, colliding job. */
                var existingModal = document.getElementById("download-modal");
                if (existingModal) { addClass(existingModal, "is-open"); }
                showToast("A download is already in progress.", "info");
                return;
            }

            resetModalContent(title, message);
            var modal = document.getElementById("download-modal");
            addClass(modal, "is-open");
            requestWakeLock();

            var bar = document.getElementById("download-progress-bar");
            var detail = document.getElementById("download-progress-detail");
            var total = urls.length;
            var jobId = kind + "-" + (new Date()).getTime();
            bulkJob = { jobId: jobId, kind: kind };

            var verb = forceRefresh ? "Refreshing" : "Downloading";
            var doneVerb = forceRefresh ? "Refresh complete! " : "Download complete! ";

            function setProgress(done, label) {
                var pct = total > 0 ? Math.floor((done / total) * 100) : 100;
                if (bar) { bar.style.width = pct + "%"; }
                if (detail) { detail.textContent = label + " (" + pct + "%)"; }
            }

            function onMessage(event) {
                var data = event.data;
                if (!data || data.type !== "cache-progress" || data.jobId !== jobId) { return; }

                if (data.cancelled) {
                    navigator.serviceWorker.removeEventListener("message", onMessage);
                    releaseWakeLock();
                    bulkJob = null;
                    setProgress(data.done, "Cancelled — " + data.done + " of " + total + " saved");
                    showDoneButton();
                    return;
                }

                setProgress(data.done, verb + ": " + data.done + " of " + total);

                if (data.complete) {
                    navigator.serviceWorker.removeEventListener("message", onMessage);
                    releaseWakeLock();
                    bulkJob = null;
                    setProgress(total, doneVerb + total + " pages saved for offline use");
                    showDoneButton();
                    if (typeof onComplete === "function") { onComplete(); }
                }
            }

            navigator.serviceWorker.addEventListener("message", onMessage);
            navigator.serviceWorker.controller.postMessage({
                type: "cache-urls", urls: urls, jobId: jobId, reportEvery: reportEvery, forceRefresh: !!forceRefresh
            });
        }

        function loadBibleDataIfNeeded(callback) {
            if (typeof BIBLE_DATA !== "undefined") { callback(); return; }
            var existing = document.getElementById("bible-data-script");
            if (existing) {
                existing.addEventListener("load", callback);
                return;
            }
            var script = document.createElement("script");
            script.id = "bible-data-script";
            script.src = "/js/bible-data.js";
            script.onload = callback;
            script.onerror = function () {
                showToast("Could not load Bible book/chapter list — try reloading the page and trying again.", "error");
            };
            document.head.appendChild(script);
        }

        window.downloadOffline = function (kind, onComplete) {
            if (kind === "lexicon") {
                runBulkDownload("dictionary", "Downloading Lexicon", buildDictUrlList(), 500, onComplete);
            } else {
                loadBibleDataIfNeeded(function () {
                    runBulkDownload("chapters", "Downloading Bible Text", buildChapterUrlList(), 50, onComplete);
                });
            }
        };

        /* "Refresh Offline Content" — re-downloads everything already
           cached, overwriting it regardless of whether it's already
           present. Needed because "already cached" and "correctly up
           to date" aren't the same thing: e.g. after editing/rebaking
           notes on the PC, a phone's offline copy of that chapter page
           keeps showing the old baked note forever otherwise, since
           the normal download only ever fills in what's MISSING, never
           corrects what's already there but stale. */
        window.refreshOfflineContent = function () {
            loadBibleDataIfNeeded(function () {
                runBulkDownload("chapters", "Refreshing Bible Text", buildChapterUrlList(), 50, function () {
                    runBulkDownload("dictionary", "Refreshing Lexicon", buildDictUrlList(), 500, null, true);
                }, true);
            });
        };

    })();

    /* ============================================================
       One-time Phone Setup Wizard
       ============================================================
       On the very first Home-page visit in phone mode, offers to do
       everything in one guided flow: download Bible text, download
       the Hebrew/Greek lexicon, then pull down any existing PC notes
       — instead of the user having to discover and run three separate
       menu items themselves. Shown at most once automatically (tracked
       via a dedicated localStorage flag); the existing "Download Bible
       Text for Offline" / "Download Lexicon for Offline" menu rows
       remain available afterward for anyone who said "Not Now" or
       wants to re-run things later (e.g. after clearing site data).
       ============================================================ */

    var PHONE_SETUP_PROMPTED_KEY = "kjv-phone-setup-prompted";

    function ensurePhoneSetupModal() {
        if (document.getElementById("phone-setup-modal")) { return; }
        var modal = document.createElement("div");
        modal.id = "phone-setup-modal";
        modal.className = "update-modal";
        modal.innerHTML =
            '<div class="update-modal-box">' +
            '  <div class="update-modal-icon"><svg xmlns="http://www.w3.org/2000/svg" width="16" height="18" viewBox="0 0 16 18" fill="currentColor"><path d="M7 0h2v10.5l3-3 1.4 1.4L8 13.3 2.6 8.9 4 7.5l3 3V0z"/><rect x="0" y="15" width="16" height="3"/></svg></div>' +
            '  <h2 class="update-modal-title">Set Up This Phone for Offline Use</h2>' +
            '  <p class="update-modal-msg">This will download the entire Bible text, the Hebrew/Greek lexicon, ' +
            '  and any existing notes/highlights from your PC &mdash; about <strong>163 MB</strong> total, ' +
            '  typically taking several minutes depending on your home WiFi speed.</p>' +
            '  <p class="update-modal-msg">This is a <strong>one-time setup</strong>. Once it finishes, this phone ' +
            '  can read and study completely offline, anytime, and will automatically stay in sync with your PC ' +
            '  whenever you\'re back on your home WiFi with the PC app running. If you get a new phone or reinstall ' +
            '  the app, you can repeat this setup again from the &#9776; menu.</p>' +
            '  <div class="update-modal-btns">' +
            '    <button class="update-now-btn" onclick="confirmPhoneSetup()">Set Up Now</button>' +
            '    <button class="update-later-btn" onclick="dismissPhoneSetup()">Not Now</button>' +
            '  </div>' +
            '</div>';
        document.body.appendChild(modal);
    }

    window.startPhoneSetup = function () {
        ensurePhoneSetupModal();
        var modal = document.getElementById("phone-setup-modal");
        addClass(modal, "is-open");
    };

    window.dismissPhoneSetup = function () {
        var modal = document.getElementById("phone-setup-modal");
        if (modal) { removeClass(modal, "is-open"); }
    };

    window.confirmPhoneSetup = function () {
        window.dismissPhoneSetup();
        /* Chain: Bible text -> Lexicon -> pull down existing PC notes.
           Each step reuses the exact same download machinery (progress
           modal, cancel, resume-on-interruption) as the manual menu
           items — this is just three of those, run back to back. */
        window.downloadOffline("bible", function () {
            window.downloadOffline("lexicon", function () {
                if (typeof window.syncWithPc === "function") { window.syncWithPc(); }
            });
        });
    };

    if (isPhoneMode && isHomePage) {
        var alreadyPrompted = false;
        try { alreadyPrompted = !!localStorage.getItem(PHONE_SETUP_PROMPTED_KEY); } catch (e) { }
        if (!alreadyPrompted) {
            try { localStorage.setItem(PHONE_SETUP_PROMPTED_KEY, "1"); } catch (e) { }
            window.startPhoneSetup();
        }
    }

    /* "Sync Phone via QR Code" is how the PC side initiates a phone
       connection — it doesn't make sense to show once you're already
       running on the phone itself. It has no id in the generated HTML
       (unlike other rows), so target it by its onclick attribute
       instead of touching generate_bible.ps1 and regenerating every
       page across the whole site for one menu row. */
    if (isPhoneMode) {
        var qrSyncRow = document.querySelector('[onclick="syncViaQr()"]');
        if (qrSyncRow) { qrSyncRow.style.display = "none"; }
    }

    /* "Download for Offline" only makes sense on the phone -- the PC
       already IS the server, with instant zero-latency access to
       everything on disk, so there's no scenario where the PC itself
       needs to work "offline" from itself. Mirror image of the QR-row
       hiding above (that one only makes sense on the PC side). Hides
       the whole section (not just the two rows), so the "OFFLINE
       ACCESS" label doesn't end up floating alone with nothing under it. */
    if (isLocalhost) {
        var offlineBibleRow = document.getElementById("offline-bible-row");
        var offlineSection = offlineBibleRow ? offlineBibleRow.closest(".settings-section") : null;
        if (offlineSection) { offlineSection.style.display = "none"; }
    }

    /* ============================================================
       Notes Manager Page
       ============================================================
       Browsable, filterable, editable list of every note across the
       whole Bible (OT -> NT order). Filters: by tag (AND logic across
       multiple selected tags) and by Book/Testament/Category (reusing
       the same category scheme as the Search page, for familiarity).
       Editing reuses the existing per-verse note modal (openNoteModal)
       rather than building a separate editing UI.
       ============================================================ */
    if (isNotesManagerPage) {
        (function () {

            if (!canTakeNotes) {
                var statusElEarly = document.getElementById("notes-manager-status");
                if (statusElEarly) { statusElEarly.textContent = "Notes aren't available in this mode."; }
                return;
            }

            /* Same book-number ranges as the Search page's category
               scheme, duplicated here to keep this page self-contained
               rather than reaching into search.js. */
            var NM_CATEGORIES = {
                torah:         [1, 2, 3, 4, 5],
                historical:    [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
                poetic:        [18, 19, 20, 21, 22],
                prophetic:     [23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39],
                gospels:       [40, 41, 42, 43],
                acts:          [44],
                paul_church:   [45, 46, 47, 48, 49, 50, 51, 52, 53],
                paul_pastoral: [54, 55, 56, 57],
                general:       [58, 59, 60, 61, 62, 63, 64, 65],
                revelation:    [66]
            };

            var nmAllNotes = [];          /* flattened, sorted note records with computed metadata */
            var nmBookLookup = {};        /* abbr -> { num, folder, name } */
            var nmSelectedTags = {};      /* tag (lowercase) -> true, for currently-selected filter tags */
            var nmSelectedBookIds = null; /* null = no book/category filter active; else array of book numbers */

            function nmLoadBibleDataIfNeeded(callback) {
                if (typeof BIBLE_DATA !== "undefined") { callback(); return; }
                var existing = document.getElementById("nm-bible-data-script");
                if (existing) { existing.addEventListener("load", callback); return; }
                var script = document.createElement("script");
                script.id = "nm-bible-data-script";
                script.src = "/js/bible-data.js";
                script.onload = callback;
                script.onerror = function () {
                    showToast("Could not load book/chapter data — try reloading the page.", "error");
                };
                document.head.appendChild(script);
            }

            function buildBookLookup() {
                if (typeof BIBLE_DATA === "undefined") { return; }
                for (var i = 0; i < BIBLE_DATA.length; i++) {
                    var b = BIBLE_DATA[i];
                    nmBookLookup[b.abbr] = { num: b.num, folder: b.folder, name: b.name };
                }
            }

            function parseRef(ref) {
                var parts = ref.split(".");
                return {
                    bookAbbr: parts[0] || "",
                    chapter: parseInt(parts[1], 10) || 0,
                    verse: parseInt(parts[2], 10) || 0
                };
            }

            function loadAllNotesAndHighlights(callback) {
                if (isPhoneMode) {
                    callback(phoneGetNotes(), phoneGetHighlights());
                } else {
                    var notesResult = null;
                    var highlightsResult = null;
                    var pending = 2;
                    function maybeDone() {
                        pending--;
                        if (pending === 0) { callback(notesResult || {}, highlightsResult || {}); }
                    }
                    ajax("GET", pcServerOrigin + "/api/notes", null, function (status, data) {
                        notesResult = (status === 200 && data) ? data : {};
                        normalizeNotesTagsInPlace(notesResult);
                        maybeDone();
                    });
                    ajax("GET", pcServerOrigin + "/api/highlights", null, function (status, data) {
                        highlightsResult = (status === 200 && data) ? data : {};
                        maybeDone();
                    });
                }
            }

            function buildNoteRecords(notesObj, highlightsObj) {
                var records = [];
                var seenRefs = {};
                var ref;

                /* Every ref that has a note (text and/or tags) */
                for (ref in notesObj) {
                    if (!notesObj.hasOwnProperty(ref)) { continue; }
                    var n = notesObj[ref];
                    var text = n.text || "";
                    var tags = normalizeTagsArray(n.tags);
                    var color = highlightsObj ? (highlightsObj[ref] || null) : null;
                    /* Skip entries with nothing at all (shouldn't normally
                       happen, but be defensive rather than show blank cards) */
                    if (!text && tags.length === 0 && !color) { continue; }
                    seenRefs[ref] = true;
                    records.push(makeRecord(ref, text, tags, color));
                }

                /* Every ref that's highlighted but has no note entry at
                   all -- previously these never showed up here. */
                for (ref in highlightsObj) {
                    if (!highlightsObj.hasOwnProperty(ref) || seenRefs[ref]) { continue; }
                    var hlColor = highlightsObj[ref];
                    if (!hlColor) { continue; }
                    records.push(makeRecord(ref, "", [], hlColor));
                }

                records.sort(function (a, b) {
                    if (a.bookNum !== b.bookNum) { return a.bookNum - b.bookNum; }
                    if (a.chapter !== b.chapter) { return a.chapter - b.chapter; }
                    return a.verse - b.verse;
                });
                return records;
            }

            function makeRecord(ref, text, tags, color) {
                var parsed = parseRef(ref);
                var bookInfo = nmBookLookup[parsed.bookAbbr] || { num: 999, folder: "", name: parsed.bookAbbr };
                return {
                    ref: ref,
                    text: text,
                    tags: tags,
                    color: color || null,
                    bookAbbr: parsed.bookAbbr,
                    bookName: bookInfo.name,
                    bookNum: bookInfo.num,
                    folder: bookInfo.folder,
                    chapter: parsed.chapter,
                    verse: parsed.verse
                };
            }

            function collectAllTagsFromRecords(records) {
                var seen = {};
                for (var i = 0; i < records.length; i++) {
                    var tags = records[i].tags || [];
                    for (var j = 0; j < tags.length; j++) {
                        var key = normalizeTagKey(tags[j]);
                        if (!seen[key]) { seen[key] = tags[j]; }
                    }
                }
                return seen;
            }

            function renderTagCloud(tagsMap) {
                var cloud = document.getElementById("nm-tag-cloud");
                if (!cloud) { return; }
                cloud.innerHTML = "";
                var keys = [];
                var k;
                for (k in tagsMap) { if (tagsMap.hasOwnProperty(k)) { keys.push(k); } }
                keys.sort();
                if (keys.length === 0) {
                    cloud.innerHTML = '<span class="nm-tag-empty">No tags yet — add some from any note\u2019s editor.</span>';
                    return;
                }
                for (var i = 0; i < keys.length; i++) {
                    (function (key, label) {
                        var btn = document.createElement("button");
                        btn.className = "nm-tag-btn";
                        btn.setAttribute("data-tag", key);
                        btn.appendChild(document.createTextNode(label));
                        btn.onclick = function () { window.nmToggleTag(key, btn); };
                        cloud.appendChild(btn);
                    })(keys[i], tagsMap[keys[i]]);
                }
            }

            window.nmToggleTag = function (key, btnEl) {
                if (nmSelectedTags[key]) {
                    delete nmSelectedTags[key];
                    if (btnEl) { removeClass(btnEl, "is-selected"); }
                } else {
                    nmSelectedTags[key] = true;
                    if (btnEl) { addClass(btnEl, "is-selected"); }
                }
                nmRenderList();
            };

            function getSelectedCategoryBookIds() {
                var checks = document.getElementsByClassName("nm-cat-check");
                var ids = [];
                var any = false;
                var i;
                for (i = 0; i < checks.length; i++) {
                    if (checks[i].checked) {
                        any = true;
                        var cat = checks[i].value;
                        if (NM_CATEGORIES[cat]) { ids = ids.concat(NM_CATEGORIES[cat]); }
                    }
                }
                var bookSel = document.getElementById("nm-book-select");
                if (bookSel && bookSel.value) {
                    any = true;
                    /* A specific book takes precedence over any category
                       checkboxes also selected -- narrows to just that book. */
                    ids = [parseInt(bookSel.value, 10)];
                }
                return any ? ids : null;
            }

            window.nmMasterChecked = function (which) {
                var group = (which === "ot")
                    ? ["torah", "historical", "poetic", "prophetic"]
                    : ["gospels", "acts", "paul_church", "paul_pastoral", "general", "revelation"];
                var master = document.getElementById("nm-cat-" + which + "-master");
                var checks = document.getElementsByClassName("nm-cat-check");
                for (var i = 0; i < checks.length; i++) {
                    if (group.indexOf(checks[i].value) !== -1) { checks[i].checked = master.checked; }
                }
                window.nmApplyFilters();
            };

            window.nmApplyFilters = function () {
                nmSelectedBookIds = getSelectedCategoryBookIds();
                nmRenderList();
            };

            window.nmClearFilters = function () {
                var checks = document.getElementsByClassName("nm-cat-check");
                for (var i = 0; i < checks.length; i++) { checks[i].checked = false; }
                var otMaster = document.getElementById("nm-cat-ot-master");
                var ntMaster = document.getElementById("nm-cat-nt-master");
                if (otMaster) { otMaster.checked = false; }
                if (ntMaster) { ntMaster.checked = false; }
                var bookSel = document.getElementById("nm-book-select");
                if (bookSel) { bookSel.value = ""; }
                nmSelectedTags = {};
                var tagBtns = document.getElementsByClassName("nm-tag-btn");
                for (var j = 0; j < tagBtns.length; j++) { removeClass(tagBtns[j], "is-selected"); }
                nmSelectedBookIds = null;
                nmRenderList();
            };

            function populateBookSelect() {
                var sel = document.getElementById("nm-book-select");
                if (!sel || typeof BIBLE_DATA === "undefined") { return; }
                for (var i = 0; i < BIBLE_DATA.length; i++) {
                    var opt = document.createElement("option");
                    opt.value = BIBLE_DATA[i].num;
                    opt.appendChild(document.createTextNode(BIBLE_DATA[i].name));
                    sel.appendChild(opt);
                }
            }

            function buildNoteCard(rec) {
                var card = document.createElement("div");
                card.className = "nm-card";

                var header = document.createElement("div");
                header.className = "nm-card-header";

                var refWrap = document.createElement("span");
                refWrap.className = "nm-card-ref-wrap";

                if (rec.color) {
                    var swatch = document.createElement("span");
                    swatch.className = "nm-card-color-swatch nm-hl-" + rec.color;
                    swatch.title = rec.color.charAt(0).toUpperCase() + rec.color.slice(1) + " highlight";
                    refWrap.appendChild(swatch);
                }

                var refLink = document.createElement("a");
                refLink.className = "nm-card-ref";
                refLink.href = "/books/" + rec.folder + "/" + rec.chapter + ".html#verse-" + rec.verse;
                refLink.appendChild(document.createTextNode(rec.bookName + " " + rec.chapter + ":" + rec.verse));
                refWrap.appendChild(refLink);

                header.appendChild(refWrap);

                var editBtn = document.createElement("button");
                editBtn.className = "btn nm-card-edit-btn";
                editBtn.appendChild(document.createTextNode("Edit"));
                editBtn.onclick = function () { window.openNoteModal(rec.ref); };
                header.appendChild(editBtn);

                card.appendChild(header);

                if (rec.tags && rec.tags.length > 0) {
                    var tagsRow = document.createElement("div");
                    tagsRow.className = "nm-card-tags";
                    for (var i = 0; i < rec.tags.length; i++) {
                        var badge = document.createElement("span");
                        badge.className = "nm-card-tag-badge";
                        badge.appendChild(document.createTextNode(rec.tags[i]));
                        tagsRow.appendChild(badge);
                    }
                    card.appendChild(tagsRow);
                }

                var textEl = document.createElement("p");
                if (rec.text) {
                    textEl.className = "nm-card-text";
                    textEl.innerHTML = linkifyVerseRefs(escapeHtml(rec.text));
                } else {
                    textEl.className = "nm-card-text nm-card-text-empty";
                    textEl.appendChild(document.createTextNode("No note text \u2014 highlighted and/or tagged only."));
                }
                card.appendChild(textEl);

                return card;
            }

            function nmRenderList() {
                var listEl = document.getElementById("notes-manager-list");
                var countEl = document.getElementById("nm-result-count");
                if (!listEl) { return; }

                var selectedTagKeys = [];
                var k;
                for (k in nmSelectedTags) { if (nmSelectedTags.hasOwnProperty(k)) { selectedTagKeys.push(k); } }

                var filtered = [];
                var i;
                for (i = 0; i < nmAllNotes.length; i++) {
                    var rec = nmAllNotes[i];

                    if (nmSelectedBookIds && nmSelectedBookIds.indexOf(rec.bookNum) === -1) { continue; }

                    if (selectedTagKeys.length > 0) {
                        var recTagKeys = {};
                        for (var t = 0; t < rec.tags.length; t++) { recTagKeys[normalizeTagKey(rec.tags[t])] = true; }
                        var matchesAll = true;
                        for (var s = 0; s < selectedTagKeys.length; s++) {
                            if (!recTagKeys[selectedTagKeys[s]]) { matchesAll = false; break; }
                        }
                        if (!matchesAll) { continue; }
                    }

                    filtered.push(rec);
                }

                if (countEl) {
                    countEl.textContent = filtered.length + " note" + (filtered.length !== 1 ? "s" : "");
                }

                listEl.innerHTML = "";
                if (filtered.length === 0) {
                    listEl.innerHTML = '<p class="nm-empty">No notes match the current filters.</p>';
                    return;
                }

                for (i = 0; i < filtered.length; i++) {
                    listEl.appendChild(buildNoteCard(filtered[i]));
                }
            }
            window.nmRenderList = nmRenderList;

            function refreshOneRecord(ref) {
                loadAllNotesAndHighlights(function (notesObj, highlightsObj) {
                    nmAllNotes = buildNoteRecords(notesObj, highlightsObj);
                    renderTagCloud(collectAllTagsFromRecords(nmAllNotes));
                    nmRenderList();
                });
            }
            window.nmRefreshAfterSave = refreshOneRecord;

            function initNotesManager() {
                var statusEl = document.getElementById("notes-manager-status");
                nmLoadBibleDataIfNeeded(function () {
                    buildBookLookup();
                    populateBookSelect();
                    loadAllNotesAndHighlights(function (notesObj, highlightsObj) {
                        nmAllNotes = buildNoteRecords(notesObj, highlightsObj);
                        if (statusEl) { statusEl.style.display = "none"; }
                        renderTagCloud(collectAllTagsFromRecords(nmAllNotes));
                        nmRenderList();
                    });
                });
            }

            initNotesManager();

        })();
    }

    if (!isChapterPage) { return; }

    if (canTakeNotes) {
        /* Add is-localhost to body — CSS uses this to show pencil buttons */
        addClass(document.body, "is-localhost");

        if (isLocalhost) {
            /* PC mode: Start Kindle status polling every 5 seconds */
            pollKindleStatus();
            setInterval(pollKindleStatus, 5000);

            /* Load highlights from server and apply to current page */
            ajax("GET", pcServerOrigin + "/api/highlights", null, function (status, data) {
                if (status === 200 && data) {
                    highlights = data;
                    for (var ref in highlights) {
                        if (!highlights.hasOwnProperty(ref)) { continue; }
                        var parts = ref.split(".");
                        if (parts[0] === osisBook && parseInt(parts[1], 10) === chapterNum) {
                            applyHighlightClass("verse-" + parts[2], highlights[ref]);
                        }
                    }
                }
            });
        } else if (isPhoneMode) {
            /* Phone mode: load highlights from localStorage */
            var phoneHighs = phoneGetHighlights();
            highlights = phoneHighs;
            for (var pRef in phoneHighs) {
                if (!phoneHighs.hasOwnProperty(pRef)) { continue; }
                var pParts = pRef.split(".");
                if (pParts[0] === osisBook && parseInt(pParts[1], 10) === chapterNum) {
                    applyHighlightClass("verse-" + pParts[2], phoneHighs[pRef]);
                }
            }

            /* Also show phone notes from localStorage (baked notes won't be present
               since the PC hasn't baked phone-only notes into HTML yet) */
            var phoneNs = phoneGetNotes();
            for (var pNRef in phoneNs) {
                if (!phoneNs.hasOwnProperty(pNRef)) { continue; }
                var pNParts = pNRef.split(".");
                if (pNParts[0] === osisBook && parseInt(pNParts[1], 10) === chapterNum) {
                    updateVerseIndicator(pNRef, true);
                    refreshBakedNote(pNRef, phoneNs[pNRef].text);
                }
            }
        }

        /* Mark note buttons that have existing baked notes */
        var noteDivs = document.getElementsByTagName("div");
        for (var i = 0; i < noteDivs.length; i++) {
            var div = noteDivs[i];
            if (div.className && div.className.indexOf("verse-note") !== -1
                && div.id && div.innerHTML && div.innerHTML.replace(/\s/g, "") !== "") {
                var idMatch = div.id.match(/note-verse-(\d+)/);
                if (idMatch) {
                    var vNum = idMatch[1];
                    var vp = document.getElementById("verse-" + vNum);
                    if (vp) {
                        var btns = vp.getElementsByTagName("button");
                        for (var j = 0; j < btns.length; j++) {
                            if (btns[j].className.indexOf("note-btn") !== -1) {
                                addClass(btns[j], "has-note");
                            }
                        }
                    }
                }
            }
        }

        /* Show sync button if present */
        var syncBtns = document.getElementsByClassName
            ? document.getElementsByClassName("sync-btn")
            : [];
        if (syncBtns.length === 0) {
            var allBtns = document.getElementsByTagName("button");
            for (var k = 0; k < allBtns.length; k++) {
                if (allBtns[k].className.indexOf("sync-btn") !== -1) {
                    addClass(allBtns[k], "is-localhost");
                }
            }
        } else {
            for (var m = 0; m < syncBtns.length; m++) {
                addClass(syncBtns[m], "is-localhost");
            }
        }

    } else {
        /* File:// or Kindle mode: hide all pencil buttons, show only baked notes */
        var allButtons = document.getElementsByTagName("button");
        for (var n = 0; n < allButtons.length; n++) {
            if (allButtons[n].className.indexOf("note-btn") !== -1) {
                addClass(allButtons[n], "notes-hidden");
            }
        }
    }

})();
