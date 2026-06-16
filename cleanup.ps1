# cleanup.ps1
# Removes test files, sample files, and debug files from the project root.
# Safe to run — only deletes files explicitly listed below.

cd 'C:\Users\OldTi\KJV-Strongs'

$filesToDelete = @(
    # Test HTML pages from Kindle debugging
    'kindle-test.html',
    'kindle-test2.html',
    'scroll-debug-test.html',
    'scroll-debug-test2.html',
    'index-v2-test.html',
    'index-v3-test.html',
    'index-v4-test.html',
    'index-v5-test.html',
    'index-v6-test.html',
    'index-v7-test.html',
    'index-v8-test.html',
    'gen1-ondevice.html',
    'gen1-pulled.html',
    'gen1-v2.html',

    # Debug JS files from sticky header investigation
    'sticky-header-debug.js',
    'sticky-header-debug3.js',
    'sticky-header-debug4.js',
    'sticky-header-debug5.js',
    'sticky-header-debug6.js',

    # Sample files from early prototype phase
    'sample-chapter-gen1.html',
    'sample-index.html',
    'sample-verse.html',
    'sample-verse-2.html',
    'sample-verse-gen1.html',
    'sample-note-gen1-1.html',
    'sample-note-gen1-2.html',
    'sample-note-gen1-3.html',
    'sample-note-gen1-4.html',
    'sample-note-gen1-5.html',
    'sample-note-gen1-6.html',
    'sample-note-gen1-7.html',
    'sample-note-gen1-8.html',
    'sample-note-gen1-9.html',
    'sample-note-gen1-10.html',
    'sample-xref-gen1-1.html',
    'sample-xref-gen1-2.html',
    'sample-xref-gen1-3.html',
    'sample-xref-gen1-4.html',
    'sample-xref-gen1-5.html',
    'sample-xref-gen1-6.html',
    'sample-xref-gen1-7.html',
    'sample-xref-gen1-8.html',
    'sample-xref-gen1-9.html',
    'sample-xref-gen1-10.html',
    'chapter-template.html',
    'dict-entry-template.html',
    'verse-template.html',

    # Early prototype/diagnostic scripts
    'generate_genesis1.ps1',
    'generate_dictionary.ps1',
    'ConvertTo-VerseHtml-Fix.ps1',
    'testosis.ps1',
    'verse_gaps.ps1',
    'verse-gap-diag.ps1',
    'del-test-files.ps1',
    'build.ps1',

    # Duplicate/stray gitignore
    'gitignore',

    # Early architecture docs superseded by SESSION-NOTES.md and DESIGN-PROPOSAL.md
    'PLAN.md',
    'ARCHITECTURE.md'
)

$deleted = 0
$notFound = 0

foreach ($file in $filesToDelete) {
    $path = Join-Path (Get-Location) $file
    if (Test-Path $path) {
        Remove-Item $path -Force
        Write-Host "  Deleted: $file" -ForegroundColor Green
        $deleted++
    } else {
        Write-Host "  Not found (skipped): $file" -ForegroundColor Gray
        $notFound++
    }
}

Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Cleanup complete!" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host " Deleted  : $deleted files" -ForegroundColor Green
Write-Host " Not found: $notFound files" -ForegroundColor Gray
Write-Host ""
Write-Host "Files kept (active project files):" -ForegroundColor Yellow
Write-Host "  generate_bible.ps1, generate_dict.ps1, qa-test.ps1" -ForegroundColor White
Write-Host "  git-push.ps1, adb-push-test.ps1, adb-push-all.ps1" -ForegroundColor White
Write-Host "  start-study.ps1, start-study.bat, scan_morph_codes.ps1" -ForegroundColor White
Write-Host "  DESIGN-PROPOSAL.md, SESSION-NOTES.md, README.md" -ForegroundColor White
Write-Host "  .gitignore, index.html, navigate.html" -ForegroundColor White
Write-Host "  kjv.osis.xml, StrongHebrewG.xml, strongsgreek.xml" -ForegroundColor White
