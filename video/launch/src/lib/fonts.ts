import {continueRender, delayRender, staticFile} from 'remotion';

// Brand fonts from raegent-web (OFL, licences in public/fonts). Loaded once, before any frame renders.
let started = false;
export function loadFonts() {
  if (started || typeof document === 'undefined') return;
  started = true;
  const handle = delayRender('fonts');
  const faces = [
    new FontFace('Instrument Sans', `url(${staticFile('fonts/InstrumentSans.woff2')}) format('woff2')`, {weight: '400 700'}),
    new FontFace('Geist Mono', `url(${staticFile('fonts/GeistMono.woff2')}) format('woff2')`, {weight: '100 900'}),
  ];
  Promise.all(faces.map((f) => f.load()))
    .then((loaded) => {
      loaded.forEach((f) => (document.fonts as unknown as {add: (f: FontFace) => void}).add(f));
      return document.fonts.ready;
    })
    .then(() => continueRender(handle))
    .catch((e) => {
      console.error(e);
      continueRender(handle);
    });
}
