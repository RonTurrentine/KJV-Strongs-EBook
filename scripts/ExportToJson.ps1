cd 'C:\Users\OldTi\KJV-Strongs'

# Download SQLite DLL via NuGet (no installer needed)
$nugetUrl = "https://www.nuget.org/api/v2/package/System.Data.SQLite/1.0.118"
Invoke-WebRequest -Uri $nugetUrl -OutFile "sqlite-nuget.zip"

# Extract just the DLL we need
Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [System.IO.Compression.ZipFile]::OpenRead("sqlite-nuget.zip")
$dll = $zip.Entries | Where-Object { $_.FullName -match "net46.*System\.Data\.SQLite\.dll$" } | Select-Object -First 1
[System.IO.Compression.ZipFileExtensions]::ExtractToFile($dll, "System.Data.SQLite.dll", $true)
$zip.Dispose()

Write-Host "SQLite DLL ready"