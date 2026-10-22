# Recall

A private "search my whole Mac" app for macOS. Press **⌥Space**, type something vague
("pdf about visa rules", "that link about rust async", "billing plans screenshot") and Recall
finds it across your files, screenshots and clipboard history.

Everything stays on your Mac: no cloud, no account, no network calls, no telemetry.

## What it searches

| Source | What gets indexed |
| --- | --- |
| **Files** in Desktop, Documents, Downloads (plus any folders you add) | Text, Markdown, code, JSON/CSV, PDFs, Word/RTF/OpenDocument, saved web pages (visible text). Pages files by name. |
| **Screenshots & images** | Text inside the image (Apple Vision, on-device) plus a thumbnail. New screenshots are searchable within about a second. |
| **Clipboard history** | Text, links and copied images (with their text). Items password managers mark as concealed are never stored. Kept 30 days by default. |

Skipped: hidden folders, `.git`, `node_modules`, `.build`, `DerivedData`, `Library`, `venv`/`.venv`,
`__pycache__`, files over 50 MB, and binaries.

## Using it

- **⌥Space** opens and closes the search panel (change it in Settings).
- Results update as you type. **↑↓** select, **↩** open, **⌘↩** show in Finder, **⌘C** copy
  (clipboard items go back on the clipboard; files copy like in Finder).
- **⌘Y** previews with Quick Look. **Space** previews too, once you've moved through the results with the arrow keys.
- Filter with the tabs, or type **/f** (files), **/s** (screenshots) or **/c** (clipboard).
- The menu-bar icon shows indexing progress and has Pause Indexing, Settings and Quit.

**Settings** has four tabs:
- **General:** hotkey, launch at login.
- **Folders:** add, remove or reset the indexed folders.
- **Clipboard:** turn history on or off, set how long to keep it, clear it.
- **Data:** stats, pause indexing, and Clear All Data.

## How search works

Each query runs two searches and merges them:

1. **Keyword search:** SQLite FTS5 with the Porter stemmer, so "travel" also matches "travelling".
   If not every word matches, results with only some of the words are added at half weight.
2. **Meaning search:** each ~800-character chunk gets a vector. Similarity is computed by
   brute-force cosine with Accelerate (vDSP), with no vector database.

The two lists are merged with Reciprocal Rank Fusion (k = 60), plus a small boost for recent items.

**About meaning-search quality.** Vectors come from Apple's built-in models, which need no download.

- **The default embedder** averages Apple's English word vectors (`NLEmbedding`), minus a fixed
  "average text" vector. On a 12-query test it ranked the right document first 11 of 12 times,
  against 7 of 12 for mean-pooled `NLContextualEmbedding`. It is also about 8× faster to compute and smaller (300 dimensions).
- **It's a rough topic match, not real sentence understanding.** On a real Mac it works for queries
  like "billing plans" or "bill to pay". It can't reliably connect "pricing table" to a screenshot
  that only says "Plans & Billing $29/mo".
- **A dedicated sentence model** (for example all-MiniLM or bge-small converted to Core ML) would do much
  better. It plugs in behind the `Embedder` protocol (`Embedding/Embedder.swift`), but it needs a one-time model download.
- **Code and data files** (JS, JSON, CSV…) are keyword-only, so they don't drown out real meaning matches.

## Build & run

Requirements: macOS 14+, Apple Silicon, Xcode (full app, not just Command Line Tools), XcodeGen.

```bash
brew install xcodegen
./scripts/build.sh                  # Debug build → build/Recall.app, installs to ~/Applications
CONFIG=Release ./scripts/build.sh   # Release build
open ~/Applications/Recall.app
```

`build.sh` runs `xcodegen generate` (`project.yml` → `Recall.xcodeproj`), then `xcodebuild`. It copies the app to
`~/Applications/Recall.app` (set `INSTALL=0` to skip that). Package versions are pinned in `project.yml`:
GRDB 7.11.1 and KeyboardShortcuts 2.4.0.

## Permissions

- **Desktop, Documents, Downloads:** macOS asks the first time Recall indexes each one. Click **Allow**.
  If you clicked Don't Allow, Settings → Folders marks the folder. To fix it, open
  **System Settings → Privacy & Security → Files and Folders → Recall**, turn the folders on, then quit and reopen Recall.
- **Re-asking after rebuilds:** local builds are signed ad hoc, so each rebuild looks like a new app to macOS and it may ask again.
- **Launch at login:** if macOS asks, approve Recall in **System Settings → General → Login Items**.
- **Not needed:** Accessibility, Screen Recording, Full Disk Access (optional, if you want folders outside your home folder).

## Where data lives

Everything is in `~/Library/Application Support/Recall/`:
- `recall.sqlite` holds items, chunks, the FTS5 index and the vectors.
- `thumbs/` holds image thumbnails.
- `clips/` holds copied images.

Deleting an item removes its thumbnail too. **Settings → Data → Clear All Data** wipes everything, and your files then get indexed again.

## Performance

Measured on an Apple Silicon Mac, Debug build, about 1,400 items / 59,000 chunks:

| Check | Target | Measured |
| --- | --- | --- |
| Idle memory (physical footprint) | < 150 MB | ~60 MB |
| Search latency, keyword + meaning | < 100 ms on 50k chunks | 5–16 ms typical, 52 ms worst (1-letter query) |
| Meaning search alone | | 8 ms over 50k vectors, 31 ms over 200k |
| Indexing CPU | no spikes | ≤ ~90% of one core (of 10), utility priority, then idle |
| New screenshot → searchable | ~5 s | under 1 s |

Vectors are held in memory as Float32 at 1.2 KB per chunk (about 60 MB at 50k embedded chunks).
Storing them as Float16 would halve that if indexes grow much larger.

## Code layout

```
App/        app entry, menu bar, preferences, Debug-only test hook
UI/         search panel (NSPanel + SwiftUI), results, Settings window
Indexing/   folder scanner, FSEvents watcher, one extractor per source type
            (plain text, PDF, rich documents, images/OCR), clipboard watcher, indexer
Search/     keyword (FTS5) + vector search, RRF ranking
Storage/    GRDB database and schema
Embedding/  Embedder protocol, word-vector and contextual embedders, background worker
scripts/    build script and dev helpers
```

**Debug test hook.** Debug builds can be driven from the terminal, for automated checks without
screen access. It only turns on when launched with `open --env RECALL_DEBUG_BRIDGE=1 ~/Applications/Recall.app`,
writes output only to `~/Library/Application Support/Recall/debug/`, and isn't compiled into Release builds.
See `App/DebugBridge.swift` and `scripts/recall-debug.swift`.

## Not in v1 (ideas for v2)

- Browser history (Chrome, Arc, Safari)
- Screen "time machine" capture with app exclusions
- An "Ask" mode that answers questions across results
- A stronger embedding model via Core ML
