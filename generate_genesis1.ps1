param(
    [string]$OsisPath = 'kjv.osis.xml',
    [string]$OutputChapter = 'sample-chapter-gen1.html',
    [string]$OutputVersePage = 'sample-verse-gen1.html'
)

function Get-StrongLinkHtml {
    param(
        [string]$lemmaAttr
    )

    $links = @()
    foreach ($lemma in ($lemmaAttr -split '\s+')) {
        if ($lemma -match '^strong:H(\d+)$') {
            $strongNum = $matches[1].PadLeft(4, '0')
            $links += '<a href="/dict/hebrew/h' + $strongNum + '.html" class="strongs-link" title="View Strong''s Hebrew H' + $strongNum + ' entry">[H' + $strongNum + ']</a>'
        }
    }
    return $links -join ' '
}

function EscapeJsHtml {
    param(
        [string]$text
    )
    return ($text -replace '\\', '\\\\' -replace "'", "\\'" -replace "`r?`n", ' ')
}

function NormalizeVerseText {
    param(
        [string]$text
    )
    $text = ($text -replace '\s+', ' ')
    $text = ($text -replace '\s+([,.;:!?])', '$1')
    return $text.Trim()
}

Write-Host "Loading OSIS source from $OsisPath..."
$osis = [xml](Get-Content -Raw -Path $OsisPath)
$ns = New-Object System.Xml.XmlNamespaceManager($osis.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

$chapter = $osis.SelectSingleNode('//o:chapter[@osisID="Gen.1"]', $ns)
if (-not $chapter) { throw "Could not find chapter Gen.1 in $OsisPath" }

$verses = @{}
$currentVerse = $null
$currentText = ''

foreach ($node in $chapter.ChildNodes) {
    if ($node.LocalName -eq 'verse') {
        if ($node.Attributes['osisID']) {
            $currentVerse = [regex]::Match($node.Attributes['osisID'].Value, '\d+$').Value
            $currentText = ''
        } elseif ($node.Attributes['eID']) {
            if ($currentVerse) {
                $verses[$currentVerse] = NormalizeVerseText $currentText
                $currentVerse = $null
            }
        }
        continue
    }

    if (-not $currentVerse) { continue }

    if ($node.LocalName -eq 'w') {
        $currentText += $node.InnerText
        if ($node.Attributes['lemma']) {
            $links = Get-StrongLinkHtml -lemmaAttr $node.Attributes['lemma'].Value
            if ($links) { $currentText += ' ' + $links }
        }
        $currentText += ' '
        continue
    }

    if ($node.LocalName -eq 'transChange' -or $node.LocalName -eq 'divineName') {
        $currentText += $node.InnerText + ' '
        continue
    }

    if ($node.NodeType -eq [System.Xml.XmlNodeType]::Text -or $node.NodeType -eq [System.Xml.XmlNodeType]::CDATA) {
        $currentText += $node.Value
    }
}

if ($currentVerse) {
    $verses[$currentVerse] = NormalizeVerseText $currentText
}

if ($verses.Count -eq 0) { throw "No verses extracted from Gen.1" }

Write-Host "Found $($verses.Count) verses in Genesis 1. Generating pages..."

$chapterBlocks = ''
foreach ($verseNum in ($verses.Keys | Sort-Object {[int]$_})) {
    $verseText = $verses[$verseNum]
    $chapterBlocks += @"
      <p class="verse" id="verse-$verseNum">
        <a href="sample-verse-gen1.html?source=chapter&verse=$verseNum" class="verse-num-link" title="Zoom to verse $verseNum"><span class="verse-num">$verseNum</span></a>
        $verseText
        <a href="sample-note-gen1-$verseNum.html?source=chapter&verse=$verseNum" class="superscript-link note-superscript" title="Open personal note for Genesis 1:$verseNum">¹</a>
        <a href="sample-xref-gen1-$verseNum.html?source=chapter&verse=$verseNum" class="superscript-link xref-superscript" title="Open cross-references for Genesis 1:$verseNum">✝</a>.
      </p>
"@}

$chapterHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sample Chapter — Genesis 1</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <header class="page-header">
    <h1>Genesis 1 — Sample Chapter</h1>
    <p class="chapter-nav">
      <a href="index.html" class="btn" title="Go to book list">Books</a>
      <a href="gen_ch00.html" class="btn" title="Previous chapter">← Previous</a>
      <a href="gen_ch02.html" class="btn" title="Next chapter">Next →</a>
      <a href="/indexes/strongs-hebrew-index.html" class="btn" title="Browse Strong's Hebrew index">H Index</a>
      <a href="/indexes/strongs-greek-index.html" class="btn" title="Browse Strong's Greek index">G Index</a>
      <a href="/indexes/english-concordance.html" class="btn" title="Browse English concordance">Concordance</a>
    </p>
    <div class="nav">
      <a href="sample-index.html" class="icon-btn" title="Back to sample index" aria-label="Back to sample index" data-icon="🏠">Index</a>
      <strong>Sample Preview:</strong>
      <a href="sample-note-gen1-1.html?source=chapter&verse=1" class="icon-btn note-btn" title="View sample note for Genesis 1:1" aria-label="Sample note for Genesis 1:1" data-icon="📝">Note 1:1</a>
      <a href="sample-xref-gen1-1.html?source=chapter&verse=1" class="icon-btn xref-btn" title="View sample cross-references for Genesis 1:1" aria-label="Sample cross-references for Genesis 1:1" data-icon="🔗">Xref 1:1</a>
    </div>
  </header>

  <main class="chapter-content">
    <article class="verse-block">
$chapterBlocks
    </article>

    <article class="section note-section">
      <p class="note-title"><strong>Chapter summary</strong></p>
      <p>This sample chapter page demonstrates how multiple verses can be displayed together with Strong's links, interactive note and cross-reference markers, and smooth navigation across sections.</p>
    </article>
  </main>

  <footer class="chapter-footer">
    <p>Last updated: <span class="note-meta">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</span></p>
  </footer>
</body>
</html>
"@

$verseJsEntries = ''
foreach ($verseNum in ($verses.Keys | Sort-Object {[int]$_})) {
    $escapedHtml = EscapeJsHtml $verses[$verseNum]
    $verseJsEntries += "      ${verseNum}: {
        title: 'Genesis 1:$verseNum',
        html: '$escapedHtml'
      },
"
}

$versePageHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Genesis 1 Verse</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <header class="page-header">
    <h1 id="verse-title">Genesis 1:1</h1>
    <p class="chapter-nav">
      <a href="index.html" class="btn" title="Go to book list">Books</a>
      <a href="gen_ch00.html" class="btn" title="Previous chapter">← Previous</a>
      <a href="gen_ch02.html" class="btn" title="Next chapter">Next →</a>
      <a href="/indexes/strongs-hebrew-index.html" class="btn" title="Browse Strong's Hebrew index">H Index</a>
      <a href="/indexes/strongs-greek-index.html" class="btn" title="Browse Strong's Greek index">G Index</a>
      <a href="/indexes/english-concordance.html" class="btn" title="Browse English concordance">Concordance</a>
    </p>
    <div class="nav">
      <a href="sample-index.html" class="icon-btn" title="Back to sample index" aria-label="Back to sample index" data-icon="🏠">Index</a>
      <a id="chapter-return-link" href="sample-chapter-gen1.html" class="icon-btn chapter-return-btn" title="Back to chapter" aria-label="Back to chapter" data-icon="⛪">Back to chapter</a>
      <a id="note-link" href="#" class="icon-btn note-btn" title="Verse Note" aria-label="Verse Note" data-icon="📝">Verse Note</a>
      <a id="xref-link" href="#" class="icon-btn xref-btn" title="Verse Cross-Reference" aria-label="Verse Cross-Reference" data-icon="🔗">Verse Cross-Reference</a>
    </div>
  </header>
  <main class="chapter-content">
    <article class="verse-block">
      <p class="verse" id="verse-text"></p>
      <p id="verse-description"></p>
      <p class="verse-pagination" id="verse-pagination"></p>
    </article>
  </main>
  <footer class="chapter-footer">
    <p>Last updated: <span class="note-meta">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</span></p>
  </footer>
  <script>
    var verseData = {
$verseJsEntries    };

    function getQueryParam(name) {
      var params = new URLSearchParams(window.location.search);
      return params.get(name);
    }

    function renderVerse() {
      var verse = parseInt(getQueryParam('verse'), 10);
      var data = verseData[verse];
      var pagination = document.getElementById('verse-pagination');
      var chapterReturn = document.getElementById('chapter-return-link');
      if (!data) {
        document.getElementById('verse-title').textContent = 'Verse not found';
        document.getElementById('verse-text').textContent = 'Please select a valid verse from the sample chapter page.';
        document.getElementById('verse-description').textContent = '';
        document.getElementById('note-link').style.display = 'none';
        document.getElementById('xref-link').style.display = 'none';
        chapterReturn.href = 'sample-chapter-gen1.html';
        pagination.textContent = '';
        return;
      }
      document.getElementById('verse-title').textContent = data.title;
      document.getElementById('verse-text').innerHTML = data.html;
      document.getElementById('verse-description').textContent = 'This verse page uses a shared layout and Strong''s links for the selected Genesis 1 verse.';
      document.getElementById('note-link').href = 'sample-note-gen1-' + verse + '.html?source=chapter&verse=' + verse;
      document.getElementById('xref-link').href = 'sample-xref-gen1-' + verse + '.html?source=chapter&verse=' + verse;
      chapterReturn.href = 'sample-chapter-gen1.html#verse-' + verse;
      var previous = verse > 1 ? '<a class="btn" href="sample-verse-gen1.html?source=chapter&verse=' + (verse - 1) + '">← Previous</a>' : '';
      var next = verse < Object.keys(verseData).length ? '<a class="btn" href="sample-verse-gen1.html?source=chapter&verse=' + (verse + 1) + '">Next →</a>' : '';
      pagination.innerHTML = previous + (previous && next ? ' ' : '') + next;
    }

    renderVerse();
  </script>
  <script src="js/navigation.js"></script>
</body>
</html>
"@

$chapterHtml | Set-Content -Path $OutputChapter -Encoding UTF8
$versePageHtml | Set-Content -Path $OutputVersePage -Encoding UTF8

Write-Host "Generated $OutputChapter and $OutputVersePage successfully."
