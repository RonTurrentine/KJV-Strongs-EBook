# scan_morph_codes.ps1
# Scans StrongHebrewG.xml and reports all unique morph codes found,
# whether they are in the posMap or not, and how many entries use each code.

param(
    [string]$HebrewPath = 'StrongHebrewG.xml'
)

# Current posMap -- keep this in sync with generate_dict.ps1

$posMap = @{
    # Common nouns
    'n'         = 'Noun'
    'n-m'       = 'Noun Masculine'
    'n-f'       = 'Noun Feminine'
    'n-c'       = 'Noun Common'
    'n-p'       = 'Noun Proper'
    'n-m-loc'   = 'Noun Masculine Locative'
    # Proper nouns
    'n-pr'      = 'Noun Proper'
    'np'        = 'Noun Proper'
    'n-pr-m'    = 'Noun Proper Masculine'
    'n-pr-f'    = 'Noun Proper Feminine'
    'n-pr-mf'   = 'Noun Proper Masculine/Feminine'
    'n-pr-l'    = 'Noun Proper Location'
    'n-pr-loc'  = 'Noun Proper Location'
    'n-pr-g'    = 'Noun Proper Gentilic'
    'n-pr-d'    = 'Noun Proper Deity'
    'm-pr-f'    = 'Noun Proper Feminine'
    # Gentilic nouns
    'n-gm'      = 'Noun Gentilic Masculine'
    'n-gf'      = 'Noun Gentilic Feminine'
    # Adjectives
    'a'         = 'Adjective'
    'a-m'       = 'Adjective Masculine'
    'a-f'       = 'Adjective Feminine'
    'adj'       = 'Adjective'
    # Verbs
    'v'         = 'Verb'
    # Pronouns
    'p'         = 'Pronoun'
    'pron'      = 'Pronoun'
    'dp'        = 'Demonstrative Pronoun'
    # Adverbs
    'd'         = 'Adverb'
    'adv'       = 'Adverb'
    # Particles and conjunctions
    'x'         = 'Particle'
    'prt'       = 'Particle'
    'c'         = 'Conjunction'
    'conj'      = 'Conjunction'
    # Prepositions
    'r'         = 'Preposition'
    'prep'      = 'Preposition'
    # Locative
    'loc'       = 'Locative'
    # Interjections
    'i'         = 'Interjection'
    'inj'       = 'Interjection'
    'interj'    = 'Interjection'
    # Articles and affixes
    't'         = 'Article'
    'infix'     = 'Infix'
    'suffix'    = 'Suffix'
    'prefix'    = 'Prefix'
}

Write-Host "Loading $HebrewPath..." -ForegroundColor Cyan
$heb = [xml](Get-Content -Raw -Path $HebrewPath)
$ns  = New-Object System.Xml.XmlNamespaceManager($heb.NameTable)
$ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

$entries = $heb.SelectNodes('//o:div[@type="entry"]', $ns)
Write-Host "Scanning $($entries.Count) entries...`n" -ForegroundColor Cyan

# Collect all individual morph codes and their counts
$codeCounts   = @{}   # code -> count of entries using it
$unknownCodes = @{}   # code -> count (codes NOT in posMap)
$multiCodes   = @()   # entries with more than one code

foreach ($entry in $entries) {
    $w = $entry.SelectSingleNode('o:w', $ns)
    if (-not $w) { continue }

    $morph = $w.GetAttribute('morph')
    if (-not $morph) { continue }

    $parts = $morph.Trim() -split '\s+'

    if ($parts.Count -gt 1) {
        $id = $w.GetAttribute('ID')
        $multiCodes += [pscustomobject]@{
            ID    = $id
            Morph = $morph
        }
    }

    foreach ($part in $parts) {
        $lower = $part.ToLower().Trim()
        if (-not $lower) { continue }

        if (-not $codeCounts.ContainsKey($lower)) { $codeCounts[$lower] = 0 }
        $codeCounts[$lower]++

        if (-not $posMap.ContainsKey($lower)) {
            if (-not $unknownCodes.ContainsKey($lower)) { $unknownCodes[$lower] = 0 }
            $unknownCodes[$lower]++
        }
    }
}

# ── Report: All unique codes ──────────────────────────────────────────────────
Write-Host "============================================" -ForegroundColor Green
Write-Host " ALL UNIQUE MORPH CODES ($($codeCounts.Count) total)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ("{0,-15} {1,-6} {2}" -f "Code", "Count", "Status") -ForegroundColor Yellow
Write-Host ("{0,-15} {1,-6} {2}" -f "----", "-----", "------") -ForegroundColor Yellow

foreach ($code in ($codeCounts.Keys | Sort-Object)) {
    $count   = $codeCounts[$code]
    $status  = if ($posMap.ContainsKey($code)) {
        "OK  -- " + $posMap[$code]
    } else {
        "*** MISSING ***"
    }
    $color = if ($posMap.ContainsKey($code)) { 'Gray' } else { 'Red' }
    Write-Host ("{0,-15} {1,-6} {2}" -f $code, $count, $status) -ForegroundColor $color
}

# ── Report: Unknown codes ─────────────────────────────────────────────────────
Write-Host ""
if ($unknownCodes.Count -eq 0) {
    Write-Host "No unknown codes found -- posMap is complete!" -ForegroundColor Green
} else {
    Write-Host "============================================" -ForegroundColor Red
    Write-Host " UNKNOWN CODES -- ADD THESE TO posMap ($($unknownCodes.Count) missing)" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    foreach ($code in ($unknownCodes.Keys | Sort-Object)) {
        Write-Host ("  '$code' = '???'   # used $($unknownCodes[$code]) time(s)") -ForegroundColor Red
    }
}

# ── Report: Multi-code entries ────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " MULTI-CODE ENTRIES ($($multiCodes.Count) entries with 2+ codes)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
if ($multiCodes.Count -eq 0) {
    Write-Host "None found." -ForegroundColor Gray
} else {
    foreach ($entry in ($multiCodes | Sort-Object Morph)) {
        Write-Host ("  $($entry.ID.PadRight(8)) $($entry.Morph)") -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Scan complete." -ForegroundColor Green
