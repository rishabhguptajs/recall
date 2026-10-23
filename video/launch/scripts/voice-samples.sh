#!/usr/bin/env bash
# Voice-over SAMPLE versions of every cut (the finals stay music-only). Needs the finals' scores in out/.
#   bash scripts/voice-samples.sh                 # voice: first installed Premium/Enhanced English voice
#   VOICE="Ava (Premium)" bash scripts/voice-samples.sh
set -euo pipefail
cd "$(dirname "$0")/.."
V=out/.video
loudnorm() {
  local stats args
  stats=$(ffmpeg -hide_banner -i "$1" -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 | sed -n '/^{/,/^}/p')
  args=$(python3 -c 'import json,sys; s=json.loads(sys.stdin.read()); print("measured_I=%s:measured_TP=%s:measured_LRA=%s:measured_thresh=%s:offset=%s" % (s["input_i"],s["input_tp"],s["input_lra"],s["input_thresh"],s["target_offset"]))' <<<"$stats")
  ffmpeg -y -loglevel error -i "$1" -af "loudnorm=I=-16:TP=-1.5:LRA=11:linear=true:$args" -ar 48000 "$2"
}
for pair in "Master 16x9-1080p60" "Short 16x9-short-1080p60" "Vertical 9x16-1080x1920-60" "Square 1x1-1080-60"; do
  set -- $pair
  node --experimental-strip-types scripts/voice.mjs "$1" "out/score-$1.wav" "$V/vo-$1.raw.wav" 2>/dev/null
  loudnorm "$V/vo-$1.raw.wav" "$V/vo-$1.wav"
  ffmpeg -y -loglevel error -i "$V/$2.mp4" -i "$V/vo-$1.wav" -map 0:v -map 1:a -c:v copy -c:a aac -b:a 256k -shortest "out/VO-SAMPLE-$2.mp4"
done
ls -lh out/VO-SAMPLE-*
