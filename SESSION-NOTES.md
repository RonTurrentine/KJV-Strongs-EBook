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
| Strong's links | Cyan color (`#00bcd4`) | Easier to distinguish on dark background |
| Note superscript | `¹` | Personal study notes per verse |
| Cross-ref superscript | `✝` | Custom cross-references per verse |
| Notes/xrefs | Date/time stamped | Study tracking |
| Navigation | Per-chapter links + cascading dropdown | Touch-friendly on Kindle |
| Indexes | Strong's number index + English concordance (planned) | Study tools |
| Bookmarking | localStorage JS (planned) | Remember last reading position |
| Folder structure | `books/{NN}-{Abbr}/{ch}.html` — NO `ot/`/`nt/` layer | Simpler relative paths |
| Chapter filenames | `1.html`, `2.html` (plain numbers) | Simpler, prev/next math trivial |
| Dictionary case | Lowercase (`h0430.html`, `g3056.html`) | Already generated; consistent |
| Verse zoom page | Deferred — chapter anchors sufficient for now | Reduces complexity |
| Notes/xrefs in full Bible | Deferred to later phase | Core Bible first |
| JavaScript compatibility | ES3 only — no `let`/`const`/arrow functions/`URLSearchParams` | Android 2.x WebKit |

---

## Confirmed Folder Structure (from Opus Design Session)

```
kjv-strongs-html/
│
├── index.html                        # Book table-of-contents
├── navigate.html                     # Cascading Book → Chapter → Verse navigator
├── SESSION-NOTES.md                  # This file
│
├── css/
│   └── style.css                     # Shared dark-mode stylesheet
│
├── js/
│   ├── bible-data.js                 # Generated: book/chapter/verse metadata
│   └── navigation.js                 # Existing nav helpers
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
└── indexes/
    ├── strongs-hebrew-index.html
    ├── strongs-greek-index.html
    └── english-concordance.html
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
| Hebrew index | `../../indexes/strongs-hebrew-index.html` |

### From a dictionary page (`dict/hebrew/h0430.html`)

| Target | Relative path |
|--------|---------------|
| CSS stylesheet | `../../css/style.css` |
| Book index | `../../index.html` |

### From `navigate.html` (root level)

| Target | Relative path |
|--------|---------------|
| CSS stylesheet | `css/style.css` |
| JS data file | `js/bible-data.js` |
| Any chapter page | `books/01-Gen/1.html#verse-3` |

---

## Constraints

- **Kindle Fire Android 2.x WebKit** — no flexbox, no CSS grid, no ES6 JavaScript
- **ES3 JavaScript only** — no `let`, `const`, arrow functions, `URLSearchParams`,
  `Array.from`, `querySelector` (use `getElementById`), `addEventListener` with options
- All files must work as **local static files** (no absolute paths, no server)
- Verse anchors use format `id="verse-1"`, `id="verse-2"` etc.
- Unicode Hebrew and Greek must render correctly
- Font size should be adjustable (older reader, small screen)
- Screen size: 7.5 x 4.75 inches
- Select elements: `width: 100%; padding: 10px; font-size: 18px; min-height: 44px`

---

## Files Created / Generated

### Scripts
| File | Purpose |
|------|---------|
| `generate_genesis1.ps1` | Parses `kjv.osis.xml`, generates Genesis 1 chapter + verse HTML pages (prototype) |
| `generate_dict.ps1` | Parses Hebrew and Greek lexicon XMLs, generates one HTML page per Strong's entry |
| `generate_bible.ps1` | **TO BE WRITTEN** — full Bible generator (all 66 books) |
| `build.ps1` | Makefile-style helper for common tasks (generate, validate, preview, ci) |
| `testosis.ps1` | Early test script for navigating OSIS XML structure |

### Generated Output
| Path | Description |
|------|-------------|
| `sample-chapter-gen1.html` | Prototype Genesis 1 chapter page (all 31 verses) |
| `sample-verse-gen1.html` | Prototype Genesis 1 verse viewer (JS-driven) |
| `dict/hebrew/h0001.html` … `h8674.html` | ~8,674 Hebrew Strong's dictionary pages |
| `dict/greek/g0001.html` … `g5624.html` | ~5,624 Greek Strong's dictionary pages |
| `sample-note-gen1-*.html` | Sample personal note pages for Genesis 1:1–1:31 |
| `sample-xref-gen1-*.html` | Sample cross-reference pages for Genesis 1:1–1:31 |

### Templates / Static Pages
| File | Purpose |
|------|---------|
| `chapter-template.html` | HTML template for chapter pages |
| `sample-verse.html` | Hand-crafted sample verse with Strong's links |
| `index.html` | Project home page / demo entrypoint (to be replaced by generated TOC) |
| `sample-index.html` | Navigation hub for Genesis 1 sample pages |
| `css/style.css` | Shared dark-mode stylesheet |
| `js/navigation.js` | Preserves chapter return anchors via query params |

### Documentation
| File | Purpose |
|------|---------|
| `PLAN.md` | Project phases and task checklist |
| `ARCHITECTURE.md` | Detailed design decisions and HTML structure spec |
| `README.md` | Repository overview and usage instructions |
| `SESSION-NOTES.md` | This file — full project context and session log |
| `.github/agents/kjv-strongs-converter.agent.md` | Custom agent definition for VS Code Copilot |
| `.github/workflows/ci.yml` | GitHub Actions CI — runs generator and validates output |

---

## Known Issues Resolved

| Issue | Fix Applied |
|-------|-------------|
| PowerShell regex `\\d+$` in single-quoted string not matching verse numbers | Changed to `'\d+$'` |
| Word spacing missing between OSIS `<w>` nodes | Added explicit space after each word node |
| Strong's links used absolute paths (`/dict/hebrew/...`) | Changed to relative paths (`dict/hebrew/...`) |
| 4-digit Strong's numbers double-padded (e.g. `h07225.html` vs `h7225.html`) | Added `[int]` cast before `PadLeft` to strip leading zeros from OSIS data |
| Greek POS field blank (not in morphgnt source data) | Removed POS row from Greek dictionary pages conditionally |
| Greek KJV field prefixed with `:--` artifact | Stripped with `-replace '^\s*:--\s*', ''` |
| Greek definition had stray newlines | Added `NormalizeText` function to collapse whitespace |
| Hebrew missing vowel-pointed characters | Changed to use `lemma` attribute instead of `InnerText` |
| Hebrew POS showed raw code (e.g. `n-m`) | Added `$posMap` expansion table |
| `git push` rejected due to remote ahead of local | Resolved with `git pull origin main` then `git push` |

---

## Known Issues — To Fix in `generate_bible.ps1`

| Issue | Required Fix |
|-------|-------------|
| `URLSearchParams` not available on Android 2.x | Replace with ES3 manual query string parser |
| Strong's link paths must use `../../dict/` prefix | All chapter files are 2 levels deep |
| Cross-book navigation requires flat chapter list | Build ordered array of all 1,189 chapters first |

---

## Pending Tasks

### Immediate
- [ ] **`generate_bible.ps1`** — Opus 4.6 writing this script; decisions confirmed:
  - No `ot/`/`nt/` folder layer
  - Plain chapter filenames (`1.html`, `2.html`)
  - Lowercase dictionary filenames (`h0430.html`)
  - No verse zoom page
  - No notes/xrefs in this phase
- [ ] **`navigate.html`** — cascading Book → Chapter → Verse dropdowns (ES3 JS)
- [ ] **`js/bible-data.js`** — generated file with verse counts per chapter per book
- [ ] **Test with Ruth first** (4 chapters only) before full 66-book run
- [ ] **End-to-end Kindle test** — verify Genesis 50 → Exodus 1, OT→NT boundary,
      Revelation 22 (no next), and dictionary links from both testaments
- [ ] **Greek Strong's link verification** — test with a NT chapter

### Future Enhancements
- [ ] **Full text search** — deferred; needs design consultation on index size vs.
      Kindle Fire performance tradeoffs
- [ ] **Greek Part of Speech data** — current morphgnt source doesn't include structured
      POS; investigate STEPBible TSV data as a richer alternative source
- [ ] **Strong's number index pages** — `indexes/strongs-hebrew-index.html` and
      `indexes/strongs-greek-index.html`
- [ ] **English concordance** — `indexes/english-concordance.html`
- [ ] **Bookmarking** — localStorage JS to remember last reading position
- [ ] **Font size control** — adjustable font size for older reader on small screen
- [ ] **Per-verse notes/xref pages** — deferred to later phase after core Bible works
- [ ] **Deep-link navigation** — `navigate.html#Gen.3.16` auto-parse and redirect
- [ ] **EPUB packaging** — Calibre conversion of finished HTML output to EPUB for
      Kindle sideloading via ADB

---

## Complete Book Table (for `generate_bible.ps1` `$BookTable`)

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
  - Created custom agent file (`kjv-strongs-converter.agent.md`)
  - Created `PLAN.md` and `ARCHITECTURE.md`
  - Designed HTML structure: verse layout, Strong's links, superscript note/xref links
  - Created `chapter-template.html`, `sample-verse.html`, `sample-note-gen1-1.html`,
    `sample-xref-gen1-1.html`
  - Created `css/style.css` with dark mode styling
  - Set Strong's link color to cyan (`#00bcd4`)
  - Added date/time stamp support to note and cross-reference pages

---

### Session 2
- **Date:** Prior to 2026-06-08
- **Model:** GitHub Copilot (GPT-4 based) — VS Code (continued after accidental close)
- **Work Done:**
  - Restored session after accidental VS Code close
  - Set VS Code UI font size to 18 (`window.zoomLevel: 1`, `editor.fontSize: 18`)
  - Created `generate_genesis1.ps1` — first working OSIS parser
  - Debugged verse node detection (milestone vs. container OSIS structure)
  - Fixed PowerShell regex escaping bug (`\\d+$` → `'\d+$'`)
  - Fixed word spacing between `<w>` nodes
  - Successfully generated `sample-chapter-gen1.html` and `sample-verse-gen1.html`
    for all 31 verses of Genesis 1
  - Created `build.ps1` helper script
  - Created `sample-index.html` navigation hub
  - Added GitHub Actions CI workflow

---

### Session 3
- **Date:** 2026-06-08 (morning/afternoon)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**
  - Reviewed Chat1.txt and Chat2.txt transcripts to restore project context
  - Connected to GitHub repository for file access
  - Assessed current project state — confirmed Genesis 1 generator working
  - **Dictionary generator** (`generate_dict.ps1`) — written from scratch:
    - Parses `StrongHebrewG.xml` (OSIS format) for Hebrew entries
    - Parses `strongsgreek.xml` for Greek entries
    - Generates one HTML page per entry under `dict/hebrew/` and `dict/greek/`
  - Iteratively improved dictionary output:
    - Added Hebrew POS expansion table (`n-m` → `Noun Masculine` etc.)
    - Fixed Hebrew to use `lemma` attribute for fully vowel-pointed characters
    - Fixed Greek phonetic extraction (`<pronunciation strongs="...">` element)
    - Made POS row conditional (hidden when empty)
    - Stripped `:--` prefix from Greek KJV usage field
    - Added `NormalizeText` to collapse stray newlines in definitions
  - **Replaced `strongsgreek.xml`** with morphgnt v1.9 (more complete data):
    - Now includes `<strongs_derivation>` (origin/etymology) field
    - Better proof-read against printed Strong's dictionary
    - CC0 Public Domain license
    - Added `Resolve-StrongsRefs` function to convert `<strongsref>` tags to
      readable text (e.g. `G3004`) in definitions and derivations
  - **Fixed `generate_genesis1.ps1`**:
    - Changed Strong's link paths from absolute (`/dict/hebrew/...`) to
      relative (`dict/hebrew/...`)
    - Added Greek Strong's link support (`strong:G` codes)
    - Fixed 4-digit number padding bug (`[int]` cast before `PadLeft`)
  - Committed all changes to GitHub; resolved `git push` rejection via `git pull`
  - Discussed model strategy — Sonnet for coding, Opus for architecture decisions
  - Created initial `SESSION-NOTES.md`

---

### Session 4
- **Date:** 2026-06-08 (afternoon/evening)
- **Model:** Claude Opus 4.6 (claude.ai) — Architecture consultation
- **Work Done:**
  - Reviewed full project context and GitHub repository
  - Produced architecture diagram (image) showing complete system overview
  - Produced full design document covering:
    - Revised folder structure (`books/{NN}-{Abbr}/{ch}.html`)
    - Complete file naming convention table
    - Full relative path map for every file relationship
    - `generate_bible.ps1` script architecture (5 phases)
    - Flat chapter list concept (1,189 entries, key to cross-book navigation)
    - Chapter HTML template
    - `js/bible-data.js` format (ES3-compatible, ~15KB)
    - `navigate.html` cascading dropdown design
    - ES3 JavaScript compatibility requirements
    - Performance/size estimates (~90-175MB total uncompressed)
    - Complete 66-book table with OSIS IDs, folder names, chapter counts
    - Six critical bug fixes identified
    - Recommended implementation order (Ruth first as test book)
  - **Five design decisions confirmed (by Ron + Sonnet review):**
    - A: Drop `ot/`/`nt/` folder layer ✅
    - B: Plain chapter filenames `1.html`, `2.html` ✅
    - C: Keep lowercase dictionary filenames (`h0430.html`) ✅
    - D: No verse zoom page — chapter anchors sufficient ✅
    - E: Defer notes/xrefs to later phase ✅
  - Artifact URL: https://claude.ai/public/artifacts/d3359f71-aff4-42fd-b59b-d7ad7e847ef0

---

## Notes for Future Sessions

- Always fetch key scripts from GitHub at the start of a session to ensure
  working from the latest versions
- The OSIS XML uses **milestone-style** verse tags (sID/eID attributes) not
  container tags — the generator handles this correctly already
- Strong's numbers in OSIS data may have extra leading zeros (e.g. `strong:H07225`)
  — always cast through `[int]` before padding to avoid double-zero filenames
- Dictionary files are **lowercase** (`h0430.html`, `g3056.html`) — do not change
- All chapter files are exactly **2 levels deep** (`books/{folder}/{ch}.html`) so
  all relative paths from chapters use `../../` prefix
- **ES3 only** for all JavaScript — no URLSearchParams, no let/const, no arrow
  functions, no forEach, use getElementById not querySelector
- Greek POS enhancement is a known future task — STEPBible TSV data is the
  recommended source to investigate
- Full text search is deferred — needs Opus consultation on index size vs.
  Kindle Fire performance tradeoffs
- Test with **Ruth** (4 chapters) before running the full 66-book generator
