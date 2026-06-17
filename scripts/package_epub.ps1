# ================================================================
# package_epub.ps1 — EPUB Packager for KJV Strong's Bible
# ================================================================
# Builds a valid EPUB 2.0 container from the generated project
# files, optionally extracts and pushes to Kindle via ADB.
#
# Usage:
#   pwsh -File scripts/package_epub.ps1
#   pwsh -File scripts/package_epub.ps1 -SkipAdb
#   pwsh -File scripts/package_epub.ps1 -SkipStrip  # keep PC elements
#
# ================================================================

param(
    [string]$OutputEpub  = 'KJV-Strongs.epub',
    [string]$ProjectRoot = 'C:\Users\OldTi\KJV-Strongs',
    [string]$AdbPath     = 'H:\Android SDK Platform Tools\adb.exe',
    [string]$KindlePath  = '/data/local/tmp',
    [switch]$SkipAdb,
    [switch]$SkipStrip
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# ── Resolve paths ────────────────────────────────────────────────

$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$EpubPath = Join-Path $ProjectRoot $OutputEpub
$StagingDir = Join-Path $env:TEMP "kjv-epub-staging-$(Get-Random)"


# ================================================================
# Book Table
# ================================================================

$BookTable = @(
    @{ Num=1;  OsisId="Gen";    Folder="01-Gen";     Name="Genesis";         Ch=50 }
    @{ Num=2;  OsisId="Exod";   Folder="02-Exod";    Name="Exodus";          Ch=40 }
    @{ Num=3;  OsisId="Lev";    Folder="03-Lev";     Name="Leviticus";       Ch=27 }
    @{ Num=4;  OsisId="Num";    Folder="04-Num";     Name="Numbers";         Ch=36 }
    @{ Num=5;  OsisId="Deut";   Folder="05-Deut";    Name="Deuteronomy";     Ch=34 }
    @{ Num=6;  OsisId="Josh";   Folder="06-Josh";    Name="Joshua";          Ch=24 }
    @{ Num=7;  OsisId="Judg";   Folder="07-Judg";    Name="Judges";          Ch=21 }
    @{ Num=8;  OsisId="Ruth";   Folder="08-Ruth";    Name="Ruth";            Ch=4  }
    @{ Num=9;  OsisId="1Sam";   Folder="09-1Sam";    Name="1 Samuel";        Ch=31 }
    @{ Num=10; OsisId="2Sam";   Folder="10-2Sam";    Name="2 Samuel";        Ch=24 }
    @{ Num=11; OsisId="1Kgs";   Folder="11-1Kgs";    Name="1 Kings";         Ch=22 }
    @{ Num=12; OsisId="2Kgs";   Folder="12-2Kgs";    Name="2 Kings";         Ch=25 }
    @{ Num=13; OsisId="1Chr";   Folder="13-1Chr";    Name="1 Chronicles";    Ch=29 }
    @{ Num=14; OsisId="2Chr";   Folder="14-2Chr";    Name="2 Chronicles";    Ch=36 }
    @{ Num=15; OsisId="Ezra";   Folder="15-Ezra";    Name="Ezra";            Ch=10 }
    @{ Num=16; OsisId="Neh";    Folder="16-Neh";     Name="Nehemiah";        Ch=13 }
    @{ Num=17; OsisId="Esth";   Folder="17-Esth";    Name="Esther";          Ch=10 }
    @{ Num=18; OsisId="Job";    Folder="18-Job";     Name="Job";             Ch=42 }
    @{ Num=19; OsisId="Ps";     Folder="19-Ps";      Name="Psalms";          Ch=150}
    @{ Num=20; OsisId="Prov";   Folder="20-Prov";    Name="Proverbs";        Ch=31 }
    @{ Num=21; OsisId="Eccl";   Folder="21-Eccl";    Name="Ecclesiastes";    Ch=12 }
    @{ Num=22; OsisId="Song";   Folder="22-Song";    Name="Song of Solomon"; Ch=8  }
    @{ Num=23; OsisId="Isa";    Folder="23-Isa";     Name="Isaiah";          Ch=66 }
    @{ Num=24; OsisId="Jer";    Folder="24-Jer";     Name="Jeremiah";        Ch=52 }
    @{ Num=25; OsisId="Lam";    Folder="25-Lam";     Name="Lamentations";    Ch=5  }
    @{ Num=26; OsisId="Ezek";   Folder="26-Ezek";    Name="Ezekiel";        Ch=48 }
    @{ Num=27; OsisId="Dan";    Folder="27-Dan";     Name="Daniel";          Ch=12 }
    @{ Num=28; OsisId="Hos";    Folder="28-Hos";     Name="Hosea";           Ch=14 }
    @{ Num=29; OsisId="Joel";   Folder="29-Joel";    Name="Joel";            Ch=3  }
    @{ Num=30; OsisId="Amos";   Folder="30-Amos";    Name="Amos";            Ch=9  }
    @{ Num=31; OsisId="Obad";   Folder="31-Obad";    Name="Obadiah";         Ch=1  }
    @{ Num=32; OsisId="Jonah";  Folder="32-Jonah";   Name="Jonah";           Ch=4  }
    @{ Num=33; OsisId="Mic";    Folder="33-Mic";     Name="Micah";           Ch=7  }
    @{ Num=34; OsisId="Nah";    Folder="34-Nah";     Name="Nahum";           Ch=3  }
    @{ Num=35; OsisId="Hab";    Folder="35-Hab";     Name="Habakkuk";        Ch=3  }
    @{ Num=36; OsisId="Zeph";   Folder="36-Zeph";    Name="Zephaniah";       Ch=3  }
    @{ Num=37; OsisId="Hag";    Folder="37-Hag";     Name="Haggai";          Ch=2  }
    @{ Num=38; OsisId="Zech";   Folder="38-Zech";    Name="Zechariah";       Ch=14 }
    @{ Num=39; OsisId="Mal";    Folder="39-Mal";     Name="Malachi";         Ch=4  }
    @{ Num=40; OsisId="Matt";   Folder="40-Matt";    Name="Matthew";         Ch=28 }
    @{ Num=41; OsisId="Mark";   Folder="41-Mark";    Name="Mark";            Ch=16 }
    @{ Num=42; OsisId="Luke";   Folder="42-Luke";    Name="Luke";            Ch=24 }
    @{ Num=43; OsisId="John";   Folder="43-John";    Name="John";            Ch=21 }
    @{ Num=44; OsisId="Acts";   Folder="44-Acts";    Name="Acts";            Ch=28 }
    @{ Num=45; OsisId="Rom";    Folder="45-Rom";     Name="Romans";          Ch=16 }
    @{ Num=46; OsisId="1Cor";   Folder="46-1Cor";    Name="1 Corinthians";   Ch=16 }
    @{ Num=47; OsisId="2Cor";   Folder="47-2Cor";    Name="2 Corinthians";   Ch=13 }
    @{ Num=48; OsisId="Gal";    Folder="48-Gal";     Name="Galatians";       Ch=6  }
    @{ Num=49; OsisId="Eph";    Folder="49-Eph";     Name="Ephesians";       Ch=6  }
    @{ Num=50; OsisId="Phil";   Folder="50-Phil";    Name="Philippians";     Ch=4  }
    @{ Num=51; OsisId="Col";    Folder="51-Col";     Name="Colossians";      Ch=4  }
    @{ Num=52; OsisId="1Thess"; Folder="52-1Thess";  Name="1 Thessalonians"; Ch=5  }
    @{ Num=53; OsisId="2Thess"; Folder="53-2Thess";  Name="2 Thessalonians"; Ch=3  }
    @{ Num=54; OsisId="1Tim";   Folder="54-1Tim";    Name="1 Timothy";       Ch=6  }
    @{ Num=55; OsisId="2Tim";   Folder="55-2Tim";    Name="2 Timothy";       Ch=4  }
    @{ Num=56; OsisId="Titus";  Folder="56-Titus";   Name="Titus";           Ch=3  }
    @{ Num=57; OsisId="Phlm";   Folder="57-Phlm";    Name="Philemon";        Ch=1  }
    @{ Num=58; OsisId="Heb";    Folder="58-Heb";     Name="Hebrews";         Ch=13 }
    @{ Num=59; OsisId="Jas";    Folder="59-Jas";     Name="James";           Ch=5  }
    @{ Num=60; OsisId="1Pet";   Folder="60-1Pet";    Name="1 Peter";         Ch=5  }
    @{ Num=61; OsisId="2Pet";   Folder="61-2Pet";    Name="2 Peter";         Ch=3  }
    @{ Num=62; OsisId="1John";  Folder="62-1John";   Name="1 John";          Ch=5  }
    @{ Num=63; OsisId="2John";  Folder="63-2John";   Name="2 John";          Ch=1  }
    @{ Num=64; OsisId="3John";  Folder="64-3John";   Name="3 John";          Ch=1  }
    @{ Num=65; OsisId="Jude";   Folder="65-Jude";    Name="Jude";            Ch=1  }
    @{ Num=66; OsisId="Rev";    Folder="66-Rev";     Name="Revelation";      Ch=22 }
)


# ================================================================
# MIME type map
# ================================================================

$MimeMap = @{
    ".html" = "application/xhtml+xml"
    ".css"  = "text/css"
    ".js"   = "application/javascript"
    ".ico"  = "image/vnd.microsoft.icon"
    ".json" = "application/json"
    ".ncx"  = "application/x-dtbncx+xml"
}


# ================================================================
# Helper: Strip PC-only elements from chapter HTML
# ================================================================

function Strip-PcElements {
    param([string]$Html)

    # Remove sync button
    $Html = $Html -replace '(?s)<button[^>]*class="[^"]*sync-btn[^"]*"[^>]*>.*?</button>\s*', ''

    # Remove notes.js script tag
    $Html = $Html -replace '\s*<script[^>]*src="[^"]*notes\.js"[^>]*>\s*</script>', ''

    # Remove pencil buttons (note-btn)
    $Html = $Html -replace '\s*<button[^>]*class="[^"]*note-btn[^"]*"[^>]*>.*?</button>', ''

    # Remove unbaked-indicator span
    $Html = $Html -replace '\s*<span[^>]*id="unbaked-indicator"[^>]*>\s*</span>', ''

    return $Html
}


# ================================================================
# Helper: Generate a safe manifest ID from a file path
# ================================================================

function Get-ManifestId {
    param([string]$RelPath)
    $id = $RelPath -replace '[/\\]', '-' -replace '\.', '-' -replace '[^a-zA-Z0-9_-]', '_'
    return "item-$id"
}


# ================================================================
# Phase 1: Create Staging Directory
# ================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " KJV Strong's EPUB Packager" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project root:  $ProjectRoot" -ForegroundColor Gray
Write-Host "Output:        $EpubPath" -ForegroundColor Gray
Write-Host "Strip PC-only: $(-not $SkipStrip)" -ForegroundColor Gray
Write-Host "ADB push:      $(-not $SkipAdb)" -ForegroundColor Gray
Write-Host ""

if (Test-Path $StagingDir) { Remove-Item $StagingDir -Recurse -Force }
New-Item -ItemType Directory -Path $StagingDir -Force | Out-Null

# Create directory structure
$oebpsDir = Join-Path $StagingDir "OEBPS"
New-Item -ItemType Directory -Path (Join-Path $StagingDir "META-INF") -Force | Out-Null
New-Item -ItemType Directory -Path $oebpsDir -Force | Out-Null


# ================================================================
# Phase 2: Write EPUB Metadata Files
# ================================================================

Write-Host "Phase 1: Writing EPUB metadata..." -ForegroundColor Cyan

# ── mimetype (must be first entry, uncompressed) ──
Set-Content -Path (Join-Path $StagingDir "mimetype") -Value "application/epub+zip" -NoNewline -Encoding ASCII

# ── META-INF/container.xml ──
$containerXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'@
Set-Content -Path (Join-Path $StagingDir "META-INF\container.xml") -Value $containerXml -Encoding UTF8

Write-Host "  mimetype, container.xml written" -ForegroundColor Green


# ================================================================
# Phase 3: Copy Content Files to OEBPS
# ================================================================

Write-Host "Phase 2: Copying content files..." -ForegroundColor Cyan

# Track all files for manifest generation
$manifestFiles = [System.Collections.Generic.List[hashtable]]::new()
$fileCount = 0
$chapterFilesCopied = 0

# ── Helper: copy a file to staging ──
function Stage-File {
    param(
        [string]$SourcePath,
        [string]$OebpsRelPath,    # path relative to OEBPS/
        [switch]$StripHtml
    )

    $targetPath = Join-Path $oebpsDir $OebpsRelPath
    $targetDir = Split-Path $targetPath -Parent
    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }

    if ($StripHtml -and -not $SkipStrip) {
        $html = Get-Content -Path $SourcePath -Raw -Encoding UTF8
        $html = Strip-PcElements -Html $html
        Set-Content -Path $targetPath -Value $html -Encoding UTF8 -NoNewline
    }
    else {
        Copy-Item -Path $SourcePath -Destination $targetPath -Force
    }

    $ext = [System.IO.Path]::GetExtension($OebpsRelPath).ToLower()
    $mime = if ($MimeMap.ContainsKey($ext)) { $MimeMap[$ext] } else { "application/octet-stream" }

    $script:manifestFiles.Add(@{
        id   = Get-ManifestId -RelPath $OebpsRelPath
        href = $OebpsRelPath.Replace("\", "/")
        mime = $mime
    })

    $script:fileCount++
    if ($script:fileCount % 500 -eq 0) {
        Write-Host "  Copied $($script:fileCount) files..." -ForegroundColor Gray
    }
}

# ── CSS: style-kindle.css → style.css ──
$kindleCss = Join-Path $ProjectRoot "css\style-kindle.css"
if (Test-Path $kindleCss) {
    Stage-File -SourcePath $kindleCss -OebpsRelPath "css\style.css"
    Write-Host "  css/style-kindle.css -> css/style.css" -ForegroundColor Green
}
else {
    # Fall back to regular style.css
    $pcCss = Join-Path $ProjectRoot "css\style.css"
    if (Test-Path $pcCss) {
        Stage-File -SourcePath $pcCss -OebpsRelPath "css\style.css"
    }
}

# ── JavaScript files ──
$jsFiles = @("bible-data.js", "fontsize.js", "bookmarks.js", "sticky-header.js")
foreach ($jsFile in $jsFiles) {
    $src = Join-Path $ProjectRoot "js\$jsFile"
    if (Test-Path $src) {
        Stage-File -SourcePath $src -OebpsRelPath "js\$jsFile"
    }
}
# notes.js deliberately excluded — notes are baked into HTML

# ── Favicon ──
$favicon = Join-Path $ProjectRoot "BiblePencil.ico"
if (Test-Path $favicon) {
    Stage-File -SourcePath $favicon -OebpsRelPath "BiblePencil.ico"
}

# ── Root HTML pages ──
foreach ($rootPage in @("index.html", "navigate.html")) {
    $src = Join-Path $ProjectRoot $rootPage
    if (Test-Path $src) {
        Stage-File -SourcePath $src -OebpsRelPath $rootPage
    }
}

# ── Chapter HTML files (with stripping) ──
Write-Host "  Copying chapter files (with PC element stripping)..." -ForegroundColor Gray
foreach ($book in $BookTable) {
    $bookDir = Join-Path $ProjectRoot "books\$($book.Folder)"
    if (-not (Test-Path $bookDir)) { continue }

    for ($ch = 1; $ch -le $book.Ch; $ch++) {
        $src = Join-Path $bookDir "$ch.html"
        if (Test-Path $src) {
            Stage-File -SourcePath $src -OebpsRelPath "books\$($book.Folder)\$ch.html" -StripHtml
            $chapterFilesCopied++
        }
    }
}
Write-Host "  $chapterFilesCopied chapter files copied" -ForegroundColor Green

# ── Dictionary pages ──
Write-Host "  Copying dictionary files..." -ForegroundColor Gray
foreach ($lang in @("hebrew", "greek")) {
    $dictDir = Join-Path $ProjectRoot "dict\$lang"
    if (-not (Test-Path $dictDir)) { continue }

    $dictFiles = Get-ChildItem -Path $dictDir -Filter "*.html"
    foreach ($f in $dictFiles) {
        Stage-File -SourcePath $f.FullName -OebpsRelPath "dict\$lang\$($f.Name)"
    }
}

# ── Index pages ──
$indexDir = Join-Path $ProjectRoot "indexes"
if (Test-Path $indexDir) {
    $indexFiles = Get-ChildItem -Path $indexDir -Filter "*.html"
    foreach ($f in $indexFiles) {
        Stage-File -SourcePath $f.FullName -OebpsRelPath "indexes\$($f.Name)"
    }
}

# ── Cross-reference pages ──
$xrefsDir = Join-Path $ProjectRoot "xrefs"
if (Test-Path $xrefsDir) {
    $xrefFiles = Get-ChildItem -Path $xrefsDir -Filter "*.html"
    foreach ($f in $xrefFiles) {
        Stage-File -SourcePath $f.FullName -OebpsRelPath "xrefs\$($f.Name)"
    }
}

# ── Baked note pages ──
$notesDir = Join-Path $ProjectRoot "notes"
if (Test-Path $notesDir) {
    $noteFiles = Get-ChildItem -Path $notesDir -Filter "*.html"
    foreach ($f in $noteFiles) {
        Stage-File -SourcePath $f.FullName -OebpsRelPath "notes\$($f.Name)"
    }
}

Write-Host "  Total: $fileCount files staged" -ForegroundColor Green


# ================================================================
# Phase 4: Generate content.opf
# ================================================================

Write-Host "Phase 3: Generating content.opf..." -ForegroundColor Cyan

$opf = [System.Text.StringBuilder]::new()

[void]$opf.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$opf.AppendLine('<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" version="2.0">')
[void]$opf.AppendLine('')
[void]$opf.AppendLine('  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">')
[void]$opf.AppendLine('    <dc:identifier id="BookId">KJV-Strongs-EBook</dc:identifier>')
[void]$opf.AppendLine("    <dc:title>KJV Bible with Strong's Concordance</dc:title>")
[void]$opf.AppendLine('    <dc:language>en</dc:language>')
[void]$opf.AppendLine('    <dc:creator>KJV-Strongs Project</dc:creator>')
[void]$opf.AppendLine("    <dc:date>$(Get-Date -Format 'yyyy-MM-dd')</dc:date>")
[void]$opf.AppendLine('  </metadata>')
[void]$opf.AppendLine('')

# ── Manifest ──
[void]$opf.AppendLine('  <manifest>')
[void]$opf.AppendLine('    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>')

foreach ($mf in $manifestFiles) {
    [void]$opf.AppendLine("    <item id=`"$($mf.id)`" href=`"$($mf.href)`" media-type=`"$($mf.mime)`"/>")
}

[void]$opf.AppendLine('  </manifest>')
[void]$opf.AppendLine('')

# ── Spine (reading order) ──
[void]$opf.AppendLine('  <spine toc="ncx">')

# index.html first
$indexId = Get-ManifestId -RelPath "index.html"
[void]$opf.AppendLine("    <itemref idref=`"$indexId`"/>")

# navigate.html
$navId = Get-ManifestId -RelPath "navigate.html"
[void]$opf.AppendLine("    <itemref idref=`"$navId`"/>")

# Chapter pages in canonical order
foreach ($book in $BookTable) {
    for ($ch = 1; $ch -le $book.Ch; $ch++) {
        $relPath = "books/$($book.Folder)/$ch.html"
        $id = Get-ManifestId -RelPath $relPath
        [void]$opf.AppendLine("    <itemref idref=`"$id`"/>")
    }
}

[void]$opf.AppendLine('  </spine>')
[void]$opf.AppendLine('')

# ── Guide ──
[void]$opf.AppendLine('  <guide>')
[void]$opf.AppendLine('    <reference type="toc" title="Table of Contents" href="index.html"/>')
[void]$opf.AppendLine('    <reference type="text" title="Navigate" href="navigate.html"/>')
[void]$opf.AppendLine('  </guide>')
[void]$opf.AppendLine('')
[void]$opf.AppendLine('</package>')

$opfPath = Join-Path $oebpsDir "content.opf"
Set-Content -Path $opfPath -Value $opf.ToString() -Encoding UTF8
Write-Host "  content.opf written ($($manifestFiles.Count) manifest entries)" -ForegroundColor Green


# ================================================================
# Phase 5: Generate toc.ncx
# ================================================================

Write-Host "Phase 4: Generating toc.ncx..." -ForegroundColor Cyan

$ncx = [System.Text.StringBuilder]::new()
$playOrder = 1

[void]$ncx.AppendLine('<?xml version="1.0" encoding="UTF-8"?>')
[void]$ncx.AppendLine('<!DOCTYPE ncx PUBLIC "-//NISO//DTD ncx 2005-1//EN" "http://www.daisy.org/z3986/2005/ncx-2005-1.dtd">')
[void]$ncx.AppendLine('<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">')
[void]$ncx.AppendLine('  <head>')
[void]$ncx.AppendLine('    <meta name="dtb:uid" content="KJV-Strongs-EBook"/>')
[void]$ncx.AppendLine("    <meta name=`"dtb:depth`" content=`"2`"/>")
[void]$ncx.AppendLine('    <meta name="dtb:totalPageCount" content="0"/>')
[void]$ncx.AppendLine('    <meta name="dtb:maxPageNumber" content="0"/>')
[void]$ncx.AppendLine('  </head>')
[void]$ncx.AppendLine("  <docTitle><text>KJV Bible with Strong's Concordance</text></docTitle>")
[void]$ncx.AppendLine('  <navMap>')

# Table of Contents entry
[void]$ncx.AppendLine("    <navPoint id=`"navpoint-toc`" playOrder=`"$playOrder`">")
[void]$ncx.AppendLine('      <navLabel><text>Table of Contents</text></navLabel>')
[void]$ncx.AppendLine('      <content src="index.html"/>')
[void]$ncx.AppendLine('    </navPoint>')
$playOrder++

# 66 books with chapter sub-points
foreach ($book in $BookTable) {
    $bookId = "navpoint-book-$($book.Num)"

    [void]$ncx.AppendLine("    <navPoint id=`"$bookId`" playOrder=`"$playOrder`">")
    [void]$ncx.AppendLine("      <navLabel><text>$($book.Name)</text></navLabel>")
    [void]$ncx.AppendLine("      <content src=`"books/$($book.Folder)/1.html`"/>")
    $playOrder++

    for ($ch = 1; $ch -le $book.Ch; $ch++) {
        $chId = "navpoint-$($book.OsisId)-$ch"
        [void]$ncx.AppendLine("      <navPoint id=`"$chId`" playOrder=`"$playOrder`">")
        [void]$ncx.AppendLine("        <navLabel><text>$($book.Name) $ch</text></navLabel>")
        [void]$ncx.AppendLine("        <content src=`"books/$($book.Folder)/$ch.html`"/>")
        [void]$ncx.AppendLine("      </navPoint>")
        $playOrder++
    }

    [void]$ncx.AppendLine('    </navPoint>')
}

[void]$ncx.AppendLine('  </navMap>')
[void]$ncx.AppendLine('</ncx>')

$ncxPath = Join-Path $oebpsDir "toc.ncx"
Set-Content -Path $ncxPath -Value $ncx.ToString() -Encoding UTF8

$totalNavPoints = $playOrder - 1
Write-Host "  toc.ncx written ($totalNavPoints navigation points)" -ForegroundColor Green


# ================================================================
# Phase 6: Build EPUB (ZIP)
# ================================================================

Write-Host "Phase 5: Building EPUB..." -ForegroundColor Cyan

if (Test-Path $EpubPath) { Remove-Item $EpubPath -Force }

# Create ZIP with mimetype as first entry, uncompressed
$zipStream = [System.IO.File]::Create($EpubPath)
$archive = [System.IO.Compression.ZipArchive]::new($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)

# ── mimetype MUST be first, uncompressed ──
$mimetypeEntry = $archive.CreateEntry("mimetype", [System.IO.Compression.CompressionLevel]::NoCompression)
$mimetypeStream = $mimetypeEntry.Open()
$mimetypeBytes = [System.Text.Encoding]::ASCII.GetBytes("application/epub+zip")
$mimetypeStream.Write($mimetypeBytes, 0, $mimetypeBytes.Length)
$mimetypeStream.Close()

# ── Add all other files with compression ──
$addedCount = 0
$allStagedFiles = Get-ChildItem -Path $StagingDir -Recurse -File |
    Where-Object { $_.Name -ne "mimetype" }

foreach ($f in $allStagedFiles) {
    $relPath = $f.FullName.Substring($StagingDir.Length + 1).Replace("\", "/")
    $entry = $archive.CreateEntry($relPath, [System.IO.Compression.CompressionLevel]::Optimal)

    $entryStream = $entry.Open()
    $fileBytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $entryStream.Write($fileBytes, 0, $fileBytes.Length)
    $entryStream.Close()

    $addedCount++
    if ($addedCount % 1000 -eq 0) {
        Write-Host "  Added $addedCount files to EPUB..." -ForegroundColor Gray
    }
}

$archive.Dispose()
$zipStream.Close()

$epubSize = (Get-Item $EpubPath).Length
$epubSizeMB = [Math]::Round($epubSize / 1MB, 1)
Write-Host "  EPUB built: $EpubPath" -ForegroundColor Green
Write-Host "  Size: ${epubSizeMB} MB ($($addedCount + 1) entries)" -ForegroundColor Green


# ================================================================
# Phase 7: Clean up staging
# ================================================================

Write-Host "Cleaning up staging directory..." -ForegroundColor Gray
Remove-Item $StagingDir -Recurse -Force


# ================================================================
# Phase 8: Extract and ADB Push (optional)
# ================================================================

if (-not $SkipAdb) {
    Write-Host ""
    Write-Host "Phase 6: Extracting EPUB and pushing to Kindle..." -ForegroundColor Cyan

    # Check ADB
    if (-not (Test-Path $AdbPath)) {
        Write-Host "  ERROR: ADB not found at $AdbPath" -ForegroundColor Red
        Write-Host "  Skipping ADB push. EPUB was built successfully." -ForegroundColor Yellow
    }
    else {
        # Extract EPUB to temp directory
        $extractDir = Join-Path $env:TEMP "kjv-epub-extract-$(Get-Random)"
        [System.IO.Compression.ZipFile]::ExtractToDirectory($EpubPath, $extractDir)

        # The content is under OEBPS/
        $contentDir = Join-Path $extractDir "OEBPS"

        if (Test-Path $contentDir) {
            $pushFiles = Get-ChildItem -Path $contentDir -Recurse -File
            $pushCount = 0
            $pushErrors = 0

            foreach ($f in $pushFiles) {
                $relPath = $f.FullName.Substring($contentDir.Length + 1).Replace("\", "/")
                $targetPath = "$KindlePath/$relPath"

                try {
                    & $AdbPath push $f.FullName $targetPath 2>&1 | Out-Null
                    $pushCount++
                    if ($pushCount % 500 -eq 0) {
                        Write-Host "  Pushed $pushCount files..." -ForegroundColor Gray
                    }
                }
                catch {
                    $pushErrors++
                }
            }

            Write-Host "  Pushed $pushCount files to Kindle ($pushErrors errors)" -ForegroundColor Green
        }

        # Clean up
        Remove-Item $extractDir -Recurse -Force
    }
}


# ================================================================
# Phase 9: Update .gitignore
# ================================================================

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$gitignoreContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { "" }
$updated = $false

if ($gitignoreContent -notmatch [regex]::Escape($OutputEpub)) {
    Add-Content -Path $gitignorePath -Value "`n$OutputEpub"
    $updated = $true
}

if ($updated) {
    Write-Host "  Updated .gitignore" -ForegroundColor Gray
}


# ================================================================
# Summary
# ================================================================

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " EPUB Build Complete" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Output:      $EpubPath" -ForegroundColor White
Write-Host "  Size:        ${epubSizeMB} MB" -ForegroundColor White
Write-Host "  Files:       $($addedCount + 1) entries" -ForegroundColor White
Write-Host "  Chapters:    $chapterFilesCopied" -ForegroundColor White
Write-Host "  Nav points:  $totalNavPoints" -ForegroundColor White
Write-Host "  PC stripped: $(-not $SkipStrip)" -ForegroundColor White
if (-not $SkipAdb) {
    Write-Host "  ADB pushed:  $pushCount files" -ForegroundColor White
}
Write-Host ""
