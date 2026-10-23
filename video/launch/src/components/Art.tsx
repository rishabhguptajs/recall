import React from 'react';
import {C, FONT, FRAGMENT_TEXT as T} from '../constants';

// Fictional screenshots, drawn at 1440×900 and scaled. Light-mode web pages, the kind of thing people screenshot.
const SHOT_W = 1440, SHOT_H = 900;

export const ScreenshotArt: React.FC<{kind: 'billing' | 'embassy'; width: number}> = ({kind, width}) => {
  const s = width / SHOT_W;
  return (
    <div style={{width, height: SHOT_H * s, overflow: 'hidden', position: 'relative', background: '#ffffff'}}>
      <div style={{width: SHOT_W, height: SHOT_H, transform: `scale(${s})`, transformOrigin: '0 0', fontFamily: FONT.system, color: '#1d1d1f'}}>
        {kind === 'billing' ? <Billing /> : <Embassy />}
      </div>
    </div>
  );
};

const Billing: React.FC = () => (
  <div style={{padding: '70px 90px'}}>
    <div style={{display: 'flex', alignItems: 'center', gap: 16, color: '#6e6e73', fontSize: 26}}>
      <div style={{width: 34, height: 34, borderRadius: 9, background: '#2b2d31'}} />
      {T.screenshotCrumb}
    </div>
    <div style={{fontSize: 84, fontWeight: 700, letterSpacing: -2, marginTop: 50}}>{T.screenshotTitle}</div>
    <div style={{fontSize: 30, color: '#6e6e73', marginTop: 14}}>{T.screenshotSub}</div>
    <div style={{display: 'flex', gap: 34, marginTop: 64}}>
      {T.screenshotPlans.map((p, i) => (
        <div key={p.name} style={{flex: 1, border: i === 1 ? '4px solid #2b2d31' : '2px solid #d2d2d7', borderRadius: 22, padding: '36px 34px', height: 330}}>
          <div style={{fontSize: 32, fontWeight: 600}}>{p.name}</div>
          <div style={{fontSize: 96, fontWeight: 700, letterSpacing: -3, marginTop: 26}}>{p.price}</div>
          <div style={{fontSize: 26, color: '#6e6e73', marginTop: 8}}>{p.note}</div>
          <div style={{height: 14, width: '70%', background: '#e8e8ed', borderRadius: 7, marginTop: 40}} />
          <div style={{height: 14, width: '50%', background: '#e8e8ed', borderRadius: 7, marginTop: 16}} />
        </div>
      ))}
    </div>
  </div>
);

const Embassy: React.FC = () => (
  <div style={{padding: '80px 110px'}}>
    <div style={{height: 18, width: 260, background: '#d2d2d7', borderRadius: 9}} />
    <div style={{fontSize: 36, color: '#6e6e73', marginTop: 60}}>{T.embassyKicker}</div>
    <div style={{fontSize: 80, fontWeight: 700, letterSpacing: -2, marginTop: 12}}>{T.embassyTitle}</div>
    <div style={{marginTop: 50, border: '2px solid #d2d2d7', borderRadius: 22, padding: 44, width: 900}}>
      {T.embassyLines.map((l) => (
        <div key={l} style={{fontSize: 34, marginBottom: 22, display: 'flex', gap: 18, alignItems: 'center'}}>
          <div style={{width: 14, height: 14, borderRadius: 7, background: '#2b2d31'}} />
          {l}
        </div>
      ))}
    </div>
  </div>
);

/** A page of a document: PDF or Markdown note. */
export const PaperArt: React.FC<{kind: 'pdf' | 'note'; width: number}> = ({kind, width}) => {
  const s = width / 460;
  const pdf = kind === 'pdf';
  return (
    <div style={{width, height: 600 * s, overflow: 'hidden', background: C.paper, position: 'relative'}}>
      <div style={{width: 460, height: 600, transform: `scale(${s})`, transformOrigin: '0 0', padding: '48px 44px', boxSizing: 'border-box',
        fontFamily: pdf ? FONT.system : FONT.mono, color: '#2a2b28'}}>
        {pdf ? (
          <>
            <div style={{fontSize: 13, letterSpacing: 2, color: '#8a8d85', textTransform: 'uppercase'}}>{T.pdfKicker}</div>
            <div style={{fontSize: 32, fontWeight: 700, lineHeight: 1.1, marginTop: 14, letterSpacing: -0.5}}>{T.pdfTitle}</div>
            <div style={{fontSize: 18, fontWeight: 600, marginTop: 30}}>{T.pdfLines[0]}</div>
            {T.pdfLines.slice(1).map((l) => (
              <div key={l} style={{fontSize: 16, marginTop: 14, display: 'flex', gap: 12}}>
                <span style={{width: 14, height: 14, border: '2px solid #2a2b28', borderRadius: 3, flexShrink: 0, marginTop: 2}} />
                {l}
              </div>
            ))}
            {[0.9, 0.8, 0.95, 0.6].map((w, i) => (
              <div key={i} style={{height: 8, width: `${w * 100}%`, background: '#dddcd4', borderRadius: 4, marginTop: i ? 12 : 34}} />
            ))}
          </>
        ) : (
          <>
            <div style={{fontSize: 26, fontWeight: 600}}>{T.noteTitle}</div>
            {T.noteLines.map((l) => (
              <div key={l} style={{fontSize: 17, marginTop: 18, color: '#3c3e39'}}>{l}</div>
            ))}
          </>
        )}
      </div>
    </div>
  );
};

/** Copied text, shown with the selection it was copied from. */
export const ClipArt: React.FC<{size: number}> = ({size}) => (
  <div style={{fontFamily: FONT.system, fontSize: size, color: C.mineral, lineHeight: 1.35, whiteSpace: 'nowrap'}}>
    <span style={{background: 'rgba(10,132,255,0.42)', boxShadow: `0 0 0 ${size * 0.12}px rgba(10,132,255,0.42)`, borderRadius: 2, boxDecorationBreak: 'clone', WebkitBoxDecorationBreak: 'clone'}}>
      {T.clip}
    </span>
  </div>
);

/** A copied link, as an address field. */
export const LinkArt: React.FC<{size: number}> = ({size}) => (
  <div style={{display: 'inline-flex', alignItems: 'center', gap: size * 0.6, padding: `${size * 0.55}px ${size * 0.9}px`, borderRadius: size * 0.6,
    background: '#2a2c28', border: '1px solid rgba(255,255,255,0.1)', fontFamily: FONT.system, fontSize: size, color: C.mineral, whiteSpace: 'nowrap'}}>
    <LinkGlyph size={size * 1.1} color={C.muted} />
    {T.link.replace('https://', '')}
  </div>
);

export const LinkGlyph: React.FC<{size: number; color: string; stroke?: number}> = ({size, color, stroke = 2}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={stroke} strokeLinecap="round">
    <path d="M10.6 13.4a4 4 0 0 0 5.66 0l3.53-3.53a4 4 0 0 0-5.66-5.66l-1.06 1.06" />
    <path d="M13.4 10.6a4 4 0 0 0-5.66 0l-3.53 3.53a4 4 0 0 0 5.66 5.66l1.06-1.06" />
  </svg>
);

export const ClipboardGlyph: React.FC<{size: number; color: string}> = ({size, color}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={1.7} strokeLinejoin="round">
    <rect x="5" y="4.5" width="12" height="16" rx="2.2" />
    <rect x="8.5" y="3" width="5" height="3" rx="1" fill={color} />
    <path d="M9 2.8v0M19 8.5v10a3 3 0 0 1-3 3H9" />
  </svg>
);

export const MagnifierGlyph: React.FC<{size: number; color: string}> = ({size, color}) => (
  <svg width={size} height={size} viewBox="0 0 20 20" fill="none" stroke={color} strokeWidth={2} strokeLinecap="round">
    <circle cx="8.3" cy="8.3" r="6" />
    <path d="M12.8 12.8 18 18" />
  </svg>
);

/** macOS-style document icon (white page, folded corner, type label). */
export const DocIcon: React.FC<{label: string; size: number}> = ({label, size}) => (
  <svg width={size} height={size} viewBox="0 0 36 36">
    <defs>
      <linearGradient id={`pg-${label}`} x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stopColor="#ffffff" />
        <stop offset="1" stopColor="#ececec" />
      </linearGradient>
    </defs>
    <path d="M7 2.5h15.5L30 10v22.2a1.3 1.3 0 0 1-1.3 1.3H7.3A1.3 1.3 0 0 1 6 32.2V3.8A1.3 1.3 0 0 1 7.3 2.5Z" fill={`url(#pg-${label})`} stroke="rgba(0,0,0,0.25)" strokeWidth="0.5" />
    <path d="M22.5 2.5V8.7a1.3 1.3 0 0 0 1.3 1.3H30" fill="#d9d9d9" />
    {[13, 15.5, 18, 20.5].map((y) => (
      <rect key={y} x="9.5" y={y} width={y === 20.5 ? 11 : 17} height="1" rx="0.5" fill="#c9c9c9" />
    ))}
    <text x="18" y="29.5" textAnchor="middle" fontFamily="system-ui" fontWeight="700" fontSize="6.4" fill={label === 'PDF' ? '#d63b2f' : '#6b6b6b'}>{label}</text>
  </svg>
);
