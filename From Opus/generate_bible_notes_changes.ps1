# ================================================================
# generate_bible.ps1 — NOTES INTEGRATION CHANGES
# ================================================================
#
# This file shows the EXACT changes needed in your existing
# generate_bible.ps1 to add note support to every verse.
#
# Two additions per verse:
#   1. A pencil button INSIDE the verse <p>, after the verse number
#   2. A placeholder <div> AFTER the verse <p> for baked notes
#
# ================================================================


# ────────────────────────────────────────────────────────────────
# CHANGE 1: In your Write-ChapterPage function (or wherever you
# build the HTML for each verse), modify the verse <p> generation.
#
# BEFORE (current code):
# ────────────────────────────────────────────────────────────────

<#
    # Current verse HTML generation (approximately):
    [void]$bodyHtml.AppendLine("  <p class=`"verse`" id=`"verse-$($v.Num)`">")
    [void]$bodyHtml.AppendLine("    <span class=`"verse-num`">$($v.Num)</span>")
    [void]$bodyHtml.AppendLine("    $($v.Html)")

    # Xref superscript (if present)
    if ($v.Xrefs.Count -gt 0) {
        $osisId = "$($BookAbbr).$ChapterNum.$($v.Num)"
        $xrefHref = "../../xrefs/$osisId.html"
        [void]$bodyHtml.AppendLine("    <a href=`"$xrefHref`" class=`"superscript-link`" title=`"Cross-references`">&#x2020;</a>")
    }

    [void]$bodyHtml.AppendLine("  </p>")
#>


# ────────────────────────────────────────────────────────────────
# AFTER (with note pencil button and placeholder div):
# ────────────────────────────────────────────────────────────────

<#
    # Build the OSIS-style verse reference for this verse
    $verseRef = "$BookAbbr.$ChapterNum.$($v.Num)"

    # Verse paragraph with pencil button
    [void]$bodyHtml.AppendLine("  <p class=`"verse`" id=`"verse-$($v.Num)`">")
    [void]$bodyHtml.AppendLine("    <span class=`"verse-num`">$($v.Num)</span>")

    # ── NEW: Note pencil button ──
    [void]$bodyHtml.Append("    <button class=`"note-btn`" onclick=`"openNoteModal('$verseRef')`" title=`"Add note`">&#9998;</button>")

    [void]$bodyHtml.AppendLine("    $($v.Html)")

    # Xref superscript (if present)
    if ($v.Xrefs.Count -gt 0) {
        $xrefHref = "../../xrefs/$verseRef.html"
        [void]$bodyHtml.AppendLine("    <a href=`"$xrefHref`" class=`"superscript-link`" title=`"Cross-references`">&#x2020;</a>")
    }

    [void]$bodyHtml.AppendLine("  </p>")

    # ── NEW: Note placeholder div ──
    # This empty div is where bake-notes fills in the note content.
    # Must be present for every verse so the baking regex can find it.
    [void]$bodyHtml.AppendLine("  <div class=`"verse-note`" id=`"note-verse-$($v.Num)`"></div>")
#>


# ────────────────────────────────────────────────────────────────
# CHANGE 2: In your chapter HTML template (the <head> section or
# the script tags at the bottom), add notes.js.
#
# The <script> section at the bottom of each chapter page should
# now include notes.js:
# ────────────────────────────────────────────────────────────────

<#
    # Script tags at bottom of chapter HTML template:
    $scripts = @"
  <script src="../../js/fontsize.js"></script>
  <script src="../../js/bookmarks.js"></script>
  <script src="../../js/sticky-header.js"></script>
  <script src="../../js/notes.js"></script>
"@
#>


# ────────────────────────────────────────────────────────────────
# CHANGE 3: Add Sync button to the nav-buttons div.
#
# In the chapter template where you build the navigation buttons,
# add the Kindle sync button after the font size buttons:
# ────────────────────────────────────────────────────────────────

<#
    # Inside the <div class="nav-buttons"> section:
    $syncButton = '<button class="btn sync-btn" onclick="syncToKindle()" title="Sync to Kindle">&#9889; Sync</button>'

    # Full nav-buttons example:
    $navButtons = @"
    <div class="nav-buttons">
      <a href="../../index.html" class="btn">Books</a>
      <a href="../../navigate.html" class="btn">Go To</a>
      $prevLink
      $nextLink
      <button class="btn" id="font-decrease" onclick="decreaseFontSize()">a&#8595;</button>
      <button class="btn" id="font-increase" onclick="increaseFontSize()">A&#8593;</button>
      $syncButton
      <span id="unbaked-indicator"></span>
    </div>
"@
#>


# ────────────────────────────────────────────────────────────────
# RESULTING HTML (example for Genesis 1:1):
# ────────────────────────────────────────────────────────────────

<#
  <p class="verse" id="verse-1">
    <span class="verse-num">1</span>
    <button class="note-btn" onclick="openNoteModal('Gen.1.1')" title="Add note">&#9998;</button>
    In the beginning <a href="../../dict/hebrew/h7225.html" class="strongs-link" title="H7225">God</a> ...
    <a href="../../xrefs/Gen.1.1.html" class="superscript-link" title="Cross-references">&#x2020;</a>
  </p>
  <div class="verse-note" id="note-verse-1"></div>

  <p class="verse" id="verse-2">
    <span class="verse-num">2</span>
    <button class="note-btn" onclick="openNoteModal('Gen.1.2')" title="Add note">&#9998;</button>
    And the earth was without form, ...
  </p>
  <div class="verse-note" id="note-verse-2"></div>
#>


# ────────────────────────────────────────────────────────────────
# SUMMARY OF ALL CHANGES:
# ────────────────────────────────────────────────────────────────
#
# 1. Build $verseRef = "$BookAbbr.$ChapterNum.$($v.Num)" for each verse
#
# 2. Add pencil button AFTER the verse-num span:
#    <button class="note-btn" onclick="openNoteModal('{verseRef}')"
#            title="Add note">&#9998;</button>
#
# 3. Add empty note placeholder AFTER the closing </p> of each verse:
#    <div class="verse-note" id="note-verse-{N}"></div>
#
# 4. Add <script src="../../js/notes.js"></script> to the template
#
# 5. Add sync button to nav-buttons div:
#    <button class="btn sync-btn" onclick="syncToKindle()"
#            title="Sync to Kindle">&#9889; Sync</button>
#
# These changes must be made and the generator re-run to produce
# chapter files with note support.
# ────────────────────────────────────────────────────────────────
