import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {Blob} from './components/Blob';
import {Keycap} from './components/Keycap';
import {C, FONT, pbeat, PRICE, PUNCH, PUNCH_FOUND, PunchShot, SITE} from './constants';
import {loadFonts} from './lib/fonts';
import {ease, mix, rand, ramp, springAt} from './lib/motion';
import {squircle} from './scenes/End';

// PUNCH: one word per shot, flat full-bleed colour, every word acts out what it means.
// Hard cuts on a 120 BPM grid (one beat = 30 frames). Authored at 1920×1080.

loadFonts();

const W = 1920, H = 1080;
const BEAT = pbeat(1);

/** Shot start frames, from the shot list in constants.ts. */
export const punchStarts = () => {
  let at = 0;
  return PUNCH.map((s) => {
    const start = at;
    at += pbeat(s.len);
    return start;
  });
};
export const punchFrames = () => PUNCH.reduce((n, s) => n + pbeat(s.len), 0);

const Big: React.FC<{size: number; color: string; children: React.ReactNode; style?: React.CSSProperties}> = ({size, color, children, style}) => (
  <div style={{fontFamily: FONT.sans, fontWeight: 600, fontSize: size, letterSpacing: '-0.06em', lineHeight: 1, color, whiteSpace: 'nowrap', ...style}}>{children}</div>
);

/** Caption top-left and shot counter top-right, the editorial frame around each word. */
const Frame: React.FC<{s: PunchShot; i: number; lf: number; total: number}> = ({s, i, lf, total}) => {
  const t = ramp(lf, 3, 14, ease.out);
  const mono: React.CSSProperties = {position: 'absolute', top: 72, fontFamily: FONT.mono, fontSize: 34, letterSpacing: '0.04em', color: s.fg, opacity: 0.8 * t};
  return (
    <>
      {s.caption ? <div style={{...mono, left: 96, transform: `translateY(${(1 - t) * 10}px)`}}>{s.caption}</div> : null}
      <div style={{...mono, right: 96}}>{String(i + 1).padStart(2, '0')} / {String(total).padStart(2, '0')}</div>
    </>
  );
};

// ---- shots ----------------------------------------------------------------------------------------

const Keys: React.FC<{lf: number}> = ({lf}) => {
  const rise = ramp(lf, 0, 12, ease.out);
  const opt = ramp(lf, BEAT * 0.75, BEAT * 0.75 + 4, ease.out) * (1 - ramp(lf, BEAT * 2.4, BEAT * 2.4 + 6, ease.out));
  const space = ramp(lf, BEAT, BEAT + 4, ease.out) * (1 - ramp(lf, BEAT * 2.4, BEAT * 2.4 + 6, ease.out));
  const punch = lf >= BEAT ? 1 + 0.05 * Math.exp(-(lf - BEAT) / 6) : 1;
  const u = 230;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center', transform: `scale(${punch})`}}>
      <div style={{display: 'flex', gap: u * 0.12, opacity: rise, transform: `translateY(${(1 - rise) * 120}px)`}}>
        <Keycap u={u} width={1.3} down={opt} glyph="⌥" label="option" />
        <Keycap u={u} width={4.4} down={space} />
      </div>
    </AbsoluteFill>
  );
};

const Vague: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const t = lf / 60;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <Big size={440} color={s.fg}>
        {s.word.split('').map((ch, k) => {
          const ph = rand(k + 4) * 6.28, sp = 1.4 + rand(k + 9) * 1.2;
          const focus = 0.5 + 0.5 * Math.sin(t * sp * 3 + ph);
          return (
            <span key={k} style={{display: 'inline-block', filter: `blur(${6 + 16 * (1 - focus)}px)`, opacity: mix(0.55, 1, focus),
              transform: `translate(${Math.sin(t * sp * 2 + ph) * 22}px, ${Math.cos(t * sp * 1.7 + ph) * 18}px) rotate(${Math.sin(t * sp + ph) * 7}deg)`}}>{ch}</span>
          );
        })}
      </Big>
    </AbsoluteFill>
  );
};

const Exact: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const snap = ramp(lf, 0, 10, ease.out);
  const dot = springAt(lf, 12, {damping: 11, stiffness: 220});
  const caret = Math.floor(lf / 15) % 2 === 0 && lf > 24;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <Big size={460} color={s.fg} style={{letterSpacing: `${mix(0.5, -0.06, snap)}em`, filter: `blur(${(1 - snap) * 14}px)`}}>
        {s.word}
        <span style={{display: 'inline-block', color: s.accent, transform: `translateY(${(1 - dot) * -420}px)`, opacity: lf >= 12 ? 1 : 0}}>.</span>
        <span style={{display: 'inline-block', width: 14, height: 360, marginLeft: 26, background: s.fg, opacity: caret ? 1 : 0, verticalAlign: '-0.06em'}} />
      </Big>
    </AbsoluteFill>
  );
};

const Files: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const stack = ramp(lf, 0, 16, ease.out);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      {[3, 2, 1, 0].map((k) => (
        <div key={k} style={{position: 'absolute', transform: `translate(${-k * 46 * (1 - stack)}px, ${-k * 38 * (1 - stack)}px)`, opacity: k ? 0.18 + 0.1 * (3 - k) : 1}}>
          <Big size={480} color={s.fg}>{s.word}</Big>
        </div>
      ))}
    </AbsoluteFill>
  );
};

const Screenshots: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const drag = ramp(lf, 4, 24, ease.inOut);
  const x0 = 960 - 760, y0 = 540 - 190, x1 = 960 + 760, y1 = 540 + 170;
  const cx = mix(x0, x1, drag), cy = mix(y0, y1, drag);
  const done = lf > 26;
  return (
    <AbsoluteFill>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <Big size={265} color={s.fg}>{s.word}</Big>
      </AbsoluteFill>
      {lf >= 4 ? (
        <>
          <div style={{position: 'absolute', left: x0, top: y0, width: cx - x0, height: cy - y0, border: `3px dashed ${C.mineral}`,
            background: done ? 'rgba(255,255,255,0.16)' : 'rgba(255,255,255,0.10)'}} />
          <svg width={W} height={H} style={{position: 'absolute', inset: 0}}>
            <g stroke={C.mineral} strokeWidth={3}>
              <line x1={cx - 30} x2={cx + 30} y1={cy} y2={cy} />
              <line x1={cx} x2={cx} y1={cy - 30} y2={cy + 30} />
            </g>
          </svg>
          <div style={{position: 'absolute', left: cx + 22, top: cy + 18, fontFamily: FONT.mono, fontSize: 24, color: C.mineral}}>
            {Math.round(cx - x0)} × {Math.round(cy - y0)}
          </div>
        </>
      ) : null}
    </AbsoluteFill>
  );
};

const Clipboard: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const sel = ramp(lf, 2, 14, ease.out);
  const copy = ramp(lf, 18, 40, ease.out);
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <div style={{position: 'relative'}}>
        <div style={{position: 'absolute', left: -20, top: 40, bottom: 10, width: `calc(${sel * 100}% + ${sel * 40}px)`, background: 'rgba(10,132,255,0.38)', borderRadius: 6}} />
        <Big size={340} color={s.fg} style={{position: 'relative'}}>{s.word}</Big>
        {lf >= 18 ? (
          <Big size={340} color={C.sysBlue} style={{position: 'absolute', left: 0, top: 0, opacity: 0.7 * (1 - copy),
            transform: `translate(${copy * 70}px, ${copy * -90}px) scale(${1 - copy * 0.08})`}}>{s.word}</Big>
        ) : null}
      </div>
    </AbsoluteFill>
  );
};

const Meaning: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  // a masked slide: the typed words leave upward as the found words rise into the same slot (no cross-fade)
  const swap = ramp(lf, BEAT * 1.6, BEAT * 1.6 + 12, ease.inOut);
  const SLOT = 380;
  const label: React.CSSProperties = {fontFamily: FONT.mono, fontSize: 30, letterSpacing: '0.08em', color: s.fg, opacity: 0.6, marginBottom: 26};
  const block: React.CSSProperties = {position: 'absolute', left: 0, top: 40, height: SLOT};
  return (
    <AbsoluteFill>
      <div style={{position: 'absolute', left: 140, right: 60, top: 300, height: SLOT, overflow: 'hidden'}}>
        <div style={{...block, transform: `translateY(${-swap * SLOT}px)`}}>
          <div style={label}>you typed</div>
          <Big size={230} color={s.fg}>{s.word}</Big>
        </div>
        <div style={{...block, transform: `translateY(${(1 - swap) * SLOT}px)`}}>
          <div style={label}>it found</div>
          <Big size={230} color={s.accent ?? s.fg}>{PUNCH_FOUND}</Big>
        </div>
      </div>
    </AbsoluteFill>
  );
};

const Ms: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const rolling = lf < 16;
  const digit = rolling ? String(Math.floor(lf / 1.6) % 10) : s.word.replace('~', '');
  const land = lf >= 16 ? 1 + 0.06 * Math.exp(-(lf - 16) / 5) : 1;
  return (
    <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
      <Big size={700} color={s.fg} style={{transform: `scale(${land})`, display: 'flex', alignItems: 'baseline'}}>
        <span style={{fontSize: 360, opacity: 0.7, marginRight: 20}}>~</span>
        <span style={{display: 'inline-block', width: '0.6em', textAlign: 'center', filter: rolling ? 'blur(3px)' : 'none'}}>{digit}</span>
        <span style={{fontSize: 220, marginLeft: 30}}>ms</span>
      </Big>
    </AbsoluteFill>
  );
};

const Private: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const m = 70;
  const hitAt = 30;
  const travel = 330; // centre → the right-hand wall
  const go = ramp(lf, 6, hitAt, ease.in);
  const back = springAt(lf, hitAt, {damping: 9, stiffness: 150});
  const x = lf < hitAt ? go * travel : travel * (1 - back);
  const squash = lf >= hitAt ? Math.exp(-(lf - hitAt) / 6) : 0;
  const flash = lf >= hitAt ? Math.exp(-(lf - hitAt) / 10) : 0;
  return (
    <AbsoluteFill>
      <svg width={W} height={H} style={{position: 'absolute', inset: 0}}>
        <rect x={m} y={m} width={W - 2 * m} height={H - 2 * m} rx={28} fill="none" stroke={C.mineral} strokeOpacity={0.55} strokeWidth={2} />
        <line x1={W - m} x2={W - m} y1={540 - 200} y2={540 + 200} stroke={s.accent} strokeWidth={6} opacity={flash} />
      </svg>
      <AbsoluteFill style={{alignItems: 'center', justifyContent: 'center'}}>
        <div style={{transform: `translateX(${x}px) scale(${1 - 0.14 * squash}, ${1 + 0.08 * squash})`, transformOrigin: '100% 50%'}}>
          <Big size={330} color={s.fg}>
            {s.word}
            <span style={{color: s.accent}}>.</span>
          </Big>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

const End: React.FC<{lf: number; s: PunchShot}> = ({lf, s}) => {
  const T = 300, cx = 960, cy = 330;
  const grow = springAt(lf, 0, {damping: 12, stiffness: 160});
  const settle = ramp(lf, 24, 60, ease.inOut);
  const tileIn = ramp(lf, 44, 62, ease.out);
  const swap = ramp(lf, 62, 74, ease.inOut);
  const R = mix(170 * grow, 0.318 * T, settle);
  const iconSize = (T * 1024) / 824;
  const name = ramp(lf, 70, 82, ease.out);
  const dot = springAt(lf, 80, {damping: 11, stiffness: 220});
  const url = ramp(lf, 92, 108, ease.soft);
  const price = ramp(lf, 102, 118, ease.soft);
  const mask = `url("data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='${W}' height='${H}'><rect width='${W}' height='${H}' fill='white' fill-opacity='${(1 - tileIn).toFixed(3)}'/><path d='${squircle(cx, cy, T)}' fill='white'/></svg>`,
  )}")`;
  return (
    <AbsoluteFill>
      <svg width={W} height={H} style={{position: 'absolute', inset: 0, opacity: tileIn}}>
        <defs>
          <linearGradient id="ptile" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={C.tileTop} />
            <stop offset="1" stopColor={C.tileBottom} />
          </linearGradient>
        </defs>
        <path d={squircle(cx, cy, T * mix(0.94, 1, tileIn))} fill="url(#ptile)" />
      </svg>
      <div style={{position: 'absolute', inset: 0, opacity: 1 - swap, WebkitMaskImage: mask, maskImage: mask}}>
        <Blob state={{cx, cy: cy + 0.015 * T, R: Math.max(R, 0.1), time: 70 + lf / 60, wobble: 1 - settle, icon: settle, swirl: mix(1.6, 0, settle), glow: 1}} />
      </div>
      <Img src={staticFile('icon/icon.png')} style={{position: 'absolute', left: cx - iconSize / 2, top: cy - iconSize / 2, width: iconSize, height: iconSize, opacity: swap}} />
      <div style={{position: 'absolute', left: 0, right: 0, top: 530, display: 'flex', justifyContent: 'center', opacity: name,
        transform: `scale(${mix(1.08, 1, name)})`}}>
        <Big size={220} color={s.fg}>
          {s.word}
          <span style={{display: 'inline-block', color: s.accent, transform: `translateY(${(1 - dot) * -300}px)`, opacity: lf >= 80 ? 1 : 0}}>.</span>
        </Big>
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 800, textAlign: 'center', fontFamily: FONT.mono, fontSize: 40, color: s.fg, opacity: url}}>{SITE}</div>
      <div style={{position: 'absolute', left: 0, right: 0, top: 870, textAlign: 'center', fontFamily: FONT.sans, fontSize: 38, letterSpacing: '-0.02em', color: C.muted, opacity: price}}>
        {PRICE.earlyBird ? `Free to search · Pro ${PRICE.earlyBird} early bird, then ${PRICE.price}, once` : `Free to search · Pro ${PRICE.price}, once`}
      </div>
    </AbsoluteFill>
  );
};

const SHOTS: Record<string, React.FC<{lf: number; s: PunchShot}>> = {
  keys: ({lf}) => <Keys lf={lf} />, vague: Vague, exact: Exact, files: Files, screenshots: Screenshots, clipboard: Clipboard,
  meaning: Meaning, ms: Ms, private: Private, end: End,
};

export const Punch: React.FC = () => {
  const f = useCurrentFrame();
  const starts = punchStarts();
  let i = starts.length - 1;
  while (i > 0 && f < starts[i]) i--;
  const s = PUNCH[i];
  const lf = f - starts[i];
  const Shot = SHOTS[s.id];
  const slam = s.id === 'keys' || s.id === 'end' ? 1 : 1 + 0.06 * Math.exp(-lf / 5); // each word lands with a small punch-in
  const counted = PUNCH.filter((p) => p.id !== 'end').length;
  return (
    <AbsoluteFill style={{background: s.bg}}>
      <AbsoluteFill style={{transform: `scale(${slam})`}}>
        <Shot lf={lf} s={s} />
      </AbsoluteFill>
      {s.id !== 'end' ? <Frame s={s} i={i} lf={lf} total={counted} /> : null}
    </AbsoluteFill>
  );
};
