# KJV Strong's Bible with Concordance

A complete, offline-capable KJV Bible study tool with Strong's Hebrew/Greek lexicon,
BDB/Thayer definitions, personal notes, and full concordance — designed for both
PC (localhost) and Kindle Fire tablet.

![KJV Strong's Bible](https://img.shields.io/badge/KJV-Strong's%20Concordance-00bcd4)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-blue)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Mac-lightgrey)

---

## Features

### Bible Text
- Complete KJV Bible — all 66 books, 1,189 chapters
- Every word linked to its Strong's Hebrew or Greek number
- Clean, readable dark theme optimized for extended study
- Font size controls (a↓ / A↑), reading position bookmarks
- ☰ hamburger settings menu — font size, Strong's toggle, Sync to Kindle, Rebake Notes
- 🏠 Home button returns to the main book index from any page
- Keyboard shortcuts: `Ctrl+]` increase font, `Ctrl+[` decrease font, `H` toggle Strong's
- `[◀B][◀C][C▶][B▶]` navigation buttons for chapter and book jumping
- **Go To Passage** — jump to any book, chapter, and verse instantly

### Strong's Lexicon
- 8,674 Hebrew dictionary pages (H0001–H8674)
- 5,624 Greek dictionary pages (G0001–G5624)
- Each entry shows:
  - Strong's definition and KJV usage
  - **BDB/Thayer hierarchical definition** with nested sub-definitions
  - Clickable origin cross-references
  - **Complete concordance** — every Bible occurrence with English translation
- Paginated Hebrew and Greek index pages with [BEG]/[END] navigation

### Personal Study Notes
- Add notes to any verse via a gold ✏ pencil button
- Rich modal editor with **book picker** for easy verse linking
- Link to any verse using `[[Book.Ch.Vs]]` syntax (e.g. `[[John.3.16]]`)
- Notes bake instantly into the HTML — visible on Kindle without server
- Sync to Kindle via ⚡ Sync to Kindle in the ☰ hamburger menu (grayed out when no device connected)

### Verse Highlighting
- 4 pastel highlight colors (yellow, green, red, blue)
- Color picker built into the note modal — highlight and note together
- Highlights bake into the HTML and sync to Kindle automatically
- Visible in both study mode and clutter-free reading mode

### Reading Mode
- 👁 eye toggle hides all Strong's number badges for distraction-free reading
- One click switches between study mode and reading mode
- Preference remembered as you navigate between chapters

### English Word Search (PC only)
- Search the full KJV text for any English word or phrase
- Powered by the free Bible SuperSearch API — no setup required
- **Scope your search**: Whole Bible, a specific book, or any combination of
  categories (Torah, Historical, Poetic/Wisdom, Prophetic, Gospels, Acts,
  Paul's Epistles, General Epistles, Revelation)
- Adjustable results per page (50/100/200/All) with [BEG]/[END] pagination
- Click any result to jump straight to that verse
- Results persist when you navigate to a verse and come back
- Requires an internet connection — not available on Kindle

### Kindle Fire Support
- Fully tested on Kindle Fire D01E (Android 2.3 WebKit)
- Two-row centered header fits all book names
- Two-column OT/NT book index
- Baked notes with green italic styling
- Baked verse highlights with pastel colors
- Complete concordance with expand/collapse sections
- Push all 15,000+ files to Kindle via ADB

---

## Quick Start

### Option A — Electron Launcher (easiest, recommended for new installs)

Download `KJV Strong's Bible Setup.exe` from the [GitHub Releases page](https://github.com/RonTurrentine/KJV-Strongs-EBook/releases) and run it. The launcher will:
- Install PowerShell 7+ if needed
- Download all required source files automatically
- Generate all 1,189 chapters and 14,298 dictionary pages
- Start the study server and open the Bible in an embedded window

> **Note:** Your antivirus may scan files during setup — this is normal and harmless. If asked to allow or trust the app, click **Allow**.

### Option B — Manual Setup

### Requirements
- PowerShell 7+ (`pwsh`)
- ADB (Android Debug Bridge) — for Kindle push only

### Source files required (not in repo — too large)
These are downloaded automatically by the Electron Launcher, or can be obtained
from the [GitHub Releases page](https://github.com/RonTurrentine/KJV-Strongs-EBook/releases):
- `kjv.osis.xml` — KJV Bible in OSIS format with Strong's numbers
- `bdb-thayer.json` — BDB/Thayer lexicon (pre-exported JSON, ~6.5MB)

The following are bundled in the repo and do not need to be downloaded separately:
- `StrongHebrewG.xml` — Hebrew Strong's lexicon
- `strongsgreek.xml` — Greek Strong's lexicon

### Generation (one-time setup)

```powershell
# 1. Generate all 1,189 Bible chapters + concordance index
pwsh -NoProfile -File .\scripts\generate_bible.ps1

# 2. Generate all 14,298 dictionary pages with BDB definitions
pwsh -NoProfile -File .\scripts\generate_dict.ps1

# 3. Verify output (155+ tests)
pwsh -NoProfile -File .\scripts\qa-test.ps1
```

> **Note:** If you need to regenerate `bdb-thayer.json` from scratch (e.g. you have
> an updated MyBible source file), you will need SQLite3 and can run:
> `pwsh -NoProfile -File .\scripts\export-bdb.ps1`

### Running the Study Server

Double-click `start-study.bat` — the server starts at `http://localhost:8080`
and your browser opens automatically.

Or from PowerShell:
```powershell
pwsh -NoProfile -File .\start-study.ps1
```

### Pushing to Kindle Fire

```powershell
# Build EPUB and push all files to Kindle via ADB
pwsh -NoProfile -File .\scripts\package_epub.ps1
```

Then open Silk browser on Kindle and navigate to:
`file:///data/local/tmp/index.html`

---

## Scripts Reference

| Script | Purpose |
|--------|---------|
| `start-study.ps1` | Local HTTP server + notes API |
| `start-study.bat` | Double-click launcher for Windows |
| `scripts/generate_bible.ps1` | Generate all Bible chapter HTML + concordance.json |
| `scripts/generate_dict.ps1` | Generate all dictionary HTML with BDB + concordance |
| `scripts/export-bdb.ps1` | Export BDB/Thayer SQLite database to JSON |
| `scripts/qa-test.ps1` | Run 155+ quality assurance tests |
| `scripts/rebake-notes.ps1` | Restore baked notes after regeneration |
| `scripts/package_epub.ps1` | Build EPUB archive + push to Kindle |
| `scripts/adb-push-all.ps1` | Push all files to Kindle via ADB |
| `scripts/git-push.ps1` | Stage and push to GitHub |

---

## Project Structure

```
KJV-Strongs-EBook/
├── start-study.ps1          Local HTTP server with notes API
├── start-study.bat          Windows double-click launcher
├── BiblePencil.ico          App icon / browser favicon
├── index.html               Main book index (generated)
├── navigate.html            Go To Passage (generated)
├── search.html               English word search, PC only (generated)
├── books/                   1,189 chapter HTML files (generated)
│   └── {NN}-{Abbr}/
│       └── {ch}.html
├── dict/                    14,298 dictionary pages (generated)
│   ├── hebrew/              h0001.html – h8674.html
│   └── greek/               g0001.html – g5624.html
├── indexes/                 Strong's index pages (generated)
├── css/
│   ├── style.css            PC stylesheet
│   └── style-kindle.css     Kindle Fire stylesheet
├── js/
│   ├── notes.js             Notes + highlights system + Kindle sync
│   ├── search.js            English word search (PC only)
│   ├── bible-data.js        Book/chapter metadata
│   ├── fontsize.js          Font size + reading mode toggle
│   ├── bookmarks.js         Reading position memory
│   └── sticky-header.js     Fixed/absolute header behavior
└── scripts/                 PowerShell generators and utilities
```

---

## Platform Support

| Platform | Status | Guide |
|----------|--------|-------|
| Windows 10/11 (Launcher) | ✅ Fully supported | Download from Releases page |
| Windows 10/11 (Manual) | ✅ Fully supported | [WINDOWS-SETUP.md](WINDOWS-SETUP.md) |
| macOS (Manual) | ✅ Supported via PowerShell Core | [MAC-SETUP.md](MAC-SETUP.md) |
| Kindle Fire D01E | ✅ Fully tested | See Quick Start above |
| Other Kindle models | 🔜 Planned | Future release |

---

## Gitignored Files (not in repo)

These files are generated locally and excluded from the repository:

| File | Purpose |
|------|---------|
| `notes.json` | Your personal study notes |
| `highlights.json` | Your personal verse highlights |
| `concordance.json` | Strong's concordance index (~22MB) |
| `bdb-thayer.json` | BDB/Thayer lexicon (~6.5MB) — download from Releases page |
| `KJV-Strongs.epub` | Built EPUB archive |
| `kjv.osis.xml` | KJV source XML — download from Releases page |

---

## Bible Text Edition

This project uses the **King James Version (1769) Blayney Standard Edition** —
the scholarly standard text that nearly all modern KJV Bibles are based on.

The KJV was first published in 1611, but the text widely recognized as "the
KJV" today is the result of Benjamin Blayney's 1769 Oxford revision, which
standardized spelling, punctuation, and corrected printing errors that had
crept into earlier editions. The source OSIS file used by this project
carefully tracks textual details down to individual punctuation marks
(e.g. a documented comma discrepancy between Blayney's quarto and folio
editions at Genesis 1:2), and aligns the Words of Christ (red letter
markup) with Louis Klopsch's 1901 edition — the publisher who popularized
red-letter Bibles.

## Acknowledgements

- KJV Bible text and Strong's numbers: OSIS format, King James Version
  (1769) with Strong's Numbers and Morphology, from open Scripture sources
- Hebrew lexicon: Strong's Hebrew and Aramaic Dictionary
- Greek lexicon: Strong's Greek Dictionary
- BDB definitions: Brown-Driver-Briggs Hebrew Lexicon
- Thayer definitions: Thayer's Greek Lexicon
- BDB/Thayer data pre-exported from MyBible dictionary format and hosted
  as a release asset — end users do not need MyBible or SQLite3
- English word search powered by the free Bible SuperSearch API
  (api.biblesupersearch.com)

---

## License

This project is for personal Bible study use.
Scripture text is in the public domain (KJV, published 1611).
Strong's numbering system is in the public domain.
BDB/Thayer lexicon data sourced from MyBible — please respect their terms of use.

---

*Built with PowerShell 7, static HTML, and a love for God's Word* 📖
