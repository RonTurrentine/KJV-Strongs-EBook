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
    [string]$IndexDir    = 'indexes',
    [string]$StatusFile  = ''
)

# Helper: write progress to status file if provided (used by Update Now)
function Write-DictStatus {
    param([int]$Percent, [string]$Detail)
    if ($StatusFile -and (Test-Path (Split-Path $StatusFile -Parent))) {
        try {
            $s = @{ step='dict'; percent=$Percent; detail=$Detail; done=$false; error=$false; ts=(Get-Date).ToString('o') }
            $s | ConvertTo-Json -Compress | Set-Content -Path $StatusFile -Encoding UTF8
        } catch { }
    }
}

# Load Concordance Index
$ConcordancePath = Join-Path $PSScriptRoot "..\concordance.json"

# Fetch current GitHub commit SHA (baked into pages for update detection)
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

$ConcordanceData = @{}
if (Test-Path $ConcordancePath) {
    Write-Host "Loading concordance index..." -ForegroundColor Cyan
    $raw = Get-Content -Path $ConcordancePath -Raw -Encoding UTF8
    $parsed = $raw | ConvertFrom-Json
    $parsed.PSObject.Properties | ForEach-Object {
        $refs = @()
        foreach ($r in $_.Value) {
            $refs += @{ book=$r.book; folder=$r.folder; ch=[int]$r.ch; vs=[int]$r.vs; word=$r.word }
        }
        $ConcordanceData[$_.Name] = $refs
    }
    Write-Host "  Loaded $($ConcordanceData.Keys.Count) Strong's entries" -ForegroundColor Green
} else {
    Write-Host "WARNING: concordance.json not found. Run generate_bible.ps1 first." -ForegroundColor Yellow
}

# ── Load BDB/Thayer Lexicon ─────────────────────────────────────
$BdbPath = Join-Path (Get-Location) "bdb-thayer.json"
if (-not (Test-Path $BdbPath) -and $PSScriptRoot) {
    $BdbPath = Join-Path $PSScriptRoot "..db-thayer.json"
}
$BdbData = @{}
if (Test-Path $BdbPath) {
    Write-Host "Loading BDB/Thayer lexicon..." -ForegroundColor Cyan
    $bdbRaw = [System.IO.File]::ReadAllText($BdbPath, [System.Text.Encoding]::UTF8)
    # Use System.Text.Json (built into .NET 5+, available in PowerShell 7)
    $jsonDoc = [System.Text.Json.JsonDocument]::Parse($bdbRaw)
    foreach ($element in $jsonDoc.RootElement.EnumerateArray()) {
        $w = $element.GetProperty("word").GetString()
        $d = $element.GetProperty("data").GetString()
        $BdbData[$w] = $d
    }
    $jsonDoc.Dispose()
    Write-Host "  Loaded $($BdbData.Keys.Count) BDB/Thayer entries" -ForegroundColor Green
} else {
    Write-Host "WARNING: bdb-thayer.json not found. Run scripts/export-bdb.ps1 first." -ForegroundColor Yellow
}

function Convert-BdbLinks {
    param([string]$Html)
    return [System.Text.RegularExpressions.Regex]::Replace(
        $Html,
        "<a class='dict' href='#d([HG])(\d+)'>([^<]+)</a>",
        {
            param($m)
            $prefix  = $m.Groups[1].Value
            $num     = [int]$m.Groups[2].Value
            $lang2   = if ($prefix -eq 'H') { 'hebrew' } else { 'greek' }
            $padded  = $prefix.ToLower() + $num.ToString().PadLeft(4, '0')
            $paddedDisplay = $prefix + $num.ToString().PadLeft(4, '0')
            $href    = "../../dict/$lang2/$padded.html"
            return "<a href=`"$href`" class=`"strongs-link`">$paddedDisplay</a>"
        }
    )
}

function Get-BdbHtml {
    param([string]$StrongsId)
    $unpaddedId = $StrongsId -replace '^([HG])0+', '$1'
    if (-not $BdbData.ContainsKey($unpaddedId)) { return '' }
    $raw = Convert-BdbLinks -Html $BdbData[$unpaddedId]
    return "<div class=`"dict-bdb`"><p class=`"dict-label`">BDB / Thayer Definition</p>$raw</div>"
}

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

function Format-ConcordanceLink {
    param(
        [string]$Abbr,       # Book abbreviation (e.g. "Gen")
        [string]$Folder,     # Book folder (e.g. "01-Gen")
        $Ref                 # Reference object with ch, vs, word
    )
    
    $ch = if ($Ref -is [hashtable]) { $Ref.ch } else { $Ref.ch }
    $vs = if ($Ref -is [hashtable]) { $Ref.vs } else { $Ref.vs }
    $href = "../../books/$Folder/$ch.html#verse-$vs"
    
    # Build word display
    $wordHtml = ""
    $rawWord = if ($Ref -is [hashtable]) { $Ref.word } else { $Ref.word }
    if ($rawWord) {
        $w = [string]$rawWord
        if ($w.Length -gt 15) {
            $w = $w.Substring(0, 14) + [char]0x2026  # ellipsis
        }
        $w = $w -replace "&", "&amp;"
        $w = $w -replace "<", "&lt;"
        $w = $w -replace ">", "&gt;"
        $wordHtml = " <span class=`"conc-word`">&ldquo;$w&rdquo;</span>"
    }
    
    return "      <a href=`"$href`" class=`"conc-link`">$Abbr $ch`:$vs$wordHtml</a>"
}


# Book canonical order for display (same table as generate_bible.ps1)
$BookDisplayOrder = @(
    @{ Abbr = "Gen";    Name = "Genesis";         Folder = "01-Gen" }
    @{ Abbr = "Exod";   Name = "Exodus";          Folder = "02-Exod" }
    @{ Abbr = "Lev";    Name = "Leviticus";       Folder = "03-Lev" }
    @{ Abbr = "Num";    Name = "Numbers";         Folder = "04-Num" }
    @{ Abbr = "Deut";   Name = "Deuteronomy";     Folder = "05-Deut" }
    @{ Abbr = "Josh";   Name = "Joshua";          Folder = "06-Josh" }
    @{ Abbr = "Judg";   Name = "Judges";          Folder = "07-Judg" }
    @{ Abbr = "Ruth";   Name = "Ruth";            Folder = "08-Ruth" }
    @{ Abbr = "1Sam";   Name = "1 Samuel";        Folder = "09-1Sam" }
    @{ Abbr = "2Sam";   Name = "2 Samuel";        Folder = "10-2Sam" }
    @{ Abbr = "1Kgs";   Name = "1 Kings";         Folder = "11-1Kgs" }
    @{ Abbr = "2Kgs";   Name = "2 Kings";         Folder = "12-2Kgs" }
    @{ Abbr = "1Chr";   Name = "1 Chronicles";    Folder = "13-1Chr" }
    @{ Abbr = "2Chr";   Name = "2 Chronicles";    Folder = "14-2Chr" }
    @{ Abbr = "Ezra";   Name = "Ezra";            Folder = "15-Ezra" }
    @{ Abbr = "Neh";    Name = "Nehemiah";        Folder = "16-Neh" }
    @{ Abbr = "Esth";   Name = "Esther";          Folder = "17-Esth" }
    @{ Abbr = "Job";    Name = "Job";             Folder = "18-Job" }
    @{ Abbr = "Ps";     Name = "Psalms";          Folder = "19-Ps" }
    @{ Abbr = "Prov";   Name = "Proverbs";        Folder = "20-Prov" }
    @{ Abbr = "Eccl";   Name = "Ecclesiastes";    Folder = "21-Eccl" }
    @{ Abbr = "Song";   Name = "Song of Solomon"; Folder = "22-Song" }
    @{ Abbr = "Isa";    Name = "Isaiah";          Folder = "23-Isa" }
    @{ Abbr = "Jer";    Name = "Jeremiah";        Folder = "24-Jer" }
    @{ Abbr = "Lam";    Name = "Lamentations";    Folder = "25-Lam" }
    @{ Abbr = "Ezek";   Name = "Ezekiel";         Folder = "26-Ezek" }
    @{ Abbr = "Dan";    Name = "Daniel";           Folder = "27-Dan" }
    @{ Abbr = "Hos";    Name = "Hosea";            Folder = "28-Hos" }
    @{ Abbr = "Joel";   Name = "Joel";             Folder = "29-Joel" }
    @{ Abbr = "Amos";   Name = "Amos";             Folder = "30-Amos" }
    @{ Abbr = "Obad";   Name = "Obadiah";          Folder = "31-Obad" }
    @{ Abbr = "Jonah";  Name = "Jonah";            Folder = "32-Jonah" }
    @{ Abbr = "Mic";    Name = "Micah";            Folder = "33-Mic" }
    @{ Abbr = "Nah";    Name = "Nahum";            Folder = "34-Nah" }
    @{ Abbr = "Hab";    Name = "Habakkuk";         Folder = "35-Hab" }
    @{ Abbr = "Zeph";   Name = "Zephaniah";        Folder = "36-Zeph" }
    @{ Abbr = "Hag";    Name = "Haggai";           Folder = "37-Hag" }
    @{ Abbr = "Zech";   Name = "Zechariah";        Folder = "38-Zech" }
    @{ Abbr = "Mal";    Name = "Malachi";           Folder = "39-Mal" }
    @{ Abbr = "Matt";   Name = "Matthew";           Folder = "40-Matt" }
    @{ Abbr = "Mark";   Name = "Mark";              Folder = "41-Mark" }
    @{ Abbr = "Luke";   Name = "Luke";              Folder = "42-Luke" }
    @{ Abbr = "John";   Name = "John";              Folder = "43-John" }
    @{ Abbr = "Acts";   Name = "Acts";              Folder = "44-Acts" }
    @{ Abbr = "Rom";    Name = "Romans";             Folder = "45-Rom" }
    @{ Abbr = "1Cor";   Name = "1 Corinthians";     Folder = "46-1Cor" }
    @{ Abbr = "2Cor";   Name = "2 Corinthians";     Folder = "47-2Cor" }
    @{ Abbr = "Gal";    Name = "Galatians";          Folder = "48-Gal" }
    @{ Abbr = "Eph";    Name = "Ephesians";          Folder = "49-Eph" }
    @{ Abbr = "Phil";   Name = "Philippians";        Folder = "50-Phil" }
    @{ Abbr = "Col";    Name = "Colossians";         Folder = "51-Col" }
    @{ Abbr = "1Thess"; Name = "1 Thessalonians";   Folder = "52-1Thess" }
    @{ Abbr = "2Thess"; Name = "2 Thessalonians";   Folder = "53-2Thess" }
    @{ Abbr = "1Tim";   Name = "1 Timothy";          Folder = "54-1Tim" }
    @{ Abbr = "2Tim";   Name = "2 Timothy";          Folder = "55-2Tim" }
    @{ Abbr = "Titus";  Name = "Titus";              Folder = "56-Titus" }
    @{ Abbr = "Phlm";   Name = "Philemon";           Folder = "57-Phlm" }
    @{ Abbr = "Heb";    Name = "Hebrews";            Folder = "58-Heb" }
    @{ Abbr = "Jas";    Name = "James";              Folder = "59-Jas" }
    @{ Abbr = "1Pet";   Name = "1 Peter";            Folder = "60-1Pet" }
    @{ Abbr = "2Pet";   Name = "2 Peter";            Folder = "61-2Pet" }
    @{ Abbr = "1John";  Name = "1 John";             Folder = "62-1John" }
    @{ Abbr = "2John";  Name = "2 John";             Folder = "63-2John" }
    @{ Abbr = "3John";  Name = "3 John";             Folder = "64-3John" }
    @{ Abbr = "Jude";   Name = "Jude";               Folder = "65-Jude" }
    @{ Abbr = "Rev";    Name = "Revelation";         Folder = "66-Rev" }
)

$PAGE_SIZE = 50
$SMALL_THRESHOLD = 20


function Get-ConcordanceHtml {
    param(
        [Parameter(Mandatory)]
        [string]$StrongsId        # e.g. "H0430" or "G3056"
    )

    # Look up in concordance data
    if (-not $ConcordanceData.ContainsKey($StrongsId)) {
        return ""  # No occurrences found
    }

    $allRefs = $ConcordanceData[$StrongsId]
    if ($allRefs.Count -eq 0) { return "" }

    # Determine testament for heading
    $letter = $StrongsId.Substring(0, 1)
    $testament = if ($letter -eq "H") { "Old Testament" } else { "New Testament" }
    $totalCount = $allRefs.Count

    # Group references by book (preserving canonical order)
    $bookGroups = [ordered]@{}
    foreach ($ref in $allRefs) {
        $bookAbbr = if ($ref -is [hashtable]) { $ref.book } else { $ref.book }
        if (-not $bookGroups.Contains($bookAbbr)) {
            $bookGroups[$bookAbbr] = [System.Collections.Generic.List[object]]::new()
        }
        $bookGroups[$bookAbbr].Add($ref)
    }

    # Build HTML
    $html = [System.Text.StringBuilder]::new()

    [void]$html.AppendLine("")
    [void]$html.AppendLine('<div class="conc-section">')
    [void]$html.AppendLine("  <h2 class=`"conc-heading`">Occurrences in $testament <span class=`"conc-total`">($totalCount total)</span></h2>")

    $bookIdx = 0

    # Iterate books in canonical order
    foreach ($bookInfo in $BookDisplayOrder) {
        $abbr = $bookInfo.Abbr
        if (-not $bookGroups.Contains($abbr)) { continue }

        $refs = $bookGroups[$abbr]
        $count = $refs.Count
        $bookName = $bookInfo.Name
        $folder = $bookInfo.Folder

        [void]$html.AppendLine("")
        [void]$html.AppendLine("  <div class=`"conc-book`" id=`"conc-book-$bookIdx`">")

        # Book toggle button
        [void]$html.AppendLine("    <button class=`"conc-book-toggle`" id=`"conc-toggle-$bookIdx`" onclick=`"toggleBook($bookIdx)`">")
        [void]$html.AppendLine("      &#9654; $bookName <span class=`"conc-count`">($count)</span>")
        [void]$html.AppendLine("    </button>")

        # Collapsible verse section (hidden by default)
        [void]$html.AppendLine("    <div class=`"conc-verses`" id=`"conc-verses-$bookIdx`" style=`"display:none`">")

        if ($count -le $SMALL_THRESHOLD) {
            # ── Small: show all links directly, no pagination ──
            foreach ($ref in $refs) {
                $ch = if ($ref -is [hashtable]) { $ref.ch } else { $ref.ch }
                $vs = if ($ref -is [hashtable]) { $ref.vs } else { $ref.vs }
                $href = "../../books/$folder/$ch.html#verse-$vs"
                $linkHtml = Format-ConcordanceLink -Abbr $abbr -Folder $folder -Ref $ref
            [void]$html.AppendLine($linkHtml)
            }
        }
        else {
            # ── Large: paginate at $PAGE_SIZE per page ──
            $pageCount = [Math]::Ceiling($count / $PAGE_SIZE)

            for ($p = 0; $p -lt $pageCount; $p++) {
                $start = $p * $PAGE_SIZE
                $end = [Math]::Min($start + $PAGE_SIZE, $count) - 1
                $display = if ($p -eq 0) { "block" } else { "none" }

                [void]$html.AppendLine("      <div class=`"conc-page`" id=`"conc-page-$bookIdx-$p`" style=`"display:$display`">")

                for ($i = $start; $i -le $end; $i++) {
                    $ref = $refs[$i]
                    $ch = if ($ref -is [hashtable]) { $ref.ch } else { $ref.ch }
                    $vs = if ($ref -is [hashtable]) { $ref.vs } else { $ref.vs }
                    $href = "../../books/$folder/$ch.html#verse-$vs"
                    $linkHtml = Format-ConcordanceLink -Abbr $abbr -Folder $folder -Ref $refs[$i]
                    [void]$html.AppendLine($linkHtml)
                }

                [void]$html.AppendLine("      </div>")
            }

            # Pagination nav
            if ($pageCount -gt 1) {
                [void]$html.AppendLine("      <div class=`"conc-nav`" id=`"conc-nav-$bookIdx`">")
                [void]$html.AppendLine("        <button class=`"btn conc-nav-btn`" onclick=`"concPage($bookIdx,-1)`">&#9664; Prev</button>")
                [void]$html.AppendLine("        <span class=`"conc-pg-label`" id=`"conc-pg-$bookIdx`">Page 1 of $pageCount</span>")
                [void]$html.AppendLine("        <button class=`"btn conc-nav-btn`" onclick=`"concPage($bookIdx,1)`">Next &#9654;</button>")
                [void]$html.AppendLine("      </div>")
            }
        }

        [void]$html.AppendLine("    </div>")  # close conc-verses
        [void]$html.AppendLine("  </div>")    # close conc-book

        $bookIdx++
    }

    [void]$html.AppendLine("</div>")  # close conc-section

    return $html.ToString()
}


# ================================================================
# STEP 3: Inline JS to embed in each dictionary page
# ================================================================
# This JS is added ONCE per dictionary page inside a <script> tag.
# It handles expand/collapse and pagination. ES3 compatible.

$ConcordanceInlineJs = @'
<script>
var concPages = {};
function toggleBook(idx) {
  var el = document.getElementById("conc-verses-" + idx);
  var btn = document.getElementById("conc-toggle-" + idx);
  if (!el || !btn) return;
  if (el.style.display === "none") {
    el.style.display = "block";
    var t = btn.innerHTML;
    btn.innerHTML = t.replace("\u25B6", "\u25BC");
  } else {
    el.style.display = "none";
    var t2 = btn.innerHTML;
    btn.innerHTML = t2.replace("\u25BC", "\u25B6");
  }
}
function concPage(bookIdx, delta) {
  if (!concPages[bookIdx]) concPages[bookIdx] = 0;
  var cur = concPages[bookIdx];
  var next = cur + delta;
  var curEl = document.getElementById("conc-page-" + bookIdx + "-" + cur);
  var nextEl = document.getElementById("conc-page-" + bookIdx + "-" + next);
  if (!nextEl) return;
  if (curEl) curEl.style.display = "none";
  nextEl.style.display = "block";
  concPages[bookIdx] = next;
  var total = 0;
  for (var i = 0; i < 200; i++) {
    if (document.getElementById("conc-page-" + bookIdx + "-" + i)) {
      total++;
    } else {
      break;
    }
  }
  var label = document.getElementById("conc-pg-" + bookIdx);
  if (label) label.innerHTML = "Page " + (next + 1) + " of " + total;
}
</script>
'@


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
            $paddedNum = ([int]$num).ToString().PadLeft(4, '0')
            [void]$sb.Append("$prefix$paddedNum")
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
        [string]$Language,
        [string]$ConcordanceHtml = '',
        [string]$BdbHtml = ''
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

    # Linkify H/G number references in origin text e.g. "from H1234" -> clickable link
    $orgLinked = if ($orgHtml) {
        [System.Text.RegularExpressions.Regex]::Replace(
            $orgHtml,
            '([HG])(\d+)',
            {
                param($m)
                $prefix = $m.Groups[1].Value
                $num    = [int]$m.Groups[2].Value
                $lang   = if ($prefix -eq 'H') { 'hebrew' } else { 'greek' }
                $padded = $prefix.ToLower() + $num.ToString().PadLeft(4, '0')
                $href   = "../../dict/$lang/$padded.html"
                $paddedDisplay = $prefix + $num.ToString().PadLeft(4, '0')
                return "<a href=`"$href`" class=`"strongs-link`">$paddedDisplay</a>"
            }
        )
    } else { '' }

    $originRow = if ($orgLinked) {
        '          <tr><th>Origin</th><td>' + $orgLinked + '</td></tr>'
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
  <meta name="color-scheme" content="dark">
  <link rel="icon" type="image/x-icon" href="../../BiblePencil.ico">
  <link rel="manifest" href="../../manifest.json">
  <meta name="theme-color" content="#00bcd4">
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

$BdbHtml

    </div>

    <div class="dict-footer">
      <a href="javascript:history.back()" class="btn">Back</a>
    </div>

  </div>
$ConcordanceHtml
$ConcordanceInlineJs
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
        [System.Collections.Generic.List[hashtable]]$Entries,
        [string]$Sha = ""
    )

    $lang     = $Language.ToLower()
    $prefix   = if ($lang -eq 'hebrew') { 'H' } else { 'G' }
    $cssPath  = '../css/style.css'
    $title    = "$Language Index"
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
  <meta name="color-scheme" content="dark">
  <meta name="kjv-sha" content="$Sha">
  <link rel="icon" type="image/x-icon" href="../BiblePencil.ico">
  <link rel="manifest" href="../manifest.json">
  <meta name="theme-color" content="#00bcd4">
  <title>$titleEsc</title>
  <link rel="stylesheet" href="$cssPath">
  <style>
    .index-search-row { display: flex; gap: 0.5em; margin-bottom: 0.75em; }
    .index-search-input { flex: 1; }
  </style>
</head>
<body>
  <nav class="chapter-nav">
    <h1 class="book-chapter"><span class="update-cross" onclick="openUpdateModal()" title="Update available!"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="18" viewBox="0 0 14 18" fill="currentColor"><rect x="5.5" y="0" width="3" height="18"/><rect x="0" y="4" width="14" height="3"/></svg></span>$titleEsc</h1>
    <div class="nav-buttons">
      <a href="../index.html" class="btn home-btn" title="Home"><svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9.5L12 3l9 6.5V20a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9.5z"/><path d="M9 21V12h6v9"/></svg></a>
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
      <div class="settings-row settings-row-clickable" onclick="syncViaQr()">
        <span class="settings-row-icon">&#128247;</span>
        Connect New Phone
      </div>
      <div class="settings-row settings-row-clickable" onclick="window.location.href='/notes-manager.html'">
        <span class="settings-row-icon">&#128209;</span>
        My Notes
      </div>
      <div class="settings-row settings-row-clickable" onclick="rebakeNotes()">
        <span class="settings-row-icon">&#128260;</span>
        Rebake Notes
      </div>
      <div class="settings-row settings-row-clickable" onclick="exportNotes()">
        <span class="settings-row-icon">&#128190;</span>
        Export Notes
      </div>
      <div class="settings-row settings-row-clickable" onclick="importNotes()">
        <span class="settings-row-icon">&#128229;</span>
        Import Notes
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <p class="settings-section-label">OFFLINE ACCESS</p>
      <div class="settings-row settings-row-clickable" id="offline-bible-row" onclick="downloadOffline('bible')">
        <span class="settings-row-icon">&#128214;</span>
        <span id="offline-bible-label">Download Bible Text for Offline</span>
      </div>
      <div class="settings-row settings-row-clickable" id="offline-lexicon-row" onclick="downloadOffline('lexicon')">
        <span class="settings-row-icon">&#128218;</span>
        <span id="offline-lexicon-label">Download Lexicon for Offline</span>
      </div>
      <div class="settings-row settings-row-clickable" id="offline-refresh-row" onclick="refreshOfflineContent()">
        <span class="settings-row-icon">&#128259;</span>
        Refresh Offline Content
      </div>
    </div>
    <div class="settings-divider"></div>
    <div class="settings-section">
      <div class="settings-row settings-row-clickable" onclick="window.open('../help.html','_blank')">
        <span class="settings-row-icon">&#10067;</span>
        Help / Documentation
      </div>
      <div class="settings-row settings-row-clickable" onclick="window.open('../about.html','_blank')">
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

    <div class="index-search-row">
      <input type="text" id="index-search-input" class="index-search-input"
             placeholder="Search transliteration or Strong's #..." onkeyup="applyIndexSearch()">
      <button class="btn" onclick="clearIndexSearch()">Clear</button>
    </div>

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

/* Search state: null = no active filter (show everything, original
   behavior); otherwise an array of indices into INDEX_DATA that match
   the current search term. */
var FILTERED_INDICES = null;

/* Maps accented/modifier characters found in either language's
   transliteration column to a plain ASCII base letter (or to nothing,
   for glottal-stop/breathing marks), so a search for "abaddon" or
   "aaron" matches without the user needing to type diacritics. Covers
   both Hebrew and Greek since this template generates both pages --
   harmless for a page to carry the other language's unused entries.
   No String.prototype.normalize() here since this file also has to
   run on the original Kindle target. */
var IDX_DIACRITIC_MAP = {
  "\u00c1": "a", "\u00e1": "a", "\u00c2": "a", "\u00e2": "a", "\u00e0": "a", "\u0102": "a", "\u0103": "a",
  "\u00c7": "c", "\u00e7": "c",
  "\u00c9": "e", "\u00e9": "e", "\u00ca": "e", "\u00ea": "e", "\u00e8": "e",
  "\u0112": "e", "\u0113": "e", "\u0114": "e", "\u0115": "e", "\u1d49": "e",
  "\u1e15": "e", "\u1e16": "e", "\u1e17": "e",
  "\u00ce": "i", "\u00ee": "i", "\u00ec": "i", "\u00ed": "i", "\u00ef": "i", "\u1e2f": "i",
  "\u00d4": "o", "\u00f4": "o", "\u00f3": "o", "\u014c": "o", "\u014d": "o", "\u014f": "o",
  "\u1e51": "o", "\u1e53": "o",
  "\u00db": "u", "\u00fb": "u", "\u00fa": "u",
  "\u00fd": "y", "\u00ff": "y", "\u0177": "y",
  "\u1e6c": "t", "\u1e6d": "t",
  "\u02bb": "", "\u02bc": "", "\u2019": "",
  "\u02e2": "s"
};

function idxNormalize(s) {
  var out = "";
  var i, ch, mapped;
  for (i = 0; i < s.length; i++) {
    ch = s.charAt(i);
    mapped = IDX_DIACRITIC_MAP[ch];
    out += (mapped !== undefined) ? mapped : ch;
  }
  return out.toLowerCase();
}

function idxTrim(s) {
  return s.replace(/^\s+/, "").replace(/\s+`$/, "");
}

/* A bare number (optionally prefixed with H/G, optionally zero-padded)
   is treated as a Strong's-number search; anything else is matched
   against the (diacritic-normalized) transliteration as a substring. */
function idxStripNumPrefix(s) {
  s = s.replace(/^[HGhg]/, "");
  s = s.replace(/^0+/, "");
  if (s === "") { s = "0"; }
  return s;
}

function idxMatches(entry, term) {
  if (term === "") { return true; }

  var numTerm = idxStripNumPrefix(term);
  if (/^[0-9]+`$/.test(numTerm)) {
    if (idxStripNumPrefix(entry[0]) === numTerm) { return true; }
  }

  return idxNormalize(entry[2]).indexOf(idxNormalize(term)) !== -1;
}

window.applyIndexSearch = function () {
  var input = document.getElementById("index-search-input");
  var term = idxTrim(input ? input.value : "");
  var i;

  if (term === "") {
    FILTERED_INDICES = null;
  } else {
    FILTERED_INDICES = [];
    for (i = 0; i < INDEX_DATA.length; i++) {
      if (idxMatches(INDEX_DATA[i], term)) { FILTERED_INDICES.push(i); }
    }
  }
  currentPage = 1;
  render();
};

window.clearIndexSearch = function () {
  var input = document.getElementById("index-search-input");
  if (input) { input.value = ""; }
  window.applyIndexSearch();
};

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

function totalPages(activeTotal) {
  if (perPage === 0) { return 1; }
  return Math.ceil(activeTotal / perPage);
}

function renderNav(id, activeTotal) {
  var el = document.getElementById(id);
  if (perPage === 0 || totalPages(activeTotal) <= 1) { el.innerHTML = ""; return; }
  var tp = totalPages(activeTotal);
  var html = "";
  if (currentPage > 1) {
    html += "<button class=\"btn\" onclick=\"goPage(1)\">[BEG]</button> ";
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
    html += " <button class=\"btn\" onclick=\"goPage(" + tp + ")\">[END]</button>";
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
  var activeTotal = FILTERED_INDICES ? FILTERED_INDICES.length : TOTAL;
  var start = (perPage === 0) ? 0 : (currentPage - 1) * perPage;
  var end   = (perPage === 0) ? activeTotal : Math.min(start + perPage, activeTotal);
  var tbody = document.getElementById("index-body");
  var rows  = [];
  var i, idx, entry, href, row;
  for (i = start; i < end; i++) {
    idx = FILTERED_INDICES ? FILTERED_INDICES[i] : i;
    entry = INDEX_DATA[idx];
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

  var filterNote = FILTERED_INDICES ? (" (filtered from " + TOTAL + ")") : "";
  var showing;
  if (activeTotal === 0) {
    showing = "No matches found.";
  } else if (perPage === 0) {
    showing = "All " + activeTotal + " entries" + filterNote;
  } else {
    showing = "Showing " + (start + 1) + "-" + end + " of " + activeTotal + filterNote;
  }
  document.getElementById("index-status").innerHTML = showing;

  renderNav("index-nav-top", activeTotal);
  renderNav("index-nav-bottom", activeTotal);
  updatePerPageButtons();
}

render();
</script>

  <script src="../js/fontsize.js"></script>
  <script src="../js/notes.js"></script>
  <script src="../js/sticky-header.js"></script>
  <script>
  if ("serviceWorker" in navigator && (location.protocol === "http:" || location.protocol === "https:")) {
      navigator.serviceWorker.register("/sw.js").catch(function () {});
  }
  </script>
$ConcordanceHtml
$ConcordanceInlineJs
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
    $paddedHeb = "H" + $num.ToString().PadLeft(4,'0')
    $concHtml  = Get-ConcordanceHtml -StrongsId $paddedHeb
    $bdbHtml   = Get-BdbHtml -StrongsId $paddedHeb
    Write-DictPage `
        -FilePath        $outPath `
        -StrongsId       $paddedHeb `
        -OriginalWord    $origWord `
        -Translit        $xlit `
        -Phonetic        $phon `
        -PartOfSpeech    $morph `
        -Definition      $def `
        -KjvDef          $kjv `
        -Origin          $origin `
        -Language        'Hebrew' `
        -ConcordanceHtml $concHtml `
        -BdbHtml         $bdbHtml

    $shortDef = if ($def) { Get-ShortDef $def } elseif ($kjv) { Get-ShortDef $kjv } else { '' }
    [void]$hebIndexEntries.Add(@{
        Num      = $num
        Original = $origWord
        Translit = $xlit
        ShortDef = $shortDef
        Filename = $padded
    })

    $count++
    if ($count % 500 -eq 0) {
        Write-Host "  Hebrew: $count entries written..."
        # Hebrew spans 65%-76% of overall update bar
        $pct = 65 + [int](($count / $entries.Count) * 11)
        Write-DictStatus -Percent $pct -Detail "Generating Hebrew lexicon ($count / $($entries.Count))..."
    }
}
Write-Host "Hebrew done - $count pages written."

$hebIndexEntries = $hebIndexEntries | Sort-Object { $_.Num }
Write-Host "Writing Hebrew index ($($hebIndexEntries.Count) entries)..."
$hebIdxPath = Join-Path $IndexDir 'strongs-hebrew-index.html'
Write-IndexPage -FilePath $hebIdxPath -Language 'Hebrew' -Entries $hebIndexEntries -Sha $InstalledSha
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
    $paddedGrk = "G" + $num.ToString().PadLeft(4,'0')
    $concHtml  = Get-ConcordanceHtml -StrongsId $paddedGrk
    $bdbHtml   = Get-BdbHtml -StrongsId $paddedGrk
    Write-DictPage `
        -FilePath        $outPath `
        -StrongsId       $paddedGrk `
        -OriginalWord    $origWord `
        -Translit        $xlit `
        -Phonetic        $phon `
        -PartOfSpeech    '' `
        -Definition      $def `
        -KjvDef          $kjv `
        -Origin          $origin `
        -Language        'Greek' `
        -ConcordanceHtml $concHtml `
        -BdbHtml         $bdbHtml

    $shortDef = if ($def) { Get-ShortDef $def } elseif ($kjv) { Get-ShortDef $kjv } else { '' }
    [void]$grkIndexEntries.Add(@{
        Num      = $num
        Original = $origWord
        Translit = $xlit
        ShortDef = $shortDef
        Filename = $padded
    })

    $count++
    if ($count % 500 -eq 0) {
        Write-Host "  Greek: $count entries written..."
        # Greek spans 77%-89% of overall update bar
        $pct = 77 + [int](($count / $gEntries.Count) * 12)
        Write-DictStatus -Percent $pct -Detail "Generating Greek lexicon ($count / $($gEntries.Count))..."
    }
}
Write-Host "Greek done - $count pages written."

$grkIndexEntries = $grkIndexEntries | Sort-Object { $_.Num }
Write-Host "Writing Greek index ($($grkIndexEntries.Count) entries)..."
$grkIdxPath = Join-Path $IndexDir 'strongs-greek-index.html'
Write-IndexPage -FilePath $grkIdxPath -Language 'Greek' -Entries $grkIndexEntries -Sha $InstalledSha
Write-Host "Greek index written."

Write-Host "Dictionary generation complete."
