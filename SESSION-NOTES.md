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

