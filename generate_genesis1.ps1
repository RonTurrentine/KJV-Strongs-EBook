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
            $strongNum = ([int]$matches[1]).ToString().PadLeft(4, '0')
            $links += '<a href="dict/hebrew/h' + $strongNum + '.html" class="strongs-link" title="View Strong''s Hebrew H' + $strongNum + ' entry">[H' + $strongNum + ']</a>'
        } elseif ($lemma -match '^strong:G(\d+)$') {
            $strongNum = ([int]$matches[1]).ToString().PadLeft(4, '0')
            $links += '<a href="dict/greek/g' + $strongNum + '.html" class="strongs-link" title="View Strong''s Greek G' + $strongNum + ' entry">[G' + $strongNum + ']</a>'
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

function Expand-Template {
    param(
        [string]$template,
        [hashtable]$values
    )

    foreach ($key in $values.Keys) {
        $template = $template.Replace("{{${key}}}", [string]$values[$key])
    }
    return $template
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$chapterTemplatePath = Join-Path $scriptDir 'chapter-template.html'
$verseTemplatePath = Join-Path $scriptDir 'verse-template.html'

if (-not (Test-Path $chapterTemplatePath)) { throw "Missing template file: $chapterTemplatePath" }
if (-not (Test-Path $verseTemplatePath)) { throw "Missing template file: $verseTemplatePath" }

$chapterHtmlTemplate = Get-Content -Raw -Path $chapterTemplatePath
$verseHtmlTemplate = Get-Content -Raw -Path $verseTemplatePath

$chapterBlocks = ''
$chapterBlockTemplate = @'
      <p class="verse" id="verse-{{verseNum}}">
        <a href="sample-verse-gen1.html?source=chapter&verse={{verseNum}}" class="verse-num-link" title="Zoom to verse {{verseNum}}"><span class="verse-num">{{verseNum}}</span></a>
        {{verseText}}
        <a href="sample-note-gen1-{{verseNum}}.html?source=chapter&verse={{verseNum}}" class="superscript-link note-superscript" title="Open personal note for Genesis 1:{{verseNum}}">¹</a>
        <a href="sample-xref-gen1-{{verseNum}}.html?source=chapter&verse={{verseNum}}" class="superscript-link xref-superscript" title="Open cross-references for Genesis 1:{{verseNum}}">✝</a>.
      </p>
'@

foreach ($verseNum in ($verses.Keys | Sort-Object {[int]$_})) {
    $chapterBlocks += Expand-Template -template $chapterBlockTemplate -values @{ verseNum = $verseNum; verseText = $verses[$verseNum] }
}

$lastUpdated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$chapterHtml = Expand-Template -template $chapterHtmlTemplate -values @{ chapterBlocks = $chapterBlocks; lastUpdated = $lastUpdated }

$verseJsEntries = ''
foreach ($verseNum in ($verses.Keys | Sort-Object {[int]$_})) {
    $escapedHtml = EscapeJsHtml $verses[$verseNum]
    $verseJsEntries += "      ${verseNum}: {
        title: 'Genesis 1:${verseNum}',
        html: '$escapedHtml'
      },
"
}

$versePageHtml = $verseHtmlTemplate.Replace('{{verseJsEntries}}', $verseJsEntries).Replace('{{lastUpdated}}', $lastUpdated)

Set-Content -Path $OutputChapter -Value $chapterHtml -Encoding utf8
Set-Content -Path $OutputVersePage -Value $versePageHtml -Encoding utf8

Write-Host "Generated $OutputChapter and $OutputVersePage successfully."
