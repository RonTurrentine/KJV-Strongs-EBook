# KJV Strong's Bible — Windows Setup Guide

---

## Option A — Installer (Recommended)

The easiest way to get started is the one-click installer:

1. Go to the [GitHub Releases page](https://github.com/RonTurrentine/KJV-Strongs-EBook/releases/latest)
2. Download **`KJV Strong's Bible Setup 1.1.0.exe`**
3. Run the installer

The launcher will automatically:
- Install PowerShell 7+ if needed (you will see a Windows security prompt — click **Yes**)
- Download all required source files from GitHub
- Generate all 1,189 Bible chapters and 14,298 dictionary pages
- Start the study server and open the Bible in an embedded window

> **Note:** Your antivirus software may scan files during setup — this is completely
> normal and harmless. If asked to allow or trust the application, click **Allow**.
> A Windows security prompt will appear when installing PowerShell — click **Yes** to proceed.

**That's it!** Setup typically takes 3-5 minutes on a WiFi connection.

---

## Option B — Manual Setup (Developers / Advanced Users)

Use this option if you want to run the tool from source, contribute to development,
or have full control over the generation pipeline.

### Prerequisites

#### 1. Install PowerShell 7+ (pwsh)
Windows comes with PowerShell 5.x but we need PowerShell 7+.

Download and install from:
https://github.com/PowerShell/PowerShell/releases/latest

Choose the `.msi` installer for Windows (e.g. `PowerShell-7.x.x-win-x64.msi`).

Verify after installation — open a new terminal and run:
```powershell
pwsh --version
```
You should see `PowerShell 7.x.x` or higher.

#### 2. Install ADB (Android Debug Bridge)
Required only if you plan to sync to a Kindle Fire device.

Download the Android SDK Platform Tools for Windows:
https://developer.android.com/tools/releases/platform-tools

1. Download `platform-tools-latest-windows.zip`
2. Extract to a folder, e.g. `H:\Android SDK Platform Tools\`
3. Note the full path to `adb.exe` — you'll need it later

Verify ADB works:
```powershell
& 'H:\Android SDK Platform Tools\adb.exe' version
```

#### 3. Install Git
If you don't have Git installed:
https://git-scm.com/download/win

Verify:
```powershell
git --version
```

---

### Project Setup

#### 1. Clone the repository
```powershell
cd 'C:\Users\YourName'
git clone https://github.com/RonTurrentine/KJV-Strongs-EBook.git
cd KJV-Strongs-EBook
```

#### 2. Download required source files
The following files are NOT included in the repository (too large).
Download them from the [GitHub Releases page](https://github.com/RonTurrentine/KJV-Strongs-EBook/releases/latest)
and place them in the project root:

- **`kjv.osis.xml`** (~28MB) — KJV Bible in OSIS format with Strong's numbers
- **`bdb-thayer.json`** (~6.5MB) — BDB/Thayer lexicon (pre-exported JSON)

> **Note:** `bdb-thayer.json` is pre-exported and ready to use. You do NOT need
> SQLite3 or the MyBible source database unless you want to re-export from scratch
> (see `scripts/export-bdb.ps1` for that advanced workflow).

#### 3. Update paths in scripts
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

### Generation Steps

Run these commands in order from the project root directory:

```powershell
cd 'C:\Users\YourName\KJV-Strongs-EBook'

# 1. Generate Bible chapter pages + concordance
pwsh -NoProfile -File .\scripts\generate_bible.ps1

# 2. Generate dictionary pages with BDB definitions + concordance
pwsh -NoProfile -File .\scripts\generate_dict.ps1

# 3. Run QA tests
pwsh -NoProfile -File .\scripts\qa-test.ps1

# 4. Rebake personal notes (if you have any)
pwsh -NoProfile -File .\scripts\rebake-notes.ps1
```

Generation takes approximately:
- `generate_bible.ps1` — 2-3 minutes
- `generate_dict.ps1` — 1-2 minutes

---

### Running the Study Server

Double-click `start-study.bat` in the project root folder.

Or from PowerShell:
```powershell
cd 'C:\Users\YourName\KJV-Strongs-EBook'
pwsh -NoProfile -File .\start-study.ps1
```

This starts the local server at `http://localhost:8080` and opens your browser
automatically.

To stop the server: close the terminal window.

---

## Using the Bible Study Tool

Once running, your browser opens to `http://localhost:8080`.

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
- ☰ hamburger menu — font size, Strong's toggle, Sync to Kindle, Rebake Notes
- 🏠 Home button returns to the main book index from any page
- Keyboard shortcuts: `Ctrl+]` increase font, `Ctrl+[` decrease font, `H` toggle Strong's

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

**Push all files to Kindle:**
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
⚡ **Sync to Kindle** option in the ☰ hamburger menu on any chapter page.

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

---

## File Structure

```
KJV-Strongs-EBook\
├── start-study.ps1          Local HTTP server
├── start-study.bat          Double-click launcher
├── BiblePencil.ico          Browser tab icon
├── index.html               Main book index (generated)
├── navigate.html            Go To Passage page (generated)
├── search.html              English word search (generated)
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
    ├── export-bdb.ps1       BDB/Thayer exporter (advanced, optional)
    ├── qa-test.ps1          Quality assurance (155+ tests)
    ├── rebake-notes.ps1     Restore baked notes
    ├── adb-push-all.ps1     Push to Kindle
    ├── package_epub.ps1     EPUB packager
    └── git-push.ps1         GitHub push helper
```

---

*KJV Strong's Bible — https://github.com/RonTurrentine/KJV-Strongs-EBook*
