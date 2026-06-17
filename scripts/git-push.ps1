# git-push.ps1
# Stages all project files and pushes to GitHub.
# Usage: pwsh -NoProfile -File .\scripts\git-push.ps1 -Message "Your commit message"

param(
    [string]$Message = "Update project files"
)

cd 'C:\Users\OldTi\KJV-Strongs'

Write-Host "Staging files..." -ForegroundColor Cyan

git add css/
git add js/
git add books/
git add dict/
git add xrefs/
git add indexes/
git add scripts/
git add .github/
git add index.html
git add navigate.html
git add start-study.ps1
git add start-study.bat
git add BiblePencil.ico
git add SESSION-NOTES.md
git add DESIGN-PROPOSAL.md
git add README.md
git add .gitignore

Write-Host "Committing with message: $Message" -ForegroundColor Cyan
git commit -m $Message

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push

Write-Host "Done!" -ForegroundColor Green
