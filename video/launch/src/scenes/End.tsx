import React from 'react';
import {AbsoluteFill, Img, staticFile, useCurrentFrame} from 'remotion';
import {Blob} from '../components/Blob';
import {FadeLine, Rise} from '../components/Type';
import {beat, C, COPY, FONT, SITE} from '../constants';
import {pick, useGeo} from '../lib/geo';
import {END} from '../timing';
import {ease, mix, ramp} from '../lib/motion';

// The liquid slows and settles into the icon's exact shape; the tile forms; then the name, the address, the price.

type Plan = {settle: [number, number]; tile: [number, number]; swap: [number, number]; name: number; url: number; price: number; sub: number};
const PLANS: Record<string, Plan> = END;

/** macOS-style continuous-corner tile (superellipse, n = 5), as in make-icon.swift. */
export function squircle(cx: number, cy: number, size: number) {
  const n = 5, steps = 240, pts: string[] = [];
  for (let i = 0; i <= steps; i++) {
    const t = (i / steps) * Math.PI * 2, c = Math.cos(t), s = Math.sin(t);
    const x = Math.sign(c) * Math.abs(c) ** (2 / n), y = Math.sign(s) * Math.abs(s) ** (2 / n);
    pts.push(`${(cx + (x * size) / 2).toFixed(2)},${(cy + (y * size) / 2).toFixed(2)}`);
  }
  return `M${pts.join('L')}Z`;
}

export const End: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  const {w, h, aspect} = useGeo();
  const p = PLANS[variant];
  const g = pick(aspect, {
    wide: {T: 300, cx: 960, cy: 350, R0: 200, name: {top: 540, size: 150}, url: {top: 735, size: 34}, price: {top: 800, size: 34}, sub: {top: 975, size: 20}},
    tall: {T: 400, cx: 540, cy: 700, R0: 230, name: {top: 960, size: 176}, url: {top: 1200, size: 40}, price: {top: 1275, size: 38}, sub: {top: 1700, size: 27}},
    square: {T: 280, cx: 540, cy: 300, R0: 170, name: {top: 470, size: 130}, url: {top: 650, size: 30}, price: {top: 708, size: 30}, sub: {top: 975, size: 19}},
  });
  const settle = ramp(f, beat(p.settle[0]), beat(p.settle[1]), ease.inOut);
  const tileIn = ramp(f, beat(p.tile[0]), beat(p.tile[1]), ease.out);
  const swap = ramp(f, beat(p.swap[0]), beat(p.swap[1]), ease.inOut);
  const R = mix(g.R0, 0.318 * g.T, settle);
  const blobCy = g.cy + 0.015 * g.T; // the blob sits a little below the tile centre (v = 0.485)
  const tilePath = squircle(g.cx, g.cy, g.T * mix(0.94, 1, tileIn));
  const iconSize = (g.T * 1024) / 824; // icon.png: 824 px tile inside a 1024 px canvas
  const mask = `url("data:image/svg+xml;utf8,${encodeURIComponent(
    `<svg xmlns='http://www.w3.org/2000/svg' width='${w}' height='${h}'><rect width='${w}' height='${h}' fill='white' fill-opacity='${(1 - tileIn).toFixed(3)}'/><path d='${squircle(g.cx, g.cy, g.T)}' fill='white'/></svg>`,
  )}")`;

  return (
    <AbsoluteFill style={{background: C.deep}}>
      <svg width={w} height={h} style={{position: 'absolute', inset: 0, opacity: tileIn}}>
        <defs>
          <linearGradient id="tile" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0" stopColor={C.tileTop} />
            <stop offset="1" stopColor={C.tileBottom} />
          </linearGradient>
        </defs>
        <path d={tilePath} fill="url(#tile)" />
      </svg>
      <div style={{position: 'absolute', inset: 0, opacity: 1 - swap, WebkitMaskImage: mask, maskImage: mask, WebkitMaskSize: '100% 100%'}}>
        <Blob state={{cx: g.cx, cy: blobCy, R, time: 60 + f / 60, wobble: 1 - settle, icon: settle, swirl: mix(1.2, 0, settle), glow: mix(0.9, 1, settle)}} />
      </div>
      <svg width={w} height={h} style={{position: 'absolute', inset: 0, opacity: tileIn}}>
        <path d={squircle(g.cx, g.cy, g.T * mix(0.94, 1, tileIn))} fill="none" stroke="white" strokeOpacity={0.08} strokeWidth={(3 * g.T) / 824} />
      </svg>
      <Img src={staticFile('icon/icon.png')} style={{position: 'absolute', left: g.cx - iconSize / 2, top: g.cy - iconSize / 2, width: iconSize, height: iconSize, opacity: swap}} />
      <div style={{position: 'absolute', left: 0, right: 0, top: g.name.top}}>
        <Rise f={f} at={beat(p.name)} lines={[COPY.name]} size={g.name.size} align="center" stagger={0} dur={40} />
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: g.url.top, display: 'flex', justifyContent: 'center'}}>
        <FadeLine f={f} at={beat(p.url)} style={{fontFamily: FONT.mono, fontSize: g.url.size, color: C.mineral, letterSpacing: '0.02em'}}>{SITE}</FadeLine>
      </div>
      <div style={{position: 'absolute', left: 60, right: 60, top: g.price.top, display: 'flex', justifyContent: 'center', textAlign: 'center'}}>
        <FadeLine f={f} at={beat(p.price)} style={{fontFamily: FONT.sans, fontSize: g.price.size, color: C.muted, letterSpacing: '-0.02em'}}>{COPY.priceLine()}</FadeLine>
      </div>
      <div style={{position: 'absolute', left: 0, right: 0, top: g.sub.top, display: 'flex', justifyContent: 'center'}}>
        <FadeLine f={f} at={beat(p.sub)} style={{fontFamily: FONT.mono, fontSize: g.sub.size * 1.15, color: C.muted, letterSpacing: '0.04em', opacity: 0.85}}>
          {COPY.priceSub()}
        </FadeLine>
      </div>
    </AbsoluteFill>
  );
};
