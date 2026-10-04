#!/usr/bin/env bash
# Build several annotated views, stack them in ONE Excalidraw scene, and upload it.
#
#   shoot-all.sh <scene-name> <view> [view ...]
#
# Each view is built with NO_UPLOAD=1 (shoot-annotated.sh), then combine.py stacks the
# frames vertically (x = 0, 150 px gap) into .scratch/<branch-shelf>/annotated/all.excalidraw.
#
# Env: SCENE_ID=<id> replaces that scene in place; otherwise a new scene is created in
#      COLLECTION (default: generated). NO_UPLOAD=1 stops after combining.
#      Other env (SCALE, YAS_DEMO_*) passes through to shoot-annotated.sh.
set -euo pipefail

[ $# -ge 2 ] || { echo "usage: shoot-all.sh <scene-name> <view> [view ...]" >&2; exit 2; }

name=$1; shift
here=$(cd "$(dirname "$0")" && pwd)
yas_root=$(git rev-parse --show-toplevel)
shelf=$(git -C "$yas_root" branch --show-current | tr / -)
out_dir="$yas_root/.scratch/$shelf/annotated"

files=()
for view in "$@"; do
  NO_UPLOAD=1 "$here/shoot-annotated.sh" "$view"
  files+=("$out_dir/$view.excalidraw")
done

python3 "$here/combine.py" "$out_dir/all.excalidraw" "${files[@]}"

[ -z "${NO_UPLOAD:-}" ] || { echo "NO_UPLOAD set: $out_dir/all.excalidraw"; exit 0; }

rc=0
if [ -n "${SCENE_ID:-}" ]; then
  log=$(python3 "$here/upload_scene.py" "$out_dir/all.excalidraw" --scene-id "$SCENE_ID") || rc=$?
else
  log=$(python3 "$here/upload_scene.py" "$out_dir/all.excalidraw" \
    --collection "${COLLECTION:-generated}" --name "$name") || rc=$?
fi
echo "$log"
[ "$rc" -eq 0 ] || { echo "upload check failed (exit $rc)" >&2; exit "$rc"; }
id=$(printf '%s\n' "$log" | sed -n 's/^scene id: *//p' | head -1)
[ -n "$id" ] && echo "scene url: https://app.excalidraw.com/s/1BFmCncTPVB/$id"
