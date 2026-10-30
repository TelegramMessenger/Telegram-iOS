# GlassCapture

A capture harness for the static glass assets (`submodules/TelegramUI/Resources/StaticGlass/*.bin`,
`submodules/TelegramUI/Components/StaticGlassBackground`): the chat draws its per-message glass (bubble mode off) from
images of the real `GlassBackgroundView`, captured here.

The app lays out glass capsules (r 10–24 with a 60pt straight run), 30pt and 48pt circles, a 30×60 vertical capsule
and a 120×80 rectangle of radius 12 over a page colour and writes `Documents/manifest.json` with their frames once the
glass has rendered. Launch arguments: `-page RRGGBB`, `-dark 0|1`, `-tint panel|media|RRGGBB` (`media` is the chat's
dark glass over media; a colour is a styled tint at `-tintAlpha`, 0.85 by default), `-interactive 0|1`,
`-label <name>`, `-mode static` (the shipped images, `StaticGlassBackgroundView`, at the same frames, for comparing with
the glass).

## Regenerating the assets (a new iOS, a new shape)

1. Build and install on an iPhone simulator of the iOS the glass should match, at 3x (uninstall first: installd keeps
   an app of the same version):

   ```sh
   ./build-input/bazel-9.2.0-darwin-arm64 build --disk_cache=$HOME/telegram-bazel-cache --ios_multi_cpus=sim_arm64 //Tests/GlassCapture:GlassCapture
   unzip -q -o bazel-bin/Tests/GlassCapture/GlassCapture.ipa -d /tmp/glass-capture-app
   xcrun simctl uninstall $SIM org.telegram.GlassCapture; xcrun simctl install $SIM /tmp/glass-capture-app/Payload/GlassCapture.app
   ```

2. Capture the six pages the generator reads (two per mode for the alpha, one more to check):

   ```sh
   for p in FFFFFF E0E0E0 F0F0F0; do Tests/GlassCapture/capture.sh $OUT light-panel-$p -page $p -dark 0; done
   for p in 000000 202020 101010; do Tests/GlassCapture/capture.sh $OUT dark-panel-$p -page $p -dark 1; done
   ```

   For the media glass and the captured tints (the generator's `MODES`), the same pages with their tint:

   ```sh
   for p in 000000 141415 808080 FFFFFF; do Tests/GlassCapture/capture.sh $OUT dark-tint-000000a30-$p -page $p -dark 1 -tint 000000 -tintAlpha 0.3; done
   for p in FFFFFF E0E0E0 F0F0F0 F9F9FB; do Tests/GlassCapture/capture.sh $OUT light-tint-000000a100-$p -page $p -dark 0 -tint 000000 -tintAlpha 1.0; done
   for p in 000000 202020 101010 141415; do Tests/GlassCapture/capture.sh $OUT dark-tint-FFFFFFa100-$p -page $p -dark 1 -tint FFFFFF -tintAlpha 1.0; done
   for p in FFFFFF E0E0E0 F0F0F0 F9F9FB; do Tests/GlassCapture/capture.sh $OUT light-tint-FFFFFFa80-$p -page $p -dark 0 -tint FFFFFF -tintAlpha 0.8; done
   ```

3. Generate (Python 3 with numpy and Pillow); it prints, per asset, the error of compositing it over each captured page
   (name shapes after the directories to write only those, keeping assets made from earlier captures):

   ```sh
   python3 submodules/TelegramUI/Components/StaticGlassBackground/Tools/make_static_glass.py $OUT submodules/TelegramUI/Resources/StaticGlass
   ```

4. Compare on screen: capture the same pages with `-mode static` and diff against step 2 (exact over FFFFFF and 000000
   for the shipped shapes when the assets are right).

Measured on iOS 27 (2026-10-30): the glass composes linearly over gray pages (within 1 level at p99), about 5 levels off
over coloured ones (it boosts their saturation); the edge profiles are the same at every radius, the ends are not; a
styled tint lies over the panel at its alpha, with a lighter rim than the panel's.
