# Running the widget conformance set in your client

For client teams (iOS, Android, macOS, desktop, web). Each of you embeds widget-sandbox and draws widgets with your own renderer. The **widget profile** is the contract that keeps widgets looking the same everywhere. This set tells, for your renderer, which profile features it supports, in a report that can be compared with the other clients.

You need three things: the framework tag, your own host and renderer, and Node ≥ 18 for the report tool, which has no dependencies.

## What comes with the framework tag

`packages/conformance/` in the widget-sandbox checkout (SwiftPM, the Gradle `includeBuild` and the tdesktop submodule all have it):

| | |
|---|---|
| `auto/*.html` | The automatic set: 38 widgets that check themselves. Required. |
| `visual/*.html` | The visual set: 13 widgets for people (the test channel). Optional in a runner, where it is only a load check. |
| `channel.json` | The test channel in posting order: per message the widget, its size anchors, the caption and the reference photos. |
| `manifest.json` | One entry per widget: scripted `actions`, `host` checks, pixel `stages` (`rect`, `themes`, `refs`), `themes`. |
| `catalogue.json` | The profile features with their IDs and status (in / out), as `packages/core/profile.json` freezes them, plus the SDK v1 limits, and what the framework does with each (`today`; legend in `catalogue.md`). `version` is the profile version. |
| `refs/` | Reference PNGs of the stages (headless Chromium, DPR 2), and the pictures posted next to the visual and SDK widgets (`refs/visual/<widget>[.dark].png`). |
| `run.schema.json` | The run file your runner writes. |
| `tools/report.mjs` | Turns run files into the report. |
| `tools/diff.mjs` | The pixel rule, if you prefer to judge stages yourself. |

The widgets are ordinary widget HTML: one file, `data:` images only, no network, each a mini-widget (under 4 KB of gzip). Load them exactly as you load a widget from a message.

## What a widget tells you

Each widget runs its checks and publishes the result as JSON in the `data-conformance` attribute of its `<html>` element:

```json
{"v":1,"id":"auto/03-layout-a","status":"done",
 "n":{"pass":17,"fail":0,"xfail":0,"xpass":0,"skip":0,"pending":0},
 "checks":[["css.display.flex","row places children side by side","pass",""], …],
 "targets":{"knob":[x,y,w,h]}, "stages":{"flex":[8,8,80,60]}}
```

Your host sees this in the **validated ops**, the batch the framework hands to your renderer:
- the `el` op carrying `"adopt": "html"` gives the html element's id (its `attrs` may already include the attribute);
- every later `{"op":"attr","id":<that id>,"name":"data-conformance","value":"…"}` replaces the value.

Keep the last value. You need no hook in the renderer and no DOM.

`status` moves through three values:
1. `running`: still checking.
2. `awaiting`: the widget waits for the scripted input from the manifest.
3. `done`: finished.

## The runner, step by step

Build it as a test target or a debug mode in your client. For every entry of `manifest.tests` with `set: "auto"`, and for every theme in its `themes`:

1. **Configure the host as in production.** Policy `strict`. `features` as the profile sets them, today `["webAnimations"]`. Your renderer, the theme, and a width of 390 CSS px (points or dp); 360 and 430 are welcome too.
2. **Focus the chat input**, or a stand-in text field, before loading the widget.
3. **Load the widget HTML** and observe the validated ops. Every platform has the same renderer seam, so wrap your renderer: see "Reading the ops" below.
4. **Wait** for `status` `done`, or `awaiting` when the test has `actions`. Give up after 20 s and record what you have.
5. **Record `chatFocused`**: does the chat input still have the keyboard focus? The profile has no keyboard (D4), so a widget must never take the focus.
6. **Perform the `actions`**, if any, in order, with real input. Coordinates are widget CSS px from the widget's top-left. A target name means the centre of `targets[name]` in the **latest** published value, because the widget re-measures after every update. Leave about 350 ms between actions. Then wait up to 10 s for `done`.

   | action | do |
   |---|---|
   | `{"tap": T}` | a tap at T |
   | `{"dblclick": T}` | a double tap |
   | `{"rightclick": T}` | a secondary click or long press |
   | `{"hover": T}` | move a pointer over T (desktop; skip on touch) |
   | `{"press": T, "ms": n}` | hold for n ms |
   | `{"drag": T, "to": T2}` | press, move in about 10 steps, release |
   | `{"drag": T, "to": [dx, dy], "by": true}` | the same, by a delta |
   | `{"key": "Enter"}` | a key press (the widget must not receive it) |
   | `{"wheel": T, "dy": n}` | a scroll wheel or trackpad scroll over T |
   | `{"theme": "dark"}` | switch the chat theme |
   | `{"visible": false}` | scroll the bubble off screen (true: back) |
   | `{"wait": n}` | wait n ms |

   An action your platform cannot perform goes into `skippedActions` (its index); the checks it feeds are then reported as skipped, not failed.
7. **Snapshot the widget** at 2× scale. Crop every stage in `manifest.tests[].stages` whose `themes` include this theme, at `rect` (`[x, y, w, h]` in CSS px from the widget's top-left). Each crop is a PNG of `2w × 2h` pixels. Save it next to the run file.
8. **Record what the host saw:**
   - the bridge calls your host accepted after the gesture gate (`openLink` and the like, with their arguments);
   - the bubble height at the end, in CSS px;
   - whether your input is synthetic (`syntheticInput`: true when it cannot grant a user gesture);
   - uncaught widget errors.

Run the visual set the same way if you like, without actions or crops; the report then shows whether each widget loads.

Write everything into one run file per renderer, following `run.schema.json`:

```json
{
  "platform": "ios", "renderer": "wkwebview", "engine": "iOS 26.1, iPhone 17", "framework": "v1.0.0",
  "policy": "strict", "features": ["webAnimations"], "date": "2026-10-20T10:00:00Z",
  "runs": [{
    "id": "auto/03-layout-a", "theme": "light", "width": 390, "loaded": true, "dead": null, "status": "done",
    "checks": [["css.display.flex", "row places children side by side", "pass", ""]],
    "stages": [{ "name": "flex", "crop": "crops/03-layout-a.light.flex.png" }],
    "observed": { "bridge": [], "height": 512, "chatFocused": true, "syntheticInput": false },
    "skippedActions": [], "errors": []
  }]
}
```

`checks` is the published `checks` array, copied as is.

## Reading the ops

Every platform's `Renderer` gets the validated batch as `{"type":"ops","ops":[…]}`. A wrapper that forwards everything to your real renderer and looks at `ops` on the way is all you need. TypeScript, for the web, through `WidgetHost`'s `rendererFactory`:

```ts
function probe(inner: Renderer, onResult: (r: any) => void): Renderer {
  let html: number | null = null;
  return new Proxy(inner, { get(t, k) {
    if (k !== 'send') { const v = Reflect.get(t, k); return typeof v === 'function' ? v.bind(t) : v; }
    return (msg: any) => {
      if (msg.type === 'ops') for (const op of msg.ops) {
        if (op.op === 'el' && op.adopt === 'html') {
          html = op.id;
          for (const [n, v] of op.attrs) if (n === 'data-conformance') onResult(JSON.parse(v));
        } else if (op.op === 'attr' && op.id === html && op.name === 'data-conformance') onResult(JSON.parse(op.value));
      }
      t.send(msg);
    };
  } });
}
```

The same seam on the other platforms:
- **Swift:** `Renderer.send(_ json: String)`; and `send(ops: [WidgetOp])` when `acceptsTypedOps`, where `WidgetOp.json(ops)` gives the JSON of a typed batch.
- **Kotlin:** `Renderer.send(json: String)`.
- **C++:** `twidget::Renderer::send(const std::string& json)`.

Wrap your renderer in a class of the same interface, parse the JSON of `ops` messages as above, and forward. The framework is getting a ready-made `ConformanceProbe` for each host (TS, Swift, Kotlin, C++); use it once it is in your tag.

## The report

```bash
node packages/conformance/tools/report.mjs --out conformance-results path/to/run.json
```

- It writes `conformance-results/<platform>-<renderer>.json` and `summary.md`, plus `diffs/` for every stage it judged.
- It judges the crops against `refs/`. The rule: differing pixels at most 5 % of the stage's ink, anti-aliasing ignored. Stages with text allow 50 % but must show the feature's colours (a text shadow, a decoration colour).
- Pass several run files to get the renderers side by side.
- `--fail-on in` exits with 1 when an in-profile ID fails, for CI.

Verdict per catalogue ID:

| Mark | Meaning |
|---|---|
| ✅ | pass |
| ◐ | partly |
| ❌ | fail |
| ⏳ | expected to fail: the framework does not implement it yet |
| ❗ | passes although expected to fail |
| – | not applicable on your client |

How to read them by status:
- **in**: your renderer must pass these. Report ❌ and ◐ to the widget-sandbox maintainers.
- **candidate**: profile 1 has none. Candidates come back with profile 2, and the profile takes one when every client passes it.
- **out**: ✅ means the feature is neutralised as the profile says.

Send `<platform>-<renderer>.json` and `summary.md` to the widget-sandbox maintainers, or open a PR adding them to `packages/conformance/results/`.

## The client SDK group (`visual/sdk/`)

Seventeen small widgets test what **your client** implements on its side of SDK v1 (`docs/sdk-v1.md`, §5):
- links (the confirmation with the full URL, t.me inside the client, rejected and over-long URLs, no link from a timer);
- haptics of each kind and the rate limit;
- storage (re-creation, app restart, deletion with the message, the 16 KB quota);
- stopping after 2 consecutive crashes;
- drag versus swipe-to-reply, with double tap and long press staying with the bubble;
- the hard clip at the maximum height (600 px, the shared v0.1.0 value);
- the theme palette with a live switch.

Three of them need a test bot (layer 233): storage of a forwarded copy (forward the message into another chat), a bot editing the message, and the bubble size anchors (`inputMediaWidget` with `width` / `height`: 0 = auto, W = a fixed width in [200, max], H = a fixed height in [50, 600]; auto heights are clamped to [50, 600] and cached per message).

Each widget is a v1 mini-widget (at most 4 KB gzipped). It carries a one-line instruction for the tester. Its expected client behaviour, contract section and reference picture are in [`visual/sdk/README.md`](visual/sdk/README.md), the post list for the test channel. Post the picture (`refs/visual/sdk/<name>.png`, plus `.dark.png` for the palette) as a separate image next to the widget.

The automatic set checks the framework side of the same contract. In `auto/16`, `auto/15` and `auto/20` that covers:
- argument checks and `TypeError`;
- the 256-character URL limit and 16 handlers per event type;
- the haptics bucket seen on the bridge;
- `QuotaExceededError`;
- `themeParams` on a theme switch;
- `isActive`.

They need SDK v1 in the framework (`docs/sdk-v1.md`).

## The whole set in the test channel

Every widget of the set is a mini-widget, so a test bot sends all of them as real layer-233 messages (`inputMediaWidget` with the HTML; bots may post only into private chats, so a tester forwards them into the shared channel). `channel.json` is the posting order: the visual set (`visual/01…13`, in reading order), the client SDK group, then the automatic set. Each post has the widget, its size anchors (`width` / `height`, `0` = auto), a caption saying what to check, and the reference photos to post right after it: `refs/visual/<widget>.png`, plus `.dark.png` for the theme-dependent ones.

In a visual widget each row shows a group of features drawn live by your client, with one line saying what to compare with the same row of the picture. Interactive rows say what to tap or drag. Testers scroll through on a phone and report a row that does not match, with a screenshot. Fonts differ between platforms by design: compare the structure, not the letter shapes. An automatic widget reports itself: its result line at the bottom must say `done` and show no `fail` count (each failing check is listed under it). `.tgw` is only a local development format; nothing in the channel needs it.

## When the framework changes

The set belongs to the tag. When you update the framework, rerun: `catalogue.json` `version` is the profile version, and the manifest says what each test covers. The set expects a framework that enforces profile 1 (the validator neutralises the out features, `CSS.supports` and `@supports` answer from the profile, the renderer draws an unstyled `<button>` with the profile's UA stylesheet) and implements SDK v1. A check marked ⏳ is one the framework does not do yet; it turns into a pass when that lands in your tag, with no change on your side.
