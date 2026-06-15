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

        box.appendChild(modalTitle);
        box.appendChild(modalVerse);
        box.appendChild(modalTextarea);
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

    function closeNoteModal() {
        if (modal) { removeClass(modal, "is-open"); }
        currentRef = "";
    }
    window.closeNoteModal = closeNoteModal;

    /* -- Save note ----------------------------------------------  */

    function saveNote() {
        var text = modalTextarea.value;
        if (!text || !currentRef) {
            showToast("Note is empty", "error");
            return;
        }

        var ref = currentRef;
        var payload = JSON.stringify({ ref: ref, text: text });

        ajax("POST", "/api/notes", payload, function (status, data) {
            if (status === 200 && data && data.ok) {
                closeNoteModal();
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
                    closeNoteModal();
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
            + escapeHtml(text)
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

    /* ============================================================
       Sync to Kindle
       ============================================================ */

    window.syncToKindle = function () {
        if (!isLocalhost) { return; }
        showToast("Syncing to Kindle...", "");

        ajax("POST", "/api/sync-kindle", null, function (status, data) {
            if (status === 200 && data) {
                var msg = "Pushed " + (data.pushed || 0) + " file(s) to Kindle";
                showToast(msg, "success");
            } else {
                var errMsg = (data && data.error) ? data.error : "Sync failed";
                showToast(errMsg, "error");
            }
        });
    };

    /* ============================================================
       Initialization
       ============================================================ */

    if (!isChapterPage) { return; }

    if (isLocalhost) {
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
