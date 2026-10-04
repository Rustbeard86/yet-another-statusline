#!/usr/bin/env python3
'''Stack several single-frame .excalidraw scenes into one scene. Stdlib only.

  combine.py <out.excalidraw> <in1.excalidraw> <in2.excalidraw> ...

Each input holds one frame. Inputs are placed in order: the frame top-left goes to
x = 0, y = running offset, and the offset advances by frame height + GAP. Freedraw
points are relative to the element x/y, so only x/y are translated. `files` are
merged by fileId, `index` values are re-assigned so they increase across the scene,
and duplicate element ids abort the run. appState and source come from the first input.
'''
from __future__ import annotations

import json
import sys
from pathlib import Path

GAP    = 150
DIGITS = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
BASE   = len(DIGITS)

JSONDict = dict[str, object]


def frame_of(elements: list[JSONDict], path: str) -> JSONDict:
    'The single frame of a scene'
    frames = [el for el in elements if el.get('type') == 'frame']
    if len(frames) != 1:
        raise SystemExit(f'{path}: expected exactly one frame, found {len(frames)}')
    return frames[0]


def fractional_index(n: int) -> str:
    'Excalidraw fractional index with a 2-digit base-62 integer part: b00, b01, ...'
    if n >= BASE ** 2:
        raise SystemExit(f'too many elements for index scheme: {n}')
    return f'b{DIGITS[n // BASE]}{DIGITS[n % BASE]}'


def combine(paths: list[str]) -> JSONDict:
    'Merge the scenes at `paths` into one stacked scene'
    elements: list[JSONDict] = []
    files: dict[str, object] = {}
    seen: set[str] = set()
    first: JSONDict = {}
    offset = 0.0

    for path in paths:
        scene = json.loads(Path(path).read_text())
        first = first or scene
        scene_els = scene['elements']
        frame = frame_of(scene_els, path)
        dx, dy = -float(frame['x']), offset - float(frame['y'])
        for el in scene_els:
            if el['id'] in seen:
                raise SystemExit(f'{path}: duplicate element id {el["id"]}')
            seen.add(el['id'])
            el['x'] += dx
            el['y'] += dy
            elements.append(el)
        files.update(scene.get('files', {}))
        print(f'{path}: frame {frame.get("name")!r} at y={offset:g}, {len(scene_els)} elements')
        offset += float(frame['height']) + GAP

    for n, el in enumerate(elements):
        el['index'] = fractional_index(n)
    return {
        'type':     'excalidraw',
        'version':  first.get('version', 2),
        'source':   first.get('source', 'https://app.excalidraw.com'),
        'elements': elements,
        'appState': first.get('appState', {}),
        'files':    files,
    }


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print('usage: combine.py <out.excalidraw> <in.excalidraw>...', file=sys.stderr)
        return 2
    scene = combine(argv[2:])
    Path(argv[1]).write_text(json.dumps(scene, indent=2))
    print(f'wrote {argv[1]}: {len(scene["elements"])} elements, {len(scene["files"])} files')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
