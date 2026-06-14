# generate_dict.ps1
# Generates one HTML page per Strong's entry for Hebrew and Greek lexicons,
# plus paginated index pages at indexes/strongs-hebrew-index.html and
# indexes/strongs-greek-index.html.
#
# Usage:
#   pwsh -NoProfile -File .\generate_dict.ps1

param(
    [string]$HebrewPath  = 'StrongHebrewG.xml',
    [string]$GreekPath   = 'strongsgreek.xml',
    [string]$OutDir      = 'dict',
    [string]$IndexDir    = 'indexes'
)

# Part of Speech expansion table (Hebrew OSIS morph codes)
$posMap = @{
    'n'         = 'Noun'
    'n-m'       = 'Noun Masculine'
    'n-f'       = 'Noun Feminine'
    'n-c'       = 'Noun Common'
    'n-p'       = 'Noun Proper'
    'n-m-loc'   = 'Noun Masculine Locative'
    'n-pr'      = 'Noun Proper'
    'np'        = 'Noun Proper'
    'n-pr-m'    = 'Noun Proper Masculine'
    'n-pr-f'    = 'Noun Proper Feminine'
    'n-pr-mf'   = 'Noun Proper Masculine/Feminine'
    'n-pr-l'    = 'Noun Proper Location'
    'n-pr-loc'  = 'Noun Proper Location'
    'n-pr-g'    = 'Noun Proper Gentilic'
    'n-pr-d'    = 'Noun Proper Deity'
    'm-pr-f'    = 'Noun Proper Feminine'
    'n-gm'      = 'Noun Gentilic Masculine'
    'n-gf'      = 'Noun Gentilic Feminine'
    'a'         = 'Adjective'
    'a-m'       = 'Adjective Masculine'
    'a-f'       = 'Adjective Feminine'
    'adj'       = 'Adjective'
    'v'         = 'Verb'
    'p'         = 'Pronoun'
    'pron'      = 'Pronoun'
    'dp'        = 'Demonstrative Pronoun'
    'd'         = 'Adverb'
    'adv'       = 'Adverb'
    'x'         = 'Particle'
    'prt'       = 'Particle'
    'c'         = 'Conjunction'
    'conj'      = 'Conjunction'
    'r'         = 'Preposition'
    'prep'      = 'Preposition'
    'loc'       = 'Locative'
    'i'         = 'Interjection'
    'inj'       = 'Interjection'
    'interj'    = 'Interjection'
    't'         = 'Article'
    'infix'     = 'Infix'
    'suffix'    = 'Suffix'
    'prefix'    = 'Prefix'
}

function Expand-POS([string]$code) {
    if (-not $code) { return '' }
    $parts = $code.Trim() -split '\s+'
    $expanded = @()
    foreach ($part in $parts) {
        $lower = $part.ToLower().Trim()
        if ($posMap.ContainsKey($lower)) {
            $expanded += $posMap[$lower]
        } else {
            $expanded += $part
        }
    }
    return $expanded -join ' / '
}

function HtmlEscape([string]$t) {
    return $t -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;' -replace '"','&quot;'
}

function NormalizeText([string]$t) {
    return ($t -replace '\r?\n', ' ' -replace '\s+', ' ').Trim()
}

function Resolve-StrongsRefs {
    param([System.Xml.XmlNode]$node)
    if (-not $node) { return '' }
    $sb = New-Object System.Text.StringBuilder
    foreach ($child in $node.ChildNodes) {
        if ($child.NodeType -eq [System.Xml.XmlNodeType]::Text) {
            [void]$sb.Append($child.Value)
        } elseif ($child.LocalName -eq 'strongsref') {
            $lang   = $child.GetAttribute('language')
            $num    = $child.GetAttribute('strongs')
            $prefix = if ($lang -eq 'HEBREW') { 'H' } else { 'G' }
            [void]$sb.Append("$prefix$([int]$num)")
        } elseif ($child.LocalName -eq 'greek') {
            [void]$sb.Append($child.GetAttribute('unicode'))
        } elseif ($child.LocalName -eq 'pronunciation') {
            [void]$sb.Append($child.GetAttribute('strongs'))
        } else {
            [void]$sb.Append($child.InnerText)
        }
    }
    return $sb.ToString().Trim()
}

function Get-ShortDef([string]$def) {
    $normalized = NormalizeText $def
    if (-not $normalized) { return '' }
    $period = $normalized.IndexOf('.')
    if ($period -gt 0 -and $period -lt 80) {
        return $normalized.Substring(0, $period + 1)
    }
    if ($normalized.Length -le 80) { return $normalized }
    return $normalized.Substring(0, 77) + '...'
}

function Write-DictPage {
    param(
        [string]$FilePath,
        [string]$StrongsId,
        [string]$OriginalWord,
        [string]$Translit,
        [string]$Phonetic,
        [string]$PartOfSpeech,
        [string]$Definition,
        [string]$KjvDef,
        [string]$Origin,
        [string]$Language
    )

    $lang      = $Language.ToLower()
    $cssPath   = '../../css/style.css'
    $idxPath   = '../../indexes/strongs-' + $lang + '-index.html'
    $idxLabel  = $Language + ' Index'
    $titleText = HtmlEscape ($StrongsId + ' - ' + $OriginalWord)
    $origHtml  = HtmlEscape $OriginalWord
    $xlitHtml  = HtmlEscape (NormalizeText $Translit)
    $phonHtml  = HtmlEscape (NormalizeText $Phonetic)
    $posHtml   = HtmlEscape (NormalizeText $PartOfSpeech)
    $defHtml   = HtmlEscape (NormalizeText $Definition)
    $kjvHtml   = HtmlEscape (NormalizeText $KjvDef)
    $orgHtml   = HtmlEscape (NormalizeText $Origin)

    $posRow = if ($posHtml) {
        '          <tr><th>Part of Speech</th><td>' + $posHtml + '</td></tr>'
    } else { '' }

    $originRow = if ($orgHtml) {
        '          <tr><th>Origin</th><td>' + $orgHtml + '</td></tr>'
    } else { '' }

    $kjvBlock = if ($kjvHtml) {
        '<div class="dict-kjv"><p class="dict-label">Strong''s Definition / KJV Usage</p><p>' + $kjvHtml + '</p></div>'
    } else { '' }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$titleText</title>
  <link rel="stylesheet" href="$cssPath">
</head>
<body>
  <div class="dict-page">

    <div class="dict-header">
      <h1 class="dict-strongs-id">$StrongsId</h1>
      <div class="dict-nav">
        <a href="javascript:history.back()" class="btn">Back</a>
        <a href="$idxPath" class="btn">$idxLabel</a>
      </div>
    </div>

    <div class="dict-body">

      <p class="dict-original" lang="$lang">$origHtml</p>

      <table class="dict-table">
        <tbody>
          <tr><th>Transliteration</th><td>$xlitHtml</td></tr>
          <tr><th>Phonetic</th><td>$phonHtml</td></tr>
$posRow
$originRow
        </tbody>
      </table>

      <div class="dict-def">
        <p class="dict-label">Definition</p>
        <p>$defHtml</p>
      </div>

$kjvBlock

    </div>

    <div class="dict-footer">
      <a href="javascript:history.back()" class="btn">Back</a>
    </div>

  </div>
</body>
</html>
"@

    $dir = Split-Path $FilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $absolutePath = [System.IO.Path]::GetFullPath($FilePath)
    [System.IO.File]::WriteAllText($absolutePath, $html, [System.Text.Encoding]::UTF8)
}

function Write-IndexPage {
    param(
        [string]$FilePath,
        [string]$Language,
        [System.Collections.Generic.List[hashtable]]$Entries
    )

    $lang     = $Language.ToLower()
    $prefix   = if ($lang -eq 'hebrew') { 'H' } else { 'G' }
    $cssPath  = '../css/style.css'
    $title    = "Strong's $Language Lexicon Index"
    $titleEsc = HtmlEscape $title
    $total    = $Entries.Count

    # Build JSON data array embedded in page for JS pagination
    # Each entry: ["H0001", "original", "translit", "short def", "filename"]
    $jsonSb = New-Object System.Text.StringBuilder
    [void]$jsonSb.Append("var INDEX_DATA = [")
    $first = $true
    foreach ($entry in $Entries) {
        $paddedId = $prefix + $entry.Num.ToString().PadLeft(4, '0')
        $orig  = ($entry.Original -replace '\\','\\\\' -replace '"','\"' -replace "`r`n",' ' -replace "`n",' ')
        $xlit  = ($entry.Translit -replace '\\','\\\\' -replace '"','\"')
        $def   = ($entry.ShortDef -replace '\\','\\\\' -replace '"','\"')
        $file  = $entry.Filename
        if (-not $first) { [void]$jsonSb.Append(",") }
        [void]$jsonSb.Append("[`"$paddedId`",`"$orig`",`"$xlit`",`"$def`",`"$file`"]")
        $first = $false
    }
    [void]$jsonSb.Append("];")
    $jsonData = $jsonSb.ToString()

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>$titleEsc</title>
  <link rel="stylesheet" href="$cssPath">
</head>
<body>
  <nav class="chapter-nav">
    <h1 class="book-chapter">$titleEsc</h1>
    <div class="nav-buttons">
      <a href="../index.html" class="btn">Books</a>
    </div>
  </nav>
  <main class="chapter-content">

    <div class="index-controls">
      <span class="index-status" id="index-status">Loading...</span>
      <span class="index-perpage-label">Show:</span>
      <button class="btn" id="pp-50"  onclick="setPerPage(50)">50</button>
      <button class="btn" id="pp-100" onclick="setPerPage(100)">100</button>
      <button class="btn" id="pp-200" onclick="setPerPage(200)">200</button>
      <button class="btn" id="pp-all" onclick="setPerPage(0)">All</button>
    </div>

    <div class="index-nav" id="index-nav-top"></div>

    <table class="dict-index-table">
      <thead>
        <tr>
          <th>Number</th>
          <th>Word</th>
          <th>Transliteration</th>
          <th>Definition</th>
        </tr>
      </thead>
      <tbody id="index-body">
      </tbody>
    </table>

    <div class="index-nav" id="index-nav-bottom"></div>

  </main>

<script>
$jsonData
var LANG = "$lang";
var TOTAL = $total;
var perPage = 100;
var currentPage = 1;

function setPerPage(n) {
  perPage = n;
  currentPage = 1;
  render();
}

function goPage(n) {
  currentPage = n;
  render();
  window.scrollTo(0, 0);
}

function totalPages() {
  if (perPage === 0) { return 1; }
  return Math.ceil(TOTAL / perPage);
}

function renderNav(id) {
  var el = document.getElementById(id);
  if (perPage === 0 || totalPages() <= 1) { el.innerHTML = ""; return; }
  var tp = totalPages();
  var html = "";
  if (currentPage > 1) {
    html += "<button class=\"btn\" onclick=\"goPage(" + (currentPage - 1) + ")\">&laquo; Prev</button> ";
  }
  var pageStart = Math.max(1, currentPage - 3);
  var pageEnd   = Math.min(tp, currentPage + 3);
  var p;
  for (p = pageStart; p <= pageEnd; p++) {
    if (p === currentPage) {
      html += "<button class=\"btn btn-active\" disabled>" + p + "</button> ";
    } else {
      html += "<button class=\"btn\" onclick=\"goPage(" + p + ")\">" + p + "</button> ";
    }
  }
  if (currentPage < tp) {
    html += " <button class=\"btn\" onclick=\"goPage(" + (currentPage + 1) + ")\">Next &raquo;</button>";
  }
  el.innerHTML = html;
}

function updatePerPageButtons() {
  var ids  = ["pp-50","pp-100","pp-200","pp-all"];
  var vals = [50, 100, 200, 0];
  var i, el;
  for (i = 0; i < ids.length; i++) {
    el = document.getElementById(ids[i]);
    if (el) {
      if (vals[i] === perPage) {
        if (el.className.indexOf("btn-active") === -1) {
          el.className = el.className + " btn-active";
        }
      } else {
        el.className = el.className.replace(" btn-active", "");
      }
    }
  }
}

function render() {
  var start = (perPage === 0) ? 0 : (currentPage - 1) * perPage;
  var end   = (perPage === 0) ? TOTAL : Math.min(start + perPage, TOTAL);
  var tbody = document.getElementById("index-body");
  var rows  = [];
  var i, entry, href, row;
  for (i = start; i < end; i++) {
    entry = INDEX_DATA[i];
    href  = "../dict/" + LANG + "/" + entry[4] + ".html";
    row   = "<tr>";
    row  += "<td><a href=\"" + href + "\" class=\"dict-index-link\">" + entry[0] + "</a></td>";
    row  += "<td class=\"dict-index-orig\" lang=\"" + LANG + "\">" + entry[1] + "</td>";
    row  += "<td class=\"dict-index-xlit\">" + entry[2] + "</td>";
    row  += "<td class=\"dict-index-def\">"  + entry[3] + "</td>";
    row  += "</tr>";
    rows.push(row);
  }
  tbody.innerHTML = rows.join("");

  var showing = (perPage === 0)
    ? "All " + TOTAL + " entries"
    : "Showing " + (start + 1) + "-" + end + " of " + TOTAL;
  document.getElementById("index-status").innerHTML = showing;

  renderNav("index-nav-top");
  renderNav("index-nav-bottom");
  updatePerPageButtons();
}

render();
</script>

  <script src="../js/sticky-header.js"></script>
</body>
</html>
"@

    $dir = Split-Path $FilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $absolutePath = [System.IO.Path]::GetFullPath($FilePath)
    [System.IO.File]::WriteAllText($absolutePath, $html, [System.Text.Encoding]::UTF8)
}

# ── Hebrew ──────────────────────────────────────────────────────────────────

Write-Host "Loading Hebrew lexicon from $HebrewPath..."
$heb = [xml](Get-Content -Raw -Path $HebrewPath)
$ns  = New-Object System.Xml.XmlNamespaceManager($heb.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

$entries = $heb.SelectNodes('//o:div[@type="entry"]', $ns)
Write-Host "Found $($entries.Count) Hebrew entries."

$count           = 0
$hebIndexEntries = [System.Collections.Generic.List[hashtable]]::new()

foreach ($entry in $entries) {
    $w = $entry.SelectSingleNode('o:w', $ns)
    if (-not $w) { continue }

    $rawId = $w.GetAttribute('ID')
    if ($rawId -notmatch '^H(\d+)$') { continue }
    $num    = [int]$matches[1]
    $padded = 'h' + $num.ToString().PadLeft(4, '0')

    $origWord = $w.GetAttribute('lemma')
    if (-not $origWord) { $origWord = $w.InnerText.Trim() }

    $xlit  = $w.GetAttribute('xlit')
    $phon  = $w.GetAttribute('POS')
    $morph = Expand-POS $w.GetAttribute('morph')

    $defNode = $entry.SelectSingleNode('o:note[@type="explanation"]', $ns)
    $def     = if ($defNode) { $defNode.InnerText.Trim() } else { '' }

    $kjvNode = $entry.SelectSingleNode('o:note[@type="translation"]', $ns)
    $kjv     = if ($kjvNode) { $kjvNode.InnerText.Trim() } else { '' }

    $srcNode = $entry.SelectSingleNode('o:w[@src]', $ns)
    $origin  = if ($srcNode) { 'See H' + ($srcNode.GetAttribute('src') -replace 'H', '') } else { '' }

    $outPath = Join-Path $OutDir "hebrew\$padded.html"
    Write-DictPage `
        -FilePath     $outPath `
        -StrongsId    "H$num" `
        -OriginalWord $origWord `
        -Translit     $xlit `
        -Phonetic     $phon `
        -PartOfSpeech $morph `
        -Definition   $def `
        -KjvDef       $kjv `
        -Origin       $origin `
        -Language     'Hebrew'

    $shortDef = if ($def) { Get-ShortDef $def } elseif ($kjv) { Get-ShortDef $kjv } else { '' }
    [void]$hebIndexEntries.Add(@{
        Num      = $num
        Original = $origWord
        Translit = $xlit
        ShortDef = $shortDef
        Filename = $padded
    })

    $count++
    if ($count % 500 -eq 0) { Write-Host "  Hebrew: $count entries written..." }
}
Write-Host "Hebrew done - $count pages written."

$hebIndexEntries = $hebIndexEntries | Sort-Object { $_.Num }
Write-Host "Writing Hebrew index ($($hebIndexEntries.Count) entries)..."
$hebIdxPath = Join-Path $IndexDir 'strongs-hebrew-index.html'
Write-IndexPage -FilePath $hebIdxPath -Language 'Hebrew' -Entries $hebIndexEntries
Write-Host "Hebrew index written."

# ── Greek ────────────────────────────────────────────────────────────────────

Write-Host "Loading Greek lexicon from $GreekPath..."
$grk      = [xml](Get-Content -Raw -Path $GreekPath)
$gEntries = $grk.SelectNodes('//entry')
Write-Host "Found $($gEntries.Count) Greek entries."

$count           = 0
$grkIndexEntries = [System.Collections.Generic.List[hashtable]]::new()

foreach ($entry in $gEntries) {
    $strNum = $entry.GetAttribute('strongs')
    if (-not $strNum) { continue }
    $num    = [int]$strNum
    $padded = 'g' + $num.ToString().PadLeft(4, '0')

    $grkNode  = $entry.SelectSingleNode('greek')
    $origWord = if ($grkNode) { $grkNode.GetAttribute('unicode') } else { '' }
    $xlit     = if ($grkNode) { $grkNode.GetAttribute('translit') } else { '' }

    $pronNode = $entry.SelectSingleNode('pronunciation')
    $phon     = if ($pronNode) { $pronNode.GetAttribute('strongs') } else { '' }

    $derivNode = $entry.SelectSingleNode('strongs_derivation')
    $origin    = if ($derivNode) { Resolve-StrongsRefs $derivNode } else { '' }

    $defNode = $entry.SelectSingleNode('strongs_def')
    $def     = if ($defNode) { Resolve-StrongsRefs $defNode } else { '' }

    $kjvNode = $entry.SelectSingleNode('kjv_def')
    $kjv     = if ($kjvNode) { Resolve-StrongsRefs $kjvNode } else { '' }
    $kjv     = $kjv -replace '^\s*:--\s*', ''

    $outPath = Join-Path $OutDir "greek\$padded.html"
    Write-DictPage `
        -FilePath     $outPath `
        -StrongsId    "G$num" `
        -OriginalWord $origWord `
        -Translit     $xlit `
        -Phonetic     $phon `
        -PartOfSpeech '' `
        -Definition   $def `
        -KjvDef       $kjv `
        -Origin       $origin `
        -Language     'Greek'

    $shortDef = if ($def) { Get-ShortDef $def } elseif ($kjv) { Get-ShortDef $kjv } else { '' }
    [void]$grkIndexEntries.Add(@{
        Num      = $num
        Original = $origWord
        Translit = $xlit
        ShortDef = $shortDef
        Filename = $padded
    })

    $count++
    if ($count % 500 -eq 0) { Write-Host "  Greek: $count entries written..." }
}
Write-Host "Greek done - $count pages written."

$grkIndexEntries = $grkIndexEntries | Sort-Object { $_.Num }
Write-Host "Writing Greek index ($($grkIndexEntries.Count) entries)..."
$grkIdxPath = Join-Path $IndexDir 'strongs-greek-index.html'
Write-IndexPage -FilePath $grkIdxPath -Language 'Greek' -Entries $grkIndexEntries
Write-Host "Greek index written."

Write-Host "Dictionary generation complete."
