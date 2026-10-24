# Recall video prompts

Two prompts for Claude Code (Opus 5.5) in this repo. Paste one per session. Each is self-contained.

---

## Prompt 1: Launch film (motion design)

You are the director, motion designer and engineer for Recall's launch film. You have full autonomy over concept, tools and craft. The bar is a film people screenshot and share: it should feel made by a studio with taste, not generated. Generic is failure.

### The product (true facts only; never invent features)
Recall is a macOS menu-bar app by Raegent. Press **⌥Space** anywhere and a search panel opens. Type something vague ("pdf about visa rules", "that link about rust async", "billing plans screenshot") and Recall finds it across:
- **files** (PDF, Word, Markdown, code, saved web pages) in Desktop, Documents, Downloads, plus any folder on Pro;
- **the text inside every screenshot**, read on-device by Apple Vision, searchable about a second after you take it;
- **clipboard history**: text, links, copied images. Items password managers mark as concealed are never stored.

It searches by **meaning, not just words**. A small language model (MiniLM) ships inside the app and runs on the Mac's CPU. Keyword search (SQLite FTS5) and meaning search are fused. Measured on a real Mac:
- search ~5–7 ms;
- ~60 MB memory at rest;
- index ~92 MB for 1,400 items;
- new screenshot searchable in under 1 second.

**Private by construction.** No cloud, no account, no telemetry; files, searches and clipboard never leave the Mac. Free version: file search plus 7 days of clipboard. Pro: screenshots, extra folders, full clipboard history. Price: **$19 early bird, then $29, once**, 3 Macs. Requirements: macOS 14+, Apple Silicon. Site: **raegent.com/recall**.

Read before designing (it's all in this repo):
- `README.md`
- `UI/SearchView.swift`, `UI/SearchPanel.swift`: the real panel's layout, result rows, filter capsules, corner radii
- `assets/icon.png`, `scripts/make-icon.swift`, `App/AppIcon.icon/`: the icon is a glossy colour blob on a near-black indigo tile, drawn in code
  - layers `blob.png` and `background.png` are separate, so you can animate them independently
  - blob palette: pink `#FF5BD1`, orange `#FFA24D`, cyan `#2FD9FF`, violet `#7C4DFF`, core `#FF7AA8`
  - tile gradient `#1C1638` → `#0A0914`
- The website (`~/dev/raegent-web`, `app/recall/page.tsx`, `app/globals.css`) for brand voice and type:
  - Instrument Sans and Geist Mono
  - ink `#171916`, mineral `#f3f1ea`, green `#72b38c`
  - editorial, numbered, quiet confidence

Pricing source of truth: `~/dev/raegent-web/lib/recall.ts`.

### Creative brief
- **Core idea:** your Mac has seen everything you've seen; Recall lets it remember. Find a concept with a real idea in it, not a feature list. Develop three distinct concepts in a short treatment (logline, structure, key frames, sound idea), pick the strongest, and say why. Some directions to beat:
  - the blob as a living memory that absorbs fragments of your day and gives one back on demand;
  - the "tip of the tongue" moment made visual;
  - ⌥Space as a gesture that pauses time.
- **The blob is the hero.** It should behave like a material: viscous, light-refracting, breathing. Not a logo sting.
- **Show the real interface.** Rebuild the panel faithfully from the Swift source (material, spacing, result rows, the `/f /s /c` filters, ⌘↩ / ⌘C / ⌘Y hints) so it reads as the actual product, not a mock. Use plausible fictional content only: no real personal names, emails or files.
- **Typography does the talking.** Kinetic type with intent, set in the brand fonts. Copy is short, specific and human; the numbers above are your best lines.
- **Privacy is a feeling, not a bullet.** Make "nothing leaves your Mac" felt visually, e.g. data that tries to leave and simply doesn't.

**Banned:**
- "Introducing…"
- lens flares, particle explosions, light leaks, glitch transitions
- floating laptops, spinning devices, stock gradients
- generic swooshes, whoosh-on-every-cut sound design
- emoji, AI-sparkle icons, "revolutionary / seamless / supercharge"
- any claim not in the facts above

### Format and craft
- **Master:** 16:9, 3840×2160 (or 1920×1080 if render time is prohibitive), 60 fps, 45–60 s.
- **Cutdowns:** 9:16 at 15–20 s and 1:1 at about 30 s. Recompose them, don't crop.
- **Build in code:** Remotion (React) or another frame-exact pipeline you choose, with timing, easing and every curve deliberate. If a skill for art/motion is available (e.g. `huashu-art-motion`), read it.
- **Ending:** the icon resolves, then "Recall", then "raegent.com/recall", then the price line. Hold long enough to read.
- **Sound:** design the score's structure and hit points (a cue sheet with timecodes). If you can't source licensed music, render a clean version with a temp click track and leave a `MUSIC.md` describing exactly what to license (tempo, mood, references). Don't use copyrighted music.
- **Everything editable:** text in one constants file, colours from the real palette, a render script.

### Process and quality bar
1. Write the treatment and storyboard (key frames as rendered stills) before animating.
2. Render stills at every scene's key moments and review them yourself like a harsh creative director:
   - legibility at phone size
   - contrast
   - nothing touching edges unintentionally
   - motion that is never linear-default
   
   Iterate until each frame could be a poster.
3. Check the full render frame by frame around transitions: no pops, no jitter.
4. **Deliver** in `video/launch/`:
   - source code
   - `README.md` (how to render and edit)
   - `out/` with the masters and cutdowns as H.264 MP4, plus a ProRes or high-bitrate master if feasible
   - the treatment
   - a contact sheet of frames

   Add `video/**/out/` and `node_modules` to `.gitignore`. Don't commit renders.
5. Finish with a short report: concept chosen, what you'd improve with more time, and anything I must supply (music license, voice).

---

## Prompt 2: Product walkthrough (recorded and edited, Loom-style with motion graphics)

You are the producer, screen-recorder, editor and motion designer of Recall's product walkthrough. You have full autonomy. It should feel like the best walkthrough you've seen from a small, obsessive studio: the real app, recorded cleanly, edited tightly, with graphics that explain rather than decorate. Not a generic screencast with a talking head and arrows.

### The product (true facts only)
Read `README.md` first; it is the source of truth.
- **Recall:** macOS menu-bar search app. ⌥Space opens a panel.
- **Searches by words and meaning:** files in Desktop / Documents / Downloads (PDF, Word, Markdown, code, saved web pages), text inside screenshots (on-device Apple Vision, searchable within about 1 s), and clipboard history.
- **Panel keys:**
  - ↑↓ select, ↩ open, ⌘↩ show in Finder
  - ⌘C copy (clipboard items go back on the clipboard)
  - ⌘Y or Space for Quick Look
  - tabs or `/f` `/s` `/c` to filter
- **Menu bar:** indexing progress, Pause Indexing, Settings, Check for Updates.
- **Settings tabs:** General (shortcut, launch at login, auto updates), Folders, Clipboard (on/off, retention), Data (stats, Clear All Data), License.
- **Free vs Pro:**
  - Free: file search plus 7 days of clipboard.
  - Pro: screenshot search, extra folders, full clipboard history, 90-day / 1-year retention. Nothing is deleted when Pro is off; it's only hidden.
- **Price:** $19 early bird then $29, once, 3 Macs. Get it at raegent.com/recall.
- **Private:** nothing leaves the Mac, no account, no telemetry.
- **Measured numbers:** ~5–7 ms search, ~60 MB memory, ~92 MB index for 1,400 items.

### Recording setup (privacy first: this Mac has the owner's real files)
- Never record the owner's real files, clipboard, notifications, name or email. Build a **clean demo world**:
  - Preferred: ask me to create a separate macOS user account for recording, then seed it.
  - Otherwise, temporarily point Recall at a dedicated demo folder.
- Seed the demo world with rich, believable, fictional content that makes searches magical:
  - a trip folder with a visa checklist PDF;
  - a screenshot of a pricing page;
  - Markdown meeting notes;
  - code snippets;
  - a saved article;
  - clipboard history with a link and an address.
  
  Design each search so the result is found **by meaning**, with a different word than the query (e.g. query "money I owe Sam" finds a note saying "split the Lisbon dinner, Sam paid €84").
- **Driving the app deterministically.** Debug builds include a terminal hook (`App/DebugBridge.swift`, client `scripts/recall-debug.swift`). Launch with `open --env RECALL_DEBUG_BRIDGE=1 ~/Applications/Recall.app`. It can:
  - show the panel;
  - set the query;
  - send keys;
  - switch filters;
  - open Settings tabs;
  - snapshot the panel to PNG.
  
  Use it for frame-perfect, repeatable takes and pixel-perfect stills. Build with `./scripts/build.sh`.
- **Real screen recording** for the moments that must be live (typing feel, Quick Look, Finder reveal, the "Open Anyway" install flow):
  - use `screencapture -v` or ScreenCaptureKit;
  - use a clean desktop (neutral wallpaper, hidden desktop icons, Do Not Disturb, tidy menu bar);
  - record at native Retina resolution.
- **Typing:** speed must look human. Script keystrokes with natural rhythm, not uniform delay.
- If a permission prompt or anything needs my hand (creating the user account, granting screen recording), stop and ask me clearly. Don't work around macOS security.

### Structure (refine it; don't treat it as a template)
Target 2:30–3:30, 16:9 1080p60 (4K if clean), plus a 60 s vertical highlight cut.
1. **Cold open, 10 s:** a real "where was that thing" moment solved in one keystroke. No logo first.
2. **The shortcut:** ⌥Space from anywhere, the panel, typing vague.
3. **Meaning, not keywords:** 2–3 searches that should be impossible with Spotlight. A light graphic reveals why each matched (query and result phrases linking).
4. **Screenshots:** take a screenshot live, search its text within a second.
5. **Clipboard history:** find something copied days ago, ⌘C puts it back.
6. **Keyboard flow:** filters, Quick Look, Finder reveal, copy. A small key-cap HUD shows each shortcut as it's pressed.
7. **Privacy:** what stays on the Mac, shown simply (Wi-Fi off, search still works is a strong proof).
8. **Free vs Pro and the price;** install in 30 s, including the macOS "Open Anyway" steps from the README, presented calmly.
9. **End card:** icon, raegent.com/recall.

### Edit and motion language
- **Look:** match Recall's world. The icon blob palette (pink `#FF5BD1`, orange `#FFA24D`, cyan `#2FD9FF`, violet `#7C4DFF` on `#0A0914`) for accents. The website's type (Instrument Sans, Geist Mono) and editorial numbering ("01 / The shortcut") from `~/dev/raegent-web`.
- **Camera:** smooth zoom/pan into the panel (virtual camera over the recording), cursor smoothing, click ripples that are subtle, motion-blurred moves. Never zoom just to zoom.
- **Graphics:** explain one thing at a time, then leave. Callouts are crisp and set in the brand fonts, aligned to the panel's real geometry.
- **Captions:** burned-in, styled, always on (most people watch muted). Also export an `.srt`.
- **Voiceover:** write a tight script in a warm, plain, slightly dry voice. Use no corporate phrases and no "in today's fast-paced world". Deliver `VOICEOVER.md` with timecodes so I can record it. If a TTS voice is available and good, make a temp VO track; otherwise time captions to read naturally.
- **Music:** cue sheet plus licensing notes; no copyrighted music.
- **Banned:** stock "subscribe"-style animations, arrows everywhere, emoji, rainbow highlights, robotic typing, dead air, features that don't exist, real personal data.

### Build and quality bar
- Build the edit in code (Remotion or similar, compositing the recordings) so every timing and callout is editable. Text and timings go in one config file.
- Review your own render like a picky editor:
  - check stills at every callout;
  - watch every transition;
  - verify every on-screen claim against `README.md`;
  - check legibility at phone size.
  
  Iterate.
- **Deliver** in `video/walkthrough/`:
  - source
  - raw takes (git-ignored)
  - `out/` (MP4 master, vertical cut, `.srt`)
  - `VOICEOVER.md`, `MUSIC.md`
  - `README.md` (how to re-record a scene and re-render)

  Add renders and raw footage to `.gitignore`.
- After recording, clean up: restore Recall's normal settings, remove demo folders you added, and tell me what you changed.
- End with a short report: what's in the cut, what needs me (VO, music, account creation), and what you'd improve next.
