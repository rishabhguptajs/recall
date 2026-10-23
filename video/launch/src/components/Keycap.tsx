import React from 'react';
import {FONT} from '../constants';

/** A Mac keyboard key (dark), pressed by `down` (0 up … 1 fully down). Size in px of a 1u key. */
export const Keycap: React.FC<{u: number; width?: number; down: number; glyph?: string; label?: string; glyphPos?: 'tr' | 'center'}> = ({
  u, width = 1, down, glyph, label, glyphPos = 'tr',
}) => {
  const travel = u * 0.1 * down;
  return (
    <div style={{width: u * width, height: u, position: 'relative'}}>
      {/* key well shadow */}
      <div style={{position: 'absolute', inset: 0, borderRadius: u * 0.13, background: '#070807', transform: `translateY(${u * 0.1}px)`}} />
      <div style={{position: 'absolute', inset: 0, borderRadius: u * 0.13, transform: `translateY(${travel}px)`,
        background: down > 0.01 ? `linear-gradient(180deg, rgb(${44 - 10 * down},${46 - 10 * down},${43 - 10 * down}), rgb(${35 - 8 * down},${37 - 8 * down},${34 - 8 * down}))` : 'linear-gradient(180deg, #2c2e2b, #232522)',
        boxShadow: `inset 0 ${u * 0.012}px 0 rgba(255,255,255,0.14), inset 0 -${u * 0.02}px 0 rgba(0,0,0,0.35), 0 ${u * (0.05 - 0.04 * down)}px ${u * (0.12 - 0.08 * down)}px rgba(0,0,0,0.55)`,
        color: '#e9e8e2', fontFamily: FONT.system}}>
        {glyph ? (
          <div style={glyphPos === 'tr'
            ? {position: 'absolute', right: u * 0.13, top: u * 0.1, fontSize: u * 0.28, lineHeight: 1}
            : {position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: u * 0.34}}>
            {glyph}
          </div>
        ) : null}
        {label ? <div style={{position: 'absolute', left: u * 0.13, bottom: u * 0.11, fontSize: u * 0.17, letterSpacing: '0.01em'}}>{label}</div> : null}
      </div>
    </div>
  );
};
