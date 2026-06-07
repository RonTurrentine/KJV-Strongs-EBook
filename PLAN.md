# KJV Strong's Converter - Project Plan

## Project Goals
1. Convert OSIS XML Bible (with Strong's references) to interactive HTML
2. Generate dictionary entry pages for Hebrew (H####) and Greek (G####) Strong's references
3. Create interlinking between Bible verses and dictionary entries
4. Package into EPUB format using Calibre
5. Deploy to Kindle Fire tablet (Android 2.x) via ADB

## Phase 1: Data Analysis & Preparation

### Task 1.1: Analyze OSIS XML Structure
- [ ] Parse kjv.osis.xml to understand:
  - Total verse count and structure
  - Strong's reference patterns (single, multiple per word)
  - Special markup (transChange, milestone, note elements)
  - Namespace handling requirements

**Suggested approach:** PowerShell script to scan XML and generate statistics

### Task 1.2: Index Strong's Lexicon Files
- [ ] Parse StrongHebrewG.xml and extract:
  - All Hebrew entries (H0001 to H8674)
  - Structure: definition, transliteration, phonetic, etymology, cross-refs
  - Create searchable index for fast lookup

- [ ] Parse StrongsGreek.xml and extract:
  - All Greek entries (G0001 to G5624)
  - Same data structure as Hebrew

**Suggested approach:** PowerShell or Python to build JSON lookup tables for fast access

### Task 1.3: Validate Data Integrity
- [ ] Check for missing Strong's references in dictionary files
- [ ] Identify cross-references between entries
- [ ] Note any encoding issues (Unicode, special characters)

---

## Phase 2: HTML Generation Pipeline

### Task 2.1: Create Bible HTML Generation Script
**Input:** kjv.osis.xml  
**Output:** Individual HTML files per book (Genesis.html, Exodus.html, etc.)

**Structure per verse:**
```html
<p class="verse">
  <span class="verse-number">1</span>
  In the beginning
  <a href="dict/H7225.html" class="strongs">[H7225]</a>
  God
  <a href="dict/H0430.html" class="strongs">[H0430]</a>
  created
  <a href="dict/H1254.html" class="strongs">[H1254]</a>
  ...
</p>
```

**Requirements:**
- Preserve verse structure and numbering
- Extract Strong's lemma attributes and convert to links
- Handle multiple lemmas per word
- Proper text encoding (UTF-8)
- Kindle-compatible CSS only

**Suggested approach:** PowerShell with XML namespace support, or Python with lxml

### Task 2.2: Create Dictionary Entry Page Generator
**Input:** StrongHebrewG.xml, StrongsGreek.xml  
**Output:** Individual HTML files per entry (dict/H0430.html, dict/G3962.html)

**Dictionary page structure:**
```html
<h1>H430</h1>
<div class="entry">
  <div class="original">אלהים</div>
  <div class="transliteration">ĕlôhîym</div>
  <div class="phonetic">el-o-heem'</div>
  <div class="definition">
    <h2>BDB Definition:</h2>
    <ul>
      <li>rulers, judges</li>
      <li>divine ones</li>
      <li>angels</li>
      ...
    </ul>
  </div>
  <div class="etymology">
    <p>Origin: plural of H433</p>
    ...
  </div>
  <!-- Cross-reference links to related entries -->
  <div class="see-also">
    <p><a href="H0433.html">See H433</a></p>
  </div>
</div>
```

**Requirements:**
- Extract all entry fields from XML
- Convert internal Strong's references to hyperlinks
- Maintain Unicode for original language text
- Kindle-compatible HTML/CSS

### Task 2.3: Create Navigation & Index Files
**Output:** index.html, book-list.html, concordance pages

**Suggested structure:**
```
index.html (main TOC)
  ├── Old Testament (TOC)
  │   ├── Genesis.html (Bible text)
  │   ├── Exodus.html
  │   └── ...
  ├── New Testament (TOC)
  └── Dictionary/
      ├── Hebrew entries (H0001-H8674)
      ├── Greek entries (G0001-G5624)
      └── search-index.html (or simple alpha index)
```

### Task 2.4: Create sample preview/navigation hub
- [x] Add a quick test page such as `sample-index.html`
- [x] Link to the sample chapter, verse, note, and cross-reference pages
- [x] Use this page for rapid QA of anchor-aware chapter return behavior

---

## Phase 3: File Organization & Optimization

### Task 3.1: Organize HTML Output
- [ ] Create directory structure suitable for EPUB packaging
- [ ] Decide on file granularity (per book vs. per chapter)
- [ ] Plan cross-book linking strategy

**Recommended structure:**
```
kjv-strongs-html/
├── index.html
├── ot/ (Old Testament)
│   ├── 01-genesis.html
│   ├── 02-exodus.html
│   └── ...
├── nt/ (New Testament)
│   ├── 40-matthew.html
│   └── ...
├── dict/ (Strong's Dictionary)
│   ├── hebrew/
│   │   ├── h0001.html (H0001)
│   │   └── ...
│   └── greek/
│       ├── g0001.html (G0001)
│       └── ...
└── css/
    └── style.css
```

### Task 3.2: CSS Styling for Kindle Compatibility
- [ ] Create minimal CSS that works on Android 2.x WebKit
- [ ] Test font rendering (Hebrew/Greek Unicode)
- [ ] Optimize for small screen (Kindle Fire = 7")
- [ ] Ensure proper colors and contrast

**Key constraints:**
- No flexbox, grid, or modern CSS
- Use basic float or inline-block layouts
- Test on actual device if possible

---

## Phase 4: EPUB Packaging & Deployment

### Task 4.1: Prepare for Calibre Conversion
- [ ] Ensure HTML is valid and well-formed
- [ ] Create OPF manifest file (metadata)
- [ ] Test HTML rendering in Calibre preview

### Task 4.2: Convert HTML to EPUB using Calibre
- [ ] Run: `calibredb create -r "path/to/html"`
- [ ] Or use Calibre GUI to convert HTML folder to EPUB
- [ ] Verify EPUB structure and contents

### Task 4.3: Deploy to Kindle via ADB
- [ ] Connect Kindle Fire to Windows PC via USB
- [ ] Use ADB to push EPUB to `/sdcard/Books/` or FBReader app directory
- [ ] Test reading in FBReader
- [ ] Verify Strong's links work (navigate to dictionary entries)

---

## Recommended Tech Stack

### Option A: PowerShell (Familiar to you based on testosis.ps1)
**Pros:** Direct Windows integration, XML parsing support  
**Cons:** Slower for large datasets, verbose code  

**Key modules:**
- `System.Xml.XmlDocument` - OSIS parsing
- `System.Xml.XPath` - XPath queries

### Option B: Python (Recommended for performance)
**Pros:** Fast processing, clean XML libraries, better for large data  
**Cons:** Requires Python installation  

**Key libraries:**
- `lxml` - Fast XML parsing with namespace support
- `jinja2` - HTML template generation
- `json` - Efficient data storage

### Option C: Node.js (If you prefer web-based approach)
**Pros:** Can build interactive web preview  
**Cons:** Overkill for conversion pipeline  

---

## Implementation Decisions ✅

**1. File Granularity:** One file per chapter
   - Better performance on slow Kindle Fire device
   - Chapter navigation: links to next/previous chapter
   - Book/Chapter navigation at top of each file

**2. Dictionary Organization:** Separate files per entry
   - ~8000+ files (H0001-H8674, G0001-G5624)
   - Faster page loading and navigation
   - Efficient cross-reference linking

**3. Search & Navigation:** Both index types
   - Index by Strong's number (sorted H/G)
   - Concordance by English word (alphabetical)
   - Both point to dictionary entry pages

**4. Styling Preferences:**
   - **Dark mode** (white text on dark background)
   - **Simple formatting** (no rich elements needed)
   - **Flexible font sizing** (CSS font-size control or user-selectable sizes)

**5. Additional Features Requested:**
   - Auto-bookmarking (last page read)
   - Custom cross-references between verses
   - Personal notes on verses

---

## Next Steps

**Immediate action items:**
1. Review this plan and clarify any questions (see "Specific Questions" above)
2. Choose technology stack (PowerShell, Python, or Node.js)
3. Create data analysis scripts to validate input files
4. Build conversion pipeline incrementally (start with one Bible book)
5. Test on actual Kindle Fire device early

**I'm ready to help you:**
- Write conversion scripts in your preferred language
- Debug OSIS/XML parsing issues
- Optimize HTML/CSS for Kindle compatibility
- Create EPUB packaging scripts
- Troubleshoot ADB deployment

What would you like to tackle first?
