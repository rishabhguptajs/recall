// Prints the master's cue sheet as a Markdown table (timecode at 60 fps), from CUES in src/constants.ts.
//   node --experimental-strip-types scripts/cue-sheet.mjs
import {BPM, CUES, FPS, MASTER, beat} from '../src/constants.ts';

const tc = (frames) => {
  const s = Math.floor(frames / FPS), ff = frames % FPS;
  return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}:${String(ff).padStart(2, '0')}`;
};
console.log(`Grid: ${BPM} BPM, 4/4, one beat = ${beat(1)} frames at ${FPS} fps. Timecode is mm:ss:ff (60 fps).\n`);
console.log('| Timecode | Bar.beat | Cue | What happens / what the score does |');
console.log('| --- | --- | --- | --- |');
for (const c of CUES) {
  const bar = Math.floor(c.beat / 4) + 1, bt = (c.beat % 4) + 1;
  console.log(`| ${tc(beat(c.beat))} | ${bar}.${Number.isInteger(bt) ? bt : bt.toFixed(1)} | ${c.name} | ${c.note} |`);
}
console.log('\nScenes:\n');
for (const s of MASTER) console.log(`- ${tc(beat(s.at))}–${tc(beat(s.at + s.len))}  ${s.id}`);
