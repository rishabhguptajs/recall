# Recall launch film

**Surface Tension**: a launch film for Recall, built frame-exact in code with [Remotion](https://www.remotion.dev), with an original score synthesised in code.
- Concept, structure and key frames: [TREATMENT.md](TREATMENT.md).
- Score, cue sheet, and what to license if you want a composed track instead: [MUSIC.md](MUSIC.md).

| Cut | Composition | Size | Length |
| --- | --- | --- | --- |
| Master 16:9 | `Master` | authored 1920×1080, rendered 3840×2160 | 57.6 s |
| Short 16:9 | `Short` | authored 1920×1080, rendered 3840×2160 | 22.8 s |
| 9:16 | `Vertical` | 1080×1920 | 19.8 s |
| 1:1 | `Square` | 1080×1080 | 30.0 s |

All run at 60 fps. The short is the same story at speed (absorb → tip of the tongue → ⌥Space → result → privacy → numbers → end card). The cutdowns are recomposed per aspect, not cropped.

## Render

```bash
cd video/launch
npm install
bash scripts/render.sh            # everything: picture, score, final files → out/
bash scripts/render.sh video      # picture only (silent, into out/.video/)
bash scripts/render.sh audio      # re-make the score and re-mux it onto the existing picture (seconds, no video render)
```

Outputs in `out/` (git-ignored, never commit them). Every video has the score, normalised to -16 LUFS:

| File | What |
| --- | --- |
| `Recall-Launch-16x9-2160p60-ProRes.mov` | ProRes 422 HQ master, 3840×2160, 24-bit PCM audio |
| `Recall-Launch-16x9-2160p60.mp4` | full film, H.264 4K |
| `Recall-Launch-16x9-1080p60.mp4` | full film, H.264 1080p |
| `Recall-Launch-16x9-Short-2160p60.mp4` | 22.8 s short, H.264 4K |
| `Recall-Launch-16x9-Short-1080p60.mp4` | 22.8 s short, H.264 1080p |
| `Recall-Launch-9x16-1080x1920-60.mp4` | 9:16 cutdown |
| `Recall-Launch-1x1-1080-60.mp4` | 1:1 cutdown |
| `score-*.wav` | each cut's score on its own (48 kHz, normalised), for re-editing |
| `click-*.wav` | click tracks on the beat grid, for a composer replacing the score |
| `contact-sheet-*.jpg` | frames from the final renders |
| `.video/` | the silent picture the final files are muxed from (lets `render.sh audio` skip the video render) |

The H.264 files are transcoded from a ProRes render rather than rendered twice. A full render takes about 15 minutes on an Apple Silicon Mac. Set `CONCURRENCY=4` if memory is tight.

**Punch: the fast kinetic-type cut** (18 s, 16:9, 120 BPM). One huge word per shot on a flat brand colour, and each word acts out what it means:

1. ⌥ Space: the keys press.
2. vague: the letters drift out of focus.
3. exact.: the letters slam together and the full stop drops in.
4. files: copies stack into one.
5. screenshots: a screenshot selection is dragged across the word.
6. clipboard: the word is selected and a copy pops off.
7. pricing table → Plans & Billing.
8. ~6 ms: the digit rolls.
9. private.: the word hits the frame edge and bounces back.
10. End card: the blob settles into the icon, then Recall.

Files: `out/Recall-Punch-16x9-2160p60.mp4` and `-1080p60.mp4`.

How to edit it:
- Words, captions, colours and shot lengths (in beats) are in `PUNCH` in `src/constants.ts`.
- The motion is in [`src/Punch.tsx`](src/Punch.tsx).
- The music is the `isPunch` block in `scripts/score.mjs`: four-on-the-floor, a stab on every cut, and a sound for each word's action.

**Voice-over samples** (the finals stay music-only):

```bash
bash scripts/voice-samples.sh                          # → out/VO-SAMPLE-*.mp4 (1080p, all four cuts)
VOICE="Ava (Premium)" bash scripts/voice-samples.sh    # pick a specific voice
```

The lines and their beats are in `VO` in `src/constants.ts`. The script speaks them with macOS `say`, places each one on its beat, ducks the music about 8 dB under the voice, and normalises to −16 LUFS. By default it uses the first installed Premium or Enhanced English voice, and falls back to Daniel. To install one, go to System Settings → Accessibility → Spoken Content → System Voice → Manage Voices.

**Previewing and stills:**

```bash
npx remotion studio src/index.ts                                       # scrub every composition in the browser
node scripts/stills.mjs Master out/stills 0.5 120,1300,3444            # stills at chosen frames (scale 0.5)
uv run --with pillow python scripts/contact_sheet.py out/stills out/sheet.jpg 4 480
node --experimental-strip-types scripts/score.mjs Short out/s.wav      # just the score for one cut
node --experimental-strip-types scripts/cue-sheet.mjs                  # print the cue sheet
bash scripts/contact-sheets.sh                                         # contact sheets from the renders in out/
```

Renders need the GPU path (`--gl=angle`), which the scripts already pass, because the blob is a WebGL shader.

## Edit

**Words, prices, colours and timing** all live in [`src/constants.ts`](src/constants.ts):
- `COPY`: every line on screen. `PRICE` mirrors `~/dev/raegent-web/lib/recall.ts`. When the early-bird price ends, set `earlyBird: null` and the end card updates.
- `QUERIES`: the three queries in the panel and their results. Snippet bold hits are written `**word**`.
- `FRAGMENTS` and `FRAGMENT_TEXT`: the pieces of the day the blob absorbs. All content is fictional.
- `C`: the palette. Website ink, mineral and green; the icon's blob and tile colours; macOS dark-mode colours, used only inside the panel.
- `MASTER`, `SHORT`, `VERTICAL`, `SQUARE`: each cut's scenes in beats (100 BPM, one beat = 36 frames). Change a length here and the picture, temp track and cue sheet follow.
- `CUES`: score hit points for the master, listed in `MUSIC.md`.

**When things happen inside a scene** (fragment contacts, keystrokes, the reach and snap, number hits, the end-card beats) is in [`src/timing.ts`](src/timing.ts). Both the picture and the score read it, so moving an event moves its sound with it.

**The score** is [`scripts/score.mjs`](scripts/score.mjs): D major, 100 BPM, synthesised voices (pad, felt piano, glass, key clicks, bowed tone, light percussion) and a reverb. Edit a scene's case to change its music, then run `bash scripts/render.sh audio`.

**Where things are:**

```
src/
  constants.ts          all text, colour, timelines
  timing.ts             event timing inside scenes (shared by picture and score)
  Film.tsx              plays a timeline of scenes (hard cuts on the grid)
  Root.tsx              the three compositions
  components/
    blobShader.ts       the blob: a 2D signed-distance liquid, ported from scripts/make-icon.swift
    Blob.tsx            WebGL canvas for it (balls, arms, walls, ripple, icon morph)
    Panel.tsx           the search panel, rebuilt from UI/SearchView.swift
    Art.tsx             fictional screenshots, documents, icons
    Type.tsx            kinetic type (word rise, eyebrows, fades)
    Keycap.tsx          Mac keys for ⌥Space and ⌘C
  scenes/               Absorb, Tongue, PanelScene, Meaning, Privacy, Numbers, End
  lib/motion.ts         easing curves, springs, camera, seeded random
scripts/                render.sh, score.mjs, stills.mjs, contact-sheets.sh, contact_sheet.py, temp-track.mjs, cue-sheet.mjs
public/fonts            Instrument Sans and Geist Mono (OFL, licences alongside)
public/icon/icon.png    the app icon (assets/icon.png), the end card dissolves into it
```

**Notes:**
- **The blob.** At `icon: 1, wobble: 0` the shader reproduces `make-icon.swift`: the three-harmonic outline, the five blurred lights over `#6B4BFF`, the lower shade, the top rim and both speculars. The end scene settles into that state, then dissolves into the real `assets/icon.png`, so the last frame is the actual icon. If the icon changes, re-run `scripts/make-icon.sh` and copy `assets/icon.png` into `public/icon/`.
- **The panel's material** is a blurred copy of what's behind it, drawn by hand. CSS `backdrop-filter` rendered differently in Remotion's parallel browser tabs and flickered every eighth frame.
- **Determinism.** Everything is a function of the frame number, and any randomness is seeded. Two renders of the same frame are identical.
- **Fonts.** The brand fonts don't include ⌘ ⌥ ↩, so those glyphs and the whole panel use the system font (SF), as the app does. Renders are expected on a Mac.

## Licences to check

- **Remotion** is free for individuals and companies of up to three people. Larger companies need a company licence: see [remotion.dev/license](https://www.remotion.dev/license).
- **Music:** the score is original and synthesised in code, so there's nothing to license. To replace it with a composed or licensed track, see [MUSIC.md](MUSIC.md).
- **Fonts:** Instrument Sans and Geist Mono are under the SIL Open Font License (`public/fonts/LICENSE-*.txt`).
