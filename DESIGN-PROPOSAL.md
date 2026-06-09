# KJV Strong's — Full Bible Generator & Navigator Design

## Summary

This document is the complete, confirmed design for converting the OSIS
XML KJV Bible with Strong's references into a dual-platform static HTML
Bible study system:

- **PC (HTML):** Full-featured study Bible with Strong's links, OSIS
  cross-references, personal study notes, concordance, Strong's indices,
  full-text search, font size control, and bookmarks
- **Kindle (EPUB):** Portable reading Bible with Strong's links, OSIS
  cross-references, concordance, and Strong's indices — JavaScript
  features (notes, search) gracefully absent

The design covers folder structure, file naming, relative path mapping,
the full Bible generator architecture, the navigation widget, personal
notes, bookmarks, font size, search, concordance, and EPUB packaging,
organized into three implementation phases.

---

## 1. Folder Structure (Revised)

```
kjv-strongs-html/
│
├── index.html                        # Book table-of-contents
├── navigate.html                     # Cascading Book → Chapter → Verse navigator
├── notes.html                        # Personal study notes viewer/editor (PC only)
├── search.html                       # Full-text search interface (PC only)
│
├── css/
│   └── style.css                     # Shared dark-mode stylesheet
│
├── js/
│   ├── bible-data.js                 # Book/chapter/verse metadata for navigator
│   ├── bookmarks.js                  # Auto-save reading position (localStorage)
│   ├── fontsize.js                   # Font size toggle (localStorage)
│   ├── notes.js                      # Personal study notes (server API, PC only)
│   └── navigation.js                 # Existing nav helpers
│
├── books/
│   ├── 01-Gen/
│   │   ├── 1.html                    # Genesis 1
│   │   ├── 2.html                    # Genesis 2
│   │   └── ...50.html
│   ├── 02-Exod/
│   │   ├── 1.html
│   │   └── ...40.html
│   ├── ...
│   ├── 40-Matt/
│   │   ├── 1.html
│   │   └── ...28.html
│   └── 66-Rev/
│       ├── 1.html
│       └── ...22.html
│
├── dict/
│   ├── hebrew/
│   │   ├── h0001.html
│   │   └── ...h8674.html
│   └── greek/
│       ├── g0001.html
│       └── ...g5624.html
│
├── indexes/
│   ├── strongs-hebrew-index.html
│   ├── strongs-greek-index.html
│   └── english-concordance.html
│
├── xrefs/                            # OSIS cross-reference pages (static)
│   ├── Gen.1.1.html                  # Only for verses with xrefs in XML
│   ├── Gen.1.2.html
│   └── ...
│
├── notes/                            # Baked personal study notes (created by bake script)
│   ├── Gen.1.1.html                  # Only exists after user bakes a note
│   ├── Ps.23.1.html
│   └── ...
│
├── search-index/                     # Pre-built search data (PC only)
│   ├── a.json                        # Words starting with A → verse refs
│   ├── b.json
│   └── ...z.json
│
├── bake-notes.ps1                    # Permanently inject notes into chapter HTML
├── start-study.ps1                   # PowerShell HTTP server for PC study sessions
└── notes-data.json                   # Personal notes store (created on first note)
```

### What changed and why

**Dropped the `ot/` and `nt/` layer.** Your ARCHITECTURE.md nests books
under `books/ot/` and `books/nt/`. That adds a third directory level, which
means every relative path from a chapter page gets one `../` deeper:
`../../../css/style.css` instead of `../../css/style.css`,
`../../../dict/hebrew/h0430.html` instead of `../../dict/hebrew/h0430.html`.
On a device where you're debugging broken links by manually inspecting HTML
files, shorter paths are much easier to verify. The numbered prefix
(`01-Gen`, `40-Matt`) already gives you canonical ordering and makes the
OT/NT boundary obvious at a glance (books 1–39 = OT, 40–66 = NT).

**Simplified chapter filenames to `{number}.html`.** Your architecture
proposed `gen_ch01.html`. Since the book is already identified by the parent
folder (`01-Gen/`), the abbreviation prefix is redundant in the filename.
Using plain `1.html`, `2.html` makes the generator simpler — you just need
the chapter number, not a per-book abbreviation. It also makes navigation
math trivial: previous chapter = `(n-1).html`, next = `(n+1).html` within
the same book.

**Used OSIS-standard abbreviations for folder names.** `01-Gen`, `02-Exod`,
`19-Ps`, `40-Matt` — these match the `osisID` values in your XML source
(`Gen.1`, `Exod.1`, etc.), so the generator can derive the folder name
directly from the XML without a separate lookup table for folder naming.

**Dictionary files use lowercase (`h0430.html`, `g3962.html`).** This
preserves compatibility with the existing `generate_dict.ps1` output
already in the repo under `dict/hebrew/` and `dict/greek/`.

---

## 2. File Naming Convention (Complete Reference)

| Content type       | Path pattern                          | Example                            |
|--------------------|---------------------------------------|------------------------------------|
| Chapter page       | `books/{NN}-{Abbr}/{chapter}.html`    | `books/01-Gen/1.html`              |
| Hebrew dict entry  | `dict/hebrew/h{NNNN}.html`           | `dict/hebrew/h0430.html`           |
| Greek dict entry   | `dict/greek/g{NNNN}.html`            | `dict/greek/g3962.html`            |
| Hebrew index       | `indexes/strongs-hebrew-index.html`   |                                    |
| Greek index        | `indexes/strongs-greek-index.html`    |                                    |
| Concordance        | `indexes/english-concordance.html`    |                                    |
| Book TOC           | `index.html`                          |                                    |
| Navigator          | `navigate.html`                       |                                    |
| Bible data (JS)    | `js/bible-data.js`                    |                                    |
| Bookmarks (JS)     | `js/bookmarks.js`                     |                                    |
| Font size (JS)     | `js/fontsize.js`                      |                                    |
| Personal notes (JS)| `js/notes.js`                         | PC only                            |
| Notes viewer       | `notes.html`                          | PC only                            |
| OSIS xref page     | `xrefs/{Book}.{Ch}.{Vs}.html`        | `xrefs/Gen.1.1.html`              |
| Baked note page    | `notes/{Book}.{Ch}.{Vs}.html`        | `notes/Gen.1.3.html`              |
| Search page        | `search.html`                         | PC only                            |
| Search index       | `search-index/{letter}.json`          | `search-index/a.json`              |
| Note bake script   | `bake-notes.ps1`                      | Run after exporting notes          |
| Study server       | `start-study.ps1`                     | Starts local server on :8080       |
| Notes data         | `notes-data.json`                     | Created by server on first note    |

**Verse anchors** within chapter files: `id="verse-1"`, `id="verse-2"`, etc.
(matches your existing convention).

---

## 3. Relative Path Map

Every link in the system must be a relative path (no leading `/`). Here is
every path relationship, traced from the source file's location:

### From a chapter page (`books/01-Gen/1.html`)

| Target                  | Relative path                           |
|-------------------------|-----------------------------------------|
| CSS stylesheet          | `../../css/style.css`                   |
| Hebrew dict entry       | `../../dict/hebrew/h0430.html`          |
| Greek dict entry        | `../../dict/greek/g3962.html`           |
| Next chapter (same book)| `2.html`                                |
| Prev chapter (same book)| *hidden — Genesis 1 has no previous*    |
| Next chapter (cross-book)| `../02-Exod/1.html`                    |
| Book index (TOC)        | `../../index.html`                      |
| Navigator               | `../../navigate.html`                   |
| Hebrew index            | `../../indexes/strongs-hebrew-index.html` |
| Bookmarks JS            | `../../js/bookmarks.js`                 |
| Font size JS            | `../../js/fontsize.js`                  |
| Notes JS (PC only)      | `../../js/notes.js`                     |
| OSIS xref page          | `../../xrefs/Gen.1.1.html`              |
| Baked note page         | `../../notes/Gen.1.3.html`              |

### From a dictionary page (`dict/hebrew/h0430.html`)

| Target                  | Relative path                           |
|-------------------------|-----------------------------------------|
| CSS stylesheet          | `../../css/style.css`                   |
| Adjacent dict entry     | `h0431.html`                            |
| Book index (TOC)        | `../../index.html`                      |
| A chapter page          | `../../books/01-Gen/1.html#verse-1`     |

### From root-level pages (`navigate.html`, `notes.html`, `search.html`)

| Target                  | Relative path                           |
|-------------------------|-----------------------------------------|
| CSS stylesheet          | `css/style.css`                         |
| JS data file            | `js/bible-data.js`                      |
| Any chapter page        | `books/01-Gen/1.html#verse-3`           |
| Search index chunk      | `search-index/a.json`                   |

### From an xref page (`xrefs/Gen.1.1.html`)

| Target                  | Relative path                           |
|-------------------------|-----------------------------------------|
| CSS stylesheet          | `../css/style.css`                      |
| Back to chapter         | `../books/01-Gen/1.html#verse-1`        |
| Book index (TOC)        | `../index.html`                         |

### From a baked note page (`notes/Gen.1.3.html`)

| Target                  | Relative path                           |
|-------------------------|-----------------------------------------|
| CSS stylesheet          | `../css/style.css`                      |
| Back to chapter         | `../books/01-Gen/1.html#verse-3`        |
| Book index (TOC)        | `../index.html`                         |
| Notes viewer            | `../notes.html`                         |

---

## 4. Full Bible Generator Architecture

### 4.1 The Master Book Table

The generator needs a single ordered data structure containing every book in
the Bible. This is the heart of the system — it drives folder creation,
cross-book navigation, and the bible-data.js output.

```
BookNum | OsisId  | Abbr  | FullName        | Chapters | Testament
--------|---------|-------|-----------------|----------|----------
1       | Gen     | Gen   | Genesis         | 50       | OT
2       | Exod    | Exod  | Exodus          | 40       | OT
3       | Lev     | Lev   | Leviticus       | 27       | OT
...
19      | Ps      | Ps    | Psalms          | 150      | OT
...
40      | Matt    | Matt  | Matthew         | 28       | NT
...
66      | Rev     | Rev   | Revelation      | 22       | NT
```

The OSIS ID (`Gen`, `Exod`, `Matt`) is used both as the folder name suffix
and as the XML query key (`//o:chapter[@osisID="Gen.1"]`).

The full 66-row table should be hardcoded in the PowerShell script (not
derived from XML), because:
- It guarantees canonical ordering even if the XML has quirks
- It provides the human-readable display name for `<title>` and `<h1>`
- It provides the chapter count for building prev/next navigation at book
  boundaries
- It provides the `BookNum` for zero-padded folder naming

### 4.2 Script Structure (`generate_bible.ps1`)

```
generate_bible.ps1
│
├── [Config]           Parameters: $OsisPath, $OutputRoot, $CssPath
│
├── [Data]             $BookTable — the 66-row master table
│                      $FlatChapterList — ordered list of all 1,189 chapters
│
├── [Functions]
│   ├── Get-StrongLinkHtml        (existing — extended for Greek)
│   ├── NormalizeVerseText         (existing — reused)
│   ├── Get-ChapterNode            Extract a <chapter> node by osisID
│   ├── ConvertTo-VerseHtml        Parse a chapter node → verse HTML blocks
│   ├── Get-XrefNotes              Extract OSIS <note> cross-refs for a chapter
│   ├── Write-XrefPage             Generate a static xref page for one verse
│   ├── Get-NavLinks               Compute prev/next links for a given position
│   ├── Write-ChapterPage          Assemble and write one chapter HTML file
│   ├── Write-BibleDataJs          Generate js/bible-data.js from $BookTable
│   └── Write-SearchIndex          Generate search-index/*.json files
│
├── [Phase 1] Load & parse OSIS XML once into memory
│
├── [Phase 2] Build the flat chapter list
│   For each book in $BookTable:
│     For chapter 1..book.Chapters:
│       Append { Book, Chapter, FolderName, PrevEntry, NextEntry }
│
├── [Phase 3] Generate chapter HTML files + xref pages
│   For each entry in $FlatChapterList:
│     1. Query the OSIS XML for this chapter's content
│     2. Extract OSIS cross-references (Get-XrefNotes)
│     3. Parse verses → HTML with xref superscripts (ConvertTo-VerseHtml)
│     4. Write xref pages for verses that have them (Write-XrefPage)
│     5. Compute nav links (Get-NavLinks using prev/next in flat list)
│     6. Write HTML file (Write-ChapterPage)
│     7. Record verse count for bible-data.js
│     8. Collect word occurrences for search index
│
├── [Phase 4] Generate bible-data.js
│   Write the book/chapter/verse metadata for the navigator
│
├── [Phase 5] Generate index.html
│   Write the book table-of-contents page
│
├── [Phase 6] Generate concordance + Strong's indices
│   Write indexes/english-concordance.html
│   Write indexes/strongs-hebrew-index.html
│   Write indexes/strongs-greek-index.html
│
└── [Phase 7] Generate search index
    Write search-index/a.json through search-index/z.json
```

### 4.3 The Flat Chapter List (Key Data Structure)

This is the critical piece that makes cross-book navigation simple. Before
generating any HTML, build an ordered array of all 1,189 chapter positions:

```
Index | Book  | Chapter | FolderPath
------|-------|---------|------------------
0     | Gen   | 1       | books/01-Gen
1     | Gen   | 2       | books/01-Gen
...
49    | Gen   | 50      | books/01-Gen
50    | Exod  | 1       | books/02-Exod
51    | Exod  | 2       | books/02-Exod
...
1188  | Rev   | 22      | books/66-Rev
```

For any chapter at index `i`:
- Previous chapter = index `i-1` (if `i > 0`)
- Next chapter = index `i+1` (if `i < 1188`)

Navigation link computation becomes trivial:
- Same book? → `{prevChapter}.html` or `{nextChapter}.html`
- Different book? → `../{otherFolder}/{chapter}.html`
- No previous (Genesis 1)? → omit the button
- No next (Revelation 22)? → omit the button

### 4.4 Chapter HTML Template

Each chapter page follows this structure:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{BookName} {Chapter} — KJV</title>
  <link rel="stylesheet" href="../../css/style.css">
</head>
<body class="bible-text">

  <nav class="chapter-nav">
    <h1 class="book-chapter">{BookName} {Chapter}</h1>
    <div class="nav-buttons">
      <a href="../../index.html" class="btn">Books</a>
      <a href="../../navigate.html" class="btn">Go To</a>
      {prev_link_or_empty}
      {next_link_or_empty}
      <button class="btn" id="font-toggle" onclick="cycleFontSize()">Aa</button>
      <!-- notes.js injects unbaked count badge here when server is running -->
      <span id="unbaked-indicator"></span>
    </div>
  </nav>

  <main class="chapter-content">
    {verse_blocks}
  </main>

  <footer class="chapter-footer">
    <nav class="nav-buttons">
      {prev_link_or_empty}
      <a href="../../index.html" class="btn">Books</a>
      {next_link_or_empty}
    </nav>
  </footer>

  <!-- Phase 1: Core functionality (works on Kindle + PC) -->
  <script src="../../js/fontsize.js"></script>
  <script src="../../js/bookmarks.js"></script>
  <!-- Phase 2: PC-only enhancements (ignored by EPUB readers) -->
  <script src="../../js/notes.js"></script>

</body>
</html>
```

Each verse block (with OSIS cross-reference superscripts when present):

```html
<p class="verse" id="verse-{N}">
  <span class="verse-num">{N}</span>
  {verse text with inline Strong's links}
  {xref_superscript_if_present}
</p>
```

When the OSIS XML contains a `<note>` with cross-references for a verse,
the generator appends a superscript link:

```html
  <a href="../../xrefs/Gen.1.1.html" class="superscript-link"
     title="Cross-references for Genesis 1:1">✝</a>
```

When no cross-reference exists for a verse, nothing is appended. See
section 4.9 for details on OSIS cross-reference generation.

### 4.5 Strong's Link Generation (Fixing the Absolute Path Bug)

Your existing `Get-StrongLinkHtml` generates absolute paths:
```
<a href="/dict/hebrew/h0430.html" ...>
```

This must become a relative path. Since every chapter file lives at
`books/{NN}-{Abbr}/{ch}.html`, the path to dictionary entries is always:
```
<a href="../../dict/hebrew/h0430.html" ...>
```

The function should accept a `$DictRelPath` parameter (always `../../dict`)
or hardcode it, since the depth is uniform for all chapter files.

### 4.6 Hebrew vs. Greek: How to Choose

The OSIS XML uses `strong:H####` for Hebrew and `strong:G####` for Greek.
The existing regex already captures the letter. Extend it to handle both:

- `strong:H1234` → `../../dict/hebrew/h1234.html`
- `strong:G1234` → `../../dict/greek/g1234.html`

OT books (1–39) will mostly have H-numbers; NT books (40–66) will mostly
have G-numbers, but the generator doesn't need to know this — it just
follows whatever the XML says.

### 4.7 Verse Count Extraction (for bible-data.js)

During Phase 3, as the generator processes each chapter, it should record
the number of verses found. This data is collected into an array and written
out in Phase 4 as `js/bible-data.js` for the navigator to consume.

### 4.8 Index Page Generation

`index.html` is a simple table-of-contents with one link per book. Each book
links to its chapter 1:

```html
<h2>Old Testament</h2>
<ul>
  <li><a href="books/01-Gen/1.html">Genesis</a> (50 chapters)</li>
  <li><a href="books/02-Exod/1.html">Exodus</a> (40 chapters)</li>
  ...
</ul>
<h2>New Testament</h2>
<ul>
  <li><a href="books/40-Matt/1.html">Matthew</a> (28 chapters)</li>
  ...
</ul>
```

Optionally, each book entry can expand to show all chapter links, but for
the Kindle's small screen, linking to chapter 1 and relying on in-chapter
navigation is simpler.

### 4.9 OSIS Cross-Reference Generation

The OSIS XML contains `<note type="crossReference">` elements attached to
verses. These are scholarly cross-references embedded in the source data
(not personal notes). The generator extracts them and produces two things:

**1. A superscript link in the chapter page** — appended to the verse `<p>`:

```html
<a href="../../xrefs/Gen.1.1.html" class="superscript-link"
   title="Cross-references for Genesis 1:1">✝</a>
```

**2. A static xref page** — one HTML file per verse that has cross-refs,
stored under `xrefs/` at the project root:

```
xrefs/
├── Gen.1.1.html
├── Gen.1.2.html
├── Gen.1.27.html        (not every verse has xrefs)
├── ...
├── Rev.22.20.html
```

Each xref page lists the cross-referenced passages as links back to the
relevant chapter pages:

```html
<h1>Cross-References: Genesis 1:1</h1>
<ul>
  <li><a href="../books/01-Gen/1.html#verse-1">Genesis 1:1</a> (current)</li>
  <li><a href="../books/23-Isa/45.html#verse-18">Isaiah 45:18</a></li>
  <li><a href="../books/43-John/1.html#verse-1">John 1:1</a></li>
  <li><a href="../books/58-Heb/11.html#verse-3">Hebrews 11:3</a></li>
</ul>
<a href="../books/01-Gen/1.html#verse-1" class="btn">Back to Genesis 1</a>
```

The xref pages use paths one level up (`../`) since they live under
`xrefs/`, so links to chapter pages are `../books/{folder}/{ch}.html`.

Not every verse has cross-references. The generator only creates xref
pages (and superscript links) for verses where the OSIS XML contains
`<note type="crossReference">` data. Verses without cross-references
have no superscript and no xref page.

### 4.10 Folder Structure for Cross-References

The `xrefs/` folder sits at the project root alongside `books/` and
`dict/`. This keeps it at the same depth as other root-level pages, so
relative paths from xref pages to chapter pages are straightforward:

```
From xrefs/Gen.1.1.html:
  → Chapter page:  ../books/01-Gen/1.html#verse-1
  → CSS:           ../css/style.css
  → Home:          ../index.html
```

From chapter pages, the xref link path is:

```
From books/01-Gen/1.html:
  → Xref page:     ../../xrefs/Gen.1.1.html
```

---

## 5. Navigation Widget Design (`navigate.html`)

### 5.1 Concept

A single static HTML page with three cascading `<select>` dropdowns:

```
┌─────────────────────────────┐
│  Go To Passage              │
│                             │
│  Book:    [Genesis      ▾]  │
│  Chapter: [1            ▾]  │
│  Verse:   [— any —      ▾]  │
│                             │
│  [ Go ]                     │
└─────────────────────────────┘
```

Behavior:
1. **Book** dropdown is pre-populated with all 66 books on page load
2. Selecting a book populates the **Chapter** dropdown (1..N)
3. Selecting a chapter populates the **Verse** dropdown (1..M), with a
   "— any —" default that navigates to the top of the chapter
4. Tapping **Go** navigates to `books/{NN}-{Abbr}/{ch}.html#verse-{v}`

### 5.2 Data File: `js/bible-data.js`

This file is generated by the PowerShell script and provides all the
metadata the navigator needs. Format (ES3-compatible, no `const`/`let`):

```javascript
var BIBLE_DATA = [
  {
    num: 1,
    abbr: "Gen",
    name: "Genesis",
    folder: "01-Gen",
    chapters: [
      31, 25, 24, 26, 32, 22, 24, 22, 29, 32,  // ch 1-10 verse counts
      32, 20, 18, 24, 21, 16, 27, 25, 6, 18,    // ch 11-20
      ...
    ]
  },
  {
    num: 2,
    abbr: "Exod",
    name: "Exodus",
    folder: "02-Exod",
    chapters: [22, 25, 22, 31, 23, 30, 25, ...]
  },
  ...
];
```

The `chapters` array holds verse counts: `chapters[0]` = number of verses
in chapter 1, `chapters[1]` = chapter 2, and so on. This lets the Verse
dropdown populate correctly.

Total data size: 66 books × ~30 chapters average × ~5 bytes per verse count
≈ roughly 10–15 KB uncompressed. Very manageable.

### 5.3 JavaScript Logic (ES3-Compatible)

The navigator script must work on Android 2.x WebKit, which means:
- No `let`, `const`, `arrow functions`, `template literals`, or `forEach`
- No `Array.from`, `querySelector` (use `getElementById` instead)
- No `addEventListener` with options — use `onchange` attributes
- `var` only, function declarations only

```
On page load:
  1. Populate Book <select> from BIBLE_DATA
  2. Set Chapter <select> to empty, disabled
  3. Set Verse <select> to empty, disabled

On Book change:
  1. Look up selected book in BIBLE_DATA
  2. Populate Chapter <select> with 1..book.chapters.length
  3. Reset Verse <select> to "— any —", disabled
  4. Enable Chapter <select>

On Chapter change:
  1. Look up verse count: book.chapters[selectedChapter - 1]
  2. Populate Verse <select> with "— any —" + 1..verseCount
  3. Enable Verse <select>

On Go button click:
  1. Read selected book, chapter, verse
  2. Build URL: "books/" + book.folder + "/" + chapter + ".html"
  3. If verse is not "any": append "#verse-" + verse
  4. Navigate: window.location.href = url
```

### 5.4 Layout (Kindle-Compatible CSS)

No flexbox, no grid. Use simple block layout with `display: block` selects
at full width, large touch targets (minimum 44px height), and high-contrast
dark-mode styling matching the existing `style.css`.

```html
<select> elements: width: 100%; padding: 10px; font-size: 18px;
<button>:         width: 100%; padding: 12px; font-size: 20px;
```

### 5.5 Deep-Link Capability

The navigator also enables external tools to link to any passage.
Opening `navigate.html#Gen.3.16` could auto-parse the fragment and
redirect — but this is a future enhancement, not required for v1.

---

## 6. Critical Bugs to Fix from Existing Code

### 6.1 Absolute Paths

`generate_genesis1.ps1` generates links like:
```
href="/dict/hebrew/h0430.html"
href="/indexes/strongs-hebrew-index.html"
```

These will NOT work as local files (no server to resolve `/`). All must
become relative paths. From any chapter page, the prefix is `../../`.

### 6.2 Missing Greek Strong's Support

`Get-StrongLinkHtml` only matches `strong:H(\d+)` (Hebrew). It needs a
second pattern for `strong:G(\d+)` → links to `../../dict/greek/g{NNNN}.html`.

### 6.3 `URLSearchParams` Not Available on Android 2.x

The existing Genesis 1 generator uses `new URLSearchParams(...)` in its
verse page JavaScript. While the verse zoom page is eliminated (Decision D),
any future JavaScript in the project must avoid this API. Use a manual
query-string parser instead:

```javascript
function getQueryParam(name) {
  var query = window.location.search.substring(1);
  var pairs = query.split("&");
  for (var i = 0; i < pairs.length; i++) {
    var pair = pairs[i].split("=");
    if (decodeURIComponent(pair[0]) === name) {
      return decodeURIComponent(pair[1] || "");
    }
  }
  return null;
}
```

---

## 7. Performance & Size Considerations

Your ARCHITECTURE.md estimated ~300 KB per chapter file and ~40 KB per
dictionary entry. These estimates seem high. Actual expected sizes:

| Content               | Realistic avg size | Count  | Total       |
|-----------------------|-------------------|--------|-------------|
| Chapter HTML          | 15–50 KB          | 1,189  | ~30–60 MB   |
| Hebrew dict entry     | 3–8 KB            | 8,674  | ~35–70 MB   |
| Greek dict entry      | 3–8 KB            | 5,624  | ~22–45 MB   |
| OSIS xref pages       | 1–3 KB            | ~8,000 | ~10–25 MB   |
| Baked note pages      | 1–2 KB            | varies | <1 MB       |
| bible-data.js         | ~15 KB            | 1      | 15 KB       |
| Search index (JSON)   | ~100–200 KB each  | 26     | ~3–5 MB     |
| Concordance + indices | ~200–500 KB each  | 3      | ~1 MB       |
| CSS + JS              | ~30 KB            | 6      | 30 KB       |
| **Total uncompressed**|                   |        | **~100–205 MB** |
| **EPUB (compressed)** |                   |        | **~30–60 MB**   |

This is well within the Kindle Fire's storage (typically 8 GB).

Note: the search index files (`search-index/*.json`) and `notes.js` are
excluded from the EPUB, reducing the EPUB size further.

---

## 8. Complete Book Table Reference

For the PowerShell script's `$BookTable` array. Numbers, OSIS IDs,
abbreviations, full names, and chapter counts for all 66 books:

```
 #  OSIS ID   Folder      Full Name           Ch
 1  Gen       01-Gen      Genesis             50
 2  Exod      02-Exod     Exodus              40
 3  Lev       03-Lev      Leviticus           27
 4  Num       04-Num      Numbers             36
 5  Deut      05-Deut     Deuteronomy         34
 6  Josh      06-Josh     Joshua              24
 7  Judg      07-Judg     Judges              21
 8  Ruth      08-Ruth     Ruth                 4
 9  1Sam      09-1Sam     1 Samuel            31
10  2Sam      10-2Sam     2 Samuel            24
11  1Kgs      11-1Kgs     1 Kings             22
12  2Kgs      12-2Kgs     2 Kings             25
13  1Chr      13-1Chr     1 Chronicles        29
14  2Chr      14-2Chr     2 Chronicles        36
15  Ezra      15-Ezra     Ezra                10
16  Neh       16-Neh      Nehemiah            13
17  Esth      17-Esth     Esther              10
18  Job       18-Job      Job                 42
19  Ps        19-Ps       Psalms             150
20  Prov      20-Prov     Proverbs            31
21  Eccl      21-Eccl     Ecclesiastes        12
22  Song      22-Song     Song of Solomon      8
23  Isa       23-Isa      Isaiah              66
24  Jer       24-Jer      Jeremiah            52
25  Lam       25-Lam      Lamentations         5
26  Ezek      26-Ezek     Ezekiel             48
27  Dan       27-Dan      Daniel              12
28  Hos       28-Hos      Hosea               14
29  Joel      29-Joel     Joel                 3
30  Amos      30-Amos     Amos                 9
31  Obad      31-Obad     Obadiah              1
32  Jonah     32-Jonah    Jonah                4
33  Mic       33-Mic      Micah                7
34  Nah       34-Nah      Nahum                3
35  Hab       35-Hab      Habakkuk             3
36  Zeph      36-Zeph     Zephaniah            3
37  Hag       37-Hag      Haggai               2
38  Zech      38-Zech     Zechariah           14
39  Mal       39-Mal      Malachi              4
40  Matt      40-Matt     Matthew             28
41  Mark      41-Mark     Mark                16
42  Luke      42-Luke     Luke                24
43  John      43-John     John                21
44  Acts      44-Acts     Acts                28
45  Rom       45-Rom      Romans              16
46  1Cor      46-1Cor     1 Corinthians       16
47  2Cor      47-2Cor     2 Corinthians       13
48  Gal       48-Gal      Galatians            6
49  Eph       49-Eph      Ephesians            6
50  Phil      50-Phil     Philippians          4
51  Col       51-Col      Colossians           4
52  1Thess    52-1Thess   1 Thessalonians      5
53  2Thess    53-2Thess   2 Thessalonians      3
54  1Tim      54-1Tim     1 Timothy            6
55  2Tim      55-2Tim     2 Timothy            4
56  Titus     56-Titus    Titus                3
57  Phlm      57-Phlm     Philemon             1
58  Heb       58-Heb      Hebrews             13
59  Jas       59-Jas      James                5
60  1Pet      60-1Pet     1 Peter              5
61  2Pet      61-2Pet     2 Peter              3
62  1John     62-1John    1 John               5
63  2John     63-2John    2 John               1
64  3John     64-3John    3 John               1
65  Jude      65-Jude     Jude                 1
66  Rev       66-Rev      Revelation          22
```

---

## 9. Confirmed Design Decisions

These choices were confirmed before implementation:

**A. Folder depth:** Drop `ot/` and `nt/`. Books live directly under `books/`
with numbered prefixes providing order. All chapter-to-resource relative
paths use `../../` (two levels up).

**B. Chapter filenames:** Plain `1.html`, `2.html`, etc. The parent folder
already identifies the book.

**C. Dictionary case:** Lowercase (`h0430.html`, `g3962.html`) to match
the existing `generate_dict.ps1` output already in the repo.

**D. No verse zoom page.** Chapter pages with `id="verse-N"` anchors are
the only Bible text view. This eliminates the per-book JS data blob and
the shared verse page template entirely.

**E. OSIS cross-references included in Phase 1.** The OSIS XML contains
scholarly cross-references (`<note type="crossReference">`). These are
static data, not personal notes. The generator extracts them and produces
superscript links in verse markup plus static xref pages under `xrefs/`.
This works on both PC and Kindle with no JavaScript required.

**F. Personal study notes — server-based with baking.** A PowerShell
HTTP server (`start-study.ps1`) provides the live study experience on
PC: adding, editing, and baking personal notes via API endpoints. Notes
are stored in `notes-data.json` on disk (not `localStorage`). The bake
process permanently injects footnote superscripts into chapter HTML
files and creates static note pages under `notes/`. Baked notes become
static content that works everywhere, including the Kindle EPUB. The
server includes an exit safety check that prompts to bake any unbaked
notes before shutting down. Without the server running, all static
content (including baked notes) remains fully functional.

**G. Bookmarks — included, both platforms.** Auto-saves reading position
via `js/bookmarks.js` loaded by every chapter page. Uses `localStorage`
on PC (reliable) and Kindle (best-effort — may not persist if the app
clears its cache).

**H. Font size toggle — included, both platforms.** Cycles through CSS
body classes (`font-small`, `font-normal`, `font-large`, `font-xlarge`)
via `js/fontsize.js`. Saves preference to `localStorage`. The "Aa" button
appears in the chapter nav bar for both platforms.

---

## 10. Platform Feature Matrix

| Feature                          | PC (HTML) | Kindle (EPUB) |
|----------------------------------|-----------|---------------|
| Bible text + Strong's links      | ✓         | ✓             |
| OSIS cross-references (static)   | ✓         | ✓             |
| Chapter prev/next navigation     | ✓         | ✓             |
| Cascading passage navigator      | ✓         | maybe*        |
| Font size toggle                 | ✓         | maybe*        |
| Bookmarks / reading position     | ✓         | maybe*        |
| Concordance + Strong's indices   | ✓         | ✓             |
| Personal notes — add/edit (live) | ✓**       | ✗             |
| Personal notes — read (baked)    | ✓         | ✓             |
| Full-text search                 | ✓         | ✗             |

*"maybe" = depends on whether the Kindle EPUB reader executes JavaScript.
If it does, these features work. If not, the static content is fully
functional and the JS features are simply invisible. No errors, no
broken layout.

**Requires `start-study.ps1` running. Without the server, previously
baked notes are still readable (they're static HTML), but new notes
cannot be added.

---

## 11. Personal Study Notes Design

### 11.1 Architecture Overview

Personal study notes use a two-layer system: a lightweight PowerShell
HTTP server for the live study experience (PC only), and a baking
process that permanently injects notes into the static HTML files
(works everywhere, including the Kindle EPUB).

```
┌──────────────────────────────────────────────────────┐
│  Browser (http://localhost:8080)                      │
│                                                       │
│  Chapter Page                                         │
│  ┌──────────────────────────────────────────────────┐ │
│  │  Gen 1:1  In the beginning God... [H7225] ✝   + │ │
│  │  Gen 1:2  And the earth was without form...    + │ │
│  │  Gen 1:3  And God said, Let there... ✝ ¹       + │ │
│  │            ↑ OSIS xref   ↑ baked note            │ │
│  └──────────────────────────────────────────────────┘ │
│                                                       │
│  Nav bar:  [Books] [Go To] [◀ Prev] [Next ▶] [Aa]    │
│            [3 unbaked]  ← persistent indicator        │
│                                                       │
│  Click "+" → inline textarea → Save/Cancel            │
│       │                                               │
│       ▼  POST /api/save-note                          │
├───────────────────────────────────────────────────────┤
│  start-study.ps1 (PowerShell HTTP server)             │
│  http://localhost:8080                                 │
│                                                       │
│  Routes:                                              │
│    GET  /*              → serve static files           │
│    POST /api/save-note  → write to notes-data.json    │
│    POST /api/bake-notes → inject into chapter HTML    │
│    GET  /api/note-count → return unbaked count        │
│                                                       │
│  On shutdown (Ctrl+C or window close):                │
│    Check notes-data.json for unbaked notes            │
│    Prompt: "3 unbaked notes. Bake now? (Y/N)"         │
│    If Y → bake, then exit                             │
│    If N → exit (notes safe in JSON for next session)  │
└───────────────────────────────────────────────────────┘
```

### 11.2 Study Session Workflow

1. **Start:** Double-click `start-study.ps1`. The script starts the
   HTTP server and opens `http://localhost:8080/index.html` in your
   default browser.

2. **Study:** Read chapter pages normally. Every verse has a small "+"
   button on its right side (injected by `notes.js`). Strong's links,
   OSIS cross-reference superscripts, font size, and bookmarks all
   work as usual.

3. **Add a note:** Click the "+" next to any verse. An inline
   `<textarea>` appears below the verse with Save and Cancel buttons.
   Type your note, click Save. JavaScript sends a POST request to
   `http://localhost:8080/api/save-note` with the verse reference and
   note text. The server writes it to `notes-data.json` on disk. The
   "+" changes to a "✎" to indicate a note exists. The nav bar's
   unbaked count increments.

4. **Edit a note:** Click "✎" on a verse that already has a note.
   The textarea reappears pre-filled with the existing text.

5. **Bake notes:** Click the "Bake Notes" button on `notes.html`
   (or in the nav bar unbaked indicator). JavaScript sends POST to
   `/api/bake-notes`. The server reads `notes-data.json`, and for
   each unbaked note:
   - Opens the chapter HTML file on disk
   - Finds the verse `<p>` by its `id="verse-N"` attribute
   - Inserts a footnote superscript link before `</p>`
   - Creates a note page under `notes/`
   - Sets `"baked": true` in `notes-data.json`

6. **End session:** Close the PowerShell window. The server's shutdown
   handler checks for unbaked notes and prompts before exiting (see
   section 11.6).

### 11.3 Note Data File (`notes-data.json`)

Stored in the project root alongside the HTML files. This replaces
`localStorage` as the note store — it's a real file on disk, backed
up with your project, and version-controllable with Git.

```json
{
  "Gen.1.3": {
    "text": "Compare with John 1:1 — light as the first act...",
    "created": "2026-06-08T14:30:00",
    "updated": "2026-06-09T10:15:00",
    "baked": false
  },
  "Ps.23.1": {
    "text": "The shepherd metaphor — see also Ezekiel 34...",
    "created": "2026-06-09T08:00:00",
    "updated": "2026-06-09T08:00:00",
    "baked": true
  }
}
```

The `baked` flag tracks which notes have been injected into the HTML.
The bake process is incremental — it only touches notes where
`baked` is `false`, sets them to `true`, and leaves already-baked
notes alone.

### 11.4 Baked Note Output

When a note is baked, two things happen on disk:

**1. The chapter HTML file is modified.** A footnote superscript is
inserted into the verse `<p>`, visually distinct from OSIS xrefs:

```html
<p class="verse" id="verse-3">
  <span class="verse-num">3</span>
  And God said, Let there be light: and there was light.
  <a href="../../xrefs/Gen.1.3.html" class="superscript-link">✝</a>
  <a href="../../notes/Gen.1.3.html"
     class="superscript-link personal-note"
     title="Personal study note">¹</a>
</p>
```

The `personal-note` CSS class applies a distinct color (gold or green)
so personal notes are visually distinguishable from OSIS cross-references
at a glance.

**2. A static note page is created** under `notes/`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Note: Genesis 1:3 — KJV Study</title>
  <link rel="stylesheet" href="../css/style.css">
</head>
<body class="note-page">
  <nav class="chapter-nav">
    <h1>Personal Note: Genesis 1:3</h1>
    <div class="nav-buttons">
      <a href="../books/01-Gen/1.html#verse-3" class="btn">Back to Verse</a>
      <a href="../notes.html" class="btn">All Notes</a>
      <a href="../index.html" class="btn">Books</a>
    </div>
  </nav>
  <main class="note-content">
    <blockquote class="verse-text">
      And God said, Let there be light: and there was light.
    </blockquote>
    <div class="personal-note-body">
      Compare with John 1:1 — light as the first act of creation...
    </div>
    <p class="note-meta">
      Created: June 8, 2026 · Updated: June 9, 2026
    </p>
  </main>
</body>
</html>
```

Once baked, these note pages are static HTML — they work offline,
they work on the Kindle, and they survive any browser cache clearing.

### 11.5 Unbaked Notes Indicator

`notes.js` queries `GET /api/note-count` on every chapter page load.
If unbaked notes exist, it displays a persistent indicator in the nav
bar:

```html
<span class="unbaked-badge" onclick="window.location.href='../../notes.html'">
  3 unbaked
</span>
```

This serves three purposes:
- Keeps you informed while studying (you always know your bake status)
- Provides one-click access to the notes page for baking
- Ensures the `beforeunload` exit prompt (see below) is never a surprise

### 11.6 Exit Safety: Two-Layer Protection

**Layer 1 — Browser `beforeunload` (courtesy warning).**
When unbaked notes exist, `notes.js` sets a `beforeunload` handler on
the chapter page. If you close the browser tab, the browser shows its
standard confirmation dialog: "Changes you made may not be saved." This
is a speed bump — browsers intentionally limit what JavaScript can do
during this event, so it cannot trigger a bake. But it reminds you to
check the PowerShell window.

**Layer 2 — PowerShell shutdown handler (reliable check).**
The `start-study.ps1` server wraps its main loop in a `try/finally`
block. When the server shuts down — whether by Ctrl+C, closing the
window, or an explicit stop command — the `finally` block runs:

```
Shutdown sequence:
  1. Read notes-data.json
  2. Count entries where baked == false
  3. If count > 0:
     Display: "You have 3 unbaked notes. Bake them now? (Y/N): "
     If Y → run bake logic → display "Baked 3 notes. Exiting."
     If N → display "Notes saved in notes-data.json. Exiting."
  4. If count == 0:
     Display: "All notes baked. Exiting."
  5. Stop the HTTP listener and exit
```

This is the reliable layer. PowerShell has full control over its
shutdown sequence, and `notes-data.json` is always on disk regardless
of what the browser does.

### 11.7 Notes Viewer (`notes.html`)

A standalone page at the project root that provides a full view of
all personal notes. It queries the server for the complete notes list
and displays them grouped by book and chapter.

Features:
- **View all notes** — scrollable list organized by book, with links
  back to each verse
- **Bake status** — each note shows whether it's been baked or not
- **Bake All** button — triggers POST `/api/bake-notes` to bake all
  unbaked notes in one action
- **Edit** — click any note to edit it inline (saves via the server
  API, and if the note was previously baked, marks it for re-baking)
- **Export** — downloads `notes-data.json` as a file for backup
- **Import** — uploads a previously exported JSON file to restore notes

### 11.8 Editing a Previously Baked Note

When you edit a note that's already been baked (`"baked": true`), the
server sets it back to `"baked": false`. The next bake will regenerate
the note page under `notes/` with the updated text. The superscript
link in the chapter HTML doesn't need to change — it already points
to the note page, which will have the new content after re-baking.

### 11.9 Why Baked Notes Travel to the Kindle

Once notes are baked, they're static HTML — no JavaScript required.
The footnote superscript is a plain `<a>` tag in the chapter file,
and the note page is a standalone HTML file under `notes/`. When you
rebuild the EPUB in Phase 3, baked notes are automatically included:
the chapter files already contain the superscript links, and the note
pages are added to the EPUB manifest. Your personal annotations
travel with you to the Kindle without any additional work.

### 11.10 What Happens Without the Server

If you open the chapter HTML files directly from `file://` (without
running `start-study.ps1`), everything works except personal notes:

- Bible text, Strong's links, OSIS cross-references → static HTML, work
- Font size toggle → `localStorage`, works
- Bookmarks → `localStorage`, works
- Previously baked note superscripts → static HTML, work (you can read
  your baked notes, you just can't add new ones)
- "+" buttons for new notes → `notes.js` fails to reach the server,
  buttons do not appear
- Unbaked indicator → not shown (server unreachable)

This is graceful degradation. The server is only needed for the *active
study* workflow (adding/editing/baking notes). Everything else,
including reading your baked notes, works without it.

---

## 12. Bookmarks Design

`js/bookmarks.js` is loaded by every chapter page. It does two things:

**Auto-save on exit:** When the user leaves a chapter page (via
`beforeunload` event), it writes the current URL and scroll position
to `localStorage` under the key `kjv-bookmark`.

**Resume prompt on index.html:** When `index.html` loads, it checks
for a saved bookmark and displays a "Resume reading: {Book} {Chapter}"
link at the top of the page. Clicking it navigates to the saved URL
with the saved scroll position.

```javascript
// localStorage key: "kjv-bookmark"
// Value (JSON):
{
  "url": "books/01-Gen/3.html",
  "scroll": 1240,
  "title": "Genesis 3",
  "saved": "2026-06-08T14:30:00"
}
```

This is lightweight enough to include on both platforms. If `localStorage`
doesn't work on the Kindle, the bookmark simply doesn't save — no error,
no broken page.

---

## 13. Font Size Toggle Design

`js/fontsize.js` provides a single function `cycleFontSize()` called by
the "Aa" button in the chapter nav bar. It cycles through four body
classes:

```
font-normal → font-large → font-xlarge → font-small → font-normal
```

The current size class is saved to `localStorage` under `kjv-fontsize`.
On page load, the script reads the saved preference and applies it
immediately (before the page renders, to avoid a flash of wrong-sized
text).

The CSS classes are already defined in your ARCHITECTURE.md:

```css
body.font-small  { font-size: 13px; }
body              { font-size: 16px; }  /* default / font-normal */
body.font-large  { font-size: 19px; }
body.font-xlarge { font-size: 22px; }
```

---

## 14. Search Design (PC Only)

### 14.1 Search Index Generation

During the build, the generator collects every unique English word and
its verse locations. This data is written as alphabetically chunked
JSON files under `search-index/`:

```
search-index/
├── a.json    ~100-200 KB
├── b.json
├── ...
└── z.json
```

Each file contains an object mapping words to arrays of verse references:

```json
{
  "above": ["Gen.1.7", "Gen.1.20", "Gen.6.16", ...],
  "abundance": ["Gen.41.29", "Gen.41.31", ...],
  "adam": ["Gen.2.19", "Gen.2.20", "Gen.2.21", ...]
}
```

Total index size: approximately 3-5 MB across all 26 files. Each
individual chunk is small enough for even modest browsers to load.

### 14.2 Search Interface (`search.html`)

A simple page with a text input field. As the user types:

1. On the first character, load the corresponding JSON chunk via
   `XMLHttpRequest` (not `fetch` — for broader compatibility)
2. Filter matching words from the loaded chunk
3. Display results as a list of verse references, each linking to
   the chapter page with the verse anchor

The search is word-based, not phrase-based. Searching "living water"
would show results for "living" and "water" separately. Phrase search
is possible but would require a much larger index.

### 14.3 Synergy with Concordance

The concordance (`indexes/english-concordance.html`) and the search
index are built from the same data — word occurrences per verse. The
concordance is the static HTML view (browseable on both PC and Kindle),
while the search index is the JSON version for interactive lookup
(PC only). Both are generated in the same pass over the OSIS XML.

---

## 15. EPUB Packaging (Phase 3)

The HTML structure is already EPUB-friendly. An EPUB is a ZIP file
containing:

- `mimetype` — the string `application/epub+zip` (no compression)
- `META-INF/container.xml` — points to the OPF file
- `content.opf` — manifest listing every HTML, CSS, and image file
- `toc.ncx` — navigation table of contents (EPUB 2 format for Kindle)
- All the HTML content files

A packaging script will:

1. Copy the generated HTML structure into an EPUB staging folder
2. Strip the `<script src="../../js/notes.js">` tag from chapter files
   (the file is excluded from the EPUB, so the tag must be removed to
   avoid file-not-found errors in EPUB readers that attempt to load it;
   `fontsize.js` and `bookmarks.js` tags remain because those files ARE
   included in the EPUB)
3. Generate the OPF manifest from the file listing
4. Generate the NCX table of contents from the book table
5. ZIP everything with the correct EPUB structure
6. Validate with `epubcheck` if available

Files excluded from the EPUB manifest:
- `notes.html` (needs server for full functionality)
- `search.html` (needs JavaScript)
- `search-index/` (PC-only data)
- `notes-data.json` (server-side data file)
- `start-study.ps1` (PC-only server script)
- `bake-notes.ps1` (PC-only build script)
- `js/notes.js` (file excluded; `<script>` tag stripped from chapter files)

Files included:
- All chapter HTML files under `books/` (including baked note superscripts)
- All dictionary files under `dict/`
- All xref pages under `xrefs/`
- All baked note pages under `notes/` (personal study notes, static HTML)
- All index pages under `indexes/`
- `css/style.css`
- `js/fontsize.js`, `js/bookmarks.js` (best-effort on Kindle)
- `js/bible-data.js` (needed by `navigate.html`)
- `index.html`, `navigate.html`

Baked personal notes are automatically included because they are static
HTML — no special handling required. Any notes baked before the EPUB is
built will travel with you to the Kindle.

---

## 16. Implementation Phases

### Phase 1 — Core Bible Generator

Build the complete static Bible with all features that work on both
platforms. This is the bulk of the work.

Deliverables:
- `generate_bible.ps1` — the full generator script
- 1,189 chapter HTML files with Strong's links and OSIS xref superscripts
- Static xref pages under `xrefs/`
- `js/bible-data.js` — book/chapter/verse metadata
- `navigate.html` — cascading passage navigator
- `index.html` — book table-of-contents
- `js/fontsize.js` — font size toggle
- `js/bookmarks.js` — reading position tracking
- `css/style.css` — updated if needed for new UI elements

Recommended build order within Phase 1:

1. Generate `bible-data.js` — validates XML parsing across all 66 books
2. Generate a test book (Ruth, 4 chapters) with the new folder structure
   and all relative paths. Verify navigation and dictionary links.
3. Generate `navigate.html` and test with the bible-data.js
4. Generate all 66 books with xref pages
5. Generate `index.html`
6. Implement `fontsize.js` and `bookmarks.js`
7. End-to-end test: Genesis 50 → Exodus 1, OT→NT boundary,
   Revelation 22 (no next), dictionary links from both testaments

### Phase 2 — PC Study Enhancements

Add the server-powered notes system, concordance, and search.

Deliverables:
- `start-study.ps1` — PowerShell HTTP server with note save/bake API
  and exit safety check for unbaked notes
- `js/notes.js` — injects "+" buttons, handles note editing UI,
  communicates with server API, shows unbaked indicator
- `notes.html` — notes viewer with bake-all, edit, export, import
- `bake-notes.ps1` — standalone bake script (also used by server
  internally; can be run independently for batch baking)
- `indexes/english-concordance.html` — word concordance
- `indexes/strongs-hebrew-index.html` — Hebrew Strong's index
- `indexes/strongs-greek-index.html` — Greek Strong's index
- `search.html` — full-text search interface
- `search-index/*.json` — alphabetically chunked search data

### Phase 3 — EPUB Packaging

Wrap the HTML output for the Kindle.

Deliverables:
- `package_epub.ps1` — EPUB packaging script
- Final `.epub` file ready for ADB push to Kindle
- Validation with `epubcheck`
