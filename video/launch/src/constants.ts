// Every word, colour, price and timing in the film lives here.
// Times are in beats at BPM (one beat = 36 frames at 60 fps). Change a beat number and the
// picture, the click track and the cue sheet all move together.

export const FPS = 60;
export const BPM = 100;
export const FRAMES_PER_BEAT = (FPS * 60) / BPM; // 36
export const beat = (b: number) => Math.round(b * FRAMES_PER_BEAT);

// ---------------------------------------------------------------------------------------------
// Colour: the real palette only.
export const C = {
  // website (raegent-web app/globals.css)
  deep: '#10120f',
  ink: '#171916',
  mineral: '#f3f1ea',
  paper: '#faf9f5',
  green: '#72b38c',
  muted: '#a8aca3',
  mutedOnLight: '#6a7066',
  line: '#363a33',
  // icon (scripts/make-icon.swift)
  pink: '#FF5BD1',
  orange: '#FFA24D',
  cyan: '#2FD9FF',
  violet: '#7C4DFF',
  core: '#FF7AA8',
  tileTop: '#1C1638',
  tileBottom: '#0A0914',
  // macOS dark appearance, used only inside the real panel
  sysBlue: '#0A84FF',
  sysPurple: '#BF5AF2',
  sysOrange: '#FF9F0A',
  label: 'rgba(255,255,255,0.86)',
  secondary: 'rgba(255,255,255,0.55)',
  tertiary: 'rgba(255,255,255,0.26)',
};

export const FONT = {
  sans: "'Instrument Sans', system-ui, sans-serif",
  mono: "'Geist Mono', ui-monospace, monospace",
  // The panel is SwiftUI with the system font; ⌘ ⌥ ↩ also come from it (the brand fonts lack them).
  system: "system-ui, -apple-system, 'SF Pro Text', sans-serif",
};

// ---------------------------------------------------------------------------------------------
// Pricing. Source of truth: ~/dev/raegent-web/lib/recall.ts (price $29, earlyBird $19, devices 3).
export const PRICE = {price: '$29', earlyBird: '$19' as string | null, devices: 3};
export const SITE = 'raegent.com/recall';
export const REQUIREMENTS = 'macOS 14+ · Apple Silicon';

// ---------------------------------------------------------------------------------------------
// Copy. Short, specific, true. Facts: README.md and the launch brief.
export const COPY = {
  seen: ['Your Mac has seen', 'everything you’ve seen.'],
  later: 'Three weeks later',
  rememberLike: 'You remember it like this.',
  vague: ['that', 'pdf…', 'the one', 'about', 'visa', 'rules?'],
  youTyped: 'You typed',
  itFound: 'It found',
  meaningTyped: 'pricing table',
  meaningFound: 'Plans & Billing',
  meaningLine: ['It finds what you meant,', 'not just what you typed.'],
  meaningSub: 'MiniLM · ships inside the app · runs on your Mac’s CPU',
  privacyLine: 'Nothing leaves your Mac.',
  privacySub: 'No cloud · No account · No telemetry',
  boundaryLabel: 'This Mac',
  searchedIn: 'searched in',
  optionKey: 'option',
  commandKey: 'command',
  measuredEyebrow: 'Measured on a real Mac',
  numbers: [
    {n: '01', value: '5–7', unit: 'ms', label: 'to search, words and meaning'},
    {n: '02', value: '~60', unit: 'MB', label: 'of memory at rest'},
    {n: '03', value: '<1', unit: 's', label: 'until a new screenshot is searchable'},
    {n: '04', value: '~92', unit: 'MB', label: 'index for 1,400 items'},
  ],
  name: 'Recall',
  tierLine: 'Free to search. Pro to remember more.',
  priceLine: () =>
    PRICE.earlyBird
      ? `Free to search. Pro ${PRICE.earlyBird} early bird, then ${PRICE.price}, once.`
      : `Free to search. Pro ${PRICE.price}, once.`,
  priceSub: () => `Pro works on ${PRICE.devices} Macs · ${REQUIREMENTS}`,
};

// ---------------------------------------------------------------------------------------------
// The day: fragments the blob absorbs. Fictional content only.
export type FragmentKind = 'screenshot' | 'pdf' | 'clip' | 'link' | 'note';
export const FRAGMENTS: {kind: FragmentKind; time: string; tag: string}[] = [
  {kind: 'screenshot', time: '09:14', tag: 'Screenshot'},
  {kind: 'pdf', time: '10:31', tag: 'Downloads'},
  {kind: 'clip', time: '11:02', tag: 'Clipboard'},
  {kind: 'link', time: '13:47', tag: 'Clipboard'},
  {kind: 'note', time: '16:20', tag: 'Desktop'},
];

export const FRAGMENT_TEXT = {
  screenshotCrumb: 'Settings / Workspace',
  screenshotTitle: 'Plans & Billing',
  screenshotSub: 'Billed yearly · change or cancel any time',
  embassyKicker: 'Consular section',
  embassyTitle: 'Appointment confirmed',
  embassyLines: ['Bring originals and two photos', 'Arrive 15 minutes early', 'Short-stay visa · reference on file'],
  pdfKicker: 'Travel · checklist',
  screenshotPlans: [
    {name: 'Starter', price: '$0', note: '1 workspace'},
    {name: 'Team', price: '$12', note: 'per seat / mo'},
    {name: 'Business', price: '$24', note: 'per seat / mo'},
  ],
  pdfTitle: 'Short-stay visa checklist',
  pdfLines: ['Entry rules', 'Valid passport, issued within 10 years', 'Travel insurance, at least €30,000', 'Proof of accommodation', 'Return or onward ticket'],
  clip: 'A dropped future stops at its next .await',
  link: 'https://quietcompile.dev/async-cancellation',
  noteTitle: '# Trip planning',
  noteLines: ['- check entry rules before booking', '- photos for the appointment', '- insurance letter (PDF)'],
};

// ---------------------------------------------------------------------------------------------
// The panel: three queries, results as SearchView would show them.
// Snippet markup: **word** = the bold primary-colour hit that Highlight.attributed draws.
export type Source = 'file' | 'screenshot' | 'clipboard';
export type IconKind = 'pdf' | 'md' | 'shot' | 'clip' | 'link';
export type Result = {title: string; source: Source; icon: IconKind; date: string; snippet: string; shot?: 'billing' | 'embassy'};
export type Query = {text: string; ms: number; keys: string; results: Result[]};

export const QUERIES: Query[] = [
  {
    text: 'pdf about visa rules',
    ms: 6,
    keys: '↩',
    results: [
      {title: 'Short-stay visa checklist.pdf', source: 'file', icon: 'pdf', date: '3 wk. ago',
        snippet: 'Short-stay **visa** checklist. Entry **rules**: valid passport issued within 10 years, travel insurance covering at least €30,000…'},
      {title: 'Screenshot 2026-09-14 at 11.02.48', source: 'screenshot', icon: 'shot', shot: 'embassy', date: '5 wk. ago',
        snippet: 'Appointment confirmed · Consular section · bring originals and two photos'},
      {title: 'Short stays: 90 days within any 180-day period', source: 'clipboard', icon: 'clip', date: '3 wk. ago',
        snippet: 'Short stays: 90 days within any 180-day period. **Rules** differ for long stays and work permits.'},
      {title: 'Trip planning notes.md', source: 'file', icon: 'md', date: '3 wk. ago',
        snippet: '# Trip planning – check entry **rules** before booking – photos for the appointment'},
    ],
  },
  {
    text: '/s pricing table',
    ms: 7,
    keys: '⌘Y',
    results: [
      {title: 'Screenshot 2026-10-01 at 09.14.07', source: 'screenshot', icon: 'shot', shot: 'billing', date: '3 wk. ago',
        snippet: 'Plans & Billing  Starter $0  Team $12 per seat / mo  Business $24 per seat / mo'},
      {title: 'Screenshot 2026-09-24 at 17.40.12', source: 'screenshot', icon: 'shot', shot: 'billing', date: '4 wk. ago',
        snippet: 'Compare plans · billed yearly · Team includes shared folders and audit log'},
    ],
  },
  {
    text: '/c rust async',
    ms: 5,
    keys: '⌘C',
    results: [
      {title: 'A dropped future stops at its next .await', source: 'clipboard', icon: 'clip', date: '3 wk. ago',
        snippet: 'A dropped future stops at its next .await, so cancellation in **async** **Rust** is cooperative.'},
      {title: 'https://quietcompile.dev/async-cancellation', source: 'clipboard', icon: 'link', date: '3 wk. ago',
        snippet: 'https://quietcompile.dev/**async**-cancellation'},
    ],
  },
];

export const PANEL = {
  width: 720,
  height: 480,
  radius: 14,
  placeholder: 'Search your Mac…',
  emptyHint: 'Type to search files, screenshots and clipboard',
  tabs: ['All', 'Files', 'Screenshots', 'Clipboard'],
  hints: '↑↓ select · ↩ open · ⌘↩ reveal · ⌘C copy · ⌘Y preview',
  debounceFrames: 9, // SearchModel debounces 150 ms
};

// ---------------------------------------------------------------------------------------------
// Timelines (in beats). Each cut is a list of scenes with a start beat and a length.
export type SceneId = 'absorb' | 'tongue' | 'panel' | 'meaning' | 'privacy' | 'numbers' | 'end';
export type SceneSpec = {id: SceneId; at: number; len: number; variant?: string};

export const MASTER: SceneSpec[] = [
  {id: 'absorb', at: 0, len: 20, variant: 'full'},
  {id: 'tongue', at: 20, len: 12, variant: 'full'},
  {id: 'panel', at: 32, len: 20, variant: 'full'},
  {id: 'meaning', at: 52, len: 8},
  {id: 'privacy', at: 60, len: 12},
  {id: 'numbers', at: 72, len: 12},
  {id: 'end', at: 84, len: 12},
];

export const VERTICAL: SceneSpec[] = [
  {id: 'absorb', at: 0, len: 6, variant: 'short'},
  {id: 'tongue', at: 6, len: 6, variant: 'short'},
  {id: 'panel', at: 12, len: 8, variant: 'one'},
  {id: 'privacy', at: 20, len: 4, variant: 'short'},
  {id: 'end', at: 24, len: 9, variant: 'short'},
];

// 16:9 short (22.8 s): the same story at speed, for feeds and pre-roll.
export const SHORT: SceneSpec[] = [
  {id: 'absorb', at: 0, len: 6, variant: 'short'},
  {id: 'tongue', at: 6, len: 6, variant: 'short'},
  {id: 'panel', at: 12, len: 8, variant: 'one'},
  {id: 'privacy', at: 20, len: 4, variant: 'short'},
  {id: 'numbers', at: 24, len: 6, variant: 'short'},
  {id: 'end', at: 30, len: 8, variant: 'short'},
];

export const SQUARE: SceneSpec[] = [
  {id: 'absorb', at: 0, len: 12, variant: 'medium'},
  {id: 'tongue', at: 12, len: 6, variant: 'short'},
  {id: 'panel', at: 18, len: 12, variant: 'two'},
  {id: 'privacy', at: 30, len: 6, variant: 'short'},
  {id: 'numbers', at: 36, len: 6, variant: 'short'},
  {id: 'end', at: 42, len: 8, variant: 'short'},
];

export const totalBeats = (t: SceneSpec[]) => Math.max(...t.map((s) => s.at + s.len));

// ---------------------------------------------------------------------------------------------
// Voice-over (sample versions only: the final films are music-only). Beats are from the start of each cut.
// Lines land where their words are on screen. Rendered by scripts/voice.mjs with an Apple voice.
export type VoLine = {beat: number; text: string};
const VO_END = 'Recall. Find anything on your Mac.';
export const VO: Record<'Master' | 'Short' | 'Vertical' | 'Square', VoLine[]> = {
  Master: [
    {beat: 4, text: 'Your Mac has seen everything you’ve seen.'},
    {beat: 10.5, text: 'Screenshots. PDFs. The things you copied.'},
    {beat: 21, text: 'Three weeks later, you remember it like this.'},
    {beat: 29.6, text: 'Option, Space.'},
    {beat: 33.2, text: 'Type it the way you remember it.'},
    {beat: 36.6, text: 'There it is.'},
    {beat: 55.1, text: 'It finds what you meant, not just what you typed.'},
    {beat: 61, text: 'No cloud. No account. No telemetry.'},
    {beat: 67.9, text: 'Nothing leaves your Mac.'},
    {beat: 73.6, text: 'Searches take five to seven milliseconds.'},
    {beat: 78.4, text: 'New screenshots are searchable in under a second.'},
    {beat: 88, text: VO_END},
  ],
  Short: [
    {beat: 1.2, text: 'Your Mac has seen everything you’ve seen.'},
    {beat: 6.6, text: 'You remember it like this.'},
    {beat: 10.4, text: 'Option, Space.'},
    {beat: 15.8, text: 'There it is.'},
    {beat: 21.9, text: 'Nothing leaves your Mac.'},
    {beat: 24.8, text: 'Searches take five to seven milliseconds.'},
    {beat: 32.4, text: VO_END},
  ],
  Vertical: [
    {beat: 1.2, text: 'Your Mac has seen everything you’ve seen.'},
    {beat: 6.6, text: 'You remember it like this.'},
    {beat: 10.4, text: 'Option, Space.'},
    {beat: 15.8, text: 'There it is.'},
    {beat: 21.9, text: 'Nothing leaves your Mac.'},
    {beat: 26.4, text: VO_END},
  ],
  Square: [
    {beat: 2.2, text: 'Your Mac has seen everything you’ve seen.'},
    {beat: 12.6, text: 'You remember it like this.'},
    {beat: 16.4, text: 'Option, Space.'},
    {beat: 22, text: 'There it is.'},
    {beat: 31.9, text: 'Nothing leaves your Mac.'},
    {beat: 36.6, text: 'Searches take five to seven milliseconds.'},
    {beat: 44.4, text: VO_END},
  ],
};

// ---------------------------------------------------------------------------------------------
// Score hit points for the master, in beats. MUSIC.md and the temp click track come from this.
export const CUES: {beat: number; name: string; note: string}[] = [
  {beat: 0, name: 'Open', note: 'Low pad fades up from silence; no rhythm yet'},
  {beat: 3.5, name: 'Absorb 1', note: 'First glass "tock" as the screenshot merges'},
  {beat: 4, name: 'Line 1', note: '"Your Mac has seen…" — pad opens a fifth'},
  {beat: 9, name: 'Absorb 2', note: 'Tock, one step higher'},
  {beat: 11, name: 'Absorb 3', note: 'Tock'},
  {beat: 13, name: 'Absorb 4', note: 'Tock'},
  {beat: 15, name: 'Absorb 5', note: 'Tock; soft pulse starts underneath (quarter notes, felt not heard)'},
  {beat: 20, name: 'Three weeks later', note: 'Hard cut; pulse drops out, pad thins to one wavering note'},
  {beat: 31, name: '⌥ down', note: 'Option key goes down: a breath in, the pad swells'},
  {beat: 32, name: 'Space: time stops', note: 'Space goes down, the drifting words freeze, the panel opens. Everything cuts except one held high note'},
  {beat: 36, name: 'Results', note: 'Small dry tick (results land 150 ms after typing stops)'},
  {beat: 43.6, name: 'Results 2', note: 'Tick'},
  {beat: 49.6, name: 'Results 3', note: 'Tick'},
  {beat: 51.1, name: '⌘C', note: 'Key down, the row flashes; hold the breath for the cut'},
  {beat: 52, name: 'Meaning', note: 'The panel closes on the cut (as ⌘C does in the app). Melodic motif enters (three notes), warm'},
  {beat: 60, name: 'Boundary', note: 'Low drone; the hairline draws'},
  {beat: 62.4, name: 'Reach', note: 'Slow stretch: a rising, creaking bowed tone'},
  {beat: 65, name: 'Contact', note: 'Muted thud as the arm flattens on the edge'},
  {beat: 66.6, name: 'Snap back', note: 'Release; tone collapses, soft sub drop'},
  {beat: 68, name: 'Nothing leaves', note: 'Line lands on the downbeat'},
  {beat: 72, name: 'Measured', note: 'Hard cut to paper; first full beat, 100 BPM, light percussion'},
  {beat: 74, name: '01', note: 'Hit'},
  {beat: 76, name: '02', note: 'Hit'},
  {beat: 78, name: '03', note: 'Hit'},
  {beat: 80, name: '04', note: 'Hit; build toward the cut'},
  {beat: 84, name: 'Resolve', note: 'Hard cut to dark; percussion out; root chord as the blob settles'},
  {beat: 87, name: 'Icon', note: 'Tile forms; chord fully resolved'},
  {beat: 88, name: 'Recall', note: 'Wordmark lands on the downbeat'},
  {beat: 89, name: 'URL', note: 'One soft note'},
  {beat: 90, name: 'Price', note: 'Last note; ring out to the end'},
  {beat: 96, name: 'End', note: 'Silence'},
];

// ---------------------------------------------------------------------------------------------
// PUNCH: the fast kinetic-type cut (16:9, ~17 s, 120 BPM). One word per shot, flat full-bleed colour,
// each word acts out what it means. Shot lengths are in beats at PUNCH_BPM (one beat = 30 frames).
export const PUNCH_BPM = 120;
export const pbeat = (b: number) => Math.round((b * FPS * 60) / PUNCH_BPM);
export type PunchShot = {id: string; len: number; bg: string; fg: string; word: string; caption?: string; accent?: string};
export const PUNCH: PunchShot[] = [
  {id: 'keys', len: 3, bg: C.ink, fg: C.mineral, word: '', caption: 'anywhere on your Mac'},
  {id: 'vague', len: 3, bg: C.pink, fg: C.ink, word: 'vague', caption: 'type it'},
  {id: 'exact', len: 3, bg: C.orange, fg: C.ink, word: 'exact', caption: 'find it', accent: C.ink},
  {id: 'files', len: 2, bg: C.cyan, fg: C.ink, word: 'files', caption: 'pdf · docs · code · web pages'},
  {id: 'screenshots', len: 2, bg: C.violet, fg: C.mineral, word: 'screenshots', caption: 'the text inside, read on your Mac'},
  {id: 'clipboard', len: 2, bg: C.mineral, fg: C.ink, word: 'clipboard', caption: 'text · links · images'},
  {id: 'meaning', len: 4, bg: C.ink, fg: C.mineral, word: 'pricing table', caption: 'by meaning, not just words', accent: C.pink},
  {id: 'ms', len: 3, bg: C.cyan, fg: C.ink, word: '~6', caption: 'per search, on a real Mac'},
  {id: 'private', len: 4, bg: C.violet, fg: C.mineral, word: 'private', caption: 'nothing leaves your Mac', accent: C.orange},
  {id: 'end', len: 10, bg: C.deep, fg: C.mineral, word: 'Recall', accent: C.orange},
];
export const PUNCH_FOUND = 'Plans & Billing';
