import React from 'react';
import {C, FONT} from '../constants';
import {ease, mix, ramp} from '../lib/motion';

/**
 * Headline that rises word by word out of a mask, then leaves upward.
 * f is the local frame; `at` the frame the first word starts; `out` the frame it starts to leave.
 */
export const Rise: React.FC<{
  f: number;
  at: number;
  out?: number;
  lines: string[];
  size: number;
  color?: string;
  weight?: number;
  align?: 'left' | 'center' | 'right';
  stagger?: number;
  dur?: number;
  style?: React.CSSProperties;
  lineHeight?: number;
}> = ({f, at, out, lines, size, color = C.mineral, weight = 500, align = 'left', stagger = 4, dur = 34, style, lineHeight = 1.02}) => {
  let i = 0;
  return (
    <div style={{fontFamily: FONT.sans, fontSize: size, fontWeight: weight, letterSpacing: '-0.055em', lineHeight, color, textAlign: align, ...style}}>
      {lines.map((line, li) => (
        <div key={li} style={{display: 'block', whiteSpace: 'nowrap'}}>
          {line.split(' ').map((w, wi) => {
            const k = i++;
            const tIn = ramp(f, at + k * stagger, at + k * stagger + dur, ease.out);
            const tOut = out === undefined ? 0 : ramp(f, out + k * 2, out + k * 2 + 22, ease.in);
            const y = (1 - tIn) * 105 - tOut * 105;
            return (
              <span key={wi} style={{display: 'inline-block', overflow: 'hidden', verticalAlign: 'top', paddingBottom: '0.12em', marginBottom: '-0.12em'}}>
                <span style={{display: 'inline-block', transform: `translateY(${y}%)`}}>
                  {w}
                  {wi < line.split(' ').length - 1 ? ' ' : ''}
                </span>
              </span>
            );
          })}
        </div>
      ))}
    </div>
  );
};

/** Mono eyebrow with the site's green dot. Fades and tracks in. */
export const Eyebrow: React.FC<{f: number; at: number; out?: number; text: string; size?: number; color?: string; dot?: boolean; style?: React.CSSProperties}> = ({
  f, at, out, text, size = 22, color = C.muted, dot = true, style,
}) => {
  const t = ramp(f, at, at + 30, ease.soft);
  const o = out === undefined ? 0 : ramp(f, out, out + 18, ease.in);
  return (
    <div style={{fontFamily: FONT.mono, fontSize: size, letterSpacing: `${mix(0.3, 0.12, t)}em`, textTransform: 'uppercase', color,
      opacity: t * (1 - o), display: 'flex', alignItems: 'center', gap: size * 0.55, whiteSpace: 'nowrap', ...style}}>
      {dot ? <i style={{width: size * 0.3, height: size * 0.3, borderRadius: 99, background: C.green, display: 'inline-block'}} /> : null}
      {text}
    </div>
  );
};

/** Plain fade-up line (secondary copy). */
export const FadeLine: React.FC<{f: number; at: number; out?: number; children: React.ReactNode; style?: React.CSSProperties; dy?: number}> = ({
  f, at, out, children, style, dy = 14,
}) => {
  const t = ramp(f, at, at + 30, ease.soft);
  const o = out === undefined ? 0 : ramp(f, out, out + 18, ease.in);
  const base = typeof style?.opacity === 'number' ? style.opacity : 1;
  return <div style={{...style, opacity: base * t * (1 - o), transform: `translateY(${(1 - t) * dy}px)`}}>{children}</div>;
};

/** The ⌘ ⌥ ↩ glyphs are set in the system font: the brand fonts don't draw them. */
export const Sym: React.FC<{children: React.ReactNode}> = ({children}) => <span style={{fontFamily: FONT.system}}>{children}</span>;
