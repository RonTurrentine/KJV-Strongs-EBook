# KJV Strong's Demo

## Overview
This workspace is a static proof-of-concept for generating KJV Bible HTML pages with Strong's references, verse notes, and cross-reference pages.

The current generator focuses on Genesis 1 and produces:
- a sample chapter page with verse anchors and Strong's link markup
- a shared verse page template driven by query parameter navigation
- interactive note and cross-reference sample pages

## Current entrypoints
- `index.html` — main project home page and demo entrypoint
- `sample-index.html` — sample navigation hub for Genesis 1 note/xref pages
- `sample-chapter-gen1.html` — sample Genesis 1 chapter page with verse anchors and note/xref links
- `sample-verse.html` — generic verse sample page with Strong's links and note/xref buttons
- `sample-verse-gen1.html` — generated Genesis 1 verse viewer page

## Navigation behavior
- `sample-index.html` links directly to every sample note/xref page for Genesis 1:1–1:10
- `sample-note-gen1-*.html` and `sample-xref-gen1-*.html` include a top nav button back to `sample-index.html`
- note/xref pages also include "Back to chapter" and "Back to verse" buttons where appropriate
- `js/navigation.js` preserves chapter return anchors when `source=chapter&verse=X` is present in the page query

## Repository helper script
A lightweight PowerShell helper is available at `build.ps1`.
It provides Makefile-style tasks for common project actions.

Run the script with:

```powershell
cd 'C:\Users\OldTi\KJV-Strongs'
.\build.ps1 -Task generate
```

Available tasks:
- `help` — show usage information
- `generate` — run the Genesis 1 page generator
- `validate` — verify generated sample output files
- `preview` — display local preview instructions and open `index.html`
- `ci` — run generation plus validation
- `all` — alias for `ci`

## Generator script
The PowerShell generator script is `generate_genesis1.ps1`.
It reads `kjv.osis.xml` and writes the sample chapter and verse pages for Genesis 1.

Run the generator locally with:

```powershell
cd 'C:\Users\OldTi\KJV-Strongs'
pwsh -NoProfile -File .\generate_genesis1.ps1
```

## How to preview
Open `index.html` in your browser, or run a local static server from the workspace root:

```powershell
cd 'C:\Users\OldTi\KJV-Strongs'
python -m http.server 8000
```

Then open `http://localhost:8000/index.html`.

## CI workflow
This repository includes a GitHub Actions workflow at `.github/workflows/ci.yml`.
It runs on `push` and `pull_request` to `main`, executes the Genesis 1 generator, and verifies the expected sample output files.
The workflow also checks generated sample markup for key UI class names like `chapter-nav`, `btn`, `icon-btn`, and `superscript-link` to catch broken generator output early.

## Next steps
1. Generate actual Bible HTML from `kjv.osis.xml`
2. Generate Strong's dictionary pages from `StrongHebrewG.xml` and `strongsgreek.xml`
3. Add a script to automate HTML output for chapters, books, and dictionary entries
4. Expand `index.html` into a full TOC for generated Bible and dictionary pages

## Notes
- Styles are shared through `css/style.css`
- The current demo uses static sample files to validate UX and navigation patterns
- Future work should make note/xref generation dynamic and linkable from generated chapters
