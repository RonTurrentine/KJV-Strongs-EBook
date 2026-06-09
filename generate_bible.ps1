# generate_bible.ps1
# Full KJV Bible generator with Strong's links and OSIS cross-references.
# Produces one HTML file per chapter under books/{NN}-{Abbr}/{ch}.html,
# static xref pages under xrefs/, js/bible-data.js, navigate.html, and index.html.
#
# Usage:
#   pwsh -NoProfile -File .\generate_bible.ps1
#   pwsh -NoProfile -File .\generate_bible.ps1 -BookFilter Ruth
#   pwsh -NoProfile -File .\generate_bible.ps1 -BookFilter Ruth -Verbose

param(
    [string]$OsisPath   = 'kjv.osis.xml',
    [string]$OutputRoot = '.',
    [string]$BookFilter = ''        # Set to an OSIS book ID (e.g. 'Ruth') to generate one book only
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Master Book Table ─────────────────────────────────────────────────────────
# Each entry: OsisId, Folder, FullName, Chapters, Testament
$BookTable = @(
    [pscustomobject]@{ Num=1;  OsisId='Gen';    Folder='01-Gen';    FullName='Genesis';          Chapters=50;  Testament='OT' }
    [pscustomobject]@{ Num=2;  OsisId='Exod';   Folder='02-Exod';   FullName='Exodus';           Chapters=40;  Testament='OT' }
    [pscustomobject]@{ Num=3;  OsisId='Lev';    Folder='03-Lev';    FullName='Leviticus';        Chapters=27;  Testament='OT' }
    [pscustomobject]@{ Num=4;  OsisId='Num';    Folder='04-Num';    FullName='Numbers';          Chapters=36;  Testament='OT' }
    [pscustomobject]@{ Num=5;  OsisId='Deut';   Folder='05-Deut';   FullName='Deuteronomy';      Chapters=34;  Testament='OT' }
    [pscustomobject]@{ Num=6;  OsisId='Josh';   Folder='06-Josh';   FullName='Joshua';           Chapters=24;  Testament='OT' }
    [pscustomobject]@{ Num=7;  OsisId='Judg';   Folder='07-Judg';   FullName='Judges';           Chapters=21;  Testament='OT' }
    [pscustomobject]@{ Num=8;  OsisId='Ruth';   Folder='08-Ruth';   FullName='Ruth';             Chapters=4;   Testament='OT' }
    [pscustomobject]@{ Num=9;  OsisId='1Sam';   Folder='09-1Sam';   FullName='1 Samuel';         Chapters=31;  Testament='OT' }
    [pscustomobject]@{ Num=10; OsisId='2Sam';   Folder='10-2Sam';   FullName='2 Samuel';         Chapters=24;  Testament='OT' }
    [pscustomobject]@{ Num=11; OsisId='1Kgs';   Folder='11-1Kgs';   FullName='1 Kings';          Chapters=22;  Testament='OT' }
    [pscustomobject]@{ Num=12; OsisId='2Kgs';   Folder='12-2Kgs';   FullName='2 Kings';          Chapters=25;  Testament='OT' }
    [pscustomobject]@{ Num=13; OsisId='1Chr';   Folder='13-1Chr';   FullName='1 Chronicles';     Chapters=29;  Testament='OT' }
    [pscustomobject]@{ Num=14; OsisId='2Chr';   Folder='14-2Chr';   FullName='2 Chronicles';     Chapters=36;  Testament='OT' }
    [pscustomobject]@{ Num=15; OsisId='Ezra';   Folder='15-Ezra';   FullName='Ezra';             Chapters=10;  Testament='OT' }
    [pscustomobject]@{ Num=16; OsisId='Neh';    Folder='16-Neh';    FullName='Nehemiah';         Chapters=13;  Testament='OT' }
    [pscustomobject]@{ Num=17; OsisId='Esth';   Folder='17-Esth';   FullName='Esther';           Chapters=10;  Testament='OT' }
    [pscustomobject]@{ Num=18; OsisId='Job';    Folder='18-Job';    FullName='Job';              Chapters=42;  Testament='OT' }
    [pscustomobject]@{ Num=19; OsisId='Ps';     Folder='19-Ps';     FullName='Psalms';           Chapters=150; Testament='OT' }
    [pscustomobject]@{ Num=20; OsisId='Prov';   Folder='20-Prov';   FullName='Proverbs';         Chapters=31;  Testament='OT' }
    [pscustomobject]@{ Num=21; OsisId='Eccl';   Folder='21-Eccl';   FullName='Ecclesiastes';     Chapters=12;  Testament='OT' }
    [pscustomobject]@{ Num=22; OsisId='Song';   Folder='22-Song';   FullName='Song of Solomon';  Chapters=8;   Testament='OT' }
    [pscustomobject]@{ Num=23; OsisId='Isa';    Folder='23-Isa';    FullName='Isaiah';           Chapters=66;  Testament='OT' }
    [pscustomobject]@{ Num=24; OsisId='Jer';    Folder='24-Jer';    FullName='Jeremiah';         Chapters=52;  Testament='OT' }
    [pscustomobject]@{ Num=25; OsisId='Lam';    Folder='25-Lam';    FullName='Lamentations';     Chapters=5;   Testament='OT' }
    [pscustomobject]@{ Num=26; OsisId='Ezek';   Folder='26-Ezek';   FullName='Ezekiel';          Chapters=48;  Testament='OT' }
    [pscustomobject]@{ Num=27; OsisId='Dan';    Folder='27-Dan';    FullName='Daniel';           Chapters=12;  Testament='OT' }
    [pscustomobject]@{ Num=28; OsisId='Hos';    Folder='28-Hos';    FullName='Hosea';            Chapters=14;  Testament='OT' }
    [pscustomobject]@{ Num=29; OsisId='Joel';   Folder='29-Joel';   FullName='Joel';             Chapters=3;   Testament='OT' }
    [pscustomobject]@{ Num=30; OsisId='Amos';   Folder='30-Amos';   FullName='Amos';             Chapters=9;   Testament='OT' }
    [pscustomobject]@{ Num=31; OsisId='Obad';   Folder='31-Obad';   FullName='Obadiah';          Chapters=1;   Testament='OT' }
    [pscustomobject]@{ Num=32; OsisId='Jonah';  Folder='32-Jonah';  FullName='Jonah';            Chapters=4;   Testament='OT' }
    [pscustomobject]@{ Num=33; OsisId='Mic';    Folder='33-Mic';    FullName='Micah';            Chapters=7;   Testament='OT' }
    [pscustomobject]@{ Num=34; OsisId='Nah';    Folder='34-Nah';    FullName='Nahum';            Chapters=3;   Testament='OT' }
    [pscustomobject]@{ Num=35; OsisId='Hab';    Folder='35-Hab';    FullName='Habakkuk';         Chapters=3;   Testament='OT' }
    [pscustomobject]@{ Num=36; OsisId='Zeph';   Folder='36-Zeph';   FullName='Zephaniah';        Chapters=3;   Testament='OT' }
    [pscustomobject]@{ Num=37; OsisId='Hag';    Folder='37-Hag';    FullName='Haggai';           Chapters=2;   Testament='OT' }
    [pscustomobject]@{ Num=38; OsisId='Zech';   Folder='38-Zech';   FullName='Zechariah';        Chapters=14;  Testament='OT' }
    [pscustomobject]@{ Num=39; OsisId='Mal';    Folder='39-Mal';    FullName='Malachi';          Chapters=4;   Testament='OT' }
    [pscustomobject]@{ Num=40; OsisId='Matt';   Folder='40-Matt';   FullName='Matthew';          Chapters=28;  Testament='NT' }
    [pscustomobject]@{ Num=41; OsisId='Mark';   Folder='41-Mark';   FullName='Mark';             Chapters=16;  Testament='NT' }
    [pscustomobject]@{ Num=42; OsisId='Luke';   Folder='42-Luke';   FullName='Luke';             Chapters=24;  Testament='NT' }
    [pscustomobject]@{ Num=43; OsisId='John';   Folder='43-John';   FullName='John';             Chapters=21;  Testament='NT' }
    [pscustomobject]@{ Num=44; OsisId='Acts';   Folder='44-Acts';   FullName='Acts';             Chapters=28;  Testament='NT' }
    [pscustomobject]@{ Num=45; OsisId='Rom';    Folder='45-Rom';    FullName='Romans';           Chapters=16;  Testament='NT' }
    [pscustomobject]@{ Num=46; OsisId='1Cor';   Folder='46-1Cor';   FullName='1 Corinthians';    Chapters=16;  Testament='NT' }
    [pscustomobject]@{ Num=47; OsisId='2Cor';   Folder='47-2Cor';   FullName='2 Corinthians';    Chapters=13;  Testament='NT' }
    [pscustomobject]@{ Num=48; OsisId='Gal';    Folder='48-Gal';    FullName='Galatians';        Chapters=6;   Testament='NT' }
    [pscustomobject]@{ Num=49; OsisId='Eph';    Folder='49-Eph';    FullName='Ephesians';        Chapters=6;   Testament='NT' }
    [pscustomobject]@{ Num=50; OsisId='Phil';   Folder='50-Phil';   FullName='Philippians';      Chapters=4;   Testament='NT' }
    [pscustomobject]@{ Num=51; OsisId='Col';    Folder='51-Col';    FullName='Colossians';       Chapters=4;   Testament='NT' }
    [pscustomobject]@{ Num=52; OsisId='1Thess'; Folder='52-1Thess'; FullName='1 Thessalonians';  Chapters=5;   Testament='NT' }
    [pscustomobject]@{ Num=53; OsisId='2Thess'; Folder='53-2Thess'; FullName='2 Thessalonians';  Chapters=3;   Testament='NT' }
    [pscustomobject]@{ Num=54; OsisId='1Tim';   Folder='54-1Tim';   FullName='1 Timothy';        Chapters=6;   Testament='NT' }
    [pscustomobject]@{ Num=55; OsisId='2Tim';   Folder='55-2Tim';   FullName='2 Timothy';        Chapters=4;   Testament='NT' }
    [pscustomobject]@{ Num=56; OsisId='Titus';  Folder='56-Titus';  FullName='Titus';            Chapters=3;   Testament='NT' }
    [pscustomobject]@{ Num=57; OsisId='Phlm';   Folder='57-Phlm';   FullName='Philemon';         Chapters=1;   Testament='NT' }
    [pscustomobject]@{ Num=58; OsisId='Heb';    Folder='58-Heb';    FullName='Hebrews';          Chapters=13;  Testament='NT' }
    [pscustomobject]@{ Num=59; OsisId='Jas';    Folder='59-Jas';    FullName='James';            Chapters=5;   Testament='NT' }
    [pscustomobject]@{ Num=60; OsisId='1Pet';   Folder='60-1Pet';   FullName='1 Peter';          Chapters=5;   Testament='NT' }
    [pscustomobject]@{ Num=61; OsisId='2Pet';   Folder='61-2Pet';   FullName='2 Peter';          Chapters=3;   Testament='NT' }
    [pscustomobject]@{ Num=62; OsisId='1John';  Folder='62-1John';  FullName='1 John';           Chapters=5;   Testament='NT' }
    [pscustomobject]@{ Num=63; OsisId='2John';  Folder='63-2John';  FullName='2 John';           Chapters=1;   Testament='NT' }
    [pscustomobject]@{ Num=64; OsisId='3John';  Folder='64-3John';  FullName='3 John';           Chapters=1;   Testament='NT' }
    [pscustomobject]@{ Num=65; OsisId='Jude';   Folder='65-Jude';   FullName='Jude';             Chapters=1;   Testament='NT' }
    [pscustomobject]@{ Num=66; OsisId='Rev';    Folder='66-Rev';    FullName='Revelation';       Chapters=22;  Testament='NT' }
)

# Build a lookup hashtable: OsisId -> book entry (used for xref link generation)
$BookLookup = @{}
foreach ($b in $BookTable) { $BookLookup[$b.OsisId] = $b }

# ── Helper: HTML escape ───────────────────────────────────────────────────────
function HtmlEscape([string]$t) {
    return $t -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

# ── Helper: normalize verse text (collapse whitespace, fix punctuation gaps) ──
function NormalizeVerseText([string]$text) {
    $text = $text -replace '\s+', ' '
    $text = $text -replace '\s+([,.;:!?])', '$1'
    return $text.Trim()
}

# ── Helper: build Strong's link HTML (relative from books/{folder}/{ch}.html) ─
function Get-StrongLinkHtml([string]$lemmaAttr) {
    $links = @()
    foreach ($lemma in ($lemmaAttr -split '\s+')) {
        if ($lemma -match '^strong:H(\d+)') {
            $num = ([int]$matches[1]).ToString().PadLeft(4,'0')
            $links += '<a href="../../dict/hebrew/h' + $num + '.html" class="strongs-link" title="Strong''s Hebrew H' + $num + '">[H' + $num + ']</a>'
        } elseif ($lemma -match '^strong:G(\d+)') {
            $num = ([int]$matches[1]).ToString().PadLeft(4,'0')
            $links += '<a href="../../dict/greek/g' + $num + '.html" class="strongs-link" title="Strong''s Greek G' + $num + '">[G' + $num + ']</a>'
        }
    }
    return $links -join ' '
}

# ── Helper: parse osisRef "Book.Ch.Vs" or "Book.Ch.Vs-Book.Ch.Vs" ────────────
# Returns hashtable with Book, Chapter, Verse (start of range only)
function Parse-OsisRef([string]$osisRef) {
    # Handle ranges — take only the start reference
    $start = ($osisRef -split '-')[0].Trim()
    $parts = $start -split '\.'
    if ($parts.Count -lt 2) { return $null }
    return @{
        Book    = $parts[0]
        Chapter = if ($parts.Count -ge 2) { $parts[1] } else { '1' }
        Verse   = if ($parts.Count -ge 3) { $parts[2] } else { '1' }
    }
}

# ── Helper: build chapter-relative URL from an osisRef ───────────────────────
# fromFolder is the current book folder (e.g. '01-Gen') for same-book detection
function Get-ChapterUrl([string]$osisRef, [string]$fromFolder) {
    $ref = Parse-OsisRef $osisRef
    if (-not $ref) { return $null }
    $targetBook = $BookLookup[$ref.Book]
    if (-not $targetBook) { return $null }
    $chNum  = [int]$ref.Chapter
    $vsNum  = [int]$ref.Verse
    # Path from xrefs/ to books/ is ../books/
    return "../books/$($targetBook.Folder)/$chNum.html#verse-$vsNum"
}

# ── Helper: build display label for a reference ───────────────────────────────
function Get-RefLabel([string]$osisRef, [string]$displayText) {
    if ($displayText -and $displayText.Trim()) { return $displayText.Trim() }
    $ref = Parse-OsisRef $osisRef
    if (-not $ref) { return $osisRef }
    $book = $BookLookup[$ref.Book]
    $bookName = if ($book) { $book.FullName } else { $ref.Book }
    return "$bookName $($ref.Chapter):$($ref.Verse)"
}

# ── Phase 1: Load OSIS XML ────────────────────────────────────────────────────
Write-Host "Loading OSIS XML from $OsisPath..." -ForegroundColor Cyan
$osis = [xml](Get-Content -Raw -Path $OsisPath)
$ns   = New-Object System.Xml.XmlNamespaceManager($osis.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')
Write-Host "OSIS XML loaded." -ForegroundColor Green

# ── Phase 2: Build flat chapter list ─────────────────────────────────────────
Write-Host "Building flat chapter list..." -ForegroundColor Cyan
$FlatChapters = [System.Collections.ArrayList]@()

$booksToProcess = $BookTable
if ($BookFilter) {
    $booksToProcess = $BookTable | Where-Object { $_.OsisId -eq $BookFilter }
    if (-not $booksToProcess) { throw "BookFilter '$BookFilter' not found in book table." }
    Write-Host "BookFilter active — processing $BookFilter only." -ForegroundColor Yellow
}

foreach ($book in $booksToProcess) {
    for ($ch = 1; $ch -le $book.Chapters; $ch++) {
        [void]$FlatChapters.Add([pscustomobject]@{
            Book      = $book
            Chapter   = $ch
            OsisChId  = "$($book.OsisId).$ch"
            FolderPath = "books/$($book.Folder)"
        })
    }
}

Write-Host "Flat chapter list built: $($FlatChapters.Count) chapters." -ForegroundColor Green

# ── Collected data for bible-data.js ─────────────────────────────────────────
# $VerseCountData: hashtable OsisId -> array of verse counts (index 0 = ch1)
$VerseCountData = @{}
foreach ($book in $booksToProcess) {
    $VerseCountData[$book.OsisId] = @(0) * $book.Chapters
}

# ── Ensure output directories exist ──────────────────────────────────────────
function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

Ensure-Dir (Join-Path $OutputRoot 'books')
Ensure-Dir (Join-Path $OutputRoot 'xrefs')
Ensure-Dir (Join-Path $OutputRoot 'js')
Ensure-Dir (Join-Path $OutputRoot 'indexes')

# ── Phase 3: Generate chapter HTML files + xref pages ────────────────────────
Write-Host "Generating chapter pages..." -ForegroundColor Cyan

$totalChapters = $FlatChapters.Count
$doneChapters  = 0

foreach ($entry in $FlatChapters) {
    $book    = $entry.Book
    $chNum   = $entry.Chapter
    $osisChId = $entry.OsisChId    # e.g. "Gen.1"
    $folder  = $entry.FolderPath   # e.g. "books/01-Gen"

    # ── Find chapter node in OSIS ─────────────────────────────────────────────
    $chapterNode = $osis.SelectSingleNode("//o:chapter[@osisID='$osisChId']", $ns)
    if (-not $chapterNode) {
        Write-Warning "Chapter node not found: $osisChId — skipping."
        continue
    }

    # ── Parse verses + collect xrefs ─────────────────────────────────────────
    $verses      = [System.Collections.Specialized.OrderedDictionary]@{}
    $verseXrefs  = @{}   # verseNum -> array of {OsisRef, DisplayText}
    $currentVerse = $null
    $currentText  = ''

    foreach ($node in $chapterNode.ChildNodes) {

        # Verse milestone start/end
        if ($node.LocalName -eq 'verse') {
            if ($node.Attributes['osisID']) {
                $currentVerse = [regex]::Match($node.Attributes['osisID'].Value, '\d+$').Value
                $currentText  = ''
            } elseif ($node.Attributes['eID']) {
                if ($currentVerse) {
                    $verses[$currentVerse] = NormalizeVerseText $currentText
                    $currentVerse = $null
                }
            }
            continue
        }

        if (-not $currentVerse) { continue }

        # Word node with optional Strong's lemma
        if ($node.LocalName -eq 'w') {
            $currentText += $node.InnerText
            if ($node.Attributes['lemma']) {
                $links = Get-StrongLinkHtml $node.Attributes['lemma'].Value
                if ($links) { $currentText += ' ' + $links }
            }
            $currentText += ' '
            continue
        }

        # Italic / supplied words (transChange) and divine name spans
        if ($node.LocalName -eq 'transChange' -or $node.LocalName -eq 'divineName') {
            $currentText += $node.InnerText + ' '
            continue
        }

        # OSIS cross-reference note
        if ($node.LocalName -eq 'note' -and $node.Attributes['type'] -and
            $node.Attributes['type'].Value -eq 'crossReference') {
            $refs = @()
            foreach ($refNode in $node.SelectNodes('o:reference', $ns)) {
                $refOsisRef = $refNode.GetAttribute('osisRef')
                $refText    = $refNode.InnerText.Trim()
                if ($refOsisRef) {
                    $refs += [pscustomobject]@{ OsisRef = $refOsisRef; DisplayText = $refText }
                }
            }
            if ($refs.Count -gt 0) {
                $verseXrefs[$currentVerse] = $refs
            }
            continue
        }

        # Plain text nodes
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Text -or
            $node.NodeType -eq [System.Xml.XmlNodeType]::CDATA) {
            $currentText += $node.Value
        }
    }

    # Flush last verse if milestone eID was missing
    if ($currentVerse -and -not $verses.Contains($currentVerse)) {
        $verses[$currentVerse] = NormalizeVerseText $currentText
    }

    if ($verses.Count -eq 0) {
        Write-Warning "No verses found in $osisChId — skipping."
        continue
    }

    # Record verse count for bible-data.js
    $VerseCountData[$book.OsisId][$chNum - 1] = $verses.Count

    # ── Build verse HTML blocks ───────────────────────────────────────────────
    $verseBlocks = ''
    foreach ($vNum in $verses.Keys) {
        $vText     = $verses[$vNum]
        $xrefHtml  = ''
        if ($verseXrefs.ContainsKey($vNum)) {
            $xrefFile = "$($book.OsisId).$chNum.$vNum.html"
            $xrefHtml = "  <a href=`"../../xrefs/$xrefFile`" class=`"superscript-link`" title=`"Cross-references for $($book.FullName) $chNum`:$vNum`">&#x271D;</a>"
        }
        $verseBlocks += @"
    <p class="verse" id="verse-$vNum">
      <span class="verse-num">$vNum</span>
      $vText$xrefHtml
    </p>
"@
    }

    # ── Compute prev/next navigation ──────────────────────────────────────────
    $flatIdx  = $FlatChapters.IndexOf($entry)
    $prevHtml = ''
    $nextHtml = ''

    if ($flatIdx -gt 0) {
        $prev = $FlatChapters[$flatIdx - 1]
        if ($prev.Book.OsisId -eq $book.OsisId) {
            $prevHref = "$($prev.Chapter).html"
        } else {
            $prevHref = "../$($prev.Book.Folder)/$($prev.Chapter).html"
        }
        $prevLabel = "$($prev.Book.FullName) $($prev.Chapter)"
        $prevHtml  = "<a href=`"$prevHref`" class=`"btn`" title=`"$prevLabel`">&#9664; Prev</a>"
    }

    if ($flatIdx -lt ($FlatChapters.Count - 1)) {
        $next = $FlatChapters[$flatIdx + 1]
        if ($next.Book.OsisId -eq $book.OsisId) {
            $nextHref = "$($next.Chapter).html"
        } else {
            $nextHref = "../$($next.Book.Folder)/$($next.Chapter).html"
        }
        $nextLabel = "$($next.Book.FullName) $($next.Chapter)"
        $nextHtml  = "<a href=`"$nextHref`" class=`"btn`" title=`"$nextLabel`">Next &#9654;</a>"
    }

    # ── Write chapter HTML ────────────────────────────────────────────────────
    $bookFolder = Join-Path $OutputRoot "books/$($book.Folder)"
    Ensure-Dir $bookFolder

    $chapterHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$($book.FullName) $chNum -- KJV</title>
  <link rel="stylesheet" href="../../css/style.css">
</head>
<body class="bible-text">

  <nav class="chapter-nav">
    <h1 class="book-chapter">$($book.FullName) $chNum</h1>
    <div class="nav-buttons">
      <a href="../../index.html" class="btn">Books</a>
      <a href="../../navigate.html" class="btn">Go To</a>
      $prevHtml
      $nextHtml
      <button class="btn" id="font-toggle" onclick="cycleFontSize()">Aa</button>
      <span id="unbaked-indicator"></span>
    </div>
  </nav>

  <main class="chapter-content">
$verseBlocks
  </main>

  <footer class="chapter-footer">
    <div class="nav-buttons">
      $prevHtml
      <a href="../../index.html" class="btn">Books</a>
      $nextHtml
    </div>
  </footer>

  <!-- Phase 1: Core functionality (works on Kindle + PC) -->
  <script src="../../js/fontsize.js"></script>
  <script src="../../js/bookmarks.js"></script>
  <!-- Phase 2: PC-only enhancements (stripped during EPUB packaging) -->
  <script src="../../js/notes.js"></script>

</body>
</html>
"@

    $chapterFile = Join-Path $bookFolder "$chNum.html"
    $chapterHtml | Set-Content -Path $chapterFile -Encoding UTF8

    # ── Write xref pages ──────────────────────────────────────────────────────
    foreach ($vNum in $verseXrefs.Keys) {
        $refs     = $verseXrefs[$vNum]
        $xrefFile = "$($book.OsisId).$chNum.$vNum.html"
        $xrefPath = Join-Path $OutputRoot "xrefs/$xrefFile"

        $refItems = ''
        foreach ($ref in $refs) {
            $url   = Get-ChapterUrl $ref.OsisRef $book.Folder
            $label = Get-RefLabel  $ref.OsisRef  $ref.DisplayText
            if ($url) {
                $refItems += "    <li><a href=`"$url`" class=`"xref-link`">$(HtmlEscape $label)</a></li>`n"
            }
        }

        $backUrl  = "../books/$($book.Folder)/$chNum.html#verse-$vNum"
        $pageTitle = "$($book.FullName) $chNum`:$vNum"

        $xrefHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Cross-References: $pageTitle -- KJV</title>
  <link rel="stylesheet" href="../css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1>Cross-References: $pageTitle</h1>
    <div class="nav-buttons">
      <a href="$backUrl" class="btn">&#9664; Back to Verse</a>
      <a href="../index.html" class="btn">Books</a>
    </div>
  </nav>
  <main class="chapter-content">
    <ul class="xref-list">
$refItems
    </ul>
  </main>
  <footer class="chapter-footer">
    <div class="nav-buttons">
      <a href="$backUrl" class="btn">&#9664; Back to $($book.FullName) $chNum</a>
    </div>
  </footer>
</body>
</html>
"@
        $xrefHtml | Set-Content -Path $xrefPath -Encoding UTF8
    }

    $doneChapters++
    if ($doneChapters % 50 -eq 0 -or $doneChapters -eq $totalChapters) {
        Write-Host "  $doneChapters / $totalChapters chapters done..." -ForegroundColor Gray
    }
}

Write-Host "Chapter generation complete." -ForegroundColor Green

# ── Phase 4: Generate js/bible-data.js ───────────────────────────────────────
Write-Host "Generating js/bible-data.js..." -ForegroundColor Cyan

$jsEntries = ''
foreach ($book in $booksToProcess) {
    $counts     = $VerseCountData[$book.OsisId]
    $countsStr  = $counts -join ', '
    $jsEntries += @"
  {
    num: $($book.Num),
    abbr: "$($book.OsisId)",
    name: "$(HtmlEscape $book.FullName)",
    folder: "$($book.Folder)",
    chapters: [$countsStr]
  },
"@
}

$bibleDataJs = @"
// bible-data.js -- generated by generate_bible.ps1
// ES3-compatible: var declaration, plain object literals, no const/let
var BIBLE_DATA = [
$jsEntries];
"@

$bibleDataJs | Set-Content -Path (Join-Path $OutputRoot 'js/bible-data.js') -Encoding UTF8
Write-Host "js/bible-data.js written." -ForegroundColor Green

# ── Phase 5: Generate index.html ─────────────────────────────────────────────
Write-Host "Generating index.html..." -ForegroundColor Cyan

$otLinks = ''
$ntLinks = ''
foreach ($book in $BookTable) {
    $link = "  <li><a href=`"books/$($book.Folder)/1.html`">$($book.FullName)</a> <span class=`"chapter-count`">($($book.Chapters) ch)</span></li>`n"
    if ($book.Testament -eq 'OT') { $otLinks += $link }
    else                           { $ntLinks += $link }
}

$indexHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>KJV Bible with Strong's Concordance</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1>KJV Bible</h1>
    <div class="nav-buttons">
      <a href="navigate.html" class="btn">Go To Passage</a>
    </div>
  </nav>
  <main class="chapter-content">
    <div id="bookmark-resume"></div>
    <h2 class="testament-heading">Old Testament</h2>
    <ul class="book-list">
$otLinks    </ul>
    <h2 class="testament-heading">New Testament</h2>
    <ul class="book-list">
$ntLinks    </ul>
  </main>
  <script src="js/bookmarks.js"></script>
</body>
</html>
"@

$indexHtml | Set-Content -Path (Join-Path $OutputRoot 'index.html') -Encoding UTF8
Write-Host "index.html written." -ForegroundColor Green

# ── Phase 6: Generate navigate.html ──────────────────────────────────────────
Write-Host "Generating navigate.html..." -ForegroundColor Cyan

$navigateHtml = @'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Go To Passage -- KJV</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1>Go To Passage</h1>
    <div class="nav-buttons">
      <a href="index.html" class="btn">Books</a>
    </div>
  </nav>
  <main class="chapter-content">
    <div class="navigator-form">

      <label for="book-select">Book:</label>
      <select id="book-select" onchange="onBookChange()" style="width:100%;padding:10px;font-size:18px;margin-bottom:12px;">
        <option value="">-- Select a Book --</option>
      </select>

      <label for="chapter-select">Chapter:</label>
      <select id="chapter-select" onchange="onChapterChange()" disabled="disabled"
              style="width:100%;padding:10px;font-size:18px;margin-bottom:12px;">
        <option value="">-- Select a Chapter --</option>
      </select>

      <label for="verse-select">Verse:</label>
      <select id="verse-select" disabled="disabled"
              style="width:100%;padding:10px;font-size:18px;margin-bottom:16px;">
        <option value="any">-- any (top of chapter) --</option>
      </select>

      <button onclick="onGo()" style="width:100%;padding:12px;font-size:20px;">Go</button>

    </div>
  </main>

  <script src="js/bible-data.js"></script>
  <script>
  // ES3-compatible navigator logic
  var selectedBookIdx = -1;

  function populateBooks() {
    var sel = document.getElementById('book-select');
    var i, book, opt;
    for (i = 0; i < BIBLE_DATA.length; i++) {
      book = BIBLE_DATA[i];
      opt  = document.createElement('option');
      opt.value = i;
      opt.text  = book.name;
      sel.appendChild(opt);
    }
  }

  function onBookChange() {
    var bookSel = document.getElementById('book-select');
    var chSel   = document.getElementById('chapter-select');
    var vsSel   = document.getElementById('verse-select');
    var idx     = parseInt(bookSel.value, 10);

    // Reset chapter and verse
    chSel.options.length = 1;  // keep the placeholder
    vsSel.options.length = 1;  // keep the placeholder
    chSel.disabled = true;
    vsSel.disabled = true;

    if (isNaN(idx)) { selectedBookIdx = -1; return; }
    selectedBookIdx = idx;

    var book = BIBLE_DATA[idx];
    var i, opt;
    for (i = 0; i < book.chapters.length; i++) {
      opt       = document.createElement('option');
      opt.value = i + 1;
      opt.text  = 'Chapter ' + (i + 1);
      chSel.appendChild(opt);
    }
    chSel.disabled = false;
  }

  function onChapterChange() {
    var chSel  = document.getElementById('chapter-select');
    var vsSel  = document.getElementById('verse-select');
    var chNum  = parseInt(chSel.value, 10);

    vsSel.options.length = 1;  // keep the "any" placeholder
    vsSel.disabled = true;

    if (isNaN(chNum) || selectedBookIdx < 0) { return; }

    var book       = BIBLE_DATA[selectedBookIdx];
    var verseCount = book.chapters[chNum - 1];
    var i, opt;
    for (i = 1; i <= verseCount; i++) {
      opt       = document.createElement('option');
      opt.value = i;
      opt.text  = 'Verse ' + i;
      vsSel.appendChild(opt);
    }
    vsSel.disabled = false;
  }

  function onGo() {
    var bookSel = document.getElementById('book-select');
    var chSel   = document.getElementById('chapter-select');
    var vsSel   = document.getElementById('verse-select');

    var idx   = parseInt(bookSel.value, 10);
    var chNum = parseInt(chSel.value, 10);

    if (isNaN(idx) || isNaN(chNum)) {
      alert('Please select a book and chapter.');
      return;
    }

    var book   = BIBLE_DATA[idx];
    var url    = 'books/' + book.folder + '/' + chNum + '.html';
    var vsVal  = vsSel.value;
    if (vsVal && vsVal !== 'any') {
      url += '#verse-' + vsVal;
    }
    window.location.href = url;
  }

  // Initialise on load
  populateBooks();
  </script>

</body>
</html>
'@

$navigateHtml | Set-Content -Path (Join-Path $OutputRoot 'navigate.html') -Encoding UTF8
Write-Host "navigate.html written." -ForegroundColor Green

# ── Phase 7: Generate js/fontsize.js ─────────────────────────────────────────
Write-Host "Generating js/fontsize.js..." -ForegroundColor Cyan

$fontsizeJs = @'
// fontsize.js -- ES3-compatible font size toggle
// Cycles body class through font-normal -> font-large -> font-xlarge -> font-small
(function () {
  var SIZES = ['font-normal', 'font-large', 'font-xlarge', 'font-small'];
  var KEY   = 'kjv-fontsize';

  function applySize(size) {
    var i;
    for (i = 0; i < SIZES.length; i++) {
      if (document.body.className.indexOf(SIZES[i]) !== -1) {
        document.body.className = document.body.className.replace(SIZES[i], '');
      }
    }
    document.body.className = (document.body.className + ' ' + size).replace(/\s+/g, ' ').replace(/^\s|\s$/, '');
  }

  // Apply saved preference immediately on load (before render)
  var saved = '';
  try { saved = localStorage.getItem(KEY) || ''; } catch(e) {}
  if (saved) { applySize(saved); }

  // Expose toggle function for the Aa button
  window.cycleFontSize = function () {
    var current = '';
    var i;
    for (i = 0; i < SIZES.length; i++) {
      if (document.body.className.indexOf(SIZES[i]) !== -1) {
        current = SIZES[i];
        break;
      }
    }
    var nextIdx  = (SIZES.indexOf(current) + 1) % SIZES.length;
    var nextSize = SIZES[nextIdx];
    applySize(nextSize);
    try { localStorage.setItem(KEY, nextSize); } catch(e) {}
  };
}());
'@

$fontsizeJs | Set-Content -Path (Join-Path $OutputRoot 'js/fontsize.js') -Encoding UTF8
Write-Host "js/fontsize.js written." -ForegroundColor Green

# ── Phase 8: Generate js/bookmarks.js ────────────────────────────────────────
Write-Host "Generating js/bookmarks.js..." -ForegroundColor Cyan

$bookmarksJs = @'
// bookmarks.js -- ES3-compatible reading position bookmark
// Auto-saves position on chapter pages; shows resume link on index.html
(function () {
  var KEY = 'kjv-bookmark';

  // Save position when leaving a chapter page
  if (document.body.className.indexOf('bible-text') !== -1) {
    var h1 = document.getElementsByTagName('h1')[0];
    var pageTitle = h1 ? h1.innerText || h1.textContent : document.title;

    window.onbeforeunload = function () {
      var bookmark = {
        url:   window.location.href,
        scroll: window.pageYOffset || document.documentElement.scrollTop || 0,
        title:  pageTitle,
        saved:  new Date().toISOString()
      };
      try { localStorage.setItem(KEY, JSON.stringify(bookmark)); } catch(e) {}
    };
  }

  // Show resume link on index.html
  var resumeDiv = document.getElementById('bookmark-resume');
  if (resumeDiv) {
    var saved = '';
    try { saved = localStorage.getItem(KEY) || ''; } catch(e) {}
    if (saved) {
      var bm = null;
      try { bm = JSON.parse(saved); } catch(e) {}
      if (bm && bm.url && bm.title) {
        resumeDiv.innerHTML = '<p class="bookmark-resume"><a href="' + bm.url +
          '" class="btn">Resume: ' + bm.title + '</a></p>';
      }
    }
  }
}());
'@

$bookmarksJs | Set-Content -Path (Join-Path $OutputRoot 'js/bookmarks.js') -Encoding UTF8
Write-Host "js/bookmarks.js written." -ForegroundColor Green

# ── Done ──────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " generate_bible.ps1 complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Chapters generated : $doneChapters" -ForegroundColor Green
Write-Host " Output root        : $OutputRoot" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open index.html in your browser and verify layout"
Write-Host "  2. Test Strong's links and xref superscripts"
Write-Host "  3. Test navigate.html cascading dropdowns"
Write-Host "  4. Verify Genesis 50 -> Exodus 1 cross-book navigation"
Write-Host "  5. Run full 66-book generation (remove -BookFilter)"
