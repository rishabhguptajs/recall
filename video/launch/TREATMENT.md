# Recall launch film: treatment

Working title: **Surface Tension**
Length: 57.6 s master (16:9). Short: 22.8 s (16:9). Cutdowns: 19.8 s (9:16) and 30.0 s (1:1).
Grid: 100 BPM, so one beat is exactly 36 frames at 60 fps and one bar (4 beats) is 2.4 s. Every cut, type hit and sound cue lands on this grid.

The core line from the brief: *your Mac has seen everything you've seen; Recall lets it remember.* The three concepts below are three ways to make that line felt.

---

## Concept A: Surface Tension (chosen)

**Logline.** The blob is your Mac's memory as a material. All day it absorbs fragments of what you've seen. Weeks later you half-remember one, press ⌥Space, and it gives exactly that one back. When something tries to leave, surface tension holds it in.

**Structure.**
1. **Absorb (0:00–0:12).** A breathing blob on a dark stage. A screenshot drifts in. A small arm of liquid reaches out, the card dissolves into a droplet, and the droplet merges. Then the rest of a day arrives: a PDF, a copied sentence, a link, a note. Each has a mono timestamp, and each one turns the blob's colours a little further. *"Your Mac has seen everything you've seen."*
2. **Tip of the tongue (0:12–0:17).** Three weeks later. One half-formed sentence that won't hold still: words drift in and out of focus. *"You remember it like this."*
3. **⌥Space (0:17–0:19).** Two keycaps press on the downbeat. The drifting words freeze where they are: the gesture pauses time. The real panel opens over the frozen sentence, and the panel's material blurs the blob behind it.
4. **Give back (0:19–0:31).** The vague sentence becomes a vague query. The panel is the real one, rebuilt from `SearchView.swift`. The results arrive 150 ms after the last keystroke, which is the real debounce, and the blob behind the glass pulses each time. Three queries cover the three sources: a PDF, a screenshot, a clipboard link. ⌘C copies, and the panel closes the way the real one does.
5. **Meaning (0:31–0:36).** The second query was *pricing table*, and it found a screenshot that only says *Plans & Billing*. Type says the rest: it finds what you meant, not just what you typed.
6. **Surface tension (0:36–0:43).** A hairline marks the edge of the Mac. An arm of the blob reaches for it, flattens against it as if against glass, and is pulled back. Droplets bump the walls and stay in. *"Nothing leaves your Mac."*
7. **Measured (0:43–0:50).** A cut to mineral paper, the website's editorial register: four numbered measurements land on the beat.
8. **Resolve (0:50–0:58).** The liquid slows and settles into the exact shape of the app icon. The tile forms behind it. Then **Recall**, then **raegent.com/recall**, then the price, held.

**Key frames.**
- A droplet halfway through merging, with a liquid bridge between the card and the blob.
- The frozen, half-blurred sentence with ⌥ and Space pressed beneath it.
- The panel with the blob glowing through its material, the query *pdf about visa rules*, and the selected first row.
- The arm of the blob pressed flat against the hairline edge.
- The icon on its tile, the wordmark below it.

**Sound.** Starts with almost nothing: a low pad and a soft glass "tock" for each absorption, each one pitched one step higher. Its strongest beat is a silence: on ⌥Space everything cuts out except one held note, the sound of time stopping. Results get small, dry ticks. The tendril has a slow stretch, a creak in the low end, and a soft thump on its recoil. The numbers section brings the first full pulse at 100 BPM. The ending resolves onto the root chord as the icon settles, and the wordmark lands on the last downbeat. No whooshes.

**Why it wins.** Every required element falls out of the one material:
- indexing is absorbing;
- search is giving back;
- privacy is surface tension, a physical property of the same liquid rather than a bullet point;
- the ending is the liquid becoming the icon, because the icon *is* this blob at rest.

The blob is the hero in every section, not a logo sting at the end.

---

## Concept B: Tip of the Tongue

**Logline.** A type-only film about the feeling of almost remembering. One sentence fights to come into focus, letters swap and blur, and ⌥Space makes the right word land.

**Structure.** Six vague sentences, one after another, each half-formed in kinetic type. Each one is resolved by the panel into a concrete result: a file name, a screenshot, a link. Then come the numbers as type and the end card.

**Key frames.** A full-frame sentence where only the nouns are blurred. The same sentence with the nouns snapped sharp and coloured by source.

**Sound.** Breath, a held chord that won't resolve, and a resolution on each ⌥Space.

**Why not.** It is clever typography, but the blob has nothing to do: it becomes a mascot. Privacy would have to be bolted on as a type card. It also leans entirely on copy, so it would not travel without sound or language.

---

## Concept C: Stop

**Logline.** ⌥Space stops time. A busy working day is in motion: windows, scrolling, a cursor in flight. On ⌥Space it all freezes mid-air. In the frozen world you find the one thing you needed, then let time run again.

**Structure.** A montage of motion, then a freeze. The panel finds the item while everything hangs still, and the release snaps the world back into motion. It repeats three times with faster cuts each time, then the end card.

**Key frames.** A frozen scroll with motion blur stuck in place. The cursor suspended. The panel as the only moving thing.

**Sound.** A rising rhythm that cuts to dead silence on each freeze.

**Why not.** It needs a convincing desktop full of other apps, which is a mock-up trap and close to the banned "floating devices" look. The blob would be a bystander, and privacy has no natural place in it. The freeze is the best single beat of the three concepts, so Concept A takes it as its ⌥Space moment.

---

## Visual language

- **Stage.** The website's deep ink `#10120F`, flat. The blob is the only saturated colour in the film. This keeps the brand's indigo for the icon tile, so the end resolve feels like arriving somewhere.
- **Type.** Instrument Sans 500 with tight tracking (−0.055em), as the site sets headlines. Geist Mono for timestamps, eyebrows and numbering. The system font is used only inside the real panel and for the ⌘ ⌥ ↩ glyphs, which the brand fonts don't contain.
- **Accent.** The site's green `#72B38C`, used sparingly for numbering.
- **Panel.** Built from `SearchView.swift`:
  - 720 × 480 pt, radius 14, regular material in dark appearance;
  - 24 pt query with a 20 pt magnifier;
  - All / Files / Screenshots / Clipboard capsules and the exact hint string;
  - rows with a 36 pt icon (radius 4), a 14 pt semibold title, a source badge, a relative date and a two-line snippet with bold hits;
  - selection in the system accent at 22 %.
- **Camera.** Mostly still. Pushes are slow and every one is answered by a pull or a glide. A fast move happens once, when the arm snaps back.

## Storyboard and iterations

The key frames were rendered as stills before animating and then reviewed frame by frame. They are in `storyboard/`:

1. `01-first-pass-master.jpg`: the first full pass, every scene. The review found:
   - the end card's small line showed from frame 0 (an opacity bug);
   - a fragment crossed the headline;
   - the blob was too small in the opening;
   - the number labels were unreadable at phone size;
   - "macOS" and "MiniLM" were broken by uppercase styling.
2. `02` to `04`: three passes at the absorb.
   - v1: the card just slid behind the blob.
   - v2: an arm reached out, but it was beaded and dark violet.
   - v3: a smooth tapered arm that carries the blob's own colours, with the card shrinking into its tip.
3. `05` and `06`: the 9:16 and 1:1 recompositions.
4. `07-transitions-check.jpg`: the ⌥Space cut, the snap-back and the icon settle, frame by frame.

The final contact sheets, taken from the delivered renders, are in `out/`.

## Cue sheet

See `src/constants.ts` (`CUES`) for the editable source. A rendered copy is in `MUSIC.md`.
