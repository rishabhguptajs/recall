#!/usr/bin/env bash
# Contact sheets from the final renders in out/ (one frame per second plus each scene's key moments).
#   bash scripts/contact-sheets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
sheet() { # input, label, every-n-seconds, cols, thumb-width
  local tmp; tmp="$(mktemp -d)"
  ffmpeg -loglevel error -i "$1" -vf "fps=1/$3" "$tmp/$2-%04d.png"
  # name frames by their frame number at 60 fps so the sheet labels show time
  for f in "$tmp"/*.png; do
    n="${f##*-}"; n="${n%.png}"; mv "$f" "$tmp/$2-$(printf '%04d' $(( (10#$n - 1) * $3 * 60 ))).png"
  done
  uv run -q --with pillow python scripts/contact_sheet.py "$tmp" "out/contact-sheet-$2.jpg" "$4" "$5"
  rm -r "$tmp"
}
sheet out/Recall-Launch-16x9-1080p60.mp4 16x9 2 6 400
sheet out/Recall-Launch-16x9-Short-1080p60.mp4 16x9-short 1 6 400
sheet out/Recall-Punch-16x9-1080p60.mp4 punch 1 6 400
sheet out/Recall-Launch-9x16-1080x1920-60.mp4 9x16 1 10 200
sheet out/Recall-Launch-1x1-1080-60.mp4 1x1 2 8 240
