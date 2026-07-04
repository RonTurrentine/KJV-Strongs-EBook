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

param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# ── Configuration ────────────────────────────────────────────────

$Root       = $PSScriptRoot
$NotesFile       = Join-Path $Root "notes.json"
$HighlightsFile = Join-Path $Root "highlights.json"
$SyncState  = Join-Path $Root ".last-sync"
$AdbPath = "" # Resolved dynamically by Resolve-AdbPath (used for Kindle sync)
$KindlePath = "/data/local/tmp"
$BaseUrl    = "http://localhost:${Port}/"

# ── MIME Types ───────────────────────────────────────────────────

$MimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".gif"  = "image/gif"
    ".svg"  = "image/svg+xml"
    ".ico"  = "image/x-icon"
    ".woff" = "font/woff"
    ".woff2"= "font/woff2"
    ".ttf"  = "font/ttf"
    ".xml"  = "application/xml"
    ".txt"  = "text/plain; charset=utf-8"
}

# ── Book Table (OSIS abbreviation → folder name) ────────────────

$BookTable = @{
    "Gen"    = "01-Gen";     "Exod"   = "02-Exod";    "Lev"    = "03-Lev"
    "Num"    = "04-Num";     "Deut"   = "05-Deut";    "Josh"   = "06-Josh"
    "Judg"   = "07-Judg";   "Ruth"   = "08-Ruth";    "1Sam"   = "09-1Sam"
    "2Sam"   = "10-2Sam";   "1Kgs"   = "11-1Kgs";    "2Kgs"   = "12-2Kgs"
    "1Chr"   = "13-1Chr";   "2Chr"   = "14-2Chr";    "Ezra"   = "15-Ezra"
    "Neh"    = "16-Neh";    "Esth"   = "17-Esth";    "Job"    = "18-Job"
    "Ps"     = "19-Ps";     "Prov"   = "20-Prov";    "Eccl"   = "21-Eccl"
    "Song"   = "22-Song";   "Isa"    = "23-Isa";     "Jer"    = "24-Jer"
    "Lam"    = "25-Lam";    "Ezek"   = "26-Ezek";    "Dan"    = "27-Dan"
    "Hos"    = "28-Hos";    "Joel"   = "29-Joel";    "Amos"   = "30-Amos"
    "Obad"   = "31-Obad";   "Jonah"  = "32-Jonah";   "Mic"    = "33-Mic"
    "Nah"    = "34-Nah";    "Hab"    = "35-Hab";     "Zeph"   = "36-Zeph"
    "Hag"    = "37-Hag";    "Zech"   = "38-Zech";    "Mal"    = "39-Mal"
    "Matt"   = "40-Matt";   "Mark"   = "41-Mark";    "Luke"   = "42-Luke"
    "John"   = "43-John";   "Acts"   = "44-Acts";    "Rom"    = "45-Rom"
    "1Cor"   = "46-1Cor";   "2Cor"   = "47-2Cor";    "Gal"    = "48-Gal"
    "Eph"    = "49-Eph";    "Phil"   = "50-Phil";    "Col"    = "51-Col"
    "1Thess" = "52-1Thess"; "2Thess" = "53-2Thess";  "1Tim"   = "54-1Tim"
    "2Tim"   = "55-2Tim";   "Titus"  = "56-Titus";   "Phlm"   = "57-Phlm"
    "Heb"    = "58-Heb";    "Jas"    = "59-Jas";     "1Pet"   = "60-1Pet"
    "2Pet"   = "61-2Pet";   "1John"  = "62-1John";   "2John"  = "63-2John"
    "3John"  = "64-3John";  "Jude"   = "65-Jude";    "Rev"    = "66-Rev"
}


# ================================================================
# Helper Functions
# ================================================================

# ── Load notes from JSON file ──────────────────────────────────

function Get-Notes {
    if (Test-Path $NotesFile) {
        $raw = Get-Content -Path $NotesFile -Raw -Encoding UTF8
        if ($raw -and $raw.Trim().Length -gt 2) {
            return ($raw | ConvertFrom-Json -AsHashtable)
        }
    }
    return @{}
}

# ── Save notes to JSON file ───────────────────────────────────

function Save-Notes {
    param([hashtable]$Notes)
    $json = $Notes | ConvertTo-Json -Depth 4
    Set-Content -Path $NotesFile -Value $json -Encoding UTF8
}

# ── Parse a note reference into file path ──────────────────────
# Input:  "Gen.1.1"
# Output: "books\01-Gen\1.html" (relative to root)

function Get-ChapterFilePath {
    param([string]$Ref)

    $parts = $Ref -split "\."
    if ($parts.Length -lt 3) { return $null }

    $bookAbbr = $parts[0]
    $chNum    = $parts[1]

    $folder = $BookTable[$bookAbbr]
    if (-not $folder) { return $null }

    $relPath = "books\$folder\$chNum.html"
    $fullPath = Join-Path $Root $relPath
    if (Test-Path $fullPath) {
        return $fullPath
    }
    return $null
}

# ── HTML-encode text ───────────────────────────────────────────

function ConvertTo-HtmlEncoded {
    param([string]$Text)
    $Text = $Text -replace "&", "&amp;"
    $Text = $Text -replace "<", "&lt;"
    $Text = $Text -replace ">", "&gt;"
    $Text = $Text -replace '"', "&quot;"
    $Text = $Text -replace "`n", "<br>"
    $Text = $Text -replace "`r", ""
    return $Text
}

# ── Convert [[Book.Ch.Vs]] to HTML links ───────────────────────
$BookTable = @{
    "Gen"="01-Gen"; "Exod"="02-Exod"; "Lev"="03-Lev"; "Num"="04-Num";
    "Deut"="05-Deut"; "Josh"="06-Josh"; "Judg"="07-Judg"; "Ruth"="08-Ruth";
    "1Sam"="09-1Sam"; "2Sam"="10-2Sam"; "1Kgs"="11-1Kgs"; "2Kgs"="12-2Kgs";
    "1Chr"="13-1Chr"; "2Chr"="14-2Chr"; "Ezra"="15-Ezra"; "Neh"="16-Neh";
    "Esth"="17-Esth"; "Job"="18-Job"; "Ps"="19-Ps"; "Prov"="20-Prov";
    "Eccl"="21-Eccl"; "Song"="22-Song"; "Isa"="23-Isa"; "Jer"="24-Jer";
    "Lam"="25-Lam"; "Ezek"="26-Ezek"; "Dan"="27-Dan"; "Hos"="28-Hos";
    "Joel"="29-Joel"; "Amos"="30-Amos"; "Obad"="31-Obad"; "Jonah"="32-Jonah";
    "Mic"="33-Mic"; "Nah"="34-Nah"; "Hab"="35-Hab"; "Zeph"="36-Zeph";
    "Hag"="37-Hag"; "Zech"="38-Zech"; "Mal"="39-Mal"; "Matt"="40-Matt";
    "Mark"="41-Mark"; "Luke"="42-Luke"; "John"="43-John"; "Acts"="44-Acts";
    "Rom"="45-Rom"; "1Cor"="46-1Cor"; "2Cor"="47-2Cor"; "Gal"="48-Gal";
    "Eph"="49-Eph"; "Phil"="50-Phil"; "Col"="51-Col"; "1Thess"="52-1Thess";
    "2Thess"="53-2Thess"; "1Tim"="54-1Tim"; "2Tim"="55-2Tim"; "Titus"="56-Titus";
    "Phlm"="57-Phlm"; "Heb"="58-Heb"; "Jas"="59-Jas"; "1Pet"="60-1Pet";
    "2Pet"="61-2Pet"; "1John"="62-1John"; "2John"="63-2John"; "3John"="64-3John";
    "Jude"="65-Jude"; "Rev"="66-Rev"
}

function ConvertTo-VerseLinks {
    param([string]$Text)
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

# ── Bake a note into a chapter HTML file ───────────────────────
# Finds <div class="verse-note" id="note-verse-N">...</div>
# and replaces its content with the note text.

function Bake-Note {
    param(
        [string]$Ref,
        [string]$NoteText
    )

    $filePath = Get-ChapterFilePath -Ref $Ref
    if (-not $filePath) {
        Write-Host "  [WARN] Cannot find file for ref: $Ref" -ForegroundColor Yellow
        return $false
    }

    $parts = $Ref -split "\."
    $verseNum = $parts[2]
    $escaped   = ConvertTo-HtmlEncoded -Text $NoteText
    $linked    = ConvertTo-VerseLinks -Text $escaped
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

    $html = Get-Content -Path $filePath -Raw -Encoding UTF8

    # Regex: match the note-verse-N div (empty or filled)
    $pattern = "(?s)(<div class=`"verse-note`" id=`"note-verse-$verseNum`">).*?(</div>)"
    $replacement = "`$1`n  <p class=`"verse-note-text`">$linked</p>`n  <p class=`"verse-note-meta`">Note saved: $timestamp</p>`n`$2"

    if ($html -match $pattern) {
        $html = $html -replace $pattern, $replacement
        Set-Content -Path $filePath -Value $html -Encoding UTF8 -NoNewline
        Write-Host "  [BAKE] $Ref -> $filePath" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "  [WARN] Placeholder not found for verse $verseNum in $filePath" -ForegroundColor Yellow
        return $false
    }
}

# ── Remove a baked note from a chapter HTML file ───────────────

function Unbake-Note {
    param([string]$Ref)

    $filePath = Get-ChapterFilePath -Ref $Ref
    if (-not $filePath) { return $false }

    $parts = $Ref -split "\."
    $verseNum = $parts[2]

    $html = Get-Content -Path $filePath -Raw -Encoding UTF8

    $pattern = "(?s)(<div class=`"verse-note`" id=`"note-verse-$verseNum`">).*?(</div>)"
    $replacement = "`$1`$2"

    if ($html -match $pattern) {
        $html = $html -replace $pattern, $replacement
        Set-Content -Path $filePath -Value $html -Encoding UTF8 -NoNewline
        Write-Host "  [UNBAKE] $Ref -> $filePath" -ForegroundColor Cyan
        return $true
    }
    return $false
}

# ── Send HTTP response ─────────────────────────────────────────

function Send-Response {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$ContentType,
        [byte[]]$Body
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = $ContentType
    if ($Body -and $Body.Length -gt 0) {
        $Response.ContentLength64 = $Body.Length
        $Response.OutputStream.Write($Body, 0, $Body.Length)
    }
    $Response.Close()
}

function Send-Json {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode = 200,
        $Data
    )
    $json = if ($Data -is [string]) { $Data } else { $Data | ConvertTo-Json -Depth 4 }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    Send-Response -Response $Response -StatusCode $StatusCode `
        -ContentType "application/json; charset=utf-8" -Body $bytes
}

function Send-Error {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode,
        [string]$Message
    )
    Send-Json -Response $Response -StatusCode $StatusCode `
        -Data @{ ok = $false; error = $Message }
}


# ================================================================
# API Handlers
# ================================================================

# ── GET /api/notes ─────────────────────────────────────────────

function Handle-GetNotes {
    param([System.Net.HttpListenerResponse]$Response)
    $notes = Get-Notes
    Send-Json -Response $Response -Data $notes
}

# ── POST /api/notes ────────────────────────────────────────────

function Handle-SaveNote {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    # Read request body
    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try {
        $data = $body | ConvertFrom-Json
    }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON"
        return
    }

    $ref  = $data.ref
    $text = $data.text

    if (-not $ref -or -not $text) {
        Send-Error -Response $Response -StatusCode 400 -Message "Missing ref or text"
        return
    }

    Write-Host "[SAVE] $ref" -ForegroundColor Green

    # Save to notes.json
    $notes = Get-Notes
    $notes[$ref] = @{
        text    = $text
        created = if ($notes[$ref] -and $notes[$ref].created) { $notes[$ref].created } else { (Get-Date -Format "o") }
        updated = (Get-Date -Format "o")
    }
    Save-Notes -Notes $notes

    # Bake into chapter HTML
    $baked = Bake-Note -Ref $ref -NoteText $text

    Send-Json -Response $Response -Data @{ ok = $true; baked = $baked }
}

# ── DELETE /api/notes/{ref} ────────────────────────────────────

function Handle-DeleteNote {
    param(
        [string]$Ref,
        [System.Net.HttpListenerResponse]$Response
    )

    Write-Host "[DELETE] $Ref" -ForegroundColor Cyan

    # Remove from notes.json
    $notes = Get-Notes
    if ($notes.ContainsKey($Ref)) {
        $notes.Remove($Ref)
        Save-Notes -Notes $notes
    }

    # Unbake from chapter HTML
    $unbaked = Unbake-Note -Ref $Ref

    Send-Json -Response $Response -Data @{ ok = $true; unbaked = $unbaked }
}

# ── Locate adb.exe (called at runtime so removable drives are mounted) ──
function Resolve-AdbPath {
    $adbInPath = Get-Command "adb.exe" -ErrorAction SilentlyContinue
    if ($adbInPath) { return $adbInPath.Source }
    $candidates = @(
        "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
        "$env:ProgramFiles\Android\platform-tools\adb.exe",
        "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe",
        "C:\Android SDK Platform Tools\adb.exe",
        "C:\Android\platform-tools\adb.exe"
    )
    $drives = (Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Root)
    foreach ($drive in $drives) {
        $candidates += "${drive}Android SDK Platform Tools\adb.exe"
        $candidates += "${drive}Android\platform-tools\adb.exe"
    }
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return ""
}

# ── GET /api/kindle-status ─────────────────────────────────────
function Get-KindleStatus {
    try {
        $adbPath = Resolve-AdbPath
        if (-not $adbPath -or -not (Test-Path $adbPath)) {
            return @{ connected = $false; error = "ADB not found" }
        }
        $output  = & $adbPath devices 2>&1
        $lines   = $output -split "`n" | Where-Object { $_ -match '\S' }
        # Look for device line (not "List of devices" header, not "offline")
        $connected = $false
        foreach ($line in $lines) {
            if ($line -match '	device$') {
                $connected = $true
                break
            }
        }
        return @{ connected = $connected }
    } catch {
        return @{ connected = $false; error = $_.Exception.Message }
    }
}

# ── POST /api/sync-kindle ─────────────────────────────────────

function Handle-SyncKindle {
    param([System.Net.HttpListenerResponse]$Response)

    Write-Host "[SYNC] Starting Kindle sync..." -ForegroundColor Magenta

    # Resolve ADB at call time (removable drives may not be mounted at startup)
    $AdbPath = Resolve-AdbPath

    # Check ADB exists
    if (-not $AdbPath -or -not (Test-Path $AdbPath)) {
        Write-Host "  [ERROR] ADB not found" -ForegroundColor Red
        Send-Error -Response $Response -StatusCode 500 `
            -Message "ADB not found. Please install Android SDK Platform Tools and ensure adb.exe is accessible."
        return
    }

    # Determine last sync time
    $lastSync = [DateTime]::MinValue
    if (Test-Path $SyncState) {
        try {
            $lastSync = [DateTime]::Parse((Get-Content $SyncState -Raw).Trim())
        }
        catch { $lastSync = [DateTime]::MinValue }
    }

    # Find modified chapter files
    $booksDir = Join-Path $Root "books"
    $modifiedFiles = @()

    if (Test-Path $booksDir) {
        $modifiedFiles += Get-ChildItem -Path $booksDir -Recurse -Filter "*.html" |
            Where-Object { $_.LastWriteTime -gt $lastSync }
    }

    $pushedFiles = @()
    $errors = @()

    foreach ($file in $modifiedFiles) {
        $relPath = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")
        $targetPath = "$KindlePath/$relPath"

        Write-Host "  Pushing: $relPath" -ForegroundColor Gray
        try {
            $output = & $AdbPath push $file.FullName $targetPath 2>&1
            $pushedFiles += $relPath
        }
        catch {
            $errors += "Failed: $relPath - $_"
            Write-Host "  [ERROR] $relPath - $_" -ForegroundColor Red
        }
    }

    # Also push style-kindle.css as style.css
    $kindleCss = Join-Path $Root "css\style-kindle.css"
    if (Test-Path $kindleCss) {
        Write-Host "  Pushing: css/style-kindle.css -> css/style.css" -ForegroundColor Gray
        try {
            & $AdbPath push $kindleCss "$KindlePath/css/style.css" 2>&1
            $pushedFiles += "css/style.css (from style-kindle.css)"
        }
        catch {
            $errors += "Failed: css/style-kindle.css - $_"
        }
    }

    # Update sync timestamp
    Get-Date -Format "o" | Set-Content -Path $SyncState

    $result = @{
        ok     = $true
        pushed = $pushedFiles.Count
        files  = $pushedFiles
    }
    if ($errors.Count -gt 0) { $result.errors = $errors }

    Write-Host "  [SYNC] Pushed $($pushedFiles.Count) file(s)" -ForegroundColor Magenta
    Send-Json -Response $Response -Data $result
}

# ── Highlight Helper Functions ──────────────────────────────────
function Get-Highlights {
    if (Test-Path $HighlightsFile) {
        $raw = Get-Content -Path $HighlightsFile -Raw -Encoding UTF8
        if ($raw -and $raw.Trim().Length -gt 2) {
            return ($raw | ConvertFrom-Json -AsHashtable)
        }
    }
    return @{}
}

function Save-Highlights {
    param([hashtable]$Highlights)
    $json = $Highlights | ConvertTo-Json -Depth 2
    Set-Content -Path $HighlightsFile -Value $json -Encoding UTF8
}

function Bake-Highlight {
    param(
        [string]$Ref,
        [string]$Color   # "yellow", "green", "red", "blue", or "" to remove
    )

    $filePath = Get-ChapterFilePath -Ref $Ref
    if (-not $filePath) {
        Write-Host "  [WARN] Cannot find file for ref: $Ref" -ForegroundColor Yellow
        return $false
    }

    $parts = $Ref -split "\."
    $verseNum = $parts[2]

    $html = Get-Content -Path $filePath -Raw -Encoding UTF8

    # Match the verse <p> tag — with or without existing highlight class
    # Handles: class="verse" and class="verse hl-yellow" etc.
    $pattern = "(<p\s+class=`"verse)(\s+hl-\w+)?(`"\s+id=`"verse-$verseNum`")"

    if ($Color) {
        # Add or replace highlight class
        $replacement = "`${1} hl-$Color`${3}"
    }
    else {
        # Remove highlight class
        $replacement = "`${1}`${3}"
    }

    if ($html -match $pattern) {
        $html = $html -replace $pattern, $replacement
        Set-Content -Path $filePath -Value $html -Encoding UTF8 -NoNewline

        if ($Color) {
            Write-Host "  [HIGHLIGHT] $Ref -> hl-$Color" -ForegroundColor Yellow
        }
        else {
            Write-Host "  [UNHIGHLIGHT] $Ref" -ForegroundColor Gray
        }
        return $true
    }
    else {
        Write-Host "  [WARN] Verse pattern not found for $Ref in $filePath" -ForegroundColor Yellow
        return $false
    }
}


# ── Highlight API Handlers ───────────────────────────────────────
function Handle-GetHighlights {
    param([System.Net.HttpListenerResponse]$Response)
    $highlights = Get-Highlights
    Send-Json -Response $Response -Data $highlights
}

# ── POST /api/highlights ───────────────────────────────────────

function Handle-SaveHighlight {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try {
        $data = $body | ConvertFrom-Json
    }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON"
        return
    }

    $ref   = $data.ref
    $color = $data.color

    if (-not $ref -or -not $color) {
        Send-Error -Response $Response -StatusCode 400 -Message "Missing ref or color"
        return
    }

    # Validate color
    $validColors = @("yellow", "green", "red", "blue")
    if ($color -notin $validColors) {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid color: $color"
        return
    }

    Write-Host "[HIGHLIGHT] $ref -> $color" -ForegroundColor Yellow

    # Save to highlights.json
    $highlights = Get-Highlights
    $highlights[$ref] = $color
    Save-Highlights -Highlights $highlights

    # Bake into chapter HTML
    $baked = Bake-Highlight -Ref $ref -Color $color

    Send-Json -Response $Response -Data @{ ok = $true; baked = $baked }
}

# ── DELETE /api/highlights/{ref} ───────────────────────────────

function Handle-DeleteHighlight {
    param(
        [string]$Ref,
        [System.Net.HttpListenerResponse]$Response
    )

    Write-Host "[UNHIGHLIGHT] $Ref" -ForegroundColor Gray

    $highlights = Get-Highlights
    if ($highlights.ContainsKey($Ref)) {
        $highlights.Remove($Ref)
        Save-Highlights -Highlights $highlights
    }

    # Remove class from chapter HTML
    $unbaked = Bake-Highlight -Ref $Ref -Color ""

    Send-Json -Response $Response -Data @{ ok = $true; unbaked = $unbaked }
}


# ── POST /api/update ─────────────────────────────────────────────
# Pulls latest repo from GitHub and reruns generation pipeline.
# Called by the browser when user clicks "Update Now" on the cross icon.

$UpdateStatusFile = Join-Path $Root ".update-status.json"

function Write-UpdateStatus {
    param(
        [string]$Step,
        [int]$Percent,
        [string]$Detail = "",
        [bool]$Done = $false,
        [bool]$Error = $false,
        [string]$ErrorMessage = ""
    )
    $status = @{
        step    = $Step
        percent = $Percent
        detail  = $Detail
        done    = $Done
        error   = $Error
        errorMessage = $ErrorMessage
        ts      = (Get-Date).ToString("o")
    }
    try {
        $status | ConvertTo-Json -Compress | Set-Content -Path $UpdateStatusFile -Encoding UTF8
    } catch { }
}

function Handle-Update {
    param([System.Net.HttpListenerResponse]$Response)

    Write-Host "[UPDATE] Starting update..." -ForegroundColor Cyan

    $generateBibleScript = Join-Path $Root "scripts\generate_bible.ps1"
    $generateDictScript  = Join-Path $Root "scripts\generate_dict.ps1"
    $rebakeScript        = Join-Path $Root "scripts\rebake-notes.ps1"

    if (-not (Test-Path $generateBibleScript)) {
        Send-Error -Response $Response -StatusCode 500 `
            -Message "generate_bible.ps1 not found"
        return
    }

    # Respond immediately — the actual work runs in a background job so
    # the server's single request loop stays free to answer status polls.
    Send-Json -Response $Response -Data @{ started = $true }

    Write-UpdateStatus -Step "pull" -Percent 5 -Detail "Pulling latest from GitHub..."

    Start-Job -Name "kjv-update" -ScriptBlock {
        param($Root, $GenerateBibleScript, $GenerateDictScript, $RebakeScript, $StatusFile)

        function Write-Status {
            param($Step, $Percent, $Detail, $Done = $false, $Err = $false, $ErrMsg = "", $NewSha = "")
            $s = @{ step=$Step; percent=$Percent; detail=$Detail; done=$Done; error=$Err; errorMessage=$ErrMsg; newSha=$NewSha; ts=(Get-Date).ToString("o") }
            $s | ConvertTo-Json -Compress | Set-Content -Path $StatusFile -Encoding UTF8
        }

        try {
            # ── Download latest repo as ZIP and extract over existing files ──
            # NOTE: The installed app is NOT a git clone — it was extracted
            # from a ZIP by the Electron launcher. There is no .git folder,
            # so `git pull` silently fails here. We replicate the launcher's
            # cloneRepo() approach: download the latest ZIP from GitHub and
            # extract it directly over the existing install folder.
            Write-Status "pull" 10 "Downloading latest files from GitHub..."

            $zipUrl  = "https://github.com/RonTurrentine/KJV-Strongs-EBook/archive/refs/heads/main.zip"
            $zipPath = Join-Path $env:TEMP "kjv-update-repo.zip"

            Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing -TimeoutSec 120

            Write-Status "pull" 18 "Extracting latest files..."

            $extractTemp = Join-Path $env:TEMP "kjv-update-extract"
            if (Test-Path $extractTemp) { Remove-Item -Recurse -Force $extractTemp }
            Expand-Archive -Path $zipPath -DestinationPath $extractTemp -Force

            # GitHub zip extracts to a subfolder like KJV-Strongs-EBook-main/
            $extractedDir = Join-Path $extractTemp "KJV-Strongs-EBook-main"
            if (Test-Path $extractedDir) {
                Get-ChildItem -Path $extractedDir -Force | ForEach-Object {
                    $destPath = Join-Path $Root $_.Name
                    if (Test-Path $destPath) {
                        Remove-Item -Recurse -Force $destPath -ErrorAction SilentlyContinue
                    }
                    Move-Item -Path $_.FullName -Destination $destPath -Force
                }
            }

            # Cleanup temp files
            Remove-Item -Force $zipPath -ErrorAction SilentlyContinue
            Remove-Item -Recurse -Force $extractTemp -ErrorAction SilentlyContinue

            Write-Status "bible" 25 "Generating Bible chapters..."

            $bibleOutput = & pwsh -NoProfile -NonInteractive -File $GenerateBibleScript -OutputRoot $Root -StatusFile $StatusFile 2>&1 | Out-String
            Write-Status "dict" 65 "Generating dictionary pages..."

            $dictOutput = & pwsh -NoProfile -NonInteractive -File $GenerateDictScript -OutDir (Join-Path $Root "dict") -IndexDir (Join-Path $Root "indexes") -StatusFile $StatusFile 2>&1 | Out-String
            Write-Status "rebake" 90 "Rebaking your notes..."

            if (Test-Path $RebakeScript) {
                & pwsh -NoProfile -NonInteractive -File $RebakeScript -ProjectRoot $Root 2>&1 | Out-Null
            }

            # Read the SHA that generate_bible.ps1 baked into pages so notes.js
            # can suppress the update badge from reappearing after reload.
            $newSha = ""
            $shaFile = Join-Path $Root "installed-sha.txt"
            if (Test-Path $shaFile) {
                try { $newSha = (Get-Content $shaFile -Raw -Encoding UTF8).Trim() } catch { }
            }

            Write-Status "complete" 100 "Update complete!" $true $false "" $newSha
        }
        catch {
            Write-Status "error" 0 "" $true $true $_.Exception.Message
        }
    } -ArgumentList $Root, $generateBibleScript, $generateDictScript, $rebakeScript, $UpdateStatusFile | Out-Null
}

# ── GET /api/update-status ───────────────────────────────────────
# Polled by the browser every ~1.5s while an update is running.

function Handle-UpdateStatus {
    param([System.Net.HttpListenerResponse]$Response)

    if (-not (Test-Path $UpdateStatusFile)) {
        Send-Json -Response $Response -Data @{
            step = "idle"; percent = 0; detail = ""; done = $false; error = $false
        }
        return
    }

    try {
        $raw = Get-Content -Path $UpdateStatusFile -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json
        Send-Json -Response $Response -Data $data
    } catch {
        Send-Json -Response $Response -Data @{
            step = "idle"; percent = 0; detail = ""; done = $false; error = $false
        }
    }
}

# ── GET /api/export-notes ────────────────────────────────────────
# Returns notes.json as a downloadable file with a timestamped filename.

function Handle-ExportNotes {
    param([System.Net.HttpListenerResponse]$Response)

    try {
        $notes      = Get-Notes
        $highlights = Get-Highlights

        $bundle = @{
            exportedAt = (Get-Date -Format "o")
            notes      = $notes
            highlights = $highlights
        }

        $json    = $bundle | ConvertTo-Json -Depth 6
        $content = [System.Text.Encoding]::UTF8.GetBytes($json)
        $stamp   = (Get-Date).ToString("yyyy-MM-dd")
        $filename = "kjv-notes-$stamp.json"

        $Response.StatusCode  = 200
        $Response.ContentType = "application/json"
        $Response.AddHeader("Content-Disposition", "attachment; filename=`"$filename`"")
        $Response.ContentLength64 = $content.Length
        $Response.OutputStream.Write($content, 0, $content.Length)
        $Response.OutputStream.Close()

        Write-Host "[EXPORT] Notes + highlights exported as $filename ($($content.Length) bytes)" -ForegroundColor Green
    }
    catch {
        Write-Host "[EXPORT ERROR] $_" -ForegroundColor Red
        Send-Error -Response $Response -StatusCode 500 `
            -Message "Export failed: $($_.Exception.Message)"
    }
}

# ── POST /api/import-notes/preview ───────────────────────────────
# Accepts an uploaded notes export (notes + highlights bundle, or a
# legacy notes-only file) and compares it against the current state.
# Returns a diff summary without writing anything — used to drive
# the conflict-resolution modal in the browser.

function Handle-ImportPreview {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try {
        $uploaded = $body | ConvertFrom-Json
    }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON file"
        return
    }

    # Support both the new bundle format { notes:{}, highlights:{} }
    # and the legacy flat notes.json format (just { "Gen.1.1": {...} })
    $importedNotes = @{}
    $importedHighlights = @{}

    if ($uploaded.PSObject.Properties.Name -contains "notes") {
        $uploaded.notes.PSObject.Properties | ForEach-Object { $importedNotes[$_.Name] = $_.Value }
        if ($uploaded.PSObject.Properties.Name -contains "highlights") {
            $uploaded.highlights.PSObject.Properties | ForEach-Object { $importedHighlights[$_.Name] = $_.Value }
        }
    } else {
        # Legacy flat format — treat the whole thing as notes
        $uploaded.PSObject.Properties | ForEach-Object { $importedNotes[$_.Name] = $_.Value }
    }

    $currentNotes      = Get-Notes
    $currentHighlights = Get-Highlights

    $newNotes       = @()
    $conflictNotes  = @()
    $unchangedNotes = 0

    foreach ($ref in $importedNotes.Keys) {
        $importedText = $importedNotes[$ref].text
        if (-not $currentNotes.ContainsKey($ref)) {
            $newNotes += $ref
        }
        elseif ($currentNotes[$ref].text -eq $importedText) {
            $unchangedNotes++
        }
        else {
            $conflictNotes += @{
                ref          = $ref
                currentText  = $currentNotes[$ref].text
                importedText = $importedText
            }
        }
    }

    $newHighlights      = @()
    $conflictHighlights = @()
    $unchangedHighlights = 0

    foreach ($ref in $importedHighlights.Keys) {
        $importedColor = $importedHighlights[$ref]
        if (-not $currentHighlights.ContainsKey($ref)) {
            $newHighlights += $ref
        }
        elseif ($currentHighlights[$ref] -eq $importedColor) {
            $unchangedHighlights++
        }
        else {
            $conflictHighlights += @{
                ref           = $ref
                currentColor  = $currentHighlights[$ref]
                importedColor = $importedColor
            }
        }
    }

    Send-Json -Response $Response -Data @{
        ok = $true
        notes = @{
            newCount       = $newNotes.Count
            conflictCount  = $conflictNotes.Count
            unchangedCount = $unchangedNotes
            conflicts      = $conflictNotes
        }
        highlights = @{
            newCount       = $newHighlights.Count
            conflictCount  = $conflictHighlights.Count
            unchangedCount = $unchangedHighlights
            conflicts      = $conflictHighlights
        }
    }
}

# ── POST /api/import-notes/commit ────────────────────────────────
# Applies the import using the user's conflict resolutions.
# Body: { bundle: {...uploaded file...}, resolutions: { "Gen.1.1": "imported"|"current", ... } }
# Any ref NOT in resolutions defaults to "imported" if new, or is
# skipped if it was already identical (unchanged).

function Handle-ImportCommit {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try {
        $payload = $body | ConvertFrom-Json
    }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON"
        return
    }

    $uploaded    = $payload.bundle
    $resolutions = @{}
    if ($payload.resolutions) {
        $payload.resolutions.PSObject.Properties | ForEach-Object { $resolutions[$_.Name] = $_.Value }
    }

    $importedNotes = @{}
    $importedHighlights = @{}

    if ($uploaded.PSObject.Properties.Name -contains "notes") {
        $uploaded.notes.PSObject.Properties | ForEach-Object { $importedNotes[$_.Name] = $_.Value }
        if ($uploaded.PSObject.Properties.Name -contains "highlights") {
            $uploaded.highlights.PSObject.Properties | ForEach-Object { $importedHighlights[$_.Name] = $_.Value }
        }
    } else {
        $uploaded.PSObject.Properties | ForEach-Object { $importedNotes[$_.Name] = $_.Value }
    }

    $currentNotes      = Get-Notes
    $currentHighlights = Get-Highlights

    $importedCount = 0
    $skippedCount  = 0
    $bakeRefs      = New-Object System.Collections.Generic.List[string]

    foreach ($ref in $importedNotes.Keys) {
        $useImported = $true
        if ($resolutions.ContainsKey($ref) -and $resolutions[$ref] -eq "current") {
            $useImported = $false
        }

        if ($useImported) {
            $existingCreated = if ($currentNotes.ContainsKey($ref) -and $currentNotes[$ref].created) { $currentNotes[$ref].created } else { (Get-Date -Format "o") }
            $currentNotes[$ref] = @{
                text    = $importedNotes[$ref].text
                created = $existingCreated
                updated = (Get-Date -Format "o")
            }
            $bakeRefs.Add($ref) | Out-Null
            $importedCount++
        } else {
            $skippedCount++
        }
    }
    Save-Notes -Notes $currentNotes

    foreach ($ref in $importedHighlights.Keys) {
        $useImported = $true
        if ($resolutions.ContainsKey("hl:$ref") -and $resolutions["hl:$ref"] -eq "current") {
            $useImported = $false
        }

        if ($useImported) {
            $currentHighlights[$ref] = $importedHighlights[$ref]
            $importedCount++
        } else {
            $skippedCount++
        }
    }
    Save-Highlights -Highlights $currentHighlights

    # Bake imported notes into chapter HTML immediately
    foreach ($ref in $bakeRefs) {
        Bake-Note -Ref $ref -NoteText $currentNotes[$ref].text | Out-Null
    }
    foreach ($ref in $importedHighlights.Keys) {
        Bake-Highlight -Ref $ref -Color $currentHighlights[$ref] | Out-Null
    }

    Write-Host "[IMPORT] Applied $importedCount item(s), skipped $skippedCount" -ForegroundColor Green

    Send-Json -Response $Response -Data @{
        ok       = $true
        imported = $importedCount
        skipped  = $skippedCount
    }
}

# ── GET /api/local-url ───────────────────────────────────────────
# Returns the PC's LAN IP so the phone can connect via WiFi QR code.

function Get-LanIp {
    try {
        # Prefer DHCP IPv4 addresses, exclude loopback (127.x) and link-local (169.254.x)
        $ip = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
              Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\.254\." } |
              Sort-Object { if ($_.PrefixOrigin -eq "Dhcp") { 0 } else { 1 } } |
              Select-Object -First 1 -ExpandProperty IPAddress
        if (-not $ip) {
            # Fallback: DNS resolution of hostname
            $ip = [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
                  Where-Object { $_.AddressFamily -eq "InterNetwork" -and $_.ToString() -notmatch "^127\." -and $_.ToString() -notmatch "^169\.254\." } |
                  Select-Object -First 1 |
                  ForEach-Object { $_.ToString() }
        }
        return $ip
    } catch {
        return $null
    }
}

function Handle-LocalUrl {
    param([System.Net.HttpListenerResponse]$Response)
    $ip = Get-LanIp
    if ($ip) {
        Send-Json -Response $Response -Data @{
            ok  = $true
            url = "http://${ip}:${Port}/"
            ip  = $ip
            port = $Port
        }
    } else {
        Send-Json -Response $Response -Data @{
            ok    = $false
            error = "Could not detect local IP address. Make sure your PC is connected to WiFi or Ethernet."
        }
    }
}

# ── POST /api/sync-notes ─────────────────────────────────────────
# Called by the phone when it connects to the PC's WiFi.
# Receives the phone's notes, highlights, and tombstones.
# Returns a diff/conflict report WITHOUT writing anything yet.
# The phone then either auto-commits (no conflicts) or shows
# the conflict-resolution modal before calling /api/sync-notes/commit.
#
# Also stores a pending sync token in a temp file so the commit
# endpoint can apply the correct merged result.

$SyncTokenFile = Join-Path $Root ".sync-token.json"

function Handle-SyncNotes {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try { $payload = $body | ConvertFrom-Json }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON"
        return
    }

    $lastSyncAt = if ($payload.lastSyncAt) { $payload.lastSyncAt } else { "" }

    # Load PC's current notes/highlights
    $pcNotes      = Get-Notes
    $pcHighlights = Get-Highlights

    # Parse phone data into hashtables
    $phoneNotes      = @{}
    $phoneHighlights = @{}
    $phoneTombstones = @{}

    if ($payload.phoneNotes) {
        $payload.phoneNotes.PSObject.Properties | ForEach-Object { $phoneNotes[$_.Name] = $_.Value }
    }
    if ($payload.phoneHighlights) {
        $payload.phoneHighlights.PSObject.Properties | ForEach-Object { $phoneHighlights[$_.Name] = $_.Value }
    }
    if ($payload.phoneTombstones) {
        $payload.phoneTombstones.PSObject.Properties | ForEach-Object { $phoneTombstones[$_.Name] = $_.Value }
    }

    # Build the union of all refs to consider
    $allNoteRefs = (@($pcNotes.Keys) + @($phoneNotes.Keys) + @($phoneTombstones.Keys | Where-Object { $_ -notlike "hl:*" })) | Sort-Object -Unique
    $allHlRefs   = (@($pcHighlights.Keys) + @($phoneHighlights.Keys) + @($phoneTombstones.Keys | Where-Object { $_ -like "hl:*" } | ForEach-Object { $_ -replace '^hl:', '' })) | Sort-Object -Unique

    # Classify each note ref — build the merged result and detect conflicts
    $mergedNotes  = @{}
    $noteConflicts = @()
    $noteStats = @{ auto = 0; conflicts = 0 }

    foreach ($ref in $allNoteRefs) {
        $pc    = if ($pcNotes.ContainsKey($ref))      { $pcNotes[$ref] }      else { $null }
        $phone = if ($phoneNotes.ContainsKey($ref))   { $phoneNotes[$ref] }  else { $null }
        $tomb  = if ($phoneTombstones.ContainsKey($ref)) { $phoneTombstones[$ref] } else { $null }

        if ($pc -and $phone) {
            $pcUpdated    = if ($pc.updated)    { $pc.updated }    else { "" }
            $phoneUpdated = if ($phone.updated) { $phone.updated } else { "" }
            $pcText    = if ($pc.text)    { $pc.text }    else { "" }
            $phoneText = if ($phone.text) { $phone.text } else { "" }

            if ($pcText -eq $phoneText) {
                # Identical — keep as-is
                $mergedNotes[$ref] = $pc
                $noteStats.auto++
            } elseif ($tomb) {
                # Phone deleted this note (tombstone) — PC still has it; deletion wins if newer
                if ($tomb.deletedAt -gt $pcUpdated) {
                    # Tombstone is newer — delete from PC
                    $noteStats.auto++
                } else {
                    # PC edit is newer — keep PC version; flag conflict
                    $noteConflicts += @{ ref = $ref; currentText = $pcText; importedText = "[deleted on phone]"; pcUpdated = $pcUpdated; phoneUpdated = $tomb.deletedAt }
                    $mergedNotes[$ref] = $pc
                    $noteStats.conflicts++
                }
            } elseif ($pcUpdated -gt $phoneUpdated) {
                # PC is newer — auto-resolve to PC
                $mergedNotes[$ref] = $pc
                $noteStats.auto++
            } elseif ($phoneUpdated -gt $pcUpdated) {
                # Phone is newer — auto-resolve to phone
                $mergedNotes[$ref] = @{ text = $phoneText; created = $phone.created; updated = $phone.updated }
                $noteStats.auto++
            } else {
                # Same timestamp, different text — true conflict
                $noteConflicts += @{ ref = $ref; currentText = $pcText; importedText = $phoneText; pcUpdated = $pcUpdated; phoneUpdated = $phoneUpdated }
                $mergedNotes[$ref] = $pc
                $noteStats.conflicts++
            }
        } elseif ($tomb -and -not $pc) {
            # Already deleted on phone and not on PC — nothing to do
            $noteStats.auto++
        } elseif ($tomb -and $pc) {
            # Phone deleted, PC has it — tombstone wins if newer
            if ($tomb.deletedAt -gt $pc.updated) {
                # Delete from PC
                $noteStats.auto++
            } else {
                # PC edit after deletion — conflict
                $noteConflicts += @{ ref = $ref; currentText = $pc.text; importedText = "[deleted on phone]" }
                $mergedNotes[$ref] = $pc
                $noteStats.conflicts++
            }
        } elseif ($pc -and -not $phone) {
            # Only on PC — add to phone
            $mergedNotes[$ref] = $pc
            $noteStats.auto++
        } elseif ($phone -and -not $pc) {
            # Only on phone — add to PC
            $mergedNotes[$ref] = @{ text = $phone.text; created = $phone.created; updated = $phone.updated }
            $noteStats.auto++
        }
    }

    # Classify each highlight ref
    $mergedHighlights = @{}
    $hlConflicts = @()

    foreach ($ref in $allHlRefs) {
        $pcColor    = if ($pcHighlights.ContainsKey($ref))    { $pcHighlights[$ref] }    else { $null }
        $phoneColor = if ($phoneHighlights.ContainsKey($ref)) { $phoneHighlights[$ref] } else { $null }
        $hlTomb     = if ($phoneTombstones.ContainsKey("hl:$ref")) { $phoneTombstones["hl:$ref"] } else { $null }

        if ($pcColor -and $phoneColor) {
            if ($pcColor -eq $phoneColor) {
                $mergedHighlights[$ref] = $pcColor
            } else {
                # Different colors — conflict
                $hlConflicts += @{ ref = $ref; currentColor = $pcColor; importedColor = $phoneColor }
                $mergedHighlights[$ref] = $pcColor
            }
        } elseif ($hlTomb -and $pcColor) {
            # Phone deleted highlight, PC has it — flag conflict
            $hlConflicts += @{ ref = $ref; currentColor = $pcColor; importedColor = "[removed on phone]" }
            $mergedHighlights[$ref] = $pcColor
        } elseif ($pcColor) {
            $mergedHighlights[$ref] = $pcColor
        } elseif ($phoneColor) {
            $mergedHighlights[$ref] = $phoneColor
        }
    }

    # Generate a sync token and store the pending merge result
    $syncToken = [System.Guid]::NewGuid().ToString()
    $pending = @{
        token          = $syncToken
        mergedNotes    = $mergedNotes
        mergedHighlights = $mergedHighlights
        noteConflicts  = $noteConflicts
        hlConflicts    = $hlConflicts
        createdAt      = (Get-Date -Format "o")
    }
    $pending | ConvertTo-Json -Depth 10 | Set-Content -Path $SyncTokenFile -Encoding UTF8

    Send-Json -Response $Response -Data @{
        ok        = $true
        syncToken = $syncToken
        autoResolved = $noteStats.auto
        conflicts = @{
            notes      = $noteConflicts
            highlights = $hlConflicts
        }
    }
}

# ── POST /api/sync-notes/commit ───────────────────────────────────
# Applies the sync merge using user's conflict resolutions.
# Body: { syncToken: "...", resolutions: { "Gen.1.1": "imported"|"current" } }

function Handle-SyncCommit {
    param(
        [System.Net.HttpListenerRequest]$Request,
        [System.Net.HttpListenerResponse]$Response
    )

    $reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
    $body = $reader.ReadToEnd()
    $reader.Close()

    try { $payload = $body | ConvertFrom-Json }
    catch {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid JSON"
        return
    }

    # Load and validate the pending sync token
    if (-not (Test-Path $SyncTokenFile)) {
        Send-Error -Response $Response -StatusCode 400 -Message "No pending sync found"
        return
    }

    $pending = Get-Content -Path $SyncTokenFile -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($pending.token -ne $payload.syncToken) {
        Send-Error -Response $Response -StatusCode 400 -Message "Invalid sync token"
        return
    }

    # Parse resolutions
    $resolutions = @{}
    if ($payload.resolutions) {
        $payload.resolutions.PSObject.Properties | ForEach-Object { $resolutions[$_.Name] = $_.Value }
    }

    # Apply resolutions to conflicts
    $mergedNotes      = @{}
    $mergedHighlights = @{}
    $importedCount    = 0

    # Notes
    $pending.mergedNotes.PSObject.Properties | ForEach-Object {
        $ref = $_.Name
        $val = $_.Value
        if ($resolutions.ContainsKey($ref) -and $resolutions[$ref] -eq "current") {
            # User chose to keep PC version — use existing PC note
            $existing = Get-Notes
            if ($existing.ContainsKey($ref)) { $mergedNotes[$ref] = $existing[$ref] }
        } else {
            $mergedNotes[$ref] = $val
        }
        $importedCount++
    }

    # Highlights
    $pending.mergedHighlights.PSObject.Properties | ForEach-Object {
        $ref = $_.Name
        $color = $_.Value
        if ($resolutions.ContainsKey("hl:$ref") -and $resolutions["hl:$ref"] -eq "current") {
            $existing = Get-Highlights
            if ($existing.ContainsKey($ref)) { $mergedHighlights[$ref] = $existing[$ref] }
        } else {
            $mergedHighlights[$ref] = $color
        }
        $importedCount++
    }

    # Save merged results to PC
    Save-Notes -Notes $mergedNotes
    Save-Highlights -Highlights $mergedHighlights

    # Rebake all notes into HTML
    foreach ($ref in $mergedNotes.Keys) {
        Bake-Note -Ref $ref -NoteText $mergedNotes[$ref].text | Out-Null
    }
    foreach ($ref in $mergedHighlights.Keys) {
        Bake-Highlight -Ref $ref -Color $mergedHighlights[$ref] | Out-Null
    }

    # Clean up pending token
    Remove-Item -Path $SyncTokenFile -Force -ErrorAction SilentlyContinue

    Write-Host "[SYNC] Committed sync: $importedCount item(s)" -ForegroundColor Green

    Send-Json -Response $Response -Data @{
        ok               = $true
        imported         = $importedCount
        mergedNotes      = $mergedNotes
        mergedHighlights = $mergedHighlights
        syncedAt         = (Get-Date -Format "o")
    }
}

# ── POST /api/rebake ─────────────────────────────────────────────
# Re-bakes notes.json and highlights.json into chapter HTML by
# invoking rebake-notes.ps1 as a subprocess.

function Handle-Rebake {
    param([System.Net.HttpListenerResponse]$Response)

    Write-Host "[REBAKE] Starting rebake..." -ForegroundColor Magenta

    $rebakeScript = Join-Path $Root "scripts\rebake-notes.ps1"

    if (-not (Test-Path $rebakeScript)) {
        Write-Host "  [ERROR] rebake-notes.ps1 not found" -ForegroundColor Red
        Send-Error -Response $Response -StatusCode 500 `
            -Message "rebake-notes.ps1 not found at $rebakeScript"
        return
    }

    try {
        $output = & pwsh -NoProfile -NonInteractive -File $rebakeScript `
            -ProjectRoot $Root 2>&1 | Out-String

        Write-Host $output -ForegroundColor Gray

        $notesCount = 0
        $hlCount = 0

        if ($output -match "Notes baked\s*:\s*(\d+)") {
            $notesCount = [int]$Matches[1]
        }
        if ($output -match "Highlights baked\s*:\s*(\d+)") {
            $hlCount = [int]$Matches[1]
        }

        Write-Host "  [REBAKE] Done: $notesCount notes, $hlCount highlights" -ForegroundColor Magenta

        Send-Json -Response $Response -Data @{
            ok                = $true
            notesRebaked      = $notesCount
            highlightsRebaked = $hlCount
        }
    }
    catch {
        Write-Host "  [ERROR] Rebake failed: $_" -ForegroundColor Red
        Send-Error -Response $Response -StatusCode 500 `
            -Message "Rebake failed: $($_.Exception.Message)"
    }
}


# ── POST /api/test-sync ────────────────────────────────────────
# Simulates a slow sync for testing the modal UI (5 second delay)

function Handle-TestSync {
    param([System.Net.HttpListenerResponse]$Response)
    Write-Host "[TEST-SYNC] Simulating sync (5 second delay)..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
    $result = @{
        ok     = $true
        pushed = 42
        files  = @("books/01-Gen/1.html", "books/43-John/3.html", "css/style.css")
    }
    Write-Host "[TEST-SYNC] Done." -ForegroundColor Yellow
    Send-Json -Response $Response -Data $result
}

# ================================================================
# start-study.ps1 — KJV Strong's Bible PC Study Server
# ================================================================
# PowerShell 7+ (pwsh)
#
# Starts a local HTTP server on localhost:8080 that:
#   1. Serves static HTML/CSS/JS files from the project root
#   2. Handles note API endpoints (save, edit, delete, list)
#   3. Bakes notes into chapter HTML files on every save/delete
#   4. Syncs modified files to Kindle via ADB
#
# Usage:
#   pwsh -File start-study.ps1
#   Or double-click start-study.bat
#
# ================================================================


# ================================================================
# Static File Server
# ================================================================

function Handle-StaticFile {
    param(
        [string]$UrlPath,
        [System.Net.HttpListenerResponse]$Response
    )

    # Map URL path to file path
    $relPath = $UrlPath.TrimStart("/").Replace("/", "\")
    if ($relPath -eq "" -or $relPath -eq "\") { $relPath = "index.html" }

    $filePath = Join-Path $Root $relPath

    # Security: prevent directory traversal
    $resolvedPath = [System.IO.Path]::GetFullPath($filePath)
    if (-not $resolvedPath.StartsWith($Root)) {
        Send-Error -Response $Response -StatusCode 403 -Message "Forbidden"
        return
    }

    # If path is a directory, try index.html
    if (Test-Path $filePath -PathType Container) {
        $filePath = Join-Path $filePath "index.html"
    }

    if (-not (Test-Path $filePath -PathType Leaf)) {
        Send-Error -Response $Response -StatusCode 404 -Message "File not found: $UrlPath"
        return
    }

    # Determine MIME type
    $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
    $contentType = if ($MimeTypes.ContainsKey($ext)) { $MimeTypes[$ext] } else { "application/octet-stream" }

    # Read and send file
    $bytes = [System.IO.File]::ReadAllBytes($filePath)
    Send-Response -Response $Response -StatusCode 200 `
        -ContentType $contentType -Body $bytes
}


# ================================================================
# Main Server Loop
# ================================================================

# Create HTTP listener on localhost.
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($BaseUrl)

try {
    $listener.Start()
}
catch {
    Write-Host "ERROR: Cannot start server on $BaseUrl" -ForegroundColor Red
    Write-Host "       Is another process using port $Port?" -ForegroundColor Red
    Write-Host "       Error: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "  KJV Strong's Bible — PC Study Server" -ForegroundColor Cyan
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Server running at:  $BaseUrl" -ForegroundColor Green
Write-Host "  Project root:       $Root" -ForegroundColor Gray
Write-Host "  Notes file:         $NotesFile" -ForegroundColor Gray
Write-Host ""
Write-Host "  Press Ctrl+C to stop the server." -ForegroundColor Yellow
Write-Host ""

# Open browser — only when running standalone (not from Electron launcher).
# The Electron app sets KJV_LAUNCHER=1 before spawning this server,
# so we skip Start-Process when that env var is present (Electron handles the window).
if ($env:KJV_LAUNCHER -ne "1") {
    try {
        Start-Process $BaseUrl
        Write-Host "  Browser opened." -ForegroundColor Green
    }
    catch {
        Write-Host "  Could not open browser. Navigate to $BaseUrl manually." -ForegroundColor Yellow
    }
} else {
    Write-Host "  Running inside launcher — skipping browser open." -ForegroundColor Gray
}

Write-Host ""

# Main request loop
try {
    while ($listener.IsListening) {
        # Wait for incoming request
        $context  = $listener.GetContext()
        $request  = $context.Request
        $response = $context.Response

        $method = $request.HttpMethod
        $path   = $request.Url.AbsolutePath

        # ── IP Allowlist ──────────────────────────────────────────────
        # Allow localhost (127.x) and local LAN subnet (192.168.x.x and 10.x.x.x).
        # Reject everything else with 403 to prevent access from outside the network.
        $remoteIp = $request.RemoteEndPoint.Address.ToString()
        $isAllowed = $remoteIp -match "^127\." -or          # loopback
                     $remoteIp -match "^192\.168\." -or     # class C private
                     $remoteIp -match "^10\." -or           # class A private
                     $remoteIp -match "^172\.(1[6-9]|2[0-9]|3[01])\."  # class B private
        if (-not $isAllowed) {
            Write-Host "  [BLOCKED] Request from $remoteIp rejected." -ForegroundColor Red
            Send-Error -Response $response -StatusCode 403 -Message "Forbidden"
            continue
        }

        # Log request
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] $method $path from $remoteIp" -ForegroundColor Gray

        try {
            # ── Route API requests ────────────────────────────────
            if ($path -eq "/api/notes" -and $method -eq "GET") {
                Handle-GetNotes -Response $response
            }
            elseif ($path -eq "/api/notes" -and $method -eq "POST") {
                Handle-SaveNote -Request $request -Response $response
            }
            elseif ($path -match "^/api/notes/(.+)$" -and $method -eq "DELETE") {
                $ref = [System.Web.HttpUtility]::UrlDecode($Matches[1])
                Handle-DeleteNote -Ref $ref -Response $response
            }
            elseif ($path -eq "/api/highlights" -and $method -eq "GET") {
                Handle-GetHighlights -Response $response
            }
            elseif ($path -eq "/api/highlights" -and $method -eq "POST") {
                Handle-SaveHighlight -Request $request -Response $response
            }
            elseif ($path -match "^/api/highlights/(.+)$" -and $method -eq "DELETE") {
                $ref = [System.Web.HttpUtility]::UrlDecode($Matches[1])
                Handle-DeleteHighlight -Ref $ref -Response $response
            }
            elseif ($path -eq "/api/kindle-status" -and $method -eq "GET") {
                $status = Get-KindleStatus
                Send-Json -Response $Response -Data $status
            }
            elseif ($path -eq "/api/sync-kindle" -and $method -eq "POST") {
                Handle-SyncKindle -Response $response
            }
            elseif ($path -eq "/api/rebake" -and $method -eq "POST") {
                Handle-Rebake -Response $response
            }
            elseif ($path -eq "/api/export-notes" -and $method -eq "GET") {
                Handle-ExportNotes -Response $response
            }
            elseif ($path -eq "/api/import-notes/preview" -and $method -eq "POST") {
                Handle-ImportPreview -Request $request -Response $response
            }
            elseif ($path -eq "/api/import-notes/commit" -and $method -eq "POST") {
                Handle-ImportCommit -Request $request -Response $response
            }
            elseif ($path -eq "/api/sync-notes" -and $method -eq "POST") {
                Handle-SyncNotes -Request $request -Response $response
            }
            elseif ($path -eq "/api/sync-notes/commit" -and $method -eq "POST") {
                Handle-SyncCommit -Request $request -Response $response
            }
            elseif ($path -eq "/api/local-url" -and $method -eq "GET") {
                Handle-LocalUrl -Response $response
            }
            elseif ($path -eq "/api/update" -and $method -eq "POST") {
                Handle-Update -Response $response
            }
            elseif ($path -eq "/api/update-status" -and $method -eq "GET") {
                Handle-UpdateStatus -Response $response
            }
            elseif ($path -eq "/api/test-sync" -and $method -eq "POST") {
                Handle-TestSync -Response $response
            }
            # ── Serve static files ────────────────────────────────
            else {
                Handle-StaticFile -UrlPath $path -Response $response
            }
        }
        catch {
            Write-Host "  [ERROR] $($_.Exception.Message)" -ForegroundColor Red
            try {
                Send-Error -Response $response -StatusCode 500 `
                    -Message $_.Exception.Message
            }
            catch {
                # Response may already be closed
            }
        }
    }
}
finally {
    Write-Host ""
    Write-Host "Shutting down server..." -ForegroundColor Yellow
    $listener.Stop()
    $listener.Close()
    Write-Host "Server stopped." -ForegroundColor Green
}
