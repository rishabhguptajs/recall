import React from 'react';
import {C, FONT, FragmentKind} from '../constants';
import {ClipArt, LinkArt, PaperArt, ScreenshotArt} from './Art';

/** One fragment of the day, as it drifts toward the blob. `k` scales it. */
export const FragmentCard: React.FC<{kind: FragmentKind; k: number; caption: string; captionOpacity: number; captionSize?: number}> = ({kind, k, caption, captionOpacity, captionSize}) => {
  const card = (() => {
    switch (kind) {
      case 'screenshot':
        return (
          <div style={{borderRadius: 6 * k, overflow: 'hidden', boxShadow: `0 ${18 * k}px ${50 * k}px rgba(0,0,0,0.5), 0 0 0 1px rgba(255,255,255,0.08)`}}>
            <ScreenshotArt kind="billing" width={400 * k} />
          </div>
        );
      case 'pdf':
      case 'note':
        return (
          <div style={{borderRadius: 3 * k, overflow: 'hidden', boxShadow: `0 ${18 * k}px ${50 * k}px rgba(0,0,0,0.5)`}}>
            <PaperArt kind={kind === 'pdf' ? 'pdf' : 'note'} width={(kind === 'pdf' ? 230 : 210) * k} />
          </div>
        );
      case 'clip':
        return <ClipArt size={30 * k} />;
      case 'link':
        return <LinkArt size={24 * k} />;
    }
  })();
  return (
    <div style={{display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 16 * k}}>
      {card}
      <div style={{fontFamily: FONT.mono, fontSize: captionSize ?? 19 * k, letterSpacing: '0.08em', textTransform: 'uppercase', color: C.muted, opacity: captionOpacity, whiteSpace: 'nowrap'}}>
        {caption}
      </div>
    </div>
  );
};
