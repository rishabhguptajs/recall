import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Ball, Blob} from '../components/Blob';
import {FadeLine, Rise} from '../components/Type';
import {beat, C, COPY, FONT} from '../constants';
import {pick, useGeo} from '../lib/geo';
import {PRIVACY} from '../timing';
import {ease, mix, ramp, springAt} from '../lib/motion';

// Surface tension: the edge of the Mac is a hairline. The liquid reaches for it, presses flat against it,
// and is pulled back. Nothing gets through.

type Plan = {draw: number; reach: [number, number]; snap: number; line: number; sub: number; bump?: number};
const PLANS: Record<string, Plan> = PRIVACY;

export const Privacy: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  const {w, h, aspect} = useGeo();
  const p = PLANS[variant];
  const g = pick(aspect, {
    wide: {m: 72, cx: 960, cy: 500, R: 165, line: {top: 760, size: 96}, sub: {top: 900, size: 24}, lines: [COPY.privacyLine]},
    tall: {m: 56, cx: 540, cy: 860, R: 165, line: {top: 1260, size: 92}, sub: {top: 1500, size: 25}, lines: ['Nothing leaves', 'your Mac.']},
    square: {m: 48, cx: 540, cy: 400, R: 135, line: {top: 660, size: 70}, sub: {top: 790, size: 21}, lines: [COPY.privacyLine]},
  });
  const radius = 26;
  const drawT = ramp(f, beat(p.draw), beat(p.draw) + (variant === 'full' ? 70 : 30), ease.inOut);
  const perim = 2 * (w - 2 * g.m + h - 2 * g.m);

  // the reach, the press, the snap back
  const reach = ramp(f, beat(p.reach[0]), beat(p.reach[1]), ease.inOut);
  const strain = f > beat(p.reach[1]) && f < beat(p.snap) ? 0.04 * Math.sin(((f - beat(p.reach[1])) / 9) * Math.PI) : 0;
  const snap = springAt(f, beat(p.snap), {damping: 9, stiffness: 170});
  const extend = f < beat(p.snap) ? reach * 1.08 + strain : mix(1.08, 0, snap);
  const press = ramp(f, beat(p.reach[1]) - 20, beat(p.reach[1]) + 10, ease.out) * (1 - ramp(f, beat(p.snap), beat(p.snap) + 10, ease.out));
  const dtSnap = f - beat(p.snap);
  const kick = dtSnap > 0 ? Math.exp(-dtSnap / 30) * Math.sin((dtSnap / 30) * Math.PI * 2) * 1.1 : 0;

  // a few loose drops drift inside; one of them bumps the right-hand wall and comes back
  const t = f / 60;
  const balls: Ball[] = [0, 1, 2].map((i) => {
    const ang = t * 0.28 + i * 2.2;
    const rr = g.R * (1.95 + 0.15 * Math.sin(t * 0.7 + i));
    return {x: g.cx + Math.cos(ang) * rr, y: g.cy + Math.sin(ang) * rr * 0.8, r: g.R * (0.1 + 0.03 * i)};
  });
  if (p.bump !== undefined) {
    const go = ramp(f, beat(p.bump), beat(p.bump + 1.2), ease.in);
    const back = springAt(f, beat(p.bump + 1.2), {damping: 10, stiffness: 140});
    const x = mix(g.cx + g.R * 2.2, w - g.m + 30, go * (1 - back));
    balls.push({x, y: g.cy + g.R * 0.2, r: g.R * 0.2});
  }
  const wall = 3;
  const clip: [number, number, number, number] = [g.m + wall, g.m + wall, w - g.m - wall, h - g.m - wall];
  const contactGlow = press;

  return (
    <AbsoluteFill style={{background: C.deep}}>
      <svg width={w} height={h} style={{position: 'absolute', inset: 0}}>
        <rect x={g.m} y={g.m} width={w - 2 * g.m} height={h - 2 * g.m} rx={radius} fill="none" stroke={C.mineral} strokeOpacity={0.5} strokeWidth={1.5}
          strokeDasharray={perim} strokeDashoffset={perim * (1 - drawT)} />
        <line x1={g.cx - 70} x2={g.cx + 70} y1={g.m} y2={g.m} stroke={C.green} strokeWidth={2.5} opacity={contactGlow} />
      </svg>
      <div style={{position: 'absolute', left: g.m + 26, top: g.m - (aspect === 'tall' ? 17 : 11), padding: '0 10px', background: C.deep, fontFamily: FONT.mono, fontSize: aspect === 'tall' ? 28 : 18,
        letterSpacing: '0.14em', textTransform: 'uppercase', color: C.muted, opacity: ramp(f, beat(p.draw) + 20, beat(p.draw) + 50, ease.soft)}}>
        {COPY.boundaryLabel}
      </div>
      <Blob state={{cx: g.cx, cy: g.cy, R: g.R, time: t + 30, wobble: 1, swirl: 2.6, glow: 0.85, kick, kickAngle: Math.PI / 2, k: g.R * 0.45,
        balls, clip, arms: extend > 0.002 ? [{x: g.cx, y: mix(g.cy, g.m - 40, extend), base: g.R * 0.24, tip: g.R * mix(0.15, 0.28, press)}] : []}} />
      <div style={{position: 'absolute', left: 0, right: 0, top: g.line.top}}>
        <Rise f={f} at={beat(p.line)} lines={g.lines} size={g.line.size} align="center" />
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: g.sub.top, display: 'flex', justifyContent: 'center'}}>
        <FadeLine f={f} at={beat(p.sub)} style={{fontFamily: FONT.mono, fontSize: g.sub.size, letterSpacing: '0.1em', color: C.muted, textTransform: 'uppercase'}}>
          {COPY.privacySub}
        </FadeLine>
      </div>
    </AbsoluteFill>
  );
};
