param(
    [ValidateSet('help','generate','validate','preview','ci','all','version')]
    [string]$Task = 'help'
)

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Show-Help {
    Write-Host 'build.ps1 - Task helper for the KJV Strong''s project' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Usage:'
    Write-Host '  .\build.ps1 -Task help       # Show this help text'
    Write-Host '  .\build.ps1 -Task generate  # Run the Genesis 1 page generator'
    Write-Host '  .\build.ps1 -Task validate  # Verify generated sample output files'
    Write-Host '  .\build.ps1 -Task preview   # Show preview instructions for local browsing'
    Write-Host '  .\build.ps1 -Task ci        # Run generation and validation together'
    Write-Host '  .\build.ps1 -Task all       # Same as ci'
    Write-Host '  .\build.ps1 -Task version   # Show script metadata'
}

function Run-Generator {
    Write-Host 'Running Genesis 1 sample generator...' -ForegroundColor Green
    pwsh -NoProfile -File "$repoRoot\generate_genesis1.ps1"
}

function Validate-Output {
    Write-Host 'Validating generated files...' -ForegroundColor Green

    $files = @(
        'sample-chapter-gen1.html',
        'sample-verse-gen1.html'
    )

    $missing = @()
    foreach ($file in $files) {
        if (-not (Test-Path "$repoRoot\$file")) {
            $missing += $file
        }
    }

    if ($missing.Count -gt 0) {
        Write-Host "Missing generated files: $($missing -join ', ')" -ForegroundColor Red
        exit 1
    }

    Write-Host 'All required generated files exist.' -ForegroundColor Green
}

function Show-Preview {
    Write-Host 'Preview instructions:' -ForegroundColor Green
    Write-Host '  1. Open a terminal in the repository root.'
    Write-Host '  2. Run:'
    Write-Host '       python -m http.server 8000'
    Write-Host '  3. Open:'
    Write-Host '       http://localhost:8000/index.html'
    Write-Host ''
    if (Test-Path "$repoRoot\index.html") {
        Write-Host 'Opening index.html in your default browser...' -ForegroundColor Green
        Start-Process "$repoRoot\index.html"
    }
}

function Show-Version {
    Write-Host "Repository root: $repoRoot"
    Write-Host 'Available tasks: help, generate, validate, preview, ci, all, version'
}

switch ($Task.ToLower()) {
    'help'    { Show-Help }
    'generate'{ Run-Generator }
    'validate'{ Validate-Output }
    'preview' { Show-Preview }
    'ci'      { Run-Generator; Validate-Output }
    'all'     { Run-Generator; Validate-Output }
    'version' { Show-Version }
    default   { Show-Help }
}
