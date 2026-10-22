# Recall

A private "search my whole Mac" app for macOS. Press **⌥Space**, type something vague
("pdf about visa rules", "that link about rust async", "billing plans screenshot") and Recall
finds it across your files, screenshots and clipboard history.

Everything stays on your Mac: no cloud, no account, no telemetry. Your files, searches and clipboard
never leave it. The only network request is the Pro license check (see [Free and Pro](#free-and-pro)).

## Free and Pro

| | Free | Pro |
| --- | --- | --- |
| File search (keyword + meaning) in Desktop, Documents, Downloads | ✓ | ✓ |
| Clipboard history search | last 7 days | everything kept |
| Screenshot text search | | ✓ |
| Extra folders | | ✓ |
| Keep clipboard for 90 days / 1 year | | ✓ |

**Nothing is deleted when Pro is off.** Screenshots stay indexed and older clipboard items stay stored; they are only
hidden. Activating Pro brings them back instantly.

**Buying and activating.** Payments and license keys go through **Dodo Payments**: the buyer gets a key by email.
In Settings → License:
1. **Activate:** entering the key contacts Recall's license server once. It sends the key and an anonymous device ID
   (a salted SHA-256 of the Mac's hardware UUID). The server checks the key with Dodo Payments; each key works on
   3 Macs (set in Dodo).
2. **Token:** the server returns a token signed with Ed25519. The app checks the signature offline with the public
   key it ships with. The token is tied to this Mac, so copying the license file to another Mac doesn't work.
3. **Monthly re-check:** about every 30 days the app re-checks quietly.
   - Offline, or the server or Dodo down: nothing changes.
   - Key refunded or disabled, or this Mac removed in Dodo: back to Free.
4. **Deactivate This Mac** frees the slot.

Free users never contact the server. The server code is in [`server/`](server/README.md).

## What it searches

| Source | What gets indexed |
| --- | --- |
| **Files** in Desktop, Documents, Downloads (plus any folders you add) | Text, Markdown, code, JSON/CSV, PDFs, Word/RTF/OpenDocument, saved web pages (visible text). Pages files by name. |
| **Screenshots & images** | Text inside the image (Apple Vision, on-device) plus a thumbnail. New screenshots are searchable within about a second. |
| **Clipboard history** | Text, links and copied images (with their text). Items password managers mark as concealed are never stored. Kept 30 days by default. |

Skipped: hidden folders, `.git`, `node_modules`, `.build`, `DerivedData`, `Library`, `venv`/`.venv`,
`__pycache__`, files over 50 MB, and binaries.
Code and data files (JS, CSS, JSON, CSV…) are searchable by name and their first 50 KB; minified bundles
(one-line JS/CSS) by their first 10 KB.

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

**Meaning-search model.** Recall bundles **all-MiniLM-L6-v2**, a sentence-embedding model converted to
Core ML (`Embedding/Models/MiniLM.mlpackage`, 43 MB, 16-bit). It ships inside the app and runs on the CPU,
so nothing is downloaded at runtime.

- **Speed:** about 1 ms per query and about 4 ms per 256-token chunk.
- **Tokenizer:** a Swift WordPiece tokenizer (`Embedding/WordPieceTokenizer.swift`). It matches the original token
  for token, and the vectors match the original model at 0.9999+ similarity.
- **Accuracy:** on a 12-query test it ranks the right document first 12 of 12 times. Apple's built-in word vectors
  get 11 of 12, and `NLContextualEmbedding` 7 of 12.
- **On a real Mac (~280 screenshots):** `/s pricing table` puts a screenshot that only says
  "Plans & Billing $29/mo" first. With the built-in word vectors it ranked 35th.
- **Rebuilding the model:** run `scripts/convert_minilm.py` against a local copy of the Hugging Face model.
- **Fallback:** if the model is missing, Recall falls back to the built-in word-vector embedder.
- **Code and data files** (JS, JSON, CSV…) are keyword-only, so they don't drown out real meaning matches.
- **Partial-word matches:** keyword results that match only some of the query words are used only when meaning search finds nothing.

## Build & run

Requirements: macOS 14+, Apple Silicon, Xcode (full app, not just Command Line Tools), XcodeGen.
(Only for regenerating the model: Python 3.12 with `torch==2.7.0`, `transformers==4.46.3`, `coremltools`, `sentence-transformers==3.3.1`.)

```bash
brew install xcodegen
./scripts/build.sh                  # Debug build → build/Recall.app, installs to ~/Applications
CONFIG=Release ./scripts/build.sh   # Release build
open ~/Applications/Recall.app
```

**Signing.** Run `./scripts/make-signing-cert.sh` once.
- It creates a self-signed "Recall Developer" code-signing certificate in your login keychain.
- It also writes a backup to `keys/recall-signing.p12`, with a random password in `keys/recall-signing-password.txt`.
  Both are git-ignored. **Back both up and keep them private**: anyone who has them can sign an app that macOS treats as Recall.
- `build.sh` signs every build with it, so macOS ties folder permissions to the certificate instead of to one build.
  Without it, every update would ask for folder access again.
- If you lose the file, your users have to re-approve folder access once after the next update.
- The first time `codesign` uses the key, macOS may ask for permission. Click **Always Allow**.

`build.sh` runs `xcodegen generate` (`project.yml` → `Recall.xcodeproj`), then `xcodebuild`. It copies the app to
`~/Applications/Recall.app` (set `INSTALL=0` to skip that). Package versions are pinned in `project.yml`:
GRDB 7.11.1 and KeyboardShortcuts 2.4.0.

## Releasing (without an Apple Developer account)

```bash
./scripts/make-dmg.sh               # Release build, signed, → build/Recall-<version>.dmg
```

Before the first release, deploy the license server and set its URL in `project.yml` (see `server/README.md`).

The app isn't notarized, so macOS blocks it the first time. Put these steps on the download page
(macOS 15 Sequoia and later; Control-click → Open no longer works there):
1. Drag Recall to Applications and open it. macOS says it can't verify the app. Click **Done**.
2. Open **System Settings → Privacy & Security**, scroll down, and click **Open Anyway** next to "Recall was blocked".
   The button appears for about an hour after step 1.
3. Enter your password, then click **Open**.

macOS only asks once. Updates signed with the same certificate open normally, and folder permissions carry over.

## Permissions

- **Desktop, Documents, Downloads:** macOS asks the first time Recall indexes each one. Click **Allow**.
  If you clicked Don't Allow, Settings → Folders marks the folder. To fix it, open
  **System Settings → Privacy & Security → Files and Folders → Recall**, turn the folders on, then quit and reopen Recall.
- **Re-asking after rebuilds:** builds signed with the "Recall Developer" certificate keep their permissions across
  rebuilds and updates. Ad-hoc builds (no certificate installed) look like a new app each time, so macOS asks again.
- **Launch at login:** if macOS asks, approve Recall in **System Settings → General → Login Items**.
- **Not needed:** Accessibility, Screen Recording, Full Disk Access (optional, if you want folders outside your home folder).

## Where data lives

Everything is in `~/Library/Application Support/Recall/`:
- `recall.sqlite` holds items, chunks, the FTS5 index and the vectors.
  - Chunk text is stored once: the FTS5 index uses `chunks` as its external content table.
  - Space from deleted items goes back to macOS through incremental auto-vacuum, run after each startup scan and hourly.
- `thumbs/` holds image thumbnails.
- `clips/` holds copied images.

On the development Mac, about 1,400 items take **92 MB** (it was 268 MB before these storage changes):

| Part | Size |
| --- | --- |
| Vectors | 32 MB |
| Keyword index | 27 MB |
| Text | 25 MB |
| Thumbnails | 8 MB |

Deleting an item removes its thumbnail too. **Settings → Data → Clear All Data** wipes everything, and your files then get indexed again.

## Performance

Measured on an Apple Silicon Mac with about 1,400 items / 59,000 chunks:

| Check | Target | Measured |
| --- | --- | --- |
| Idle memory (physical footprint, model loaded) | < 150 MB | ~62 MB |
| Search latency, keyword + meaning | < 100 ms on 50k chunks | ~5.5 ms typical, 67 ms worst (1-letter query) |
| Meaning search alone | | 8 ms over 50k vectors, 31 ms over 200k |
| Indexing CPU | no spikes | ≤ ~90% of one core (of 10), utility priority, then idle |
| First-time meaning indexing | | ~160 chunks/s (about 6 min for 59k chunks) |
| New screenshot → searchable | ~5 s | under 1 s |
| App size / DMG | | 50 MB app, 43 MB DMG |

Vectors are held in memory as Float32 at 1.5 KB per chunk (about 75 MB at 50k embedded chunks).
Storing them as Float16 would halve that if indexes grow much larger.

## Code layout

```
App/        app entry, menu bar, preferences, Debug-only test hook
UI/         search panel (NSPanel + SwiftUI), results, Settings window
Indexing/   folder scanner, FSEvents watcher, one extractor per source type
            (plain text, PDF, rich documents, images/OCR), clipboard watcher, indexer
Search/     keyword (FTS5) + vector search, RRF ranking
Storage/    GRDB database and schema
Embedding/  Embedder protocol, MiniLM, word-vector and contextual embedders, background worker
Licensing/  Pro: signed-token check, device ID, activation/re-check/deactivation
server/     license server (Cloudflare Worker + D1)
scripts/    build, DMG, signing certificate and dev helpers
```

**Debug test hook.** Debug builds can be driven from the terminal, for automated checks without
screen access. It only turns on when launched with `open --env RECALL_DEBUG_BRIDGE=1 ~/Applications/Recall.app`,
writes output only to `~/Library/Application Support/Recall/debug/`, and isn't compiled into Release builds.
See `App/DebugBridge.swift` and `scripts/recall-debug.swift`.

## Not in v1 (ideas for v2)

- Browser history (Chrome, Arc, Safari)
- Screen "time machine" capture with app exclusions
- An "Ask" mode that answers questions across results
- A multilingual embedding model (the bundled one is English-only)
