# export-bdb.ps1
# Exports bdb-thayer.dct.mybible to bdb-thayer.json
# Uses individual queries to avoid sqlite3 JSON mode truncation
#
# Usage: pwsh -NoProfile -File .\scripts\export-bdb.ps1

param(
    [string]$DbPath     = 'C:\Users\OldTi\KJV-Strongs\bdb-thayer.dct.mybible',
    [string]$OutputPath = 'C:\Users\OldTi\KJV-Strongs\bdb-thayer.json',
    [string]$Sqlite3    = 'H:\SQLiteTools\sqlite3.exe'
)

Write-Host "Exporting BDB/Thayer lexicon..." -ForegroundColor Cyan

# Get all words
$words = & $Sqlite3 $DbPath ".headers off" ".mode list" "SELECT word FROM dictionary ORDER BY rowid;"
Write-Host "  Found $($words.Count) entries" -ForegroundColor Green

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$stream = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
$writer = New-Object System.IO.StreamWriter($stream, $utf8NoBom)
$writer.Write("[")

$count = 0
foreach ($word in $words) {
    # Query each entry individually - no truncation
    $data = & $Sqlite3 $DbPath ".headers off" ".mode list" "SELECT data FROM dictionary WHERE word='$($word -replace "'","''")';"
    
    # Join multi-line output
    $dataStr = $data -join ""
    
    # Escape for JSON
    $dataStr = $dataStr -replace '\\', '\\' -replace '"', '\"' -replace "`r", '' -replace "`n", '\n' -replace "`t", '\t'
    
    if ($count -gt 0) { $writer.Write(",") }
    $writer.Write("{""word"":""$word"",""data"":""$dataStr""}")
    
    $count++
    if ($count % 1000 -eq 0) {
        Write-Host "  Exported $count / $($words.Count)..." -ForegroundColor Gray
        $writer.Flush()
    }
}

$writer.Write("]")
$writer.Close()
$stream.Close()

$size = (Get-Item $OutputPath).Length
Write-Host "Done! $count entries, $([Math]::Round($size/1MB,1)) MB" -ForegroundColor Green

# Verify one entry
Write-Host "Verifying H1121..." -ForegroundColor Cyan
$verify = & $Sqlite3 $DbPath "SELECT length(data) FROM dictionary WHERE word='H1121';"
Write-Host "  DB length: $verify chars" -ForegroundColor Gray
$content = [System.IO.File]::ReadAllText($OutputPath, $utf8NoBom)
$idx = $content.IndexOf('"H1121"')
if ($idx -ge 0) {
    $snippet = $content.Substring($idx, [Math]::Min(200, $content.Length - $idx))
    Write-Host "  JSON preview: $snippet" -ForegroundColor Gray
}
