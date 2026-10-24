import React, {useLayoutEffect, useRef} from 'react';
import {useVideoConfig} from 'remotion';
import {FRAG, MAX_ARMS, MAX_BALLS, VERT} from './blobShader';

export type Ball = {x: number; y: number; r: number};
/** A tapered arm from the blob's centre to (x, y). */
export type Arm = {x: number; y: number; base: number; tip: number};

export type BlobState = {
  cx: number;
  cy: number;
  /** Icon radius in px (0.318 of the tile). */
  R: number;
  /** Seconds; drives the liquid motion. Derive it from the frame, never from wall time. */
  time: number;
  wobble?: number;
  icon?: number;
  swirl?: number;
  glow?: number;
  alpha?: number;
  /** Smooth-min radius in px: higher = more viscous bridges between drops. */
  k?: number;
  balls?: Ball[];
  arms?: Arm[];
  /** Lower-edge shade strength, 1 = icon. Lower it on light backgrounds. */
  shade?: number;
  dim?: number;
  kick?: number;
  kickAngle?: number;
  /** Walls the liquid presses against: [x0, y0, x1, y1] in px. */
  clip?: [number, number, number, number];
};

type GLState = {gl: WebGL2RenderingContext; prog: WebGLProgram; loc: Record<string, WebGLUniformLocation | null>};

function compile(gl: WebGL2RenderingContext, type: number, src: string) {
  const s = gl.createShader(type)!;
  gl.shaderSource(s, src);
  gl.compileShader(s);
  if (!gl.getShaderParameter(s, gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(s) ?? 'shader error');
  return s;
}

function setup(canvas: HTMLCanvasElement): GLState {
  const gl = canvas.getContext('webgl2', {premultipliedAlpha: true, preserveDrawingBuffer: true, antialias: false});
  if (!gl) throw new Error('WebGL2 unavailable: render with --gl=angle');
  const prog = gl.createProgram()!;
  gl.attachShader(prog, compile(gl, gl.VERTEX_SHADER, VERT));
  gl.attachShader(prog, compile(gl, gl.FRAGMENT_SHADER, FRAG));
  gl.linkProgram(prog);
  if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(prog) ?? 'link error');
  gl.useProgram(prog);
  const buf = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buf);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW);
  const aPos = gl.getAttribLocation(prog, 'aPos');
  gl.enableVertexAttribArray(aPos);
  gl.vertexAttribPointer(aPos, 2, gl.FLOAT, false, 0, 0);
  const names = ['uRes', 'uDpr', 'uCenter', 'uR', 'uTime', 'uWobble', 'uIcon', 'uSwirl', 'uGlow', 'uAlpha', 'uK',
    'uBalls', 'uBallCount', 'uArms', 'uArmCount', 'uDim', 'uShade', 'uKick', 'uKickAng', 'uClip'];
  const loc: GLState['loc'] = {};
  for (const n of names) loc[n] = gl.getUniformLocation(prog, n);
  return {gl, prog, loc};
}

/** Full-frame canvas that draws the blob. Sized in composition px, rendered at device resolution. */
export const Blob: React.FC<{state: BlobState; style?: React.CSSProperties}> = ({state, style}) => {
  const {width, height} = useVideoConfig();
  const ref = useRef<HTMLCanvasElement>(null);
  const glRef = useRef<GLState | null>(null);
  const dpr = typeof window === 'undefined' ? 1 : window.devicePixelRatio || 1;

  useLayoutEffect(() => {
    const canvas = ref.current!;
    if (!glRef.current) glRef.current = setup(canvas);
    const {gl, loc} = glRef.current;
    gl.viewport(0, 0, canvas.width, canvas.height);
    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    const balls = (state.balls ?? []).slice(0, MAX_BALLS);
    const flat = new Float32Array(MAX_BALLS * 4);
    balls.forEach((b, i) => flat.set([b.x, b.y, b.r, 0], i * 4));
    const arms = (state.arms ?? []).slice(0, MAX_ARMS);
    const armFlat = new Float32Array(MAX_ARMS * 4);
    arms.forEach((a, i) => armFlat.set([a.x, a.y, a.base, a.tip], i * 4));
    gl.uniform2f(loc.uRes, width, height);
    gl.uniform1f(loc.uDpr, dpr);
    gl.uniform2f(loc.uCenter, state.cx, state.cy);
    gl.uniform1f(loc.uR, state.R);
    gl.uniform1f(loc.uTime, state.time);
    gl.uniform1f(loc.uWobble, state.wobble ?? 1);
    gl.uniform1f(loc.uIcon, state.icon ?? 0);
    gl.uniform1f(loc.uSwirl, state.swirl ?? 0);
    gl.uniform1f(loc.uGlow, state.glow ?? 1);
    gl.uniform1f(loc.uAlpha, state.alpha ?? 1);
    gl.uniform1f(loc.uK, state.k ?? state.R * 0.35);
    gl.uniform4fv(loc.uBalls, flat);
    gl.uniform1i(loc.uBallCount, balls.length);
    gl.uniform4fv(loc.uArms, armFlat);
    gl.uniform1i(loc.uArmCount, arms.length);
    gl.uniform1f(loc.uDim, state.dim ?? 0);
    gl.uniform1f(loc.uShade, state.shade ?? 1);
    gl.uniform1f(loc.uKick, state.kick ?? 0);
    gl.uniform1f(loc.uKickAng, state.kickAngle ?? 0);
    const cl = state.clip ?? [0, 0, 0, 0];
    gl.uniform4f(loc.uClip, cl[0], cl[1], cl[2], cl[3]);
    gl.drawArrays(gl.TRIANGLES, 0, 3);
  });

  return (
    <canvas
      ref={ref}
      width={Math.round(width * dpr)}
      height={Math.round(height * dpr)}
      style={{position: 'absolute', inset: 0, width, height, ...style}}
    />
  );
};
