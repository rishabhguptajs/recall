// Renders stills: node scripts/stills.mjs <Composition> <outDir> <scale> <frame,frame,...>
import {bundle} from '@remotion/bundler';
import {renderStill, selectComposition} from '@remotion/renderer';
import path from 'node:path';
import fs from 'node:fs';

const [comp = 'Master', outDir = 'out/stills', scale = '0.5', framesArg = '0'] = process.argv.slice(2);
const frames = framesArg.split(',').map(Number);
fs.mkdirSync(outDir, {recursive: true});
const serveUrl = await bundle({entryPoint: path.resolve('src/index.ts')});
const composition = await selectComposition({serveUrl, id: comp, chromiumOptions: {gl: 'angle'}});
for (const frame of frames) {
  const output = path.join(outDir, `${comp}-${String(frame).padStart(4, '0')}.png`);
  await renderStill({serveUrl, composition, frame, output, scale: Number(scale), chromiumOptions: {gl: 'angle'}, overwrite: true});
  console.log(output);
}
