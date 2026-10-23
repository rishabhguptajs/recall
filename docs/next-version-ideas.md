# Recall: ideas for the next versions

Brainstorm from 2026-10-23. Nothing here is built yet: each idea was checked against the code at that point.

## Suggested order

- **v1.1 (quick wins):** date and type filters (1), scanned PDF OCR (2), empty-panel recents (3), pinned clips (5),
  plus drag-out (A1), secret detection (A7) and shell history search (A13).
- **Next paid headline:** Ask your Mac (6).
- **Standout feature:** timeline view (A17).
- **Outside the app:** notarization, which probably helps installs more than any feature.

---

## List 1

### Tier 1: small effort, big impact

1. **Dates and file types in the search box.** Understand "pdf last week", "screenshot from tuesday",
   "clipboard yesterday". Pull dates and types out of the query before searching. Every item already stores a date.
2. **OCR for scanned PDFs and photographed documents.** PDFs with no text layer (receipts, signed forms, visa papers)
   are only searchable by name today. Reuse the Vision text recognition already used for screenshots. Could be Pro.
3. **Show recents when the panel is empty.** Recent clipboard items, latest screenshots, recently opened files.
4. **Paste straight into the previous app.** ↩ pastes where you were typing. Needs Accessibility, so make it an
   opt-in setting and keep "no special permissions" as the default.
5. **Pin clipboard items.** Pinned items never expire and survive Clear. Works as saved snippets.

### Tier 2: features that set Recall apart

6. **Ask your Mac.** Use Apple's on-device Foundation Models framework (macOS 26) to answer questions from the top
   search results: "when does my passport expire?", "how much was the flight?". No cloud. Strong Pro feature.
7. **Search photos by what's in them.** Vision's on-device image labels, so "photo of a dog", "receipt" or
   "screenshot with a chart" work without any text in the image.
8. **"More like this."** One shortcut on a result to find similar items from the stored vectors.
9. **Browser history and bookmarks.** Chrome's history file is readable directly. Safari needs Full Disk Access,
   so make it optional.
10. **Exclusion rules.** Don't record the clipboard from chosen apps (Terminal, banking apps). Skip chosen folders
    or file patterns.

### Tier 3: reach and growth

11. **Search in other languages.** MiniLM is mostly English. A small multilingual model (e.g. multilingual-e5-small)
    would open the app to many more users.
12. **Shortcuts support and a `recall://search?q=` link.** Lets Shortcuts, Raycast and Alfred use Recall.
13. **7-day Pro trial.** People who never try screenshot search won't buy it. Nothing deleted when the trial ends.
14. **Voice memos and recordings.** On-device speech recognition makes audio searchable. Bigger job, later.

### Not a feature, but probably the biggest win

- **Notarization ($99/year Apple Developer account).** Removes the "Open Anyway in Privacy & Security" step on
  macOS 15+, which likely loses the most installs. It also eases the "is this safe?" worry for an app that reads all
  your files.

---

## List 2

### Quick wins that make the panel feel powerful

- **A1. Drag results out of the panel** into Slack, Mail or a browser upload box.
- **A2. Actions menu (⌘K):** Open With, Rename, Move to Trash, Share, Copy Path, Copy Text from Screenshot.
- **A3. Open at the match:** PDF on the matching page, code file at the matching line.
- **A4. Typo-tolerant file names:** "invioce" finds "invoice.pdf". SQLite's trigram index makes this cheap.
- **A5. Exact-match and exclude operators:** `"exact phrase"` and `-word`.
- **A6. More hotkeys:** e.g. ⇧⌘V opens straight to the clipboard tab.

### Clipboard

- **A7. Detect and expire secrets:** API keys, card numbers, OTP codes, and passwords not marked concealed.
  Skip them or delete them after an hour.
- **A8. Smarter clip types:** color swatch for hex codes, syntax highlighting for code, actions for phone numbers
  and addresses.
- **A9. Paste as plain text,** and a paste stack (copy 5 things, paste them in order).
- **A10. Import from other clipboard managers** (Maccy, Paste, Raycast) to make switching easy.

### Screenshots

- **A11. Rename screenshots by content** (opt-in): "Screenshot 2026-10-23 at 14.02" becomes
  "Stripe billing plans.png".
- **A12. Screenshot cleanup:** "410 screenshots older than 6 months, 38 duplicates." One click moves them to the
  Trash (never permanent delete).

### New sources

- **A13. Shell history search:** "that ffmpeg command I ran last month". One local file (`~/.zsh_history`),
  no extra permissions.
- **A14. External drives and NAS folders** (Pro). Results stay searchable while unplugged, marked offline.
- **A15. Contacts and Calendar** through Apple's APIs (each asks permission).
- **A16. Presets for Obsidian vaults, Notion exports and iCloud Drive** folders.

### New ways to use it

- **A17. Timeline view:** "what was I doing Tuesday afternoon?" One day as a strip of files touched, screenshots
  taken and things copied.
- **A18. Quick capture:** a hotkey to save a thought or link into Recall.
- **A19. Desktop widget** for pinned clips and recent screenshots.

### Privacy and trust

- **A20. Touch ID lock** for the clipboard tab or the whole app.
- **A21. Encrypt the database at rest.**
- **A22. Battery-aware indexing:** slow down or pause on battery and in Low Power Mode.

### Business and growth

- **A23. Lifetime license** next to yearly, plus a student discount.
- **A24. List on Setapp.**
- **A25. Weekly note in the menu-bar menu:** "Recall found 37 things for you this week" (computed locally).
- **A26. iPhone companion (long term):** search the Mac's index over the local network, no cloud.
