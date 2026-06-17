# export-bdb.ps1
# Exports bdb-thayer.dct.mybible SQLite database to bdb-thayer.json
# Uses sqlite3.exe for proper UTF-8 handling
#
# Usage: pwsh -NoProfile -File .\scripts\export-bdb.ps1

param(
    [string]$DbPath      = 'C:\Users\OldTi\KJV-Strongs\bdb-thayer.dct.mybible',
    [string]$OutputPath  = 'C:\Users\OldTi\KJV-Strongs\bdb-thayer.json',
    [string]$Sqlite3     = 'H:\SQLiteTools\sqlite3.exe'
)

Write-Host "Exporting BDB/Thayer lexicon to JSON..." -ForegroundColor Cyan

# Export to JSON using sqlite3's built-in JSON mode
$query = "SELECT json_object('word', word, 'data', data) FROM dictionary;"

$lines = & $Sqlite3 $DbPath $query 2>&1

if (-not $lines) {
    Write-Host "ERROR: No data returned from database" -ForegroundColor Red
    exit 1
}

# Wrap individual JSON objects into a single array
$json = "[`n" + ($lines -join ",`n") + "`n]"

# Write with UTF-8 encoding (no BOM)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutputPath, $json, $utf8NoBom)

$count = ($lines | Measure-Object).Count
Write-Host "Exported $count entries to $OutputPath" -ForegroundColor Green

# Verify a sample entry
Write-Host "Sample entry (H1121):" -ForegroundColor Cyan
$sample = & $Sqlite3 $DbPath "SELECT data FROM dictionary WHERE word='H1121';" 2>&1
Write-Host ($sample | Select-Object -First 1) -ForegroundColor Gray
