$inputFile = "kjv.osis.xml"
$outputDir = "Genesis1_Strongs"

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

[xml]$xml = Get-Content $inputFile -Encoding UTF8

$nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$nsMgr.AddNamespace("osis", $xml.DocumentElement.NamespaceURI)

Write-Host "Building Genesis 1 Strong's index..." -ForegroundColor Cyan

$strongIndex = @{}

# Find Genesis 1 chapter
$chapter = $xml.SelectSingleNode("//osis:chapter[@osisID='Gen.1']", $nsMgr)

if (-not $chapter) {
    Write-Host "Genesis 1 not found!" -ForegroundColor Red
    exit
}

# Find all verse start milestones inside chapter
$verseStarts = $chapter.SelectNodes(".//osis:verse[@sID]", $nsMgr)

Write-Host "Verse starts found: $($verseStarts.Count)"

foreach ($startVerse in $verseStarts) {

    $verseID = $startVerse.GetAttribute("sID")

    Write-Host "Processing $verseID"

    $node = $startVerse.NextSibling

    while ($node) {

        if ($node.Name -eq "verse" -and
            $node.GetAttribute("eID") -eq $verseID) {
            break
        }

        if ($node.Name -eq "w") {

            $wordText = $node.InnerText.Trim()

            $lemma = $node.GetAttribute("lemma")

            if ($lemma) {

                $strongs =
                    [regex]::Matches($lemma, '[HG]\d{3,5}') |
                    ForEach-Object { $_.Value }

                foreach ($strong in $strongs) {

                    if (-not $strongIndex.ContainsKey($strong)) {

                        $strongIndex[$strong] =
                            New-Object System.Collections.Generic.List[object]
                    }

                    $strongIndex[$strong].Add(
                        [PSCustomObject]@{
                            Verse = $verseID
                            Word  = $wordText
                        }
                    )
                }
            }
        }

        $node = $node.NextSibling
    }
}

Write-Host ""
Write-Host "Strong entries found: $($strongIndex.Keys.Count)" -ForegroundColor Green

foreach ($strong in $strongIndex.Keys) {

    $entries = $strongIndex[$strong]

    $html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>$strong</title>
<style>
body {
    font-family: Georgia, serif;
    margin: 20px;
}
.entry {
    margin-bottom: 4px;
}
</style>
</head>
<body>

<h1>$strong</h1>

<p><b>Occurrences:</b> $($entries.Count)</p>

<h2>Genesis 1 Occurrences</h2>

"@

    foreach ($e in $entries) {

        $html += "<div class='entry'><b>$($e.Verse)</b> - $($e.Word)</div>`n"
    }

    $html += @"

</body>
</html>
"@

    $file = Join-Path $outputDir "$strong.html"

    $html | Set-Content -Encoding UTF8 $file
}

Write-Host ""
Write-Host "DONE" -ForegroundColor Green
Write-Host "Output folder: $outputDir"