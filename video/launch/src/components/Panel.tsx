import React from 'react';
import {C, FONT, PANEL, Result, Source} from '../constants';
import {ClipboardGlyph, DocIcon, LinkGlyph, MagnifierGlyph, ScreenshotArt} from './Art';

// The search panel, rebuilt from UI/SearchView.swift and UI/SearchPanel.swift (dark appearance).
// Sizes are SwiftUI points; the component is drawn at 1 pt = 1 px and scaled by its parent.

const badgeColor: Record<Source, string> = {file: C.sysBlue, screenshot: C.sysPurple, clipboard: C.sysOrange};
const badgeLabel: Record<Source, string> = {file: 'File', screenshot: 'Screenshot', clipboard: 'Clipboard'};

/** Highlight.attributed: **word** becomes bold, primary colour. */
const Snippet: React.FC<{text: string}> = ({text}) => (
  <>
    {text.split(/(\*\*[^*]+\*\*)/g).map((part, i) =>
      part.startsWith('**') ? (
        <span key={i} style={{fontWeight: 700, color: C.label}}>{part.slice(2, -2)}</span>
      ) : (
        <span key={i}>{part}</span>
      ),
    )}
  </>
);

const RowIcon: React.FC<{r: Result}> = ({r}) => {
  if (r.icon === 'pdf') return <DocIcon label="PDF" size={36} />;
  if (r.icon === 'md') return <DocIcon label="MD" size={36} />;
  if (r.icon === 'shot')
    return (
      <div style={{width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
        <ScreenshotArt kind={r.shot ?? 'billing'} width={36} />
      </div>
    );
  return (
    <div style={{width: 36, height: 36, display: 'flex', alignItems: 'center', justifyContent: 'center'}}>
      {r.icon === 'link' ? <LinkGlyph size={30} color={C.label} stroke={1.8} /> : <ClipboardGlyph size={32} color={C.label} />}
    </div>
  );
};

export const ResultRow: React.FC<{r: Result; selected: boolean; flash?: number}> = ({r, selected, flash = 0}) => (
  <div style={{display: 'flex', alignItems: 'flex-start', gap: 12, padding: '7px 10px', borderRadius: 8,
    background: selected ? `rgba(10,132,255,${0.22 + flash * 0.25})` : 'transparent'}}>
    <div style={{width: 36, height: 36, borderRadius: 4, overflow: 'hidden', flexShrink: 0}}>
      <RowIcon r={r} />
    </div>
    <div style={{display: 'flex', flexDirection: 'column', gap: 3, minWidth: 0, flex: 1}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 6}}>
        <span style={{fontSize: 14, fontWeight: 600, color: C.label, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis'}}>{r.title}</span>
        <span style={{fontSize: 10, fontWeight: 500, padding: '1px 6px', borderRadius: 99, color: badgeColor[r.source],
          background: `${badgeColor[r.source]}2e`, flexShrink: 0}}>{badgeLabel[r.source]}</span>
        <span style={{flex: 1, minWidth: 8}} />
        <span style={{fontSize: 11, color: C.secondary, flexShrink: 0}}>{r.date}</span>
      </div>
      <div style={{fontSize: 12, color: C.secondary, lineHeight: '15px', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical', overflow: 'hidden'}}>
        <Snippet text={r.snippet} />
      </div>
    </div>
  </div>
);

export type PanelProps = {
  query: string;
  caret: boolean;
  results: Result[] | null;
  selection?: number;
  /** 0..1 pulse on the selected row (⌘C / ↩ feedback). */
  flash?: number;
  /** Which part of the hint string to emphasise, e.g. '⌘C copy'. */
  hint?: string | null;
};

export const Panel: React.FC<PanelProps> = ({query, caret, results, selection = 0, flash = 0, hint = null}) => {
  const hints = PANEL.hints.split(' · ');
  return (
    <div style={{width: PANEL.width, height: PANEL.height, borderRadius: PANEL.radius, position: 'relative', overflow: 'hidden',
      fontFamily: FONT.system, color: C.label, WebkitFontSmoothing: 'antialiased',
      background: 'rgba(36,36,38,0.62)', // the blurred backdrop is drawn underneath by the scene (see PanelScene)
      boxShadow: 'inset 0 0 0 1px rgba(255,255,255,0.13), inset 0 1px 0 rgba(255,255,255,0.08)'}}>
      {/* search field */}
      <div style={{display: 'flex', alignItems: 'center', gap: 10, padding: '16px 18px 10px'}}>
        <MagnifierGlyph size={21} color={C.secondary} />
        <div style={{fontSize: 24, lineHeight: '29px', height: 29, whiteSpace: 'pre', display: 'flex', alignItems: 'center'}}>
          {query ? <span>{query}</span> : null}
          <span style={{display: 'inline-block', width: 2, height: 27, marginLeft: 1, background: caret ? C.label : 'transparent'}} />
          {!query ? <span style={{color: C.tertiary, marginLeft: -3}}>{PANEL.placeholder}</span> : null}
        </div>
      </div>
      {/* filter tabs: typed /f /s /c filter the results, the capsule stays on All */}
      <div style={{display: 'flex', alignItems: 'center', gap: 4, padding: '0 14px 8px'}}>
        {PANEL.tabs.map((t, i) => (
          <span key={t} style={{fontSize: 12, fontWeight: i === 0 ? 600 : 400, padding: '4px 10px', borderRadius: 99,
            background: i === 0 ? 'rgba(10,132,255,0.22)' : 'transparent'}}>{t}</span>
        ))}
        <span style={{flex: 1}} />
        <span style={{fontSize: 10, color: C.tertiary, whiteSpace: 'pre'}}>
          {hints.map((h, i) => (
            <React.Fragment key={h}>
              {i ? ' · ' : ''}
              <span style={hint === h ? {color: C.label, fontWeight: 600} : undefined}>{h}</span>
            </React.Fragment>
          ))}
        </span>
      </div>
      <div style={{height: 1, background: 'rgba(255,255,255,0.1)'}} />
      {results && results.length ? (
        <div style={{display: 'flex', flexDirection: 'column', gap: 2, padding: 6}}>
          {results.map((r, i) => (
            <ResultRow key={r.title} r={r} selected={i === selection} flash={i === selection ? flash : 0} />
          ))}
        </div>
      ) : (
        <div style={{position: 'absolute', left: 0, right: 0, top: 77, bottom: 0, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: C.secondary}}>
          {query ? '' : PANEL.emptyHint}
        </div>
      )}
    </div>
  );
};

/** Outer window shadow (NSPanel hasShadow), drawn outside the clipped panel. */
export const panelShadow = '0 24px 80px rgba(0,0,0,0.55), 0 4px 18px rgba(0,0,0,0.35), 0 0 0 0.5px rgba(0,0,0,0.8)';
