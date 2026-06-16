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

param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"

# ── Configuration ────────────────────────────────────────────────

$Root       = $PSScriptRoot
$NotesFile  = Join-Path $Root "notes.json"
$SyncState  = Join-Path $Root ".last-sync"
$AdbPath    = "H:\Android SDK Platform Tools\adb.exe"
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
    $escaped = ConvertTo-HtmlEncoded -Text $NoteText
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"

    $html = Get-Content -Path $filePath -Raw -Encoding UTF8

    # Regex: match the note-verse-N div (empty or filled)
    $pattern = "(?s)(<div class=`"verse-note`" id=`"note-verse-$verseNum`">).*?(</div>)"
    $replacement = "`$1`n  <p class=`"verse-note-text`">$escaped</p>`n  <p class=`"verse-note-meta`">Note saved: $timestamp</p>`n`$2"

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

# ── POST /api/sync-kindle ─────────────────────────────────────

function Handle-SyncKindle {
    param([System.Net.HttpListenerResponse]$Response)

    Write-Host "[SYNC] Starting Kindle sync..." -ForegroundColor Magenta

    # Check ADB exists
    if (-not (Test-Path $AdbPath)) {
        Write-Host "  [ERROR] ADB not found at: $AdbPath" -ForegroundColor Red
        Send-Error -Response $Response -StatusCode 500 `
            -Message "ADB not found at $AdbPath"
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

# Create HTTP listener
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

# Open browser
try {
    Start-Process $BaseUrl
    Write-Host "  Browser opened." -ForegroundColor Green
}
catch {
    Write-Host "  Could not open browser. Navigate to $BaseUrl manually." -ForegroundColor Yellow
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

        # Log request
        $timestamp = Get-Date -Format "HH:mm:ss"
        Write-Host "[$timestamp] $method $path" -ForegroundColor Gray

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
            elseif ($path -eq "/api/sync-kindle" -and $method -eq "POST") {
                Handle-SyncKindle -Response $response
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
