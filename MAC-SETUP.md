# KJV Strong's Bible — Mac Setup Guide

This guide walks through setting up the KJV Strong's Bible study tool on macOS.
All the PowerShell scripts work identically on Mac since they use PowerShell Core (pwsh),
which is fully cross-platform.

---

## Prerequisites

### 1. Install Homebrew (Mac package manager)
If you don't have Homebrew installed, open Terminal and run:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 2. Install PowerShell Core
```bash
brew install powershell
```
Verify it works:
```bash
pwsh --version
```
You should see `PowerShell 7.x.x` or higher.

### 3. Install ADB (Android Debug Bridge)
Required for pushing files to the Kindle Fire via USB.
```bash
brew install android-platform-tools
```
Verify:
```bash
adb version
```

---

## Project Setup

### 1. Clone the repository
```bash
git clone https://github.com/RonTurrentine/KJV-Strongs-EBook.git
cd KJV-Strongs-EBook
```

### 2. Download required source files
The following files are NOT included in the repository (too large) and must be
obtained separately:

- **`kjv.osis.xml`** (~28MB) — KJV Bible in OSIS format with Strong's numbers
  - Source: https://github.com/openscriptures/morphhb or similar OSIS repository
- **`StrongHebrewG.xml`** (~6MB) — Hebrew Strong's lexicon
- **`strongsgreek.xml`** (~2MB) — Greek Strong's lexicon
- **`bdb-thayer.dct.mybible`** — BDB/Thayer lexicon (SQLite database)
  - Source: MyBible app dictionary downloads

Place all four files in the project root directory.

### 3. Download SQLite tools
Required for exporting the BDB/Thayer lexicon:
```bash
brew install sqlite
```

---

## Script Path Adjustments for Mac

The scripts use Windows-style paths in a few places that need updating for Mac.

### ADB path
On Windows: `H:\Android SDK Platform Tools\adb.exe`
On Mac: `adb` (just the command name, since it's in PATH via Homebrew)

Edit these scripts and change the ADB path:
- `scripts/adb-push-all.ps1` — change `$AdbPath` default value
- `scripts/package_epub.ps1` — change `$AdbPath` default value
- `start-study.ps1` — change `$adbPath` in `Get-KindleStatus` and `Handle-SyncKindle`

**Find and replace in each file:**
```
Old: H:\Android SDK Platform Tools\adb.exe
New: adb
```

### Project root path
On Windows: `C:\Users\OldTi\KJV-Strongs`
On Mac: `/Users/yourname/KJV-Strongs` (or wherever you cloned it)

The scripts use `$PSScriptRoot` to find paths relatively, so most will work
automatically. The main exception is `start-study.ps1` which has a hardcoded
project root — update it to match your Mac path.

### SQLite path
On Windows: `H:\SQLiteTools\sqlite3.exe`
On Mac: `sqlite3` (in PATH via Homebrew)

Edit `scripts/export-bdb.ps1`:
```
Old: [string]$Sqlite3 = 'H:\SQLiteTools\sqlite3.exe'
New: [string]$Sqlite3 = 'sqlite3'
```

---

## Generation Steps

Run these commands in order from the project root directory:

```bash
cd ~/KJV-Strongs

# 1. Export BDB/Thayer lexicon (one-time setup)
pwsh -NoProfile -File ./scripts/export-bdb.ps1

# 2. Generate Bible chapter pages + concordance
pwsh -NoProfile -File ./scripts/generate_bible.ps1

# 3. Generate dictionary pages with BDB definitions + concordance
pwsh -NoProfile -File ./scripts/generate_dict.ps1

# 4. Run QA tests
pwsh -NoProfile -File ./scripts/qa-test.ps1

# 5. Rebake personal notes (if you have any)
pwsh -NoProfile -File ./scripts/rebake-notes.ps1
```

---

## Running the Study Server

```bash
cd ~/KJV-Strongs
pwsh -NoProfile -File ./start-study.ps1
```

This starts the local server at `http://localhost:8080` and opens your browser
automatically. Use Chrome or Firefox for best results.

To stop the server: press **Ctrl+C** in the Terminal window.

---

## Pushing to Kindle Fire

Connect your Kindle Fire via USB, enable ADB debugging, then:

```bash
# Full push (all 15,000+ files — takes 15-30 minutes)
pwsh -NoProfile -File ./scripts/package_epub.ps1

# Or use adb-push-all for a simpler push
pwsh -NoProfile -File ./scripts/adb-push-all.ps1
```

On the Kindle, open Silk browser and navigate to:
`file:///data/local/tmp/index.html`

---

## Troubleshooting

**"pwsh: command not found"**
PowerShell wasn't installed correctly. Try: `brew reinstall powershell`

**"adb: command not found"**
ADB wasn't installed. Try: `brew reinstall android-platform-tools`

**ADB device not found**
- Enable Developer Options on Kindle: Settings → Device Options → tap Serial Number 7 times
- Enable ADB: Developer Options → Enable ADB
- Trust the computer when prompted on Kindle screen
- Verify connection: `adb devices`

**Permission denied on scripts**
```bash
chmod +x scripts/*.ps1
```

**Port 8080 already in use**
```bash
lsof -i :8080
kill -9 <PID>
```

---

## Key Differences from Windows

| Feature | Windows | Mac |
|---------|---------|-----|
| PowerShell | `pwsh` or `powershell` | `pwsh` |
| ADB path | `H:\Android SDK Platform Tools\adb.exe` | `adb` |
| SQLite path | `H:\SQLiteTools\sqlite3.exe` | `sqlite3` |
| Path separator | `\` | `/` |
| Project root | `C:\Users\Name\KJV-Strongs` | `/Users/name/KJV-Strongs` |
| Line endings | CRLF | LF (git handles this) |

---

*Generated for KJV Strong's Bible study tool — https://github.com/RonTurrentine/KJV-Strongs-EBook*
