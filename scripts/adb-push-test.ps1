# adb-push-test.ps1
# Pushes a minimal test set to the Kindle Fire via ADB.
# Pushes style-kindle.css AS style.css so chapter HTML references resolve.
#
# Usage: pwsh -NoProfile -File .\adb-push-test.ps1

param(
    [string]$AdbPath    = 'H:\Android SDK Platform Tools\adb.exe',
    [string]$KindleRoot = '/data/local/tmp',
    [string]$ProjectRoot = 'C:\Users\OldTi\KJV-Strongs'
)

Set-Location $ProjectRoot

function AdbPush([string]$local, [string]$remote) {
    Write-Host "Pushing $local..." -ForegroundColor Cyan
    & $AdbPath push $local "$KindleRoot/$remote"
}

Write-Host "Creating directories on Kindle..." -ForegroundColor Yellow
& $AdbPath shell mkdir $KindleRoot/css
& $AdbPath shell mkdir $KindleRoot/js
& $AdbPath shell mkdir $KindleRoot/books
& $AdbPath shell mkdir $KindleRoot/books/01-Gen
& $AdbPath shell mkdir $KindleRoot/books/08-Ruth
& $AdbPath shell mkdir $KindleRoot/books/43-John
& $AdbPath shell mkdir $KindleRoot/dict
& $AdbPath shell mkdir $KindleRoot/dict/hebrew
& $AdbPath shell mkdir $KindleRoot/dict/greek
& $AdbPath shell mkdir $KindleRoot/xrefs

Write-Host "Pushing CSS (Kindle version as style.css)..." -ForegroundColor Yellow
AdbPush 'css/style-kindle.css' 'css/style.css'

Write-Host "Pushing JS..." -ForegroundColor Yellow
AdbPush 'js/bible-data.js'     'js/bible-data.js'
AdbPush 'js/fontsize.js'       'js/fontsize.js'
AdbPush 'js/bookmarks.js'      'js/bookmarks.js'
AdbPush 'js/sticky-header.js'  'js/sticky-header.js'

Write-Host "Pushing navigation pages..." -ForegroundColor Yellow
AdbPush 'index.html'            'index.html'
AdbPush 'navigate.html'         'navigate.html'

Write-Host "Pushing sample chapters..." -ForegroundColor Yellow
AdbPush 'books/01-Gen/1.html'   'books/01-Gen/1.html'
AdbPush 'books/01-Gen/50.html'  'books/01-Gen/50.html'
AdbPush 'books/08-Ruth/1.html'  'books/08-Ruth/1.html'
AdbPush 'books/08-Ruth/4.html'  'books/08-Ruth/4.html'
AdbPush 'books/43-John/1.html'  'books/43-John/1.html'
AdbPush 'books/43-John/3.html'  'books/43-John/3.html'

Write-Host "Pushing sample dictionary pages..." -ForegroundColor Yellow
AdbPush 'dict/hebrew/h0430.html' 'dict/hebrew/h0430.html'
AdbPush 'dict/hebrew/h1162.html' 'dict/hebrew/h1162.html'
AdbPush 'dict/greek/g3056.html'  'dict/greek/g3056.html'
AdbPush 'dict/greek/g4151.html'  'dict/greek/g4151.html'

Write-Host ""
Write-Host "=====================================" -ForegroundColor Green
Write-Host " ADB push complete!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Green
Write-Host " Open Silk browser on Kindle and go to:" -ForegroundColor Yellow
Write-Host " file:///data/local/tmp/index.html" -ForegroundColor White