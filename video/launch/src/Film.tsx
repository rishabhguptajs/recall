import React from 'react';
import {AbsoluteFill, Sequence} from 'remotion';
import {beat, C, SceneId, SceneSpec} from './constants';
import {loadFonts} from './lib/fonts';
import {Absorb} from './scenes/Absorb';
import {End} from './scenes/End';
import {Meaning} from './scenes/Meaning';
import {Numbers} from './scenes/Numbers';
import {PanelScene} from './scenes/PanelScene';
import {Privacy} from './scenes/Privacy';
import {Tongue} from './scenes/Tongue';

loadFonts();

const SCENES: Record<SceneId, React.FC<{variant?: string; len: number}>> = {
  absorb: Absorb,
  tongue: Tongue,
  panel: PanelScene,
  meaning: Meaning,
  privacy: Privacy,
  numbers: Numbers,
  end: End,
};

/** Plays a timeline: each scene in its own Sequence, hard cuts on the beat grid. */
export const Film: React.FC<{timeline: SceneSpec[]}> = ({timeline}) => (
  <AbsoluteFill style={{background: C.deep}}>
    {timeline.map((s) => {
      const Scene = SCENES[s.id];
      return (
        <Sequence key={s.id} from={beat(s.at)} durationInFrames={beat(s.len)} name={s.id}>
          <Scene variant={s.variant} len={beat(s.len)} />
        </Sequence>
      );
    })}
  </AbsoluteFill>
);
