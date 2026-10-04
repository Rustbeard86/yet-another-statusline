#!/usr/bin/env bash
# Usage: gif.sh <out.gif> <scene.excalidraw>...   (env: BG=#121212 PAD=40 SCALE=2 DELAY=250)
set -euo pipefail
out=$1; shift
here=$(cd "$(dirname "$0")" && pwd)
bg=${BG:-#121212}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
frames=()
for scene in "$@"; do
  png="$tmp/$(basename "${scene%.excalidraw}").png"
  python3 "$here/render.py" "$scene" "$png" --bg "$bg" --pad "${PAD:-40}" --scale "${SCALE:-2}"
  frames+=("$png")
done
dims=$(magick identify -format '%w %h\n' "${frames[@]}" | sort -n | awk '{if($1>w)w=$1;if($2>h)h=$2}END{print w"x"h}')
magick -delay "${DELAY:-250}" -loop 0 "${frames[@]}" \
  -background "$bg" -gravity northwest -extent "$dims" -layers optimize "$out"
magick identify "$out" | awk '{print $1,$2,$3}'
