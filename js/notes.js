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

    /* -- Toast notification -------------------------------------  */

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
    var HL_COLORS = ["yellow", "green", "red", "blue"];
    var HL_CLASSES = { yellow: "hl-yellow", green: "hl-green", red: "hl-red", blue: "hl-blue" };

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
        if (!isLocalhost) { return; }

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
        modalDeleteBtn.style.display = "none";

        /* Set up highlight state for this verse */
        var existingColor = highlights[ref] || null;
        selectedColor = existingColor;
        originalColor = existingColor;
        updatePickerUI(selectedColor);
        previewHighlight(ref, selectedColor);

        /* Fetch existing note from server */
        ajax("GET", "/api/notes", null, function (status, data) {
            if (status === 200 && data && data[ref]) {
                modalTextarea.value = data[ref].text || "";
                modalDeleteBtn.style.display = "inline-block";
            }
            /* Show modal */
            addClass(modal, "is-open");
            modalTextarea.focus();
        });
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

        if (!ref) { return; }

        /* Save highlight first (independent of note) */
        var hlColor = selectedColor;
        var hlOriginal = originalColor;
        var hlChanged = (hlColor !== hlOriginal);

        if (hlChanged) {
            if (hlColor) {
                var hlPayload = JSON.stringify({ ref: ref, color: hlColor });
                ajax("POST", "/api/highlights", hlPayload, function (st) {
                    if (st === 200) {
                        highlights[ref] = hlColor;
                    }
                });
            } else {
                ajax("DELETE", "/api/highlights/" + encodeURIComponent(ref), null, function (st) {
                    if (st === 200) {
                        delete highlights[ref];
                    }
                });
            }
        }

        if (!text) {
            /* No note text — just close, highlight already saved above */
            closeNoteModal(true);
            if (hlChanged) {
                showToast("Highlight updated", "success");
            } else {
                showToast("Note is empty", "error");
            }
            return;
        }

        var payload = JSON.stringify({ ref: ref, text: text });

        ajax("POST", "/api/notes", payload, function (status, data) {
            if (status === 200 && data && data.ok) {
                closeNoteModal(true);
                updateVerseIndicator(ref, true);
                refreshBakedNote(ref, text);
                showToast("Note saved", "success");
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

        ajax("DELETE", "/api/notes/" + encodeURIComponent(ref), null,
            function (status, data) {
                if (status === 200 && data && data.ok) {
                    closeNoteModal(true);
                    updateVerseIndicator(ref, false);
                    clearBakedNote(ref);
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

        ajax("POST", "/api/rebake", null, function (status, data) {
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

        ajax("POST", "/api/sync-kindle", null, function (status, data) {
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
        ajax("POST", "/api/test-sync", null, function (status, data) {
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
        ajax("GET", "/api/kindle-status", null, function (status, data) {
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
                    '  <div class="update-modal-progress" id="update-progress">Updating... this may take a few minutes.<br><br><span id="update-progress-detail">Downloading latest files...</span></div>' +
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
                if (btns) { btns.style.display = "none"; }
                if (progress) { addClass(progress, "is-visible"); }

                ajax("POST", "/api/update", null, function (status, data) {
                    var detail = document.getElementById("update-progress-detail");
                    if (status === 200 && data && data.success) {
                        if (detail) { detail.textContent = "Update complete! Reloading..."; }
                        setTimeout(function () {
                            window.location.reload();
                        }, 1500);
                    } else {
                        if (detail) { detail.textContent = "Update failed: " + (data && data.error ? data.error : "Unknown error"); }
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
                    if (latestSha && latestSha !== installedSha) {
                        showCrossIcon(latestSha, commitMsg);
                    }
                } catch (e) { /* parse error — ignore */ }
            };
            xhr.send(null);

        })();
    }

    if (!isChapterPage) { return; }

    if (isLocalhost) {
        /* Add is-localhost to body — CSS uses this to show pencil buttons and sync btn */
        addClass(document.body, "is-localhost");

        /* Start Kindle status polling every 5 seconds */
        pollKindleStatus();
        setInterval(pollKindleStatus, 5000);

        /* Load highlights from server and apply to current page */
        ajax("GET", "/api/highlights", null, function (status, data) {
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

        /* PC study mode: pencil buttons are active, show sync button */

        /* Mark note buttons that have existing baked notes */
        var noteDivs = document.getElementsByTagName("div");
        for (var i = 0; i < noteDivs.length; i++) {
            var div = noteDivs[i];
            if (div.className && div.className.indexOf("verse-note") !== -1
                && div.id && div.innerHTML && div.innerHTML.replace(/\s/g, "") !== "") {
                /* This verse has a baked note — mark its button */
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
        /* Fallback for old browsers without getElementsByClassName */
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
        /* File:// mode: hide all pencil buttons, show only baked notes */
        var allButtons = document.getElementsByTagName("button");
        for (var n = 0; n < allButtons.length; n++) {
            if (allButtons[n].className.indexOf("note-btn") !== -1) {
                addClass(allButtons[n], "notes-hidden");
            }
        }
    }

})();
