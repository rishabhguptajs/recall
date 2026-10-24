import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Blob} from '../components/Blob';
import {Eyebrow} from '../components/Type';
import {beat, C, COPY, FONT} from '../constants';
import {pick, useGeo} from '../lib/geo';
import {NUMBERS} from '../timing';
import {ease, ramp} from '../lib/motion';

// Measured on a real Mac: the site's editorial register, on mineral paper. Four numbers land on the beat.

const GREEN_ON_LIGHT = '#3f7150'; // the site's docs green, readable on mineral

const Roll: React.FC<{f: number; at: number; text: string}> = ({f, at, text}) => (
  <>
    {text.split('').map((ch, i) => {
      const t = ramp(f, at + i * 3, at + i * 3 + 30, ease.out);
      return (
        <span key={i} style={{display: 'inline-block', overflow: 'hidden', verticalAlign: 'top', paddingBottom: '0.1em', marginBottom: '-0.1em'}}>
          <span style={{display: 'inline-block', transform: `translateY(${(1 - t) * 105}%)`}}>{ch}</span>
        </span>
      );
    })}
  </>
);

type Plan = {eyebrow: number; rows: number[]};
const PLANS: Record<string, Plan> = NUMBERS;

export const Numbers: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  const {aspect} = useGeo();
  const p = PLANS[variant];
  const g = pick(aspect, {
    wide: {x0: 760, x1: 1790, top: 150, rowH: 196, val: 124, unit: 52, label: 32, valW: 350, eyebrow: {x: 140, y: 150}, blob: {x: 430, y: 600, R: 150}},
    square: {x0: 70, x1: 1010, top: 210, rowH: 196, val: 100, unit: 42, label: 29, valW: 330, eyebrow: {x: 70, y: 100}, blob: null},
    tall: {x0: 70, x1: 1010, top: 520, rowH: 240, val: 110, unit: 46, label: 26, valW: 420, eyebrow: {x: 70, y: 400}, blob: null},
  });
  // the blob pulses as each number lands
  let kick = 0;
  p.rows.forEach((rb) => {
    const dt = f - beat(rb);
    if (dt > 0) kick += Math.exp(-dt / 20) * Math.sin((dt / 28) * Math.PI * 2) * 0.7;
  });
  return (
    <AbsoluteFill style={{background: C.mineral, color: C.ink}}>
      {g.blob ? (
        <Blob state={{cx: g.blob.x, cy: g.blob.y, R: g.blob.R, time: f / 60 + 50, wobble: 1, swirl: 3.1, glow: 0.3, shade: 0.25, kick, kickAngle: 0.4}} />
      ) : null}
      <div style={{position: 'absolute', left: g.eyebrow.x, top: g.eyebrow.y}}>
        <Eyebrow f={f} at={beat(p.eyebrow)} text={COPY.measuredEyebrow} color={C.mutedOnLight} />
      </div>
      {COPY.numbers.map((n, i) => {
        const at = beat(p.rows[i]);
        const line = ramp(f, at - 10, at + 40, ease.inOut);
        const fade = ramp(f, at, at + 26, ease.soft);
        const y = g.top + i * g.rowH;
        return (
          <div key={n.n} style={{position: 'absolute', left: g.x0, top: y, width: g.x1 - g.x0, height: g.rowH}}>
            <div style={{position: 'absolute', left: 0, top: 0, height: 1.5, width: `${line * 100}%`, background: '#bdbcb4'}} />
            <div style={{position: 'absolute', left: 0, top: g.rowH * 0.24, width: 54, height: 54, borderRadius: 99, border: `1.5px solid ${GREEN_ON_LIGHT}`,
              display: 'grid', placeItems: 'center', fontFamily: FONT.mono, fontSize: 18, color: GREEN_ON_LIGHT, opacity: fade}}>{n.n}</div>
            <div style={{position: 'absolute', left: 92, top: g.rowH * 0.12, fontFamily: FONT.sans, fontWeight: 500, fontSize: g.val, letterSpacing: '-0.055em',
              lineHeight: 1, whiteSpace: 'nowrap'}}>
              <Roll f={f} at={at} text={n.value} />
              <span style={{fontSize: g.unit, letterSpacing: '-0.03em', marginLeft: '0.18em', opacity: fade}}>{n.unit}</span>
            </div>
            <div style={{position: 'absolute', left: 92 + g.valW, right: 0, top: g.rowH * 0.12 + g.val * 0.5, fontFamily: FONT.sans, fontSize: g.label,
              color: C.mutedOnLight, letterSpacing: '-0.01em', opacity: fade, transform: `translateY(${(1 - fade) * 10}px)`}}>
              {n.label}
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};
