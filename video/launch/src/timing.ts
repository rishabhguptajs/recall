// When things happen inside each scene, in beats from the scene's start, per variant.
// Pure data (no React), so the picture and the score (scripts/score.mjs) read the same numbers.

/** Seeded random in [0, 1): every render of a frame is identical. */
export const rand = (seed: number) => {
  const x = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

export const ABSORB: Record<string, {contacts: number[]; kinds: number[]; lineAt: number; lineOut?: number}> = {
  full: {contacts: [3.5, 9, 11, 13, 15], kinds: [0, 1, 2, 3, 4], lineAt: 4, lineOut: 9.6},
  medium: {contacts: [2.5, 5, 6.5, 8, 9.5], kinds: [0, 1, 2, 3, 4], lineAt: 2.2, lineOut: 7.4},
  short: {contacts: [1.5, 3.0, 4.5], kinds: [0, 1, 2], lineAt: 1.2},
};

export const TONGUE: Record<string, {wordsAt: number; wordGap: number; captionAt?: number; captionOut?: number; keysAt: number; optAt: number}> = {
  full: {wordsAt: 1.2, wordGap: 0.55, captionAt: 4.6, captionOut: 7.6, keysAt: 8.2, optAt: 11},
  short: {wordsAt: 0.4, wordGap: 0.3, keysAt: 3.2, optAt: 5},
};

export type PanelQuery = {q: number; results: number; select?: number};
export const PANEL_T: Record<string, {stage: string; stageLen: number; queries: PanelQuery[]; copyAt?: number}> = {
  full: {stage: 'full', stageLen: 12, queries: [{q: 0, results: 4}, {q: 1, select: 8.7, results: 11.6}, {q: 2, select: 15.1, results: 17.6}], copyAt: 19.1},
  two: {stage: 'short', stageLen: 6, queries: [{q: 0, results: 3.8}, {q: 1, select: 7, results: 9.8}]},
  one: {stage: 'short', stageLen: 6, queries: [{q: 0, results: 3.6}]},
};

export const KEY_INTERVAL = 5; // frames per keystroke, with ±1 frame of human jitter
export const DEBOUNCE_FRAMES = 9; // SearchModel debounces 150 ms

/** Keystroke frames for a query, ending so that results land exactly on `resultsFrame` (150 ms debounce). */
export function keystrokes(text: string, resultsFrame: number, seed: number) {
  const last = resultsFrame - DEBOUNCE_FRAMES;
  const n = text.length;
  return Array.from({length: n}, (_, i) => last - (n - 1 - i) * KEY_INTERVAL + (i < n - 1 ? Math.floor(rand(seed + i) * 3) - 1 : 0));
}
export const keySeed = (i: number) => 17 + i * 31;

export const PRIVACY: Record<string, {draw: number; reach: [number, number]; snap: number; line: number; sub: number; bump?: number}> = {
  full: {draw: 0, reach: [2.4, 5.0], snap: 6.6, line: 7.8, sub: 9.0, bump: 9.2},
  short: {draw: 0, reach: [0.3, 1.5], snap: 2.0, line: 1.9, sub: 2.6},
};

export const NUMBERS: Record<string, {eyebrow: number; rows: number[]}> = {
  full: {eyebrow: 0.3, rows: [2, 4, 6, 8]},
  short: {eyebrow: 0, rows: [0.6, 1.5, 2.4, 3.3]},
};

export const END: Record<string, {settle: [number, number]; tile: [number, number]; swap: [number, number]; name: number; url: number; price: number; sub: number}> = {
  full: {settle: [0, 2.6], tile: [1.8, 2.9], swap: [2.9, 3.4], name: 4, url: 5, price: 6, sub: 6.6},
  short: {settle: [0, 1.7], tile: [1.2, 2.0], swap: [2.0, 2.4], name: 2.4, url: 3.2, price: 3.8, sub: 4.3},
};
