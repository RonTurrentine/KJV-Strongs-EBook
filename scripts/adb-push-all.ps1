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

# adb-push-all.ps1
# Pushes the complete KJV Strong's Bible to the Kindle Fire via ADB.
# Includes all chapter pages, all dictionary pages, index pages,
# navigation pages, CSS, JS, and indexes.
#
# NOTE: This pushes style-kindle.css AS style.css so all HTML
# references resolve correctly on the Kindle.
#
# Usage: pwsh -NoProfile -File .\adb-push-all.ps1

param(
    [string]$AdbPath     = 'H:\Android SDK Platform Tools\adb.exe',
    [string]$KindleRoot  = '/data/local/tmp',
    [string]$ProjectRoot = 'C:\Users\OldTi\KJV-Strongs'
)

Set-Location $ProjectRoot

$env:PATH += ';H:\Android SDK Platform Tools'

function AdbPush([string]$local, [string]$remote) {
    & $AdbPath push $local "$KindleRoot/$remote" 2>&1 | Out-Null
}

function AdbMkdir([string]$path) {
    & $AdbPath shell mkdir "$KindleRoot/$path" 2>&1 | Out-Null
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " KJV Strong's — Full Kindle Push" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# ── Create directory structure ───────────────────────────────────

Write-Host "Creating directories..." -ForegroundColor Yellow
AdbMkdir "css"
AdbMkdir "js"
AdbMkdir "indexes"
AdbMkdir "dict"
AdbMkdir "dict/hebrew"
AdbMkdir "dict/greek"
AdbMkdir "xrefs"

# Create book directories
$bookDirs = Get-ChildItem -Path "books" -Directory
foreach ($dir in $bookDirs) {
    AdbMkdir "books/$($dir.Name)"
}

Write-Host "  Directories created." -ForegroundColor Green

# ── CSS ──────────────────────────────────────────────────────────

Write-Host "Pushing CSS..." -ForegroundColor Yellow
AdbPush "css/style-kindle.css" "css/style.css"
Write-Host "  CSS pushed (style-kindle.css as style.css)." -ForegroundColor Green

# ── JS ───────────────────────────────────────────────────────────

Write-Host "Pushing JS..." -ForegroundColor Yellow
AdbPush "js/bible-data.js"    "js/bible-data.js"
AdbPush "js/fontsize.js"      "js/fontsize.js"
AdbPush "js/bookmarks.js"     "js/bookmarks.js"
AdbPush "js/sticky-header.js" "js/sticky-header.js"
Write-Host "  JS pushed." -ForegroundColor Green

# ── Navigation pages ─────────────────────────────────────────────

Write-Host "Pushing navigation pages..." -ForegroundColor Yellow
AdbPush "index.html"    "index.html"
AdbPush "navigate.html" "navigate.html"
Write-Host "  Navigation pages pushed." -ForegroundColor Green

# ── Index pages ──────────────────────────────────────────────────

Write-Host "Pushing Strong's index pages..." -ForegroundColor Yellow
AdbPush "indexes/strongs-hebrew-index.html" "indexes/strongs-hebrew-index.html"
AdbPush "indexes/strongs-greek-index.html"  "indexes/strongs-greek-index.html"
Write-Host "  Index pages pushed." -ForegroundColor Green

# ── Chapter pages ────────────────────────────────────────────────

Write-Host "Pushing chapter pages (1,189 files)..." -ForegroundColor Yellow
$chapterCount = 0
$bookDirs = Get-ChildItem -Path "books" -Directory | Sort-Object Name
foreach ($bookDir in $bookDirs) {
    $chapters = Get-ChildItem -Path $bookDir.FullName -Filter "*.html" |
                Sort-Object { [int]($_.BaseName) }
    foreach ($ch in $chapters) {
        AdbPush "books/$($bookDir.Name)/$($ch.Name)" "books/$($bookDir.Name)/$($ch.Name)"
        $chapterCount++
    }
    Write-Host "  $($bookDir.Name) done ($chapterCount chapters pushed so far)..." -ForegroundColor Gray
}
Write-Host "  All $chapterCount chapter pages pushed." -ForegroundColor Green

# ── Hebrew dictionary ────────────────────────────────────────────

Write-Host "Pushing Hebrew dictionary (8,674 files)..." -ForegroundColor Yellow
$hebFiles = Get-ChildItem -Path "dict/hebrew" -Filter "*.html" | Sort-Object Name
$count = 0
foreach ($f in $hebFiles) {
    AdbPush "dict/hebrew/$($f.Name)" "dict/hebrew/$($f.Name)"
    $count++
    if ($count % 250 -eq 0) {
        Write-Host "  Hebrew: $count files pushed..." -ForegroundColor Gray
    }
}
Write-Host "  Hebrew dictionary done ($count files)." -ForegroundColor Green

# ── Greek dictionary ─────────────────────────────────────────────

Write-Host "Pushing Greek dictionary (5,624 files)..." -ForegroundColor Yellow
$grkFiles = Get-ChildItem -Path "dict/greek" -Filter "*.html" | Sort-Object Name
$count = 0
foreach ($f in $grkFiles) {
    AdbPush "dict/greek/$($f.Name)" "dict/greek/$($f.Name)"
    $count++
    if ($count % 250 -eq 0) {
        Write-Host "  Greek: $count files pushed..." -ForegroundColor Gray
    }
}
Write-Host "  Greek dictionary done ($count files)." -ForegroundColor Green

# ── Done ─────────────────────────────────────────────────────────

$stopwatch.Stop()
$elapsed = $stopwatch.Elapsed
$mins    = [int]$elapsed.TotalMinutes
$secs    = $elapsed.Seconds

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Full push complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Time elapsed : $mins min $secs sec" -ForegroundColor Yellow
Write-Host " Chapter pages: $chapterCount" -ForegroundColor Yellow
Write-Host " Dict (Hebrew): $($hebFiles.Count)" -ForegroundColor Yellow
Write-Host " Dict (Greek) : $($grkFiles.Count)" -ForegroundColor Yellow
Write-Host ""
Write-Host " Open Silk browser on Kindle and go to:" -ForegroundColor Cyan
Write-Host " file:///data/local/tmp/index.html" -ForegroundColor White
Write-Host ""
