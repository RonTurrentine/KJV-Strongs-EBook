# git-push.ps1
# Stages all project files and pushes to GitHub.
# Usage: pwsh -NoProfile -File .\git-push.ps1 -Message "Your commit message"

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
git add generate_bible.ps1
git add generate_dict.ps1
git add generate_genesis1.ps1
git add qa-test.ps1
git add scan_morph_codes.ps1
git add index.html
git add navigate.html
git add SESSION-NOTES.md
git add DESIGN-PROPOSAL.md

Write-Host "Committing with message: $Message" -ForegroundColor Cyan
git commit -m $Message

Write-Host "Pushing to GitHub..." -ForegroundColor Cyan
git push

Write-Host "Done!" -ForegroundColor Green