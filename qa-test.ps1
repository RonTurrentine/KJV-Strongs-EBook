# qa-test.ps1
# Quality Assurance test suite for the KJV Strong's EBook project.
# Run after generate_bible.ps1 and generate_dict.ps1 to validate output.
#
# Usage:
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\qa-test.ps1
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\qa-test.ps1 -OutputRoot '.' -Verbose
#   pwsh -NoProfile -ExecutionPolicy Bypass -File .\qa-test.ps1 -BookFilter Ruth

param(
    [string]$OutputRoot  = '.',
    [string]$BookFilter  = ''     # Limit chapter tests to one book (e.g. 'Ruth')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'   # Don't stop on individual test failures

# ── Counters ──────────────────────────────────────────────────────────────────
$PassCount = 0
$FailCount = 0
$WarnCount = 0
$Errors    = [System.Collections.ArrayList]@()
$Warnings  = [System.Collections.ArrayList]@()

function Pass([string]$msg) {
    $script:PassCount++
    Write-Host "  [PASS] $msg" -ForegroundColor Green
}

function Fail([string]$msg) {
    $script:FailCount++
    [void]$script:Errors.Add($msg)
    Write-Host "  [FAIL] $msg" -ForegroundColor Red
}

function Warn([string]$msg) {
    $script:WarnCount++
    [void]$script:Warnings.Add($msg)
    Write-Host "  [WARN] $msg" -ForegroundColor Yellow
}

function Section([string]$title) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host " $title" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

function Test-FileExists([string]$path, [string]$label) {
    if (Test-Path $path) {
        Pass "$label exists"
        return $true
    } else {
        Fail "$label MISSING: $path"
        return $false
    }
}

# ── Master Book Table (must match generate_bible.ps1) ────────────────────────
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

# Known verse counts for spot-check validation
$VerseSpotChecks = @(
    [pscustomobject]@{ Book='Gen';  Ch=1;   ExpectedVerses=31;  Label='Genesis 1' }
    [pscustomobject]@{ Book='Gen';  Ch=50;  ExpectedVerses=26;  Label='Genesis 50' }
    [pscustomobject]@{ Book='Ruth'; Ch=1;   ExpectedVerses=22;  Label='Ruth 1' }
    [pscustomobject]@{ Book='Ruth'; Ch=4;   ExpectedVerses=22;  Label='Ruth 4' }
    [pscustomobject]@{ Book='Ps';   Ch=119; ExpectedVerses=176; Label='Psalm 119 (longest chapter)' }
    [pscustomobject]@{ Book='Ps';   Ch=117; ExpectedVerses=2;   Label='Psalm 117 (shortest chapter)' }
    [pscustomobject]@{ Book='John'; Ch=3;   ExpectedVerses=36;  Label='John 3' }
    [pscustomobject]@{ Book='John'; Ch=11;  ExpectedVerses=57;  Label='John 11' }
    [pscustomobject]@{ Book='Rev';  Ch=22;  ExpectedVerses=21;  Label='Revelation 22 (last chapter)' }
    [pscustomobject]@{ Book='Obad'; Ch=1;   ExpectedVerses=21;  Label='Obadiah 1 (single chapter book)' }
    [pscustomobject]@{ Book='Phlm'; Ch=1;   ExpectedVerses=25;  Label='Philemon 1 (single chapter book)' }
)

$booksToTest = $BookTable
if ($BookFilter) {
    $booksToTest = $BookTable | Where-Object { $_.OsisId -eq $BookFilter }
    if (-not $booksToTest) { throw "BookFilter '$BookFilter' not found." }
    Write-Host "BookFilter active: testing $BookFilter only." -ForegroundColor Yellow
}

# ── TEST 1: Core files exist ──────────────────────────────────────────────────
Section "TEST 1: Core Files"

Test-FileExists (Join-Path $OutputRoot 'index.html')       'index.html' | Out-Null
Test-FileExists (Join-Path $OutputRoot 'navigate.html')    'navigate.html' | Out-Null
Test-FileExists (Join-Path $OutputRoot 'css/style.css')    'css/style.css' | Out-Null
Test-FileExists (Join-Path $OutputRoot 'js/bible-data.js') 'js/bible-data.js' | Out-Null
Test-FileExists (Join-Path $OutputRoot 'js/fontsize.js')   'js/fontsize.js' | Out-Null
Test-FileExists (Join-Path $OutputRoot 'js/bookmarks.js')  'js/bookmarks.js' | Out-Null

# ── TEST 2: Chapter file counts ───────────────────────────────────────────────
Section "TEST 2: Chapter File Counts"

$totalExpected  = 0
$totalFound     = 0
$missingFolders = 0

foreach ($book in $booksToTest) {
    $bookDir = Join-Path $OutputRoot "books/$($book.Folder)"
    if (-not (Test-Path $bookDir)) {
        Fail "Book folder missing: books/$($book.Folder)"
        $missingFolders++
        continue
    }
    $found = @(Get-ChildItem $bookDir -Filter '*.html').Count
    $expected = $book.Chapters
    $totalExpected += $expected
    $totalFound    += $found
    if ($found -eq $expected) {
        Pass "$($book.FullName): $found/$expected chapters"
    } else {
        Fail "$($book.FullName): found $found chapters, expected $expected"
    }
}

if ($missingFolders -eq 0) {
    Pass "All book folders present"
}

# ── TEST 3: Dictionary file counts ───────────────────────────────────────────
Section "TEST 3: Dictionary File Counts"

$hebDir  = Join-Path $OutputRoot 'dict/hebrew'
$grkDir  = Join-Path $OutputRoot 'dict/greek'
$hebCount = 0
$grkCount = 0

if (Test-Path $hebDir) {
    $hebCount = (Get-ChildItem $hebDir -Filter 'h*.html').Count
    if ($hebCount -ge 8000) {
        Pass "Hebrew dictionary: $hebCount files (expected ~8674)"
    } else {
        Fail "Hebrew dictionary: only $hebCount files found (expected ~8674)"
    }
} else {
    Fail "Hebrew dictionary folder missing: dict/hebrew"
}

if (Test-Path $grkDir) {
    $grkCount = (Get-ChildItem $grkDir -Filter 'g*.html').Count
    if ($grkCount -ge 5000) {
        Pass "Greek dictionary: $grkCount files (expected ~5624)"
    } else {
        Fail "Greek dictionary: only $grkCount files found (expected ~5624)"
    }
} else {
    Fail "Greek dictionary folder missing: dict/greek"
}

# ── TEST 4: Verse spot checks ─────────────────────────────────────────────────
Section "TEST 4: Verse Count Spot Checks"

foreach ($check in $VerseSpotChecks) {
    $book = $BookTable | Where-Object { $_.OsisId -eq $check.Book }
    if (-not $book) { continue }
    if ($BookFilter -and $book.OsisId -ne $BookFilter) { continue }

    $chFile = Join-Path $OutputRoot "books/$($book.Folder)/$($check.Ch).html"
    if (-not (Test-Path $chFile)) {
        Warn "$($check.Label): file not found (may not be generated yet)"
        continue
    }
    $content     = Get-Content -Raw $chFile
    $verseCount  = ([regex]::Matches($content, 'id="verse-\d+"')).Count
    if ($verseCount -eq $check.ExpectedVerses) {
        Pass "$($check.Label): $verseCount verses (correct)"
    } else {
        Fail "$($check.Label): found $verseCount verses, expected $($check.ExpectedVerses)"
    }
}

# ── TEST 5: Cross-book navigation boundaries ──────────────────────────────────
Section "TEST 5: Cross-Book Navigation Boundaries"

# Genesis 50 should link forward to Exodus 1
$gen50 = Join-Path $OutputRoot 'books/01-Gen/50.html'
if (Test-Path $gen50) {
    $content = Get-Content -Raw $gen50
    if ($content -match '../02-Exod/1\.html') {
        Pass "Genesis 50: next link points to Exodus 1"
    } else {
        Fail "Genesis 50: next link to Exodus 1 NOT found"
    }
    if ($content -match 'id="verse-26"') {
        Pass "Genesis 50: has verse 26 (last verse)"
    } else {
        Fail "Genesis 50: verse 26 not found"
    }
} else {
    Warn "Genesis 50 not generated yet -- skipping boundary test"
}

# Malachi 4 should link forward to Matthew 1 (OT/NT boundary)
$mal4 = Join-Path $OutputRoot 'books/39-Mal/4.html'
if (Test-Path $mal4) {
    $content = Get-Content -Raw $mal4
    if ($content -match '../40-Matt/1\.html') {
        Pass "Malachi 4: next link points to Matthew 1 (OT/NT boundary)"
    } else {
        Fail "Malachi 4: next link to Matthew 1 NOT found"
    }
} else {
    Warn "Malachi 4 not generated yet -- skipping OT/NT boundary test"
}

# Revelation 22 should have NO next link
$rev22 = Join-Path $OutputRoot 'books/66-Rev/22.html'
if (Test-Path $rev22) {
    $content = Get-Content -Raw $rev22
if ($content -match 'btn-disabled.*Next|Next.*btn-disabled') {
        Pass "Revelation 22: Next button is disabled (correct -- last chapter)"
    } elseif ($content -match '<a href.*Next') {
        Fail "Revelation 22: Next button is active but should be disabled"
    } else {
        Fail "Revelation 22: Next button not found at all"
    }
    if ($content -match '21\.html') {
        Pass "Revelation 22: prev link points to Revelation 21 (correct)"
    } else {
        Fail "Revelation 22: prev link to Revelation 21 NOT found"
    }
}

# Revelation 1 should link back to Jude 1
$rev1 = Join-Path $OutputRoot 'books/66-Rev/1.html'
if (Test-Path $rev1) {
    $content = Get-Content -Raw $rev1
    if ($content -match '../65-Jude/1\.html') {
        Pass "Revelation 1: prev link points to Jude 1 (correct)"
    } else {
        Fail "Revelation 1: prev link to Jude 1 NOT found"
    }
} else {
    Warn "Revelation 22 not generated yet -- skipping last chapter test"
}

# Genesis 1 should have NO prev link
# Genesis 1 should have a DISABLED prev button
$gen1 = Join-Path $OutputRoot 'books/01-Gen/1.html'
if (Test-Path $gen1) {
    $content = Get-Content -Raw $gen1
    if ($content -match 'btn-disabled.*Prev|Prev.*btn-disabled') {
        Pass "Genesis 1: Prev button is disabled (correct -- first chapter)"
    } elseif ($content -match '<a href.*Prev') {
        Fail "Genesis 1: Prev button is active but should be disabled"
    } else {
        Fail "Genesis 1: Prev button not found at all"
    }
}

# ── TEST 6: Strong's link target validation (spot check) ─────────────────────
Section "TEST 6: Strong's Link Target Validation (Spot Check)"

# Extract all Strong's links from a few key chapters and verify targets exist
$spotChapters = @(
    [pscustomobject]@{ File='books/01-Gen/1.html';  Label='Genesis 1' }
    [pscustomobject]@{ File='books/08-Ruth/1.html'; Label='Ruth 1' }
    [pscustomobject]@{ File='books/43-John/1.html'; Label='John 1 (Greek links)' }
    [pscustomobject]@{ File='books/66-Rev/1.html';  Label='Revelation 1 (Greek links)' }
)

foreach ($spot in $spotChapters) {
    $chFile = Join-Path $OutputRoot $spot.File
    if (-not (Test-Path $chFile)) {
        Warn "$($spot.Label): file not found -- skipping link check"
        continue
    }
    $content  = Get-Content -Raw $chFile
    $matches  = [regex]::Matches($content, 'href="(\.\./\.\./dict/(?:hebrew|greek)/[hg]\d+\.html)"')
    $broken   = 0
    $checked  = 0
    foreach ($m in $matches) {
        $href     = $m.Groups[1].Value
        # Resolve relative path from books/XX-Xxx/ up two levels
        $target   = Join-Path $OutputRoot ($href -replace '^\.\./\.\./', '')
        $checked++
        if (-not (Test-Path $target)) { $broken++ }
    }
    if ($broken -eq 0 -and $checked -gt 0) {
        Pass "$($spot.Label): all $checked Strong's links resolve correctly"
    } elseif ($checked -eq 0) {
        Warn "$($spot.Label): no Strong's links found in chapter"
    } else {
        Fail "$($spot.Label): $broken of $checked Strong's links are broken"
    }
}

# ── TEST 7: Xref link target validation ──────────────────────────────────────
Section "TEST 7: Cross-Reference Page Validation"

$xrefDir = Join-Path $OutputRoot 'xrefs'
if (Test-Path $xrefDir) {
    $xrefFiles = @(Get-ChildItem $xrefDir -Filter '*.html')
    Pass "xrefs/ folder exists with $($xrefFiles.Count) pages"

    # Check a sample of xref pages for broken back-links
    $sampleSize = [Math]::Min(20, $xrefFiles.Count)
    $sample     = $xrefFiles | Select-Object -First $sampleSize
    $brokenBack = 0
    foreach ($xf in $sample) {
        $content = Get-Content -Raw $xf.FullName
        $backMatch = [regex]::Match($content, 'href="(\.\./books/[^"]+)"')
        if ($backMatch.Success) {
            $backHref   = $backMatch.Groups[1].Value
            $backTarget = Join-Path $OutputRoot ($backHref -replace '^\.\./','')
            # Strip anchor for file existence check
            $backFile   = ($backTarget -split '#')[0]
            if (-not (Test-Path $backFile)) { $brokenBack++ }
        }
    }
    if ($brokenBack -eq 0) {
        Pass "Xref back-links: all $sampleSize sampled pages link back correctly"
    } else {
        Fail "Xref back-links: $brokenBack of $sampleSize sampled pages have broken back-links"
    }
} else {
    Warn "xrefs/ folder not found -- no xref pages generated yet"
}

# ── TEST 8: HTML structure validation ────────────────────────────────────────
Section "TEST 8: HTML Structure Validation (Sample Chapters)"

$structSample = @(
    'books/01-Gen/1.html'
    'books/08-Ruth/2.html'
    'books/19-Ps/23.html'
    'books/43-John/3.html'
    'books/66-Rev/22.html'
)

foreach ($rel in $structSample) {
    $chFile = Join-Path $OutputRoot $rel
    if (-not (Test-Path $chFile)) {
        Warn "$rel not found -- skipping structure check"
        continue
    }
    $content = Get-Content -Raw $chFile
    $issues  = @()

    if ($content -notmatch '<nav class="chapter-nav">')   { $issues += 'missing chapter-nav' }
    if ($content -notmatch '<main class="chapter-content">') { $issues += 'missing chapter-content' }
    if ($content -notmatch 'id="verse-1"')                 { $issues += 'missing verse-1 anchor' }
    if ($content -notmatch 'css/style\.css')               { $issues += 'missing style.css link' }
    if ($content -notmatch 'js/fontsize\.js')              { $issues += 'missing fontsize.js' }
    if ($content -notmatch 'js/bookmarks\.js')             { $issues += 'missing bookmarks.js' }
    if ($content -notmatch 'navigate\.html')               { $issues += 'missing navigate.html link' }
    if ($content -notmatch 'index\.html')                  { $issues += 'missing index.html link' }

    if ($issues.Count -eq 0) {
        Pass "$rel`: structure OK"
    } else {
        Fail "$rel`: $($issues -join ', ')"
    }
}

# ── TEST 9: bible-data.js validation ─────────────────────────────────────────
Section "TEST 9: bible-data.js Validation"

$bibleDataFile = Join-Path $OutputRoot 'js/bible-data.js'
if (Test-Path $bibleDataFile) {
    $content = Get-Content -Raw $bibleDataFile
    if ($content -match 'var BIBLE_DATA') {
        Pass "bible-data.js: BIBLE_DATA variable declared"
    } else {
        Fail "bible-data.js: BIBLE_DATA variable not found"
    }
    
if (-not $BookFilter) {
        if ($content -match '"Genesis"') {
            Pass "bible-data.js: Genesis entry present"
        } else {
            Fail "bible-data.js: Genesis entry not found"
        }
        if ($content -match '"Revelation"') {
            Pass "bible-data.js: Revelation entry present"
        } else {
            Fail "bible-data.js: Revelation entry not found"
        }
    } else {
        $filterBook = $BookTable | Where-Object { $_.OsisId -eq $BookFilter }
        if ($content -match "`"$($filterBook.FullName)`"") {
            Pass "bible-data.js: $($filterBook.FullName) entry present"
        } else {
            Fail "bible-data.js: $($filterBook.FullName) entry not found"
        }
    }	

    # Check verse counts are not all zeros
    if ($content -match 'chapters: \[0, 0, 0') {
        Fail "bible-data.js: verse counts appear to be all zeros -- generator may not have extracted verses"
    } else {
        Pass "bible-data.js: verse counts appear populated"
    }
}

# ── TEST 10: Dictionary POS raw code check ────────────────────────────────────
Section "TEST 10: Dictionary POS Raw Code Check (Sample)"

$posSample = @(
    'dict/hebrew/h4125.html'   # Moab -- was showing n-pr-m n-pr-loc
    'dict/hebrew/h1162.html'   # Boaz -- was showing n-pr-m
    'dict/hebrew/h3389.html'   # Jerusalem
    'dict/hebrew/h0430.html'   # Elohim
    'dict/greek/g3056.html'    # Logos
)

$rawCodePattern = '\b(n-pr-m|n-pr-f|n-pr-loc|n-m|n-f|a-m|a-f|prt|inj|dp)\b(?=\s*</td>)'

foreach ($rel in $posSample) {
    $dictFile = Join-Path $OutputRoot $rel
    if (-not (Test-Path $dictFile)) {
        Warn "$rel not found -- skipping POS check"
        continue
    }
    $content = Get-Content -Raw $dictFile
    if ($content -match $rawCodePattern) {
        Fail "$rel`: raw morph code still present in output: $($matches[0])"
    } else {
        Pass "$rel`: POS field correctly expanded"
    }
}

# ── TEST 11: navigate.html structure ─────────────────────────────────────────
Section "TEST 11: navigate.html Structure"

$navFile = Join-Path $OutputRoot 'navigate.html'
if (Test-Path $navFile) {
    $content = Get-Content -Raw $navFile
    if ($content -match 'id="book-select"')    { Pass "navigate.html: book-select dropdown present" }
    else                                        { Fail "navigate.html: book-select dropdown MISSING" }
    if ($content -match 'id="chapter-select"') { Pass "navigate.html: chapter-select dropdown present" }
    else                                        { Fail "navigate.html: chapter-select dropdown MISSING" }
    if ($content -match 'id="verse-select"')   { Pass "navigate.html: verse-select dropdown present" }
    else                                        { Fail "navigate.html: verse-select dropdown MISSING" }
    if ($content -match 'BIBLE_DATA')           { Pass "navigate.html: references BIBLE_DATA" }
    else                                        { Fail "navigate.html: BIBLE_DATA reference MISSING" }
    if ($content -match 'onGo\(\)')             { Pass "navigate.html: Go button handler present" }
    else                                        { Fail "navigate.html: Go button handler MISSING" }
    if ($content -notmatch '\blet\b|\bconst\b|\b=>\b') {
        Pass "navigate.html: no ES6 syntax detected (Kindle-safe)"
    } else {
        Fail "navigate.html: ES6 syntax detected -- may not work on Kindle"
    }
}

# ── FINAL REPORT ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host " QA TEST SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host "  PASSED  : $PassCount" -ForegroundColor Green
Write-Host "  FAILED  : $FailCount" -ForegroundColor $(if ($FailCount -gt 0) { 'Red' } else { 'Green' })
Write-Host "  WARNINGS: $WarnCount" -ForegroundColor $(if ($WarnCount -gt 0) { 'Yellow' } else { 'Gray' })

if ($FailCount -gt 0) {
    Write-Host ""
    Write-Host "FAILURES:" -ForegroundColor Red
    foreach ($e in $Errors) {
        Write-Host "  - $e" -ForegroundColor Red
    }
}

if ($WarnCount -gt 0) {
    Write-Host ""
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($w in $Warnings) {
        Write-Host "  - $w" -ForegroundColor Yellow
    }
}

Write-Host ""
if ($FailCount -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
} else {
    Write-Host "$FailCount test(s) failed. Review the failures above." -ForegroundColor Red
}
