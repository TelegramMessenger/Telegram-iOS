# Media editor export harness

Benchmark and export runs for the media editor's export paths, on the iPhone 18 Pro simulator
(iOS 27.0).

```sh
submodules/TelegramUI/Components/MediaEditor/Harness/run-export-harness.sh [all|export|benchmark|compositor|entities|composer|photo|vignette] [host output dir] [scenario id]
```

The script builds `//submodules/TelegramUI/Components/MediaEditor:MediaEditorExportHarness`
(`-c dbg`, so Swift is `-Onone`, like `Make.py test`). It then reuses or creates the simulator
`MediaEditorExportHarness iPhone 18 Pro 27.0`, reinstalls the app and launches it. It waits for
`status.txt`, then copies the app's `tmp/MediaEditorExportTests` directory to the host output
directory, which defaults to `$TMPDIR/MediaEditorExportOutput`.

The output directory holds:

- `<id>-<frame>.png`: composed frames (pre-encode pixel buffers for videos), for inspection (`export` mode, also
  part of `all`). Each scenario must complete, capture frames and, for videos, report a composition time per frame.
- `<id>-decoded-<frame>.png`: decoded output frames, for inspection. The decoded file's dimensions, duration and
  frame count must match the export.
- `benchmark.csv` and `benchmark.md`.
- `compositor.txt`: `PASS`/`FAIL` per `MediaEditorFrameCompositorSuite` test with its measured deltas
  (`compositor` mode, also part of `all`).
- `entities.txt`: `PASS`/`FAIL` per `MediaEditorComposerEntityFrameSuite` test (`entities` mode, also part of
  `all`). Each composer entity kind's frame is rendered through the compositor and through
  `mediaEditorEntityFrameCIImage` (rendered with a `CIContext`, as the CoreImage composer did), and the two are
  compared. Every kind gets its own
  temporary Postbox, because the lottie frame cache is keyed by resource and a second entity on the same
  resource would read the first one's compressed frames.
- `composer.txt`: `PASS`/`FAIL` per `MediaEditorComposerSuite` test (`composer` mode, also part of `all`): a nil
  entity frame still completes the frame, and the CoreImage audit of `Sources/`, which the test bundle carries as
  `Sources/**/*.swift` resources.
- `photo.txt`: `PASS`/`FAIL` per `MediaEditorPhotoCompositionSuite` test (`photo` mode, also part of `all`): the
  CoreImage-free `getTextureImage` readback against a `CIContext` `createCGImage` readback of the same texture, both
  unmirrored and mirrored, byte for byte; the panorama and oversized photos through `makeChatEditorImageComposition`; and the chat crop composition
  cases that used to live in `ChatMediaEditorCropCompositionTests`, which need a Metal device. The simulator's GPU is
  Apple2 only, so its texture side limit is 8192, not 16384.
- `vignette.txt`: `PASS`/`FAIL` per `MediaEditorVignetteSuite` test (`vignette` mode, also part of `all`): the
  adjustments pass on a flat grey texture, with positive vignette values pinned to the pre-bidirectional output and
  negative ones lightening the edges as the mirror image of positive ones.
- `harness.log`, `failures.txt` and `status.txt` (`done <failure count>`).

Realistic sources are opt-in: `--only` (the script's third argument) takes a comma-separated list of scenario ids,
and `realistic` selects all of them. They are left out of the default `export` and `benchmark` runs.

- `chat-video-4k`, `chat-video-4k-crop`, `chat-video-4k-adjust`: chat sending with the chat editor's default quality
  preset (`compressedMedium`, 848 px H.264 at 1.6 Mbps, 30 fps configuration) with no edit, a square crop, and three
  colour adjustments.
- `story-video-4k-sticker-text`: story export (720×1280 HEVC, 60 fps configuration) with a sticker and a text entity.
- `chat-video-4k-hlg`, `story-video-4k-sticker-text-hlg`: the same on the HDR variant of the source.

The source is shaped like an iPhone camera clip: 3840×2160 HEVC coded landscape with a 90° track transform
(portrait on display), 60 fps, 45 s, 50 Mbps with a 1 s keyframe interval, and 48 kHz stereo AAC. The SDR variant
is 8-bit BT.709 (HEVC Main), the HDR one 10-bit HLG BT.2020 (HEVC Main10), the iPhone camera's default. Its frames
are drawn by a Metal kernel (fractal texture, pan, zoom, shake, moving objects and per-frame grain), so it
compresses like natural footage rather than a flat gradient. It is not stored in the repository:
`MediaEditorRealisticSource` (`Tests/MediaEditorRealisticSource.swift`) generates it with the hardware encoder on
first use and caches it in the app's `Library/Caches/MediaEditorRealisticSources` (about 280 MB per variant). On an
iPhone 17 Pro Max that takes under a minute per variant; in the simulator it took 22 minutes, and the script
reinstalls the app, which drops the cache. `--runs <n>` sets the benchmark's measured runs per scenario
(`MEDIA_EDITOR_EXPORT_RUNS` in the script, default 5).

`--mode decode-probe` (device only, iOS 17+, not offered by the script) times decoding the realistic sources alone,
with AVAssetReader in several output configurations, VTDecompressionSession with 1–16 frames in flight, and 2–4
segments decoded concurrently. It writes `decode-probe.csv`. Its options are `--rounds`, `--rest <s>` (the rest before
each run, then it waits for a nominal thermal state), `--reverse`, `--variants <comma list>` and `--sources sdr,hlg`.
`--parity` instead hashes every decoded frame of selected variants against the export's reader configuration
(`decode-parity.txt`).

No reference images are stored: every comparison is against a live CoreImage or CoreGraphics rendering. The simulator is shut down afterwards unless `MEDIA_EDITOR_EXPORT_KEEP_BOOTED=1`; `MEDIA_EDITOR_EXPORT_TIMEOUT` (seconds, default 5400) bounds the wait. The exit status is 0 only when there
are no failures.

Why an app and not the `MediaEditorExportTests` `ios_unit_test`, measured on 2026-10-23 with
Xcode 27.1:

- **The hostless runner has no Metal device.** `ios_test_runner` starts xctest with
  `simctl spawn -s`, and `MTLCreateSystemDefaultDevice()` returns nil there.
- **`ios_xctestrun_runner` hangs in UIKit.** It spawns without `-s`, but the xctest process then
  hangs in `+[UIScreen initialize]`, which AsyncDisplayKit's `+load` reaches.
- **Hosted tests hang in xcodebuild.** `xcodebuild test-without-building` never launches the host,
  on both 27.0 and 26.5.
- **iOS 27.1 refuses iPhone 18 Pro**, so the harness runs on 27.0.

The `ios_unit_test` target wraps the same `MediaEditorExportSuite` for machines where a runner
works.

Fixtures in `Tests/Resources/` were generated once with
`swift Tests/FixtureGenerator/generate-fixtures.swift <dir>`. The animated sticker is HEICS, not
GIF, because `UIImage.animatedImageFromData` reads only the HEICS frame delays, and a GIF yields a
zero duration.
