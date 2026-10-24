import React from 'react';
import {AbsoluteFill, useCurrentFrame} from 'remotion';
import {Blob} from '../components/Blob';
import {Keycap} from '../components/Keycap';
import {Panel, panelShadow} from '../components/Panel';
import {beat, C, COPY, FONT, PANEL, QUERIES} from '../constants';
import {pick, useGeo} from '../lib/geo';
import {camera, CamKey, ease, mix, ramp, toScreen} from '../lib/motion';
import {keySeed, keystrokes, PANEL_T, PanelQuery} from '../timing';
import {STAGE_PLANS, TongueStage} from './Tongue';

// ⌥Space: the panel opens over the frozen moment. Vague queries, exact results, ⌘C closes it.

type Q = PanelQuery;
type Plan = {stage: string; stageLen: number; queries: Q[]; copyAt?: number; cam: (P: (x: number, y: number) => {x: number; y: number}, w: number, h: number) => CamKey[]};


const PLANS: Record<string, Plan> = {
  full: {
    ...PANEL_T.full,
    cam: (P, w, h) => [
      {f: 0, x: w / 2, y: h / 2, s: 1},
      {f: beat(4.6), x: w / 2, y: h / 2, s: 1},
      {f: beat(6.0), ...P(270, 122), s: 1.34},
      {f: beat(8.2), ...P(270, 122), s: 1.34},
      {f: beat(9.2), x: w / 2, y: h / 2, s: 1},
      {f: beat(12.0), x: w / 2, y: h / 2, s: 1},
      {f: beat(13.0), ...P(360, 128), s: 1.2},
      {f: beat(15.0), ...P(360, 128), s: 1.2},
      {f: beat(15.8), x: w / 2, y: h / 2, s: 1},
    ],
  },
  two: {
    ...PANEL_T.two,
    cam: (P, w, h) => [
      {f: 0, x: w / 2, y: h / 2, s: 1},
      {f: beat(4.3), x: w / 2, y: h / 2, s: 1},
      {f: beat(5.5), ...P(250, 122), s: 1.3},
      {f: beat(6.6), ...P(250, 122), s: 1.3},
      {f: beat(7.4), x: w / 2, y: h / 2, s: 1},
      {f: beat(10.2), x: w / 2, y: h / 2, s: 1},
      {f: beat(11.5), ...P(330, 128), s: 1.15},
    ],
  },
  one: {
    ...PANEL_T.one,
    cam: (P, w, h) => [
      {f: 0, x: w / 2, y: h / 2, s: 1},
      {f: beat(4.1), x: w / 2, y: h / 2, s: 1},
      // 16:9 keeps the whole row (title to date) in frame; 9:16 pushes onto the title
      {f: beat(5.4), ...(w > h ? P(360, 124) : P(230, 124)), s: w > h ? 1.28 : 1.36},
      {f: beat(8), ...(w > h ? P(360, 124) : P(230, 124)), s: w > h ? 1.28 : 1.36},
    ],
  },
};


export const PanelScene: React.FC<{variant?: string}> = ({variant = 'full'}) => {
  const f = useCurrentFrame();
  const {w, h, aspect} = useGeo();
  const plan = PLANS[variant];
  const g = pick(aspect, {
    wide: {cx: 960, cy: 530, ps: 1.55, blob: {x: 1500, y: 870, R: 210}, keyU: 62, msSize: 14},
    tall: {cx: 540, cy: 880, ps: 1.36, blob: {x: 760, y: 1330, R: 200}, keyU: 70, msSize: 22},
    square: {cx: 540, cy: 540, ps: 1.3, blob: {x: 850, y: 830, R: 170}, keyU: 56, msSize: 17},
  });
  const pw = PANEL.width * g.ps, ph = PANEL.height * g.ps;
  const px0 = g.cx - pw / 2, py0 = g.cy - ph / 2;
  const P = (x: number, y: number) => ({x: px0 + x * g.ps, y: py0 + y * g.ps});
  const cam = camera(f, plan.cam(P, w, h));

  // ⌥ is already down from the previous scene; Space goes down now, and time stops.
  const spaceDown = ramp(f, 0, 5, ease.out) * (1 - ramp(f, 26, 34, ease.out));
  const keysGone = ramp(f, 30, 58, ease.in);
  const open = ramp(f, 3, 11, ease.out);
  const stageF = beat(plan.stageLen) + f;
  const frozenAt = beat(plan.stageLen) + 3;

  // query state
  let text = '', results = null as (typeof QUERIES)[number]['results'] | null, selected = false, resultIdx = -1, lastResultsFrame = -999;
  plan.queries.forEach((qq, i) => {
    const q = QUERIES[qq.q];
    const rf = beat(qq.results);
    const ks = keystrokes(q.text, rf, keySeed(i));
    if (qq.select !== undefined && f >= beat(qq.select) && f < ks[0]) selected = true;
    if (qq.select !== undefined ? f >= beat(qq.select) : true) {
      const n = ks.filter((k) => f >= k).length;
      if (n > 0 || qq.select === undefined) text = q.text.slice(0, n);
    }
    if (f >= rf) {
      results = q.results;
      resultIdx = qq.q;
      lastResultsFrame = rf;
    }
  });
  // caret blinks (NSTextView: ~0.5 s on/off), solid while typing
  const typingRecently = plan.queries.some((qq, i) => {
    const ks = keystrokes(QUERIES[qq.q].text, beat(qq.results), keySeed(i));
    return f >= ks[0] - 6 && f <= ks[ks.length - 1] + 20;
  });
  const caret = typingRecently || Math.floor(f / 32) % 2 === 0;

  const copyF = plan.copyAt === undefined ? Infinity : beat(plan.copyAt);
  const flash = f >= copyF ? Math.exp(-(f - copyF) / 10) : 0;
  const copyKeys = plan.copyAt === undefined ? 0 : ramp(f, copyF - 30, copyF - 6, ease.out);
  const copyDown = plan.copyAt === undefined ? 0 : ramp(f, copyF - 2, copyF + 3, ease.out);

  // the blob behind the glass condenses as the panel opens and pulses when results land
  const condense = ramp(f, 0, beat(2.5), ease.soft);
  const dt = f - lastResultsFrame;
  const kick = dt >= 0 && dt < 200 ? Math.exp(-dt / 24) * Math.sin((dt / 30) * Math.PI * 2) * 0.8 : 0;
  const b = toScreen(cam, w, h, g.blob.x, g.blob.y);
  const memoryFade = 1 - ramp(f, beat(plan.queries[0].results), beat(plan.queries[0].results) + 50, ease.inOut);

  const panelPos = toScreen(cam, w, h, px0, py0);
  const ms = resultIdx >= 0 ? QUERIES[resultIdx].ms : null;
  const msIn = ramp(f, lastResultsFrame, lastResultsFrame + 14, ease.out);

  const scale = g.ps * cam.s * mix(0.985, 1, open);
  // What is behind the panel. Drawn twice: as the scene, and blurred inside the panel's shape as its material.
  // (CSS backdrop-filter is not deterministic across Remotion's parallel tabs, so the material is built by hand.)
  const backdrop = (
    <>
      <AbsoluteFill style={{opacity: memoryFade}}>
        <TongueStage f={stageF} variant={plan.stage} frozenAt={frozenAt} spaceDown={spaceDown} keysGone={keysGone} />
      </AbsoluteFill>
      <Blob state={{cx: b.x, cy: b.y, R: g.blob.R * cam.s * mix(0.55, 1, condense), time: f / 60 + 12, wobble: 1, swirl: 2.1, glow: 0.9,
        alpha: condense, kick, kickAngle: 2.2}} />
    </>
  );

  return (
    <AbsoluteFill style={{background: C.deep}}>
      {backdrop}
      <div style={{position: 'absolute', left: panelPos.x, top: panelPos.y, width: PANEL.width * scale, height: PANEL.height * scale,
        borderRadius: PANEL.radius * scale, overflow: 'hidden', opacity: open, boxShadow: panelShadow, background: C.deep}}>
        <div style={{position: 'absolute', left: -panelPos.x, top: -panelPos.y, width: w, height: h, filter: `blur(${28 * scale}px) saturate(1.7)`}}>
          {backdrop}
        </div>
      </div>
      <div style={{position: 'absolute', left: panelPos.x, top: panelPos.y, transformOrigin: '0 0',
        transform: `scale(${scale})`, opacity: open}}>
        <div style={{borderRadius: PANEL.radius}}>
          <Panel query={text} caret={caret && !selected} results={results} flash={flash}
            hint={f >= copyF - 4 ? '⌘C copy' : null} selection={0} />
        </div>
        {selected ? (
          <div style={{position: 'absolute', left: 49, top: 16, height: 29, padding: '0 1px', background: 'rgba(10,132,255,0.45)',
            fontFamily: FONT.system, fontSize: 24, lineHeight: '29px', color: 'transparent', whiteSpace: 'pre'}}>{text}</div>
        ) : null}
        {ms !== null ? (
          <div style={{position: 'absolute', left: 4, top: PANEL.height + 14, fontFamily: FONT.mono, fontSize: g.msSize, letterSpacing: '0.08em',
            color: C.muted, opacity: msIn, textTransform: 'uppercase', whiteSpace: 'nowrap'}}>
            {COPY.searchedIn} <span style={{color: C.green}}>{ms} ms</span>
          </div>
        ) : null}
      </div>
      {plan.copyAt !== undefined ? (
        <div style={{position: 'absolute', left: 0, right: 0, top: h - g.keyU - (aspect === 'wide' ? 34 : 120), display: 'flex', justifyContent: 'center',
          gap: g.keyU * 0.14, opacity: copyKeys, transform: `translateY(${(1 - copyKeys) * 30}px)`}}>
          <Keycap u={g.keyU} width={1.25} down={copyDown} glyph="⌘" label={COPY.commandKey} />
          <Keycap u={g.keyU} down={copyDown} glyph="C" glyphPos="center" />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

export const PANEL_PLANS = PLANS;
export const stagePlanFor = (v: string) => STAGE_PLANS[PLANS[v].stage];
