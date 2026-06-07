# KJV Strong's Demo

## Overview
This workspace is a static proof-of-concept for generating KJV Bible HTML pages with Strong's references, verse notes, and cross-reference pages.

## Current entrypoints
- `index.html` — main project home page and demo entrypoint
- `sample-index.html` — sample navigation hub for Genesis 1 note/xref pages
- `sample-chapter-gen1.html` — sample Genesis 1 chapter page with verse anchors and note/xref links
- `sample-verse.html` — single verse sample page with Strong's links and note/xref markers
- `sample-verse-2.html` — alternate single verse sample page

## Navigation behavior
- `sample-index.html` links directly to every sample note/xref page for Genesis 1:1–1:10
- `sample-note-gen1-*.html` and `sample-xref-gen1-*.html` include a top nav button back to `sample-index.html`
- note/xref pages also include "Back to chapter" and "Back to verse" buttons where appropriate
- `js/navigation.js` preserves chapter return anchors when `source=chapter&verse=X` is present in the page query

## How to preview
Open `index.html` in your browser, or run a local static server from the workspace root:

```powershell
cd 'C:\Users\OldTi\KJV-Strongs'
python -m http.server 8000
```

Then open `http://localhost:8000/index.html`.

## Next steps
1. Generate actual Bible HTML from `kjv.osis.xml`
2. Generate Strong's dictionary pages from `StrongHebrewG.xml` and `strongsgreek.xml`
3. Add a script to automate HTML output for chapters, books, and dictionary entries
4. Expand `index.html` into a full TOC for generated Bible and dictionary pages

## Notes
- Styles are shared through `css/style.css`
- The current demo uses static sample files to validate UX and navigation patterns
- Future work should make note/xref generation dynamic and linkable from generated chapters
