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

# Documentation
git add README.md
git add WINDOWS-SETUP.md
git add MAC-SETUP.md

# Note: books/, dict/, indexes/, index.html, navigate.html, search.html
# are generated files — they are gitignored and pushed separately if needed.
# SESSION-NOTES.md and highlights.json are personal files — not committed here.

Write-Host "Committing with message: $Message" -ForegroundColor Cyan
git commit -m $Message

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push

Write-Host "Done!" -ForegroundColor Green
