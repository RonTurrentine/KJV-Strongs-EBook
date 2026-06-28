# KJV Strong's Bible with Concordance
# Copyright (C) 2026 Ron Turrentine
# https://github.com/RonTurrentine/KJV-Strongs-EBook
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# generate_bible.ps1
# Full KJV Bible generator with Strong's links and OSIS cross-references.
# Produces one HTML file per chapter under books/{NN}-{Abbr}/{ch}.html,
# static xref pages under xrefs/, js/bible-data.js, navigate.html, and index.html.
#
# Includes Opus fix for NT verse parsing: <q>, <div>, <lg>, <l> container
# elements are recursively flattened so nested verse milestones are found.
#
# Usage:
#   pwsh -NoProfile -File .\generate_bible.ps1
#   pwsh -NoProfile -File .\generate_bible.ps1 -BookFilter Ruth
#   pwsh -NoProfile -File .\generate_bible.ps1 -BookFilter Matt

param(
    [string]$OsisPath   = 'kjv.osis.xml',
    [string]$OutputRoot = '.',
    [string]$BookFilter = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Master Book Table
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

$BookLookup = @{}
foreach ($b in $BookTable) { $BookLookup[$b.OsisId] = $b }

function Ensure-Dir([string]$path) {
    if (-not (Test-Path $path)) { New-Item -ItemType Directory -Path $path -Force | Out-Null }
}

function Parse-OsisRef([string]$osisRef) {
    $start = ($osisRef -split '-')[0].Trim()
    $parts = $start -split '\.'
    if ($parts.Count -lt 2) { return $null }
    return @{
        Book    = $parts[0]
        Chapter = if ($parts.Count -ge 2) { $parts[1] } else { '1' }
        Verse   = if ($parts.Count -ge 3) { $parts[2] } else { '1' }
    }
}

function Get-ChapterUrl([string]$osisRef) {
    $ref = Parse-OsisRef $osisRef
    if (-not $ref) { return $null }
    $targetBook = $BookLookup[$ref.Book]
    if (-not $targetBook) { return $null }
    $chNum = [int]$ref.Chapter
    $vsNum = [int]$ref.Verse
    return "../books/$($targetBook.Folder)/$chNum.html#verse-$vsNum"
}

function Get-RefLabel([string]$osisRef, [string]$displayText) {
    if ($displayText -and $displayText.Trim()) { return $displayText.Trim() }
    $ref = Parse-OsisRef $osisRef
    if (-not $ref) { return $osisRef }
    $book = $BookLookup[$ref.Book]
    $bookName = if ($book) { $book.FullName } else { $ref.Book }
    return "$bookName $($ref.Chapter):$($ref.Verse)"
}

# OPUS FIX: Recursive node flattener
# Fixes NT verse gaps caused by verse milestones nested inside <q> elements
function Get-FlattenedNodes {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$Parent
    )

    $leafElements = @{
        'verse'       = $true
        'w'           = $true
        'note'        = $true
        'transChange' = $true
        'divineName'  = $true
        'hi'          = $true
        'milestone'   = $true
        'catchWord'   = $true
        'rdg'         = $true
        'seg'         = $true
        'title'       = $true
    }

    $result = [System.Collections.Generic.List[System.Xml.XmlNode]]::new()

    foreach ($child in $Parent.ChildNodes) {
        $nodeType = $child.NodeType

        if ($nodeType -eq [System.Xml.XmlNodeType]::Text -or
            $nodeType -eq [System.Xml.XmlNodeType]::Whitespace -or
            $nodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
            [void]$result.Add($child)
            continue
        }

        if ($nodeType -eq [System.Xml.XmlNodeType]::Element) {
            if ($leafElements.ContainsKey($child.LocalName)) {
                [void]$result.Add($child)
	    } else {
                $nested = [System.Collections.Generic.List[System.Xml.XmlNode]](Get-FlattenedNodes -Parent $child)
                $result.AddRange($nested)
            }
        }
    }

    return $result
}

# OPUS FIX: Updated Strong's link builder
# Word text is wrapped IN the link; handles Hebrew, Greek, and multiple refs

function Get-StrongLinkHtml {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Word,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Lemma,

        [string]$DictRelPath = '../../dict'
    )

    # Skip empty word nodes entirely — no word, no badge
    if (-not $Word) { return '' }

    $wordHtml = [System.Net.WebUtility]::HtmlEncode($Word)

    if (-not $Lemma) { return $wordHtml }

    $matchesFound = [regex]::Matches($Lemma, 'strong:([HG])(\d+)')
    if ($matchesFound.Count -eq 0) { return $wordHtml }

    # Build bracketed badge links after the word text
    $badges = [System.Text.StringBuilder]::new()
    foreach ($m in $matchesFound) {
        $letter   = $m.Groups[1].Value
        $number   = ([int]$m.Groups[2].Value).ToString().PadLeft(4, '0')
        $strongId = "$letter$number"
        $subdir   = if ($letter -eq 'H') { 'hebrew' } else { 'greek' }
        $href     = "$DictRelPath/$subdir/$($strongId.ToLower()).html"
        [void]$badges.Append("<a href=`"$href`" class=`"strongs-link`" title=`"$strongId`">[$strongId]</a>")
    }

    return $wordHtml + ' ' + $badges.ToString()
}

# OPUS FIX: Verse parser using flattened node list
function ConvertTo-VerseHtml {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$ChapterNode,

        [Parameter(Mandatory)]
        [string]$BookFolder,

        [Parameter(Mandatory)]
        [string]$BookName,

        [Parameter(Mandatory)]
        [int]$ChapterNum,

        [string]$DictRelPath = '../../dict'
    )

    $flatNodes       = Get-FlattenedNodes -Parent $ChapterNode
    $verses          = [System.Collections.Generic.List[hashtable]]::new()
    $inVerse         = $false
    $currentVerseNum = 0
    $verseHtml       = [System.Text.StringBuilder]::new()
    $verseXrefs      = [System.Collections.Generic.List[string]]::new()
    $verseWords      = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($node in $flatNodes) {

        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Text) {
            if ($inVerse) {
                $text = $node.Value -replace '[\r\n\t]+', ' ' -replace '  +', ' '
                [void]$verseHtml.Append([System.Net.WebUtility]::HtmlEncode($text))
            }
            continue
        }

        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Whitespace -or
            $node.NodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
            if ($inVerse) { [void]$verseHtml.Append(' ') }
            continue
        }

        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

        $localName = $node.LocalName

        if ($localName -eq 'verse') {
            $sID = $node.GetAttribute('sID')
            $eID = $node.GetAttribute('eID')

            if ($sID) {
                $parts    = $sID.Split('.')
                $verseStr = $parts[$parts.Length - 1]
                if ($verseStr -match '^(\d+)') {
                    $currentVerseNum = [int]$Matches[1]
                    $inVerse         = $true
                    [void]$verseHtml.Clear()
                    $verseXrefs.Clear()
                    $verseWords = [System.Collections.Generic.List[hashtable]]::new()
                } else {
                    $inVerse = $false
                }
            } elseif ($eID) {
                if ($inVerse -and $currentVerseNum -gt 0) {
                    $finalHtml = $verseHtml.ToString().Trim()
                    $finalHtml = [regex]::Replace($finalHtml, '\s+([,;:.!?])', '$1')
                    [void]$verses.Add(@{
                        Num   = $currentVerseNum
                        Html  = $finalHtml
                        Xrefs = @($verseXrefs)
                        Words = @($verseWords)
                    })
                }
                $inVerse = $false
            }
            continue
        }

        if (-not $inVerse) { continue }

        switch ($localName) {
			'w' {
				$word     = $node.InnerText
				$lemma    = $node.GetAttribute('lemma')
				if ($word -or $lemma) {
					$linkHtml = Get-StrongLinkHtml -Word $word -Lemma $lemma -DictRelPath $DictRelPath
					if ($linkHtml) { [void]$verseHtml.Append($linkHtml + ' ') }
				}
				# Concordance word extraction
				if ($lemma -and $word) {
					$sm = [regex]::Matches($lemma, 'strong:([HG])(\d+[a-z]?)')
					foreach ($m in $sm) {
						$letter  = $m.Groups[1].Value.ToUpper()
						$digits  = $m.Groups[2].Value
						# Strip trailing letter, remove ALL leading zeros, re-pad to exactly 4
						$numStr  = ($digits -replace '[a-z]$', '').TrimStart('0')
						if (-not $numStr) { $numStr = '0' }
						$numPart = $numStr.PadLeft(4, '0')
						$sid     = $letter + $numPart
						[void]$verseWords.Add(@{ strongs = $sid; word = $word.Trim() })
					}
				}
			}
			'transChange' {
				$text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
				[void]$verseHtml.Append("<em class=`"added`">$text</em> ")
			}
            'divineName' {
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                [void]$verseHtml.Append("<span class=`"divine-name`">$text</span>")
            }
            'hi' {
                $hiType = $node.GetAttribute('type')
                $text   = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                switch ($hiType) {
                    'italic' { [void]$verseHtml.Append("<em>$text</em>") }
                    'bold'   { [void]$verseHtml.Append("<strong>$text</strong>") }
                    'super'  { [void]$verseHtml.Append("<sup>$text</sup>") }
                    'sub'    { [void]$verseHtml.Append("<sub>$text</sub>") }
                    default  { [void]$verseHtml.Append($text) }
                }
            }
            'title' {
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                [void]$verseHtml.Append("<span class=`"section-title`">$text</span> ")
            }
            'note' {
                $noteType = $node.GetAttribute('type')
                if ($noteType -eq 'crossReference') {
                    foreach ($childNode in $node.ChildNodes) {
                        if ($childNode.NodeType -eq [System.Xml.XmlNodeType]::Element -and
                            $childNode.LocalName -eq 'reference') {
                            $osisRef = $childNode.GetAttribute('osisRef')
                            if ($osisRef) { [void]$verseXrefs.Add($osisRef) }
                        }
                    }
                }
            }
            default {
                $text = $node.InnerText
                if ($text) { [void]$verseHtml.Append([System.Net.WebUtility]::HtmlEncode($text)) }
            }
        }
    }

    if ($inVerse -and $currentVerseNum -gt 0) {
        [void]$verses.Add(@{
            Num   = $currentVerseNum
            Html  = $verseHtml.ToString().Trim()
            Xrefs = @($verseXrefs)
            Words = @($verseWords)
        })
    }

    return $verses
}

# Phase 0: Fetch current GitHub commit SHA (baked into pages for update detection)
Write-Host "Fetching latest commit SHA from GitHub..." -ForegroundColor Cyan
$InstalledSha = ""
try {
    $apiUrl  = "https://api.github.com/repos/RonTurrentine/KJV-Strongs-EBook/commits/main"
    $headers = @{ "User-Agent" = "KJV-Strongs-Generator"; "Accept" = "application/vnd.github.v3+json" }
    $resp    = Invoke-RestMethod -Uri $apiUrl -Headers $headers -TimeoutSec 10
    $InstalledSha = $resp.sha
    Write-Host "  SHA: $($InstalledSha.Substring(0,7))..." -ForegroundColor Green
} catch {
    Write-Host "  Could not fetch SHA (offline?). Update check will be disabled." -ForegroundColor Yellow
    $InstalledSha = ""
}

# Phase 1: Load OSIS XML
Write-Host "Loading OSIS XML from $OsisPath..." -ForegroundColor Cyan
$osis = [xml](Get-Content -Raw -Path $OsisPath)
$ns   = New-Object System.Xml.XmlNamespaceManager($osis.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')
Write-Host "OSIS XML loaded." -ForegroundColor Green

# Phase 2: Build flat chapter list
Write-Host "Building flat chapter list..." -ForegroundColor Cyan
$FlatChapters = [System.Collections.ArrayList]@()

$booksToProcess = $BookTable
if ($BookFilter) {
    $booksToProcess = $BookTable | Where-Object { $_.OsisId -eq $BookFilter }
    if (-not $booksToProcess) { throw "BookFilter '$BookFilter' not found in book table." }
    Write-Host "BookFilter active: processing $BookFilter only." -ForegroundColor Yellow
}

foreach ($book in $booksToProcess) {
    for ($ch = 1; $ch -le $book.Chapters; $ch++) {
        [void]$FlatChapters.Add([pscustomobject]@{
            Book       = $book
            Chapter    = $ch
            OsisChId   = "$($book.OsisId).$ch"
            FolderPath = "books/$($book.Folder)"
        })
    }
}
Write-Host "Flat chapter list built: $($FlatChapters.Count) chapters." -ForegroundColor Green

$VerseCountData = @{}
foreach ($book in $booksToProcess) {
    $VerseCountData[$book.OsisId] = @(0) * $book.Chapters
}

# Pre-compute book array for prev/next book navigation
$allBooks = @($booksToProcess)

Ensure-Dir (Join-Path $OutputRoot 'books')
Ensure-Dir (Join-Path $OutputRoot 'xrefs')
Ensure-Dir (Join-Path $OutputRoot 'js')
Ensure-Dir (Join-Path $OutputRoot 'indexes')

# Phase 3: Generate chapter HTML files and xref pages
Write-Host "Generating chapter pages (with concordance)..." -ForegroundColor Cyan

# Concordance accumulator
$concordance = @{}
$concordanceRefCount = 0

$totalChapters = $FlatChapters.Count
$doneChapters  = 0

foreach ($entry in $FlatChapters) {
    $book     = $entry.Book
    $chNum    = $entry.Chapter
    $osisChId = $entry.OsisChId

    $chapterNode = $osis.SelectSingleNode("//o:chapter[@osisID='$osisChId']", $ns)
    if (-not $chapterNode) {
        Write-Warning "Chapter node not found: $osisChId -- skipping."
        continue
    }

    $verses = ConvertTo-VerseHtml `
        -ChapterNode $chapterNode `
        -BookFolder  $book.Folder `
        -BookName    $book.FullName `
        -ChapterNum  $chNum

    if ($verses.Count -eq 0) {
        Write-Warning "No verses found in $osisChId -- skipping."
        continue
    }

    $VerseCountData[$book.OsisId][$chNum - 1] = $verses.Count

    # Populate concordance from this chapter
    $bookAbbr2   = $book.OsisId
    $bookFolder2 = $book.Folder
    foreach ($v in $verses) {
        if ($v.Words -and $v.Words.Count -gt 0) {
            foreach ($wEntry in $v.Words) {
                $sid = $wEntry.strongs
                $wrd = $wEntry.word
                if (-not $sid -or -not $wrd) { continue }
                if (-not $concordance.ContainsKey($sid)) {
                    $concordance[$sid] = [System.Collections.Generic.List[hashtable]]::new()
                }
                $isDup = $false
                foreach ($ex in $concordance[$sid]) {
                    if ($ex.book -eq $bookAbbr2 -and $ex.ch -eq $chNum -and $ex.vs -eq $v.Num) {
                        $isDup = $true; break
                    }
                }
                if (-not $isDup) {
                    $concordance[$sid].Add(@{
                        book   = $bookAbbr2
                        folder = $bookFolder2
                        ch     = $chNum
                        vs     = $v.Num
                        word   = $wrd
                    })
                    $concordanceRefCount++
                }
            }
        }
    }

    $verseBlocks = [System.Text.StringBuilder]::new()
    foreach ($v in $verses) {
        $verseRef = "$($book.OsisId).$chNum.$($v.Num)"
        $xrefHtml = ''
        if ($v.Xrefs.Count -gt 0) {
            $xrefFile = "$verseRef.html"
            $xrefHtml = "  <a href=`"../../xrefs/$xrefFile`" class=`"superscript-link`" title=`"Cross-references for $($book.FullName) $chNum`:$($v.Num)`">&#x271D;</a>"
        }
        [void]$verseBlocks.Append("
    <p class=`"verse`" id=`"verse-$($v.Num)`">
      <span class=`"verse-num`">$($v.Num)</span>
      <button class=`"note-btn`" onclick=`"openNoteModal('$verseRef')`" title=`"Add note`">&#9998;</button>
      $($v.Html)$xrefHtml
    </p>
    <div class=`"verse-note`" id=`"note-verse-$($v.Num)`"></div>")
    }

    $flatIdx  = $FlatChapters.IndexOf($entry)
    $prevHtml = ''
    $nextHtml = ''

# Prev/Next Chapter buttons
    if ($flatIdx -gt 0) {
        $prev      = $FlatChapters[$flatIdx - 1]
        $prevHref  = if ($prev.Book.OsisId -eq $book.OsisId) { "$($prev.Chapter).html" } else { "../$($prev.Book.Folder)/$($prev.Chapter).html" }
        $prevLabel = "$($prev.Book.FullName) $($prev.Chapter)"
        $prevHtml  = "<a href=`"$prevHref`" class=`"btn`" title=`"$prevLabel`">&#9664;C</a>"
    } else {
        $prevHtml  = "<span class=`"btn btn-disabled`">&#9664;C</span>"
    }

    if ($flatIdx -lt ($FlatChapters.Count - 1)) {
        $next      = $FlatChapters[$flatIdx + 1]
        $nextHref  = if ($next.Book.OsisId -eq $book.OsisId) { "$($next.Chapter).html" } else { "../$($next.Book.Folder)/$($next.Chapter).html" }
        $nextLabel = "$($next.Book.FullName) $($next.Chapter)"
        $nextHtml  = "<a href=`"$nextHref`" class=`"btn`" title=`"$nextLabel`">C&#9654;</a>"
    } else {
        $nextHtml  = "<span class=`"btn btn-disabled`">C&#9654;</span>"
    }

    # Prev/Next Book buttons (always jump to chapter 1 of that book)
    $bookIdx      = -1
    for ($bi = 0; $bi -lt $allBooks.Count; $bi++) {
        if ($allBooks[$bi].OsisId -eq $book.OsisId) { $bookIdx = $bi; break }
    }
    if ($bookIdx -gt 0) {
        $prevBook     = $allBooks[$bookIdx - 1]
        $prevBookHref = "../$($prevBook.Folder)/1.html"
        $prevBookHtml = "<a href=`"$prevBookHref`" class=`"btn`" title=`"$($prevBook.FullName)`">&#9664;B</a>"
    } else {
        $prevBookHtml = "<span class=`"btn btn-disabled`">&#9664;B</span>"
    }

    if ($bookIdx -ge 0 -and $bookIdx -lt ($allBooks.Count - 1)) {
        $nextBook     = $allBooks[$bookIdx + 1]
        $nextBookHref = "../$($nextBook.Folder)/1.html"
        $nextBookHtml = "<a href=`"$nextBookHref`" class=`"btn`" title=`"$($nextBook.FullName)`">B&#9654;</a>"
    } else {
        $nextBookHtml = "<span class=`"btn btn-disabled`">B&#9654;</span>"
    }

    $bookFolder = Join-Path $OutputRoot "books/$($book.Folder)"
    Ensure-Dir $bookFolder

    $chapterHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="kjv-sha" content="$InstalledSha">
  <link rel="icon" type="image/x-icon" href="../../BiblePencil.ico">
  <title>$($book.FullName) $chNum -- KJV</title>
  <link rel="stylesheet" href="../../css/style.css">
</head>
<body class="bible-text">

  <nav class="chapter-nav">
    <h1 class="book-chapter"><span class="update-cross" onclick="openUpdateModal()" title="Update available!"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg></span>$($book.FullName) $chNum <span class="chapter-meta">($($verses.Count) v)</span></h1>
    <div class="nav-buttons">
      <a href="../../index.html" class="btn home-btn" title="Home"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg></a>
      <button class="btn" onclick="history.back()" title="Back">&#9664; Back</button>
      <a href="../../navigate.html#$($book.OsisId)" class="btn">Go To</a>
      $prevBookHtml
      $prevHtml
      $nextHtml
      $nextBookHtml
      <button class="btn hamburger-btn" id="hamburger-btn" onclick="toggleSettingsMenu()" title="Settings">&#9776;</button>
      <span id="unbaked-indicator"></span>
    </div>
  </nav>

  <div class="settings-dropdown" id="settings-dropdown">
    <div class="settings-section">
      <p class="settings-section-label">DISPLAY</p>
      <div class="settings-row settings-font-row">
        <button class="btn settings-font-btn" id="font-decrease" onclick="decreaseFontSize()">a&#8595;</button>
        <span class="settings-row-label">Font size</span>
        <button class="btn settings-font-btn" id="font-increase" onclick="increaseFontSize()">A&#8593;</button>
      </div>
      <div class="settings-row settings-row-clickable" id="strongs-toggle-row" onclick="toggleStrongs()">
        <span class="settings-row-icon">&#128065;</span>
        <span>Strong's links: </span>
        <span id="strongs-state-text">Shown</span>
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" id="sync-kindle-row" onclick="syncToKindle()">
        <span class="settings-row-icon">&#9889;</span>
        Sync to Kindle
      </div>
      <div class="settings-row settings-row-clickable" onclick="rebakeNotes()">
        <span class="settings-row-icon">&#128260;</span>
        Rebake Notes
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" onclick="window.open('../../help.html','_blank')">
        <span class="settings-row-icon">&#10067;</span>
        Help / Documentation
      </div>
      <div class="settings-row settings-row-clickable" onclick="window.open('../../about.html','_blank')">
        <span class="settings-row-icon">&#8505;</span>
        About
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable settings-row-exit" onclick="window.close()">
        <span class="settings-row-icon">&#10005;</span>
        Exit
      </div>
    </div>
  </div>



  <main class="chapter-content">
	$($verseBlocks.ToString())
  </main>

  <footer class="chapter-footer">
    <div class="nav-buttons">
      $prevHtml
      <a href="../../index.html" class="btn home-btn" title="Home"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg></a>
      $nextHtml
    </div>
  </footer>

  <script src="../../js/fontsize.js"></script>
  <script src="../../js/bookmarks.js"></script>
  <script src="../../js/sticky-header.js"></script>
  <script src="../../js/notes.js"></script>

</body>
</html>
"@

    $chapterHtml | Set-Content -Path (Join-Path $bookFolder "$chNum.html") -Encoding UTF8

    foreach ($v in $verses) {
        if ($v.Xrefs.Count -eq 0) { continue }

        $xrefFile = "$($book.OsisId).$chNum.$($v.Num).html"
        $xrefPath = Join-Path $OutputRoot "xrefs/$xrefFile"
        $refItems = [System.Text.StringBuilder]::new()

        foreach ($osisRef in $v.Xrefs) {
            $url   = Get-ChapterUrl $osisRef
            $label = Get-RefLabel $osisRef ''
            if ($url) {
                [void]$refItems.Append("    <li><a href=`"$url`" class=`"xref-link`">$([System.Net.WebUtility]::HtmlEncode($label))</a></li>`n")
            }
        }

        $backUrl   = "../books/$($book.Folder)/$chNum.html#verse-$($v.Num)"
        $pageTitle = "$($book.FullName) $chNum`:$($v.Num)"

        $xrefHtml = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <link rel="icon" type="image/x-icon" href="../../BiblePencil.ico">
  <title>Cross-References: $pageTitle -- KJV</title>
  <link rel="stylesheet" href="../css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1>Cross-References: $pageTitle</h1>
    <div class="nav-buttons">
      <a href="$backUrl" class="btn">&#9664; Back to Verse</a>
      <a href="../index.html" class="btn home-btn" title="Home"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg></a>
    </div>
  </nav>
  <main class="chapter-content">
    <ul class="xref-list">
$($refItems.ToString())    </ul>
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

# Phase 4: Generate js/bible-data.js
Write-Host "Generating js/bible-data.js..." -ForegroundColor Cyan

$jsEntries = [System.Text.StringBuilder]::new()
foreach ($book in $booksToProcess) {
    $counts    = $VerseCountData[$book.OsisId]
    $countsStr = $counts -join ', '
    [void]$jsEntries.Append("  {`n    num: $($book.Num),`n    abbr: `"$($book.OsisId)`",`n    name: `"$($book.FullName)`",`n    folder: `"$($book.Folder)`",`n    chapters: [$countsStr]`n  },`n")
}

"// bible-data.js -- generated by generate_bible.ps1`n// ES3-compatible: var declaration, plain object literals`nvar BIBLE_DATA = [`n$($jsEntries.ToString())];" | Set-Content -Path (Join-Path $OutputRoot 'js/bible-data.js') -Encoding UTF8
Write-Host "js/bible-data.js written." -ForegroundColor Green

# Phase 5: Generate index.html
Write-Host "Generating index.html..." -ForegroundColor Cyan

$otLinks = [System.Text.StringBuilder]::new()
$ntLinks = [System.Text.StringBuilder]::new()
foreach ($book in $BookTable) {
    $link = "  <li><a href=`"books/$($book.Folder)/1.html`">$($book.FullName) <span class=`"chapter-count`">($($book.Chapters) ch)</span></a></li>`n"
    if ($book.Testament -eq 'OT') { [void]$otLinks.Append($link) } else { [void]$ntLinks.Append($link) }
}

@"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="kjv-sha" content="$InstalledSha">
  <link rel="icon" type="image/x-icon" href="BiblePencil.ico">
  <title>KJV Bible with Strong's Concordance</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1><span class="update-cross" onclick="openUpdateModal()" title="Update available!"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg></span>KJV Bible</h1>
    <div class="nav-buttons">
      <a href="indexes/strongs-hebrew-index.html" class="btn">Hebrew</a>
      <a href="indexes/strongs-greek-index.html" class="btn">Greek</a>
      <a href="navigate.html" class="btn">Go To</a>
      <a href="search.html" class="btn" id="search-nav-btn">Search</a>
      <button class="btn hamburger-btn" id="hamburger-btn" onclick="toggleSettingsMenu()" title="Settings">&#9776;</button>
    </div>
  </nav>

  <div class="settings-dropdown" id="settings-dropdown">
    <div class="settings-section">
      <p class="settings-section-label">DISPLAY</p>
      <div class="settings-row settings-font-row">
        <button class="btn settings-font-btn" id="font-decrease" onclick="decreaseFontSize()">a&#8595;</button>
        <span class="settings-row-label">Font size</span>
        <button class="btn settings-font-btn" id="font-increase" onclick="increaseFontSize()">A&#8593;</button>
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" id="sync-kindle-row" onclick="syncToKindle()">
        <span class="settings-row-icon">&#9889;</span>
        Sync to Kindle
      </div>
      <div class="settings-row settings-row-clickable" onclick="rebakeNotes()">
        <span class="settings-row-icon">&#128260;</span>
        Rebake Notes
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" onclick="window.open('help.html','_blank')">
        <span class="settings-row-icon">&#10067;</span>
        Help / Documentation
      </div>
      <div class="settings-row settings-row-clickable" onclick="window.open('about.html','_blank')">
        <span class="settings-row-icon">&#8505;</span>
        About
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable settings-row-exit" onclick="window.close()">
        <span class="settings-row-icon">&#10005;</span>
        Exit
      </div>
    </div>
  </div>

  <main class="chapter-content">
    <div id="bookmark-resume"></div>
    <div class="book-columns">
      <div class="book-col">
        <h2 class="testament-heading">Old Testament</h2>
        <ul class="book-list">
$($otLinks.ToString())        </ul>
      </div>
      <div class="book-col">
        <h2 class="testament-heading">New Testament</h2>
        <ul class="book-list">
$($ntLinks.ToString())        </ul>
      </div>
      <div class="book-col-clear"></div>
    </div>
  </main>
  <script src="js/fontsize.js"></script>
  <script src="js/notes.js"></script>
  <script src="js/sticky-header.js"></script>
  <script src="js/bookmarks.js"></script>
  <script>
  (function () {
      var p = window.location.protocol || "";
      if (p === "file:") {
          var btn = document.getElementById("search-nav-btn");
          if (btn) { btn.style.display = "none"; }
      }
  })();
  </script>
</body>
</html>
"@ | Set-Content -Path (Join-Path $OutputRoot 'index.html') -Encoding UTF8
Write-Host "index.html written." -ForegroundColor Green

# Phase 5b: Copy search.html (static file, no per-page templating needed)
Write-Host "Copying search.html..." -ForegroundColor Cyan
$searchSrc = Join-Path $PSScriptRoot "search.html"
if (Test-Path $searchSrc) {
    $searchDest = Join-Path $OutputRoot 'search.html'
    $searchContent = Get-Content -Path $searchSrc -Raw -Encoding UTF8
    $searchContent = $searchContent -replace 'KJV_SHA_PLACEHOLDER', $InstalledSha
    Set-Content -Path $searchDest -Value $searchContent -Encoding UTF8
    Write-Host "  search.html copied." -ForegroundColor Green
} else {
    Write-Host "  WARNING: scripts/search.html not found - skipping." -ForegroundColor Yellow
}

# Phase 5c: Copy help.html and about.html (static files) — inject SHA
foreach ($staticFile in @('help.html', 'about.html')) {
    $src = Join-Path $PSScriptRoot $staticFile
    if (Test-Path $src) {
        $dest = Join-Path $OutputRoot $staticFile
        $content = Get-Content -Path $src -Raw -Encoding UTF8
        $content = $content -replace 'KJV_SHA_PLACEHOLDER', $InstalledSha
        Set-Content -Path $dest -Value $content -Encoding UTF8
        Write-Host "  $staticFile copied." -ForegroundColor Green
    } else {
        Write-Host "  WARNING: scripts/$staticFile not found - skipping." -ForegroundColor Yellow
    }
}

# Phase 6: Generate navigate.html
Write-Host "Generating navigate.html..." -ForegroundColor Cyan

@'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="dark">
  <meta name="kjv-sha" content="$InstalledSha">
  <link rel="icon" type="image/x-icon" href="BiblePencil.ico">
  <title>Go To -- KJV</title>
  <link rel="stylesheet" href="css/style.css">
</head>
<body class="bible-text">
  <nav class="chapter-nav">
    <h1><span class="update-cross" onclick="openUpdateModal()" title="Update available!"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg></span>Go To</h1>
    <div class="nav-buttons">
      <a href="index.html" class="btn home-btn" title="Home"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg></a>
      <button class="btn" onclick="history.back()" title="Back">&#9664; Back</button>
      <button class="btn hamburger-btn" id="hamburger-btn" onclick="toggleSettingsMenu()" title="Settings">&#9776;</button>
    </div>
  </nav>
  <div class="settings-dropdown" id="settings-dropdown">
    <div class="settings-section">
      <p class="settings-section-label">DISPLAY</p>
      <div class="settings-row settings-font-row">
        <button class="btn settings-font-btn" id="font-decrease" onclick="decreaseFontSize()">a&#8595;</button>
        <span class="settings-row-label">Font size</span>
        <button class="btn settings-font-btn" id="font-increase" onclick="increaseFontSize()">A&#8593;</button>
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" id="sync-kindle-row" onclick="syncToKindle()">
        <span class="settings-row-icon">&#9889;</span>
        Sync to Kindle
      </div>
      <div class="settings-row settings-row-clickable" onclick="rebakeNotes()">
        <span class="settings-row-icon">&#128260;</span>
        Rebake Notes
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" onclick="window.open('help.html','_blank')">
        <span class="settings-row-icon">&#10067;</span>
        Help / Documentation
      </div>
      <div class="settings-row settings-row-clickable" onclick="window.open('about.html','_blank')">
        <span class="settings-row-icon">&#8505;</span>
        About
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable settings-row-exit" onclick="window.close()">
        <span class="settings-row-icon">&#10005;</span>
        Exit
      </div>
    </div>
  </div>
  <main class="chapter-content">
    <div class="navigator-form">
      <label for="book-select">Book:</label>
      <select id="book-select" onchange="onBookChange()" style="width:100%;padding:10px;font-size:18px;margin-bottom:12px;">
        <option value="">-- Select a Book --</option>
      </select>
      <label for="chapter-select">Chapter:</label>
      <select id="chapter-select" onchange="onChapterChange()" disabled="disabled" style="width:100%;padding:10px;font-size:18px;margin-bottom:12px;">
        <option value="">-- Select a Chapter --</option>
      </select>
      <label for="verse-select">Verse:</label>
      <select id="verse-select" disabled="disabled" style="width:100%;padding:10px;font-size:18px;margin-bottom:16px;">
        <option value="any">-- any (top of chapter) --</option>
      </select>
      <button onclick="onGo()" style="width:100%;padding:12px;font-size:20px;">Go</button>
    </div>
  </main>
  <!-- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 -->
  <script src="js/bible-data.js"></script>
  <script src="js/fontsize.js"></script>
  <script src="js/notes.js"></script>
  <script src="js/sticky-header.js"></script>
  <script>
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
    chSel.options.length = 1;
    vsSel.options.length = 1;
    chSel.disabled = true;
    vsSel.disabled = true;
    if (isNaN(idx)) { selectedBookIdx = -1; return; }
    selectedBookIdx = idx;
    var book = BIBLE_DATA[idx];
    var i, opt;
    for (i = 0; i < book.chapters.length; i++) {
      opt = document.createElement('option');
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
    vsSel.options.length = 1;
    vsSel.disabled = true;
    if (isNaN(chNum) || selectedBookIdx < 0) { return; }
    var book       = BIBLE_DATA[selectedBookIdx];
    var verseCount = book.chapters[chNum - 1];
    var i, opt;
    for (i = 1; i <= verseCount; i++) {
      opt = document.createElement('option');
      opt.value = i;
      opt.text  = 'Verse ' + i;
      vsSel.appendChild(opt);
    }
    vsSel.disabled = false;
    if (vsSel.options.length > 1) { vsSel.value = 1; }
  }
  function onGo() {
    var bookSel = document.getElementById('book-select');
    var chSel   = document.getElementById('chapter-select');
    var vsSel   = document.getElementById('verse-select');
    var idx     = parseInt(bookSel.value, 10);
    if (isNaN(idx)) { alert('Please select a book.'); return; }
    var chNum = parseInt(chSel.value, 10);
    if (isNaN(chNum)) { chNum = 1; }
    var book  = BIBLE_DATA[idx];
    var url   = 'books/' + book.folder + '/' + chNum + '.html';
    var vsVal = vsSel.value;
    if (vsVal && vsVal !== 'any') { url += '#verse-' + vsVal; }
    window.location.href = url;
  }
  populateBooks();

  // Auto-select current book from URL hash e.g. navigate.html#Gen
  (function() {
    var hash = window.location.hash.replace('#', '');
    if (!hash) { return; }
    var sel = document.getElementById('book-select');
    var i;
    for (i = 0; i < BIBLE_DATA.length; i++) {
      if (BIBLE_DATA[i].abbr === hash) {
        sel.value = i;
        onBookChange();
        var chSel = document.getElementById('chapter-select');
        if (chSel && chSel.options.length > 1) {
          chSel.value = 1;
          onChapterChange();
        }
        break;
      }
    }
  })();
  </script>
</body>
</html>
'@ | Set-Content -Path (Join-Path $OutputRoot 'navigate.html') -Encoding UTF8
Write-Host "navigate.html written." -ForegroundColor Green

# Write concordance.json
Write-Host ""
Write-Host "=== Writing Concordance Index ===" -ForegroundColor Cyan
$concordancePath = Join-Path $OutputRoot "concordance.json"
$output = @{}
foreach ($key in $concordance.Keys) { $output[$key] = @($concordance[$key]) }
$json = $output | ConvertTo-Json -Depth 4 -Compress
Set-Content -Path $concordancePath -Value $json -Encoding UTF8
Write-Host "  Strong's entries : $($concordance.Keys.Count)" -ForegroundColor Green
Write-Host "  Total references : $concordanceRefCount" -ForegroundColor Green
$gitignorePath = Join-Path $OutputRoot ".gitignore"
$gitignoreContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath -Raw } else { "" }
if ($gitignoreContent -notmatch "concordance") {
    Add-Content -Path $gitignorePath -Value "`nconcordance.json"
}

# Done
Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " generate_bible.ps1 complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Chapters generated : $doneChapters" -ForegroundColor Green
Write-Host " Output root        : $OutputRoot" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Run qa-test.ps1 to verify output"
Write-Host "  2. Check John 3 -- should now have all 36 verses"
Write-Host "  3. Check Matthew 5 (Sermon on the Mount) -- previously had large gaps"
Write-Host "  4. Run verse_gaps.ps1 -- should show zero gaps"
Write-Host "  5. If clean, commit to GitHub"
