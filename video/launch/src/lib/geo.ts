import {useVideoConfig} from 'remotion';

export type Aspect = 'wide' | 'tall' | 'square';

/** Frame size and aspect. Scenes recompose per aspect rather than cropping. */
export function useGeo() {
  const {width: w, height: h} = useVideoConfig();
  const aspect: Aspect = w > h * 1.2 ? 'wide' : h > w * 1.2 ? 'tall' : 'square';
  return {w, h, aspect};
}

export const pick = <T,>(aspect: Aspect, v: Record<Aspect, T>): T => v[aspect];
