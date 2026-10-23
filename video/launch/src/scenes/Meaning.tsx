import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {ScreenshotArt} from '../components/Art';
import {Blob} from '../components/Blob';
import {Eyebrow, FadeLine, Rise} from '../components/Type';
import {beat, C, COPY, FONT} from '../constants';
import {camera, ease, mix, ramp, toScreen} from '../lib/motion';

// The second query typed "pricing table" and found a screenshot that only says "Plans & Billing".
// A drop of the blob carries one to the other. (Master only: 16:9.)

const SHOT = {x: 1010, y: 230, w: 800};
const BOX = {x0: 78, y0: 150, x1: 700, y1: 262}; // around the heading, in 1440×900 screenshot units

export const Meaning: React.FC = () => {
  const f = useCurrentFrame();
  const w = 1920, h = 1080;
  const cam = camera(f, [{f: 0, x: w / 2, y: h / 2, s: 1.0}]); // still: this is a reading scene
  const k = SHOT.w / 1440;
  const box = {x0: SHOT.x + BOX.x0 * k, y0: SHOT.y + BOX.y0 * k, x1: SHOT.x + BOX.x1 * k, y1: SHOT.y + BOX.y1 * k};
  const shotIn = ramp(f, beat(0.6), beat(0.6) + 50, ease.soft);
  const boxDraw = ramp(f, beat(1.6), beat(1.6) + 34, ease.inOut);
  // connector from under the typed phrase to the left edge of the box
  const a = {x: 420, y: 352}, b = {x: box.x0 - 14, y: (box.y0 + box.y1) / 2};
  const c1 = {x: a.x + 10, y: a.y + 150}, c2 = {x: b.x - 280, y: b.y};
  const bez = (t: number) => {
    const u = 1 - t;
    return {
      x: u * u * u * a.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * b.x,
      y: u * u * u * a.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * b.y,
    };
  };
  const travel = ramp(f, beat(1.2), beat(2.6), ease.inOut);
  const draw = ramp(f, beat(1.2), beat(2.6), ease.inOut);
  const drop = toScreen(cam, w, h, bez(travel).x, bez(travel).y);
  const dropR = 22 * Math.sin(Math.PI * Math.min(1, ramp(f, beat(1.0), beat(2.9), ease.inOut))) ** 0.6;
  const path = `M${a.x},${a.y} C${c1.x},${c1.y} ${c2.x},${c2.y} ${b.x},${b.y}`;
  const perim = 2 * (box.x1 - box.x0 + box.y1 - box.y0);

  return (
    <AbsoluteFill style={{background: C.deep}}>
      <div style={{position: 'absolute', left: 0, top: 0, width: w, height: h, transformOrigin: '0 0',
        transform: `translate(${w / 2 - cam.x * cam.s}px, ${h / 2 - cam.y * cam.s}px) scale(${cam.s})`}}>
        <div style={{position: 'absolute', left: 140, top: 170}}>
          <Eyebrow f={f} at={0} text={COPY.youTyped} />
        </div>
        <div style={{position: 'absolute', left: 134, top: 222}}>
          <Rise f={f} at={4} lines={[`“${COPY.meaningTyped}”`]} size={104} />
        </div>
        <div style={{position: 'absolute', left: SHOT.x, top: SHOT.y - 52}}>
          <Eyebrow f={f} at={beat(1.9)} text={COPY.itFound} />
        </div>
        <div style={{position: 'absolute', left: SHOT.x, top: SHOT.y, opacity: shotIn, transform: `translateX(${(1 - shotIn) * 40}px)`,
          borderRadius: 8, overflow: 'hidden', boxShadow: '0 30px 80px rgba(0,0,0,0.55), 0 0 0 1px rgba(255,255,255,0.08)'}}>
          <ScreenshotArt kind="billing" width={SHOT.w} />
        </div>
        <svg width={w} height={h} style={{position: 'absolute', left: 0, top: 0, overflow: 'visible'}}>
          <circle cx={a.x} cy={a.y} r={5} fill={C.green} opacity={ramp(f, beat(1.0), beat(1.0) + 12, ease.out)} />
          <path d={path} fill="none" stroke={C.green} strokeWidth={2} strokeDasharray="1600" strokeDashoffset={1600 * (1 - draw)} opacity={0.9} />
          <rect x={box.x0} y={box.y0} width={box.x1 - box.x0} height={box.y1 - box.y0} rx={10} fill="none" stroke={C.green} strokeWidth={3}
            strokeDasharray={perim} strokeDashoffset={perim * (1 - boxDraw)} />
        </svg>
        <div style={{position: 'absolute', left: 140, top: 690}}>
          <Rise f={f} at={beat(3.1)} lines={COPY.meaningLine} size={84} />
        </div>
        <div style={{position: 'absolute', left: 140, top: 900}}>
          <FadeLine f={f} at={beat(4.6)} style={{fontFamily: FONT.mono, fontSize: 25, letterSpacing: '0.02em', color: C.muted}}>
            {COPY.meaningSub}
          </FadeLine>
        </div>
      </div>
      {dropR > 0.5 ? (
        <Blob state={{cx: drop.x, cy: drop.y, R: dropR * cam.s, time: f / 60, wobble: 1, swirl: mix(0.5, 2.5, travel), glow: 0.8}} />
      ) : null}
    </AbsoluteFill>
  );
};
