# rebake-notes.ps1
# Re-bakes all notes from notes.json into chapter HTML files.
# Run this after regenerating bible HTML to restore baked notes.
#
# Usage: pwsh -NoProfile -File .\rebake-notes.ps1

param(
    [string]$NotesFile   = 'notes.json',
    [string]$ProjectRoot = 'C:\Users\OldTi\KJV-Strongs'
)

Set-Location $ProjectRoot

if (-not (Test-Path $NotesFile)) {
    Write-Host "notes.json not found — nothing to rebake." -ForegroundColor Yellow
    exit 0
}

$notesJson = Get-Content $NotesFile -Raw -Encoding UTF8
$notes     = $notesJson | ConvertFrom-Json

# Book table: OsisId -> folder
$BookTable = @{
    'Gen'='01-Gen'; 'Exod'='02-Exod'; 'Lev'='03-Lev'; 'Num'='04-Num';
    'Deut'='05-Deut'; 'Josh'='06-Josh'; 'Judg'='07-Judg'; 'Ruth'='08-Ruth';
    '1Sam'='09-1Sam'; '2Sam'='10-2Sam'; '1Kgs'='11-1Kgs'; '2Kgs'='12-2Kgs';
    '1Chr'='13-1Chr'; '2Chr'='14-2Chr'; 'Ezra'='15-Ezra'; 'Neh'='16-Neh';
    'Esth'='17-Esth'; 'Job'='18-Job'; 'Ps'='19-Ps'; 'Prov'='20-Prov';
    'Eccl'='21-Eccl'; 'Song'='22-Song'; 'Isa'='23-Isa'; 'Jer'='24-Jer';
    'Lam'='25-Lam'; 'Ezek'='26-Ezek'; 'Dan'='27-Dan'; 'Hos'='28-Hos';
    'Joel'='29-Joel'; 'Amos'='30-Amos'; 'Obad'='31-Obad'; 'Jonah'='32-Jonah';
    'Mic'='33-Mic'; 'Nah'='34-Nah'; 'Hab'='35-Hab'; 'Zeph'='36-Zeph';
    'Hag'='37-Hag'; 'Zech'='38-Zech'; 'Mal'='39-Mal'; 'Matt'='40-Matt';
    'Mark'='41-Mark'; 'Luke'='42-Luke'; 'John'='43-John'; 'Acts'='44-Acts';
    'Rom'='45-Rom'; '1Cor'='46-1Cor'; '2Cor'='47-2Cor'; 'Gal'='48-Gal';
    'Eph'='49-Eph'; 'Phil'='50-Phil'; 'Col'='51-Col'; '1Thess'='52-1Thess';
    '2Thess'='53-2Thess'; '1Tim'='54-1Tim'; '2Tim'='55-2Tim'; 'Titus'='56-Titus';
    'Phlm'='57-Phlm'; 'Heb'='58-Heb'; 'Jas'='59-Jas'; '1Pet'='60-1Pet';
    '2Pet'='61-2Pet'; '1John'='62-1John'; '2John'='63-2John'; '3John'='64-3John';
    'Jude'='65-Jude'; 'Rev'='66-Rev'
}

function ConvertTo-HtmlEncoded([string]$Text) {
    return $Text `
        -replace '&', '&amp;' `
        -replace '<', '&lt;' `
        -replace '>', '&gt;' `
        -replace '"', '&quot;' `
        -replace "`n", '<br>'
}

function ConvertTo-VerseLinks([string]$Text) {
    return [System.Text.RegularExpressions.Regex]::Replace(
        $Text,
        '\[\[([A-Za-z0-9]+)\.(\d+)\.(\d+)\]\]',
        {
            param($m)
            $book   = $m.Groups[1].Value
            $ch     = $m.Groups[2].Value
            $vs     = $m.Groups[3].Value
            $folder = $BookTable[$book]
            if ($folder) {
                $href = "../../books/$folder/$ch.html#verse-$vs"
                return "<a href=`"$href`" class=`"verse-note-link`">$book $ch`:$vs</a>"
            } else {
                return "$book $ch`:$vs"
            }
        }
    )
}

$count  = 0
$errors = 0

$notes.PSObject.Properties | ForEach-Object {
    $ref  = $_.Name
    $data = $_.Value

    $parts    = $ref -split '\.'
    $bookAbbr = $parts[0]
    $chNum    = $parts[1]
    $verseNum = $parts[2]
    $text     = $data.text

    $folder = $BookTable[$bookAbbr]
    if (-not $folder) {
        Write-Host "  [SKIP] Unknown book: $bookAbbr" -ForegroundColor Yellow
        $errors++
        return
    }

    $filePath = Join-Path $ProjectRoot "books\$folder\$chNum.html"
    if (-not (Test-Path $filePath)) {
        Write-Host "  [SKIP] File not found: $filePath" -ForegroundColor Yellow
        $errors++
        return
    }

    $escaped   = ConvertTo-HtmlEncoded -Text $text
    $linked    = ConvertTo-VerseLinks -Text $escaped
    $timestamp = if ($data.timestamp) { $data.timestamp } else { Get-Date -Format "yyyy-MM-dd HH:mm" }

    $html    = Get-Content -Path $filePath -Raw -Encoding UTF8
    $pattern = "(?s)(<div class=`"verse-note`" id=`"note-verse-$verseNum`">).*?(</div>)"
    $replacement = "`$1`n  <p class=`"verse-note-text`">$linked</p>`n  <p class=`"verse-note-meta`">Note saved: $timestamp</p>`n`$2"

    if ($html -match $pattern) {
        $html = $html -replace $pattern, $replacement
        [System.IO.File]::WriteAllText($filePath, $html, [System.Text.Encoding]::UTF8)
        Write-Host "  [BAKED] $ref" -ForegroundColor Green
        $count++
    } else {
        Write-Host "  [WARN] Placeholder not found for $ref in $filePath" -ForegroundColor Yellow
        $errors++
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Rebake complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Notes baked : $count" -ForegroundColor Green
Write-Host " Errors/skips: $errors" -ForegroundColor $(if ($errors -gt 0) { 'Yellow' } else { 'Green' })
