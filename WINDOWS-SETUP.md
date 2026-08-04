# KJV Strong's Bible — Windows Setup Guide

---

## Option A — Installer (Recommended)

The easiest way to get started is the one-click installer:

1. Go to the [GitHub Releases page](https://github.com/RonTurrentine/KJV-Strongs-EBook/releases/latest)
2. Download **`KJV Strong's Bible Setup [version].exe`** (the "latest" page always has the newest one)
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

## Upgrading from a Version Before v1.2.0

If you installed KJV Strong's Bible **before v1.2.0**, the app does not yet
know how to detect and clean up an old installation automatically. Starting
with v1.2.0, this happens for you — but if you're coming from an older
version, please follow these steps **exactly in order** to upgrade cleanly.

> **Why this is necessary:** Older versions did not check whether a previous
> installation existed. Simply installing the new version over an old one
> can leave behind stale files, causing the app to show outdated content or
> fail to start with a `spawn EPERM` error.

### Step 1 — Back up your notes (recommended)

Before doing anything else, back up your notes so you don't lose them:

1. Open the app
2. Click the ☰ hamburger menu (top-right)
3. Click **💾 Export Notes**
4. A file named `kjv-notes-YYYY-MM-DD.json` will save to your **Downloads** folder
5. Keep this file safe — you'll use it later to restore your notes

### Step 2 — Uninstall the old app

1. Open **Settings** → **Apps** → **Installed apps** (or **Control Panel** → **Programs and Features**)
2. Find **KJV Strong's Bible**
3. Click **Uninstall** and confirm

### Step 3 — Delete the old data folder

This is the step older versions can't do automatically — you'll need to do
it manually just this once.

1. Press `Win + R` to open the Run dialog
2. Type exactly: `%LOCALAPPDATA%\KJVStrongs`
3. Press **Enter** — this opens the old data folder in File Explorer
4. Go back up one level (click the folder icon in the address bar, or press `Backspace`)
5. Right-click the **KJVStrongs** folder and choose **Delete**

> If Windows says it can't find that folder, that's fine — it just means
> there's nothing to clean up. Continue to Step 4.

### Step 4 — Download and install the latest version

1. Go to the [KJV Strong's Bible Launcher Releases page](https://github.com/RonTurrentine/KJV-Strongs-Launcher/releases/latest)
2. Download **`KJV Strong's Bible Setup [version].exe`**
3. Run the installer and follow the on-screen prompts

### Step 5 — Restore your notes

1. Once the app finishes setup and opens, click the ☰ hamburger menu
2. Click **📥 Import Notes**
3. Select the `kjv-notes-YYYY-MM-DD.json` file you saved in Step 1
4. Review the summary and click **Apply Import**

You're done! From this point forward (v1.2.0 and later), the app will
automatically detect version mismatches and offer to back up your notes
before refreshing — you won't need to repeat these manual steps again.

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
- Hebrew and Greek index pages support searching by transliteration or Strong's number
- Add personal study notes to any verse (pencil ✏ button), with optional tags
- Use `[[Book.Ch.Vs]]` syntax in notes to create verse links (e.g. `[[John.3.16]]`)
- **My Notes** — browse, filter, and tag every note across the whole Bible in one place
- Click **Go To Passage** to jump to any verse
- Click **Hebrew** or **Greek** to browse the full Strong's index
- ☰ hamburger menu — font size, Connect New Phone, My Notes, Sync to Kindle, Export/Import Notes, Rebake Notes
- 🏠 Home button returns to the main book index from any page
- Keyboard shortcuts: `Ctrl+]` increase font, `Ctrl+[` decrease font, `H` toggle Strong's

---

## Connecting Your Phone

Your phone reads the same Bible study tool over your home WiFi network, and can
download everything it needs to keep working fully offline — away from home,
on a plane, wherever.

### Step 1 — Allow phone access through Windows Firewall (one time only)

Windows blocks incoming connections by default, so your phone can't reach your
PC until you allow it. Open PowerShell **as Administrator** and run:

```powershell
cd 'C:\Users\YourName\KJV-Strongs-EBook'
pwsh -NoProfile -File .\scripts\setup-phone-access.ps1
```

You only need to do this once per PC. If you ever move to a new computer, or
your firewall settings get reset, just run it again.

### Step 2 — Connect via QR code

1. Make sure the study server is running (`start-study.bat` or `start-study.ps1`)
2. On the PC, open the ☰ menu and click **Connect New Phone**
3. A QR code appears on screen
4. On your phone, open your camera app and scan it — this opens the app in
   your phone's browser automatically
5. The first time you connect a given phone, a setup wizard walks you through
   downloading the Bible text, downloading the Hebrew/Greek Lexicon (this one's
   larger, 100+ MB — do it on WiFi), and syncing your existing notes over

### Step 3 — Install it as a real app (recommended)

In Chrome on your phone, tap **⋮** (three-dot menu) → **"Install app"** (some
phones word this "Add to Home screen" or "Install and create shortcut" — same
thing). This gives you a proper full-screen app icon with no browser address
bar showing, instead of a regular browser tab.

> **Important:** only install while your phone shows it's actually connected
> to your PC (no red "Offline mode" banner). Installing while disconnected can
> silently create a plain bookmark shortcut instead of a real app, with no
> error to warn you — it'll still work, but it'll keep the address bar
> visible. If that happens: long-press the icon → Uninstall, reconnect to your
> PC, then reinstall.

### Using it day to day

- ☰ menu → **Download Bible Text for Offline** / **Download Lexicon for
  Offline** / **Refresh Offline Content** — re-run any of these anytime; a
  failed or interrupted download automatically picks up where it left off
- A red **"Offline mode"** banner just means your phone can't currently reach
  your PC (away from home, or the PC app isn't running) — everything you've
  already downloaded keeps working normally regardless
- **Search** (the English word search) specifically needs a live connection to
  your PC even though the rest of the app works offline — see
  [Troubleshooting](#troubleshooting) if it's not showing up
- When an app update is ready, you'll see an **"App Update Available"** prompt
  with **Update Now** / **Remind Me Later** / **Remind Tomorrow** — updating
  only refreshes the app itself and never touches your downloaded content. If
  you snooze it, a manual **Update Now** item appears at the top of the ☰ menu
  whenever you're back on home WiFi.

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

**Phone won't connect / QR code doesn't work**
Almost always Windows Firewall blocking the connection. Run this once, as
Administrator:
```powershell
pwsh -NoProfile -File .\scripts\setup-phone-access.ps1
```
See [Connecting Your Phone](#connecting-your-phone) above for the full setup flow.

**Installed phone app still shows the browser address bar**
Either it was installed while disconnected from the PC (uninstall, reconnect,
reinstall — see [Connecting Your Phone](#connecting-your-phone)), or your setup
is using a plain local address rather than HTTPS, which Android restricts to
showing the address bar regardless of the app's settings. This is a known,
current limitation of running over a home network without a proper
certificate, not a bug you can fix through the app itself.

**"Search" isn't showing up on my phone**
By design — Search needs a live connection to your PC even though everything
else works offline. It only appears while your phone is actually connected to
your PC over home WiFi with the PC app running; it's hidden automatically the
rest of the time so you're not left tapping a button that can't work.

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
├── icon-192.png             Phone app icon (small)
├── icon-512.png             Phone app icon (large)
├── manifest.json            Phone app installability info
├── sw.js                    Phone offline/caching support (generated)
├── index.html               Main book index (generated)
├── navigate.html            Go To Passage page (generated)
├── search.html              English word search (generated)
├── notes-manager.html       My Notes — browse/filter/tag all notes (generated)
├── notes.json               Your personal notes (NOT in GitHub)
├── concordance.json         Strong's concordance index (NOT in GitHub)
├── books\                   1,189 chapter HTML files (generated)
├── dict\                    14,298 dictionary pages (generated)
│   ├── hebrew\              H0001 - H8674
│   └── greek\               G0001 - G5624
├── indexes\                 Strong's index pages, searchable (generated)
├── css\
│   ├── style.css            PC stylesheet
│   └── style-kindle.css     Kindle stylesheet
├── js\
│   ├── bible-data.js        Book/chapter data
│   ├── notes.js             Notes, tags, phone offline & update system
│   ├── fontsize.js          Font size controls
│   ├── bookmarks.js         Reading position
│   └── sticky-header.js     Header behavior
└── scripts\
    ├── generate_bible.ps1      Bible generator
    ├── generate_dict.ps1       Dictionary generator
    ├── export-bdb.ps1          BDB/Thayer exporter (advanced, optional)
    ├── qa-test.ps1             Quality assurance (170+ tests)
    ├── rebake-notes.ps1        Restore baked notes
    ├── setup-phone-access.ps1  One-time Windows Firewall rule for phone access
    ├── adb-push-all.ps1        Push to Kindle
    ├── package_epub.ps1        EPUB packager
    └── git-push.ps1            GitHub push helper
```

---

*KJV Strong's Bible — https://github.com/RonTurrentine/KJV-Strongs-EBook*
