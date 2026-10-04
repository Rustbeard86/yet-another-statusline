---
name: yas-screenshot-annotated
description: Build an annotated, labelled YAS statusline screenshot as an Excalidraw scene (PNG in a named frame, hand-written-style labels, freedraw pointer lines) and upload it to the Excalidraw+ "generated" collection. Use when the user asks for an annotated screenshot, a readme or landing-page screenshot, a labelled statusline image, a "what does each part mean" image, a release screenshot for YAS, or wants the default, subagents or openspec view explained with callouts.
---

# YAS annotated screenshots

Render one demo scenario to a PNG, then build an Excalidraw scene in the same
style as the hand-made annotated screenshots: the PNG inside one `#bbb` frame,
short lowercase labels (Excalifont, size 16), and thin pointer lines drawn as
`freedraw` strokes. The scene is uploaded to the Excalidraw+ collection
`generated` (id `9NsVrCCRcBb`) where the user reviews and hand-tunes it.

## Prerequisites

- `magick` (ImageMagick with Pango) and a Mono Nerd Font (see `ops/ansi_png.py`).
- `EXCALIDRAW_API_KEY` in the environment. Never write it to disk.
- Python 3.12 (the scripts use the standard library only).
- Optional: `node` + `~/.claude/skills/excalidraw-diagram/scripts/export_image.mjs`.
  It crops embedded images to the frame, so treat it as a rough check only.

## Steps

1. **Pick a view.** Presets are in `assets/views/<view>.json`:

   | View | Scenario | Shows |
   |---|---|---|
   | `default` | `sonnet-thinking` | bare statusline: every top-level section |
   | `subagents` | `subagents` | flat subagent list: duration, name, model, task description, tokens, current activity |
   | `openspec` | `openspec` | spec progress rows under the main sections |

2. **Run the glue script** from the repo root:

   ```bash
   .claude/skills/yas-screenshot-annotated/scripts/shoot-annotated.sh default
   .claude/skills/yas-screenshot-annotated/scripts/shoot-annotated.sh openspec 'yas 0.9.6 - openspec view (annotated)'
   NO_UPLOAD=1 .claude/skills/yas-screenshot-annotated/scripts/shoot-annotated.sh subagents
   SCENE_ID=7UllwMh4EVh .claude/skills/yas-screenshot-annotated/scripts/shoot-annotated.sh default   # replace in place
   ```

   Current scenes in `generated`: default `7UllwMh4EVh`, subagents `89fhA5EXY67`,
   openspec `v1MVvkrbxh`. Pass `SCENE_ID` to keep the links valid; without it a new scene is created.

   It renders `DEMO_ONLY=<scenario> make demo/img`, copies the PNG and txt to
   `.scratch/<branch>/annotated/` straight away, builds `<view>.excalidraw`,
   uploads, and prints `scene url: https://app.excalidraw.com/s/1BFmCncTPVB/<id>`.
   Why the copy: `demo/` is git-ignored and any other `make demo/img` rewrites it,
   and the PNG and txt must come from the same render or the label positions drift.

3. **Inspect before uploading.** `annotate.py` warns on stderr about skipped
   labels (anchor did not match) and overlapping labels. Run with `NO_UPLOAD=1`,
   then check `python3 -m json.tool <view>.excalidraw`. Open the scene in
   Excalidraw+ for the real review; drag labels there if needed.

4. **Report** the scene URL and id, labels skipped, and anything unsure.

## All views in one scene

`scripts/shoot-all.sh <scene-name> <view>...` builds each view with `NO_UPLOAD=1`, stacks them
with `scripts/combine.py` (frames at x = 0, 150 px gap, in the order given), writes
`.scratch/<branch>/annotated/all.excalidraw`, and uploads it with the same live-count check.

```bash
.claude/skills/yas-screenshot-annotated/scripts/shoot-all.sh 'yas 0.9.6 — all views (annotated)' default subagents openspec
SCENE_ID=<id> .claude/skills/yas-screenshot-annotated/scripts/shoot-all.sh '<name>' default subagents openspec   # replace
```

`combine.py <out> <in>...` can also be run alone on built `<view>.excalidraw` files. It
re-assigns `index` values, merges `files`, and fails if two element ids collide.
Note: this re-renders each view, so any hand edit made in Excalidraw+ is overwritten.

## How positions are found

`annotate.py --dump-grid --txt demo/<scenario>.txt` prints the ANSI-stripped text
with a column ruler and 0-based row numbers. Pick anchors from it.

- An anchor is a **regex on the stripped text**, not a fixed (col,row). Presets
  then survive layout changes between releases: a moved pill still matches.
  `occurrence` (1-based) selects among all matches in reading order; `row` restricts
  to one row; `offset: [dcol, drow]` nudges the target.
- `"at": [col, row]` replaces `anchor` when no stable text exists.
- An anchor that does not match is a warning and the label is skipped, never a crash.
- Targeted cell: centre of the match for above/below labels, first character for
  left, last character for right.

Cell geometry is an estimate because the PNG pipeline reports none. The PNG is
trimmed to its ink and padded by `YAS_DEMO_PAD` (24 px). The first and last text
rows are box-drawing rows whose ink is a centred line, so column `c` is centred at
`pad + c * (W - 2*pad) / (cols - 1)` and row `r` at `pad + r * (H - 2*pad) / (rows - 1)`.
`cols` is the longest stripped line, `rows` the non-blank line count (leading and
trailing blank lines are trimmed in the PNG too). Accuracy is within about half a
cell. `annotate.py` prints the geometry on every run.

## Spec format

```json
{"scenario": "openspec", "frame": "openspec view",
 "labels": [{"text": "session ID", "side": "above",
             "anchor": {"regex": "[0-9a-f]{8}-[0-9a-f]{4}", "occurrence": 1, "offset": [10, 0]}}]}
```

`side` is `above`, `below`, `left` or `right`. Use `\n` for multi-line labels. Optional `"end": "edge"` (default) or `"anchor"`, see the pointer end rule below.

## Placement rules (and why)

- Above/below: centred on the target x, gap 40 px from the image, staggered onto
  further baselines when x-ranges clash, so no two labels overlap and pointers do
  not cross a neighbouring label.
- Left/right: one column, 65 px (left) or 60 px (right) from the image, tops at
  least 70 px apart, sorted by target y. This matches the hand-made scenes.
- Pointers go label to image, 20-40 points, ease-in spacing and a slight bow
  (path/chord about 1.05) so they look hand-drawn. Use above/below only when nothing sits
  between the edge and the target; otherwise use left/right.
- **Pointer end rule (default `"end": "edge"`).** A pointer stops at the edge of the block it
  describes, never inside the contents. It does not run to the anchor's row. Constants
  (measured from the user's hand edit of the subagents scene: all four moved pointers ended
  exactly 28 px inside the image edge, chord 58 px = 40 label gap - 10 start gap + 28):
  - above: ends at the top edge of the first text row (`centre(row 1) - 0.45 row`), at least 15 px inside the image (`POINTER_DEPTH`) for row-0 targets such as the session ID.
  - below: ends at the bottom edge of the last text row (`centre(rows-2) + 0.45 row`), at most 15 px inside.
  - left/right: ends `EDGE_INSET` = 28 px inside the image edge (never past the anchor's x).
  - Interior targets (table columns) therefore point at the top or bottom of the table block.
  - Per-label override `"end": "anchor"` ends at the targeted glyph instead (old behaviour):
    use it only when a label must touch one specific glyph. Staggered pointers keep their extra length.
- No arrowheads, no rectangles, roughness 0, stroke `#1e1e1e` width 1.

## Adding a label

1. Dump the grid, choose a regex that is unique or add `occurrence`/`row`.
2. Append an object to `assets/views/<view>.json` using the user's wording:
   "model / thinking\n(changes colour)", "session ID", "repo dir/git info",
   "token limit", "context\nwindow", "input tokens\n(incl. cache writes)\nsession / today",
   "cache read tokens\nsession / today", "output tokens\nsession / today",
   "cost for\nsession & day", "lines of code\nread / changed", "session\nelapsed time",
   "time until\n5h reset", "5h limit\nused", "5 hour\nburn rate", "7d limit\nused",
   "7 day\nburn rate", "cache\ncountdown", "plugins &\nskills",
   "border shows\ncolour gradient\nas context fills", "subagent\nname", "task description",
   "current activity\n(tool call, or\nreply text)", "subagent\nmodel",
   "subagent\nduration", "token rate", "share of\nsession\ntotal", "total\ntokens",
   "output\ntokens", "openspec\nspec progress", "task/plan\nprogress".
3. Re-run with `NO_UPLOAD=1` and read the warnings.

For a new view, copy a preset, set `scenario` (any name in `ops/demo.py` `SCENARIOS`;
`subagent-tree-*` render to `demo/subagents/`) and rewrite the labels.

## What the top-row and tokens-row numbers are (from `claude/yas/`)

- `+13:27`: session elapsed time (`SessionView.elapsed`, from `cost.total_duration_ms`).
- 5h pill `(-2:00) 30.0% -30.0%`: time until the 5h window resets (`resets_at - now`),
  percent of the 5h limit used (`used_percentage`), burn rate.
- 7d pill `20.0% -78.8%`: percent of the 7d limit used, burn rate.
- Burn rate (`burndown_delta`): `used% - ideal%`, where ideal is the share of the window
  elapsed. Negative = under the even-use pace; positive = over it. Shown as a signed percent.
- Tokens row `↓ 41.5K/8.2M (422.4K/215.4M) ⬆ 4.8K/1.5M`: each pair is `this session / today`
  (today = all sessions, from the token log). First pair: input tokens, which is
  `input_tokens + cache_creation_input_tokens` (`billed_in`). Parenthesised pair: cache read
  tokens. Last pair: output tokens. The cell after it (`0 0`) is lines of code read / changed.

Crowded top row: above-labels stagger onto as many baselines as needed (three for the
default view), so no change to `annotate.py` was required. In views where the tokens row is
inside the image (subagents, openspec) one combined left label is used instead of three
below-labels, because left pointers can only reach the image edge.

## Env knobs

- `NO_UPLOAD=1` skip the upload. `COLLECTION=<name|id>` target collection (default `generated`).
- `SCENE_ID=<id>` replace that scene in place instead of creating a new one.
- `SCALE=1.0` multiplies image width (1440 px base) and font size (16 px base).
- `YAS_DEMO_FONT`, `YAS_DEMO_SIZE`, `YAS_DEMO_BG`, `YAS_DEMO_FG`, `YAS_DEMO_DPI`
  change the PNG. `YAS_DEMO_PAD` must also be passed to `annotate.py --pad`; the
  glue script does this.
- `annotate.py --name` sets the frame name (default: `frame` in the spec).

## Deterministic ids and in-place replace

- Every element id is `sha1(<frame name>|<role>|<label text>|<n>)[:21]` (`Scene.new_id`), so
  re-running a preset yields the same ids. Keep label texts unique per view.
- The server merges a PUT by element `id`: elements missing from the PUT survive. With
  `--scene-id` (or `SCENE_ID=`), `upload_scene.py` first GETs the live scene and appends a
  tombstone (`isDeleted: true`, `version + 1`, fresh `updated`, `fileId: null`) for every live id
  absent from the new build. `files` come from the new build only. New elements use
  `version = now in seconds`, which is above any earlier upload.
- After the PUT it GETs the scene back, prints `element count: local N, live M` (tombstones
  excluded), and exits 1 if the counts differ or two live text elements in the same frame share a text.
- Text width is estimated at `CHAR_W = 0.62` em per character of the longest line. Excalifont
  renders wider than the earlier 0.45; left-aligned text tolerates over-estimates, and
  `autoResize: true` lets Excalidraw refit the box.

## Subagent row columns (from `claude/yas/renderer.py`)

- subagent name: `subagent_type_label(sub)` (renderer.py, `type_text = subagent_type_label(sub)`).
- task description: `sub.description` (renderer.py `desc_text = sub.description or ''`, italic).
- current activity: `subagent_activity(sub.last_activity)` (renderer.py `def subagent_activity`):
  `Tool[arg]`, `(thinking)`, or the latest reply text.

## Notes

- Each upload creates a new scene unless `SCENE_ID` is set (or `scripts/upload_scene.py <file> --scene-id <id>`
  is used directly).
- `scripts/upload_scene.py` is a copy of the one in `~/.claude/skills/excalidraw-diagram`
  so this skill is self-contained.
- Label meanings that are still guesses: "token limit" (the end of the context bar).
  "lines of code read / changed" replaced the earlier "tokens used in last 1-2 mins", which
  pointed at the loc segment by mistake.

## Local rendering and GIF (no Excalidraw export)

- `scripts/render.py <scene.excalidraw> <out.png> [--bg #121212] [--pad 40] [--scale 2]` draws a scene
  with Pillow: embedded image, Excalifont text (`assets/fonts/`, licence in the README beside it) at each
  element's x,y with lineHeight 1.25, and freedraw polylines. The canvas is the tight bounding box of all
  non-frame elements plus `--pad` on each side. On a dark `--bg`, stored `#1e1e1e` strokes are drawn as
  `#e3e3e8`; `--bg white` keeps the stored colours.
- `scripts/gif.sh <out.gif> <scene.excalidraw>...` renders each scene, pads all frames to the largest size
  (top-left aligned, so the statusline stays fixed), 250 cs per frame, loops forever. Needs `magick`.
  Order scenes smallest to largest. Env overrides: `BG`, `PAD`, `SCALE`, `DELAY`.
- Differences from a true Excalidraw render: freedraw is drawn as a plain polyline (no pressure
  variation), and glyph baseline placement is estimated from font metrics.
- `.scratch/.../annotated/preview.py` is superseded by `render.py`.
