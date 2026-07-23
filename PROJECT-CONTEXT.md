# KJV Strong's Bible — Project Context & Recent History

This document exists to bring a new Claude session up to speed quickly after
hitting the 100-file conversation limit. Read this before doing anything else.

## What this project is

A static-HTML KJV Bible with Strong's concordance, originally built for an
old Kindle Fire (Gingerbread/WebKit — hence ES3-only JS, no flexbox/grid/CSS
vars in `style-kindle.css`). It has since grown into:

- An Electron desktop app (installed at
  `C:\Users\OldTi\AppData\Local\KJVStrongs`) for PC study, running a
  PowerShell HTTP server (`start-study.ps1`) on `localhost:8080`.
- A phone-access mode: a hand-rolled TCP proxy relays LAN traffic from
  `192.168.86.39:8081` to `localhost:8080`, letting a phone on the same WiFi
  reach the same server the PC uses. Phone connects via QR code or a bookmark
  / installed PWA icon.
- Full offline support on the phone via a service worker (`sw.js`) and a
  "Download for Offline" feature (separate Bible-text and Lexicon downloads).
- Bidirectional note/highlight sync between phone (localStorage) and PC
  (`notes.json` / `highlights.json`), so notes taken at church sync home.

## Repo vs. installed app vs. scripts/ — the three-location trap

This caused enormous confusion this week. There are (at least) **three**
places files can live, and it's easy to edit one and forget the others:

1. **Local git repo**: `C:\Users\OldTi\KJV-Strongs\` — the source of truth,
   pushed to GitHub (`RonTurrentine/KJV-Strongs-EBook`).
2. **Installed Electron app**: `C:\Users\OldTi\AppData\Local\KJVStrongs\` —
   a separate, independent copy that the desktop app actually runs from.
   Editing files in the repo does **nothing** until they're copied here (or
   pushed through whatever "Update Now" mechanism exists) and the app is
   restarted.
3. **`scripts/` folder within the repo** — contains **template/model**
   copies of certain files that `generate_bible.ps1` copies into the repo
   root during generation:
   - `search.html`, `about.html`, `help.html` (static, copied as-is or with
     SHA/VERSION injected)
   - `manifest.json`, `sw.js`, `icon-192.png`, `icon-512.png` (PWA shell
     files)
   - **`sw.js` specifically gets a SHA injected**: `generate_bible.ps1`
     does a literal string replace of `KJV_SHA_PLACEHOLDER` →
     `$InstalledSha` inside the copied `sw.js`, so each install/update gets
     a unique cache-version name, forcing old cached pages to be discarded.
     **If you edit `sw.js`, edit `scripts/sw.js` (the template), not just
     the root copy** — the root copy gets silently overwritten by the next
     `generate_bible.ps1` run.
   - `generate_dict.ps1` does **not** copy/inject any of these — it only
     references them (relative links, service worker registration).
   - `js/notes.js`, `css/style.css`, and `start-study.ps1` are **NOT** in
     this template-copy pattern (confirmed by their absence from
     `scripts/`) — editing them directly in the repo root is safe.
   - `scripts/lan-proxy.ps1` exists but its relationship to
     `start-study.ps1`'s embedded `Initialize-LanProxy` function is
     **unconfirmed** — worth checking before assuming either is safe to
     edit in isolation.

**Going forward, the user wants this workflow, and it's a good one:**
edit only in the local repo → regenerate (bible + dict) → QA test → rebake
notes → verify locally → `git commit` + push to GitHub → then update the
installed app (copy files or via "Update Now"). Never edit the installed
app directly again.

## Fixes made this session (chronological, high-level)

1. **LAN proxy `Connection: close` fix** (`start-study.ps1`,
   `Initialize-LanProxy`/`LanProxy` C# class): the proxy only rewrote the
   `Host` header on the *first* request of a raw TCP connection; anything
   sent later on a kept-alive connection bypassed the rewrite entirely and
   got rejected by `HttpListener` with a generic 400 (`Microsoft-HTTPAPI`
   error page). Fixed by also injecting `Connection: close` so every request
   gets a fresh connection (and thus a fresh rewrite). Tradeoff: slightly
   slower page loads (new TCP handshake per resource) — acceptable for a
   personal LAN app.

2. **Mobile header layout** (`css/style.css`): `.chapter-nav` on narrow
   screens was clipping the nav buttons entirely (`overflow: hidden` +
   fixed height + floated title/buttons competing for width). Fixed with a
   `@media (max-width: 600px)` block that stacks title above buttons in two
   rows, sized to match the existing 90px header height so
   `.chapter-content`'s `padding-top: 95px` didn't need to change. Buttons
   use flexbox for reliable centering (safe here — this media query only
   applies to modern phone browsers, not the ES3-constrained Kindle).

3. **Chrome secure-context blocker for service workers on LAN IPs**:
   `navigator.serviceWorker` doesn't exist at all on plain `http://` origins
   that aren't `localhost` — confirmed via `TypeError: Cannot read
   properties of undefined (reading 'getRegistration')`. Workaround used:
   `chrome://flags/#unsafely-treat-insecure-origin-as-secure` with the LAN
   origin added, on the phone. **Real fix (HTTPS via self-signed cert, e.g.
   mkcert) is still outstanding** — flagged as a explicit follow-up, not
   done this session.

4. **Offline "Download for Offline" feature** (`js/notes.js`, `js/sw.js`):
   - Single `downloadOffline(kind)` function (`'bible'` or `'lexicon'`),
     matching the existing HTML calling convention (found in
     `generate_bible.ps1`/`generate_dict.ps1`/`search.html` — don't assume
     two separately-named functions).
   - Builds chapter URLs from `BIBLE_DATA` (loaded on-demand via a
     dynamically-injected `<script>` tag, since `bible-data.js` isn't
     normally loaded on chapter pages) and dictionary URLs as
     `/dict/hebrew/h####.html` (1–8674) / `/dict/greek/g####.html`
     (1–5624).
   - Progress modal reuses the existing "Update Available" modal CSS
     classes (`update-modal`, `update-progress-bar`, etc.) for visual
     consistency.
   - `sw.js`'s bulk-download handler needed `event.waitUntil()` — without
     it, the browser was killing the service worker mid-download for being
     "idle" (the promise chain wasn't actually wired to reflect true
     completion time before this fix either — both had to be fixed
     together).
   - Added `cancel-job` message type + resume support (`cache.match()`
     check before each fetch, so a re-run skips already-cached URLs).
   - Added a Screen Wake Lock request while downloading.

5. **Phone/PC note sync — the big one.** Root causes, in the order they
   were found:
   - `isPhoneMode` in `notes.js` hardcoded `loc.port === "8080"`, so it
     never activated once phone traffic moved to the LAN proxy (port
     8081). Fixed by keying off hostname/protocol instead of a specific
     port (any non-localhost, non-file HTTP(S) origin = phone mode).
   - `countPendingNotes()` counted *every* highlight as pending forever
     (no timestamp comparison for highlights, unlike notes). Fixed with a
     `LS_SYNCED_HIGHLIGHTS` snapshot to compare against.
   - Sync banner spammed "up to date" on every page navigation. Fixed with
     a `sessionStorage` flag so it only shows once per session unless
     something's actually pending.
   - The "offline" banner state had no dismiss button at all (unlike the
     other states) — fixed.
   - **The real timestamp bug**: PowerShell's `Get-Date -Format "o"` uses
     the machine's *local* timezone (e.g. `...-05:00`), while JS's
     `toISOString()` is always UTC (`...Z`). String comparisons between
     the two (`notes[key].updated > lastSync`) are invalid whenever the
     offsets differ. This made PC notes look permanently "newer" than any
     sync, forever.
   - **A destructive first fix**: the initial migration function's `catch`
     block fell back to "now" on any parse failure, which — combined with
     the next bug — silently overwrote real historical timestamps with the
     current moment. **Recovered from a June 29 backup the user had.**
     Lesson: never silently default to "now" for unparseable data; leave it
     unchanged and log it instead.
   - **The real root cause of repeated corruption**:
     `ConvertFrom-Json -AsHashtable` silently auto-parses ISO-8601-looking
     JSON string values into real `[DateTime]` .NET objects — it does
     **not** keep them as strings. When that `DateTime` (already correct,
     `Kind=Utc`) got passed to something expecting a string, PowerShell
     silently re-stringified it with `DateTime`'s bare default format
     (`"06/21/2026 21:43:27"` — **no timezone info at all**). Re-parsing
     that with `DateTimeOffset::Parse` then assumed the machine's *local*
     offset to fill the gap, adding 5 more hours to an already-correct
     value. This is why "already migrated" checks kept failing and values
     kept drifting further on every subsequent load — **it wasn't a
     migration-logic bug so much as a fundamental silent-type-coercion
     trap in PowerShell's JSON parsing.**
   - **Final fix**: `Get-NormalizedTimestamp` explicitly checks the
     runtime type. If it's a `[DateTime]`, converts based on its actual
     `.Kind` (Utc/Local/Unspecified) directly — never round-tripping
     through an ambiguous string. `Get-Notes()` now always normalizes on
     every call (safe because this version is genuinely idempotent).
     Confirmed stable across multiple consecutive server restarts.
   - **Result confirmed working end-to-end**: notes now correctly settle
     into "up to date" and stay there; sync pulls PC-only notes to a fresh
     phone; cross-device edits merge/conflict-resolve correctly.

6. **`sw.js` CACHE_VERSION regression** (found during this GitHub-audit
   pass, not yet deployed): the current `sw.js` hardcodes
   `"kjv-cache-v1"` instead of containing the `KJV_SHA_PLACEHOLDER` token
   that `generate_bible.ps1` expects to replace. This silently broke the
   SHA-based cache-busting design from an earlier session. **Fixed in
   `scripts/sw.js`** (changed to `"kjv-cache-KJV_SHA_PLACEHOLDER"`) but
   **not yet copied into the repo by the user as of this writing** — check
   `scripts/sw.js` in a new session and confirm this landed.

## Git audit findings — RESOLVED this session

- `kjv.osis.xml` "modified" status was pure line-ending noise (empty
  `git diff`, LF/CRLF only). Fixed with `.gitattributes` (`kjv.osis.xml
  -text`) + `git restore kjv.osis.xml`. Do **not** gitignore this file —
  it's the master source data `generate_bible.ps1` reads from.
- `search.html`'s diff (77 insertions / 3 deletions) was confirmed
  **legitimate and safe** — it brings the search page's header up to
  parity with chapter pages (settings-dropdown/hamburger menu, PWA
  manifest link, service-worker registration, `js/notes.js` load, moved
  font-size buttons into the dropdown). Not corruption, safe to commit.
- `highlights.json` added to `.gitignore` (repo is **public** — confirmed
  with the user — so personal highlight data must never be committed).
  `notes.json` was already correctly gitignored.
- `installed-sha.txt`, `.sync-token.json`, `migration-warnings.log` added
  to `.gitignore` (machine-local/transient runtime state, not source).
- `css/style_OLD.css` (stray leftover backup) deleted, not gitignored —
  one-off cleanup, not a systemic pattern worth a permanent rule.
- **`git-push.ps1` had a real gap**: it only staged `css/`, `js/`,
  `scripts/`, `.github/`, and a short explicit root-file list — it never
  staged `sw.js`, `manifest.json`, `icon-192.png`, `icon-512.png`,
  `about.html`, `help.html`, or `search.html`, all of which live at the
  repo root outside those folders. This meant the **entire PWA/offline
  feature set could have silently never been pushed to GitHub** even
  after committing. Fixed by adding explicit `git add` lines for each of
  these, plus `.gitattributes` and `PROJECT-CONTEXT.md`.
- **`scripts/sw.js` CACHE_VERSION regression** (found in an earlier pass
  this session) — confirmed fixed and copied in by the user; the
  `generate_bible.ps1` run afterward printed `sw.js SHA injected:
  2e53680...`, confirming the placeholder mechanism works again.

## Regenerate → QA → rebake → commit workflow — confirmed working

Ran once, end-to-end, this session, as the new standard process:

1. `pwsh scripts\generate_bible.ps1` — 1189 chapters, PWA files copied +
   SHA-injected correctly.
2. `pwsh scripts\generate_dict.ps1` — 8674 Hebrew + 5624 Greek entries
   (14298 total, matches the offline-download feature's numbers exactly).
3. `pwsh scripts\qa-test.ps1` — 155/155 passed. **Important caveat: this
   script predates almost everything built this session (LAN proxy,
   mobile header, offline download, phone/PC sync) — a clean pass only
   confirms it didn't break whatever the script already knew to check
   (verse completeness, concordance integrity, etc.), not that this
   week's features still work.** A manual smoke test is still required
   after every regenerate until qa-test.ps1 is updated to cover the newer
   features (not done this session — worth adding as a future task).
4. `pwsh scripts\rebake-notes.ps1` — 42 notes + 33 highlights baked back
   into the freshly-regenerated chapter HTML, 0 errors.
5. Manual smoke test (server started from the **repo**, not the installed
   app) — confirmed notes/highlights display correctly, mobile header
   still correct, offline download modal still opens correctly, phone/PC
   sync still settles to "up to date." All passed.
6. Git cleanup (`.gitignore`/`.gitattributes`/`git-push.ps1` fixes above),
   then `git status` review, then `pwsh scripts\git-push.ps1 -Message
   "..."`.

## Next major feature (design phase, not yet started): Notes Management System

Originally just "All My Notes" (a page listing every note OT → NT with
jump links, also useful as an ad-hoc QA tool) — now expanded into a
bigger vision the user calls "the next major app upgrade": a **tagging/
indexing system** on top of that page. Tag a note "Justification" or
"Second Coming", then filter the whole note collection by tag to see
every related note/verse across the entire Bible — cross-referential
topical study, not just per-verse annotation. User believes this would
be a genuine differentiator vs. other Bible apps (hasn't seen this
feature elsewhere).

Key design questions raised, **not yet decided** — work through together
in a dedicated session:

1. **Tags as a new field on each note** (`tags: [...]`) — small, contained
   data-model change, but the *existing* sync/merge logic (both
   `Handle-SyncNotes` in `start-study.ps1` and the phone-side sync code in
   `notes.js`) needs to correctly carry this field through too. Contained,
   not a redesign, but must be deliberate given how much effort went into
   getting sync right.
2. **Tag consistency**: recommend storing/matching tags case-insensitively
   with a remembered "nice" display form, and offering autocomplete of
   already-used tags when adding new ones, to avoid silent fragmentation
   ("Second Coming" vs "second coming" as accidentally-different tags).
3. **Read-only browsing vs. edit-in-place**: user wants to use this page to
   spot notes needing "attention/updating" — which leans toward wanting
   real inline editing, not just view+jump-to-verse. Meaningfully affects
   scope; user explicitly deferred this decision to the design session
   rather than choosing now.
4. **Data source**: no new sync infrastructure needed — this page just
   reads from whatever the current device already considers "current"
   notes (PC's `/api/notes`, or phone's `localStorage`), same as
   everything else already does.

Not started. Pick up here next session on this topic.


## Update log — July 8, 2026

Real-world phone testing (a day after the stale-while-revalidate fix)
surfaced four smaller UI/UX issues, all fixed:

- **Verse number line break on phone**: `.verse-num { display: block; }`
  was a *pre-existing* rule inside `@media (max-width: 800px)`, predating
  this project's recent work — not something introduced this week. PC is
  almost always wider than 800px so never saw it; any phone did. Removed
  per user preference (now matches PC's inline verse-number style).
- **Search Scope page on phone**: two-column category checkboxes were
  still overflowing/cutting off text even after the `max-width: 600px`
  stacking fix from July 7 — likely a deployment/caching gap rather than
  the fix being wrong (unconfirmed as of this writing; check whether it's
  still an issue after a fresh push + hard refresh). Added
  `overflow-x: hidden` on `.scope-panel`/`.search-page-wrap` as a safety
  net regardless.
- **Hebrew/Greek index controls wrapping**: "Showing X of Y" + "Show:
  50/100/200/All" buttons wrapped awkwardly (All orphaned alone). Fixed
  by forcing `.index-status` to `flex-basis: 100%` on mobile so the
  status takes its own row and the buttons wrap together as a group.
- **Sync banner shown on every page**: previously only suppressed
  *repeats* of the same banner state within a session (July 7 fix) — user
  wanted it restricted to the **Home page only**, full stop. Implemented:
  `checkPcReachable()` still runs on every page (needed for Search
  visibility everywhere), but the actual banner display is now gated on
  `isHomePage`. Tradeoff: no fresh "you're offline" notice if you go
  offline while deep in a reading session away from Home until you next
  visit Home — flagged to user, not yet confirmed if acceptable long-term.

### On Claude's memory system (clarified for user this session)

User asked whether Claude's cross-conversation memory means session notes
/ this file are no longer needed for new sessions. Clarified: memory
stores periodically-generated high-level summaries (name, ongoing
projects, preferences) — not file contents, code, or session-note-level
technical detail, and may lag behind recent conversations. **Continue
uploading this file + session notes at the start of new sessions** — memory
is a nice-to-have on top, not a replacement for the detailed handoff this
project needs. User has agreed to keep doing this, and asked Claude to
keep adding to this file proactively as new crucial details emerge.


- Real HTTPS setup (self-signed cert via mkcert or similar) so phone
  service-worker registration doesn't require the manual Chrome flag
  workaround. Explicitly deferred, not forgotten.
- Confirm `scripts/lan-proxy.ps1`'s actual relationship to
  `start-study.ps1` (unresolved question from this session — still open).
- **`qa-test.ps1` needs updating** to actually cover this session's work
  (LAN proxy behavior, mobile header layout, offline download, phone/PC
  sync) — right now a clean QA pass only proves the regenerate didn't
  break pre-existing structural checks (verse counts, concordance
  integrity), not that any of this week's features still work. A manual
  smoke test is required after every regenerate until this is addressed.
- **"All My Notes" page** — a single page listing every note OT → NT with
  jump links, doubling as a QA tool. Explicitly requested, explicitly
  deferred to a future session.
- Fold the Hebrew/Greek index pages (`indexes/strongs-hebrew-index.html`,
  `strongs-greek-index.html`) and `navigate.html` into the bulk
  offline-download URL list — currently they only get cached
  opportunistically if visited manually while online.
- Consider whether the LAN proxy's per-request `Connection: close`
  performance tradeoff is worth revisiting later (teaching the proxy to
  parse and rewrite each pipelined request instead of just the first, to
  restore keep-alive) — not urgent, flagged for later.

## Key file locations quick-reference

- `start-study.ps1` — PC server + LAN proxy + all API handlers (repo root)
- `js/notes.js` — notes/highlights/sync/offline-download UI logic (repo)
- `js/sw.js` (root) — service worker (repo; also templated from
  `scripts/sw.js`, see above)
- `css/style.css` — all styling including Kindle constraints + mobile
  media query (repo)
- `bible-data.js` — book/chapter/folder manifest, generated by
  `generate_bible.ps1`, loaded on-demand by `downloadOffline('bible')`
- `notes.json` / `highlights.json` — PC-side personal data (repo root,
  gitignore status: see audit section above)
- `scripts/` — templates copied into repo root during generation; see
  "three-location trap" section above for exactly which files
