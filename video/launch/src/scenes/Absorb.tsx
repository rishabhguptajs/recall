import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Arm, Ball, Blob} from '../components/Blob';
import {FragmentCard} from '../components/Fragment';
import {Rise} from '../components/Type';
import {beat, C, COPY, FRAGMENTS} from '../constants';
import {pick, useGeo} from '../lib/geo';
import {ABSORB} from '../timing';
import {camera, CamKey, ease, mix, ramp, toScreen} from '../lib/motion';

// The day: fragments drift in, the blob reaches out, takes each one in and changes colour a little.

type Plan = {contacts: number[]; kinds: number[]; lineAt: number; lineOut?: number; cam: (w: number, h: number, cx: number, cy: number) => CamKey[]};

const PLANS: Record<string, Plan> = {
  full: {
    ...ABSORB.full,
    cam: (w, h, cx, cy) => [
      {f: 0, x: cx, y: cy, s: 1.2},
      {f: beat(3.6), x: cx, y: cy, s: 1.16, e: ease.soft},
      {f: beat(6.4), x: w / 2, y: h / 2, s: 1.0},
      {f: beat(15.5), x: w / 2, y: h / 2, s: 1.0},
      {f: beat(20), x: mix(w / 2, cx, 0.5), y: mix(h / 2, cy, 0.5), s: 1.07, e: ease.soft},
    ],
  },
  medium: {
    ...ABSORB.medium,
    cam: (w, h, cx, cy) => [
      {f: 0, x: cx, y: cy, s: 1.14},
      {f: beat(4.5), x: w / 2, y: h / 2, s: 1.0},
      {f: beat(12), x: w / 2, y: h / 2, s: 1.03, e: ease.soft},
    ],
  },
  short: {
    ...ABSORB.short,
    cam: (w, h) => [
      {f: 0, x: w / 2, y: h / 2, s: 1.06},
      {f: beat(6), x: w / 2, y: h / 2, s: 1.0, e: ease.soft},
    ],
  },
};

// Where each kind of fragment comes from (degrees, y up) and how far out it starts.
const DIRS = [8, 140, 62, 188, -38];
const START_DIST = 1150;
const TRAVEL = beat(2.7);

export const Absorb: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  const {w, h, aspect} = useGeo();
  const plan = PLANS[variant];
  const g = pick(aspect, {
    wide: {cx: 1200, cy: 480, R0: 165, grow: 8, k: 1, line: {left: 140, top: 700, size: 96}},
    tall: {cx: 540, cy: 760, R0: 160, grow: 9, k: 0.95, line: {left: 84, top: 1330, size: 78}},
    square: {cx: 540, cy: 410, R0: 130, grow: 8, k: 0.82, line: {left: 76, top: 760, size: 66}},
  });
  const cam = camera(f, plan.cam(w, h, g.cx, g.cy));

  // Blob growth, colour turn and ripple accumulate per absorption.
  let R = g.R0, swirl = 0, kick = 0, kickAngle = 0;
  const balls: Ball[] = [];
  const arms: Arm[] = [];
  const cards: React.ReactNode[] = [];
  plan.contacts.forEach((cb, i) => {
    const fc = beat(cb);
    const kind = FRAGMENTS[plan.kinds[i]];
    const deg = DIRS[plan.kinds[i]];
    const a = (deg * Math.PI) / 180;
    const dir = {x: Math.cos(a), y: -Math.sin(a)}; // screen (y down)
    const perp = {x: -dir.y, y: dir.x};
    const grown = ramp(f, fc + 20, fc + 70, ease.out);
    R += g.grow * grown;
    swirl += 0.42 * ramp(f, fc - 10, fc + 70, ease.inOut);
    if (f > fc + 30) {
      const dt = f - fc - 30;
      const kk = Math.exp(-dt / 26) * Math.sin((dt / 34) * Math.PI * 2);
      if (Math.abs(kk) > Math.abs(kick)) {
        kick = kk * 0.9;
        kickAngle = a;
      }
    }
    // world-space positions. fc is the frame the fragment is fully inside the arm.
    const Rw = R;
    const reachOut = Rw + (kind.kind === 'screenshot' ? 230 : kind.kind === 'clip' || kind.kind === 'link' ? 250 : 190) * g.k;
    const hold = {x: g.cx + dir.x * reachOut, y: g.cy + dir.y * reachOut};
    const start = {x: g.cx + dir.x * START_DIST, y: g.cy + dir.y * START_DIST};
    // 1. drift in and slow to a stop just outside the blob
    const tIn = ramp(f, fc - TRAVEL, fc - 30, ease.soft);
    // 2. the arm reaches it; 3. it shrinks into the arm's tip; 4. the arm pulls back
    const reachT = ramp(f, fc - 50, fc - 22, ease.inOut);
    const shrink = ramp(f, fc - 26, fc - 2, ease.swallow);
    const retract = ramp(f, fc - 2, fc + 44, ease.inOut);
    const bulge = Math.sin(Math.PI * tIn) * 90 * (i % 2 ? -1 : 1);
    const pos = {x: mix(start.x, hold.x, tIn) + perp.x * bulge, y: mix(start.y, hold.y, tIn) + perp.y * bulge};
    if (f >= fc - TRAVEL && f <= fc) {
      const s = toScreen(cam, w, h, pos.x, pos.y);
      cards.push(
        <div key={i} style={{position: 'absolute', left: s.x, top: s.y, opacity: 1 - ramp(f, fc - 12, fc - 1, ease.in),
          transform: `translate(-50%, -50%) scale(${mix(1, 0.04, shrink) * cam.s}) rotate(${(1 - tIn) * (i % 2 ? 6 : -5)}deg)`,
          filter: `blur(${shrink * 5}px)`}}>
          <FragmentCard kind={kind.kind} k={g.k} caption={`${kind.time} · ${kind.tag}`} captionOpacity={1 - ramp(f, fc - 48, fc - 34, ease.in)} captionSize={aspect === 'tall' ? 28 : undefined} />
        </div>,
      );
    }
    // the arm: a chain of drops that leaves the surface, holds the fragment, and carries it back
    const ext = reachT * (1 - retract);
    if (ext > 0.002) {
      const tipD = mix(Rw * 0.55, reachOut, ext);
      const swell = Math.sin(Math.PI * ramp(f, fc - 24, fc + 16, ease.inOut));
      arms.push({x: g.cx + dir.x * tipD, y: g.cy + dir.y * tipD, base: Rw * 0.2 * mix(0.7, 1, ext), tip: Rw * (0.13 + 0.07 * swell) * mix(0.6, 1, ext)});
    }
  });

  const breath = 1 + 0.018 * Math.sin((f / 60) * Math.PI * 2 * 0.25);
  const sc = (p: {x: number; y: number}) => toScreen(cam, w, h, p.x, p.y);
  const c = sc({x: g.cx, y: g.cy});

  return (
    <AbsoluteFill style={{background: C.deep}}>
      <Blob
        state={{
          cx: c.x, cy: c.y, R: R * breath * cam.s, time: f / 60, wobble: 1, swirl, glow: 0.9,
          kick, kickAngle, k: R * 0.42 * cam.s,
          arms: arms.map((a) => {
            const s = sc(a);
            return {x: s.x, y: s.y, base: a.base * cam.s, tip: a.tip * cam.s};
          }),
          balls: balls.map((b) => {
            const s = sc(b);
            return {x: s.x, y: s.y, r: b.r * cam.s};
          }),
        }}
      />
      {cards}
      <div style={{position: 'absolute', left: g.line.left, top: g.line.top}}>
        <Rise f={f} at={beat(plan.lineAt)} out={plan.lineOut === undefined ? undefined : beat(plan.lineOut)} lines={COPY.seen} size={g.line.size} />
      </div>
    </AbsoluteFill>
  );
};
