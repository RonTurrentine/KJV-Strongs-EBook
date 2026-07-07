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

# git-push.ps1
# Stages all project files and pushes to GitHub.
# Usage: pwsh -NoProfile -File .\scripts\git-push.ps1 -Message "Your commit message"

param(
    [string]$Message = "Update project files"
)

cd 'C:\Users\OldTi\KJV-Strongs'

Write-Host "Staging files..." -ForegroundColor Cyan

# Source files
git add css/
git add js/
git add scripts/
git add .github/

# Root files
git add start-study.ps1
git add start-study.bat
git add BiblePencil.ico
git add .gitignore
git add .gitattributes

# PWA / offline support files (root-level, not covered by css/js/scripts/
# above -- these were being silently missed by this script previously)
git add sw.js
git add manifest.json
git add icon-192.png
git add icon-512.png
git add about.html
git add help.html

# search.html changes infrequently but IS a real, hand-maintained page
# (not purely generated output) -- stage it explicitly so real edits to
# it (like this week's settings-dropdown/PWA additions) actually get
# committed, rather than relying on someone remembering to add it by hand.
git add search.html

# Documentation
git add README.md
git add WINDOWS-SETUP.md
git add MAC-SETUP.md
git add PROJECT-CONTEXT.md

# Note: books/, dict/, indexes/, index.html, navigate.html are generated
# output — they are gitignored and pushed separately if needed.
# notes.json, highlights.json, SESSION-NOTES.md are personal files — not
# committed here (also gitignored as a safety net -- see .gitignore).

Write-Host "Committing with message: $Message" -ForegroundColor Cyan
git commit -m $Message

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push

Write-Host "Done!" -ForegroundColor Green
