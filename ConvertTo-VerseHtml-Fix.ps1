# ================================================================
# ConvertTo-VerseHtml-Fix.ps1
#
# Drop-in replacement functions for generate_bible.ps1 to fix
# the NT verse-parsing gap. The OSIS XML nests verse milestones
# inside <q>, <lg>, <l>, <div>, and other container elements.
# The original code iterated only $chapterNode.ChildNodes, so
# any verse milestone hidden inside a container was never seen.
#
# This fix introduces ONE new concept — a recursive node
# flattener — and rebuilds ConvertTo-VerseHtml on top of it.
# The OT continues to parse identically because the flattener
# is a no-op when there are no container elements (it simply
# returns the same direct children the old code already walked).
#
# INTEGRATION INTO generate_bible.ps1:
#   1. Add the Get-FlattenedNodes function (below)
#   2. Replace your existing ConvertTo-VerseHtml with this version
#   3. Replace your existing Get-StrongLinkHtml with this version
#      (adds Greek support + relative paths)
#   4. Everything else in your script stays the same
#
# ================================================================


# ----------------------------------------------------------------
# Get-FlattenedNodes
#
# Recursively walks an XML subtree and returns ALL content nodes
# in document order as a flat list. Container elements like <q>,
# <div>, <lg>, <l>, <p>, <speaker>, <list>, <item> are opened
# and their children added to the list — the container element
# itself is NOT added. Leaf elements like <verse>, <w>, <note>,
# <transChange> are added as-is (no recursion into their children).
#
# WHY THIS FIXES THE BUG:
#   Before:  foreach ($node in $chapterNode.ChildNodes)
#            → sees <q> as one opaque node, skips everything inside
#   After:   foreach ($node in Get-FlattenedNodes $chapterNode)
#            → sees every <verse>, <w>, text node inside <q>
#
# The OT has no container nesting at the chapter level, so the
# flat list is identical to ChildNodes — no behavior change.
# ----------------------------------------------------------------
function Get-FlattenedNodes {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$Parent
    )

    # Leaf elements: add directly to the flat list, do NOT recurse.
    # These are the elements the verse parser knows how to handle.
    $leafElements = @{
        'verse'         = $true   # milestone markers (sID / eID)
        'w'             = $true   # words with Strong's lemma
        'note'          = $true   # cross-references, footnotes
        'transChange'   = $true   # translator-added words (KJV italics)
        'divineName'    = $true   # LORD in small caps
        'hi'            = $true   # highlight / formatting
        'milestone'     = $true   # other OSIS milestones
        'catchWord'     = $true   # catch-word in notes
        'rdg'           = $true   # variant reading
        'seg'           = $true   # segment
        'title'         = $true   # psalm/section titles (treat as leaf)
    }

    $result = [System.Collections.Generic.List[System.Xml.XmlNode]]::new()

    foreach ($child in $Parent.ChildNodes) {
        $nodeType = $child.NodeType

        # ── Text nodes: always add ──
        if ($nodeType -eq [System.Xml.XmlNodeType]::Text -or
            $nodeType -eq [System.Xml.XmlNodeType]::Whitespace -or
            $nodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
            [void]$result.Add($child)
            continue
        }

        # ── Element nodes ──
        if ($nodeType -eq [System.Xml.XmlNodeType]::Element) {
            if ($leafElements.ContainsKey($child.LocalName)) {
                # Leaf element: add it, don't look inside
                [void]$result.Add($child)
            }
            else {
                # Container element (<q>, <div>, <lg>, <l>, <p>, etc.):
                # skip the container itself, recurse into its children
                $nested = Get-FlattenedNodes -Parent $child
                $result.AddRange($nested)
            }
        }
        # Skip comments, processing instructions, CDATA, etc.
    }

    return $result
}


# ----------------------------------------------------------------
# Get-StrongLinkHtml
#
# Takes a <w> element's lemma attribute and word text, returns
# an HTML <a> link to the appropriate dictionary page.
#
# Handles:
#   - Hebrew:  lemma="strong:H0430"    → ../../dict/hebrew/h0430.html
#   - Greek:   lemma="strong:G3056"    → ../../dict/greek/g3056.html
#   - Multi:   lemma="strong:H0853 strong:H01254"  → two links
#   - Missing: no lemma attribute      → plain text, no link
#
# The $DictRelPath parameter is the relative path from the
# chapter file to the dict/ folder. For all chapter files at
# books/{NN}-{Abbr}/{ch}.html, this is always "../../dict".
# ----------------------------------------------------------------
function Get-StrongLinkHtml {
    param(
        [Parameter(Mandatory)]
        [string]$Word,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Lemma,

        [string]$DictRelPath = "../../dict"
    )

    if (-not $Lemma) {
        return [System.Net.WebUtility]::HtmlEncode($Word)
    }

    # Parse all strong:XNNNN references from the lemma string
    $matches_found = [regex]::Matches($Lemma, 'strong:([HG])(\d+)')

    if ($matches_found.Count -eq 0) {
        # Lemma exists but doesn't match Strong's format — return plain text
        return [System.Net.WebUtility]::HtmlEncode($Word)
    }

    # For single Strong's reference: wrap the whole word in one link
    if ($matches_found.Count -eq 1) {
        $m = $matches_found[0]
        $letter = $m.Groups[1].Value           # H or G
        $number = $m.Groups[2].Value.PadLeft(4, '0')  # zero-pad to 4 digits
        $strongId = "$letter$number"           # e.g. H0430

        if ($letter -eq 'H') {
            $subdir = "hebrew"
        } else {
            $subdir = "greek"
        }

        $href = "$DictRelPath/$subdir/$($strongId.ToLower()).html"
        $encoded = [System.Net.WebUtility]::HtmlEncode($Word)

        return "<a href=`"$href`" class=`"strongs-link`" title=`"$strongId`">$encoded</a>"
    }

    # For multiple Strong's references: word gets the first link,
    # additional references shown as bracketed superscripts
    $html = [System.Text.StringBuilder]::new()

    for ($i = 0; $i -lt $matches_found.Count; $i++) {
        $m = $matches_found[$i]
        $letter = $m.Groups[1].Value
        $number = $m.Groups[2].Value.PadLeft(4, '0')
        $strongId = "$letter$number"

        if ($letter -eq 'H') {
            $subdir = "hebrew"
        } else {
            $subdir = "greek"
        }

        $href = "$DictRelPath/$subdir/$($strongId.ToLower()).html"

        if ($i -eq 0) {
            # First reference wraps the word text
            $encoded = [System.Net.WebUtility]::HtmlEncode($Word)
            [void]$html.Append("<a href=`"$href`" class=`"strongs-link`" title=`"$strongId`">$encoded</a>")
        }
        else {
            # Additional references as small bracketed superscripts
            [void]$html.Append("<sup><a href=`"$href`" class=`"strongs-link strongs-extra`" title=`"$strongId`">[$strongId]</a></sup>")
        }
    }

    return $html.ToString()
}


# ----------------------------------------------------------------
# ConvertTo-VerseHtml
#
# Parses one chapter's worth of OSIS XML and returns an array
# of verse objects, each containing:
#   .Num    — verse number (int)
#   .Html   — the verse body HTML (string), ready to insert into
#             <p class="verse" id="verse-N">...<span>N</span> {HERE} </p>
#   .Xrefs  — array of osisRef strings for xref page generation
#
# This function handles the OSIS milestone verse model:
#   <verse sID="Gen.1.1"/>  ...content...  <verse eID="Gen.1.1"/>
#
# The key difference from the original version: it calls
# Get-FlattenedNodes to walk ALL descendant nodes in document
# order, so verse milestones nested inside <q>, <lg>, <l>, <div>
# are found correctly.
# ----------------------------------------------------------------
function ConvertTo-VerseHtml {
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode]$ChapterNode,

        [Parameter(Mandatory)]
        [string]$BookFolder,      # e.g. "01-Gen"

        [Parameter(Mandatory)]
        [string]$BookName,        # e.g. "Genesis"

        [Parameter(Mandatory)]
        [int]$ChapterNum,

        [string]$DictRelPath = "../../dict"
    )

    # ── Step 1: Flatten the node tree ──
    # This is the ONE LINE that fixes the NT parsing bug.
    # Instead of $ChapterNode.ChildNodes (direct children only),
    # we get ALL descendant nodes in document order, with container
    # elements like <q> opened and their children inlined.
    $flatNodes = Get-FlattenedNodes -Parent $ChapterNode

    # ── Step 2: Walk the flat list, tracking verse milestones ──
    $verses = [System.Collections.Generic.List[hashtable]]::new()
    $inVerse = $false
    $currentVerseNum = 0
    $verseHtml = [System.Text.StringBuilder]::new()
    $verseXrefs = [System.Collections.Generic.List[string]]::new()

    foreach ($node in $flatNodes) {

        # ── Handle text nodes ──
        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Text) {
            if ($inVerse) {
                # Normalize whitespace: collapse runs of spaces/newlines/tabs
                # into single spaces. HTML rendering collapses whitespace too,
                # but this keeps the source HTML cleaner.
                $text = $node.Value -replace '[\r\n\t]+', ' ' -replace '  +', ' '
                [void]$verseHtml.Append([System.Net.WebUtility]::HtmlEncode($text))
            }
            continue
        }

        if ($node.NodeType -eq [System.Xml.XmlNodeType]::Whitespace -or
            $node.NodeType -eq [System.Xml.XmlNodeType]::SignificantWhitespace) {
            if ($inVerse) {
                [void]$verseHtml.Append(' ')
            }
            continue
        }

        # ── From here on, we're dealing with Element nodes ──
        if ($node.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }

        $localName = $node.LocalName

        # ── Verse milestones ──
        if ($localName -eq 'verse') {
            $sID = $node.GetAttribute('sID')
            $eID = $node.GetAttribute('eID')

            if ($sID) {
                # ── VERSE START ──
                # Extract verse number from osisID: "Matt.5.3" → 3
                # Handle edge cases: "Ps.3.title" → skip (or treat as 0)
                $parts = $sID.Split('.')
                $verseStr = $parts[$parts.Length - 1]

                if ($verseStr -match '^(\d+)') {
                    $currentVerseNum = [int]$Matches[1]
                    $inVerse = $true
                    [void]$verseHtml.Clear()
                    $verseXrefs.Clear()
                }
                else {
                    # Non-numeric verse (e.g. psalm title) — skip
                    $inVerse = $false
                }
            }
            elseif ($eID) {
                # ── VERSE END ──
                if ($inVerse -and $currentVerseNum -gt 0) {
                    # Trim the accumulated HTML and save the verse
                    $finalHtml = $verseHtml.ToString().Trim()

                    # Collapse any remaining multi-space runs in the HTML text
                    # (but not inside tag attributes — safe because attributes
                    # use quotes and encoded values, not bare spaces)
                    $finalHtml = [regex]::Replace($finalHtml, '(?<=>)\s+(?=<)', ' ')

                    [void]$verses.Add(@{
                        Num   = $currentVerseNum
                        Html  = $finalHtml
                        Xrefs = @($verseXrefs)
                    })
                }
                $inVerse = $false
            }
            continue
        }

        # ── Everything below only matters if we're inside a verse ──
        if (-not $inVerse) { continue }

        switch ($localName) {

            # ── <w> — Word with Strong's reference ──
            'w' {
                $word  = $node.InnerText
                $lemma = $node.GetAttribute('lemma')
                $linkHtml = Get-StrongLinkHtml -Word $word -Lemma $lemma -DictRelPath $DictRelPath
                [void]$verseHtml.Append($linkHtml)
            }

            # ── <transChange> — Translator-added words (KJV italics) ──
            'transChange' {
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                [void]$verseHtml.Append("<em class=`"added`">$text</em>")
            }

            # ── <note> — Cross-references and footnotes ──
            'note' {
                $noteType = $node.GetAttribute('type')
                if ($noteType -eq 'crossReference') {
                    # Collect all <reference> osisRef values for the xref page
                    foreach ($childNode in $node.ChildNodes) {
                        if ($childNode.NodeType -eq [System.Xml.XmlNodeType]::Element -and
                            $childNode.LocalName -eq 'reference') {
                            $osisRef = $childNode.GetAttribute('osisRef')
                            if ($osisRef) {
                                [void]$verseXrefs.Add($osisRef)
                            }
                        }
                    }
                }
                # Other note types (study notes, translation notes) can be
                # handled here in a future phase if needed.
            }

            # ── <divineName> — "LORD" in small caps ──
            'divineName' {
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                [void]$verseHtml.Append("<span class=`"divine-name`">$text</span>")
            }

            # ── <hi> — Highlighted/formatted text ──
            'hi' {
                $hiType = $node.GetAttribute('type')
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                switch ($hiType) {
                    'italic'    { [void]$verseHtml.Append("<em>$text</em>") }
                    'bold'      { [void]$verseHtml.Append("<strong>$text</strong>") }
                    'super'     { [void]$verseHtml.Append("<sup>$text</sup>") }
                    'sub'       { [void]$verseHtml.Append("<sub>$text</sub>") }
                    default     { [void]$verseHtml.Append($text) }
                }
            }

            # ── <title> — Section/psalm titles inside a verse ──
            'title' {
                $text = [System.Net.WebUtility]::HtmlEncode($node.InnerText)
                [void]$verseHtml.Append("<span class=`"section-title`">$text</span> ")
            }

            # ── Anything else: extract text safely ──
            default {
                $text = $node.InnerText
                if ($text) {
                    [void]$verseHtml.Append([System.Net.WebUtility]::HtmlEncode($text))
                }
            }
        }
    }

    # ── Handle edge case: verse started but file ended without eID ──
    # (shouldn't happen in valid OSIS, but be defensive)
    if ($inVerse -and $currentVerseNum -gt 0) {
        [void]$verses.Add(@{
            Num   = $currentVerseNum
            Html  = $verseHtml.ToString().Trim()
            Xrefs = @($verseXrefs)
        })
    }

    return $verses
}


# ================================================================
# USAGE EXAMPLE
#
# This shows how the caller in generate_bible.ps1 would use
# ConvertTo-VerseHtml to build a chapter page.
# ================================================================
<#
    # Load the OSIS XML
    [xml]$osis = Get-Content -Path "kjv.osis.xml" -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager($osis.NameTable)
    $ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

    # Get a chapter node (e.g. Genesis 1)
    $chapterNode = $osis.SelectSingleNode("//o:chapter[@osisID='Gen.1']", $ns)

    # Parse all verses
    $verses = ConvertTo-VerseHtml `
        -ChapterNode $chapterNode `
        -BookFolder "01-Gen" `
        -BookName "Genesis" `
        -ChapterNum 1

    # Build the chapter HTML
    $bodyHtml = [System.Text.StringBuilder]::new()
    foreach ($v in $verses) {
        [void]$bodyHtml.AppendLine("  <p class=`"verse`" id=`"verse-$($v.Num)`">")
        [void]$bodyHtml.AppendLine("    <span class=`"verse-num`">$($v.Num)</span>")
        [void]$bodyHtml.AppendLine("    $($v.Html)")

        # Add xref superscript if this verse has cross-references
        if ($v.Xrefs.Count -gt 0) {
            $osisId = "Gen.$($ChapterNum).$($v.Num)"
            $xrefHref = "../../xrefs/$osisId.html"
            [void]$bodyHtml.AppendLine("    <a href=`"$xrefHref`" class=`"superscript-link`" title=`"Cross-references`">&#x2020;</a>")
        }

        [void]$bodyHtml.AppendLine("  </p>")
    }

    # $bodyHtml.ToString() is now ready to insert into the chapter template
    # $verses also provides .Xrefs data for generating xref pages
#>


# ================================================================
# QUICK VERIFICATION
#
# Run this block to test the fix against your actual OSIS file.
# It reports the verse count for every chapter in the 6 affected
# books so you can compare against expected counts.
# ================================================================
<#
    [xml]$osis = Get-Content -Path "kjv.osis.xml" -Raw
    $ns = New-Object System.Xml.XmlNamespaceManager($osis.NameTable)
    $ns.AddNamespace('o', 'http://www.bibletechnologies.net/2003/OSIS/namespace')

    $testBooks = @(
        @{ Abbr = 'Matt'; Name = 'Matthew';    Chapters = 28 }
        @{ Abbr = 'Mark'; Name = 'Mark';        Chapters = 16 }
        @{ Abbr = 'Luke'; Name = 'Luke';        Chapters = 24 }
        @{ Abbr = 'John'; Name = 'John';        Chapters = 21 }
        @{ Abbr = 'Acts'; Name = 'Acts';        Chapters = 28 }
        @{ Abbr = 'Rev';  Name = 'Revelation';  Chapters = 22 }
    )

    foreach ($book in $testBooks) {
        Write-Host "`n=== $($book.Name) ===" -ForegroundColor Cyan
        for ($ch = 1; $ch -le $book.Chapters; $ch++) {
            $osisId = "$($book.Abbr).$ch"
            $chNode = $osis.SelectSingleNode("//o:chapter[@osisID='$osisId']", $ns)
            if (-not $chNode) {
                Write-Host "  Chapter $ch — NOT FOUND IN XML" -ForegroundColor Red
                continue
            }

            $verses = ConvertTo-VerseHtml `
                -ChapterNode $chNode `
                -BookFolder "test" `
                -BookName $book.Name `
                -ChapterNum $ch

            $count = $verses.Count
            Write-Host "  Chapter $ch — $count verses" -ForegroundColor Green
        }
    }
#>
