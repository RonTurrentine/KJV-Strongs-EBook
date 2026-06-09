# KJV Strong's EBook — Project Session Notes

## Project Overview

A static HTML KJV Bible with Strong's lexicon references, designed to be converted
to EPUB via Calibre and read on an old Kindle Fire tablet (Android 2.x / Gingerbread,
WebKit browser). All output is static HTML — no server required.

**GitHub Repository:** https://github.com/RonTurrentine/KJV-Strongs-EBook

---

## Source Data Files

| File | Description |
|------|-------------|
| `kjv.osis.xml` | Full KJV Bible in OSIS XML format with Strong's lemma references (e.g. `lemma="strong:H0430"`) |
| `StrongHebrewG.xml` | Hebrew lexicon in OSIS format (openscriptures/strongs) |
| `strongsgreek.xml` | Greek lexicon — **morphgnt v1.9** (replaced original; CC0 Public Domain) |

---

## Key Design Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| File granularity | One HTML file per chapter | Better performance on slow Kindle hardware |
| Dictionary files | One HTML file per Strong's entry | Fast lookup, avoids large combined files |
| Styling | Dark mode, simple CSS | Kindle compatibility, older eyes |
| Strong's badges | Cyan solid background, dark text, small font | Visible and readable in dark mode |
| Note superscript | Gold circle button | Personal study notes per verse |
| Cross-ref superscript | Cyan circle button | Custom cross-references per verse |
| Notes/xrefs | Date/time stamped | Study tracking |
| Navigation | Per-chapter links + cascading dropdown | Touch-friendly on Kindle |
| Indexes | Strong's number index + English concordance (planned) | Study tools |
| Bookmarking | localStorage JS | Remember last reading position |
| Folder structure | `books/{NN}-{Abbr}/{ch}.html` — NO `ot/`/`nt/` layer | Simpler relative paths |
| Chapter filenames | `1.html`, `2.html` (plain numbers) | Simpler, prev/next math trivial |
| Dictionary case | Lowercase (`h0430.html`, `g3056.html`) | Already generated; consistent |
| Verse zoom page | Deferred — chapter anchors sufficient for now | Reduces complexity |
| Notes/xrefs in full Bible | Deferred to later phase | Core Bible first |
| JavaScript compatibility | ES3 only — no `let`/`const`/arrow functions/`URLSearchParams` | Android 2.x WebKit |
| Strong's link style | Word text plain + `[G1161]` badge after | Readable; old style preferred |

---

## Confirmed Folder Structure

```
kjv-strongs-html/
│
├── index.html                        # Book table-of-contents
├── navigate.html                     # Cascading Book -> Chapter -> Verse navigator
├── SESSION-NOTES.md                  # This file
├── DESIGN-PROPOSAL.md                # Opus architecture design document
│
├── css/
│   └── style.css                     # Shared dark-mode stylesheet
│
├── js/
│   ├── bible-data.js                 # Generated: book/chapter/verse metadata (~15KB)
│   ├── fontsize.js                   # Font size cycling (4 sizes, localStorage)
│   └── bookmarks.js                  # Reading position bookmark (localStorage)
│
├── books/
│   ├── 01-Gen/
│   │   ├── 1.html                    # Genesis 1
│   │   └── ...50.html
│   ├── 02-Exod/
│   │   └── ...40.html
│   └── 66-Rev/
│       └── ...22.html
│
├── dict/
│   ├── hebrew/
│   │   └── h0001.html ... h8674.html
│   └── greek/
│       └── g0001.html ... g5624.html
│
├── xrefs/
│   └── {OsisId}.{ch}.{vs}.html      # Cross-reference pages
│
└── indexes/
    ├── strongs-hebrew-index.html     # Not yet generated
    ├── strongs-greek-index.html      # Not yet generated
    └── english-concordance.html      # Not yet generated
```

---

## Confirmed Relative Path Map

### From a chapter page (`books/01-Gen/1.html`)

| Target | Relative path |
|--------|---------------|
| CSS stylesheet | `../../css/style.css` |
| Hebrew dict entry | `../../dict/hebrew/h0430.html` |
| Greek dict entry | `../../dict/greek/g3056.html` |
| Next chapter (same book) | `2.html` |
| Next chapter (cross-book) | `../02-Exod/1.html` |
| Book index (TOC) | `../../index.html` |
| Navigator | `../../navigate.html` |
| Xref page | `../../xrefs/Gen.1.1.html` |

### From a dictionary page (`dict/hebrew/h0430.html`)

| Target | Relative path |
|--------|---------------|
| CSS stylesheet | `../../css/style.css` |
| Book index | `../../index.html` |

### From an xref page (`xrefs/Gen.1.1.html`)

| Target | Relative path |
|--------|---------------|
| CSS stylesheet | `../css/style.css` |
| Chapter back-link | `../books/01-Gen/1.html#verse-1` |

---

## Constraints

- **Kindle Fire Android 2.x WebKit** — no flexbox, no CSS grid, no ES6 JavaScript
- **ES3 JavaScript only** — no `let`, `const`, arrow functions, `URLSearchParams`,
  `Array.from`, `querySelector` (use `getElementById`), no `addEventListener` with options
- All files must work as **local static files** (no absolute paths, no server)
- Verse anchors use format `id="verse-1"`, `id="verse-2"` etc.
- Unicode Hebrew and Greek must render correctly
- Font size adjustable (older reader, small screen)
- Screen size: 7.5 x 4.75 inches
- Select elements: `width: 100%; padding: 10px; font-size: 18px; min-height: 44px`
- Always run scripts with `pwsh -NoProfile -File .\scriptname.ps1` not `.\scriptname.ps1`
  (ensures .NET working directory matches PowerShell working directory)

---

## Scripts

| Script | Purpose |
|--------|---------|
| `generate_bible.ps1` | Full Bible generator — all 66 books, 1,189 chapters |
| `generate_dict.ps1` | Hebrew + Greek dictionary page generator |
| `qa-test.ps1` | QA test suite — 119 tests across 11 test suites |
| `scan_morph_codes.ps1` | Diagnostic — finds all unique Hebrew POS codes in XML |
| `ConvertTo-VerseHtml-Fix.ps1` | Opus fix reference file (integrated into generate_bible.ps1) |
| `generate_genesis1.ps1` | Original prototype — Genesis 1 only (kept for reference) |
| `build.ps1` | Makefile-style helper |

### Standard run commands

```powershell
cd 'C:\Users\OldTi\KJV-Strongs'
pwsh -NoProfile -File .\generate_bible.ps1                    # Full 66-book run
pwsh -NoProfile -File .\generate_bible.ps1 -BookFilter Ruth   # Single book test
pwsh -NoProfile -File .\generate_dict.ps1                     # Regenerate dictionary
pwsh -NoProfile -File .\qa-test.ps1                           # Full QA test
pwsh -NoProfile -File .\qa-test.ps1 -BookFilter Ruth          # Single book QA
pwsh -NoProfile -File .\scan_morph_codes.ps1                  # POS diagnostic
```

---

## Generated Output Statistics

| Output | Count |
|--------|-------|
| Chapter HTML files | 1,189 |
| Hebrew dictionary pages | 8,674 |
| Greek dictionary pages | 5,624 |
| Total dictionary pages | 14,298 |
| Xref pages | Generated per verse (varies) |
| QA tests passing | 119/119 |
| Verse gaps | 0 (confirmed clean) |

---

## Known Issues Resolved

| Issue | Fix Applied |
|-------|-------------|
| PowerShell regex escaping bug | Changed `\\d+$` to `'\d+$'` |
| Word spacing missing between OSIS `<w>` nodes | Added explicit space after each word node |
| Strong's links used absolute paths | Changed to relative paths (`../../dict/...`) |
| 4-digit Strong's numbers double-padded | Added `[int]` cast before `PadLeft` |
| Greek POS field blank | Removed POS row from Greek pages conditionally |
| Greek KJV field prefixed with `:--` | Stripped with `-replace '^\s*:--\s*', ''` |
| Greek definition had stray newlines | Added `NormalizeText` function |
| Hebrew missing vowel-pointed characters | Changed to use `lemma` attribute |
| Hebrew POS showed raw code (e.g. `n-pr-m`) | Added complete `$posMap` expansion table (27 codes) |
| `git push` rejected due to remote ahead | Resolved with `git pull origin main` then push |
| NT verses missing (68 chapters affected) | Opus fix: `Get-FlattenedNodes` recursive flattener |
| Every English word wrapped as Strong's link | Reverted to old style: plain word + badge after |
| Empty `<w>` nodes producing orphan badges | Added empty word check in `Get-StrongLinkHtml` |
| Space before punctuation (`, .`) | Added regex cleanup in `ConvertTo-VerseHtml` |
| Greek dictionary characters garbled | Switched to `[System.IO.File]::WriteAllText` with UTF8 |
| Strong's badges invisible in dark mode | Solid cyan background, dark text, smaller font |
| QA false failures on single-chapter books | Added `@()` array wrapper to `Get-ChildItem` |
| QA wrong Revelation 22 prev link check | Fixed to check Rev 22->Rev 21, Rev 1->Jude 1 |
| `.\script.ps1` path errors | Always use `pwsh -NoProfile -File .\script.ps1` |

---

## Pending Tasks

### Phase 2 — PC Study Enhancements
- [ ] `js/notes.js` — personal notes system with localStorage + JSON export
- [ ] `start-study.ps1` — PowerShell HTTP server for localhost study session
- [ ] `bake-notes.ps1` — bakes JSON notes into static HTML for Kindle
- [ ] Search functionality — chunked JSON index by letter (`search-index/a.json` etc.)
- [ ] `search.html` — full text search page (PC only, XHR from localhost)

### Phase 3 — EPUB Packaging
- [ ] `package_epub.ps1` — packages HTML output as EPUB for Kindle sideloading
- [ ] Strip `<script src="../../js/notes.js">` tags during EPUB packaging
- [ ] EPUB manifest generation
- [ ] Test on actual Kindle Fire via ADB sideload

### Future Enhancements
- [ ] **Greek Part of Speech data** — STEPBible TSV data as richer source
- [ ] **Strong's number index pages** — `indexes/strongs-hebrew-index.html` etc.
- [ ] **English concordance** — `indexes/english-concordance.html`
- [ ] **Font size control** — CSS classes already in fontsize.js
- [ ] **Per-verse notes/xref pages** — deferred to later phase
- [ ] **Deep-link navigation** — `navigate.html#Gen.3.16` auto-parse and redirect

---

## Complete Book Table

```
 #  OSIS ID   Folder      Full Name                Ch
 1  Gen       01-Gen      Genesis                  50
 2  Exod      02-Exod     Exodus                   40
 3  Lev       03-Lev      Leviticus                27
 4  Num       04-Num      Numbers                  36
 5  Deut      05-Deut     Deuteronomy              34
 6  Josh      06-Josh     Joshua                   24
 7  Judg      07-Judg     Judges                   21
 8  Ruth      08-Ruth     Ruth                      4
 9  1Sam      09-1Sam     1 Samuel                 31
10  2Sam      10-2Sam     2 Samuel                 24
11  1Kgs      11-1Kgs     1 Kings                  22
12  2Kgs      12-2Kgs     2 Kings                  25
13  1Chr      13-1Chr     1 Chronicles             29
14  2Chr      14-2Chr     2 Chronicles             36
15  Ezra      15-Ezra     Ezra                     10
16  Neh       16-Neh      Nehemiah                 13
17  Esth      17-Esth     Esther                   10
18  Job       18-Job      Job                      42
19  Ps        19-Ps       Psalms                  150
20  Prov      20-Prov     Proverbs                 31
21  Eccl      21-Eccl     Ecclesiastes             12
22  Song      22-Song     Song of Solomon           8
23  Isa       23-Isa      Isaiah                   66
24  Jer       24-Jer      Jeremiah                 52
25  Lam       25-Lam      Lamentations              5
26  Ezek      26-Ezek     Ezekiel                  48
27  Dan       27-Dan      Daniel                   12
28  Hos       28-Hos      Hosea                    14
29  Joel      29-Joel     Joel                      3
30  Amos      30-Amos     Amos                      9
31  Obad      31-Obad     Obadiah                   1
32  Jonah     32-Jonah    Jonah                     4
33  Mic       33-Mic      Micah                     7
34  Nah       34-Nah      Nahum                     3
35  Hab       35-Hab      Habakkuk                  3
36  Zeph      36-Zeph     Zephaniah                 3
37  Hag       37-Hag      Haggai                    2
38  Zech      38-Zech     Zechariah                14
39  Mal       39-Mal      Malachi                   4
40  Matt      40-Matt     Matthew                  28
41  Mark      41-Mark     Mark                     16
42  Luke      42-Luke     Luke                     24
43  John      43-John     John                     21
44  Acts      44-Acts     Acts                     28
45  Rom       45-Rom      Romans                   16
46  1Cor      46-1Cor     1 Corinthians            16
47  2Cor      47-2Cor     2 Corinthians            13
48  Gal       48-Gal      Galatians                 6
49  Eph       49-Eph      Ephesians                 6
50  Phil      50-Phil     Philippians               4
51  Col       51-Col      Colossians                4
52  1Thess    52-1Thess   1 Thessalonians           5
53  2Thess    53-2Thess   2 Thessalonians           3
54  1Tim      54-1Tim     1 Timothy                 6
55  2Tim      55-2Tim     2 Timothy                 4
56  Titus     56-Titus    Titus                     3
57  Phlm      57-Phlm     Philemon                  1
58  Heb       58-Heb      Hebrews                  13
59  Jas       59-Jas      James                     5
60  1Pet      60-1Pet     1 Peter                   5
61  2Pet      61-2Pet     2 Peter                   3
62  1John     62-1John    1 John                    5
63  2John     63-2John    2 John                    1
64  3John     64-3John    3 John                    1
65  Jude      65-Jude     Jude                      1
66  Rev       66-Rev      Revelation               22
```

---

## Session Log

---

### Session 1
- **Date:** Prior to 2026-06-08
- **Model:** GitHub Copilot (GPT-4 based) — VS Code
- **Work Done:**
  - Initial project scoping and requirements gathering
  - Created `PLAN.md`, `ARCHITECTURE.md`, custom agent file
  - Designed HTML structure, CSS dark mode stylesheet
  - Created chapter template, sample verse, note and xref pages
  - Set Strong's link color to cyan

---

### Session 2
- **Date:** Prior to 2026-06-08
- **Model:** GitHub Copilot (GPT-4 based) — VS Code
- **Work Done:**
  - Restored session after accidental VS Code close
  - Created `generate_genesis1.ps1` — first working OSIS parser
  - Fixed verse node detection and word spacing bugs
  - Generated Genesis 1 sample chapter and verse pages
  - Created `build.ps1`, `sample-index.html`, GitHub Actions CI

---

### Session 3
- **Date:** 2026-06-08 (morning)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**
  - Reviewed chat transcripts to restore project context
  - Built `generate_dict.ps1` from scratch (Hebrew + Greek)
  - Iteratively fixed Hebrew POS, vowel pointing, Greek phonetic
  - Replaced `strongsgreek.xml` with morphgnt v1.9
  - Fixed Strong's link paths and 4-digit padding bug
  - Created initial `SESSION-NOTES.md`

---

### Session 4
- **Date:** 2026-06-08 (afternoon)
- **Model:** Claude Opus 4.6 (claude.ai) — Architecture consultation
- **Work Done:**
  - Produced full architecture design document (`DESIGN-PROPOSAL.md`)
  - Confirmed folder structure, file naming, relative paths
  - Designed `generate_bible.ps1` architecture (5 phases)
  - Designed `navigate.html` cascading dropdown (ES3)
  - Designed `js/bible-data.js` format
  - Confirmed five key design decisions (A-E)
  - Artifact: https://claude.ai/public/artifacts/d3359f71-aff4-42fd-b59b-d7ad7e847ef0

---

### Session 5
- **Date:** 2026-06-08 (evening) — 2026-06-09
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation)
- **Work Done:**
  - Completed Hebrew POS table — scanned all 27 unique morph codes
  - Added `scan_morph_codes.ps1` diagnostic script
  - Fixed 11 missing POS codes including `n-pr-loc`, `n-pr-m`, `prt` etc.
  - Built `qa-test.ps1` — 11 test suites, 119 tests
  - Built complete `generate_bible.ps1` — all 66 books
  - First full run: 1,189 chapters generated
  - Discovered 68 NT chapters with verse gaps (verses in `<q>` elements)
  - **Opus consultation:** produced `ConvertTo-VerseHtml-Fix.ps1`
    - `Get-FlattenedNodes` recursive flattener
    - Rebuilt `ConvertTo-VerseHtml` using flat node list
    - Updated `Get-StrongLinkHtml`
  - Integrated Opus fix into `generate_bible.ps1`
  - Fixed: empty word nodes, space before punctuation, UTF-8 encoding
  - Fixed: Strong's badge style (solid cyan, dark text, visible in dark mode)
  - Fixed: QA test false failures (single-chapter books, Rev 22 nav check)
  - **Final full run: 1,189 chapters, ZERO verse gaps, 119/119 QA tests passing**
  - Committed everything to GitHub

---

## Notes for Future Sessions

- Always run scripts with `pwsh -NoProfile -File .\script.ps1` not `.\script.ps1`
- Dictionary files are **lowercase** (`h0430.html`, `g3056.html`) — do not change
- All chapter files are exactly **2 levels deep** — all relative paths use `../../`
- **ES3 only** for all JavaScript — no URLSearchParams, no let/const, no arrow functions
- The OSIS XML uses **milestone-style** verse tags (sID/eID) not container tags
- Strong's numbers in OSIS may have extra leading zeros — always cast through `[int]`
- NT verses are nested inside `<q>` elements — `Get-FlattenedNodes` handles this
- Greek POS enhancement is a known future task — STEPBible TSV is recommended source
- Phase 2 (notes system) and Phase 3 (EPUB packaging) are the next major milestones
- The `notes.js` script tag must be stripped during EPUB packaging (not optional)
- Search is PC-only via localhost — XHR from `file://` URLs is blocked by browsers
