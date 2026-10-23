#!/usr/bin/env bash
# Renders every deliverable into out/.
#   bash scripts/render.sh            # everything: picture, score, final files
#   bash scripts/render.sh video      # picture only (silent, into out/.video/)
#   bash scripts/render.sh audio      # score only, then re-mux onto the existing picture (no video render)
# Needs: node 22+, ffmpeg, python3. First run: npm install.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=out
V="$OUT/.video"
mkdir -p "$OUT" "$V"
WHAT="${1:-all}"
REMOTION="npx remotion render src/index.ts --gl=angle --concurrency=${CONCURRENCY:-8} --log=error"
H264="-c:v libx264 -preset slow -pix_fmt yuv420p -movflags +faststart -an"

video() {
  # 16:9 master: one render at 3840×2160 (authored at 1920×1080, scale 2), ProRes 422 HQ; H.264 is transcoded from it.
  $REMOTION Master "$V/16x9-2160p60.mov" --scale=2 --codec=prores --prores-profile=hq
  ffmpeg -y -loglevel error -i "$V/16x9-2160p60.mov" $H264 -crf 14 -profile:v high -level 5.2 "$V/16x9-2160p60.mp4"
  ffmpeg -y -loglevel error -i "$V/16x9-2160p60.mov" -vf scale=1920:1080:flags=lanczos $H264 -crf 16 "$V/16x9-1080p60.mp4"
  # 16:9 short (22.8 s), also 4K
  $REMOTION Short "$V/.short.mov" --scale=2 --codec=prores --prores-profile=hq
  ffmpeg -y -loglevel error -i "$V/.short.mov" $H264 -crf 14 -profile:v high -level 5.2 "$V/16x9-short-2160p60.mp4"
  ffmpeg -y -loglevel error -i "$V/.short.mov" -vf scale=1920:1080:flags=lanczos $H264 -crf 16 "$V/16x9-short-1080p60.mp4"
  rm -f "$V/.short.mov"
  # PUNCH: the fast kinetic-type cut (18 s), also 4K
  $REMOTION Punch "$V/.punch.mov" --scale=2 --codec=prores --prores-profile=hq
  ffmpeg -y -loglevel error -i "$V/.punch.mov" $H264 -crf 14 -profile:v high -level 5.2 "$V/16x9-punch-2160p60.mp4"
  ffmpeg -y -loglevel error -i "$V/.punch.mov" -vf scale=1920:1080:flags=lanczos $H264 -crf 16 "$V/16x9-punch-1080p60.mp4"
  rm -f "$V/.punch.mov"
  # cutdowns
  for pair in "Vertical 9x16-1080x1920-60" "Square 1x1-1080-60"; do
    set -- $pair
    $REMOTION "$1" "$V/.$2.mov" --codec=prores --prores-profile=hq
    ffmpeg -y -loglevel error -i "$V/.$2.mov" $H264 -crf 15 "$V/$2.mp4"
    rm -f "$V/.$2.mov"
  done
}

# Two-pass loudness normalisation (linear, no pumping) to -16 LUFS integrated, -1.5 dBTP.
loudnorm() { # in.wav out.wav
  local stats
  stats=$(ffmpeg -hide_banner -i "$1" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
  local args
  args=$(python3 -c 'import json,sys; s=json.loads(sys.stdin.read()); print("measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s" % (s["input_i"],s["input_tp"],s["input_lra"],s["input_thresh"],s["target_offset"]))' <<<"$stats")
  ffmpeg -y -loglevel error -i "$1" -af "loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:$args" -ar 48000 "$2"
}

audio() {
  for comp in Master Short Vertical Square Punch; do
    node --experimental-strip-types scripts/score.mjs "$comp" "$V/score-$comp.raw.wav" 2>/dev/null
    loudnorm "$V/score-$comp.raw.wav" "$OUT/score-$comp.wav"
    [ "$comp" = Punch ] || node --experimental-strip-types scripts/temp-track.mjs "$comp" "$OUT/click-$comp.wav" 2>/dev/null
  done
}

mux() { # video, score, out, [pcm]
  if [ "${4:-}" = pcm ]; then
    ffmpeg -y -loglevel error -i "$1" -i "$2" -map 0:v -map 1:a -c:v copy -c:a pcm_s24le -shortest "$3"
  else
    ffmpeg -y -loglevel error -i "$1" -i "$2" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "$3"
  fi
}

final() {
  mux "$V/16x9-2160p60.mov" "$OUT/score-Master.wav" "$OUT/Recall-Launch-16x9-2160p60-ProRes.mov" pcm
  mux "$V/16x9-2160p60.mp4" "$OUT/score-Master.wav" "$OUT/Recall-Launch-16x9-2160p60.mp4"
  mux "$V/16x9-1080p60.mp4" "$OUT/score-Master.wav" "$OUT/Recall-Launch-16x9-1080p60.mp4"
  mux "$V/16x9-short-2160p60.mp4" "$OUT/score-Short.wav" "$OUT/Recall-Launch-16x9-Short-2160p60.mp4"
  mux "$V/16x9-short-1080p60.mp4" "$OUT/score-Short.wav" "$OUT/Recall-Launch-16x9-Short-1080p60.mp4"
  mux "$V/9x16-1080x1920-60.mp4" "$OUT/score-Vertical.wav" "$OUT/Recall-Launch-9x16-1080x1920-60.mp4"
  mux "$V/1x1-1080-60.mp4" "$OUT/score-Square.wav" "$OUT/Recall-Launch-1x1-1080-60.mp4"
  mux "$V/16x9-punch-2160p60.mp4" "$OUT/score-Punch.wav" "$OUT/Recall-Punch-16x9-2160p60.mp4"
  mux "$V/16x9-punch-1080p60.mp4" "$OUT/score-Punch.wav" "$OUT/Recall-Punch-16x9-1080p60.mp4"
}

case "$WHAT" in
  all) video && audio && final ;;
  video) video ;;
  audio) audio && final ;;
  *) echo "usage: render.sh [all|video|audio]"; exit 1 ;;
esac
ls -lh "$OUT"
