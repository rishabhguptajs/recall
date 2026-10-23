import {Easing, interpolate, spring} from 'remotion';
import {FPS} from '../constants';

// Curves. Nothing in the film moves on a linear ramp.
export const ease = {
  out: Easing.bezier(0.16, 1, 0.3, 1), // fast start, long settle: arrivals
  inOut: Easing.bezier(0.65, 0, 0.35, 1), // camera moves
  in: Easing.bezier(0.55, 0, 0.9, 0.35), // departures
  soft: Easing.bezier(0.33, 0, 0.2, 1), // gentle arrivals for type
  swallow: Easing.bezier(0.7, 0, 0.84, 0.2), // accelerating pull into the blob
};

/** 0→1 between frames a and b with an easing curve, clamped. */
export const ramp = (f: number, a: number, b: number, e: (t: number) => number = ease.out) =>
  interpolate(f, [a, b], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: e});

export const mix = (a: number, b: number, t: number) => a + (b - a) * t;
export const clamp01 = (t: number) => Math.min(1, Math.max(0, t));

/** Damped spring from frame `from`, 0→1 with overshoot. Deterministic (frame-based). */
export const springAt = (f: number, from: number, config: {damping?: number; stiffness?: number; mass?: number} = {}) =>
  f < from ? 0 : spring({frame: f - from, fps: FPS, config: {damping: 14, stiffness: 120, mass: 1, ...config}});

export {rand} from '../timing';

export type CamKey = {f: number; x: number; y: number; s: number; e?: (t: number) => number};
export type Cam = {x: number; y: number; s: number};

/** Camera as keyframes: (x, y) is the point at frame centre, s the zoom. Each segment uses the easing of its end key. */
export function camera(f: number, keys: CamKey[]): Cam {
  if (f <= keys[0].f) return keys[0];
  for (let i = 1; i < keys.length; i++) {
    const a = keys[i - 1], b = keys[i];
    if (f <= b.f) {
      const t = ramp(f, a.f, b.f, b.e ?? ease.inOut);
      return {x: mix(a.x, b.x, t), y: mix(a.y, b.y, t), s: mix(a.s, b.s, t)};
    }
  }
  return keys[keys.length - 1];
}

/** Maps a world point to screen through the camera (frame w×h). */
export const toScreen = (cam: Cam, w: number, h: number, x: number, y: number) => ({
  x: (x - cam.x) * cam.s + w / 2,
  y: (y - cam.y) * cam.s + h / 2,
});

export const camStyle = (cam: Cam, w: number, h: number): React.CSSProperties => ({
  position: 'absolute',
  left: 0,
  top: 0,
  width: w,
  height: h,
  transformOrigin: '0 0',
  transform: `translate(${w / 2 - cam.x * cam.s}px, ${h / 2 - cam.y * cam.s}px) scale(${cam.s})`,
});
