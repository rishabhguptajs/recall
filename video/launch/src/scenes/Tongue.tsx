import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Blob} from '../components/Blob';
import {Keycap} from '../components/Keycap';
import {Eyebrow, FadeLine} from '../components/Type';
import {beat, C, COPY, FONT} from '../constants';
import {Aspect, pick, useGeo} from '../lib/geo';
import {TONGUE} from '../timing';
import {ease, mix, rand, ramp} from '../lib/motion';

// Tip of the tongue: a sentence that won't hold still. ⌥ goes down; Space (next scene) freezes it.

export const STAGE_PLANS = TONGUE;

const LINES: Record<Aspect, number[][]> = {wide: [[0, 1, 2], [3, 4, 5]], square: [[0, 1, 2], [3, 4, 5]], tall: [[0, 1], [2, 3], [4, 5]]};

export const stageGeo = (aspect: Aspect) =>
  pick(aspect, {
    wide: {size: 132, top: 300, cap: {top: 640, size: 50}, keys: {u: 118, top: 800}, blob: {x: 960, y: 520, R: 330}, pad: 140},
    tall: {size: 112, top: 560, cap: {top: 1040, size: 48}, keys: {u: 112, top: 1430}, blob: {x: 540, y: 900, R: 330}, pad: 84},
    square: {size: 92, top: 260, cap: {top: 520, size: 42}, keys: {u: 96, top: 780}, blob: {x: 540, y: 520, R: 270}, pad: 76},
  });

/**
 * Everything on screen during the tip-of-the-tongue moment.
 * f: frames since the scene began. frozenAt: frame at which time stops (the Space press).
 * spaceDown / keysGone are driven by the panel scene.
 */
export const TongueStage: React.FC<{f: number; variant: string; frozenAt?: number; spaceDown?: number; keysGone?: number; captionGone?: boolean}> = ({
  f, variant, frozenAt, spaceDown = 0, keysGone = 0,
}) => {
  const {aspect} = useGeo();
  const p = STAGE_PLANS[variant];
  const g = stageGeo(aspect);
  const tf = frozenAt === undefined ? f : Math.min(f, frozenAt); // the clock that stops
  const t = tf / 60;
  let wi = 0;
  const optDown = ramp(f, beat(p.optAt), beat(p.optAt) + 5, ease.out);
  const keysIn = ramp(f, beat(p.keysAt), beat(p.keysAt) + 40, ease.out);
  return (
    <AbsoluteFill style={{background: C.deep}}>
      <Blob
        style={{filter: 'blur(46px)'}}
        state={{cx: g.blob.x, cy: g.blob.y, R: g.blob.R, time: t + 40, wobble: 1, swirl: 2.1, glow: 0.5, alpha: 0.5, dim: 0.35}}
      />
      <div style={{position: 'absolute', left: g.pad, top: aspect === 'tall' ? 380 : g.pad * 0.85}}>
        <Eyebrow f={f} at={beat(0.2)} text={COPY.later} size={aspect === 'tall' ? 30 : 22} />
      </div>
      <div style={{position: 'absolute', left: g.pad, right: g.pad, top: g.top, fontFamily: FONT.sans, fontSize: g.size, fontWeight: 500,
        letterSpacing: '-0.05em', wordSpacing: '0.14em', lineHeight: 1.08, color: C.mineral}}>
        {LINES[aspect].map((line, li) => (
          <div key={li} style={{whiteSpace: 'nowrap'}}>
            {line.map((idx) => {
              const k = wi++;
              const word = COPY.vague[idx];
              const appear = ramp(f, beat(p.wordsAt + k * p.wordGap), beat(p.wordsAt + k * p.wordGap) + 40, ease.soft);
              // each word breathes in and out of focus on its own period; frozen with the clock
              const ph = rand(idx + 3) * 6.28, sp = 0.55 + rand(idx + 11) * 0.5;
              const focus = 0.5 + 0.5 * Math.sin(t * sp * 2.2 + ph);
              const blur = mix(16, 1.5 + 9 * (1 - focus) ** 1.6, appear);
              const dx = Math.sin(t * sp * 1.3 + ph * 2) * 14;
              const dy = Math.cos(t * sp * 0.9 + ph) * 6;
              const ls = -0.05 + 0.03 * Math.sin(t * sp + ph);
              return (
                <span key={idx} style={{display: 'inline-block', marginRight: '0.28em', opacity: appear * mix(0.5, 1, focus),
                  filter: `blur(${blur}px)`, transform: `translate(${dx}px, ${dy}px)`, letterSpacing: `${ls}em`}}>
                  {word}
                </span>
              );
            })}
          </div>
        ))}
      </div>
      {p.captionAt !== undefined ? (
        <div style={{position: 'absolute', left: g.pad, top: g.cap.top}}>
          <FadeLine f={f} at={beat(p.captionAt)} out={p.captionOut === undefined ? undefined : beat(p.captionOut)}
            style={{fontFamily: FONT.sans, fontSize: g.cap.size, color: C.muted, letterSpacing: '-0.02em'}}>
            {COPY.rememberLike}
          </FadeLine>
        </div>
      ) : null}
      <div style={{position: 'absolute', left: 0, right: 0, top: g.keys.top, display: 'flex', justifyContent: 'center', gap: g.keys.u * 0.14,
        opacity: keysIn * (1 - keysGone), transform: `translateY(${(1 - keysIn) * 50 + keysGone * 30}px)`}}>
        <Keycap u={g.keys.u} width={1.3} down={optDown} glyph="⌥" label={COPY.optionKey} />
        <Keycap u={g.keys.u} width={5.2} down={spaceDown} />
      </div>
    </AbsoluteFill>
  );
};

export const Tongue: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  return <TongueStage f={f} variant={variant} />;
};
