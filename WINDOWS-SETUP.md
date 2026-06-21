# KJV Strong's Bible — Windows Setup Guide

This guide walks through setting up the KJV Strong's Bible study tool on Windows.

---

## Prerequisites

### 1. Install PowerShell 7+ (pwsh)
Windows comes with PowerShell 5.x but we need PowerShell 7+.

Download and install from:
https://github.com/PowerShell/PowerShell/releases/latest

Choose the `.msi` installer for Windows (e.g. `PowerShell-7.x.x-win-x64.msi`).

Verify after installation — open a new terminal and run:
```powershell
pwsh --version
```
You should see `PowerShell 7.x.x` or higher.

### 2. Install ADB (Android Debug Bridge)
Required for pushing files to the Kindle Fire via USB.

Download the Android SDK Platform Tools for Windows:
https://developer.android.com/tools/releases/platform-tools

1. Download `platform-tools-latest-windows.zip`
2. Extract to a folder, e.g. `H:\Android SDK Platform Tools\`
3. Note the full path to `adb.exe` — you'll need it later

Verify ADB works:
```powershell
& 'H:\Android SDK Platform Tools\adb.exe' version
```

### 3. Install Git
If you don't have Git installed:
https://git-scm.com/download/win

Verify:
```powershell
git --version
```

### 4. Install SQLite Tools
Required for exporting the BDB/Thayer lexicon.

Download SQLite tools for Windows:
https://www.sqlite.org/download.html

1. Download `sqlite-tools-win-x64-*.zip`
2. Extract to a folder, e.g. `H:\SQLiteTools\`
3. Note the full path to `sqlite3.exe` — you'll need it later

---

## Project Setup

### 1. Clone the repository
Open PowerShell and run:
```powershell
cd 'C:\Users\YourName'
git clone https://github.com/RonTurrentine/KJV-Strongs-EBook.git
cd KJV-Strongs-EBook
```

### 2. Download required source files
The following files are NOT included in the repository (too large) and must be
obtained separately. Place them in the project root directory:

- **`kjv.osis.xml`** (~28MB) — KJV Bible in OSIS format with Strong's numbers
- **`StrongHebrewG.xml`** (~6MB) — Hebrew Strong's lexicon
- **`strongsgreek.xml`** (~2MB) — Greek Strong's lexicon
- **`bdb-thayer.dct.mybible`** — BDB/Thayer lexicon (SQLite database)
  - Source: MyBible app dictionary downloads

### 3. Update paths in scripts
Several scripts have paths that need to match your system. Open each file
in a text editor and update the following:

**`scripts/adb-push-all.ps1`** — update `$AdbPath`:
```powershell
[string]$AdbPath = 'H:\Android SDK Platform Tools\adb.exe'
```

**`scripts/package_epub.ps1`** — update `$AdbPath`:
```powershell
[string]$AdbPath = 'H:\Android SDK Platform Tools\adb.exe'
```

**`scripts/export-bdb.ps1`** — update `$Sqlite3`:
```powershell
[string]$Sqlite3 = 'H:\SQLiteTools\sqlite3.exe'
```

**`start-study.ps1`** — update `$adbPath` in two places:
```powershell
$adbPath = 'H:\Android SDK Platform Tools\adb.exe'
```

**`scripts/generate_bible.ps1`** and **`scripts/generate_dict.ps1`** —
update `$ProjectRoot` if different from default:
```powershell
[string]$ProjectRoot = 'C:\Users\YourName\KJV-Strongs-EBook'
```

---

## Generation Steps

Run these commands in order from the project root directory:

```powershell
cd 'C:\Users\YourName\KJV-Strongs-EBook'

# 1. Export BDB/Thayer lexicon (one-time setup)
pwsh -NoProfile -File .\scripts\export-bdb.ps1

# 2. Generate Bible chapter pages + concordance
pwsh -NoProfile -File .\scripts\generate_bible.ps1

# 3. Generate dictionary pages with BDB definitions + concordance
pwsh -NoProfile -File .\scripts\generate_dict.ps1

# 4. Run QA tests
pwsh -NoProfile -File .\scripts\qa-test.ps1

# 5. Rebake personal notes (if you have any)
pwsh -NoProfile -File .\scripts\rebake-notes.ps1
```

Generation takes approximately:
- `generate_bible.ps1` — 10-15 minutes
- `generate_dict.ps1` — 5-10 minutes
- `export-bdb.ps1` — 15-20 minutes (one-time only)

---

## Running the Study Server

Double-click `start-study.bat` in the project root folder.

Or from PowerShell:
```powershell
cd 'C:\Users\YourName\KJV-Strongs-EBook'
pwsh -NoProfile -File .\start-study.ps1
```

This starts the local server at `http://localhost:8080` and opens your browser
automatically.

To stop the server: close the terminal window (Ctrl+C may not work).

---

## Using the Bible Study Tool

Once the server is running, your browser opens to `http://localhost:8080`.

**Key features:**
- Browse all 66 books of the KJV Bible
- Click any Strong's number badge `[H0430]` to open the Hebrew/Greek lexicon
- Each lexicon entry shows:
  - Strong's definition and KJV usage
  - BDB/Thayer hierarchical definition
  - Every occurrence in the Bible with English translation
- Add personal study notes to any verse (pencil ✏ button)
- Use `[[Book.Ch.Vs]]` syntax in notes to create verse links (e.g. `[[John.3.16]]`)
- Click **Go To Passage** to jump to any verse
- Click **Hebrew** or **Greek** to browse the full Strong's index

---

## Pushing to Kindle Fire

Connect your Kindle Fire D01E via USB.

**Enable ADB on Kindle:**
1. Settings → Device Options → tap Serial Number 7 times (enables Developer Options)
2. Developer Options → Enable ADB → On
3. When prompted on Kindle screen, tap "Allow" to trust the computer

**Verify connection:**
```powershell
& 'H:\Android SDK Platform Tools\adb.exe' devices
```
You should see your device listed as `device` (not `offline`).

**Push all files to Kindle (~15-30 minutes):**
```powershell
pwsh -NoProfile -File .\scripts\package_epub.ps1
```

Or for a simpler push without EPUB packaging:
```powershell
pwsh -NoProfile -File .\scripts\adb-push-all.ps1
```

**On the Kindle**, open the Silk browser and navigate to:
`file:///data/local/tmp/index.html`

Bookmark this page for easy access.

---

## Personal Notes

Notes are stored in `notes.json` in the project root. This file is personal
and is excluded from GitHub (listed in `.gitignore`).

After making notes via the study server, sync them to the Kindle using the
**⚡ K** button in any chapter page header.

If you regenerate the Bible pages (run `generate_bible.ps1`), your notes
will disappear from the HTML — restore them by running:
```powershell
pwsh -NoProfile -File .\scripts\rebake-notes.ps1
```

---

## Troubleshooting

**"pwsh: command not found"**
PowerShell 7 wasn't installed or PATH wasn't updated.
Restart your terminal after installing, or add PowerShell to PATH manually.

**"adb is not recognized"**
Add the ADB folder to your PATH, or always use the full path:
```powershell
$env:PATH += ';H:\Android SDK Platform Tools'
```

**ADB device shows "unauthorized"**
Unlock the Kindle screen and tap "Allow" on the USB debugging prompt.

**ADB device shows "offline"**
Try unplugging and replugging the USB cable, then run `adb devices` again.

**Port 8080 already in use**
Another program is using port 8080. Find and close it, or edit `start-study.ps1`
to use a different port number (change all references from `8080` to e.g. `8081`).

**Scripts won't run — execution policy error**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Generation scripts are slow**
Normal — generating 15,000+ HTML files takes time. Expect:
- `generate_bible.ps1`: 10-15 minutes
- `generate_dict.ps1`: 5-10 minutes

---

## File Structure

```
KJV-Strongs-EBook\
├── start-study.ps1          Local HTTP server
├── start-study.bat          Double-click launcher
├── BiblePencil.ico          Browser tab icon
├── index.html               Main book index (generated)
├── navigate.html            Go To Passage page (generated)
├── notes.json               Your personal notes (NOT in GitHub)
├── concordance.json         Strong's concordance index (NOT in GitHub)
├── books\                   1,189 chapter HTML files (generated)
├── dict\                    14,298 dictionary pages (generated)
│   ├── hebrew\              H0001 - H8674
│   └── greek\               G0001 - G5624
├── indexes\                 Strong's index pages (generated)
├── css\
│   ├── style.css            PC stylesheet
│   └── style-kindle.css     Kindle stylesheet
├── js\
│   ├── bible-data.js        Book/chapter data
│   ├── notes.js             Notes system
│   ├── fontsize.js          Font size controls
│   ├── bookmarks.js         Reading position
│   └── sticky-header.js     Header behavior
└── scripts\
    ├── generate_bible.ps1   Bible generator
    ├── generate_dict.ps1    Dictionary generator
    ├── export-bdb.ps1       BDB/Thayer exporter
    ├── qa-test.ps1          Quality assurance
    ├── rebake-notes.ps1     Restore baked notes
    ├── adb-push-all.ps1     Push to Kindle
    ├── package_epub.ps1     EPUB packager
    └── git-push.ps1         GitHub push helper
```

---

*Generated for KJV Strong's Bible study tool — https://github.com/RonTurrentine/KJV-Strongs-EBook*
