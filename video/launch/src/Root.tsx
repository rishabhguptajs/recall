import React from 'react';
import {Composition} from 'remotion';
import {beat, FPS, MASTER, SceneSpec, SHORT, SQUARE, totalBeats, VERTICAL} from './constants';
import {Film} from './Film';
import {Punch, punchFrames} from './Punch';

const film = (id: string, timeline: SceneSpec[], width: number, height: number) => (
  <Composition id={id} component={Film} defaultProps={{timeline}} durationInFrames={beat(totalBeats(timeline))} fps={FPS} width={width} height={height} />
);

export const Root: React.FC = () => (
  <>
    {film('Master', MASTER, 1920, 1080)}
    {film('Short', SHORT, 1920, 1080)}
    {film('Vertical', VERTICAL, 1080, 1920)}
    {film('Square', SQUARE, 1080, 1080)}
    <Composition id="Punch" component={Punch} durationInFrames={punchFrames()} fps={FPS} width={1920} height={1080} />
  </>
);
