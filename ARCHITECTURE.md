# KJV Strong's Converter - Architecture & Design

## Overview

This document defines the technical architecture for converting OSIS XML Bible with Strong's references into an interactive HTML/EPUB suitable for Kindle Fire (Android 2.x).

---

## File Organization Structure

```
kjv-strongs-html/
│
├── index.html                    # Main entry point / book list
├── css/
│   └── style.css                 # Unified dark-mode stylesheet
│
├── books/                        # Bible text (chapter-based)
│   ├── ot/
│   │   ├── 01-genesis/
│   │   │   ├── gen_ch01.html     # Genesis 1
│   │   │   ├── gen_ch02.html
│   │   │   └── ...
│   │   ├── 02-exodus/
│   │   └── ...
│   └── nt/
│       ├── 40-matthew/
│       └── ...
│
├── dict/                         # Strong's dictionary entries
│   ├── hebrew/
│   │   ├── h0001.html            # H0001 entry
│   │   ├── h0002.html
│   │   └── ... (up to h8674)
│   │
│   └── greek/
│       ├── g0001.html            # G0001 entry
│       ├── g0002.html
│       └── ... (up to g5624)
│
├── indexes/                      # Navigation & reference tools
│   ├── strongs-hebrew-index.html # All H#### entries sorted
│   ├── strongs-greek-index.html  # All G#### entries sorted
│   └── english-concordance.html  # Words sorted A-Z with verse counts
│
└── user/                         # User-specific data (bookmarks, notes)
    ├── bookmarks.json            # Last page read
    └── personal-notes.json       # Custom notes & cross-refs
```

### Path Examples
- Genesis 1: `books/ot/01-genesis/gen_ch01.html`
- Strong's H0430 (God): `dict/hebrew/h0430.html`
- Strong's G3962 (Father): `dict/greek/g3962.html`
- Hebrew Index: `indexes/strongs-hebrew-index.html`
- English Concordance: `indexes/english-concordance.html`

---

## Chapter HTML Format

### File Naming Convention
Books: `{book_num}-{book_name}/`  
Chapters: `{abbrev}_ch{chapter}.html`

Examples:
- `01-genesis/gen_ch01.html`
- `02-exodus/exo_ch01.html`
- `40-matthew/mat_ch01.html`
- `66-revelation/rev_ch22.html`

### Chapter Page Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Genesis 1</title>
  <link rel="stylesheet" href="../../css/style.css">
</head>
<body class="bible-text">
  
  <!-- Navigation Header -->
  <nav class="chapter-nav">
    <div class="nav-info">
      <h1 class="book-chapter">Genesis 1</h1>
    </div>
    <div class="nav-buttons">
      <a href="../../index.html" class="btn">Books</a>
      <a href="gen_ch00.html" class="btn">← Previous</a>
      <a href="gen_ch02.html" class="btn">Next →</a>
      <a href="../../indexes/strongs-hebrew-index.html" class="btn">H Index</a>
      <a href="../../indexes/strongs-greek-index.html" class="btn">G Index</a>
      <a href="../../indexes/english-concordance.html" class="btn">Concordance</a>
    </div>
  </nav>

  <!-- Chapter Content -->
  <main class="chapter-content">
    <h2>Chapter 1</h2>

    <!-- Verse 1 -->
    <p class="verse">
      <span class="verse-num">1</span>
      In the beginning
      <a href="../../dict/hebrew/h7225.html" class="strongs-link" title="H7225: beginning">[H7225]</a>
      God
      <a href="../../dict/hebrew/h0430.html" class="strongs-link" title="H0430: God">[H0430]</a>
      created
      <a href="../../dict/hebrew/h1254.html" class="strongs-link">[H1254]</a>
      <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
      the heaven
      <a href="../../dict/hebrew/h8064.html" class="strongs-link">[H8064]</a>
      and
      <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
      the earth
      <a href="../../dict/hebrew/h0776.html" class="strongs-link">[H0776]</a>.
    </p>

    <!-- Verse 2 -->
    <p class="verse">
      <span class="verse-num">2</span>
      And the earth
      ...
    </p>

    <!-- ... more verses ... -->
  </main>

  <!-- Footer Navigation -->
  <footer class="chapter-footer">
    <nav>
      <a href="gen_ch00.html" class="btn">← Previous Chapter</a>
      <a href="../../index.html" class="btn">Back to Books</a>
      <a href="gen_ch02.html" class="btn">Next Chapter →</a>
    </nav>
    <p class="last-updated">Last read: <span id="last-read"></span></p>
  </footer>

  <!-- Bookmark tracking script (optional) -->
  <script>
    // Simple bookmark tracking (see Bookmarking Strategy section below)
    function saveBookmark() {
      localStorage.setItem('last-page', window.location.href);
      localStorage.setItem('last-read-time', new Date().toLocaleString());
    }
    window.addEventListener('beforeunload', saveBookmark);
    
    // Display last read time
    const lastRead = localStorage.getItem('last-read-time');
    if (lastRead) {
      document.getElementById('last-read').textContent = lastRead;
    }
  </script>

</body>
</html>
```

### Verse Markup Details

**Single Strong's reference:**
```html
<a href="../../dict/hebrew/h0430.html" class="strongs-link">[H0430]</a>
```

**Multiple Strong's references (composite word):**
```html
<a href="../../dict/hebrew/h1254.html" class="strongs-link">[H1254]</a>
<a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
```

**Link styling:** Dark blue/bright color on dark background, underlined for visibility.

### Verse-level Notes and Cross-References

To keep custom notes and cross-references unobtrusive, render them as superscript links immediately after the verse or referenced phrase.

Example:
```html
<p class="verse">
  <span class="verse-num">1</span>
  In the beginning
  <a href="../../dict/hebrew/h7225.html" class="strongs-link">[H7225]</a>
  God
  <a href="../../dict/hebrew/h0430.html" class="strongs-link">[H0430]</a>
  created
  <a href="../../dict/hebrew/h1254.html" class="strongs-link">[H1254]</a>
  <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
  the heaven
  <a href="../../dict/hebrew/h8064.html" class="strongs-link">[H8064]</a>
  and
  <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
  the earth
  <a href="../../dict/hebrew/h0776.html" class="strongs-link">[H0776]</a>
  <a href="../notes/verse-notes-gen1-1.html" class="superscript-link">¹</a>
  <a href="../xref/verse-xref-gen1-1.html" class="superscript-link">⟶</a>.
</p>
```

The superscript links can point to:
- a personal note summary page for that verse or verse range
- a custom cross-reference page showing related verses

This keeps the main text clean while still making notes available.

---

## Dictionary Entry HTML Format

### File Naming Convention
Hebrew: `dict/hebrew/h{number}.html` (e.g., `h0430.html`)  
Greek: `dict/greek/g{number}.html` (e.g., `g3962.html`)

### Entry Page Structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>H0430 - Strong's Hebrew</title>
  <link rel="stylesheet" href="../../css/style.css">
</head>
<body class="dictionary">

  <!-- Navigation -->
  <nav class="dict-nav">
    <a href="../../index.html" class="btn">Home</a>
    <a href="h0429.html" class="btn">← Previous</a>
    <a href="h0431.html" class="btn">Next →</a>
    <a href="../strongs-hebrew-index.html" class="btn">H Index</a>
  </nav>

  <!-- Entry Content -->
  <main class="entry-content">
    <div class="entry-header">
      <h1>H0430</h1>
      <div class="original-lang">אלהים</div>
    </div>

    <section class="entry-section">
      <h3>Transliteration</h3>
      <p class="transliteration">ĕlôhîym</p>
    </section>

    <section class="entry-section">
      <h3>Phonetic</h3>
      <p class="phonetic">el-o-heem'</p>
    </section>

    <section class="entry-section">
      <h3>Definition</h3>
      <div class="definition">
        <p><strong>Plural form</strong></p>
        <ul>
          <li>rulers, judges</li>
          <li>divine ones</li>
          <li>angels</li>
          <li>gods</li>
        </ul>
        <p><strong>Singular meaning</strong></p>
        <ul>
          <li>god, goddess</li>
          <li>godlike one</li>
          <li>the (true) God</li>
        </ul>
      </div>
    </section>

    <section class="entry-section">
      <h3>Etymology</h3>
      <p>Plural of
        <a href="h0433.html" class="cross-ref-link">H0433</a>
      </p>
    </section>

    <section class="entry-section">
      <h3>Related Entries</h3>
      <ul>
        <li><a href="h0433.html">H0433 - el (root)</a></li>
        <li><a href="h0434.html">H0434 - eloah</a></li>
      </ul>
    </section>

    <!-- KJV Usage Stats -->
    <section class="entry-section">
      <h3>Usage in KJV</h3>
      <p>Occurs <strong>2,602 times</strong> in the Bible</p>
      <p><a href="../../indexes/english-concordance.html#god" class="btn">See in Concordance</a></p>
    </section>
  </main>

  <!-- Footer -->
  <footer class="dict-footer">
    <nav>
      <a href="h0429.html" class="btn">← Previous</a>
      <a href="../strongs-hebrew-index.html" class="btn">Hebrew Index</a>
      <a href="h0431.html" class="btn">Next →</a>
    </nav>
  </footer>

</body>
</html>
```

---

## Index & Navigation Files

### Strong's Hebrew Index (`indexes/strongs-hebrew-index.html`)

```html
<h1>Strong's Hebrew Dictionary Index</h1>
<p>Total entries: 8,674</p>

<div class="index-list">
  <h3>H0001 - H0100</h3>
  <ul>
    <li><a href="../dict/hebrew/h0001.html">H0001 - אב (ʼâb) - father</a></li>
    <li><a href="../dict/hebrew/h0002.html">H0002 - אבד (ʼâbad) - perish</a></li>
    ...
  </ul>

  <h3>H0101 - H0200</h3>
  ...
</div>
```

**Organization:** Group by hundreds for easier navigation

### English Concordance (`indexes/english-concordance.html`)

Lists unique English words extracted from KJV text, alphabetically sorted, with verse counts and links to dictionary entries.

```html
<h1>English Word Concordance</h1>
<p>Total unique words: ~12,000</p>

<div class="concordance-list">
  <h3>A</h3>
  <ul>
    <li><a href="#able">able</a> - 48 occurrences</li>
    <li><a href="#abode">abode</a> - 12 occurrences</li>
    ...
  </ul>

  <h3>G</h3>
  <ul>
    <li><a href="#god">God</a> - 2,602 occurrences 
      <span class="strongs">[H0430, H0433]</span>
    </li>
    ...
  </ul>
</div>
```

---

## CSS Styling for Dark Mode & Kindle Compatibility

### Key Features

1. **Dark Mode Base**
   - Dark background (`#1a1a1a` or `#222222`)
   - Light text (`#e0e0e0` or `#f0f0f0`)
   - High contrast for readability

2. **Font Sizing (User-Flexible)**
   - Base size: `16px` for comfortable reading on 7" screen
   - CSS variables or explicit size classes for adjustment
   - Support 3-4 size options (small, normal, large, x-large)

3. **Kindle Compatibility**
   - No flexbox/grid (use floats if needed)
   - Basic styling only
   - Proper Unicode support for Hebrew/Greek

4. **Link Colors**
   - Strong's links: `#4da6ff` (bright blue) - easily visible on dark background
   - Navigation links: `#66cc66` (light green)
   - Cross-reference links: `#ffcc00` (gold)

### Sample CSS

```css
:root {
  --bg-dark: #1a1a1a;
  --text-light: #e0e0e0;
  --strongs-link: #4da6ff;
  --font-base: 16px;
}

body {
  background-color: var(--bg-dark);
  color: var(--text-light);
  font-family: Georgia, 'Times New Roman', serif;
  font-size: var(--font-base);
  line-height: 1.6;
  margin: 0;
  padding: 10px;
}

/* Font size variants */
body.font-small {
  --font-base: 13px;
}
body.font-large {
  --font-base: 19px;
}
body.font-xlarge {
  --font-base: 22px;
}

/* Strong's links */
.strongs-link {
  color: var(--strongs-link);
  text-decoration: underline;
  background-color: transparent;
}

.strongs-link:hover {
  background-color: rgba(77, 166, 255, 0.2);
}

/* Superscript note and cross-reference links */
.superscript-link {
  color: #ffcc00;
  text-decoration: none;
  font-size: 0.85em;
  vertical-align: super;
  margin-left: 2px;
}

.superscript-link:hover {
  text-decoration: underline;
}

/* Navigation buttons */
.btn {
  color: #66cc66;
  text-decoration: none;
  border: 1px solid #66cc66;
  padding: 5px 10px;
  display: inline-block;
  margin: 5px 5px 5px 0;
}

.btn:hover {
  background-color: rgba(102, 204, 102, 0.2);
}

/* Dictionary entry sections */
.entry-section {
  margin: 20px 0;
  padding: 10px;
  border-left: 3px solid #4da6ff;
}

.original-lang {
  font-size: 1.5em;
  font-weight: bold;
  direction: rtl;
  margin: 10px 0;
}

.transliteration {
  font-style: italic;
  color: #b3b3b3;
}

/* Verse numbering */
.verse-num {
  font-weight: bold;
  color: #888888;
  margin-right: 5px;
}

.verse {
  margin: 15px 0;
  padding-left: 10px;
}
```

---

## Bookmarking Strategy

### Challenge

FBReader (old version on Android 2.x) doesn't support HTML5 localStorage or cookies reliably. However, we can implement a workaround:

### Solution Approaches

#### Option 1: localStorage (Best-effort, may not work on FBReader)

```javascript
function saveBookmark() {
  localStorage.setItem('last-page', window.location.href);
  localStorage.setItem('last-read-time', new Date().toLocaleString());
}

function loadBookmark() {
  const lastPage = localStorage.getItem('last-page');
  if (lastPage && confirm('Resume reading from last page?')) {
    window.location.href = lastPage;
  }
}

window.addEventListener('beforeunload', saveBookmark);
window.addEventListener('load', loadBookmark);
```

**Note:** This works in modern browsers but may fail in FBReader. Test on actual device.

#### Option 2: Manual Bookmark Page

Create a `bookmarks.html` page where users can manually save chapter links:

```html
<!DOCTYPE html>
<html>
<head>
  <title>My Bookmarks</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <h1>My Reading Bookmarks</h1>
  <div id="bookmarks"></div>
  <a href="javascript:saveCurrentPage()" class="btn">Save Current Page</a>
  
  <script>
    function saveCurrentPage() {
      const bookmarks = JSON.parse(localStorage.getItem('bookmarks') || '[]');
      bookmarks.push({
        url: document.referrer,
        title: prompt('Page name:'),
        date: new Date().toLocaleDateString()
      });
      localStorage.setItem('bookmarks', JSON.stringify(bookmarks));
      location.reload();
    }
    
    // Display bookmarks
    const bookmarks = JSON.parse(localStorage.getItem('bookmarks') || '[]');
    const list = document.getElementById('bookmarks');
    bookmarks.forEach((bm, i) => {
      const li = document.createElement('li');
      li.innerHTML = `<a href="${bm.url}">${bm.title}</a> (${bm.date})`;
      list.appendChild(li);
    });
  </script>
</body>
</html>
```

#### Option 3: External Tracking File

Generate a separate JSON file (`user/bookmarks.json`) that users can edit manually:

```json
{
  "last-page": "books/ot/01-genesis/gen_ch01.html",
  "last-read": "2026-06-06 14:30:00",
  "bookmarks": [
    {
      "page": "books/ot/01-genesis/gen_ch01.html",
      "title": "Genesis 1",
      "date": "2026-06-06"
    }
  ]
}
```

### Recommendation

**Start with Option 1 (localStorage)** for simplicity. If testing on Kindle shows it doesn't work, fall back to Option 2 (manual bookmark page).

---

## Personal Notes & Custom Cross-References

### Challenge

FBReader doesn't provide an annotation system. We need a workaround that doesn't require server-side storage.

### Solution: Local Note Storage

#### HTML Note Editor

Add a notes section to each chapter page:

```html
<!-- Add to chapter pages -->
<section class="personal-notes">
  <h3>My Notes for Genesis 1:1</h3>
  
  <div class="verse-1-notes">
    <textarea id="note-gen1-1" placeholder="Add your note here..."></textarea>
    <button onclick="saveNote('gen1', '1')">Save Note</button>
  </div>

  <div class="note-timestamp" id="note-gen1-1-timestamp"></div>
  <div class="note-display" id="note-gen1-1-display"></div>
</section>

<script>
  function saveNote(book, verse) {
    const noteText = document.getElementById(`note-${book}-${verse}`).value;
    const notes = JSON.parse(localStorage.getItem('personal-notes') || '{}');
    notes[`${book}-${verse}`] = {
      text: noteText,
      savedAt: new Date().toLocaleString()
    };
    localStorage.setItem('personal-notes', JSON.stringify(notes));
    alert('Note saved!');
    displayNoteMetadata(book, verse, notes[`${book}-${verse}`]);
  }

  function displayNoteMetadata(book, verse, noteData) {
    const timestamp = document.getElementById(`note-${book}-${verse}-timestamp`);
    if (timestamp && noteData && noteData.savedAt) {
      timestamp.textContent = `Last updated: ${noteData.savedAt}`;
    }
  }

  // Load and display notes
  function loadNotes() {
    const notes = JSON.parse(localStorage.getItem('personal-notes') || '{}');
    Object.keys(notes).forEach(key => {
      const display = document.getElementById(`note-${key}-display`);
      if (display && notes[key]) {
        display.innerHTML = `<p>${notes[key].text || notes[key]}</p>`;
      }
      const [book, verse] = key.split('-');
      displayNoteMetadata(book, verse, notes[key]);
    });
  }

  window.addEventListener('load', loadNotes);
</script>
```

#### Superscript Links for Notes and Cross-References

To keep the verse text unobtrusive, attach small superscript links immediately after the verse or phrase.

Example within a verse:

```html
<p class="verse">
  <span class="verse-num">1</span>
  In the beginning
  <a href="../../dict/hebrew/h7225.html" class="strongs-link">[H7225]</a>
  God
  <a href="../../dict/hebrew/h0430.html" class="strongs-link">[H0430]</a>
  created
  <a href="../../dict/hebrew/h1254.html" class="strongs-link">[H1254]</a>
  <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
  the heaven
  <a href="../../dict/hebrew/h8064.html" class="strongs-link">[H8064]</a>
  and
  <a href="../../dict/hebrew/h0853.html" class="strongs-link">[H0853]</a>
  the earth
  <a href="../../dict/hebrew/h0776.html" class="strongs-link">[H0776]</a>
  <a href="../user/notes/gen1-1.html" class="superscript-link">¹</a>
  <a href="../user/xrefs/gen1-1.html" class="superscript-link">⟶</a>.
</p>
```

This creates:
- a notes page for the verse: `user/notes/gen1-1.html`
- a cross-reference page: `user/xrefs/gen1-1.html`

Those pages can show grouped cross-references and personal notes without cluttering the verse text.


#### Custom Cross-Reference Links

Add a "Cross-reference" button to each verse:

```html
<button onclick="addCrossRef('gen1-1')">Link to another verse</button>

<script>
  function addCrossRef(verseId) {
    const targetVerse = prompt('Link to verse (e.g., john3-16):');
    if (targetVerse) {
      const refs = JSON.parse(localStorage.getItem('cross-refs') || '{}');
      if (!refs[verseId]) refs[verseId] = [];
      refs[verseId].push(targetVerse);
      localStorage.setItem('cross-refs', JSON.stringify(refs));
      alert(`Linked to ${targetVerse}`);
    }
  }
</script>
```

#### Export/Backup Notes

Create a `notes-backup.html` page to display and export notes as JSON:

```html
<!DOCTYPE html>
<html>
<head>
  <title>My Notes Backup</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body>
  <h1>My Personal Notes</h1>
  <button onclick="exportNotes()">Export as JSON</button>
  <button onclick="importNotes()">Import from JSON</button>
  <pre id="notes-data"></pre>

  <script>
    function exportNotes() {
      const notes = localStorage.getItem('personal-notes');
      const refs = localStorage.getItem('cross-refs');
      const all = { notes, refs };
      
      const dataStr = JSON.stringify(all, null, 2);
      document.getElementById('notes-data').textContent = dataStr;
      
      // Allow copy to clipboard
      const blob = new Blob([dataStr], { type: 'text/plain' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = 'kjv-notes.json';
      a.click();
    }
  </script>
</body>
</html>
```

### Limitations & Warnings

⚠️ **Important:**
- localStorage is **per-device, per-app, not synced** across devices
- If FBReader clears cache/data, notes are lost
- Backup export should be done regularly
- No cloud sync (would require external infrastructure)

### Recommendation

Implement basic notes feature with strong emphasis on **regular backups**. Include backup/export feature prominently in the UI.

---

## Conversion Pipeline Overview

### Step 1: Parse & Index
- Read OSIS XML, extract verses and Strong's lemmas
- Parse Strong's lexicon files into lookup tables
- Build concordance index from English words

### Step 2: Generate Dictionary Files
- Create `dict/hebrew/h####.html` for each Hebrew entry
- Create `dict/greek/g####.html` for each Greek entry
- Insert cross-reference links between entries

### Step 3: Generate Chapter Pages
- Create `books/{book}/{chapter}.html` for each chapter
- Insert Strong's lemma links pointing to `dict/` pages
- Add chapter navigation (Previous/Next)

### Step 4: Generate Index Files
- Create `indexes/strongs-hebrew-index.html` (organized by hundreds)
- Create `indexes/strongs-greek-index.html` (organized by hundreds)
- Create `indexes/english-concordance.html` (A-Z word list)

### Step 5: Package
- Create EPUB structure using Calibre
- Include CSS, JavaScript, HTML files
- Generate EPUB manifest (OPF/NCX)

### Step 6: Deploy
- Use ADB to push EPUB to Kindle Fire
- Open in FBReader
- Test navigation, links, rendering

---

## Technical Considerations

### Unicode & Encoding
- **All HTML files:** UTF-8 encoding (`<meta charset="UTF-8">`)
- **Hebrew text:** Render using system fonts (most Android devices support)
- **Greek text:** Similar support as Hebrew
- **Testing:** Verify on Kindle device that characters render correctly

### Performance Optimization
- Chapter files: Keep to <500KB (rough estimate)
- Dictionary files: Typically <50KB each
- Index files: Group by hundreds to avoid massive single files
- CSS: Single shared stylesheet (avoid duplication)

### Kindle Fire Specifics
- **Screen:** 7.5" × 4.75" (typical)
- **Default font size:** 16px comfortable for most users
- **Browser:** Old WebKit (2010-era), no modern features
- **Storage:** Typically 8GB (mostly available)
- **Test on device early** to catch rendering issues

### Browser Compatibility Notes
- Don't rely on modern CSS (no flexbox, grid, etc.)
- Test all links in actual FBReader app
- Verify Unicode rendering
- Check color contrast in actual Kindle lighting
- Avoid JavaScript if possible; if used, keep it simple

---

## File Size Estimates

| Component | Count | Avg Size | Total |
|-----------|-------|----------|-------|
| Bible chapters | 1,189 | 300 KB | ~357 MB |
| Hebrew dict entries | 8,674 | 40 KB | ~347 MB |
| Greek dict entries | 5,624 | 40 KB | ~225 MB |
| Index/concordance | 5 | 500 KB | ~2.5 MB |
| CSS/assets | - | - | ~100 KB |
| **Uncompressed Total** | - | - | **~932 MB** |
| **EPUB Compressed** | - | - | **~150-200 MB** |

**Note:** This is large. Consider splitting into:
- KJV Bible only (small version)
- Hebrew dictionary only
- Greek dictionary only
- Combined (full version)

---

## Next Steps

1. **Create data parsing scripts** (Phase 1.1 of PLAN.md)
   - OSIS XML parser
   - Lexicon indexer
   - Concordance builder

2. **Build HTML generation** (Phase 2 of PLAN.md)
   - Chapter HTML generator
   - Dictionary entry generator
   - Index/concordance generator

3. **Test on actual Kindle Fire device**
   - Verify rendering
   - Test navigation
   - Check font sizes and colors

4. **Package into EPUB**
   - Generate EPUB structure
   - Use Calibre for conversion
   - Deploy via ADB

---

## References

- [OSIS Specification](http://www.bibletechnologies.net/osisCore.2.1.1.xsd)
- [Strong's Numbering System](https://www.blueletterbible.org/study/strongs/)
- [EPUB Standard](http://www.idpf.org/epub/30/)
- [Calibre eBook Tool](https://calibre-ebook.com/)
- [Android ADB Documentation](https://developer.android.com/studio/command-line/adb)
