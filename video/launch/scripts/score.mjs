// Original score and sound design for every cut, synthesised from scratch (no samples, nothing to license).
//   node --experimental-strip-types scripts/score.mjs <Master|Short|Vertical|Square> <out.wav>
//
// D major, 100 BPM, on the same beat grid as the picture. Every hit is placed from src/timing.ts and
// src/constants.ts, so it moves with the picture when the timing changes.
import fs from 'node:fs';
import {BPM, FPS, MASTER, PUNCH, PUNCH_BPM, QUERIES, SHORT, SQUARE, VERTICAL, pbeat, totalBeats} from '../src/constants.ts';
import {ABSORB, END, NUMBERS, PANEL_T, PRIVACY, TONGUE, keySeed, keystrokes, rand} from '../src/timing.ts';

const [comp = 'Master', out = 'out/score.wav'] = process.argv.slice(2);
const isPunch = comp === 'Punch';
const timeline = isPunch ? [] : {Master: MASTER, Short: SHORT, Vertical: VERTICAL, Square: SQUARE}[comp];
if (!timeline) throw new Error(`unknown composition ${comp}`);

const SR = 48000;
const SPB = 60 / (isPunch ? PUNCH_BPM : BPM); // seconds per beat
const LEN = isPunch ? PUNCH.reduce((n, s) => n + s.len, 0) * SPB : totalBeats(timeline) * SPB;
const N = Math.ceil((LEN + 0.05) * SR);
const dry = [new Float32Array(N), new Float32Array(N)];
const send = [new Float32Array(N), new Float32Array(N)]; // into the reverb

const midi = (m) => 440 * 2 ** ((m - 69) / 12);
const NOTE = {D1: 26, G1: 31, A1: 33, B1: 35, D2: 38, Fs2: 42, G2: 43, A2: 45, B2: 47, Cs3: 49, D3: 50, E3: 52, Fs3: 54, G3: 55, A3: 57, B3: 59,
  Cs4: 61, D4: 62, E4: 64, Fs4: 66, G4: 67, A4: 69, B4: 71, Cs5: 73, D5: 74, E5: 76, Fs5: 78, G5: 79, A5: 81, B5: 83, D6: 86, E6: 88, Fs6: 90};
const f = (n) => midi(NOTE[n]);

/** Adds a voice: fn(t, i) → sample, from time t0 for dur seconds, panned (-1..1), with a reverb send. */
function voice(t0, dur, pan, wet, fn) {
  const s0 = Math.max(0, Math.round(t0 * SR)), len = Math.round(dur * SR);
  const gl = Math.cos((pan + 1) * Math.PI / 4), gr = Math.sin((pan + 1) * Math.PI / 4);
  for (let i = 0; i < len && s0 + i < N; i++) {
    const v = fn(i / SR, i);
    dry[0][s0 + i] += v * gl; dry[1][s0 + i] += v * gr;
    send[0][s0 + i] += v * gl * wet; send[1][s0 + i] += v * gr * wet;
  }
}
const env = (t, dur, a, r) => Math.min(1, t / a) * Math.min(1, Math.max(0, (dur - t) / r));
let noiseSeed = 1;
const noise = () => { noiseSeed = (noiseSeed * 16807) % 2147483647; return (noiseSeed / 2147483647) * 2 - 1; };

// ---- instruments -----------------------------------------------------------------------------
/** Soft pad: detuned sine pairs with a slow breathing swell. */
function pad(notes, t0, t1, amp, {attack = 1.4, release = 0.8, swell = 0} = {}) {
  const dur = t1 - t0;
  notes.forEach((n, k) => {
    const fr = typeof n === 'number' ? n : f(n);
    const pan = (k / Math.max(1, notes.length - 1)) * 1.2 - 0.6;
    voice(t0, dur + release, pan, 0.55, (t) => {
      const e = env(t, dur + release, attack, release) * (1 + swell * Math.min(1, t / Math.max(dur, 0.01)));
      const lfo = 1 + 0.12 * Math.sin(2 * Math.PI * (0.13 + k * 0.03) * t + k);
      const w = 2 * Math.PI * fr * t;
      return 0.8 * amp * e * lfo * (Math.sin(w) * 0.5 + Math.sin(w * 1.003 + 1) * 0.5 + 0.12 * Math.sin(2 * w) + 0.04 * Math.sin(3 * w));
    });
  });
}
/** Felt piano: a few decaying partials, slightly stretched, soft hammer. */
function piano(n, t0, amp, pan = 0, dur = 2.6) {
  const fr = typeof n === 'number' ? n : f(n);
  voice(t0, dur, pan, 0.45, (t) => {
    const a = Math.min(1, t / 0.004);
    let s = 0;
    [[1, 1, 1.1], [2.003, 0.35, 0.6], [3.01, 0.12, 0.35], [4.02, 0.05, 0.25]].forEach(([h, g, d]) => { s += g * Math.exp(-t / d) * Math.sin(2 * Math.PI * fr * h * t); });
    return amp * a * s * Math.min(1, (dur - t) / 0.3);
  });
}
/** Glass tock: a struck glass, bell-like partials. */
function glass(n, t0, amp, pan = 0) {
  const fr = typeof n === 'number' ? n : f(n);
  voice(t0, 1.6, pan, 0.6, (t) => {
    const a = Math.min(1, t / 0.0015) * Math.min(1, (1.6 - t) / 0.3);
    return amp * a * (Math.exp(-t / 0.5) * Math.sin(2 * Math.PI * fr * t) + 0.35 * Math.exp(-t / 0.18) * Math.sin(2 * Math.PI * fr * 2.76 * t) + 0.12 * Math.exp(-t / 0.07) * Math.sin(2 * Math.PI * fr * 5.4 * t));
  });
}
/** A soft liquid gulp under each absorption. */
function gulp(t0, amp) {
  voice(t0, 0.3, 0, 0.2, (t) => amp * Math.exp(-t / 0.08) * Math.sin(2 * Math.PI * (160 - 260 * t) * t) * Math.min(1, t / 0.005));
}
/** Mac key click: a short noise tick plus a low thock. */
function key(t0, amp, low = 1, pan = 0) {
  const pitch = 150 + rand(t0 * 977) * 40;
  voice(t0, 0.09, pan, 0.08, (t) => amp * (0.55 * noise() * Math.exp(-t / 0.0035) + low * Math.exp(-t / 0.018) * Math.sin(2 * Math.PI * pitch * t)));
}
/** Results tick: dry, bright, tiny. */
function tick(t0, amp) {
  voice(t0, 0.12, 0.15, 0.1, (t) => amp * Math.exp(-t / 0.012) * Math.sin(2 * Math.PI * 3150 * t) + amp * 0.4 * noise() * Math.exp(-t / 0.002));
}
/** Held note with slow vibrato: the moment time stops. */
function held(n, t0, dur, amp) {
  const fr = typeof n === 'number' ? n : f(n);
  voice(t0, dur, 0, 0.7, (t) => amp * env(t, dur, 0.02, Math.min(1.6, dur * 0.5)) * Math.sin(2 * Math.PI * fr * t + 0.004 * fr * Math.sin(2 * Math.PI * 4.8 * t) / 4.8));
}
/** Bowed tone gliding f0→f1 with a growing tremolo: the reach. */
function bowed(f0, f1, t0, dur, amp, release = 0.12) {
  let ph = 0;
  voice(t0, dur + release, 0, 0.5, (t) => {
    const k = Math.min(1, t / dur);
    const fr = f0 * (f1 / f0) ** (k * k);
    ph += 2 * Math.PI * fr / SR;
    let s = 0;
    for (let h = 1; h <= 7; h++) s += Math.sin(ph * h) / (h * h * 0.8 + 0.2);
    const trem = 1 + 0.25 * k * Math.sin(2 * Math.PI * (5 + 4 * k) * t);
    const e = Math.min(1, t / 0.4) * (0.35 + 0.65 * k) * (t > dur ? Math.max(0, 1 - (t - dur) / release) : 1);
    return amp * e * trem * s * 0.6;
  });
}
function thud(t0, amp) {
  voice(t0, 0.4, 0, 0.25, (t) => amp * (Math.exp(-t / 0.09) * Math.sin(2 * Math.PI * (75 - 40 * t) * t) + 0.25 * noise() * Math.exp(-t / 0.01)));
}
function subdrop(t0, amp) {
  let ph = 0;
  voice(t0, 0.9, 0, 0.15, (t) => { ph += 2 * Math.PI * (95 * Math.exp(-t * 2.2) + 32) / SR; return amp * Math.exp(-t / 0.35) * Math.sin(ph) * Math.min(1, t / 0.01); });
}
function kick(t0, amp) {
  let ph = 0;
  voice(t0, 0.35, 0, 0.05, (t) => { ph += 2 * Math.PI * (48 + 90 * Math.exp(-t * 35)) / SR; return amp * Math.exp(-t / 0.13) * Math.sin(ph); });
}
function rim(t0, amp) {
  voice(t0, 0.08, 0.25, 0.25, (t) => amp * (0.6 * noise() * Math.exp(-t / 0.006) + Math.exp(-t / 0.02) * Math.sin(2 * Math.PI * 1850 * t)));
}
let hpPrev = 0;
function shaker(t0, amp, pan = -0.3) {
  voice(t0, 0.07, pan, 0.15, (t) => { const n = noise(); const hp = n - hpPrev; hpPrev = n; return amp * hp * Math.min(1, t / 0.008) * Math.exp(-t / 0.02); });
}
function bass(n, t0, dur, amp) {
  const fr = typeof n === 'number' ? n : f(n);
  voice(t0, dur, 0, 0.05, (t) => amp * env(t, dur, 0.01, 0.08) * (Math.sin(2 * Math.PI * fr * t) + 0.25 * Math.sin(4 * Math.PI * fr * t)) * Math.exp(-t / 1.4));
}
function drone(notes, t0, t1, amp) {
  const dur = t1 - t0;
  notes.forEach((n, k) => voice(t0, dur, k ? 0.3 : -0.3, 0.3, (t) => {
    const w = 2 * Math.PI * f(n) * t;
    return amp * env(t, dur, 1.2, 0.3) * (Math.sin(w) + 0.3 * Math.sin(2 * w + 0.5) + 0.1 * Math.sin(3 * w)) * (1 + 0.1 * Math.sin(2 * Math.PI * 0.2 * t));
  }));
}


// ---- PUNCH: the fast kinetic-type cut, 120 BPM, a stab on every cut -----------------------------
function clap(t0, amp) {
  voice(t0, 0.18, -0.1, 0.35, (t) => {
    const bursts = [0, 0.011, 0.022].reduce((a, d) => a + (t >= d ? Math.exp(-(t - d) / 0.006) : 0), 0) + Math.exp(-t / 0.05);
    return amp * noise() * bursts * 0.5;
  });
}
function hat(t0, amp, open = false) {
  let prev = 0;
  voice(t0, open ? 0.18 : 0.05, 0.35, 0.1, (t) => { const n = noise(); const hp = n - prev; prev = n; return amp * hp * Math.exp(-t / (open ? 0.06 : 0.012)); });
}
/** Bright plucked chord stab: the hit on every cut. */
function stab(notes, t0, amp) {
  notes.forEach((n, k) => {
    const fr = typeof n === 'number' ? n : f(n);
    voice(t0, 0.7, (k - 1) * 0.35, 0.4, (t) => {
      const e = Math.min(1, t / 0.003) * Math.exp(-t / 0.16);
      const w = 2 * Math.PI * fr * t;
      return amp * e * (Math.sin(w) + 0.5 * Math.sin(2 * w) * Math.exp(-t / 0.05) + 0.25 * Math.sin(3 * w) * Math.exp(-t / 0.03) + 0.3 * Math.sin(w * 1.007));
    });
  });
}
/** Wobbly, out-of-focus lead: "vague". */
function wobble(n, t0, dur, amp) {
  let ph = 0;
  const fr = f(n);
  voice(t0, dur, 0.1, 0.6, (t) => {
    ph += 2 * Math.PI * fr * (1 + 0.035 * Math.sin(2 * Math.PI * 5.5 * t) + 0.02 * Math.sin(2 * Math.PI * 1.3 * t)) / SR;
    return amp * env(t, dur, 0.05, 0.08) * (Math.sin(ph) + 0.2 * Math.sin(2 * ph));
  });
}
function riseTone(f0, f1, t0, dur, amp) {
  let ph = 0;
  voice(t0, dur, 0, 0.3, (t) => { const k = t / dur; ph += 2 * Math.PI * f0 * (f1 / f0) ** (k * k) / SR; return amp * k * k * (Math.sin(ph) + 0.3 * Math.sin(3 * ph)) * Math.min(1, (dur - t) / 0.01); });
}

if (isPunch) {
  const B = (b) => b * SPB;
  const fr = (frames) => frames / FPS; // a frame offset inside a shot, in seconds
  const starts = [];
  let acc = 0;
  for (const sh of PUNCH) { starts.push(acc); acc += sh.len; }
  const at = Object.fromEntries(PUNCH.map((sh, i) => [sh.id, starts[i]]));
  const endB = at.end;
  const chords = [['D4', 'Fs4', 'A4'], ['B3', 'D4', 'Fs4'], ['G3', 'B3', 'D4'], ['A3', 'Cs4', 'E4']];
  const roots = ['D2', 'B1', 'G1', 'A1'];

  // intro: the keys. A low swell, ⌥, then Space lands a sub hit and the hats creep in.
  pad(['D2', 'A2'], 0, B(at.vague), 0.05, {attack: 1.0, release: 0.05, swell: 0.8});
  key(fr(pbeat(0.75)), 0.22, 1.2, -0.2);
  key(fr(pbeat(1)), 0.3, 1.5, 0.2);
  subdrop(fr(pbeat(1)), 0.25);
  for (let k = 0; k < 8; k++) hat(B(1 + k * 0.25), 0.03 + k * 0.01);

  // the groove: four on the floor from the first word to the end card
  for (let b = at.vague; b < endB; b++) {
    const bar = Math.floor((b - at.vague) / 4) % 4;
    kick(B(b), 0.42);
    if ((b - at.vague) % 2 === 1) clap(B(b), 0.32);
    hat(B(b + 0.5), 0.09, (b - at.vague) % 4 === 3);
    hat(B(b + 0.25), 0.035); hat(B(b + 0.75), 0.035);
    bass(roots[bar], B(b + 0.5), SPB * 0.45, 0.16);
    bass(roots[bar], B(b), SPB * 0.3, 0.1);
  }
  // a stab on every cut
  PUNCH.forEach((sh, i) => {
    if (sh.id === 'keys' || sh.id === 'end') return;
    const bar = Math.floor((starts[i] - at.vague) / 4) % 4;
    stab(chords[bar], B(starts[i]), 0.07);
  });
  // each word's sound
  wobble('A5', B(at.vague), B(at.exact - at.vague) - 0.02, 0.05);                 // vague: can't hold the pitch
  glass('D6', B(at.exact) + fr(22), 0.18, 0.3);                                     // exact: the full stop lands
  [0, 0.06, 0.12].forEach((d) => tick(B(at.files) + d, 0.08));                    // files: pages stack
  tick(B(at.screenshots) + fr(4), 0.06); key(B(at.screenshots) + fr(25), 0.2, 0.6, 0.3); // screenshots: drag, release
  key(B(at.clipboard) + fr(16), 0.14, 1, 0.1); key(B(at.clipboard) + fr(18), 0.18, 1.1, 0.1); // clipboard: ⌘C
  piano('A4', B(at.meaning), 0.16, -0.1); piano('D5', B(at.meaning + 1.6), 0.18, 0.1); piano('Fs5', B(at.meaning + 1.6) + 0.12, 0.12, 0.2); // meaning: typed → found
  for (let k = 0; k < 10; k++) tick(B(at.ms) + fr(k * 1.6), 0.05);                 // ms: the number rolls
  glass('A5', B(at.ms) + fr(16), 0.16, 0);
  riseTone(f('A3'), f('E4'), B(at.private) + fr(6), fr(24), 0.08);                 // private: runs at the wall
  thud(B(at.private) + fr(30), 0.34); subdrop(B(at.private) + fr(30), 0.18);

  // end: the groove stops dead; the chord resolves as the icon settles; the name lands
  subdrop(B(endB), 0.22);
  pad(['D3', 'A3', 'E4', 'Fs4', 'A4'], B(endB), LEN - 0.4, 0.06, {attack: 0.6, release: 1.2, swell: 0.3});
  bass('D2', B(endB) + fr(60), LEN - B(endB) - fr(60), 0.08);
  [['A4', 30], ['Cs5', 45], ['D5', 60]].forEach(([n, d]) => piano(n, B(endB) + fr(d), 0.15, 0));
  glass('D6', B(endB) + fr(80), 0.16, 0); piano('D3', B(endB) + fr(80), 0.14, 0, 4);
  piano('Fs5', B(endB) + fr(92), 0.08, 0.2, 3);
  piano('A5', B(endB) + fr(102), 0.07, -0.2, 3);
}

// ---- the score, scene by scene ------------------------------------------------------------------
const T = (sceneAt, b) => (sceneAt + b) * SPB; // seconds
const TOCKS = ['A5', 'B5', 'D6', 'E6', 'Fs6'];

for (const s of timeline) {
  const at = s.at, end = s.at + s.len, v = s.variant ?? 'full';
  const t0 = T(at, 0), t1 = T(end, 0);
  switch (s.id) {
    case 'absorb': {
      const p = ABSORB[v];
      pad(['D3', 'A3', 'E4', 'Fs4'], t0, t1, 0.055, {attack: at === 0 ? 2.2 : 0.4, release: 0.25});
      pad(['A4', 'Cs5'], T(at, p.lineAt), t1, 0.03, {attack: 1.6, release: 0.25});
      p.contacts.forEach((c, i) => {
        glass(TOCKS[p.kinds[i]], T(at, c), 0.16, [0.5, -0.5, 0.3, -0.6, 0.4][p.kinds[i]]);
        gulp(T(at, c) - 0.05, 0.12);
      });
      // a felt pulse arrives with the last fragment
      const last = p.contacts[p.contacts.length - 1];
      for (let b = Math.ceil(last); b < s.len; b++) bass('D2', T(at, b), SPB * 0.9, 0.06);
      break;
    }
    case 'tongue': {
      const p = TONGUE[v];
      pad(['G2', 'D3', 'A3', 'E4'], t0, t1, 0.05, {attack: 0.6, release: 0.05, swell: 0.6});
      voice(t0 + 0.4, t1 - t0 - 0.4, 0.2, 0.7, (t) => 0.035 * env(t, t1 - t0 - 0.4, 1.2, 0.05) * Math.sin(2 * Math.PI * f('E5') * t * (1 + 0.006 * Math.sin(2 * Math.PI * 0.7 * t))));
      key(T(at, p.optAt), 0.16, 1, -0.2); // ⌥ goes down
      break;
    }
    case 'panel': {
      const p = PANEL_T[v];
      key(t0, 0.22, 1.4, 0.1); // Space: time stops
      held('A5', t0, 4.2 * SPB, 0.07);
      pad(['D3', 'Fs3', 'A3'], T(at, 1.5), t1, 0.035, {attack: 1.6, release: 0.12}); // after the stop
      pad(['Cs5', 'E5'], T(at, 4), t1, 0.018, {attack: 2.0, release: 0.12});
      p.queries.forEach((qq, i) => {
        const q = QUERIES[qq.q];
        const rf = Math.round((at + qq.results) * FPS * SPB);
        if (qq.select !== undefined) { key(T(at, qq.select), 0.09, 0.8, 0.1); key(T(at, qq.select) + 0.06, 0.08, 0.8, 0.1); } // ⌘A
        keystrokes(q.text, Math.round(qq.results * FPS * SPB), keySeed(i)).forEach((k) => key(t0 + k / FPS, 0.06 + rand(k) * 0.02, 0.9, 0.1 + (rand(k + 3) - 0.5) * 0.3));
        tick(rf / FPS, 0.09);
        glass('D6', rf / FPS + 0.02, 0.05, 0.3);
      });
      if (p.copyAt !== undefined) { key(T(at, p.copyAt) - 0.05, 0.1, 1, 0.1); key(T(at, p.copyAt), 0.13, 1.1, 0.1); }
      break;
    }
    case 'meaning': {
      pad(['B2', 'Fs3', 'A3', 'D4'], t0, T(at, 4), 0.05, {attack: 0.5, release: 0.4});
      pad(['G2', 'D3', 'Fs3', 'B3'], T(at, 4), t1, 0.05, {attack: 0.4, release: 0.1});
      [['A4', 0.5], ['D5', 1], ['Cs5', 1.5], ['A4', 4.5], ['D5', 5], ['B4', 5.5]].forEach(([n, b]) => piano(n, T(at, b), 0.14, 0.15));
      glass('Fs6', T(at, 2.6), 0.05, 0.5); // the drop reaches the screenshot
      break;
    }
    case 'privacy': {
      const p = PRIVACY[v];
      drone(['D2', 'A2'], t0, t1, 0.05);
      bowed(f('A3'), f('E4'), T(at, p.reach[0]), (p.snap - p.reach[0]) * SPB, 0.07);
      thud(T(at, p.reach[1]), 0.22);
      subdrop(T(at, p.snap), 0.22);
      glass('D5', T(at, p.snap) + 0.05, 0.08, 0);
      [['D4', 0], ['Fs4', 0.02], ['A4', 0.04]].forEach(([n, d]) => piano(n, T(at, p.line + 0.25) + d, 0.09, 0));
      if (p.bump !== undefined) glass('A5', T(at, p.bump + 1.2), 0.06, 0.7);
      break;
    }
    case 'numbers': {
      const p = NUMBERS[v];
      const chords = [['D3', 'Fs3', 'A3'], ['Cs3', 'E3', 'A3'], ['B2', 'D3', 'Fs3'], ['G2', 'B2', 'D3']];
      const roots = ['D2', 'A1', 'B1', 'G1'];
      for (let bar = 0; bar * 4 < s.len; bar++) {
        const bt = T(at, bar * 4);
        pad(chords[bar % 4], bt, Math.min(bt + 4 * SPB, t1), 0.04, {attack: 0.08, release: 0.1});
        for (let b = 0; b < 4 && bar * 4 + b < s.len; b++) {
          const tb = T(at, bar * 4 + b);
          bass(roots[bar % 4], tb, SPB * 0.85, 0.11);
          if (b % 2 === 0) kick(tb, 0.32); else rim(tb, 0.1);
          const subdiv = v === 'full' && bar === 2 ? 4 : 2; // last bar builds
          for (let k = 0; k < subdiv; k++) shaker(tb + (k * SPB) / subdiv, k % 2 ? 0.05 : 0.08);
        }
      }
      ['D5', 'Fs5', 'A5', 'D6'].forEach((n, i) => piano(n, T(at, p.rows[i]), 0.15, -0.2 + i * 0.15, 1.6));
      break;
    }
    case 'end': {
      const p = END[v];
      pad(['D3', 'A3', 'E4', 'Fs4', 'A4'], t0, t1 - 0.6, 0.05, {attack: 1.5, release: 1.4, swell: 0.4});
      bass('D2', T(at, p.settle[1]), t1 - T(at, p.settle[1]), 0.07);
      [['A4', p.tile[0]], ['Cs5', p.tile[0] + 0.5], ['D5', p.tile[1]]].forEach(([n, b]) => piano(n, T(at, b), 0.14, 0));
      glass('D6', T(at, p.name), 0.12, 0); piano('D3', T(at, p.name), 0.12, 0, 4);
      piano('Fs5', T(at, p.url), 0.08, 0.2, 3);
      piano('A5', T(at, p.price), 0.07, -0.2, Math.max(1.5, t1 - T(at, p.price)));
      break;
    }
  }
}

// ---- reverb (Freeverb-style) on the send bus, then mix and limit --------------------------------
function reverb(input, spread) {
  const scale = SR / 44100;
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map((d) => ({buf: new Float32Array(Math.round((d + spread) * scale)), i: 0, lp: 0}));
  const aps = [556, 441, 341, 225].map((d) => ({buf: new Float32Array(Math.round((d + spread) * scale)), i: 0}));
  const out = new Float32Array(N), fb = 0.86, damp = 0.25;
  for (let n = 0; n < N; n++) {
    const x = input[n] * 0.015;
    let y = 0;
    for (const c of combs) {
      const o = c.buf[c.i];
      c.lp = o * (1 - damp) + c.lp * damp;
      c.buf[c.i] = x + c.lp * fb;
      c.i = (c.i + 1) % c.buf.length;
      y += o;
    }
    for (const a of aps) {
      const o = a.buf[a.i];
      a.buf[a.i] = y + o * 0.5;
      a.i = (a.i + 1) % a.buf.length;
      y = o - y;
    }
    out[n] = y;
  }
  return out;
}
const wetL = reverb(send[0], 0), wetR = reverb(send[1], 23);
const mixL = new Float32Array(N), mixR = new Float32Array(N);
// one-pole high-pass at ~30 Hz keeps the sub clean
const hpA = 1 / (1 + 2 * Math.PI * 30 / SR);
let pxL = 0, pyL = 0, pxR = 0, pyR = 0;
for (let n = 0; n < N; n++) {
  const xl = dry[0][n] + wetL[n] * 2.2, xr = dry[1][n] + wetR[n] * 2.2;
  pyL = hpA * (pyL + xl - pxL); pxL = xl; mixL[n] = pyL;
  pyR = hpA * (pyR + xr - pxR); pxR = xr; mixR[n] = pyR;
}

// fade the very end, normalise, gentle limiter
const fadeN = Math.round(1.2 * SR);
for (let n = N - fadeN; n < N; n++) { const g = (N - n) / fadeN; mixL[n] *= g; mixR[n] *= g; }
let peak = 0;
for (let n = 0; n < N; n++) peak = Math.max(peak, Math.abs(mixL[n]), Math.abs(mixR[n]));
const gain = 0.85 / peak; // headroom; final loudness is set when muxing (loudnorm, -16 LUFS)
const lim = (x) => Math.tanh(x * gain);

const data = Buffer.alloc(N * 4);
for (let n = 0; n < N; n++) {
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, lim(mixL[n]))) * 32767), n * 4);
  data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, lim(mixR[n]))) * 32767), n * 4 + 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22);
h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 4, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(data.length, 40);
fs.mkdirSync(out.split('/').slice(0, -1).join('/') || '.', {recursive: true});
fs.writeFileSync(out, Buffer.concat([h, data]));
console.log(`${out}  ${(N / SR).toFixed(2)} s  ${comp}`);
