// Temp click track, generated from the same beat grid and cue table as the picture.
// Not music: a guide for the composer and the edit. Original, no samples.
//   node --experimental-strip-types scripts/temp-track.mjs <Master|Short|Vertical|Square> <out.wav>
//
// Every beat: a soft click (downbeats accented). Every cue in CUES (master) or every scene start (cutdowns):
// a short sine ping, so the hit points are audible.
import fs from 'node:fs';
import {BPM, CUES, MASTER, SHORT, SQUARE, VERTICAL, totalBeats} from '../src/constants.ts';

const [comp = 'Master', out = 'out/temp-track.wav'] = process.argv.slice(2);
const timeline = {Master: MASTER, Short: SHORT, Vertical: VERTICAL, Square: SQUARE}[comp];
const SR = 48000;
const secPerBeat = 60 / BPM;
const beats = totalBeats(timeline);
const n = Math.round(beats * secPerBeat * SR);
const buf = new Float32Array(n);

function add(atSec, durSec, fn) {
  const s0 = Math.round(atSec * SR), len = Math.round(durSec * SR);
  for (let i = 0; i < len && s0 + i < n; i++) buf[s0 + i] += fn(i / SR);
}
const click = (freq, amp) => (t) => amp * Math.sin(2 * Math.PI * freq * t) * Math.exp(-t / 0.006);
const ping = (freq, amp) => (t) => amp * (Math.sin(2 * Math.PI * freq * t) + 0.3 * Math.sin(4 * Math.PI * freq * t)) * Math.exp(-t / 0.18) * Math.min(1, t / 0.004);

for (let b = 0; b < beats; b++) add(b * secPerBeat, 0.05, click(b % 4 === 0 ? 2400 : 1600, b % 4 === 0 ? 0.32 : 0.18));

const hits = comp === 'Master' ? CUES.map((c) => c.beat) : timeline.map((s) => s.at);
const scale = [523.25, 587.33, 659.25, 783.99, 880.0]; // C major pentatonic, so overlapping pings never clash
hits.forEach((b, i) => {
  if (b >= beats) return;
  add(b * secPerBeat, 0.9, ping(scale[i % scale.length], 0.28));
});

// 16-bit stereo WAV
const data = Buffer.alloc(n * 4);
for (let i = 0; i < n; i++) {
  const v = Math.max(-1, Math.min(1, buf[i])) * 32767;
  data.writeInt16LE(v | 0, i * 4);
  data.writeInt16LE(v | 0, i * 4 + 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22);
h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 4, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(data.length, 40);
fs.mkdirSync(out.split('/').slice(0, -1).join('/') || '.', {recursive: true});
fs.writeFileSync(out, Buffer.concat([h, data]));
console.log(`${out}  ${(n / SR).toFixed(2)} s, ${beats} beats at ${BPM} BPM, ${hits.length} hit points`);
