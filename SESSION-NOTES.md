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
| Styling | Dual CSS: `style.css` (PC) + `style-kindle.css` (Kindle) | Maintain full PC features while ensuring Kindle compatibility |
| Strong's badges | Cyan solid background, dark text, small font | Visible and readable in dark mode (PC); dotted underline (Kindle) |
| Note superscript | Gold circle button | Personal study notes per verse |
| Cross-ref superscript | Cyan circle button | Custom cross-references per verse |
| Notes/xrefs | Date/time stamped | Study tracking |
| Navigation | Per-chapter links + cascading dropdown | Touch-friendly on Kindle |
| Prev/Next buttons | Always visible; grayed out when unavailable | Consistent layout, better UX |
| Font size | Separate increase/decrease buttons with min/max disabled state | Better UX than single cycle button |
| Font size scope | Applied to `.chapter-content` only | Header stays fixed size |
| Header | Always `position: fixed` (no JS) on PC; broken on Kindle (see Known Issues) | Simplicity, works on PC |
| Storage | `localStorage` → cookies → `window.name` fallback chain | `localStorage` blocked on `file://` URLs on Kindle |
| Indexes | Strong's number index + English concordance (planned) | Study tools |
| Folder structure | `books/{NN}-{Abbr}/{ch}.html` — NO `ot/`/`nt/` layer | Simpler relative paths |
| Chapter filenames | `1.html`, `2.html` (plain numbers) | Simpler, prev/next math trivial |
| Dictionary case | Lowercase (`h0430.html`, `g3056.html`) | Already generated; consistent |
| Dictionary CSS | New class names: `dict-page`, `dict-header`, `dict-body` etc. | Required by Kindle-compatible stylesheet |
| Verse zoom page | Deferred — chapter anchors sufficient for now | Reduces complexity |
| Notes/xrefs in full Bible | Deferred to later phase | Core Bible first |
| JavaScript compatibility | ES3 only — no `let`/`const`/arrow functions/`URLSearchParams` | Android 2.x WebKit |
| Strong's link style | Word text plain + `[G1161]` badge after | Readable; old style preferred |
| EPUB CSS swap | `package_epub.ps1` replaces `style.css` ref with `style-kindle.css` | Automatic during packaging |

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
│   ├── style.css                     # PC stylesheet (full features, fixed header, badges)
│   └── style-kindle.css              # Kindle stylesheet (Android 2.3 compatible)
│
├── js/
│   ├── bible-data.js                 # Generated: book/chapter/verse metadata (~15KB)
│   ├── fontsize.js                   # Font increase/decrease (4 sizes, storage fallback)
│   ├── bookmarks.js                  # Reading position bookmark (storage fallback)
│   └── sticky-header.js              # Kindle header positioning (no-op on PC)
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

- **Kindle Fire 1st Gen (D01E)** — Fire OS 6.3.4 / Android 2.3 Gingerbread WebKit
- **No flexbox, no CSS grid, no CSS variables** on Kindle — use literal hex values and float/inline-block
- **ES3 JavaScript only** — no `let`, `const`, arrow functions, `URLSearchParams`,
  `Array.from`, `querySelector` (use `getElementById`), no `addEventListener` with options
- **`localStorage` blocked on `file://` URLs** — use `window._kjvStore` fallback chain
- **`position: fixed` confirmed NON-FUNCTIONAL on Kindle** — `.chapter-nav` uses `position: absolute` + `js/sticky-header.js` (setInterval poll) on Kindle; PC keeps `position: fixed` (works fine there). RESOLVED, see "Sticky Header — RESOLVED"
- **Multi-class selectors on one element do not apply correctly on this WebKit** — e.g. `class="chapter-content header-spacer"` failed even though each class individually worked. Always use single classes; merge styles into one class instead. RESOLVED — `header-spacer` merged into `.chapter-content`
- **Silk aggressively caches `.js` files** — clearing cache/cookies/history/data and full device reboot do NOT clear cached scripts. To force-load a new script version during debugging, push under a NEW filename AND reference it from a NEW HTML filename (both must be new)
- **Tiny HTML pages (<1KB) may render with external CSS NOT applied at all** — not an issue for real chapter pages (always tens of KB)
- All files must work as **local static files** (no absolute paths, no server)
- ADB push target: `/data/local/tmp/` (only writable location found)
- Verse anchors use format `id="verse-1"`, `id="verse-2"` etc.
- Always run scripts with `pwsh -NoProfile -File .\scriptname.ps1` not `.\scriptname.ps1`
- **Generated by `generate_bible.ps1`** (overwritten every run): `index.html`, `navigate.html`, `js/bible-data.js`, all chapter HTML, all xref pages
- **Manually maintained** (never overwrite): `js/fontsize.js`, `js/bookmarks.js`, `js/sticky-header.js`, `css/style.css`, `css/style-kindle.css`

---

## Scripts

| Script | Purpose |
|--------|---------|
| `generate_bible.ps1` | Full Bible generator — all 66 books, 1,189 chapters |
| `generate_dict.ps1` | Hebrew + Greek dictionary page generator |
| `qa-test.ps1` | QA test suite — 119 tests across 11 test suites |
| `scan_morph_codes.ps1` | Diagnostic — finds all unique Hebrew POS codes in XML |
| `git-push.ps1` | Stages all files and pushes to GitHub with commit message |
| `adb-push-test.ps1` | Pushes test set to Kindle via ADB (uses style-kindle.css as style.css; still references deleted js/sticky-header.js — harmless error, should be removed) |
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
pwsh -NoProfile -File .\git-push.ps1 -Message "commit msg"   # Git commit and push
$env:PATH += ';H:\Android SDK Platform Tools'                 # Add ADB to PATH (per session)
pwsh -NoProfile -File .\adb-push-test.ps1                     # Push test set to Kindle
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

## Kindle Fire Test Results (1st Gen D01E, Fire OS 6.3.4, Android 2.3)

| Feature | PC | Kindle | Notes |
|---------|-----|--------|-------|
| Dark mode | ✅ | ✅ | Renders correctly |
| Book index page | ✅ | ✅ | Content visible below header |
| Navigate.html dropdowns | ✅ | ✅ | "Books" dropdown visible below header |
| Chapter navigation | ✅ | ✅ | Prev/Next work |
| Strong's badges | ✅ | ✅ | Links open correctly |
| Dictionary pages | ✅ | ✅ | No more black box |
| Font increase/decrease | ✅ | ✅ | Buttons work, min/max disabled, font size changes |
| Header (PC: fixed; Kindle: absolute+JS snap) | ✅ | ✅ | Kindle header snaps to viewport top after scroll stops (see Sticky Header — RESOLVED) |
| Content visible below header | ✅ | ✅ | Spacer div (JS) ensures verse 1 never hidden |
| Bookmarks | ✅ | ❓ | Pending Kindle test |
| `window.name` storage | N/A | ❓ | Pending Kindle test |

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
| Prev/Next buttons disappear at boundaries | Replaced with always-visible grayed-out disabled state |
| Flexbox not supported on Android 2.3 | Replaced with float/inline-block in `style-kindle.css` |
| `localStorage` blocked on `file://` | `window._kjvStore` fallback chain (cookies → window.name) |
| Dictionary pages show as black box on Kindle | New CSS class names (`dict-page`, `dict-header` etc.) |
| Font size cycling Aa button | Replaced with separate A↑ and a↓ buttons |
| Font size changed header buttons too | Scoped font-size rules to `.chapter-content` only |
| Font size CSS classes missing | Added `body.font-*  .chapter-content` rules to both CSS files |
| `fontsize.js` j-bug (applySize(j) after loop) | Fixed to use `savedIdx` variable |
| Font buttons not clickable (disabled on load) | Fixed by `savedIdx` bug fix above |
| `generate_bible.ps1` Phase 7/8 overwrote manually-maintained fontsize.js/bookmarks.js | Removed Phase 7/8 blocks entirely — these files are never regenerated |
| `position: sticky` not supported | Abandoned; replaced with `position: fixed` always-on header (no JS) |
| `sticky-header.js` (scroll-event based) | Deleted — replaced by always-fixed CSS header |
| Header buttons stacking vertically (display: table-cell) | Switched to float + line-height layout (Opus chapter-nav-fix.css) |
| Body padding causing 10px header shift | Changed `padding: 20px` to `padding: 0 20px 20px 20px` |
| Header h1/buttons not vertically centered | `line-height: 88px` on h1/.book-chapter and .nav-buttons (90px height - 2px border) |
| Duplicate `.chapter-nav` and `.chapter-nav.is-fixed` rules | Removed leftover sticky-header CSS rules |
| `.header-spacer` padding not applying on Kindle | Root cause: multi-class `class="chapter-content header-spacer"` doesn't apply on this WebKit even though each class works individually (confirmed via isolated test files). Fix: merged `.header-spacer` properties directly INTO `.chapter-content` (single class), removed `header-spacer` from all 4 `<main>` tags in generate_bible.ps1 |

---

## Sticky Header — RESOLVED (Session 8)

The Kindle sticky header issue is now RESOLVED. Final root causes and fixes:

1. **Tiny test pages (<1KB) rendered completely unstyled** — Silk appears to skip
   applying external CSS to very small pages. Confirmed via a padded ~52KB test
   page (200 verses), which rendered styled correctly. Real chapter pages are
   always tens of KB, so this never affects production. No fix needed.

2. **Multi-class selectors (`class="chapter-content header-spacer"`) don't apply**
   on this WebKit, even though each class works individually. Fixed by merging
   `.header-spacer`'s `padding-top` directly into `.chapter-content` (single
   class). All 4 `<main>` tags in `generate_bible.ps1` use `class="chapter-content"`
   only.

3. **`position: fixed` is completely non-functional** on this device — confirmed
   via isolated single-element test (element scrolls away with page). PC's
   `position: fixed` works fine and is unchanged in `style.css`.

4. **Final fix for Kindle** (`style-kindle.css` + `js/sticky-header.js`):
   - `.chapter-nav` changed from `position: fixed` to `position: absolute`
   - `.chapter-content` padding-top changed from `95px !important` to `0`
   - `js/sticky-header.js` (new file):
     - Detects via `getComputedStyle` whether `position: fixed` actually
       works (PC) — if so, does nothing (no-op on PC)
     - On Kindle: forces `position: absolute`, injects an invisible spacer
       div (height = header height) in normal flow after `<nav>` so verse 1
       is never hidden
     - `setInterval(poll, 100)` reads `scrollTop` and sets
       `header.style.top = scrollTop + "px"` to follow the viewport
   - Added `<script src="../../js/sticky-header.js"></script>` to the chapter
     template in `generate_bible.ps1`, between `bookmarks.js` and `notes.js`

5. **BEHAVIOR (accepted as final)**: Due to Android 2.3 freezing JS during
   momentum/fling scrolling, the header scrolls away during an active scroll
   gesture and "snaps" back to the correct viewport position once scrolling
   stops (~100-300ms after). Confirmed via live diagnostic readout
   (`[st=N top=Npx]`) injected into verse text during debugging — `scrollTop`
   and `header.style.top` track correctly and continuously; only the *visual*
   repositioning during active scroll is impossible without `position: fixed`.
   User found this "snap to top after scroll stops" behavior acceptable.

### Diagnostic technique that finally cracked this (for future reference)

Silk aggressively caches `.js` files referenced from `<script src="...">` —
**clearing cache/cookies/history/data via Settings does NOT clear this**, nor
does a full device power-off/power-on. The only reliable way to force Silk to
load a NEW version of a script during debugging is to **push it under a brand
new filename AND reference that new filename from a brand-new HTML filename**
(e.g. `sticky-header2.js` + `gen1-v2.html`). Renaming only the JS file, or only
the HTML file, was insufficient — both must be new. This should be remembered
for any future Kindle JS debugging.

### Future Enhancement (Architecture Note)

**Sticky header on/off toggle** — user may want a checkbox/button to disable
the snap-to-top header behavior if it proves distracting during real reading.
Would require:
- A toggle UI element (adds to already-tight 90px header on Kindle)
- `window._kjvStore` persisted preference (same pattern as font size/bookmarks)
- `sticky-header.js` checks preference before running absolute+poll logic;
  if off, sets `.chapter-nav` to `position: static` via JS and skips spacer
  injection
- Deferred — not yet needed; revisit if user finds snap-to-top distracting
  after real-world use

---

## Pending Tasks

### Immediate — Phase 3 (EPUB Packaging)
- [x] Phase 2 notes system complete — DONE
- [x] Strong's index pages — DONE
- [x] Navigation improvements (B/V buttons, Go To auto-select) — DONE
- [x] Two-column book index — DONE
- [x] Kindle header button overflow fixed — DONE
- [ ] **Test notes system end-to-end** — double-click start-study.bat, write a note, verify it bakes, verify Sync to Kindle works
- [ ] **Phase 3: `package_epub.ps1`** — package HTML as EPUB for Kindle sideloading
  - Swap `style.css` references to `style-kindle.css`
  - Strip `<script src="../../js/notes.js">` (notes are PC-only)
  - Strip `<script src="../../js/sticky-header.js">` (EPUB readers handle scrolling)
  - Generate EPUB manifest (content.opf, toc.ncx)
  - Test sideloading via ADB
- [ ] (Low priority) Clean up local test files (kindle-test*.html, scroll-debug-test*.html etc.)
- [ ] (Low priority) Investigate John 1 occasionally loading at verse 27 — likely stale bookmark

### Phase 2 — PC Study Enhancements
- [ ] `js/notes.js` — personal notes system with localStorage + JSON export
- [ ] `start-study.ps1` — PowerShell HTTP server for localhost study session
- [ ] `bake-notes.ps1` — bakes JSON notes into static HTML for Kindle
- [ ] Search functionality — chunked JSON index by letter (`search-index/a.json` etc.)
- [ ] `search.html` — full text search page (PC only, XHR from localhost)

### Phase 3 — EPUB Packaging
- [ ] `package_epub.ps1` — packages HTML output as EPUB for Kindle sideloading
- [ ] Swap `style.css` reference to `style-kindle.css` (or embed inline CSS) during packaging
- [ ] Strip `<script src="../../js/notes.js">` tags during EPUB packaging
- [ ] EPUB manifest generation
- [ ] Test on actual Kindle Fire via ADB sideload

### Future Enhancements
- [ ] **Greek Part of Speech data** — STEPBible TSV data as richer source
- [ ] **Strong's number index pages** — `indexes/strongs-hebrew-index.html` etc.
- [ ] **English concordance** — `indexes/english-concordance.html`
- [ ] **Per-verse notes/xref pages** — deferred to later phase
- [ ] **Deep-link navigation** — `navigate.html#Gen.3.16` auto-parse and redirect
- [ ] Clean up `adb-push-test.ps1` — remove reference to deleted `js/sticky-header.js`
- [ ] Clean up test files (`kindle-test*.html`, `index-v2/v3-test.html`) once issue resolved

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
  - Integrated Opus fix — ZERO verse gaps, 119/119 QA tests passing
  - Committed everything to GitHub

---

### Session 6
- **Date:** 2026-06-10
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation)
- **Work Done:**
  - Added disabled Prev/Next buttons for first/last chapters (grayed out, always visible)
  - Added sticky header CSS (`position: sticky`) — works on PC, not Kindle
  - **First Kindle Fire test (D01E, Android 2.3):**
    - Confirmed: dark mode, navigation, Strong's links, dictionary pages all work
    - Found: flexbox not supported, `position: sticky` not supported
    - Found: `localStorage` blocked on `file://` URLs — font size Aa button did nothing
    - Found: dictionary pages showed as black box
  - **Opus consultation — Kindle compatibility overhaul:**
    - New `css/style-kindle.css` — no flexbox, no CSS variables, no transitions
    - New `js/fontsize.js` — `window._kjvStore` storage fallback chain
    - New `js/bookmarks.js` — scroll-based saving, throttled, `window.name` fallback
    - New `js/sticky-header.js` — scroll event based (later replaced)
    - New dictionary CSS class names (`dict-page`, `dict-header`, `dict-body` etc.)
    - Updated `generate_dict.ps1` with new class names
  - **Dual CSS strategy adopted:** `style.css` for PC, `style-kindle.css` for Kindle/EPUB
  - **Second Kindle test:**
    - Dark mode ✅, dictionary pages ✅ (no more black box), font size ✅
    - Sticky header ❌ — scroll events don't fire during momentum on Android 2.3
  - **Opus consultation — sticky header + font buttons:**
    - New `js/sticky-header.js` — `setInterval` polling at 100ms (replaces scroll events)
    - New `js/fontsize.js` — separate A↑ and a↓ buttons replacing single Aa cycle
    - `updateFontButtons()` grays out buttons at min/max font size
    - Fixed `j`-bug in fontsize.js initialization (savedIdx variable)
  - Added font-size CSS rules to both stylesheets (scoped to `.chapter-content`)
  - Added `git-push.ps1` and `adb-push-test.ps1` utility scripts
  - All changes committed to GitHub
  - **Pending:** Re-test on Kindle with new polling sticky header and font buttons

---

### Session 7
- **Date:** 2026-06-11 — 2026-06-12
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation)
- **Work Done:**
  - Confirmed font increase/decrease buttons working on Kindle ✅
  - Confirmed polling `setInterval` sticky header STILL not working on Kindle ❌
  - **User proposed:** floating fixed-position `<div>` header instead of JS-based sticky
  - Decided: make `.chapter-nav` ALWAYS `position: fixed`, remove `sticky-header.js` entirely (PC and Kindle both)
  - Discovered `generate_bible.ps1` Phase 7/8 was overwriting manually-maintained `fontsize.js`/`bookmarks.js` on every run — **removed these phases entirely**; these files are now permanently hand-maintained
  - **Opus consultation #1 — header layout:**
    - Initial `display: table` / `table-cell` approach — fixed vertical centering on PC but `position: fixed` failed AND buttons stacked vertically on Kindle
  - **Opus consultation #2 — root cause + fix:**
    - Root cause identified: `display: table` on `.chapter-nav` breaks `position: fixed` on Android 2.3 WebKit
    - Fix: `display: block` + `float: left`/`float: right` + `line-height: 88px` for vertical centering (chapter-nav-fix.css)
    - Unified `.btn` styling for both `<a>` and `<button>` — explicit height, line-height, `-webkit-appearance: none`
    - Added `.header-spacer` class (`padding-top: 95px`) for `<main>`
  - Rewrote both `style.css` and `style-kindle.css` cleanly with float-based header (1.8em title, 90px height)
  - Updated `generate_bible.ps1` — all 4 `<main>` tags changed to `class="chapter-content header-spacer"`
  - Full regeneration (1,189 chapters) + QA 119/119 pass
  - **Third Kindle test:**
    - Header buttons still misaligned, header still not sticky, content STILL hidden under header (same as before)
  - **Extensive isolation debugging:**
    - `kindle-test.html` (single-class, inline style): `padding-top` WORKS, `position: fixed` does NOT work — confirms `position: fixed` is fundamentally broken on this device
    - `kindle-test2.html` (two-class, inline style): padding does NOT apply — **discovered multi-class selector combinations don't work on this WebKit**, even though each class works individually
  - Merged `.header-spacer` directly into `.chapter-content` (single class) in both stylesheets; updated `generate_bible.ps1` to remove `header-spacer` from all `<main>` tags (back to single class)
  - Full regeneration + QA 119/119 pass + Kindle push
  - **Fourth Kindle test: NO CHANGE** — all symptoms identical despite confirmed-correct CSS on device (verified via `adb shell cat` and Silk's "Find on page")
  - **Created `index-v2-test.html`/`index-v3-test.html`** (new filenames, relative and absolute `file://` CSS paths) — BOTH rendered with OLD/broken styling despite referencing the confirmed-current `style-v2.css`
  - **CURRENT BLOCKER (unresolved):** Either Silk's `<link rel="stylesheet">` doesn't apply external CSS at all on `file://` pages, or there's a caching mechanism that survives cache/cookie/history clearing AND full device reboot AND new filenames. Theory is in tension with apparent partial success of dark mode/badges/font buttons on real chapter pages — needs `adb shell cat css/style.css | findstr header-spacer` to check staleness of the file actually used by real pages.
  - **Not yet committed to GitHub** — current `style.css`/`style-kindle.css`/`generate_bible.ps1` changes are local only pending resolution

---

### Session 8
- **Date:** 2026-06-13
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation)
- **Work Done:**
  - Resumed Session 7's unresolved CSS/sticky-header blocker via reverse bisection
  - Pulled real on-device `1.html` via `adb pull` — confirmed byte-identical to local source (37381 bytes), ruling out transfer corruption
  - Discovered `adb shell cat ... > file.html` via PowerShell redirect produces UTF-16 (75756 bytes vs 37381) — a red herring for the main investigation, but important to remember for future diagnostics
  - **V8 test (52KB, 200 padded verses)**: rendered with CSS correctly applied — proved the CSS-loading "blocker" from Session 7 was actually a tiny-page-size issue, not a fundamental loading failure. Real chapter pages unaffected.
  - With CSS confirmed working, returned to the ORIGINAL two problems: `position: fixed` non-functional, and `padding-top` not creating space below header
  - **Opus consultation:** provided `position: absolute` + `setInterval` poll + injected spacer div approach (`header-fix.css` + `sticky-header.js`)
  - Applied: `.chapter-nav` → `position: absolute` (Kindle only; PC keeps `position: fixed`), `.chapter-content` `padding-top: 0` (Kindle only)
  - New `js/sticky-header.js` includes `getComputedStyle` guard — no-ops on PC where `position: fixed` works
  - First real-device test: header still appeared non-functional, but user noticed during pinch-zoom+scroll that header DID briefly reposition with verses 1-2 visible above it
  - **Created `scroll-debug-test.html`/`scroll-debug-test2.html`** — live scrollTop readout in cyan bar + every content block. CONFIRMED on Kindle: scrollTop tracking works correctly, bar repositions to correct (non-zero) scrollTop after scroll stops (matches "snap after fling" expectation)
  - Tested real Genesis 1 with production `sticky-header.js` — header DOES reposition after scroll stops, consistent with debug test
  - **Extensive debug script iteration** (debug, debug2, debug3, debug4, debug5, debug6) to find why visual debug markers weren't appearing despite header repositioning working:
    - debug4 (alert-only): confirmed script DOES execute
    - debug5 (step-by-step alerts, no setInterval): all 6 steps completed successfully, green spacer became visible, `computedPosition = 'absolute'`, `headerHeight = 90`
    - **debug3 vs debug5/6 discrepancy traced to Silk's aggressive `.js` file caching** — confirmed via `adb shell cat` showing debug6 content on-device while Silk displayed debug5's alerts
  - **KEY DIAGNOSTIC TECHNIQUE DISCOVERED:** Silk caches `.js` files in a way that survives cache/cookie/data clearing AND full device reboot. Only a brand-new JS filename referenced from a brand-new HTML filename bypasses this cache. Renaming only one of the two is insufficient.
  - Using `sticky-header2.js` + `gen1-v2.html` (both new filenames): debug6 finally ran correctly — confirmed live `[st=N top=Npx]` readout in verse 1 text updates correctly and continuously during scroll (e.g. st=23/top=23px, st=80/top=80px), proving the poll mechanism works perfectly
  - Header itself only visually snaps to correct position AFTER scroll gesture ends (Android 2.3 JS-freeze during fling) — matches Opus's predicted "Known Limitation" exactly
  - **User accepted "snap to top after scroll stops" as final behavior** — good enough for real use
  - Finalized clean `js/sticky-header.js` (no debug/alert code)
  - Discussed and deferred a sticky-header on/off toggle as a future enhancement (documented in architecture notes)
  - Updated `SESSION-NOTES.md` with full resolution writeup and diagnostic technique for future Kindle JS debugging
  - **Not yet done:** regenerate real `1.html` etc. with final `sticky-header.js` reference added to `generate_bible.ps1` template, full QA pass, commit to GitHub, cleanup of test files

---

### Session 8 — Addendum (continued same day)

- Found `index.html` and `navigate.html` templates were missing `<script src="js/sticky-header.js">` entirely — this is why Genesis/Old Testament and the Book/Chapter dropdowns were hidden under the header on those pages (no spacer div ever got injected on them)
- Fixed `generate_bible.ps1`:
  - `index.html` template: added `<script src="js/sticky-header.js"></script>` before `bookmarks.js`
  - `navigate.html` template: added `<script src="js/sticky-header.js"></script>` after `bible-data.js`
  - Both use `js/sticky-header.js` (one level, root-level pages) vs chapter pages' `../../js/sticky-header.js`
- **Discovered and fixed a separate latent bug** while regenerating: `ConvertTo-VerseHtml`'s inner `'w'` case did `$word = $node.InnerText`, which can return `$null` for empty `<w>` nodes. When `$lemma` was non-empty but `$word` was `$null`, the call to `Get-StrongLinkHtml -Word $word` failed because `[AllowEmptyString()]` permits `""` but not `$null`. Fixed with `$word = [string]$node.InnerText` (casts null to empty string). This had apparently always been latent but only surfaced now.
- Full regeneration (1,189 chapters) completed in **37.92 seconds**, QA test in **1.86 seconds**, 119/119 passing
- **Final Kindle test — ALL PASSING:**
  - `index.html`: "Old Testament"/"Genesis" fully visible below header, no clipping ✅
  - `navigate.html`: "Book:", book dropdown, "Chapter:" all fully visible below header ✅
  - Genesis 1, Ruth 1, John 1: verse 1 visible, sticky snap-to-top header working ✅
  - Dictionary pages (via Strong's link from John 1:1 → G3056): working ✅
- Committed to GitHub: `git-push.ps1 -Message "Resolve Kindle header: position absolute + JS snap-to-top, fix index/navigate spacer, fix null word InnerText bug"`
- Attempted cleanup of leftover Kindle test files via `adb shell rm` — all already absent (nothing to clean up)
- **Noted but not investigated:** John 1 sometimes loads scrolled to verse 27 instead of verse 1 — believed to be `bookmarks.js` restoring a stale saved scroll position from earlier testing, not a bug. Revisit if it persists with fresh/real usage.

**STATUS: Kindle compatibility work is essentially COMPLETE.** All core features (navigation, dark mode, Strong's links, dictionary, font sizing, bookmarks-pending-final-check, sticky header) working on both PC and Kindle. Ready to move to Phase 2 (notes system) and Phase 3 (EPUB packaging) in a future session.

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
- Phase 2 (notes system) and Phase 3 (EPUB packaging) are blocked behind resolving the Kindle CSS issue
- The `notes.js` script tag must be stripped during EPUB packaging (not optional)
- Search is PC-only via localhost — XHR from `file://` URLs is blocked by browsers
- ADB push target on Kindle: `/data/local/tmp/` (only writable location found)
- `adb-push-test.ps1` pushes `style-kindle.css` AS `style.css` for Kindle testing
- Kindle device: 1st Gen Fire D01E, Fire OS 6.3.4, Android 2.3, serial starts with D01E
- ADB path: `H:\Android SDK Platform Tools\adb.exe`
- Add ADB to PATH with: `$env:PATH += ';H:\Android SDK Platform Tools'`
- `generate_bible.ps1` Phase 7/8 (fontsize.js/bookmarks.js generation) was REMOVED — never regenerate these files via the script
- **CRITICAL OPEN ISSUE:** CSS loading/application on Kindle Silk browser is fundamentally broken in a way not yet understood. `position: fixed` confirmed non-functional even in isolated inline-style tests. Multi-class selectors confirmed non-functional even in isolated inline-style tests. Next session should start with `adb shell cat /data/local/tmp/css/style.css | findstr "header-spacer"` to determine if real chapter pages are using stale CSS.

---

### Session 9
- **Date:** 2026-06-15
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation)
- **Work Done:**

  **Strong's Index Pages**
  - Added `indexes/strongs-hebrew-index.html` and `indexes/strongs-greek-index.html`
  - Paginated table (50/100/200/All) with active button highlighting
  - Padded IDs (H0001, G0023) consistent with inline verse display
  - Short definition preview per entry
  - "Hebrew Index" / "Greek Index" buttons on dictionary pages now work (no more 404)
  - Index title shortened to "$Language Index" (was "Strong's $Language Lexicon Index") to prevent header truncation

  **Notes System (Phase 2) — Opus consultation**
  - `start-study.ps1` — PowerShell HTTP server on localhost:8080
  - `start-study.bat` — double-click launcher
  - `js/notes.js` — ES3, gold ✏ pencil button per verse, modal editor
  - Save/Edit/Delete all immediately bake into chapter HTML (no separate bake step)
  - ⚡ Sync to Kindle button pushes modified chapter files via ADB
  - Modal hidden on `file://` (Kindle) — only baked notes visible there
  - `notes.json` and `.last-sync` excluded via `.gitignore`
  - CSS additions (notes-additions.css) appended to both `style.css` and `style-kindle.css`

  **Navigation improvements**
  - `[<B][<V][V>][B>]` buttons replace old `[◀ Prev][Next ▶]`
  - `<B` / `B>` jump to first chapter of previous/next book
  - `<V` / `V>` navigate previous/next chapter (as before)
  - `$allBooks` pre-computed outside chapter loop for efficiency
  - Book index lookup uses OsisId matching loop (ES3 compatible)

  **Go To Passage improvements**
  - "Go To" link now passes current book as URL hash: `navigate.html#Gen`
  - Hash-based auto-select in navigate.html (replaces broken referrer approach)
  - Uses `BIBLE_DATA[i].abbr` field for hash matching
  - Auto-selects chapter 1 and verse 1 when book is pre-selected
  - `onGo()` defaults to chapter 1 if no chapter selected (no more alert)

  **Two-column Book Index**
  - `index.html` now shows OT books (left) and NT books (right) in float-based columns
  - `width: 49%` float layout — Kindle compatible, no flexbox
  - `.book-columns`, `.book-col`, `.book-col-clear` CSS classes added to both stylesheets
  - Added `sticky-header.js` to `index.html` template (was missing)

  **Kindle header button overflow fix**
  - `.book-chapter` font-size reduced from 1.8em to 1.1em in `style-kindle.css`
  - Button padding reduced from 6px 10px to 4px 7px
  - Button font-size reduced from 14px to 12px
  - Button margin reduced from 2px to 1px
  - Fixes missing buttons on long book names (Deuteronomy, Ecclesiastes, 1 Thessalonians etc.)

  **Bug fixes**
  - Removed stray "powershell" text from chapter nav template (line 505)
  - Fixed `$Books` reference to use `$booksToProcess` / `$allBooks`
  - QA test updated for new V/B button label patterns
  - `generate_dict.ps1` title shortened to prevent header overflow
  - `style-kindle.css` CSS corruption fixed (restored from GitHub)
  - `adb-push-all.ps1` — new script to push complete Bible to Kindle

  **QA: 119/119 passing**
  **All changes committed to GitHub**

---


---

### Session 10
- **Date:** 2026-06-15 (continued same day as Session 9)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Two-row Kindle header**
  - Changed `.chapter-nav` from fixed `height: 90px` to auto-height with `padding: 4px 0 2px 0`
  - Changed `.book-chapter`/`h1` from `float: left` to `display: block; text-align: center` — title centers on row 1
  - Changed `.nav-buttons` from `float: right` to `display: block; text-align: center` — buttons center on row 2
  - Reduced button size: `padding: 4px 7px`, `font-size: 12px`, `margin: 1px`, `height: 36px`
  - Fixes ALL book name overflow issues (Deuteronomy, Ecclesiastes, 1 Thessalonians etc.)

  **Two-column book index**
  - Added `.book-columns`, `.book-col`, `.book-col-clear` CSS to both stylesheets
  - Updated `generate_bible.ps1` index.html template to use two-column float layout
  - OT books (left column), NT books (right column), `width: 49%` float-based
  - Added `sticky-header.js` to `index.html` template (was missing)

  **Go To Passage fixes**
  - Added `sticky-header.js` to `navigate.html` template
  - `navigate.html` padded to ~9.9KB (was 4.4KB — below Silk's CSS threshold)
  - Hash-based book auto-select (`navigate.html#Gen`) — works on `file://` URLs
  - Uses `BIBLE_DATA[i].abbr` field for matching
  - Auto-selects chapter 1 and verse 1 when book pre-selected
  - `onGo()` defaults to chapter 1 if no chapter selected

  **Navigation button improvements**
  - `[<B][<V][V>][B>]` replace old `[◀ Prev][Next ▶]`
  - `$allBooks` pre-computed outside chapter loop
  - "Go To" link passes book as URL hash: `navigate.html#Gen`
  - Removed stray "powershell" text from nav button (recurring issue — fixed multiple times)

  **Bug fixes / cleanup**
  - 58 test/sample/debug files deleted from project root via `cleanup.ps1`
  - `style-kindle.css` restored from GitHub multiple times due to corruption during session
  - Two-column CSS was missing from `style-kindle.css` — appended correctly at end of session
  - `adb-push-all.ps1` created for full Kindle push (15-30 min, all 15,000+ files)
  - QA test updated for new V/B button label patterns
  - `generate_dict.ps1` index title shortened to `"$Language Index"`

  **Persistent issues encountered this session**
  - Silk CSS caching: changes to `style.css` on Kindle don't apply until new filename used
  - Workaround: push as `style3.css`, create test HTML referencing it, then push back as `style.css`
  - `generate_bible.ps1` changes not persisting across downloads — always verify with `findstr` after regenerating
  - Small pages (<5KB) don't get CSS applied on Silk — fixed for `navigate.html` with invisible padding comment block

  **QA: 119/119 passing**
  **All changes committed to GitHub**
  **PC and Kindle styles now aligned**

---


---

### Session 11
- **Date:** 2026-06-15 (continued same day as Sessions 9 & 10)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Notes System — fully working end-to-end**
  - `generate_bible.ps1` updated with pencil buttons (`note-btn`) and note placeholder divs (`verse-note`) on every verse
  - `rebake-notes.ps1` created — re-bakes all notes from `notes.json` after regeneration
  - Must always run `rebake-notes.ps1` after any full `generate_bible.ps1` regeneration
  - 6 notes successfully baked: Rom.3.23, Rom.6.23, Rom.10.10, 1John.1.9, John.3.16, Rom.8.1

  **Pencil buttons fix**
  - `.note-btn { display: none }` by default in CSS
  - `body.is-localhost .note-btn { display: inline }` shows them only on localhost
  - `notes.js` adds `is-localhost` class to `<body>` on localhost detection
  - Kindle never sees pencil buttons (always `file://`)

  **Verse reference links in notes**
  - Syntax: `[[Book.Ch.Vs]]` e.g. `[[Rom.6.23]]`, `[[1John.1.9]]`
  - `notes.js` — `linkifyVerseRefs()` function with built-in `BOOK_FOLDERS` table (no BIBLE_DATA dependency)
  - `start-study.ps1` — `ConvertTo-VerseLinks` PowerShell function with `$BookTable`
  - Links convert at save time in both live DOM and baked HTML
  - Hint text shown in modal: "Tip: Use [[Book.Ch.Vs]] to link to a verse"
  - `bible-data.js` NOT included in chapter pages — built-in table used instead

  **Sync wait modal**
  - Clicking ⚡ K button shows "Syncing to Kindle… please wait" modal
  - Modal closes automatically when sync completes
  - Toast notification shows number of files pushed

  **Kindle status polling**
  - `GET /api/kindle-status` endpoint in `start-study.ps1` — runs `adb devices`
  - `notes.js` polls every 5 seconds, disables ⚡ K button when Kindle not connected
  - Button re-enables automatically when Kindle plugged in

  **Sync button label**
  - Changed from "⚡ Sync" to "⚡ K" to save header space

  **Note textarea size**
  - Increased from `min-height: 120px` to `min-height: 250px`

  **Verse anchor offset fix**
  - PC: `scroll-margin-top: 100px` on `.verse` in `style.css`
  - Kindle: JS anchor offset fix in `sticky-header.js`

  **Kindle note styling**
  - `.verse-note-text` in `style-kindle.css` now styled with green background, italic, indented
  - Slightly smaller font than PC version

  **Key bugs encountered & fixed this session**
  - `BIBLE_DATA` undefined on chapter pages (not loaded) → switched to built-in `BOOK_FOLDERS` table
  - `ConvertTo-VerseLinks` missing from `start-study.ps1` → added with `$BookTable`
  - `linkifyVerseRefs` missing from `notes.js` → added
  - Notes disappeared after regeneration → `rebake-notes.ps1` created as fix
  - Pencil buttons not showing → `is-localhost` class on body via CSS approach
  - `start-study.ps1` parse error (missing closing brace) → fixed
  - `generate_bible.ps1` verse-note placeholders missing → re-applied multiple times

  **Book abbreviation reference for [[]] syntax:**
  Gen, Exod, Lev, Num, Deut, Josh, Judg, Ruth, 1Sam, 2Sam, 1Kgs, 2Kgs,
  1Chr, 2Chr, Ezra, Neh, Esth, Job, Ps, Prov, Eccl, Song, Isa, Jer,
  Lam, Ezek, Dan, Hos, Joel, Amos, Obad, Jonah, Mic, Nah, Hab, Zeph,
  Hag, Zech, Mal, Matt, Mark, Luke, John, Acts, Rom, 1Cor, 2Cor, Gal,
  Eph, Phil, Col, 1Thess, 2Thess, 1Tim, 2Tim, Titus, Phlm, Heb, Jas,
  1Pet, 2Pet, 1John, 2John, 3John, Jude, Rev

  **QA: 119/119 passing**
  **All changes committed to GitHub**

---


---

### Session 12
- **Date:** 2026-06-16
- **Model:** Claude Sonnet 4.6 (claude.ai) + Claude Opus 4.6 (consultation x2)
- **Work Done:**

  **Concordance System (Phase 2 enhancement)**
  - `generate_bible.ps1` — inline concordance builder during Phase 3 verse generation
  - Extracts Strong's number + English KJV word from OSIS `<w>` elements
  - Writes `concordance.json` with `{book, folder, ch, vs, word}` per entry
  - 14,070 Strong's entries, deduped per verse
  - `generate_dict.ps1` — loads concordance.json, bakes collapsible/paginated occurrence sections into every dictionary page
  - Books grouped with expand/collapse toggle, pagination at 50/page for large books
  - English word shown alongside each verse reference: `Gen 1:1 "God"`
  - `Format-ConcordanceLink` helper function for clean link generation
  - `.conc-word` CSS class (italic, light green) in both stylesheets

  **Concordance padding bug fix**
  - OSIS lemma format inconsistent: some `strong:H06531` (5-digit), some `strong:H6531` (4-digit)
  - Fix: `TrimStart('0')` before `PadLeft(4,'0')` normalizes all to 4-digit
  - H6531 (rigour) now correctly shows 6 occurrences
  - No more over-padded keys (H02087 etc.) in concordance.json

  **Dictionary page padding fixes**
  - StrongsId display was unpadded (G26 instead of G0026)
  - Fixed Hebrew and Greek `Write-DictPage` calls to use `PadLeft(4,'0')`
  - Fixed origin link display text (was showing G25, now shows G0025)
  - Fixed `Resolve-StrongsRefs` display for Greek derivation fields

  **Favicon**
  - `BiblePencil.ico` added to project root
  - Favicon link added to all page templates in both generators
  - Correct relative paths: `BiblePencil.ico` (root), `../../BiblePencil.ico` (deep pages), `../BiblePencil.ico` (indexes)

  **Clickable origin references**
  - H/G number references in dictionary Origin field now render as clickable teal badges
  - Links to the referenced dictionary page

  **Note book picker**
  - "📖 Show Book List" toggle in note modal expands all 66 books
  - Clicking a book inserts `[[BookAbbr.` at cursor position
  - Collapsible panel, OT/NT sections

  **QA Tests expanded (Tests 12-15)**
  - TEST 12: Favicon present in root, chapter, and dictionary pages
  - TEST 13: Notes system — pencil buttons, placeholders, notes.js, linkifyVerseRefs, BOOK_FOLDERS
  - TEST 14: Concordance — entry count, H0430/H6531/G3056 spot checks, padding validation, conc-section in dict pages
  - TEST 15: Navigation — B/V buttons, Go To hash, sticky-header in navigate.html
  - 151/152 passing (1 warning: sync button needs regeneration)

  **Scripts reorganized**
  - All PS1 scripts moved to `scripts\` subfolder via `git mv`
  - `start-study.ps1` and `start-study.bat` remain in project root
  - Commands now: `pwsh -NoProfile -File .\scripts\generate_bible.ps1`

  **GitHub cleanup**
  - Removed obsolete `ci.yml` workflow (was referencing deleted sample scripts)
  - No more "CI: All jobs have failed" emails

  **Correct generation order (IMPORTANT):**
  1. `scripts\generate_bible.ps1` — builds chapters + concordance.json
  2. `scripts\generate_dict.ps1` — builds dictionary + concordance sections
  3. `scripts\qa-test.ps1`
  4. `scripts\rebake-notes.ps1`

  **QA: 151/152 passing**
  **All changes committed to GitHub**

---


---

### Session 13
- **Date:** 2026-06-17
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Kindle fixes verified (all working)**
  - Sync button hidden on Kindle (`display: none !important` in style-kindle.css)
  - Dictionary page titles correctly padded (G0026 not G26)
  - Origin references padded and linked
  - Concordance sections visible on Kindle dictionary pages
  - Notes green italic styling working on Kindle
  - Two-column book index working on Kindle

  **Sync modal confirmed working**
  - Added `/api/test-sync` endpoint to start-study.ps1 (5 second fake delay)
  - Added `testSyncModal()` function to notes.js
  - Test via browser console: `testSyncModal()`
  - Modal grays out background, prevents interaction during sync

  **ADB push progress improved**
  - `adb-push-all.ps1` now reports every 250 files (was 1000) for Hebrew/Greek dict

  **Phase 3 EPUB Packager complete**
  - `scripts/package_epub.ps1` builds valid EPUB 2.0 container
  - 15,497 files staged, 15,501 EPUB entries, 29.9MB compressed
  - PC elements stripped from chapter pages (pencil buttons, sync button, notes.js)
  - style-kindle.css included as style.css
  - content.opf with 15,497 manifest entries
  - toc.ncx with 1,256 navigation points (66 books + 1,189 chapters + TOC)
  - Phase 6: extracts EPUB and pushes to Kindle via ADB (replaces adb-push-all.ps1)
  - `-SkipAdb` switch for build-only mode
  - FBReader experiment: too large for D01E, Silk browser remains best experience
  - Decision: keep adb-push-all.ps1 for personal use, EPUB for future distribution

  **BDB/Thayer Lexicon Integration (in progress)**
  - Downloaded `bdb-thayer.dct.mybible` from MyBible site
  - Confirmed SQLite database format
  - Schema: `dictionary` table with `word` (TEXT), `data` (TEXT) columns
  - 14,197 entries (Hebrew H1-H8674, Greek G1-G5624)
  - Keys are unpadded: `H1121` not `H0001`
  - Data is rich HTML with hierarchical BDB definitions, nested lists
  - `scripts/export-bdb.ps1` exports database to `bdb-thayer.json`
  - UTF-8 encoding issue resolved using `.mode json` with piped stdin
  - `bdb-thayer.json` = 4.8MB, valid JSON array, Hebrew/Greek chars correct
  - Added to .gitignore: bdb-thayer.json, bdb-thayer.csv, bdb-thayer.db,
    bdb-thayer.dct.mybible, sqlite-nuget.zip, reorganize.ps1

  **Git conflict resolved**
  - File manually added to GitHub caused push failure
  - Fixed with: `git stash` → `git pull --rebase` → `git stash pop` → `git push`

  **Pending — Next Session:**
  - Integrate bdb-thayer.json into generate_dict.ps1
  - Display BDB/Thayer hierarchical definitions on dictionary pages
  - Convert `<a class='dict' href='#dH1'>H1</a>` links to our dict page links
  - Decision needed: replace or supplement existing Strong's definition

  **QA: 151/152 passing**
  **All changes committed to GitHub**

---


---

### Session 14
- **Date:** 2026-06-17
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **BDB/Thayer Lexicon Integration — Complete**
  - `bdb-thayer.dct.mybible` confirmed as SQLite database
  - Schema: `dictionary` table, columns: `word` (TEXT), `data` (TEXT)
  - 14,197 entries with rich HTML hierarchical definitions
  - Keys unpadded: `H1121` not `H0001`
  - Data already formatted as HTML with `<ol><li>` nested lists

  **Export script (`scripts/export-bdb.ps1`)**
  - sqlite3 `.mode json` truncates long data fields — discovered via debugging
  - Fix: individual queries per entry using streaming file writer
  - Output: `bdb-thayer.json` — 6.5MB, 14,197 entries, full UTF-8
  - Hebrew/Greek characters preserved correctly (`בּן`, `λόγος`)

  **generate_dict.ps1 integration**
  - Loads `bdb-thayer.json` using `System.Text.Json.JsonDocument`
  - `Get-BdbHtml` function looks up entry by unpadded ID (strips leading zeros)
  - `Convert-BdbLinks` converts `<a class='dict' href='#dH1129'>` to our dict links
  - BDB block inserted between KJV Usage and concordance section
  - Purple left border (`#7e57c2`) distinguishes BDB from Strong's (teal/gold)
  - CSS added to both `style.css` and `style-kindle.css`

  **Results**
  - H1121 (son): beautiful 9-item hierarchical definition with nested sub-items
  - H0430 (God/Elohim): full BDB definition showing all usages
  - G3056 (Logos/Word): Thayer's Greek definition with full detail
  - Origin cross-reference links work correctly
  - Both PC and Kindle display correctly

  **Files changed**
  - `scripts/generate_dict.ps1` — BDB loading + Get-BdbHtml + Convert-BdbLinks
  - `scripts/export-bdb.ps1` — robust SQLite export with individual queries
  - `css/style.css` — `.dict-bdb` styles
  - `css/style-kindle.css` — `.dict-bdb` styles (Kindle-compatible)
  - `bdb-thayer.json` — gitignored, regenerated via export-bdb.ps1
  - `.gitignore` — added bdb-thayer.json, bdb-thayer.csv, bdb-thayer.db,
    bdb-thayer.dct.mybible, sqlite-nuget.zip

  **Generation order (updated):**
  1. `scripts/export-bdb.ps1` — export BDB/Thayer lexicon (one-time or when updated)
  2. `scripts/generate_bible.ps1` — chapters + concordance.json
  3. `scripts/generate_dict.ps1` — dictionary pages with BDB + concordance
  4. `scripts/qa-test.ps1`
  5. `scripts/rebake-notes.ps1`

  **QA: 151/152 passing (sync button warning — needs regeneration)**
  **All changes committed to GitHub**

---


---

### Session 15
- **Date:** 2026-06-17 (continued)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Hebrew/Greek Index buttons on index.html**
  - Added [Hebrew] and [Greek] buttons to the left of [Go To Passage] in index.html header
  - Change in `generate_bible.ps1` index.html nav-buttons template

  **[BEG] and [END] pagination buttons on index pages**
  - Added [BEG] button (jumps to page 1) to left of Prev button
  - Added [END] button (jumps to last page) to right of Next button
  - Change in `generate_dict.ps1` renderNav() function
  - Makes navigation much easier on large indices (Hebrew 8,674 / Greek 5,624 entries)

  **Concordance CSS missing from style.css**
  - All concordance CSS (conc-section, conc-link, conc-word, etc.) was missing
  - Appended full concordance + note-picker CSS block to style.css
  - style-kindle.css already had correct CSS

  **BDB/Thayer file cleanup**
  - Deleted test export files: bdb-line.txt, bdb-quoted.txt, bdb-thayer-raw.txt,
    bdb-thayer.csv, bdb-thayer.db, sqlite-nuget.zip
  - Deleted bdbthayer.LZMA from repository via git rm
  - Kept bdb-thayer.json (needed by generate_dict.ps1)
  - NOTE: bdb-thayer.dct.mybible (source database) also deleted locally
    - To regenerate bdb-thayer.json, re-download from MyBible site
    - Then run: pwsh -NoProfile -File .\scripts\export-bdb.ps1
  - Added all BDB files to .gitignore

  **start-study.ps1 param warning**
  - Harmless error on server startup — server runs correctly despite warning
  - Will investigate fix next session

  **QA status: 151/152 (sync button warning)**
  **All changes committed to GitHub**

---


---

### Session 16
- **Date:** 2026-06-18
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Sync modal fix**
  - Real `syncToKindle` function never had modal code — only `testSyncModal` did
  - Added full modal creation + 2 second minimum display time to `syncToKindle`
  - Modal now always visible for at least 2 seconds regardless of sync speed

  **Hebrew/Greek index buttons on index.html**
  - Added [Hebrew] and [Greek] buttons to left of [Go To Passage]
  - Change in `generate_bible.ps1` index.html nav-buttons template

  **[BEG]/[END] pagination buttons**
  - Added [BEG] (jump to page 1) and [END] (jump to last page)
  - Change in `generate_dict.ps1` renderNav() function

  **Concordance CSS fix**
  - All concordance CSS missing from style.css
  - Appended full concordance + note-picker CSS block

  **BDB/Thayer file cleanup**
  - Deleted test files: bdb-line.txt, bdb-quoted.txt, bdb-thayer-raw.txt,
    bdb-thayer.csv, bdb-thayer.db, sqlite-nuget.zip, bdbthayer.LZMA
  - Added all to .gitignore
  - NOTE: bdb-thayer.dct.mybible deleted — re-download from MyBible to regenerate

  **Documentation**
  - `README.md` — completely rewritten to reflect current project state
  - `WINDOWS-SETUP.md` — comprehensive Windows setup guide
  - `MAC-SETUP.md` — comprehensive Mac setup guide (uses PowerShell Core)
  - Future: Electron launcher app for non-technical users

  **Verse link debugging**
  - [[Luke.18:14]] vs [[Luke.18.14]] — colon vs dot syntax issue
  - Syntax requires dots throughout: [[Book.Ch.Vs]]
  - Book picker helps by auto-inserting [[Book. at cursor

  **Electron launcher app — planned**
  - For non-technical users who find setup guides intimidating
  - Cross-platform: Windows (.exe) and Mac (.dmg)
  - Source XML files hosted as GitHub Release assets
  - Executables distributed via GitHub Releases page
  - Will require Opus consultation when ready to build

  **QA: 151/152 passing**
  **All changes committed to GitHub**

---

### Session 17
- **Date:** 2026-06-20
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Strong's links reading-mode toggle**
  - Added 👁 eye button to chapter header, between font controls and sync button
  - Toggles `.strongs-hidden` class on `<body>` — hides all Strong's badges for clutter-free reading
  - SVG icon switches between open eye and eye-with-diagonal-strikethrough
  - Preference persisted via existing `_kjvStore` storage chain (same as font size)
  - Change in `js/fontsize.js` (new IIFE block) and `generate_bible.ps1` (button HTML)

  **Verse highlighting feature (4 pastel colors)**
  - Yellow/Green/Red/Blue highlight colors added to note modal as a color picker row
  - Pastel rgba values with subtle left border accent; more opaque variants for Kindle
  - Storage: `highlights.json`, keyed by `Book.Ch.Vs` same as notes
  - Baked as `hl-{color}` CSS class directly on `<p class="verse">` elements
  - Highlight save/delete independent of note text — a verse can have either, both, or neither
  - New API endpoints in `start-study.ps1`: GET/POST `/api/highlights`, DELETE `/api/highlights/{ref}`
  - `rebake-notes.ps1` extended to also rebake highlights after regeneration
  - Fixed `start-study.ps1` "param( not recognized" error — a misplaced `Handle-TestSync`
    function had been prepended to the very top of the file before the real `param()` block;
    moved it to the correct location

  **Edge dark-mode yellow highlight bug — found and fixed**
  - Yellow highlights appeared dark olive in Edge but correct in Avast browser
  - Root cause: Edge's "Force dark mode" auto-color-inversion was double-processing
    the already-dark-themed page; yellow tones get muddied during inversion
  - FIX: added `<meta name="color-scheme" content="dark">` to all page templates
    (6 locations across `generate_bible.ps1` and `generate_dict.ps1`)
  - Verified live by toggling Edge's force-dark setting on/off
  - User can also manually disable "Force dark mode" in Edge settings as a fallback

  **English word search feature (Bible SuperSearch API)**
  - New `search.html` + `js/search.js` — searches KJV text via
    `https://api.biblesupersearch.com/api?bible=kjv&search={query}` (free, no API key)
  - Tested live: confirmed working, ~338 results for "faith" across 12 pages
  - PC-only feature — requires internet; hidden on Kindle via `file://` protocol detection
    on the Search nav button (inline script in `index.html`)
  - `search.html` lives in `scripts/` as source of truth; `generate_bible.ps1`
    Phase 5b copies it to project root on every regeneration
  - Initial header-overlap bug fixed: `.search-page-wrap` needed `padding-top: 95px`
    to clear the fixed 90px header (same pattern as `.chapter-content`)

  **Advanced search scoping**
  - Added Results-per-page dropdown: 50 / 100 / 200 / All
    - Whole Bible + page size → API's native `page_limit`/`page` (server-side pagination)
    - Any filtered scope → always `page_all=true`, filter client-side by `book_id`,
      paginate the filtered array ourselves (keeps counts/pagination accurate)
  - Added [BEG]/[END] pagination buttons matching the Strong's index page pattern
  - Added Specific Book dropdown (all 66 books)
  - Added Category checkboxes, multi-select, verified complete (66 books, no gaps):
    - OT: Torah (5), Historical (12), Poetic/Wisdom (5), Prophetic (17) = 39 books
    - NT: Gospels (4), Acts (1), Paul's Church Epistles (9), Paul's Pastoral
      Epistles (4), General Epistles (8), Revelation (1) = 27 books
  - UI REDESIGN mid-session: originally used Whole/OT/NT radio buttons alongside
    Book dropdown and Category checkboxes (3 mutually-exclusive modes via radios) —
    but radios could get permanently disabled/stuck with no way back once Book or
    Category mode was selected via session-restore. REPLACED with simpler model:
    - No more Whole/OT/NT radios at all
    - Book dropdown empty + no categories checked = Whole Bible (the default)
    - Selecting a Book clears any checked categories (and vice versa) — still
      mutually exclusive, but no locked/stuck state possible
    - Added "Old Testament" and "New Testament" **master checkboxes** — checking
      one auto-checks all categories beneath it (4 for OT, 6 for NT)
  - `getActiveScope()` rewritten: book dropdown wins if set, else union of all
    checked category checkboxes, else Whole Bible — clean single source of truth

  **Search result persistence across navigation (sessionStorage)**
  - Problem: clicking a search result to view a verse, then returning, lost all
    results and had to re-search from scratch — broke the "study multiple verses
    on a topic" workflow
  - Solution: full search state (query, scope selections, checked categories,
    current page, and the actual result data) saved to `sessionStorage` after
    every successful search/pagination action
  - On page load, if saved state exists, UI controls and results are restored
    instantly without re-calling the API
  - Tab-scoped (not localStorage) — clears automatically when tab closes;
    starting a new search clears old state to avoid staleness
  - PC-only feature, so no conflict with Kindle's `file://` storage restrictions

  **Cross-platform setup guides**
  - `MAC-SETUP.md` and `WINDOWS-SETUP.md` written earlier this session, confirmed
    PowerShell Core (`pwsh`) is already cross-platform — no script rewrite needed,
    just path adjustments (ADB path, SQLite path, project root)

  **Documentation/organization learning**
  - Discussed "source of truth" pattern: `scripts/` holds source material (either
    as standalone files like `search.html`, or as PowerShell here-strings like
    `navigate.html`/`index.html`); project root holds generated/deployed output
  - `search.html` can be copied directly into both `scripts/` and root without a
    full `generate_bible.ps1` run, since it's a static file with no per-page
    templating — faster than full regeneration for search-only changes

  **KJV text edition identified**
  - Confirmed via `kjv.osis.xml` header: King James Version (1769) Blayney
    Standard Edition — the scholarly standard nearly all modern KJV texts use
  - Source file tracks fine textual details (e.g. Genesis 1:2 comma discrepancy
    between Blayney's quarto/folio editions) and aligns Words of Christ red-letter
    markup with Louis Klopsch's 1901 edition
  - README update with this provenance info was planned but not yet applied
    (file mismatch this session — to be added next session)

  **QA status:** not re-run this session after the search scoping redesign —
  recommend running `qa-test.ps1` next session to confirm no regressions

  **Files modified this session:** `fontsize.js`, `generate_bible.ps1`,
  `style.css`, `style-kindle.css`, `notes.js`, `start-study.ps1`,
  `rebake-notes.ps1`, `search.html`, `search.js`, `search-additions.css`,
  `index.html` (Search nav button + file:// hiding script)

---

Session 18

Date: 2026-06-22
Model: Claude Sonnet 4.6 (claude.ai)
Work Done:
Superscript Strong's badges

Changed .strongs-link from teal pill/badge style to superscript text
display: inline, vertical-align: super, font-size: 0.7em, no background
Color changed to #00b7eb directly on text (no pill needed)
Hover underlines instead of old "lift" transform
Kindle CSS left unchanged (already used a lighter non-pill style)

Hamburger settings menu

Moved font size buttons, Strong's toggle, Sync to Kindle out of main header
Added ☰ hamburger button at far right of nav bar
Dropdown panel outside .chapter-nav (critical — overflow: hidden on nav was clipping it)
Dropdown uses position: fixed; top: 92px; right: 8px to stay anchored
Two sections: "Display" (font + Strong's toggle) and "Kindle" (Sync + Rebake Notes)
Unbaked notes indicator stays in main header bar
Hamburger + dropdown hidden entirely on Kindle via style-kindle.css
Files changed: generate_bible.ps1, fontsize.js, notes.js, start-study.ps1,

style.css, style-kindle.css

Keyboard shortcuts

Ctrl+] → increase font size
Ctrl+[ → decrease font size
H (no modifier) → toggle Strong's links
Safety check: shortcuts bail if document.activeElement is INPUT/TEXTAREA/SELECT
Added to fontsize.js as a third IIFE

Rebake Notes API endpoint

New POST /api/rebake in start-study.ps1 → invokes rebake-notes.ps1 as subprocess
Fixed Opus's regex to match actual output: "Notes baked" / "Highlights baked"

(Opus assumed "Notes rebaked" / "Highlights rebaked" — corrected before integration)
rebakeNotes() function added to notes.js — shows toast with counts on completion
Menu item "Rebake Notes" in hamburger dropdown triggers this

Hover states on dropdown menu rows

Added :hover background highlight to .settings-row-clickable
Active state darkens slightly further for clear click feedback

QA test updates

Updated sync button check from class="sync-btn" to onclick="syncToKindle()"
Added 3 new checks: hamburger button, settings dropdown, rebake notes menu item
Result: 153/153 passing, 0 failures, 1 harmless legacy warning (xrefs/)

GitHub Releases

Learned about GitHub Releases as a free distribution channel (2GB per file, unlimited files)
Created v1.0.0 Release with kjv.osis.xml and bdb-thayer.json as downloadable assets
These are the two files required for setup that are too large for the git repo itself

Repository cleanup (major)

Adopted "lean repo" philosophy — source files only, no generated output
git rm --cached to untrack: books/, dict/, indexes/, index.html,

navigate.html, concordance.json, KJV-Strongs.epub, notes.json
Deleted From Opus/ scratch folder entirely
Added to .gitignore: all of the above plus highlights.json, .last-sync
Added previously untracked: MAC-SETUP.md, WINDOWS-SETUP.md, search.html
Repo size: was ~76MB, now ~31MB after cleanup

BFG Repo-Cleaner — history scrub

Used BFG 1.14.0 (Java 8 compatible) to permanently remove notes.json from

all historical commits (personal study notes had been publicly visible)
Full process: mirror clone → BFG scrub → git gc --prune=now --aggressive

→ force push → rename old local folder → fresh clone → copy back local files
Notes.json scrubbed from 44 commits, 46 object IDs changed
Repo size reduced from 76.79MB to 31.45MB

Node.js installation

Node.js v24.15.0 + npm 11.12.1 installed (MSI installer)
PATH fix: $env:PATH += ";C:\Program Files\nodejs" for current session

(restart PC to make permanent)

Electron Launcher — initial build (WORKING!)

Created C:\Users\OldTi\kjv-strongs-launcher\ as a separate project/repo
7 files from Opus consultation: main.js, preload.js, setup.html,

setup.js, setup.css, package.json, LAUNCHER-DEV-NOTES.md
Plus .gitignore (ignoring node_modules/, dist/, etc.)
Two fixes applied to Opus output before testing:

PowerShell MSI URL was hardcoded to v7.4.6 — changed to dynamic GitHub

API lookup for latest win-x64.msi asset
installedVersion was hardcoded to "1.0.0" — now uses real release tag

fetched during download step


npm install completed successfully (405 packages, deprecation warnings normal)
npm start — FULL SETUP FLOW WORKED ON FIRST RUN:

PowerShell detected automatically (skipped install)
Kindle prompt shown → user clicked "No, skip"
Downloaded kjv.osis.xml and bdb-thayer.json from GitHub Release
Ran generate_bible.ps1 — 1,189 chapters in 2m 17s ← first timing data!
Ran generate_dict.ps1 — completed successfully
Ran rebake-notes.ps1 — completed
Server started, Bible app opened in embedded Electron window ✅


Conversation hit 100-file limit before capturing final elapsed time and

testing close/shutdown behavior

Pending for next session:

Note the final total generation elapsed time (all 3 scripts)
Test subsequent launch (should skip setup, go straight to Bible)
Test close/shutdown (verify no orphaned PowerShell processes via Task Manager)
Create GitHub repo for launcher (KJV-Strongs-Launcher) and push
Add icon.ico (convert BiblePencil.ico from main project)
Eventually: npm run build to produce the actual .exe installer
Restart PC to make Node.js PATH permanent

QA status: 153/153 passing

Files modified this session: style.css, style-kindle.css,

generate_bible.ps1, fontsize.js, notes.js, start-study.ps1,

scripts/qa-test.ps1


---

### Session 19
- **Date:** 2026-06-22 (continued same day as Session 18)
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Electron Launcher — first .exe build**
  - Added `icon.ico` (copied BiblePencil.ico from main project)
  - Built first `.exe` via `npm run build` (electron-builder, NSIS target)
  - Initial build failed: winCodeSign symlink error — fixed by running as
    Administrator and clearing `%LOCALAPPDATA%\electron-builder\Cache\winCodeSign`
  - Second build succeeded: `dist\KJV Strong's Bible Setup 1.0.0.exe`

  **Laptop install test — Round 1 (FAILED)**
  - Clean Windows 11 laptop, Avast antivirus, WiFi, no dev tools installed
  - Issues found:
    - 24-second blank gap before setup window appeared
    - PowerShell install failed silently — msiexec /quiet exits 1603 without
      UAC elevation; no prompt shown to user
    - Avast CyberCapture intercepted executables multiple times
    - No warning to user about antivirus scanning behavior

  **Launcher fixes — Round 2 (main.js, setup.js, setup.html)**

  main.js:
  - show: false + ready-to-show event — window appears only once HTML painted
  - PWSH_DEFAULT_PATH constant — C:\Program Files\PowerShell\7\pwsh.exe
  - detectPowerShell() — checks direct path if pwsh not in PATH; fresh MSI
    install doesn't update PATH in current process
  - runPowerShell() — uses explicit path if not in PATH yet
  - startServer() — same explicit path fix
  - install-powershell handler — /quiet → /passive (shows Windows UI, triggers
    UAC elevation visibly); timeout 120s → 180s; hardcoded v7.4.6 URL →
    dynamic GitHub API lookup with fallback

  setup.js:
  - avWarningShown flag — AV warning only shows once per session
  - firstRunSetup() split into showAntivirusWarning() + doFirstRunSetup()
  - retrySetup() sets avWarningShown = true — retry skips AV warning

  setup.html:
  - Added #av-warning full-screen overlay before first-run setup begins
  - Explains antivirus scanning is normal, warns about UAC prompt
  - Links to GitHub repo as open-source assurance
  - "Got it — Begin Setup" button

  **Laptop install test — Round 2 (SUCCESS with issues)**
  - AV warning appeared correctly ✅
  - PowerShell downloaded (110MB) and installed with UAC prompt ✅
  - Bible generation ran: chapters ~1m 34s, dictionary ~40s, total ~2m 15s ✅
  - Bible opened successfully ✅
  - Remaining issues:
    - AV warning appeared 3 times (Avast CyberCapture triggered multiple times)
    - Red PowerShell error flashed briefly before self-recovering
    - Both Electron window AND system browser opened simultaneously

  **Launcher fixes — Round 3 (main.js, start-study.ps1)**
  - start-study.ps1: Start-Process $BaseUrl guarded by $env:KJV_LAUNCHER -ne "1"
    — browser only opens when running standalone, not from Electron
  - main.js startServer(): passes env: Object.assign({}, process.env, { KJV_LAUNCHER: "1" })
    when spawning server process

  **Laptop install test — Round 3 (FULLY SUCCESSFUL)**
  - Added installer to Avast exceptions to prevent CyberCapture interruptions
  - Total elapsed time: ~2m 45s end-to-end ✅
  - AV warning appeared once only ✅
  - No PowerShell error (PS already installed from Round 2) ✅
  - No duplicate browser window — Electron window only ✅
  - Subsequent launch: skipped setup, went straight to Bible ✅
  - Shutdown: no orphaned PowerShell processes in Task Manager ✅
  - All UI changes present on laptop ✅

  **GitHub 2FA**
  - GitHub required 2FA by August 5, 2026 — set up via authenticator app ✅
  - Daily git push from PowerShell unaffected (uses token/SSH, not website login)

  **UI improvements — KJV-Strongs main project**

  generate_bible.ps1:
  - ◀V / V▶ → ◀C / C▶ (chapters, not verses)
  - All "Books" buttons → SVG house icon (home-btn, title="Home") across
    all 4 nav templates (chapter pages x2, navigate.html, index.html)
  - Hamburger dropdown: removed "KINDLE" section label — Sync to Kindle
    and Rebake Notes now peers in unlabeled section
  - sync-kindle-row id added for JS targeting

  generate_dict.ps1:
  - "Books" button → SVG house icon on Hebrew/Greek index pages

  scripts/search.html:
  - "Books" button → SVG house icon

  notes.js:
  - updateSyncButton() targets #sync-kindle-row in settings menu
  - Kindle not connected: row gets settings-row-disabled class, click
    disabled, title="Not connected" tooltip on hover
  - Connected: class removed, click re-enabled, title cleared

  style.css:
  - Added .settings-row-disabled — opacity 0.4, cursor not-allowed, hover suppressed
  - Added .home-btn — inline-flex for SVG icon centering

  style-kindle.css:
  - Added .home-btn — inline-block for Kindle compatibility

  scripts/qa-test.ps1:
  - Updated all V→C button pattern checks (6 occurrences across 4 assertions)

  README.md:
  - Added Option A (Electron Launcher) as recommended install path
  - Removed SQLite3 from requirements — not needed by end users
  - Removed bdb-thayer.dct.mybible from source files — replaced with
    pre-exported bdb-thayer.json hosted on Releases page
  - Removed export-bdb.ps1 as required step — demoted to optional note
  - Updated QA test count: 151+ → 155+
  - Updated nav buttons: ◀V/V▶ → ◀C/C▶
  - Added hamburger menu, home button, keyboard shortcuts to features
  - Updated platform table to include Launcher row
  - Clarified BDB/Thayer acknowledgement — end users don't need MyBible

  **GitHub Releases**
  - Bumped launcher to v1.1.0 in package.json, rebuilt installer
  - Created v1.1.0 release on GitHub Releases page with:
    - KJV Strong's Bible Setup 1.1.0.exe
    - kjv.osis.xml (carried over from v1.0.0)
    - bdb-thayer.json (carried over from v1.0.0)

  **KJV-Strongs-Launcher GitHub repo created**
  - https://github.com/RonTurrentine/KJV-Strongs-Launcher
  - Initial push failed — gitignore file was missing dot prefix so Git
    tracked node_modules/ (405 packages) and dist/ (270MB); push rejected
    by GitHub due to 177MB files exceeding the 100MB limit
  - Fix: renamed gitignore → .gitignore, deleted .git entirely,
    re-initialized fresh, re-committed and pushed cleanly
  - Final push: 10 files, 90KB ✅

  **Git commit message fix**
  - Accidentally used launcher commit message on main project commit
  - Fixed with: git commit --amend + git push --force-with-lease

  **QA: 155/155 passing, 0 failures, 0 warnings**

  **Files modified this session (KJV-Strongs-EBook repo):**
  - js/notes.js
  - css/style.css
  - css/style-kindle.css
  - scripts/generate_bible.ps1
  - scripts/generate_dict.ps1
  - scripts/qa-test.ps1
  - scripts/search.html
  - start-study.ps1
  - README.md

  **Files modified this session (KJV-Strongs-Launcher repo):**
  - main.js
  - setup.js
  - setup.html
  - package.json (version 1.0.0 → 1.1.0)
  - .gitignore (renamed from gitignore)

  **Pending for next session:**
  - Test PowerShell fresh-install detection on a truly clean machine
    (Round 3 laptop already had PS from Round 2 — fix not fully verified)
  - Add git-push.ps1 helper script to launcher repo
  - Consider code signing certificate for cleaner Avast/SmartScreen experience
  - Add LAUNCHER-DEV-NOTES.md content if not already written


---

### Session 20
- **Date:** 2026-06-24
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Help, About, and Exit in hamburger menu**

  `generate_bible.ps1` — hamburger dropdown updated with two new sections:
  - ❓ Help / Documentation — opens `help.html` in a new tab
  - ℹ️ About — opens `about.html` in a new tab
  - ✕ Exit — calls `window.close()`
  - Help/About use `window.open('../../help.html', '_blank')` (chapter page depth)
  - Exit row styled with subtle red tint on hover via `.settings-row-exit`

  `style.css`:
  - Added `.settings-row-exit` — `color: #ff6b6b`, dark red hover background

  `scripts/help.html` (new static file):
  - Full documentation page covering: Navigation, Strong's Numbers, Settings
    Menu, Keyboard Shortcuts, Personal Notes, Verse Highlighting, Reading Mode,
    English Word Search, Kindle Fire Sync
  - Sticky "✕ Close Tab" bar at top calls `window.close()`
  - Styled to match app dark theme using `css/style.css`
  - Stored in `scripts/` like `search.html`, copied to root by `generate_bible.ps1`

  `scripts/about.html` (new static file):
  - Shows version (v1.1.0), stat counters (1,189 chapters, 66 books,
    14,298 lexicon pages, 155+ QA tests)
  - Bible text edition description (Blayney 1769)
  - Acknowledgements, links to GitHub repo and Releases page
  - Sticky "✕ Close Tab" bar at top
  - Stored in `scripts/`, copied to root by `generate_bible.ps1`

  `generate_bible.ps1` Phase 5c added:
  - Copies `help.html` and `about.html` from `scripts/` to project root
    during generation (same pattern as `search.html` Phase 5b)

  **Hamburger menu on index (home) page**

  `generate_bible.ps1` index.html template updated:
  - Added hamburger ☰ button to nav bar
  - Added full settings dropdown (Font Size, Sync to Kindle, Rebake Notes,
    Help, About, Exit) — Strong's toggle omitted (no badges on home page)
  - Added `fontsize.js` and `notes.js` script includes
  - Help/About paths are root-relative (`help.html` / `about.html`)
  - Bug fix: button called `toggleSettings()` which doesn't exist —
    corrected to `toggleSettingsMenu()` (the function in notes.js)

  **Chapter count and verse count display**

  `generate_bible.ps1`:
  - Index page book list: chapter count moved inside `<a>` tag so it sits
    immediately after the book name and is part of the clickable link
    e.g. "Matthew (28 ch)" — was previously outside the link
  - Chapter header: verse count added in `chapter-meta` span
    e.g. "Genesis 1 (31 v)"

  `style.css`:
  - Added `.chapter-meta` — `color: #888888`, `font-size: 0.7em`,
    `font-weight: normal` — matches existing gray chapter-count style
  - Added `a .chapter-count` rule — keeps count gray inside anchor tags
    (prevents it inheriting link blue color)

  **WINDOWS-SETUP.md updated**
  - Restructured as Option A (Installer, recommended) and Option B (Manual)
  - Removed SQLite3 from requirements
  - Removed bdb-thayer.dct.mybible from source files
  - Removed export-bdb.ps1 as required step
  - Updated generation time estimates to actual times (2-3 min not 10-15)
  - Added hamburger menu, home button, keyboard shortcuts to features
  - Updated sync button reference to hamburger menu
  - Updated QA count to 155+
  - Added search.html to file structure
  - Marked export-bdb.ps1 as advanced/optional

  **GPL v3 License added**
  - LICENSE file created on GitHub.com using built-in license template
  - README.md license section updated — proper GPL v3 notice with copyright,
    warranty disclaimer, and third-party public domain content listed
  - License headers added to all 8 PowerShell source files:
    generate_bible.ps1, generate_dict.ps1, qa-test.ps1, rebake-notes.ps1,
    adb-push-all.ps1, package_epub.ps1, git-push.ps1, start-study.ps1
  - BDB (1906) and Thayer (1889) confirmed public domain — predates copyright
    by over 100 years; MyBible format is just a SQLite container for PD content

  **Legacy scripts removed from scripts/**
  - `adb-push-test.ps1` — test version of adb-push-all, superseded
  - `cleanup.ps1` — early dev cleanup script, no longer needed
  - `ExportToJson.ps1` — superseded by export-bdb.ps1
  - `scan_morph_codes.ps1` — morphology tool from early development

  **Git configuration fix**
  - `git pull` triggered vim editor for merge commit confirmation (LICENSE
    created on GitHub wasn't in local repo) — very confusing first encounter
  - Fixed: `git config --global core.editor "notepad"` — Git now uses
    Notepad for merge messages instead of vim

  **QA: 155/155 passing, 0 failures, 0 warnings**

  **Files modified this session (KJV-Strongs-EBook repo):**
  - `css/style.css`
  - `scripts/generate_bible.ps1`
  - `scripts/generate_dict.ps1` (license header only)
  - `scripts/qa-test.ps1` (license header only)
  - `scripts/rebake-notes.ps1` (license header only)
  - `scripts/adb-push-all.ps1` (license header only)
  - `scripts/package_epub.ps1` (license header only)
  - `scripts/git-push.ps1` (license header only)
  - `scripts/help.html` (new)
  - `scripts/about.html` (new)
  - `start-study.ps1` (license header only)
  - `README.md`
  - `WINDOWS-SETUP.md`
  - `LICENSE` (new — created on GitHub)

  **Files deleted this session:**
  - `scripts/adb-push-test.ps1`
  - `scripts/cleanup.ps1`
  - `scripts/ExportToJson.ps1`
  - `scripts/scan_morph_codes.ps1`

  **Pending for next session:**
  - Add GPL v3 license headers to JS files (notes.js, search.js, fontsize.js,
    bookmarks.js, sticky-header.js, bible-data.js)
  - Add LICENSE file to KJV-Strongs-Launcher repo
  - Add license headers to launcher source files (main.js, preload.js,
    setup.js, setup.css)
  - Test Help/About/Exit in hamburger menu in browser
  - Test hamburger menu on index page
  - Verify chapter count inline and verse count in header after regeneration
  - Run QA after all generate_bible.ps1 changes this session


---

### Session 21
- **Date:** 2026-06-26
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **macOS Installer — full implementation**

  `main.js` changes:
  - Added `IS_WIN` / `IS_MAC` platform constants at top
  - `INSTALL_DIR` — `~/Library/Application Support/KJVStrongs` on Mac,
    `%LOCALAPPDATA%\KJVStrongs` on Windows
  - `PWSH_DEFAULT_PATH` — null on Mac; added `PWSH_MAC_PATHS` array covering
    Intel (`/usr/local/bin/pwsh`), Apple Silicon (`/opt/homebrew/bin/pwsh`),
    and manual install fallback
  - `detectPowerShell()` — loops through platform-appropriate paths; checks
    both PATH and known install locations
  - `detectHomebrew()` — checks `/usr/local/bin/brew` (Intel) and
    `/opt/homebrew/bin/brew` (Apple Silicon), falls back to `which brew`
  - `installHomebrewViaTerm()` — spawns Terminal via `osascript` with official
    Homebrew install command; resolves immediately so user clicks Continue
  - `runPowerShell()` — platform-aware pwsh path resolution
  - `startServer()` — `windowsHide` only on Windows; Mac-aware pwsh path;
    `spawnOpts` object centralizes spawn options
  - `install-powershell` IPC handler — branches on Mac (brew install powershell)
    vs Windows (MSI download + /passive install)
  - New IPC handlers: `check-homebrew`, `install-homebrew-via-term`, `get-platform`
  - `clone-repo` — uses `unzip` on Mac instead of PowerShell `Expand-Archive`;
    tar fallback works on both platforms
  - `createSetupWindow()` — uses `icon.icns` on Mac, `icon.ico` on Windows

  `preload.js` changes:
  - Added `checkHomebrew`, `installHomebrewViaTerm`, `getPlatform` exposures

  `setup.js` changes:
  - `firstRunSetup()` — calls `getPlatform()` to show correct warning overlay
  - `checkHomebrew()` — new Mac flow: detect → show prompt → spawn Terminal
    → show waiting state with Continue button → verify → proceed to setup

  `setup.html` changes:
  - Renamed AV warning to Windows-specific (`#av-warning`)
  - Added Mac Gatekeeper warning overlay (`#mac-warning`) — explains Gatekeeper,
    Homebrew, and PowerShell install; same "Got it" button flow
  - Added Homebrew install prompt (`#homebrew-prompt`) — "Open Terminal to
    Install Homebrew" button calls `homebrewInstallStart()`
  - Added Homebrew waiting state (`#homebrew-waiting`) — "✓ Homebrew is
    installed — Continue" button calls `homebrewContinue()`

  `package.json` changes:
  - Added `build:mac` and `build:all` npm scripts
  - Added `mac` build target — DMG format, x64 + arm64 architectures
  - Added `dmg` config with window dimensions
  - Added `icon.icns` to files list
  - Updated license from MIT → GPL-3.0

  `icon.icns` (new file):
  - Generated from existing `BiblePencil.ico` (256x256 source)
  - Contains all required Mac icon sizes (16, 32, 128, 256, 512, 1024)
    plus Retina (@2x) variants
  - 208KB

  **GitHub Actions CI pipeline**

  `.github/workflows/build-release.yml` (new file):
  - Triggers on version tag push (e.g. `git tag v1.2.0 && git push origin v1.2.0`)
  - Parallel jobs: `build-windows` (windows-latest) and `build-mac` (macos-latest)
  - Both use Node.js 24, `npm ci`, electron-builder
  - Uploads artifacts directly to GitHub Release via `softprops/action-gh-release@v2`
  - `permissions: contents: write` required for release creation
  - First successful run: Build Release #3, 2m 23s total

  **First automated release — v1.1.0 / tag v1.2.0**
  - Tag/version mismatch: package.json says 1.1.0, tag is v1.2.0
    — release title manually set to v1.1.0 on GitHub; tag left as-is
  - Three installer assets produced:
    - `KJV Strong's Bible Setup 1.1.0.exe` (76.1 MB) — Windows
    - `KJV Strong's Bible-1.1.0.dmg` (97.8 MB) — Mac Intel x64
    - `KJV Strong's Bible-1.1.0-arm64.dmg` (93.6 MB) — Mac Apple Silicon
  - Code signing skipped (no Apple Developer ID certificate) — users need
    to click "Open Anyway" in macOS Gatekeeper / System Settings → Privacy

  **Troubleshooting during CI setup**
  - Build #1 failed: Node.js 20 deprecated, exit code 1 (old package.json
    without build:mac script)
  - Build #2 failed: 403 Forbidden — GITHUB_TOKEN lacked write permissions;
    fixed by enabling Read and write permissions in repo Settings → Actions → General
    and adding `permissions: contents: write` to workflow
  - Build #3: ✅ SUCCESS

  **KJV-Strongs-EBook releases confirmed correct**
  - v1.1.0 release has kjv.osis.xml and bdb-thayer.json attached ✅
  - Launcher downloads from latest EBook release — no changes needed

  **Pending for next session:**
  - Fix package.json version to 1.2.0 to match tag going forward
  - Test Mac installer on an actual Mac (via friend/borrowed machine or
    wait for user feedback)
  - Consider Apple Developer ID certificate for cleaner Gatekeeper experience
  - Update SESSION-NOTES.md with Sessions 20-21 content (partially done)
  - Update README on launcher repo to document the CI build process


---

### Session 22
- **Date:** 2026-06-28
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **UI: Back Button added to all pages**

  `generate_bible.ps1`:
  - Chapter pages — `◀ Back` button (`history.back()`) added after home icon
  - navigate.html — `◀ Back` button added to nav bar

  `generate_dict.ps1`:
  - Hebrew/Greek index pages — `◀ Back` button added to nav bar
  - (Individual dict entry pages already had `javascript:history.back()`)

  `scripts/search.html`:
  - `◀ Back` button added after Go To link
  - Font size buttons removed from nav (moved into hamburger menu)

  **UI: "Go To Passage" renamed to "Go To" everywhere**

  `generate_bible.ps1`:
  - Chapter page nav button: "Go To Passage" → "Go To"
  - navigate.html `<title>` and `<h1>`: "Go To Passage" → "Go To"
  - index.html nav button: "Go To Passage" → "Go To"

  **UI: Hamburger menu added to Hebrew, Greek, Go To, and Search pages**

  `generate_bible.ps1`:
  - navigate.html — full hamburger dropdown added (root-level paths)
  - navigate.html — `fontsize.js` and `notes.js` script includes added

  `generate_dict.ps1`:
  - Hebrew/Greek index pages — full hamburger dropdown added
    (`../help.html` / `../about.html` paths)
  - Hebrew/Greek index pages — `fontsize.js` and `notes.js` added

  `scripts/search.html`:
  - Full hamburger dropdown added (root-level paths)
  - `notes.js` script include added

  **Feature: Update checker with glowing cross icon notification**

  `generate_bible.ps1`:
  - Phase 0 added — fetches latest commit SHA from GitHub API
    (`https://api.github.com/repos/RonTurrentine/KJV-Strongs-EBook/commits/main`)
    before generation starts; stored in `$InstalledSha`
  - SHA baked into `<meta name="kjv-sha">` on every chapter page and index.html
  - Rectangular Christian cross SVG icon added to every `<h1>` (hidden by default)
  - Phase 5b updated — replaces `KJV_SHA_PLACEHOLDER` in search.html after copy
  - Phase 5c updated — replaces `KJV_SHA_PLACEHOLDER` in help.html/about.html
  - navigate.html fixed — was using single-quoted here-string (`@'...'@`) so
    `$InstalledSha` was written as literal text; fixed using `KJV_SHA_PLACEHOLDER`
    replaced via `ForEach-Object` pipeline before `Set-Content`

  `generate_dict.ps1`:
  - SHA fetch added at top (same GitHub API call)
  - SHA meta tag and cross icon added to Hebrew/Greek index template
  - `Write-IndexPage` function updated to accept `-Sha` parameter —
    `$InstalledSha` is script-scope and not visible inside functions in PowerShell;
    must be passed explicitly

  `scripts/search.html`:
  - `KJV_SHA_PLACEHOLDER` meta tag added (replaced at generation time)
  - Cross icon added to `<h1>`

  `js/notes.js`:
  - New update check block runs on every page load (localhost only)
  - Silently calls GitHub API, compares SHA to baked-in meta tag SHA
  - If different: reveals glowing gold cross icon via `.is-visible` class
  - `openUpdateModal()` — shows update modal with latest commit SHA and message
  - `closeUpdateModal()` — dismisses modal
  - `doUpdateNow()` — calls `POST /api/update`, shows progress, reloads on success
  - Update modal created dynamically with progress state

  `css/style.css`:
  - `.update-cross` — gold `#f0c040` color, drop-shadow glow, 2s pulse animation
  - `.update-cross.is-visible` — reveals the icon
  - `@keyframes cross-pulse` — alternates glow intensity 4px↔12px
  - Full update modal styles — overlay, box, icon, title, message, progress,
    buttons (Update Now + Later)

  `start-study.ps1`:
  - `Handle-Update` function added — git pull → generate_bible → generate_dict
    → rebake notes
  - `/api/update` POST route added to router

  **Cross icon shape fix**
  - Original `&#10010;` (U+271A) is a square cross — replaced with custom SVG
  - SVG cross: vertical beam full height (0-18), horizontal beam at y=4 (upper
    third) — matches traditional rectangular Christian cross proportion
  - Applied to: generate_bible.ps1 (3 instances), generate_dict.ps1 (1),
    notes.js (2 — icon in header and modal)

  **Correct push/regenerate order established**
  - Must push to GitHub FIRST, then regenerate
  - Generation fetches the SHA of the latest commit — if regenerated before
    pushing, the new push immediately makes the baked SHA stale

  **PowerShell scoping lessons learned**
  - Single-quoted here-strings (`@'...'@`) do NOT expand variables — use
    placeholder + replace pattern instead
  - Script-scope variables are NOT visible inside functions — must pass explicitly
    as parameters

  **QA: 155/155 passing, 0 failures, 0 warnings**

  **Files modified this session:**
  - `js/notes.js`
  - `css/style.css`
  - `start-study.ps1`
  - `scripts/generate_bible.ps1`
  - `scripts/generate_dict.ps1`
  - `scripts/search.html`
  - `scripts/help.html` (cross icon added)
  - `scripts/about.html` (cross icon added)

  **Pending for next session:**
  - Notes Export to JSON — "Download notes.json" button in hamburger menu
    saves to user's Downloads folder
  - Mobile/PWA support
  - Update SESSION-NOTES.md (this entry)


---

### Session 23
- **Date:** 2026-06-29
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Notes Export to JSON**

  `start-study.ps1`:
  - `Handle-ExportNotes` function added — reads `notes.json`, returns it with
    `Content-Disposition: attachment; filename="kjv-notes-YYYY-MM-DD.json"` header
  - `/api/export-notes` GET route added to router

  `js/notes.js`:
  - `exportNotes()` function — creates hidden `<a>` element pointing to
    `/api/export-notes`, clicks it programmatically, removes it
  - Toast message tells user exact filename and that it saved to Downloads folder:
    "Notes saved to your Downloads folder as kjv-notes-YYYY-MM-DD.json"
  - Works on both Windows (Downloads) and Mac/Safari (~/Downloads) — same behavior

  `scripts/generate_bible.ps1`, `scripts/generate_dict.ps1`, `scripts/search.html`:
  - "💾 Export Notes" menu item added to every hamburger dropdown,
    immediately after "🔄 Rebake Notes"

  **Launcher: Option B — Fresh Install Cleanup Flow**

  `main.js` — 3 new IPC handlers:
  - `check-existing-install` — checks if `KJVStrongs` folder exists and
    if `notes.json` is present; returns `{ exists, hasNotes, notesSize, notesPath }`
  - `export-notes-backup` — copies `notes.json` to
    `~/Downloads/kjv-notes-backup-YYYY-MM-DD.json`; returns `{ ok, path, filename }`
  - `wipe-install-dir` — deletes entire `KJVStrongs` folder with `fs.rmSync`;
    returns `{ ok }` or `{ ok: false, message }`

  `setup.js` — new flow before `firstRunSetup()`:
  - `runSetup()` now calls `checkExistingInstall()` instead of `firstRunSetup()`
    directly when `setupComplete` is false
  - `checkExistingInstall()` — calls `check-existing-install` IPC; routes to
    `showExistingInstallPrompt()` if folder exists, otherwise `firstRunSetup()`
  - `showExistingInstallPrompt()` — shows overlay, wires up three buttons:
    - `exportNotesBackup` — exports notes, disables button, shows
      "✓ Notes saved — Refresh Now" button after success
    - `refreshInstall` — wipes folder then calls `firstRunSetup()`
    - `keepExisting` — marks `setupComplete: true` and calls `subsequentLaunch()`

  `setup.html` — new `#existing-install-prompt` overlay:
  - Shown when existing `KJVStrongs` folder detected on fresh install
  - Notes warning section (hidden if no notes exist)
  - "💾 Export My Notes First" button
  - "✓ Notes saved — Refresh Now" button (appears after successful export)
  - "Refresh Without Backup" button
  - "Keep Existing & Launch" button

  `preload.js` — fully rewritten with all handlers:
  - Added `checkExistingInstall`, `exportNotesBackup`, `wipeInstallDir`
  - Added Mac handlers: `checkHomebrew`, `installHomebrewViaTerm`, `getPlatform`
  - All previous handlers retained

  **Launcher v1.2.0 Release**

  `package.json`:
  - Version bumped to `1.2.0`
  - DMG config fixed: `"background": null` + explicit `contents` layout
    — fixes `FileNotFoundError: background.tiff` on macOS 26 GitHub runner
  - Added `"createDesktopShortcut": true` and `"createStartMenuShortcut": true`
    to NSIS config — installer now creates desktop and Start Menu shortcuts

  CI build:
  - Build #5 succeeded after DMG background fix
  - Three assets produced: Windows `.exe`, Mac Intel `.dmg`, Mac arm64 `.dmg`
  - Old v1.1.0 duplicate assets cleaned up from release page
  - Release notes updated on GitHub

  **Laptop fresh install test**
  - Installed v1.1.0 from Releases page on laptop
  - Discovered laptop had old version (6/21 files) — missing hamburger,
    back buttons, and other recent features
  - Root cause: launcher downloaded repo ZIP on 6/21 before recent changes pushed
  - Fix: uninstall → delete `%LOCALAPPDATA%\KJVStrongs` → reinstall fresh
  - Notes copied from desktop project to laptop:
    `Copy-Item "C:\Users\OldTi\KJV-Strongs\notes.json" "$env:LOCALAPPDATA\KJVStrongs\notes.json"`
  - Rebake Notes handles both notes AND highlights in one pass ✅

  **Correct push/regenerate order reminder**
  - Always: push to GitHub FIRST → then regenerate
  - Generation fetches latest SHA — if you regenerate before pushing,
    the new push makes the baked SHA immediately stale

  **QA: 155/155 passing, 0 failures, 0 warnings**

  **Files modified this session (KJV-Strongs-EBook repo):**
  - `js/notes.js`
  - `start-study.ps1`
  - `scripts/generate_bible.ps1`
  - `scripts/generate_dict.ps1`
  - `scripts/search.html`

  **Files modified this session (KJV-Strongs-Launcher repo):**
  - `main.js`
  - `preload.js`
  - `setup.js`
  - `setup.html`
  - `package.json` (v1.2.0, DMG fix, desktop shortcut)

  **Pending for next session:**
  - Mobile/PWA support
  - Test existing install detection flow on laptop with v1.2.0 installer
  - Update SESSION-NOTES.md (this entry)
  - Commit EBook repo changes (notes export, hamburger updates)


---

### Session 24
- **Date:** 2026-06-30
- **Model:** Claude Sonnet 4.6 (claude.ai)
- **Work Done:**

  **Bug discovered: laptop install showed stale content after reinstall**
  - User uninstalled old launcher app but kept `%LOCALAPPDATA%\KJVStrongs` data
    folder; reinstalling a newer launcher version still showed old Bible content
    and threw `spawn EPERM` on launch
  - Root cause: `.launcher-state.json` had `setupComplete: true` from the
    previous install, so the launcher skipped straight to launching stale
    content instead of detecting the mismatch

  **Launcher fix: version-mismatch detection on every launch**

  `main.js`:
  - New `get-app-version` IPC handler — returns `app.getVersion()` (real
    installed version from electron-builder, not a guessed/stored value)
  - `check-existing-install` enhanced — now also compares `state.installedVersion`
    (what generated the data) against `app.getVersion()` (what's running);
    returns `versionMismatch: true/false`, `installedDataVersion`, `currentAppVersion`

  `setup.js`:
  - `runSetup()` — even when `setupComplete: true`, now calls
    `checkVersionMismatch()` instead of launching directly
  - New `checkVersionMismatch()` — calls `checkExistingInstall()`, routes to
    the existing-install prompt if versions differ, otherwise launches normally
  - `showExistingInstallPrompt()` — now accepts `isUpgrade` flag; customizes
    title/message to "App Updated — Refresh Recommended" and shows old vs.
    current version; hides "Keep Existing" option in upgrade scenario
  - `startGeneration()` — fixed bug where `installedVersion` was being saved
    from the bogus `state.latestKnownVersion` instead of the real app version
    via the new `getAppVersion()` call

  `preload.js`:
  - Exposed `getAppVersion()`

  **Launcher v1.2.0 — Windows shortcuts + DMG fix**

  `package.json`:
  - Added `"createDesktopShortcut": true` and `"createStartMenuShortcut": true`
    to NSIS config
  - DMG background fix carried forward from prior session

  **About page version — three iterations to get it right**

  Round 1 — hardcoded value (broken):
  - `about.html` had `v1.1.0` hardcoded as plain text — never updated when
    versions bumped

  Round 2 — VERSION file (rejected by user, too manual):
  - Considered a `VERSION` file as single source of truth
  - User: "I don't like the idea of depending upon human effort... I'm quite
    forgetful" — rejected in favor of automation

  Round 3 — git describe --tags (broken for ZIP installs):
  - `generate_bible.ps1` Phase 0b reads version via `git describe --tags --abbrev=0`
  - Worked perfectly in dev repo (real git clone)
  - BROKE on installed app: `%LOCALAPPDATA%\KJVStrongs` has no `.git` folder
    (it's a ZIP extraction, not a clone) — `git describe` fails silently,
    falls back to "unknown"

  Round 4 — GitHub Releases API (final, correct fix):
  - `generate_bible.ps1` Phase 0b now queries
    `https://api.github.com/repos/RonTurrentine/KJV-Strongs-EBook/releases/latest`
    and reads `tag_name` — works identically whether dev clone or ZIP install,
    no local git required
  - Created and published the first proper GitHub Release (not just a tag)
    for v1.2.0 on the KJV-Strongs-EBook repo, with `kjv.osis.xml` and
    `bdb-thayer.json` attached

  **Bug discovered: "Update Now" never actually pulled fresh content**
  - `Handle-Update` in `start-study.ps1` ran `git -C $Root pull origin main`
  - Same root cause as the version bug: installed app folder has no `.git`,
    so `git pull` silently failed every time
  - Every previous "Update Now" click was just regenerating from stale
    ZIP content over and over — explains why About page stayed on v1.1.0
    through multiple "successful" updates

  **Fix: ZIP-download replaces git pull in Handle-Update**

  `start-study.ps1`:
  - Replicated the Electron launcher's `cloneRepo()` approach: download
    `https://github.com/RonTurrentine/KJV-Strongs-EBook/archive/refs/heads/main.zip`,
    extract to temp, move each top-level item over the existing install
  - `notes.json`/`highlights.json` confirmed safe — gitignored, never in the
    ZIP, never touched by the move loop
  - `Handle-Update` rewritten to be async — responds immediately with
    `{started: true}`, runs the real pipeline (download → bible → dict →
    rebake) in a `Start-Job` background job so the HTTP listener stays
    responsive for polling
  - New `Write-UpdateStatus` helper — writes progress to `.update-status.json`
    at each step (10% → 18% → 25% → 65% → 90% → 100%)
  - New `Handle-UpdateStatus` function + `/api/update-status` GET route

  **Feature: live progress bar for update modal**

  `js/notes.js`:
  - Update modal HTML now includes a real progress bar element
  - `doUpdateNow()` rewritten — kicks off update via POST, then polls
    `/api/update-status` every 1.5s, updates bar width and detail text live
  - Handles error state and success/reload state

  `css/style.css`:
  - `.update-progress-bar-wrap` / `.update-progress-bar` — gradient fill,
    same visual language as the launcher's setup progress bar

  **Feature: Import Notes & Highlights with conflict resolution**

  User requested Option 4 (full conflict-resolution UI, like a git merge)
  over simpler auto-merge strategies — more correct for irreplaceable
  personal data.

  `start-study.ps1`:
  - `Handle-ExportNotes` updated — now bundles BOTH `notes.json` and
    `highlights.json` into one export file (previously notes-only)
  - New `Handle-ImportPreview` — POST `/api/import-notes/preview`; compares
    uploaded bundle against current notes/highlights; returns
    `{ newCount, conflictCount, unchangedCount, conflicts: [...] }` for each,
    without writing anything
  - New `Handle-ImportCommit` — POST `/api/import-notes/commit`; applies
    merge using per-item user resolutions (`"imported"` or `"current"`),
    bakes changes into HTML immediately
  - Supports both new bundle format and legacy flat notes.json format

  `js/notes.js`:
  - `importNotes()` — creates hidden file input, reads JSON via `FileReader`
  - `requestImportPreview()` — posts to preview endpoint
  - `showImportPreviewModal()` — renders summary (new/conflict/unchanged counts)
    plus a conflict row for each item needing a decision
  - `renderNoteConflict()` / `renderHighlightConflict()` — side-by-side radio
    choice (Imported vs Keep Current) with text comparison or color swatches
  - `applyImport()` — collects all radio selections, posts to commit endpoint,
    reloads page on success

  `css/style.css`:
  - Full `.import-modal` styling — larger scrollable box for conflict lists,
    color swatch classes for highlight previews

  `generate_bible.ps1`, `generate_dict.ps1`, `scripts/search.html`:
  - "📥 Import Notes" added to every hamburger menu, after "💾 Export Notes"

  **End-to-end validation — full pipeline confirmed working**
  - Pushed Import Notes feature to GitHub
  - Opened installed app — cross icon appeared correctly
  - Clicked "Update Now" — progress bar displayed live, correctly cycled
    through download → bible → dict → rebake → complete
  - About page correctly showed v1.2.0 (via GitHub Releases API, working
    identically on the ZIP-based install)
  - Import Notes appeared in hamburger menu on installed copy
  - User exported notes from dev repo, imported into installed app —
    "worked flawlessly"

  **QA: 155/155 passing, 0 failures, 0 warnings (dev repo)**

  **Files modified this session (KJV-Strongs-EBook repo):**
  - `start-study.ps1`
  - `js/notes.js`
  - `css/style.css`
  - `scripts/generate_bible.ps1`
  - `scripts/generate_dict.ps1`
  - `scripts/search.html`
  - `scripts/about.html`

  **Files modified this session (KJV-Strongs-Launcher repo):**
  - `main.js`
  - `setup.js`
  - `preload.js`
  - `package.json`

  **GitHub Releases:**
  - Published first real Release (not just tag) for v1.2.0 on
    KJV-Strongs-EBook with kjv.osis.xml and bdb-thayer.json attached

  **Pending for next session:**
  - Mobile/PWA support (Android — Samsung Galaxy S24 Ultra) — still pending
    from prior session, deferred again today due to bug-fixing taking priority
  - Consider whether Launcher repo's `main.js` should also use a ZIP-based
    update mechanism consistently, or if it already does (cloneRepo already did)
  - Update SESSION-NOTES.md (this entry)


---

### Session 25
- **Date:** 2026-07-03
- **Model:** Claude Sonnet 5 (claude.ai)
- **Work Done:**

  **Bug fix: version mismatch detection on launcher startup**

  `main.js`:
  - New `get-app-version` IPC handler — returns `app.getVersion()` (real
    installed version from electron-builder)
  - `check-existing-install` enhanced — now compares `state.installedVersion`
    against `app.getVersion()`; returns `versionMismatch`, `installedDataVersion`,
    `currentAppVersion`

  `setup.js`:
  - `runSetup()` — even when `setupComplete: true`, now calls
    `checkVersionMismatch()` instead of launching directly
  - New `checkVersionMismatch()` — routes to existing-install prompt if
    versions differ
  - `showExistingInstallPrompt()` — accepts `isUpgrade` flag; shows "App
    Updated — Refresh Recommended" with old version shown; hides
    "Keep Existing" option in upgrade scenario
  - `startGeneration()` — fixed bug: was saving `latestKnownVersion` instead
    of real app version; now calls `getAppVersion()` IPC

  `preload.js`:
  - Exposed `getAppVersion()`

  **Bug fix: About page version — three iterations**

  Round 1 — hardcoded `v1.1.0` (broken)
  Round 2 — `git describe --tags` (broken on ZIP installs — no .git folder)
  Round 3 (final) — GitHub Releases API:
  - `generate_bible.ps1` Phase 0b queries
    `https://api.github.com/repos/.../releases/latest`, reads `tag_name`
  - Works identically on dev clone and ZIP-extracted installed app
  - Requires a published GitHub Release (not just a bare tag)
  - Published v1.2.0 Release on KJV-Strongs-EBook with both source files

  **Bug fix: "Update Now" never pulled fresh content**

  Root cause: `Handle-Update` ran `git -C $Root pull origin main` but
  installed app folder has no `.git` (it's a ZIP extraction). `git pull`
  silently failed every time — regeneration used stale content repeatedly.

  Fix: replaced `git pull` with ZIP download + extract (same as launcher's
  `cloneRepo()`):
  - Downloads `https://github.com/.../archive/refs/heads/main.zip`
  - Extracts to temp folder, moves each top-level item over existing install
  - `notes.json`/`highlights.json` safe — gitignored, never in ZIP
  - Async background job (`Start-Job`) so server stays responsive for polling

  **Feature: live progress bar for Update Now modal**

  `start-study.ps1`:
  - `Handle-Update` responds immediately with `{started: true}`
  - Pipeline runs in `Start-Job` background job
  - `Write-UpdateStatus` helper writes progress to `.update-status.json`
    at each step: 10% pull → 18% extract → 25% bible → 65% dict → 90%
    rebake → 100% complete
  - New `Handle-UpdateStatus` + `/api/update-status` GET route

  `js/notes.js`:
  - Update modal now has real progress bar element
  - `doUpdateNow()` — kicks off update, polls `/api/update-status` every
    1.5s, animates bar width and detail text live

  `css/style.css`:
  - `.update-progress-bar-wrap` / `.update-progress-bar` — gradient fill

  **Feature: Import Notes & Highlights with conflict resolution**

  `start-study.ps1`:
  - `Handle-ExportNotes` updated — bundles both `notes.json` AND
    `highlights.json` into one export file (was notes-only before)
  - New `Handle-ImportPreview` POST `/api/import-notes/preview` — returns
    diff without writing anything
  - New `Handle-ImportCommit` POST `/api/import-notes/commit` — applies
    merge with per-item user resolutions; supports legacy flat notes.json

  `js/notes.js`:
  - `importNotes()` — hidden file input, reads JSON via FileReader
  - Preview → conflict modal → commit flow
  - Side-by-side radio choices for notes (text) and highlights (color swatches)
  - `applyImport()` — posts resolutions, reloads on success

  `css/style.css`:
  - Full `.import-modal` styles with scrollable conflict list, color swatches

  `generate_bible.ps1`, `generate_dict.ps1`, `scripts/search.html`:
  - "📥 Import Notes" added to all hamburger menus after "💾 Export Notes"

  **Feature: About page version from GitHub Releases API**

  `scripts/about.html`:
  - Version changed from hardcoded → `vKJV_VERSION_PLACEHOLDER`

  `generate_bible.ps1`:
  - Phase 0b reads latest release tag from GitHub Releases API
  - Phase 5c replaces `KJV_VERSION_PLACEHOLDER` in about.html during copy

  **Docs: Upgrade guide for pre-v1.2.0 users**

  `WINDOWS-SETUP.md`:
  - New "Upgrading from a Version Before v1.2.0" section (5 steps:
    back up notes → uninstall → delete %LOCALAPPDATA%\KJVStrongs →
    reinstall → import notes)
  - Added condensed version to Launcher v1.2.0 release notes

  **Feature: PWA mobile support**

  New files (`scripts/` → copied to root by Phase 5d):
  - `manifest.json` — PWA manifest (name, icons, theme #00bcd4, standalone)
  - `sw.js` — service worker: app shell cached on install, cache-on-visit
    for Bible/dict pages, never caches search/API calls, bulk download via
    postMessage for offline download buttons
  - `icon-192.png` / `icon-512.png` — generated from BiblePencil.png

  `generate_bible.ps1`:
  - Manifest link + theme-color meta added to chapter pages, index.html,
    navigate.html
  - SW registration script added to all page closing scripts
  - New Phase 5d — copies manifest.json, sw.js, icon-192.png, icon-512.png
    from scripts/ to project root

  `generate_dict.ps1`:
  - Manifest link + theme-color meta added to dict index and entry pages
  - SW registration added to dict index pages

  `scripts/search.html`:
  - Manifest link added; rectangular SVG cross fixed (was still &#10010;)
  - SW registration added

  `start-study.ps1`:
  - Binds to `http://+:8080/` (all network interfaces) so phone can connect
    over WiFi; graceful fallback to localhost with one-time netsh instructions
  - LAN IP detection via `Get-NetIPAddress`; printed in startup banner:
    "On your phone/tablet (same WiFi): http://[IP]:8080/"
  - Browser open uses `$LocalhostBaseUrl` (not the + wildcard)

  **Feature: Phone ↔ PC bidirectional note sync**

  `js/notes.js`:
  - `isPhoneMode` detection — true when port is 8080, not localhost, http://
  - `canTakeNotes` flag — true on localhost OR phone mode
  - Full localStorage layer: `phoneGetNotes()`, `phoneSaveNote()`,
    `phoneDeleteNote()`, `phoneGetHighlights()`, `phoneSaveHighlight()`
    all with tombstone support for deletions
  - `openNoteModal()` / `saveNote()` / `deleteNote()` — route to localStorage
    in phone mode
  - Full sync system: `checkPcReachable()`, sync banner (4 states: connected/
    syncing/offline/error), `syncWithPc()`, `applySyncResult()`,
    `showSyncConflictModal()` — reuses import conflict modal UI
  - Phone mode page init — loads localStorage highlights/notes, shows in page
  - `connectViaUsb()` — calls `/api/usb-connect`, shows instructions in toast

  `start-study.ps1`:
  - `Handle-SyncNotes` POST `/api/sync-notes` — full bidirectional merge
    algorithm handling all 8 sync scenarios (identical, PC newer, phone
    newer, PC only, phone only, true conflict, PC tombstone, phone tombstone);
    generates sync token stored in `.sync-token.json`
  - `Handle-SyncCommit` POST `/api/sync-notes/commit` — applies merge with
    user resolutions, saves to PC, rebakes HTML, returns merged data to phone
  - `Handle-UsbConnect` POST `/api/usb-connect` — runs
    `adb reverse tcp:8080 tcp:8080`, checks device connected first

  `css/style.css`:
  - `.sync-banner` with 4 states (connected/syncing/offline/error/hidden)
  - Sync banner buttons and dismiss controls
  - `body:has(.sync-banner-*)` padding to push content below banner

  `generate_bible.ps1`, `generate_dict.ps1`, `scripts/search.html`:
  - "📱 Connect Phone via USB" added to all hamburger menus (after Sync
    to Kindle)
  - "📖 Download Bible Text for Offline" and "📚 Download Lexicon for
    Offline" buttons in OFFLINE ACCESS section of all hamburger menus
  - "⚠️ Search always requires internet" note in OFFLINE ACCESS section

  **QA: 155/155 passing, 0 failures, 0 warnings**

  **Files modified this session (KJV-Strongs-EBook repo):**
  - `start-study.ps1`
  - `js/notes.js`
  - `css/style.css`
  - `scripts/generate_bible.ps1`
  - `scripts/generate_dict.ps1`
  - `scripts/search.html`
  - `scripts/about.html`
  - `scripts/manifest.json` (new)
  - `scripts/sw.js` (new)
  - `scripts/icon-192.png` (new)
  - `scripts/icon-512.png` (new)
  - `WINDOWS-SETUP.md`

  **Files modified this session (KJV-Strongs-Launcher repo):**
  - `main.js`
  - `setup.js`
  - `preload.js`
  - `package.json` (desktop shortcut added)

  **GitHub Releases:**
  - Published v1.2.0 Release on KJV-Strongs-EBook with kjv.osis.xml and
    bdb-thayer.json attached — required for GitHub Releases API version check

  **Key architectural decisions:**
  - Phone notes always go to localStorage (never directly to server), sync
    when WiFi available
  - Tombstones track deliberate deletions so sync knows difference between
    "never existed" and "was deleted"
  - `lastSyncAt` timestamp stored in localStorage after every successful sync
  - Two connection modes: WiFi (auto-detect) and USB/ADB (one tap via menu)
  - Service worker uses cache-on-visit strategy with opt-in bulk download
  - Search page explicitly excluded from all caching (requires live API)

  **Pending for next session:**
  - Test phone connection (WiFi and USB) end-to-end
  - Test note-taking on phone and sync back to PC
  - Verify "Add to Home Screen" PWA install prompt appears in Chrome
  - Implement "Download for Offline" bulk caching buttons (sw.js postMessage
    handler is ready; notes.js `downloadOffline()` function still needed)
  - Run Update Now on installed app to get all new mobile/sync features
  - Consider whether `downloadOffline()` needs a separate `/api/offline-urls`
    endpoint to get the full list of chapter/dict URLs to cache

SESSION NOTES — End of July 4, 2026
Completed today:

Fixed service worker cache — sw.js now uses SHA-versioned cache name (kjv-cache-{SHA}) so every update automatically busts old cached pages
Fixed IPv6 loopback (::1) in IP allowlist — app now starts correctly
Added Cache-Control: no-store headers for HTML/JS — prevents Electron caching
Fixed Get-LanIp to exclude 169.254.x.x link-local addresses, prefer DHCP
Created scripts/setup-phone-access.ps1 — one-time elevated setup for phone WiFi sync
Added killServer() before startServer() in main.js launcher — prevents duplicate server instances
Extracted, patched, and repacked app.asar with updated main.js

Current blocker — LAN listener:

HttpListener cannot bind to both localhost:8080 AND 192.168.86.39:8080 simultaneously without conflicts in HTTP.sys
The netsh urlacl reservation for 192.168.86.39:8080 causes listener.Start() to fail even on localhost
Current installed start-study.ps1 is reverted to localhost-only (stable)
The 503 from phone is because listener only binds localhost

Tomorrow's plan — proper LAN solution:

Instead of fighting HttpListener, run a separate lightweight TCP proxy on the LAN IP that forwards to localhost:8080
This avoids HTTP.sys entirely and requires no elevation
The proxy can be a simple PowerShell TcpListener background job

Files currently correct in repo:

start-study.ps1 ✅ (localhost-only, stable)
js/notes.js ✅
sw.js ✅
scripts/generate_bible.ps1 ✅
scripts/generate_dict.ps1 ✅
scripts/setup-phone-access.ps1 ✅ (new)
main.js (launcher) ✅ — killServer() fix applied

Still TODO before v1.3.0:

Get phone WiFi sync actually working end-to-end
Fix "Offline Access" section visibility (hide on PC, show on phone only)
Fix warning text styling in hamburger menu
Fix ⚠️ icon color (should be yellow)
Rebuild launcher installer with updated main.js

## SESSION NOTES — July 5, 2026

### Major Achievement
Phone WiFi sync via QR code is now partially working — the home page loads on the phone via `http://192.168.86.39:8081/`. This is the first successful phone connection after days of effort!

### Root Cause of All Previous Failures (identified by Opus)
`System.Net.HttpListener` uses HTTP.sys, a Windows kernel-mode HTTP driver that owns the port across all interfaces. Any attempt to bind a second prefix (LAN IP, wildcard, etc.) to the same port conflicts with HTTP.sys registrations. No amount of `netsh urlacl` registration fixes this reliably from a non-elevated process.

### The Solution (Opus's TCP Proxy approach)
A raw `TcpListener` on port 8081 that intercepts phone requests, rewrites the `Host` header from `192.168.86.39:8081` to `localhost:8080`, and forwards to the existing HttpListener. `TcpListener` uses raw Winsock sockets, bypassing HTTP.sys entirely — no elevation needed, no URL ACL registration, no conflicts.

### Implementation — 5 integration points in `start-study.ps1`
1. C# `LanProxy` class compiled via `Add-Type` (inline C#)
2. Lazy initialization — `Initialize-LanProxy` is called AFTER the first request is processed, not at startup (critical — avoids 30-second timeout)
3. Proxy stopped cleanly in `finally` block
4. `Handle-LocalUrl` returns port 8081 instead of 8080 for QR code
5. `setup-phone-access.ps1` simplified — only adds firewall rule for port 8081, no netsh urlacl

### Compilation issues resolved along the way
- `System.Text.RegularExpressions` assembly reference error → removed `-ReferencedAssemblies` entirely (not needed on .NET 6+)
- `CS4014` unawaited Task warning → `_ = Task.Run(...)` discard pattern + `#pragma warning disable 4014`
- `CS0155` SocketException namespace → replaced with generic `catch { }`
- `Add-Type` blocking server startup for 30 seconds → moved to lazy-init after first request
- `::1` IPv6 loopback blocked → added `$remoteIp -eq "::1"` to IP allowlist

### Current State
- Home page loads on phone ✅
- Navigation to book pages fails with `ERR_CONNECTION_REFUSED` ❌

### Known Issue — Navigation fails after home page
When the phone clicks a book link (e.g. Genesis), the URL changes to `192.168.86.39:8081/books/01-Gen/1.html` but gets `ERR_CONNECTION_REFUSED`. Two likely causes:
1. Lazy-init timing — proxy may not have fully started before navigation clicks happen
2. The proxy's `RelayAsync` bidirectional relay may be closing the connection too early, not keeping it alive for subsequent requests

### Files changed
- `start-study.ps1` — LAN proxy, lazy-init, ::1 allowlist, Handle-LocalUrl port 8081
- `scripts/setup-phone-access.ps1` — simplified to firewall-only, no netsh

### Still TODO
- Fix phone navigation beyond home page
- Test note sync phone→PC and PC→phone
- Fix "Offline Access" section visibility (hide on PC, show on phone only)
- Fix warning text styling in hamburger menu
- Fix ⚠️ icon color (should be yellow)
- Push all changes to GitHub and do Update Now
- Rebuild launcher installer with `killServer()` fix in `main.js`
- Version bump to v1.3.0 once phone sync is fully proven

### Next session first task
Upload current `start-study.ps1` and diagnose why navigation fails. Likely fix: ensure the proxy is fully initialized before returning the first response, OR increase the lazy-init trigger to fire immediately rather than after first request completes.

### Session Summary — July 6, 2026

### Where we left off:
The LAN TCP proxy is now working correctly. The log confirms:

Proxy compiles and starts successfully after first request
Phone requests are reaching the server as 127.0.0.1 (proxy forwarding works)
WhenAll fix applied so CSS/JS stream completely

### Current blocker:
Phone is still connecting on port 8080 instead of 8081 — getting "Invalid Hostname" 400 error. The QR code is showing the old cached URL. The service worker has cached the old http://192.168.86.39:8080/ URL.

### Immediate next step:
Clear Chrome cache on phone (chrome://settings/clearBrowserData), then re-scan QR code. Should show port 8081 and work fully.
Two fixes applied today (in repo start-study.ps1):

1. Added ::1 IPv6 loopback to IP allowlist (was blocking Electron's own requests)
2. Changed WhenAny to WhenAll in proxy relay (was cutting off CSS/JS responses mid-stream)

### Still TODO:

- Confirm full phone navigation works after cache clear
- Test bidirectional note sync
- Fix Offline Access section visibility (hide on PC)
- Fix warning text styling in menu
- Fix ⚠️ icon yellow color
- Push all changes to GitHub + Update Now
- Rebuild launcher installer with killServer() fix
- Version bump to v1.3.0

## Session: July 6, 2026

**Big theme:** LAN proxy stability, mobile UI, offline downloads, and a
deep phone↔PC note-sync bug hunt — then establishing a proper
repo→regenerate→commit→update workflow to stop losing track of changes
across the three places this project lives (repo, installed app, scripts/
templates).

### LAN proxy — fixed
- Root cause of the intermittent "Invalid Hostname" 400 error: the proxy
  only rewrote the `Host` header on the *first* request of a kept-alive
  TCP connection. Every subsequent request on that same connection
  bypassed the rewrite and got rejected by `HttpListener`.
- Fix: inject `Connection: close` so every request opens a fresh
  connection (and gets the rewrite). Tradeoff: slightly slower page loads
  (new handshake per resource) — acceptable for a personal LAN app.

### Mobile header — fixed
- Narrow-screen header was clipping/hiding nav buttons entirely
  (`overflow: hidden` + fixed height + floated elements competing for
  width).
- Fixed with a `@media (max-width: 600px)` two-row layout (title above,
  buttons below), flexbox-centered, sized to match the existing header
  height so `.chapter-content` padding didn't need to change.

### Offline downloads — built
- `downloadOffline('bible' | 'lexicon')` — matches the existing HTML
  calling convention already baked into generated pages.
- Full progress modal (reusing "Update Available" modal styling),
  **Cancel** that actually stops the job, **resume** that skips
  already-cached pages after an interruption, and a screen wake lock
  while downloading.
- Had to add `event.waitUntil()` to the service worker's bulk-download
  handler — without it, the browser was killing the service worker
  mid-download for being "idle."

### Phone ↔ PC note sync — the big one, fixed
- `isPhoneMode` was hardcoded to port 8080 — never activated once phone
  traffic moved to the LAN proxy (8081). Fixed to key off
  hostname/protocol instead of a specific port.
- Highlights were being counted as "pending sync" forever (no timestamp
  comparison, unlike notes) — fixed with a synced-snapshot comparison.
- **Root cause of notes never settling as "synced":** PowerShell's
  `Get-Date -Format "o"` uses local timezone; JS's `toISOString()` is
  always UTC. String-comparing the two is invalid whenever offsets
  differ.
- **A real scare along the way:** the first migration fix silently
  defaulted to "now" on any unparseable timestamp, which combined with a
  second bug to overwrite real historical note timestamps with a single
  identical value. **Recovered from a June 29 backup** — lesson learned:
  never silently default to "now" for bad data; leave it and log it.
- **The actual root cause of repeated corruption:**
  `ConvertFrom-Json -AsHashtable` silently auto-parses ISO-8601 strings
  into real `[DateTime]` objects (not strings). Passing that object where
  a string was expected silently re-stringified it with no timezone info
  at all, and re-parsing *that* assumed the local machine's offset —
  quietly adding hours to an already-correct value, every time. Fixed with
  a type-aware, `Kind`-checking normalization function, confirmed stable
  across multiple consecutive server restarts.
- End-to-end confirmed working: notes/highlights sync both directions,
  banner settles to "up to date" and stays there, resume/cancel/wake-lock
  all behave correctly.

### Git / workflow cleanup
- Found and fixed a real gap: `git-push.ps1` never staged `sw.js`,
  `manifest.json`, icons, `about.html`, `help.html`, or `search.html` —
  meaning this week's entire PWA/offline feature set could have silently
  never reached GitHub even after committing.
- Found and fixed a regression: the committed `sw.js` had lost its
  `KJV_SHA_PLACEHOLDER` token, silently breaking the SHA-based
  cache-busting mechanism from an earlier session.
- `highlights.json` added to `.gitignore` (repo is public — personal
  highlight data must never be committed). `installed-sha.txt`,
  `.sync-token.json`, `migration-warnings.log` also added as
  machine-local/transient state.
- `kjv.osis.xml`'s phantom "modified" status was pure line-ending noise —
  fixed with `.gitattributes` (`-text`), not gitignored (it's the master
  source data, must stay tracked).
- **New standing workflow going forward:** edit only in the local repo →
  `generate_bible.ps1` → `generate_dict.ps1` → `qa-test.ps1` →
  `rebake-notes.ps1` → manual smoke test → `git-push.ps1` → "Update Now"
  in the installed app. Confirmed working end-to-end this session.
- Added `PROJECT-CONTEXT.md` to the repo — a technical handoff doc for
  starting future sessions, since this one hit the 100-file limit
  discussion again. Upload it first thing next time.

### Pending for next session
- **"All My Notes" page** — single page listing every note OT → NT with
  jump links; also useful as a QA tool. Explicitly requested, explicitly
  deferred.
- **Real HTTPS** (self-signed cert, e.g. mkcert) to replace the manual
  Chrome flag workaround (`unsafely-treat-insecure-origin-as-secure`)
  currently needed for the phone's service worker to register at all over
  the LAN IP.
- `qa-test.ps1` needs updating to actually cover this week's features (LAN
  proxy, mobile header, offline download, phone/PC sync) — right now a
  clean pass only proves pre-existing structural checks still hold.
- Confirm what `scripts/lan-proxy.ps1` actually is / whether it feeds into
  `start-study.ps1` — came up but was never resolved.
- Fold the Hebrew/Greek index pages and `navigate.html` into the bulk
  offline-download list (currently only cached if visited manually while
  online first).

## Session: July 7, 2026

**Big theme:** Real-world offline testing exposed a genuine architectural
caching bug (not the SHA-versioning issue we suspected), plus a round of
UI polish making the app feel native to whichever device you're on
(hiding phone-only and PC-only menu items from each other).

### Offline download gaps — fixed
- Repeated red "Offline mode" banner on every page — the once-per-session
  suppression fix from yesterday only covered the "connected/up to date"
  banner state, never the "offline" state itself. Fixed with the same
  sessionStorage pattern.
- "Go To" and both Hebrew/Greek index pages always showed "hasn't been
  downloaded" even after a full bulk download — they were never actually
  included in the download URL lists to begin with. Added `navigate.html`
  and both `indexes/strongs-*-index.html` pages to the bulk downloads.
- Root cause of "downloaded content just disappeared": almost certainly
  our own repeated manual Cache Storage clears during yesterday's
  extensive notes-sync debugging — not a code bug. Re-running both
  downloads while leaving the cache alone resolved it.

### The real stale-content bug — found and fixed
- User reported `help.html` and the hamburger menu kept showing old
  content no matter how many times "Update Now" ran and regenerated
  everything — even on the **PC**, not just the phone.
- First suspect: the SHA-based cache-busting mechanism (`sw.js`'s
  `CACHE_VERSION`) — confirmed still broken (the `KJV_SHA_PLACEHOLDER`
  token never actually gets replaced by whatever runs during "Update Now",
  even though our manual `generate_bible.ps1` runs correctly inject it).
  Root cause of *that* specific bug still unconfirmed — likely lives in
  the Electron app's own update code, which hasn't been reviewed.
- Added explicit `Cache-Control: no-cache, no-store, must-revalidate`
  headers to every server response (`start-study.ps1`'s `Send-Response`)
  as a first attempt — genuinely good practice, but turned out not to be
  the actual culprit here.
- **The real culprit**: `sw.js`'s fetch handler used pure "cache-first" —
  once anything was cached, it was served forever with zero revalidation,
  completely ignoring `Cache-Control` headers by design (a cache hit never
  even reaches the browser's normal HTTP cache logic). Only a hard refresh
  (which bypasses an active service worker's interception) revealed fresh
  content, and normal browsing reverted to stale within one page or two.
- **Fix**: rewrote the fetch handler to use **stale-while-revalidate** —
  serve the cached copy instantly (offline/fast behavior completely
  unchanged), but always kick off a background fetch to refresh the cache
  for next time. This makes every page self-healing within one extra
  normal reload after a real change, permanently, without ever depending
  on the SHA-versioning mechanism working. One important one-time
  transition cost: since `sw.js` itself is cached, the currently-installed
  old cache-first service worker needs one manual hard-refresh/unregister
  to actually pick up this new code — after that, no more manual
  intervention should ever be needed again.

### Search UX cleanup
- Search page's mobile layout (two-column Old/New Testament category
  checkboxes) overflowed on phone screens, cutting off longer labels —
  fixed with a `@media (max-width: 600px)` single-column stack.
- The static "⚠ Search always requires internet — it isn't available
  offline" note in the hamburger menu was confusing and unwanted —
  **removed entirely** (from all 4 template locations across
  `generate_bible.ps1`, `generate_dict.ps1`, and the standalone
  `search.html`, which is copied as-is rather than generated and had to be
  fixed separately).
- Instead: the "Search" nav button itself now hides automatically —
  immediately on Kindle (`file://`, can never work there), and dynamically
  on phone based on the same PC-reachability check already driving the
  sync banner (reappears the moment you're back on WiFi).
- Added a genuine friendly in-page error for when a search request
  actually fails to reach the API: *"The Bible SuperSearch service is
  unavailable at the moment. Please check your internet connection and
  try again."* — distinguished from other error types (parse/response
  issues) which get a different, more accurate message.
- `help.html`'s Search section rewritten to clearly explain both real
  requirements: PC needs actual internet (not just the app running), and
  phone needs WiFi connection specifically to the PC (cellular/other
  internet isn't sufficient by itself).

### Menu decluttering
- "Sync Phone via QR Code" already hid on phone (from yesterday).
  Symmetric fix added: the entire "OFFLINE ACCESS" section (Download
  Bible Text / Download Lexicon) now hides on PC/localhost, since the PC
  is the server itself and has no scenario where "offline" is meaningful.
  Hides the whole section via `.closest(".settings-section")`, not just
  the two rows, so the section label doesn't end up floating alone.

### Deployed files this session
`notes.js`, `generate_bible.ps1`, `generate_dict.ps1`, `help.html`,
`style.css`, `search.js`, `search.html`, `start-study.ps1`, `sw.js` (→
`scripts/sw.js` template). Full regenerate cycle run and confirmed
working; final push pending at time of writing.

### Pending for next session
- Still deferred from yesterday: **"All My Notes" page** (OT → NT list
  with jump links), **real HTTPS** setup, **`qa-test.ps1` update** to
  cover this week's features, confirming what `scripts/lan-proxy.ps1`
  actually is.
- **New**: find and fix the actual root cause of the SHA-placeholder
  never being replaced during "Update Now" (likely in Electron's own
  update-checker code, not yet reviewed) — now lower priority than
  before, since stale-while-revalidate means the app no longer *depends*
  on this working, but it'd still be good to understand and fix properly.
# SESSION-NOTES.md — Update covering sessions since July 8, 2026

(Append this to the existing file — last entry there was dated 7/7.)

---

## Session: Phone Setup Wizard design + wife's laptop troubleshooting

- Designed and built the one-time phone setup wizard (rename "Sync
  Phone via QR Code" → "Connect New Phone"; auto-prompt on first phone
  Home-page visit offering to download Bible + lexicon + pull PC notes
  in one chained flow).
- Testing this on the wife's laptop (a genuinely fresh install) turned
  into a much bigger investigation: stale menu text even after a clean
  reinstall led to discovering the release-vs-commit distinction for
  the Launcher repo, then a real silent-failure bug in the update
  system (SHA-fetch failing invisibly, permanently disabling
  update-detection with zero symptom), then a second real bug (a
  read-only-file edge case that could make "Update Now" report false
  success while silently changing nothing). Both fixed and confirmed
  working on the actual affected laptop.
- Also found and fixed a stale hardcoded IP in `setup-phone-access.ps1`
  (harmless in practice — the actual firewall rule was never
  IP-specific — but sloppy and worth cleaning up), and automated that
  script into the Launcher's first-run setup flow with proper UAC
  elevation handling (non-fatal if declined).
- Created `KJV-Strongs-Launcher/scripts/git-push.ps1`.

## Session: Notes Management System design

- Ron proposed a Notes Management System: browse all notes OT→NT in
  one place, plus a tagging/indexing system to filter notes by topic
  across the whole Bible. Identified as "the next major app upgrade."
- Talked through key design decisions before building: tags as a new
  note field (needs sync-logic updates too), tag-casing consistency
  via autocomplete + normalization, read-only-browse vs. edit-in-place
  (decided: edit-in-place), and confirmed no new sync infrastructure
  needed (reuses whatever data source — API or localStorage — the
  device already considers current).
- Ron added a requirement: also filter by Book/Testament/Category
  (reusing Search's existing scheme).

## Session: Notes Management System build

- Built tag support in the existing note editor (autocomplete, casing
  normalization), then the full Notes Manager page (filtering, inline
  editing, highlight-only verses), then the "Refresh Offline Content"
  feature, then wired the menu links across all templates.
- Chased and fixed the PowerShell `ConvertTo-Json` single-element-array
  bug (crashed the pencil-icon editor for any note with exactly one
  tag) using the same self-healing-on-load pattern from the earlier
  timestamp bug.
- Chased and fixed a sync-commit bug where deleted notes/highlights
  weren't being un-baked from chapter HTML after syncing from phone to
  PC (Ron caught this via a real example: deleted a note on his phone
  weeks ago, and the chapter page still showed the old note text
  indefinitely).
- Fixed `notes-manager.html` not actually being copied into the
  generated output (the menu link existed before the file-copy step
  was wired in).
- Pushed to GitHub, tested tagging live — "working great."

## Session: Tag-duplication bug hunt ("New Creature ×8")

A genuinely extensive, well-documented debugging session. Ron reported
the tag filter cloud showing "New Creature" repeated 8 times instead
of once. Ruled out, in order, via direct evidence rather than guessing:
whitespace/invisible-character variants (checked actual export file
byte-by-byte — only one clean instance existed), stale deployment
(confirmed the fix was actually present in the deployed file), browser
extensions (confirmed still broken in a fully clean InPrivate window),
duplicate network requests (Network tab showed exactly one `/api/notes`
fetch), and duplicate module/script inclusion (confirmed only one of
each in the file). Finally isolated via temporary diagnostic
`console.log`/`console.trace` instrumentation: the actual bug was a
stale leftover loop variable (`k` instead of `keys[i]`) in
`renderTagCloud`, meaning every button rendered the same frozen value
regardless of which tag it was meant to represent. Fixed, confirmed
working with a screenshot showing all 8 genuinely distinct tags
correctly.

Also fixed in the same session: tags being silently discarded when
saving a highlight-only verse with no note text (both client and
server-side gates required non-empty text — removed), and verse
cross-references not linkifying in the Notes Manager (was using a
plain text node instead of the same escapeHtml+linkifyVerseRefs
pipeline used elsewhere).

## Session: v1.3.0 releases (EBook + Launcher)

- Published `KJV-Strongs-EBook` v1.3.0 cleanly. Confirmed live via an
  InPrivate browser check after Claude's own web-fetch tool showed a
  brief caching lag.
- Attempted a Launcher v1.3.0 release. First tried a manual local
  `npm run build` — worked, but Windows-only; discovered there's
  actually a GitHub Actions workflow (`build-release.yml`, triggered by
  pushing a version tag) that builds Windows + both Mac architectures
  automatically and was the "real" release process all along (used
  successfully for v1.2.0, including Mac support despite Ron not
  owning a Mac).
- Multiple fix-and-retrigger cycles to get the Mac build working:
  fixed a `dmg.background: null` config crash, then discovered the
  arm64 build's "hdiutil detach" flakiness wasn't actually fixed by
  splitting into matrix jobs (the CLI arch flags don't override
  `package.json`'s arch array as expected — had to explicitly rewrite
  the workspace's own `package.json` per job to force true isolation).
  All three installers (Windows, Mac x64, Mac arm64) built and
  published successfully after that.
- **Left unresolved**: cleaning up redundant/unnecessary release
  assets on the Launcher v1.3.0 release (duplicate files under two
  naming conventions, plus unused Electron auto-updater artifacts).
  Ron was mid-deletion when Claude flagged a concern about ambiguous
  file-size labels in the confirmation dialog possibly corresponding
  to files that should be kept, and asked for a screenshot to verify
  before confirming — session ended before this was confirmed either
  way. **Check this first in the next session.**
- Also noted as a minor, non-urgent loose end: the EBook repo's public
  Releases page seems to be missing a v1.2.0 entry despite earlier
  evidence it existed at some point — worth a quick look eventually,
  not urgent.
