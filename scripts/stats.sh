#!/bin/zsh
# Prints Recall's numbers from the license Worker: downloads per version, update checks per app
# version, and Pro activations. All counts are anonymous. Needs keys/stats-token.txt.
set -euo pipefail
cd "$(dirname "$0")/.."
curl -fsS -H "Authorization: Bearer $(cat keys/stats-token.txt)" \
  https://recall-license.rishabhgupta4523.workers.dev/v1/stats | python3 scripts/stats.py
