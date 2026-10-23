// Voice-over SAMPLE: speaks the VO lines in src/constants.ts with an Apple voice (macOS `say`), places each line
// on its beat, ducks the score underneath, and writes one mixed WAV. The final films stay music-only.
//   node --experimental-strip-types scripts/voice.mjs <Master|Short|Vertical|Square> <score.wav> <out.wav>
// Voice: $VOICE if set, else the first installed Premium/Enhanced English voice, else Daniel.
import {execFileSync} from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {BPM, VO} from '../src/constants.ts';

const [comp = 'Master', scorePath, out] = process.argv.slice(2);
const lines = VO[comp];
if (!lines || !scorePath || !out) throw new Error('usage: voice.mjs <comp> <score.wav> <out.wav>');
const SR = 48000;
const SPB = 60 / BPM;

function pickVoice() {
  if (process.env.VOICE) return process.env.VOICE;
  const list = execFileSync('say', ['-v', '?']).toString().split('\n');
  const english = list.filter((l) => /\ben_(US|GB|AU|IE)\b/.test(l));
  const prefer = ['Ava', 'Zoe', 'Evan', 'Nathan', 'Serena', 'Jamie', 'Allison', 'Tom', 'Susan', 'Samantha'];
  for (const tier of ['(Premium)', '(Enhanced)']) {
    for (const name of prefer) {
      const hit = english.find((l) => l.startsWith(name) && l.includes(tier));
      if (hit) return hit.split(/\s{2,}/)[0].trim();
    }
    const any = english.find((l) => l.includes(tier));
    if (any) return any.split(/\s{2,}/)[0].trim();
  }
  return 'Daniel';
}

function readWav(file) {
  const b = fs.readFileSync(file);
  let p = 12, fmt = null, data = null;
  while (p < b.length) {
    const id = b.toString('ascii', p, p + 4), size = b.readUInt32LE(p + 4);
    if (id === 'fmt ') fmt = {ch: b.readUInt16LE(p + 10), sr: b.readUInt32LE(p + 12), bits: b.readUInt16LE(p + 22)};
    if (id === 'data') data = b.subarray(p + 8, p + 8 + size);
    p += 8 + size + (size % 2);
  }
  if (!fmt || !data || fmt.bits !== 16 || fmt.sr !== SR) throw new Error(`${file}: need 16-bit ${SR} Hz PCM`);
  const n = data.length / (2 * fmt.ch);
  const chans = Array.from({length: 2}, () => new Float32Array(n));
  for (let i = 0; i < n; i++) for (let c = 0; c < 2; c++) chans[c][i] = data.readInt16LE((i * fmt.ch + Math.min(c, fmt.ch - 1)) * 2) / 32768;
  return chans;
}

const voice = pickVoice();
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'recall-vo-'));
const [L, R] = readWav(scorePath);
const N = L.length;
const vo = new Float32Array(N);
let prevEnd = 0;
lines.forEach((ln, i) => {
  const aiff = path.join(tmp, `${i}.aiff`), wav = path.join(tmp, `${i}.wav`);
  execFileSync('say', ['-v', voice, '-r', '172', '-o', aiff, ln.text.replace(/’/g, "'")]);
  // clean, close voice: trim leading silence, roll off rumble, gentle compression
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', aiff, '-af',
    'silenceremove=start_periods=1:start_threshold=-50dB,highpass=f=90,acompressor=threshold=-22dB:ratio=3:attack=5:release=120,volume=1.4',
    '-ar', String(SR), '-ac', '1', '-c:a', 'pcm_s16le', wav]);
  const [v] = readWav(wav);
  const s0 = Math.round(ln.beat * SPB * SR);
  if (s0 < prevEnd) console.warn(`  overlap: "${ln.text}" starts ${((prevEnd - s0) / SR).toFixed(2)} s before the previous line ends`);
  if (s0 + v.length > N) console.warn(`  runs past the end: "${ln.text}"`);
  for (let k = 0; k < v.length && s0 + k < N; k++) vo[s0 + k] += v[k];
  prevEnd = s0 + v.length;
  console.log(`  ${(s0 / SR).toFixed(2).padStart(6)} s  ${(v.length / SR).toFixed(2)} s  ${ln.text}`);
});

// duck the score under the voice: a smoothed envelope of the VO pulls the music down ~8 dB
const env = new Float32Array(N);
let e = 0;
const att = Math.exp(-1 / (0.03 * SR)), rel = Math.exp(-1 / (0.45 * SR));
for (let i = 0; i < N; i++) { const x = Math.abs(vo[i]) > 0.003 ? 1 : 0; e = x > e ? att * e + (1 - att) * x : rel * e + (1 - rel) * x; env[i] = e; }
const duck = 10 ** (-8 / 20);
const data = Buffer.alloc(N * 4);
for (let i = 0; i < N; i++) {
  const g = 1 - (1 - duck) * env[i];
  const l = Math.max(-1, Math.min(1, L[i] * g + vo[i] * 0.9)), r = Math.max(-1, Math.min(1, R[i] * g + vo[i] * 0.9));
  data.writeInt16LE(Math.round(l * 32767), i * 4); data.writeInt16LE(Math.round(r * 32767), i * 4 + 2);
}
const h = Buffer.alloc(44);
h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8);
h.write('fmt ', 12); h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(2, 22);
h.writeUInt32LE(SR, 24); h.writeUInt32LE(SR * 4, 28); h.writeUInt16LE(4, 32); h.writeUInt16LE(16, 34);
h.write('data', 36); h.writeUInt32LE(data.length, 40);
fs.writeFileSync(out, Buffer.concat([h, data]));
fs.rmSync(tmp, {recursive: true});
console.log(`${out}  voice: ${voice}`);
