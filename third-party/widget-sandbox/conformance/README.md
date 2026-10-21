# Widget profile conformance set

Each Telegram client draws widgets with its own renderer: Shadow DOM on the web,
WKWebView/WebView or a native engine (litehtml, TwidgetCore) on the others. A
widget looks the same everywhere only if every renderer draws the same profile
and the validator strips everything else the same way. This set checks that.
For any client it answers the question: which profile features does it support?

**Client teams: start with [CLIENTS.md](CLIENTS.md).** It covers how to run the set in your client on your renderer and read the report. This README is for the maintainers of the set.

| | |
|---|---|
| [`catalogue.json`](catalogue.json) / [`catalogue.md`](catalogue.md) | 255 profile features with stable IDs (`css.display.grid`, `canvas.filter`, `tw.profile`, …). Each is marked in / out / candidate, with the decision it comes from (D3a, D3b, D4, D18, D23, the invariants, or `proposed` for the catalogue's own proposals), what the pipeline of the tag does with it (`today`: kept, stripped, replaced, resolved, … with profile 1 enforced and SDK v1; the legend is at the end of `catalogue.md`), and the keys a validator table would match. Profile 1 is frozen in `packages/core/profile.json` (2026-10-17), which is the source: the catalogue takes its statuses, decisions and neutralisations, so profile 1 has no candidates. `profile.json` lists the same 255 IDs, the SDK v1 limits and client behaviours included. The source is `scripts/conformance/catalogue.ts`; `emit-catalogue.ts` overlays `profile.json` when the branch has it. |
| [`auto/`](auto) | **Automatic set**, 38 dense widgets for runners and CI (a topic too large for one mini-widget is split into parts: `03-layout-a`, `-b`, …). Each one asserts layout, computed style, APIs and events itself and publishes the result. Pixel stages are diffed against reference PNGs. |
| [`visual/`](visual) | **Visual set**, 13 readable widgets for people (the shared Telegram test channel). Each row shows a group of features drawn live, with a one-line caption; the reference picture of the whole widget (`refs/visual/<widget>.png`, `.dark.png` for theme-dependent ones) is posted as a photo next to it. Interactive rows carry a one-line instruction. Numbered in reading order. |
| [`visual/sdk/`](visual/sdk) | **Client SDK group**, 17 widgets for what each client implements of SDK v1. Their reference pictures are `refs/visual/sdk/<widget>.png`, posted next to them; [`visual/sdk/README.md`](visual/sdk/README.md) is the post list. They use the mini harness (`harness/mini.js`). |
| [`channel.json`](channel.json) | The test channel in posting order: per message the widget, its size anchors, the caption and the reference photos. A test bot sends them as layer-233 messages. |
| [`manifest.json`](manifest.json) | Per test: catalogue IDs, kind (self / pixel / interactive), stages with rects and reference files, scripted actions, host checks, themes, and what native Chromium answers to each check. Also coverage per set. |
| [`refs/`](refs) | Reference PNGs for every stage (`refs/<set>/<widget>/<stage>.chromium[.dark].png`, for the automatic diff) and the pictures posted next to the visual and SDK widgets (`refs/visual/<widget>[.dark].png`): native headless Chromium (and WebKit when installed), DPR 2, the reference width 390. |
| [`run.schema.json`](run.schema.json) | The run file every runner writes. |
| [`tools/`](tools) | `report.mjs`, the report (run files → per-renderer JSON + `summary.md`); `diff.mjs`, the pixel rule; `png.mjs`. No dependencies, Node ≥ 18. |
| [`harness/`](harness) | The harness inlined into every widget: `harness.js` (checks, the result attribute; the build bundles only the functions a widget uses), `harness.css` + `auto.css` / `visual.css`, and `mini.js` / `mini.css` for the SDK group. |
| [`results/`](results) | Reports of the renderers run so far, plus [`summary.md`](results/summary.md). |

Coverage: the automatic set covers 245 of the 255 catalogue IDs. The other ten are listed under `coverage.external` in the manifest: four limits the attack suite and the server check, and six client behaviours the client SDK group tests. The visual set covers the 105 IDs that a person should also see: gradients, shadows, filters, text, canvas, animations, SVG, images, interaction, theme and the client SDK.

## How a widget reports

Every widget is one self-contained HTML file: no external resources, `data:` images only. Every widget is a mini-widget, like a product widget (at most 4 KB after gzip and 32 KB uncompressed, `docs/tgw-format.md`): the build keeps each one under 3800 bytes of gzip at levels 6 and 9, since the server's level is unknown, and fails otherwise. A test bot sends every widget as a layer-233 message with its reference picture posted next to it, in the order of `channel.json`.

The harness writes the result as JSON into the `data-conformance` attribute of `<html>`. Any host reads it from its own validated ops: it is the `attr` op on the element that the `el` op adopted as `html`.

Every check names a catalogue ID and gets one of six statuses:

| Status | Meaning |
|---|---|
| `pass` | The check passed. |
| `fail` | The check failed. |
| `pending` | Input never came; counts as a fail. |
| `skip` | Not applicable on this renderer. |
| `xfail` | Expected to fail: the framework does not implement it yet. |
| `xpass` | Expected to fail but passed, so the expectation is out of date. |

Interactive widgets publish `targets`, the rects of what to tap or drag, measured in their own layout. See CLIENTS.md for the full format.

## Maintainers: building and running here

The steps are in this order:

1. Rebuild the set after editing a widget, the harness or the catalogue. This regenerates the catalogue, inlines the harness, renders the references and the posted pictures, records the native answers in the manifest and writes `channel.json`. It fails when a widget is over the size limit; `--sizes` checks only the sizes, in a second, without a browser:

   ```bash
   corepack pnpm tsx scripts/conformance/build.ts
   corepack pnpm tsx scripts/conformance/build.ts --sizes
   ```

2. Start the dev server. From a worktree, use a port no other checkout uses:

   ```bash
   corepack pnpm dev --port 5175
   ```

3. Run the web renderers. This covers iframe, Shadow DOM, and Blitz/litehtml when their wasm is built (`pnpm build:blitz-web`, `pnpm build:litehtml-web`):

   ```bash
   corepack pnpm tsx scripts/conformance/run-web.ts --origin http://127.0.0.1:5175
   ```

   The defaults are the product configuration: `strict`, `webAnimations`, width 390, DPR 2. Options: `--renderers shadow`, `--set auto`, `--only 12-canvas-a`, `--themes light,dark`, `--widths 360,390,430`.

4. Judge the run files into the reports. This is the same tool the clients run:

   ```bash
   node packages/conformance/tools/report.mjs --out packages/conformance/results reports/conformance/{iframe,shadow,blitz,litehtml}.json
   ```

`run-web.ts` is the reference runner. It loads each widget through `window.__tw.load` (the real worker → validator → renderer pipeline) and wraps the renderer's `send` to read the result from the validated ops. It focuses a stand-in chat input first and performs the manifest actions with real mouse input (the canvas renderers get taps only, through `__tw.tap`). It crops the stages from a DPR 2 viewport screenshot at the widget's snapped device-pixel origin and writes the run files to `reports/conformance/`, which is gitignored. The dev app lists the set as the `conformance/` group in its corpus panel.

## Writing a test

- Start from an existing widget. Keep the header comment `<!-- conformance {…} -->` (title, hint, actions with the catalogue `ids` they feed, host checks, covers) and the `<!-- conformance:harness -->` markers; `build.ts` fills the markers.
- Self-checks use the harness API:

  | Call | Use |
  |---|---|
  | `T.check`, `T.eq`, `T.near`, `T.ok(id, name, …, opts)` | Checks that run at once. |
  | `T.wait(id, name)` | A check resolved later, by an event. |
  | `T.step(fn)` | Runs after the first frames. |
  | `T.target(name, el)` | Publishes a tap or drag target. |
  | `T.run({awaitInput, deadline})` | Starts the widget. |

  Options: `opts.xfail: 'reason'` for known gaps, `opts.sandboxOnly` for what a plain browser cannot do. Also `T.rect`, `T.cs`, `T.color`, `T.stage`, `T.skip`, `T.sandbox`, `T.mode`. The build inlines only the functions a widget calls, minified, so the harness costs about 0.9 KB of gzip in a visual widget and 1.3–1.6 KB in an automatic one.
- Pixel stages are `<div data-stage="name" data-covers="ids" [data-themes] [data-max-diff] [data-colors] [data-xfail]>` with fixed colours on the white stage:
  - auto set: an 80×60 grid at the top;
  - visual set: 150×90, in flow.

  A `<template data-ref="name">` at the end of the body gives the expected rendering when it differs from what Chromium draws. Script-drawn stages go through `T.stage(name, draw)`.
- Keep auto widgets under 600 px tall (the host cap since v0.1.0) and keep layout above the probes stable.
- Keep every widget under the size limit (`build.ts --sizes`). When a topic outgrows it, split it into parts (`NN-topic-a`, `-b`) with the same check ids and names, rather than trimming what a check measures.
- No external URLs; v1 has no bundled libraries.

The posted pictures come from the same build: the whole widget in reference mode (templates swapped in) at 390 px, DPR 2, on the reference palette's background. For the client SDK group, `scripts/conformance/sdk-mock.js` is a stand-in for `TelegramWidget` that follows the contract and uses that palette, so the pictures show the "SDK present" state; the visual set gets only the palette. Only the build injects it.

## Known limits

- References come from headless Chromium on macOS. WebKit references appear once Playwright's WebKit is installed, and the rule then takes the better of the two.
- Text stages depend on platform fonts. They allow 50 % of the ink but check the feature's colours.
- The web runner gives the canvas renderers (Blitz and litehtml wasm prototypes, which are not product renderers) only synthetic taps. Drags, hover, keys and wheel are skipped there, and so are gesture-gated host checks.
