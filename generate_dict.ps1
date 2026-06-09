param(
    [string]$HebrewPath  = 'StrongHebrewG.xml',
    [string]$GreekPath   = 'strongsgreek.xml',
    [string]$OutDir      = 'dict'
)

# Part of Speech expansion table (Hebrew OSIS morph codes)

$posMap = @{
    # Common nouns
    'n'         = 'Noun'
    'n-m'       = 'Noun Masculine'
    'n-f'       = 'Noun Feminine'
    'n-c'       = 'Noun Common'
    'n-p'       = 'Noun Proper'
    'n-m-loc'   = 'Noun Masculine Locative'
    # Proper nouns
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
    # Gentilic nouns
    'n-gm'      = 'Noun Gentilic Masculine'
    'n-gf'      = 'Noun Gentilic Feminine'
    # Adjectives
    'a'         = 'Adjective'
    'a-m'       = 'Adjective Masculine'
    'a-f'       = 'Adjective Feminine'
    'adj'       = 'Adjective'
    # Verbs
    'v'         = 'Verb'
    # Pronouns
    'p'         = 'Pronoun'
    'pron'      = 'Pronoun'
    'dp'        = 'Demonstrative Pronoun'
    # Adverbs
    'd'         = 'Adverb'
    'adv'       = 'Adverb'
    # Particles and conjunctions
    'x'         = 'Particle'
    'prt'       = 'Particle'
    'c'         = 'Conjunction'
    'conj'      = 'Conjunction'
    # Prepositions
    'r'         = 'Preposition'
    'prep'      = 'Preposition'
    # Locative
    'loc'       = 'Locative'
    # Interjections
    'i'         = 'Interjection'
    'inj'       = 'Interjection'
    'interj'    = 'Interjection'
    # Articles and affixes
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

    $lang     = $Language.ToLower()
    $cssPath  = '../../css/style.css'
    $idxPath  = '../../indexes/strongs-' + $lang + '-index.html'
    $idxLabel = $Language + ' Index'

    # Build title safely without em dash to avoid parser issues
    $titleText = HtmlEscape ($StrongsId + ' - ' + $OriginalWord)
    $origHtml  = HtmlEscape $OriginalWord
    $xlitHtml  = HtmlEscape (NormalizeText $Translit)
    $phonHtml  = HtmlEscape (NormalizeText $Phonetic)
    $posHtml   = HtmlEscape (NormalizeText $PartOfSpeech)
    $defHtml   = HtmlEscape (NormalizeText $Definition)
    $kjvHtml   = HtmlEscape (NormalizeText $KjvDef)
    $orgHtml   = HtmlEscape (NormalizeText $Origin)

    $posRow = if ($posHtml) {
        '      <tr><th>Part of Speech</th><td>' + $posHtml + '</td></tr>'
    } else { '' }

    $originRow = if ($orgHtml) {
        '      <tr><th>Origin</th><td>' + $orgHtml + '</td></tr>'
    } else { '' }

    $kjvBlock = if ($kjvHtml) {
        '<div class="strongs-kjv"><p class="note-title"><strong>Strong''s Definition / KJV Usage</strong></p><p>' + $kjvHtml + '</p></div>'
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
<body class="bible-text">
<header class="page-header">
  <h1 class="strongs-entry-id">$StrongsId</h1>
  <p class="chapter-nav">
    <a href="javascript:history.back()" class="btn" title="Go back">Back</a>
    <a href="$idxPath" class="btn" title="Browse $Language index">$idxLabel</a>
  </p>
</header>
<main class="chapter-content">
  <article class="verse-block strongs-entry">
    <p class="strongs-original" lang="$lang">$origHtml</p>
    <table class="strongs-table">
      <tr><th>Transliteration</th><td>$xlitHtml</td></tr>
      <tr><th>Phonetic</th><td>$phonHtml</td></tr>
$posRow
$originRow
    </table>
    <div class="strongs-def">
      <p class="note-title"><strong>Definition</strong></p>
      <p>$defHtml</p>
    </div>
$kjvBlock
  </article>
</main>
<footer class="chapter-footer">
  <p>Strong's $Language Lexicon - $StrongsId</p>
</footer>
</body>
</html>
"@
    $dir = Split-Path $FilePath
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($FilePath, $html, [System.Text.Encoding]::UTF8)
}

# Hebrew

Write-Host "Loading Hebrew lexicon from $HebrewPath..."
$heb = [xml](Get-Content -Raw -Path $HebrewPath)
$ns  = New-Object System.Xml.XmlNamespaceManager($heb.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

$entries = $heb.SelectNodes('//o:div[@type="entry"]', $ns)
Write-Host "Found $($entries.Count) Hebrew entries."

$count = 0
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

    $count++
    if ($count % 500 -eq 0) { Write-Host "  Hebrew: $count entries written..." }
}
Write-Host "Hebrew done - $count pages written."

# Greek

Write-Host "Loading Greek lexicon from $GreekPath..."
$grk      = [xml](Get-Content -Raw -Path $GreekPath)
$gEntries = $grk.SelectNodes('//entry')
Write-Host "Found $($gEntries.Count) Greek entries."

$count = 0
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

    $count++
    if ($count % 500 -eq 0) { Write-Host "  Greek: $count entries written..." }
}
Write-Host "Greek done - $count pages written."
Write-Host "Dictionary generation complete."
