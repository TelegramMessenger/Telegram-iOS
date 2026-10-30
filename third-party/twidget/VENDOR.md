# twidget (vendored)

twidget is Telegram for macOS's message-widget renderer: a litehtml fork plus an Objective-C++ layer
(`LHDocument`, `LHContainer`) that lays HTML out and draws it with CoreText and CoreGraphics. This
directory builds its rendering core for iOS.

- **Source:** twidget `b5878f9` (2026-10-14; see "Re-vendored at b5878f9" below), first copied at
  `80dad8c081535f39153aaf5e2982595a51fea81a` (`~/build/twidget`) on 2026-10-13. The commits named next are the
  80dad8c pristine copies; the 80dad8c → b5878f9 delta was merged over the edits below, not re-copied pristine, so
  `git diff 751715a0ba` now shows upstream's delta and our edits together.
- **Pristine copy:** commit `751715a0ba` ("vendor twidget 80dad8c LiteHTML and TwidgetAssets
  (pristine)"). Every change to the vendored files is `git diff 751715a0ba -- third-party/twidget`.
  The tests and their corpus were copied, from the same revision, in commit `815edebe33` (pristine), so
  every change to them is `git diff 815edebe33 -- third-party/twidget/tests third-party/twidget/Examples`.
- **The Swift DOM, removed 2026-10-19:** `TwidgetRenderer/WidgetDOM.swift`, widget-sandbox's
  `WidgetSandboxProtocol/{WidgetOp,WidgetCanvasBatch}.swift` and their tests (`tests/DOMTests/`), vendored on
  2026-10-13 for the ops-fed renderer, were deleted with it when the app moved to WidgetRuntime (M1d,
  `a85f21a602`; `git show a85f21a602^:<path>` has them). Since then the app uses the litehtml fork through
  WidgetRuntime and the `LiteHTML` layer only through edit 22's `LHHostSupport.h`.

## Taken

| twidget | here |
|---|---|
| `Sources/LiteHTML/**` (all of it but gumbo: the ObjC++ layer, `core/`, `include/`, `litehtml/` and both licences) | `LiteHTML/` |
| `Sources/TwidgetAssets/{twa_icons.cpp,twa_icon_data.inc,include/twidget_assets.h,icons/LICENSE}` | `TwidgetAssets/` |
| `LICENSE`, `THIRD_PARTY_NOTICES.md` | `./` |
| `Tests/LiteHTMLTests/*.mm` (all 30 at b5878f9) | `tests/LiteHTMLTests/` |
| `Tests/TwidgetRendererTests/{DashboardLayout,DamageBand,CompositorClip,CachePurge}Tests.swift` | `tests/DocumentTests/` |
| `Examples/chats/*.chat` (13 files, 872 KB: the seed corpus of four LiteHTMLTests suites; since 2026-10-15 only `TwidgetRenderingTests`' fixture) | `Examples/chats/` |

gumbo (`litehtml/src/gumbo`, `litehtml/gumbo-include`) was taken with the rest at 80dad8c and moved to
`third-party/gumbo` on 2026-10-16, where this repo forks it (its own `VENDOR.md`). A re-vendor of twidget leaves
litehtml's copy of gumbo out; litehtml links `//third-party/gumbo`.

The tests live under `tests/`, not twidget's `Tests/`: `tests/` (the host smoke test) already exists,
and on a case-insensitive file system the two names are one directory.

`THIRD_PARTY_NOTICES.md` is upstream's, verbatim: its paths (`Sources/LiteHTML/litehtml`, …) are
twidget's layout, and it lists projects not taken here (QuickJS-ng, three.js).

## Not taken

- `Sources/TwidgetAssets/icons/{light,regular,bold,fill}/*.svg` and `icons.json`: the inputs of
  twidget's `tools/icons/generate.py`, which writes `twa_icon_data.inc`. Nothing here builds from
  them. To change the icon set, regenerate upstream and copy the `.inc`; `icons/LICENSE` stays, as
  the path data in the `.inc` is Phosphor's.
- `Sources/TwidgetRenderer`: the macOS renderer (`LiteHTMLWidgetRenderer`, its compositor, canvas, magic
  move, scrolling, form editing). Telegram's iOS host is WidgetRuntime
  (`submodules/TelegramUI/Components/MessageWidget/WidgetRuntime`) and its platform half, `WidgetRuntimeIOS`.
- `Sources/HTML3D`, `Sources/HTMLScript/JSCScriptRuntime.swift`, `Sources/Twidget3D*`,
  `Sources/TwidgetCore`, `Sources/TwidgetIcons`, `Lab`, `tools`; `Examples` other than `chats`;
  `Tests` other than the files above (the other `TwidgetRendererTests`, and `TwidgetCoreTests`,
  `TwidgetIconsTests`, `Twidget3DTests`, `Twidget3DSandboxTests`, which test sources not taken).

## Bazel targets (`BUILD`)

| target | what |
|---|---|
| `:litehtml_fork` | `cc_library`, the litehtml fork, linking `//third-party/gumbo` (`-std=gnu++17`, as upstream's `cxxLanguageStandard`); links CoreFoundation for `el_form.cpp`'s date formats |
| `:TwidgetAssets` | `cc_library`, the icon set; header `twidget_assets.h` |
| `:LiteHTML` | `objc_library`, `module_name = "LiteHTML"`; public headers `LiteHTML/include/*.h` (`import LiteHTML` from Swift); `LiteHTML/core/lhx_painter.h` and `LiteHTML/LHHostSupport.h` (edit 22) as textual headers (below) |
| `:TwidgetLitehtmlSmokeTests` | host `cc_test` of the fork |
| `:TwidgetForkTests` | host `cc_test` of Telegram's fork changes (edits 4, 8, 9 and 10): `tests/fork_test.cpp` |
| `:TwidgetExternalTests` | host `cc_test` of edits 12, 16, 17, 18, 20 and 21: `tests/external_test.cpp` |
| `:TwidgetSchemeTests` | host `cc_test` of edit 13: `tests/scheme_test.cpp` |
| `:TwidgetCssNestingTests` | host `cc_test` of edit 14: `tests/css_nesting_test.cpp`, on a 512 KiB thread |
| `:TwidgetCssListsTests` | host `cc_test` of edit 15: `tests/css_lists_test.cpp` |
| `:TwidgetPseudoNestingTests` | host `cc_test` of edit 19: `tests/pseudo_nesting_test.cpp`, on a 512 KiB thread |
| `:litehtml_test_container` | `cc_library` (test only) of `tests/test_container.h`, for WidgetRuntime's host tests, which lay fixtures out through `litehtml_test::TestContainer` as the metrics `WidgetContainer` must reproduce |
| `:TwidgetExampleChats` | `apple_resource_group`: `Examples/chats` as a structured resource, so the test bundle holds `Examples/chats/*.chat` (`TwidgetRenderingTests` only; nothing in the app reads it since 2026-10-15) |
| `:LiteHTMLTestsLib` | `objc_library` (test only) of `tests/LiteHTMLTests/*.mm`, `LHTestShim.h` force-included |
| `:DocumentTestsLib` | `swift_library` (test only) of `tests/DocumentTests/*.swift` |
| `:TwidgetRenderingTests` | `ios_unit_test` of both, on `:TwidgetTestRunner` (iPhone 17, iOS 26.5), `timeout = "long"` |
| `:ScanSources` | `filegroup` (test only) of the fork's sources, for WidgetRuntime's no-I/O scan (`:WidgetRuntimeNoIOScanTests`) |

`include/LHDocumentPainting.h` (public) includes `"../core/lhx_painter.h"`, so `:LiteHTML` exports
that header as a `textual_hdrs` entry (and keeps it out of `srcs`): without it an Objective-C++
dependent cannot find it in its sandbox. It is not in `hdrs` because it is C++ (`namespace lhx`) and
`hdrs` make up the module Swift imports. `LHHostSupport.h` is exported the same way, for the same reason.

The fork's `cc_library` is not called `litehtml`: that differs from `LiteHTML` only by case, and on a
case-insensitive file system (the APFS default) the two targets then write the same `bazel-bin`
paths (`_objs/litehtml/`, and `liblitehtml.a` is `libLiteHTML.a`), each archive overwriting the other.

The fork needs RTTI and exceptions, which are Bazel's defaults.

## Re-vendored at b5878f9 (2026-10-14)

`LiteHTML/**`, `TwidgetRenderer/WidgetDOM.swift` and `tests/LiteHTMLTests/*.mm` were moved from 80dad8c to b5878f9
(the twidget clone's `Sources/LiteHTML`, `Sources/TwidgetRenderer/WidgetDOM.swift`, `Tests/LiteHTMLTests`) by a
three-way merge: `git diff --no-index --full-index` between the two upstream trees, paths mapped onto this layout,
applied with `git apply --3way` (the 80dad8c preimages are the pristine commits' blobs). Upstream's delta: +1180/−101
in 33 LiteHTML files — viewport reuse across resizes (`viewportSize`/`dependsOnViewport`), a CoreText
`CTTypesetter` line breaker, `overflow-wrap: break-word/anywhere`, CSS transforms on SVG elements and an SVG group
cache, a background-colour-only patch fast path, `overflow: clip`, box-shadow slicing, and new API (`visualBounds`,
`attribute(_:at:withinAttribute:value:)`, `offsetMetrics`, `textareaMetrics`, `drawInContext:…baseTransform:`);
WidgetDOM +19/−7 (a textarea's value patched as text; `hidesText` without `color:transparent !important`).

Everything merged cleanly except two files, resolved so that every numbered edit below survives:

- `litehtml/src/document.cpp` (`document::update_text_and_style`): edit 10's text-piece pre-count stays in the
  text branch; the style branch is upstream's (it moved `style_change_is_local` into the block for its
  background-colour fast path).
- `LHDocument.mm`, four hunks:
  - the two layout `set_viewport` calls take upstream's viewport height (`_viewportSize.height`) **and** keep edit 7's
    `_doc->viewport_changed()`: upstream's viewport reuse never re-evaluates media queries or viewport units when the
    layout width changes, which is what edit 7 does;
  - the scroll-container dictionary keeps edit 1's `#if TARGET_OS_OSX`, with upstream's new `wheel` and
    `hitViewport` keys in both branches (iOS: `LHValueWithRect`);
  - `boundsByAttribute`'s visitor is upstream's (it carries the ancestors' transform) with edit 6's iOS inline-box
    block inside it (`visit(child, matrix)`).

Two new guards, both edit 1: `-fontWithAttribute:value:lineHeight:baseline:` returns `NSFont *` (declaration in
`include/LHDocument.h` and implementation in `LHDocument.mm` under `#if TARGET_OS_OSX`), and the new test
`SimpleTextTests.testTransparentLeadingShadowMatchesVisibleShadowOnGPU` uses the Metal `RenderGPU` helper, macOS only
like its siblings (see "Tests"). New upstream tests taken: `BackgroundStylePatchTests`, `FontCacheTests`,
`OverflowWrapTests`, `ShadowRasterTests`, `TextPaintExclusionTests` (TwidgetRenderingTests 177 → 223, all passing).
Not adopted: `drawInContext:…baseTransform:` could replace the "tile rule" (root `CLAUDE.md`) for box shadows; the
app no longer draws through `LHDocument`, and its painter (`LayerTreePainter`, through edit 22) still draws tiles into
its own bitmap context. Line numbers in the edits below are 80dad8c's; after the merge
they can be off by upstream's insertions — find an edit by the code it quotes.

## The template path (removed)

`LHDocument`'s update API, and the fork code only it reached, are gone: nothing in the app used them, and the widget
runtime patches a document through the external DOM API (edits 12, 16 to 18). Removed from `LHDocument`:
`initWithHTML:css:previous:` and its `viewportSize:` variant (replaced by `initWithHTML:css:viewportSize:`),
`initWithPrevious:styles:attribute:css:`, `initWithPrevious:changes:attribute:css:`, `reusedPrevious`, `reusedLayout`,
`layoutDirtyRects`, `patchDirtyRects`, `dependsOnViewport` and the consumed-document restore. Removed from `document`:
`createUpdatableFromString`, `update_from_string`, `update_from_template`, `update_structure`, `build_template`,
`apply_template_values`, `update_styles`, `update_holes`, `template_html`, `layout_dirty_regions`,
`last_patch_regions`, `last_patch_paint_only`, `begin_layout_patch`, `class_change_allowed`, `retag_allowed`,
`retext_in_place`, the template's holes and literals, the parse-node tracking, and the file-local helpers only they used;
`apply_retag` lost its `region` and `geometry` arguments (edit 63). The tests of the update API went with it:
BackgroundStylePatchTests, PatchRegionTests, RebuildMemoryTests and StructurePatchTests whole; the update tests of
ContainTests, DocumentFuzzTests, LayoutCacheTests, OverflowWrapTests, StylePatchTests, SubtreeCullingTests,
SVGGeometryTests (the SVG group cache across patches), TextLayoutPatchTests and TextPaintExclusionTests, and the patched
part of TelegramPolicyTests' remote URL count; the fork's update-path text-piece cap checks (`fork_test.cpp`) and a
template class change's style charge (`external_test.cpp`). TwidgetRenderingTests went from 227 tests to 173. Edits
below that mention the template path (`update_document`, `update_structure`, `update_styles`, `update_holes`) describe
how they met it while it existed. New edits state no macOS effect.

## Edits to the vendored sources

In LiteHTML no upstream line was changed or removed: the diff against `751715a0ba` is insertions only. Edits 1-3,
5 and 6 are guards, and with them alone the macOS preprocessed output of every vendored source
(`clang++ -E -P -target arm64-apple-macos11`, blank lines ignored) is identical to the pristine
copy's. Edit 4, Telegram's fork changes, applies to both platforms by design: it changes the litehtml
fork, whose headers every Objective-C++ source includes, and in the Objective-C++ layer only
`AcquireSharedFont`'s tabular-nums block. Measured 2026-10-13: preprocessing the layer and `core/` for
macOS against the same fork headers, before and after edits 4 and 5, differs in `LHContainer.mm`'s
tabular-nums lines and nowhere else. Edit 7 (2026-10-14) also applies to both platforms: it changes the
fork's `document` and, in the layer, adds two `_doc->viewport_changed();` lines to `LHDocument.mm`, the
only macOS preprocessed difference against the commit before it (measured the same way). Edit 8
(2026-10-14) is one line in the fork's `render_flex.cpp`, for both platforms; the layer is unchanged.
Edit 9 (2026-10-14) sets two upstream lines of the fork's `css_properties.cpp` aside under `#if 0` and adds
their replacements under `#else`, for both platforms; the layer is unchanged. Edit 10 (2026-10-14) adds the
text-piece cap to the fork's `document`, `el_text` and `el_before_after`, for both platforms, as insertions
only; the layer is unchanged.
Line numbers below are upstream's.

**The host edits 5–11 name is gone.** They were checked through the ops-fed iOS host of the time
(`MessageWidgetRendering`'s `MessageWidgetRenderer` and `RendererTests`, the `MessageWidgetDocument` guard), deleted
on 2026-10-19 (`a85f21a602`). Their twidget pins stand (`TelegramPolicyTests`, `fork_test.cpp`,
`TelegramViewportUnitTests`); the pins that were `RendererTests` cases went with the host: edit 6's (an inline
element's bounds through `boundsByAttribute:`, which the app no longer calls: WidgetRuntime's `HitTest.h` computes the
same boxes from the render items) and edit 7's two (its `viewport_changed()` still runs in `external_test.cpp`'s
`testRefreshAfterTheLimitEqualsARebuild`).

1. **iOS: AppKit guarded** (`#if TARGET_OS_OSX`, with `#include <TargetConditionals.h>` where nothing
   has defined it yet).
   1. `include/LHDocument.h:1`, `include/LHTextFragment.h:1`, `include/LHImages.h:1`,
      `include/LHGPURenderer.h:1`: `<Cocoa/Cocoa.h>`; iOS imports `<Foundation/Foundation.h>` and
      `<CoreGraphics/CoreGraphics.h>`. `LHContainer.mm:1`: `<Cocoa/Cocoa.h>`; iOS imports
      Foundation, CoreGraphics and CoreText. `LHDocument.mm:2`: `<AppKit/AppKit.h>`; iOS imports
      CoreText. `LHContainer.h:8`: includes `<TargetConditionals.h>`.
   2. The NSImage API is macOS only: `LHContainer.h:24-27` (`@class NSImage`,
      `LHRegisterAppImage`, `LHSetImageProvider`, `LHImageProvider`), `LHContainer.mm:222-272`
      (`CreateCGImageFromNSImage`, and `ColorFromHex`, whose only caller is `LoadSymbol`),
      `:393-394` (the provider globals), `:496-503` and `:513-523` (their definitions),
      `LHImages.h:7-9,13` and `LHImages.mm:4-162` (the NSBezierPath demo images), `:166-179`
      (`registerImage:name:`, `setProvider:`, `provider`), `:216-222` (`registerDemoImages`).
      `forgetImageWithURL:`, `copyImageForURL:`, `prefetchURLs:completion:` and `portableSymbols`
      stay.
   3. `LHContainer.mm:326-366`, `LoadSymbol` (SF Symbols through NSImage): returns `{}` on iOS, so
      `LookupImage` resolves an `sf:` URL through the icon aliases (`LoadIcon`), as
      `portableSymbols` does on macOS.
   4. `LHContainer.mm:398-417`, `LoadProvided`: returns `{}` on iOS. There is no image provider on
      iOS, so only `data:`, `icon:` and `sf:` images load.
   5. `LHContainer.mm:911-1054`, `ResolveFont` and its helpers (NSFont, NSFontManager,
      NSFontDescriptor): macOS only, with an iOS twin through CoreText under `#else` (see below;
      the twin is Telegram's code, written in `8e86935fcc`, and `7e0321a163` changed its member choice and its
      italic there).
      `:1156` and `:1159` (`AcquireSharedFont`) hold the twin's +1 `CTFontRef` where macOS holds
      the toll-free bridged NSFont.
   6. `LHDocument.mm:71-77`, `LHControlAccent`: the `NSColor.controlAccentColor` block is macOS
      only. iOS returns the function's own fallback, `web_color(0, 122, 255)`, the iOS system blue.
   7. NSValue geometry (`valueWithRect:`, `valueWithSize:`, `valueWithPoint:`, `rectValue` are
      AppKit's): `LHDocument.mm:365, 420, 438, 989, 1053, 1369, 1370, 1372, 2295` and
      `LHGPURenderer.mm:546` use, on iOS, `LHValueWithRect`/`LHValueWithSize`/`LHValueWithPoint`
      and `LHRectValue`, added to `LHContainer.h` (after `:31`) under `#if !TARGET_OS_OSX`. They box
      with `[NSValue valueWithBytes:objCType:@encode(CGRect)]` (and `CGSize`, `CGPoint`), the bytes
      and type encoding `valueWithRect:` produces on macOS. Swift reads one with
      `var r = CGRect.zero; value.getValue(&r)`.
2. **iOS: Metal's managed storage guarded** in `LHGPURenderer.mm`: `:250-255` (iOS uses
   `MTLStorageModeShared`), `:447` (`MTLResourceStorageModeShared`), `:508-513` (`didModifyRange:`
   is macOS only; a shared buffer needs none). The GPU path is not used on iOS; it compiles because
   `LHDocument.mm` includes `LHGPUInternal.h`.
3. **iOS: the conic-gradient availability check.** `LHContainer.mm:2871`,
   `if(@available(macOS 14.0, *))` around `CGContextDrawConicGradient`, is true on every iOS, where
   the function is iOS 17 and later; below 17 (Telegram supports 15.0) it would call a missing weak
   import. iOS checks `@available(iOS 17.0, *)`, and older iOS takes the existing
   `DrawConicWedges` fallback. Found with `-Wunguarded-availability-new`, which reports no other
   site in the vendored sources for `arm64-apple-ios15.0-simulator`.
4. **Telegram's fork changes, both platforms** (2026-10-13), ported from the branch's own litehtml
   fork (`third-party/litehtml`, deleted 2026-10-14 when `MessageWidget` moved to this renderer; it is
   in `78acb4f9b9`), with `tests/fork_test.cpp` pinning each one (`:TwidgetForkTests`;
   each check failed before its change).
   1. **`font-variant-numeric: tabular-nums`** (from `2893e94e18`, final form at `34b070085f`): a
      `_font_variant_numeric_` string id (`string_id.h:88`), kept as its text by `style::add_property`
      (`style.cpp:744`), computed and inherited like `font-variant` into
      `css_properties::m_font_variant_numeric` (`css_properties.h:120`, `css_properties.cpp:591`), and
      `font_description::tabular_nums` (`font_description.h:38`), which is in `hash()` (`:61`, only when
      set, as `letter_spacing` and `smoothing` are, so no other font's hash changes). `LHContainer.mm`'s
      `AcquireSharedFont` puts it in its process-wide cache key (`:1147`; without it a tabular and a
      proportional font of one family, size and weight would share one entry) and replaces the resolved
      font by its copy with CoreText's monospaced-numbers feature (`:1159`,
      `CTFontDescriptorCreateCopyWithFeature(…, kNumberSpacingType, kMonospacedNumbersSelector)` and
      `CTFontCreateCopyWithAttributes(font, 0, NULL, …)`, which keeps the size, the matrix of a
      synthesized italic and the `wght` variation: measured on macOS 27; the iOS test checks the size,
      the weight and the digits' one advance). Every width,
      line and simple-shaper glyph is then measured with that font. The system font's digits are
      proportional by default (`1111` 28.4 px, `0000` 39.1 px at 16 px); tabular, both are 39.1.
   2. **A wrapped row's intrinsic width** (`render_flex.cpp:110`, as `599d20928b`): `ret_width` summed
      each line's main size, which holds that line's own gaps, so a wrapped row's max-content width
      lacked the N-1 gaps between lines. A shrink-to-fit box (a float) then came out narrower than the
      content needs: in a 165 px box, `[50][50][50]` with a 10 px gap measured 160, not 170, so the float
      was 160 wide instead of 165.
   3. **Non-finite paint values are unset** (the branch's ruling in `34b070085f`). The tokenizer reads
      numbers in double and stores floats: `1e999` and `1e39` are inf, `0e999` is NaN. A non-finite
      length in `box-shadow` (and `text-shadow`, the same parser) drops the whole value
      (`css_effects.cpp:192`); so does a non-finite number in any transform function's arguments, even
      one the parser otherwise ignores (`perspective`, an off-axis `rotate3d`), and a non-finite value
      computed from them (`:679`, `:779`). A `box-shadow` or `transform` length whose pixels are not
      finite (`1e38em`) is unset too, after unit conversion (`css_properties.cpp:846`, `:898`; a
      `text-shadow`'s converted lengths are clamped where the font is made). And as the ruling also
      says, finite factors can still compose to a non-finite matrix: the fork composes in
      `group_transform` (`render_item.cpp:1143`), at paint time, where it also resolves percentages
      and the `transform-origin` against the box. Before its `return` (`:1185`; `<cmath>` at `:5`) a
      composed matrix with any non-finite entry is the identity, as an unset transform: measured
      before, `scale(1e20) scale(1e20)` reached the painter's `begin_group` as
      `[inf nan nan inf nan nan]`, `translate(3e38%)` on a 200 px box as `tx` inf, `ty` NaN, and
      `transform-origin: 3e38% 0` as NaN `tx`/`ty`.
5. **iOS: Telegram's image policy and the refusal counter** (2026-10-13; all `#if !TARGET_OS_OSX`, so
   macOS is unchanged). Pinned by `tests/LiteHTMLTests/TelegramPolicyTests.mm`, whose refusal
   cases fail without it.
   1. **Data images are PNG, JPEG, GIF, WebP or SVG.** The sanitizer's default `imageMIMETypes`
      (`core/lhx_sanitizer.cpp:118`, with `<TargetConditionals.h>` at `:4`) is
      `image/png image/jpeg image/jpg image/gif image/webp image/svg+xml` on iOS, so `avif`, `bmp`
      and the icon types are removed from author markup (`url-blocked`). SVG data images are allowed
      (decision of 2026-10-14, spec D8; the first version of this edit refused them): they are drawn by
      `LHCreateSVGImage`, the rasterizer that already draws `icon:` images, which loads nothing but
      `data:` images while it renders (`LHRenderingSVGImage()`), so an SVG cannot cause a request.
      `LHContainer.mm`'s `LoadImageFromData` (`:282`) therefore passes SVG through, and before decoding
      any raster image requires `CGImageSourceGetType` to be
      `public.png`, `public.jpeg`, `com.compuserve.gif` or `org.webmproject.webp` (the bytes' own type:
      TIFF bytes behind `image/png` are refused) and `CGImageSourceCopyPropertiesAtIndex` to report
      both pixel sizes, at most 4096 and at most 16 Mpx in all (`TelegramImageSourceAllowed`). It fails
      closed when ImageIO cannot tell.
      SVG bounds (`LHCreateSVGImage`, `LHDocument.mm:2972`): markup of at most 2 MB, nesting depth 1 (a
      `thread_local` depth guard returns null for an SVG met while one renders), a box of at most 16384 pt
      a side, and a bitmap capped at 4096 x 4096 (so 16 Mpx) by the scale clamp. `LoadDataURI` picks SVG by
      a case-sensitive `svg` substring of the header: non-SVG bytes there fail closed (no `<svg>...</svg>`),
      and `image/SVG+xml` goes to the raster sniff, which refuses SVG bytes. `LHCopyImageForURL` now returns
      SVG rasters too; its only callers are `LHImages`' `copyImageForURL:` and `prefetchURLs:`, which
      nothing outside twidget calls.
   2. **Nothing is fetched, and what would have been is counted.** iOS already had no image provider
      (edit 1.4), so only `data:`, `icon:` and `sf:` images ever loaded. `LHContainer::refuse_request`
      counts every other image URL (`twcanvas:` and `app:` included: neither has a source on iOS) each
      time it reaches `load_image` or `get_image_size` (which then return without looking it up),
      `draw_image` or `draw_list_marker` (counted on arrival, before the painter is handed it; drawing
      is unchanged). `sf:` is not counted: on iOS it is drawn from the bundled icon set, like `icon:`
      (edit 1.3). `import_css` and `link` (`LHContainer.h:183`, `:177`; `{}` upstream) count every call,
      but nothing reaches either under the default sanitizer policy: `<link>` is a dropped tag whatever
      the styles' trust, `@import` is not an allowed at-rule in author css, and an `@import` in the host's
      `css:` follows the master stylesheet's rules, so litehtml ignores it. They count only if a later
      policy lets one through.
      In `LHContainer.mm`, `refuse_request` sits before `load_image` (`:2890`), and the calls follow
      `:2891`, `:2897`, `:2907` and `:2959`.
   3. **`LHDocument.refusedRequests`** (`include/LHDocument.h:159`, `LHDocument.mm:2822`) reads the
      container's counter. It counts only what got past the sanitizer (whose removals are
      `sanitizerCounts`): with the default schemes, author markup never reaches it, as the sanitizer
      removes `<link>`, `@import` and every non-`data:` image, so it counts what the host lets through,
      such as its own `css:` (trusted, not sanitized) or an image scheme it allowed with `LHSanitizer`.
      A document made by patching takes over its predecessor's container, so it starts from the
      predecessor's count; the consumed predecessor then reads 0, as its `sanitizerCounts` do, and a
      predecessor rebuilt by a later use counts again from 0.
      One author source does get through (found 2026-10-13): the sanitizer keeps a `<canvas>`'s
      `twcanvas:` `src` (`core/lhx_sanitizer.cpp:241`), and the container refuses and counts it on every
      build, layout and draw. `MessageWidgetRendering`'s `RendererTests.testNetworkRefusalsCountEachDocumentOnce`
      uses it to check how the host adds up the counts of patched and rebuilt documents.
6. **iOS: an inline element's bounds** (2026-10-13; `#if !TARGET_OS_OSX`, so macOS is unchanged).
   `boundsByAttribute:` (`LHDocument.mm:2266`) gave an element the border box of its render item's
   placement (`:2277`). An inline element's render item has no box of its own (litehtml never sets its
   position), so a `<span>` came out as a point, or as just its padding and borders: a span wrapping
   over three lines of a 120 px paragraph measured 0 x 0. The visit lambda (`:2275`) now starts with an
   iOS block that, for a render item whose `for_inline_boxes` reports line fragments, takes the union of
   those fragments (which already hold the padding and borders) moved by `get_placement() - pos()`, as
   `getBoundingClientRect` has it and as the branch's previous, since deleted, core did (`border_box_of` in
   `MessageWidgetCore/Sources/renderer.cpp` at `a4fcdae2c0`); an inline element with no fragment stays
   a point at its placement. The same span now measures 119.9 x 72 (three 24 px lines), and
   `ab` in a span with 3 px padding and a 2 px border 28.0 x 29 from x 0, as WebKit has it. The host's
   hit testing and queries read every box through this method.
   Table rows take the same branch: `render_item_table_row::for_inline_boxes` (`render_table.cpp:586`)
   returns true and reports one box per cell (the cell's border box, its height stretched by the row's
   padding and borders), so a `<tr>`'s rect is the union of its cells, from the first cell's left edge to
   the last one's right edge, the spacing between them included, as WebKit's is. The offset holds for both
   kinds: inline fragments and cell boxes are in the coordinate space of the item's parent, the space its
   own `pos()` is in, so `get_placement() - pos()` is that space's origin in the document. Measured with a
   table placed at (27, 30) inside a padded box, 4 px border spacing: the row is (31, 34, 100, 32), the
   union of its cells (31, 34, 44, 32) and (79, 34, 52, 32), and hit tests at those points find the cells.
   Pinned by
   `MessageWidgetRendering`'s `RendererTests.testFlexContainerAndWrappingSpanHaveRects`, which failed
   without it (the span's height 0); the 176 `:TwidgetRenderingTests` cases pass with it (iOS 26.5,
   hand-built bundle).
   Why here and not in the host's guard (`MessageWidgetDocument`): the line fragments are only on
   litehtml's render items, which `LHDocument` keeps in ivars private to `LHDocument.mm` (`_doc`, under
   `_lock`); no public method hands out an element's fragments or anything they could be rebuilt from
   (`textFragments(maxWidth:)` has no owners, `layoutSignature` skips the zero-sized inline item, and
   `copyImageOfElement`'s ink bounds are drawn pixels, not boxes, at a raster per query). Reaching the
   ivars from another file would mean reading `LHDocument`'s private layout through the runtime.
7. **Media queries and viewport units follow the layout width** (2026-10-14; both platforms, like edit 4).
   litehtml reads the container's media features once, while it parses (`document.cpp:2148`,
   `finalize_from_external_root`), and `update_from_string` never reads them again; `LHDocument` never
   called `media_changed()`. A fresh `LHContainer`'s viewport is zero until the first layout sets it, so
   every document, fresh or patched, matched `@media` width queries against 0 (`max-width` always,
   `min-width` never) and resolved `vw`/`vmin`/`vmax` to 0 (`to_pixels`, `:2890`, reads the stored
   features while styles compute), whatever width it was laid out at, and a width change re-evaluated
   nothing.
   1. `document.h`: `viewport_changed()` (after `media_changed()`, `:246`) and a `mutable bool
      m_viewport_units` (after `m_next_share_id`, `:140`).
   2. `document.cpp`: `to_pixels` (`:2857`) sets `m_viewport_units` when it resolves a `vw`, `vh`, `vmin` or
      `vmax` length. `viewport_changed()` (after `media_changed()`, `:3168`) reads the media features
      again; when the viewport's width or height moved it applies the media lists again and, when a list
      flipped or the document resolved a viewport unit, empties the style-sharing cache (it holds computed
      values, viewport lengths already in pixels), restyles and replaces the root's render subtree (edit 74) as
      `media_changed()` does. A document with neither pays one comparison. The flag misses nothing hidden:
      `html_tag::compute_styles` (`html_tag.cpp:618`) recurses into every child whatever its `display`, so a
      viewport length under `display:none` is resolved, and flags the document, like any other; a patch
      computes its new styles against the document's stored features, which the last layout set.
   3. `LHDocument.mm`: `layoutLockedWithMaxWidth:` calls it right after setting the viewport of the
      preferred-width pass (`:1201`) and of the full-width pass (`:1217`). The narrower viewports of the
      shrink-to-fit passes after it are not the frame's, so they do not move the media features. The
      viewport height there is 0 (`fitViewportHeightLockedWithWidth:` sets the document's height only for
      its second render, and does not call it), so height queries and `vh` still see 0, as before: a
      widget's height follows its content, so a height-relative unit has nothing stable to resolve against.
      Nothing calls `media_changed()`; code that adds a call will see the fit pass's height in the
      container and restyle against it.
   Measured through the iOS host (`MessageWidgetRendering`'s `RendererTests`): before, `@media
   (max-width: 400px){div{height:20px}}` applied at 500 px as at 360 px (20 px both), and a `50vw` box
   was 0 wide at 360 and 500; after, the rule gives 20 at 360 and 10 at 500, follows `setWidth(500)` and
   back, holds in a document patched at either width (a `class` change, `reusedPrevious` measured) and
   follows a later width change from one; the `50vw` box is 180 at 360 and 250 after
   `setWidth(500)`. `testMediaQueriesFollowTheWidth` and `testViewportUnitsFollowTheWidth` failed before
   (5 assertions), pass after; the 176 `:TwidgetRenderingTests` cases and the host `cc_test`s pass with it.
8. **A flex container is registered with its element** (2026-10-14; both platforms, like edit 4).
   `render_item_flex::init()` (`render_flex.cpp:375`) never called `src_el()->add_render(shared_from_this())`,
   which `render_item::init()` (`render_item.cpp:2067`), `render_item_block::init()` and
   `render_item_table::init()` all do (grid has no `init()` of its own and takes the base's), so a flex
   container's element had no render item. Hit testing lost it: `get_child_by_point`
   (`render_item.cpp:1614`), carrying a hit up through the static ancestors of a positioned element (the
   `draw_positioned` pass), keeps it only if `run_on_renderers` finds one of its render items that passes the
   caller's check (`:1741`, `:1768`), and for a flex container it found none. So a point over a flex
   container, between its items, inside a `position: relative` element, hit that element's parent instead.
   In the fixture `04-poll` every option is a relative `<button>` holding a flex row, and a tap in the middle
   of an option, between its name and its percentage, landed on `#opts`: no vote. That failed
   `MessageWidget`'s `InstanceTests.testSendMessageOnlyFromATapAndOncePerTap`, in both executor modes,
   once `MessageWidget` moved to this renderer. The fix is the missing line, first in `init()`.
   Why in litehtml and not in the host: the hit is dropped inside `get_child_by_point`, before
   `attribute:atPoint:` (`LHDocument.mm:2003`) sees a result. Calling it without a check skips
   `run_on_renderers`, but the check is how `pointer-events: none` is honoured.
   The registration also puts a flex container's render item on every path that walks an element's render
   items, which upstream's other containers were already on: `element::get_placement` (a flex container's
   placement was an empty box: the fork test's row now measures 280 px wide, 0 before), `mark_layout_dirty`,
   `find_styles_changes` (its redraw boxes), `v_scroll`/`h_scroll`, `get_render_item` (so a restyle confined to
   a flex container now starts its relayout there rather than at the nearest ancestor with a render item,
   `document.cpp:2729`) and `for_each_render_item` (`LHDocument.mm:1009`, the incremental relayout's regions).
   The check for those is that the suites pass, not a proof that each was wrong before: the 176
   `:TwidgetRenderingTests` cases and the 23 `MessageWidgetRenderingTests` (iOS 26.5, hand-built) pass with it,
   and for each of the fixtures `01`–`05`, after taps (`02` `+ + −`, an `03` question, a `04` vote and send)
   and a 1.2 s run (`05` ticks), the patched document and one built fresh from the same HTML have the same
   height and the same pixels at 2x (probe, not committed). Pinned by `tests/fork_test.cpp`
   (`:TwidgetForkTests`): a point between the items of a flex row in a relative box hits the row (it hit
   `#o` before), and the row is 280 px wide.

9. **A line height keeps its fraction** (2026-10-14; both platforms, like edit 4). twidget `4f877c7`
   (2026-10-11, "LiteHTML: Match WebKit line heights and border-box max-width") floors both computed
   line-height branches of `css_properties::compute` to a whole pixel: a number (`css_properties.cpp:276`)
   and a length (`:280`). WebKit does not. Measured on macOS 27 (`WKWebView`, 2026-10-14): at 15 px,
   `line-height` `1.35`, `135%`, `1.35em` and `20.25px` all compute to 20.25 px and two lines are 40.5 px
   tall; `11.5px monospace` at `1.5` is 17.25 px. Floored, every fractional line box came out short by its
   fraction and nothing else differed: in fixture `01` every element had WebKit's width and every box
   without text its height; only the line boxes were shorter (17 against 17.55, 18 against 18.89, …), and
   the offsets below them by their sum. Each of the two lines is now under `#if 0`, with the expression
   before `4f877c7` under `#else`. The same commit's other half, the border-box `max-width` relayout in
   `render_block.cpp:289`, is kept: with only the floor gone the fixtures already equal WebKit.

   The fixtures at 360 and 240 px, through `MessageWidgetInstance` (iOS 26.5 and 27.0 alike). The renderer
   rounds a document's height up, so WebKit's is compared rounded up too:

   | fixture | before (floored) | after | WebKit | WebKit, rounded up |
   |---|---|---|---|---|
   | 01 | 314 / 331 | 319 / 336 | 318.11 / 335.66 | 319 / 336 |
   | 02 | 323 / 323 | 327 / 327 | 326.64 / 326.64 | 327 / 327 |
   | 03 | 313 / 326 | 314 / 328 | 313.89 / 327.39 | 314 / 328 |
   | 04 | 298 / 319 | 302 / 323 | 301.03 / 322.63 | 302 / 323 |
   | 05 | 166 / 166 | 169 / 169 | 168.19 / 168.19 | 169 / 169 |

   Before, `01` was 5 pt short at both widths, past the 4 pt `MessageWidget`'s `AcceptanceTests` allow,
   and `02` and `04` exactly 4. Pinned by `tests/fork_test.cpp` (`:TwidgetForkTests`): at 15 px,
   `line-height` `1.35`, `1.35em` and `20.25px` each make a 20.25 px block, each starting where the one
   above ends (20 px each, 5 failures, before). No other test pinned the floor: the 176
   `:TwidgetRenderingTests` cases (`WebKitParityTests` among them), the 23 `MessageWidgetRenderingTests`
   and `MessageWidgetTests` pass with it (iOS 26.5, hand-built).

10. **Text pieces are capped per document** (2026-10-14; both platforms, like edit 4). litehtml makes one
    `el_text` per word and one `el_space` per whitespace character, each with a full `css_properties`
    (~2.8 KB per piece with its layout, measured at -O0), and nothing capped them: `max_build_elements`
    (20,000) counts tags only. A message could therefore exhaust memory through text that fits well inside
    the validator's limits, in three ways: a text node (`'a '.repeat(5e5)`, 1 MB, made 1,000,000 pieces),
    a whitespace run between blocks (one `el_space` per character), and `::before`/`::after` content,
    which is made again for every element a rule matches: 3.5 KB of HTML (200 `<b>` and one 1,000-word
    `content`) made 400,000. A patch that changes a text run makes its pieces outside `create_node`.
    1. `document.h`: after `take_table_cells` (`:58`), `max_text_elements` (10,000), `note_text_element`,
       `text_elements()` and `text_element_allowed()`; after `m_build_limited` (`:145`), the live count
       `std::atomic<int> m_text_elements`, `m_text_limited` and `m_text_allowance` (5. below).
    2. `el_text.h:21`, `el_text.cpp:15`: the constructor adds one to its document's count and a new
       destructor takes it away (`el_space` derives from `el_text`), so the count is what is alive, through
       patches, in-place retexts and restyles alike. A document being destroyed no longer resolves from its
       elements and needs no count.
    3. `document.cpp`: `text_element_allowed()` (before `forget_positions`, `:1238`) answers false at the cap
       and reports `sanitizer_limit("text")` once per document. `create_node` asks it before every piece of a
       text node (`:2458`) and every character of a whitespace run (`:2502`), and past the cap makes no more
       and sets `m_build_limited` (so the next update builds afresh, as for the tag cap).
       `apply_template_values` (`:976`) counts, with the container's `split_text`, the pieces each changed
       text run would make (`:1000`) and refuses the patch (`-1`) before changing anything when the document
       would pass the cap; the caller then patches the structure or builds afresh, both capped.
    4. `el_before_after.cpp`: `add_text` (`:85`) asks before each piece it makes (`:107`, `:105`, `:128`)
       and stops at the cap.
    5. `update_structure` (`:1554`; added in the final review's fix round, 2026-10-14): a structure patch makes
       its new pieces while the pieces they replace are still alive and counted, so under the cap it came out cut
       (a 5,999-piece paragraph patched to new words plus a `<div>` held 4,001 pieces, and LHDocument drew that
       patched tree). After `diff_children` (`:1902`) and before anything changes, it counts the pieces the plan
       drops (the replaced children's subtrees) and makes (the new gumbo subtrees, through `split_text`, one per
       whitespace character, one for a `<script>`'s text), refuses the patch (`false`) when the document would
       pass the cap, so LHDocument builds afresh from zero and under the cap, and otherwise lets the rebuild loop
       (`:1953` to `:2003`) make its pieces past the count of those it replaces (`m_text_allowance`, reset after
       the loop). Pinned by fork_test: that paragraph is patched in place and holds 6,000 pieces (4,001 before;
       with the allowance removed, a mutation, it is 4,001 again), and a patch adding a 60,000-piece subtree is
       refused (it was accepted and cut).

    What the cap does not cover, measured: form controls' generated parts (`el_form.cpp`'s `append_content`, an
    `el_text` inside a generated `html_tag`) neither ask nor count against the tag cap, so a page of bare
    `<input>`s passes both caps: 10,505 of them (the most that fit in `MessageWidgetRenderer.maximumContentBytes`)
    make 10,505 pieces and 31,518 elements, +130 MB and 610 ms (the final review's probe). The bound on a
    document is therefore the host's 256 KiB HTML cap, not these caps. A `<style>`'s text is split into pieces
    like any text, and an updatable document (LHDocument's) keeps them alive through its node map after the
    stylesheet is read, so CSS counts against the cap; the validator minifies CSS, and the fixtures' live counts
    are 84-249. One `::before` content is held three times at the peak of a build (two pseudo elements alive at
    once, and `add_style` keeps the old children while it makes the new ones), so a single content past about a
    third of the cap is cut; left as is.

    Why a separate cap, and 10,000: a piece costs ~2.8 KB against ~3.7 KB for a tag, so sharing
    `max_build_elements` would have let text add another ~55 MB to the ~73 MB 20,000 tags already allow;
    10,000 pieces is ~27 MB (form controls aside: see below). The fixtures `01`–`05` and `10` use 45–205 in the
    tree (`03` the most), 84–249 alive, the attack corpus
    pages fewer, and a 900 pt bubble shows far fewer than 10,000. Some pieces outlive their tree in
    litehtml's caches for a while (1 after a text patch, 3–7 after a restyle, measured); they hold memory, so
    they count, and the difference stays constant over patches.
    Measured on the host (`litehtml_test::TestContainer`, -O0, macOS, phys_footprint after the layout):

    | page | before | after |
    |---|---|---|
    | `<p>` + `'a '` × 500,000 (1 MB) | +2,617 MB, 4,866 ms | +43 MB, 197 ms |
    | `<p>` + `'a '` × 100,000 | +529 MB, 897 ms | +29 MB, 75 ms |
    | 20,000 spaces | +52 MB, 65 ms | +26 MB, 32 ms |
    | 200 `<b>`, `b::before{content:"a a … (1,000 words)"}` (3.5 KB) | +1,062 MB, 1,487 ms | +27 MB, 37 ms |
    | 20,000 `<b></b>` (no text; the tag cap) | +70 MB, 182 ms | +73 MB, 171 ms |

    The rest of the 1 MB page's 197 ms is reading it: gumbo's parse and `split_text` take ~45 and ~110 ms
    for 1 MB (55 and 22 ms for 512 KB), and a text node is still split whole. `MessageWidgetRenderer` caps
    the HTML it builds from (`maximumContentBytes`), which bounds that. Pinned by `tests/fork_test.cpp`
    (`:TwidgetForkTests`): a 60,000-piece text node, a 30,000-character whitespace run, the `::before`
    amplifier (50 `<b>` × 2,000 pieces), a patch that grows a text run to 60,000 and one that adds a
    60,000-piece subtree each end at the cap (5 failures before: 60,000, 30,002, 100,000, 60,000 and 60,003
    pieces); and over 40 patches of a ~6,000-piece run and 30 in-place restyles of 400 `::before` contents
    (~240,000 and ~48,000 pieces made) every document holds its whole text and the count stays its tree's
    plus a constant. With the destructor's decrement removed (a mutation, not committed) both loops fail.
    The 176 `:TwidgetRenderingTests` pass with it (iOS 26.5, hand-built).

These eleven are the whole edit set as of 2026-10-14; edits 12 and 13 follow the viewport-unit entry below.

11. **Viewport units are cached per viewport** (2026-10-14, with the b5878f9 re-vendor; both platforms, like edit 4).
    Since b5878f9, `fold_math` (`css_parser.cpp`) turns `vw`/`vh`/`vmin`/`vmax` (and their `s`/`l`/`d` variants) into
    pixels while a declaration is parsed, against the container's viewport, and `style::add`'s process-wide
    `declaration_cache` (`style.cpp`) is keyed by the declaration's text alone — so a document built at another
    viewport received the first document's fold (a `50vw` measured at 360 stayed 180 px in a document built at 500).
    The key now carries the container's viewport width and height when the declaration's text may hold a viewport
    unit (`declaration_may_hold_viewport_unit`, a conservative scan for `v` followed by `w`, `h` or `m`). Pinned by
    `tests/LiteHTMLTests/TelegramViewportUnitTests.mm`, which fails without it. Upstream builds a document at its real
    viewport (`initWithHTML:css:previous:viewportSize:`) and rebuilds it when the viewport changes and it depends on it;
    `MessageWidgetDocument` does the same (it builds at the width laid out at, height 0, and rebuilds a
    viewport-dependent document on a width change). Edit 7's `viewport_changed()` stays: with the fold, it is what
    re-evaluates `@media` for a relayout that does not rebuild.

12. **A document built from an external DOM; the master CSS in C++** (2026-10-18, M1c Task 1; both platforms, as insertions
    only). The native widget runtime builds a litehtml document element by element from its own DOM, with no HTML
    string. Fork `document.h` gains public `insert_child(parent, index, child)` (splices through the parent's own
    `appendChild`, so a `<style>` still takes text only, then moves the new last child to `index`),
    `remove_child(child)` (unlinks, and re-points `m_over_element`/`m_active_element` to the former parent when they
    were the child or inside it), `append_text(parent, text, pieces)` (what `create_node` does for a gumbo text node,
    `document.cpp` `GUMBO_NODE_TEXT`: `split_text`'s words and one `el_space` per whitespace character, each piece
    asking `text_element_allowed()` first, and one piece inside `<style>`/`<script>`) and
    `external_element_allowed(depth)` (the cap check at `document.cpp:2586`, `max_build_depth` 256 and
    `max_build_elements` 20,000, reporting `sanitizer_limit("depth")`/`("elements")`). They are implemented in the new
    `src/telegram_external.cpp` (+ `include/litehtml/telegram_external.h`); with the existing `create_element`,
    `set_document_mode` and `finalize_from_external_root` they are the whole external build. Names pass as the
    caller holds them: SVG's `linearGradient` and `viewBox` build the same document the parse does (pinned). The
    one difference from `create_node` is that a `<style>`'s text is one piece, not split, so its piece count (and
    its `text_elements()` share) is smaller; `get_text` concatenates to the same sheet.
    `LHDocument.mm`'s `MasterCSS()` (litehtml's `master_css` with `a:link` replaced, plus twidget's additions) moved
    to `litehtml::telegram_master_css()` (`src/telegram_master_css.cpp`), so host tests lay out against the app's
    user-agent sheet; the Objective-C++ body is set aside under `#if 0` and the function returns the shared one. Pinned
    by `tests/external_test.cpp` (`:TwidgetExternalTests`), which did not compile before the edit (the entry points
    did not exist): the build matches the parse on a styled document and on an SVG (placements and recorded paths),
    insertion at every index, hover re-pointing on removal, the 10,000-piece text cap, the depth/element caps against
    `create_node`'s counts (300-deep chain, 20,001 siblings), and the master sheet's contents.
    **macOS effect:** none for documents parsed from strings, because the new entry points have no caller there;
    the only changed macOS path is `LHDocument.mm`'s `MasterCSS()`, which returns the byte-identical sheet.

13. **The colour scheme in litehtml** (2026-10-18, M1c Task 2; both platforms). The native runtime has no validator, so
    the theme features the JS validator rewrote in CSS text (`policy.md` §5) are understood by litehtml itself.
    `media_features` (`types.h`) gains `int color_scheme = 0` (0 light, 1 dark), which the container fills in
    `get_media_features`. `src/media_query.cpp`: `prefers-color-scheme` is a discrete keyword feature with the values
    `light` and `dark` (new string ids `_prefers_color_scheme_`, `_light_`, `_dark_`); it is true in boolean context, and
    any other value (`no-preference`) is an invalid feature, so the query matches nothing. `src/web_color.cpp`:
    `parse_color` resolves `light-dark(<color>, <color>)` to the scheme's branch through the container's
    `get_media_features` (the new `container_color_scheme`); nested ones resolve, and anything but two comma-separated
    colours (`light-dark(url(#a), red)`) is not a colour, so the declaration is dropped. `src/style.cpp`: a `color-scheme`
    naming both `light` and `dark` gives the container's scheme, `dark` alone gives 1, anything else 0 (the upstream
    `dark && !light` line is set aside under `#if 0`); form controls read it through `get_dark_scheme()`. The three
    caches are keyed by the scheme: `document.cpp`'s master-sheet cache (`master_key`, the text prefixed by a scheme
    byte; the upstream `find` and `emplace` lines are under `#if 0`) and author-sheet cache (`styles_key` gains a
    scheme byte), and edit 11's declaration cache in `style.cpp` (`style::add`'s key gains a scheme byte whenever there
    is a container). Pinned by `tests/scheme_test.cpp` (`:TwidgetSchemeTests`): `@media (prefers-color-scheme: ...)`,
    boolean and `no-preference`; `light-dark()` in `color`, `background-color`, `border-color`, nested, invalid, and in
    a `style` attribute; `color-scheme`; and the same sheet, `style` text and master sheet in a light then a dark
    document in one process (30 failures before the edit; with the `styles_key` byte removed the cache cases fail).
    **macOS effect:** Telegram-Mac's container reports `color_scheme` 0, so `(prefers-color-scheme: light)` now matches
    there and `light-dark()` resolves to its first branch; before this edit the feature and the function were unknown.
    **Today's iOS path never reaches the new code:** its validator rewrites all three before litehtml parses
    (`policy.md` §5), and `LHContainer` reports `color_scheme` 0. A scheme change in place: edit 80.

14. **CSS component nesting is bounded** (2026-10-18, M1c Task 2b; both platforms, as insertions only). litehtml's
    componentizer recurses once per block (`css_parser::consume_simple_block` and `consume_function` through
    `consume_component_value`, `css_parser.cpp`; `componentize` drives it) and deep-copies each finished block into its
    parent, so 64 KiB of `(` nests about 65,000 deep and overflows any stack. The native runtime has no validator in
    front of it: sheets, `style` attributes and every attribute litehtml parses as CSS (`width`, `bgcolor`, SVG `fill`)
    reach it directly. `css_parser.h` gains `constexpr int max_component_depth = 64` (the bound of WidgetRuntime's
    selector pre-walk, `kMaxBracketDepth`), a `m_depth` member and `skip_block`. A block or function that would open
    with 64 already open is not recursed into: `skip_block` consumes its tokens up to the matching closer by an
    iterative bracket count (the componentizer's rules: a function or an opening bracket opens a block; a closing token
    closes only the innermost block, and only its own kind; the end of input closes every block) and it becomes an empty
    block of the same kind, so the declaration or rule holding it is invalid as a bad value is. The parse is otherwise
    unchanged, and everything that recurses on component nesting (edit 13's nested `light-dark()`, nested at-rule blocks,
    nested functional selectors) is bounded with it; `calc()` folding keeps its own bound of 16. The copying is at most
    64 times the tokens. Pinned by `tests/css_nesting_test.cpp` (`:TwidgetCssNestingTests`), each deep case on a
    512 KiB thread: a sheet with 100,000 nested `(` keeps its neighbouring rules and not the width; 100,000 `(` in a
    `width` attribute and 100,000 `calc(` in a `style` attribute; 10,000 nested `light-dark(`; and nesting within the
    bound unchanged (`calc` 10 deep, `:is(:is(:is(q)))`, `@media` in `@media`). The three deep cases died of SIGBUS
    (a stack overflow, exit 138) before the edit.
    **macOS effect:** the same bound on Telegram-Mac; only CSS nested deeper than 64 changes, and it was a crash
    before. **Today's iOS path is covered too:** it parses the serialized HTML through the same code.

15. **List-valued CSS is capped at parse** (2026-10-18, M1c Task 5b; both platforms, as insertions only, except one
    `#if 0`/`#else` pair). litehtml keeps a declaration's tokens in every element's style, twice for the properties in
    `raw_declaration_names` (the raw copy, `style.cpp`'s `add_property`), and builds a per-element list from them that
    each entry paints, so a long list costs its length times up to 20,000 elements; only the CSS byte caps bounded
    it. Measured before: a 100-entry `box-shadow` on 1,000 divs grew the heap by 105 MB. `css_parser.h` gains
    `constexpr size_t max_css_layers = 8` and `max_css_list = 32`. Entries past the cap are dropped, the first ones
    are kept and the declaration stays valid.
    1. **`style.cpp`, `add_property`** cuts the tokens before anything keeps a copy (`cap_list_value`, called after
       the `-webkit-backdrop-filter` rename and before the raw copy is stored; the call re-enters `add_property`
       with the cut value, as the `fold_math` branch does):
       - 8 layers (top-level comma groups): `box-shadow`, `text-shadow`, `background`, `background-image`,
         `background-position`, `background-size`, `background-repeat`, `background-attachment`,
         `background-origin`, `background-clip`. In a `background` cut to 8 layers the colour is the 8th layer's,
         if it has one: the final layer, which carried it, is dropped.
       - 8 functions: `filter`, `backdrop-filter`, `transform`.
       - 32 (+1 for a leading direction or fill rule) comma groups inside a function's arguments: gradient colour
         stops in `background`/`background-image`, and `clip-path: polygon()` points.
    2. **`css_effects.cpp`** caps what the parsers build, for any caller: `parse_box_shadow` (the shared parser of
       `box-shadow` and `text-shadow`) drops entries past 8; `parse_filter` and `parse_transform` stop after 8
       functions (`parse_filter`'s `tokens.size() > 32` rejection, which made a longer filter invalid, is set aside
       under `#if 0`); `parse_clip_path` keeps 32 polygon points.
    3. **`gradient.cpp`**, `parse_color_stop_list`, keeps 32 colour stops (a two-position stop is two).

    **Every list-valued property found.** Capped: the ones above. Left alone: `grid-template-columns/rows`,
    `grid-auto-rows` (a `repeat()` count is clamped to 1000 by `parse_grid_track_list`; a grid container is
    rare, but it is the one list left that can multiply), `stroke-dasharray`, `font-family`, `counter-increment`,
    `counter-reset`, `content`, the `transition-*` and `animation-*` lists (raw declarations only, read when an
    animation is built), SVG `<stop>` children (elements, bounded by the 20,000-element cap), and `mask` (not
    supported by the fork: only SVG's `mask` attribute exists). `text-shadow` is also cut at 8 where fonts are made
    (`css_properties.cpp`, the `i < 8` over the extra shadows); the parse-time cap applies on top of it.
    Pinned by `tests/css_lists_test.cpp` (`:TwidgetCssListsTests`): each capped property given 100 entries holds
    the cap's number (18 checks failed before the edit, the first entries are the ones kept, and the declaration
    after the long one still applies); a list of exactly the cap, and the corpus maxima (6 background layers with the
    colour on the last, 1 shadow, 2 filter functions), are unchanged; and 1,000 divs with a 100-shadow `box-shadow`
    grow the heap by 14.4 MB (105 MB before; 6.2 MB is 1,000 divs with no list at all), with 100 stops, 100
    layers and 100 polygon points at 16-20 MB, 100 filters (8 kept) at 9.7 MB and 100 transforms (8 kept) at
    13.2 MB (Ruling E12: 32 kept cost 33 MB, about 330 MB at 10,000 elements; the corpus uses at most 3 transform
    functions and 2 filter functions).
    **macOS effect:** the same caps on Telegram-Mac; only lists past a cap change, and a `filter` of more than 32
    functions, invalid before, now keeps its first 8. **Today's iOS path is covered too:** it parses the
    serialized HTML through the same code.

16. **Text patched in place** (2026-10-18, M1c Task 7; both platforms, as insertions only). The native runtime's flush
    patches a text change into the published document instead of building a new one (Ruling 8). Fork `document.h`
    gains public `replace_text(parent, first, count, text, pieces)`, `can_replace_text(parent, first, count, text,
    pending_growth, growth)` and `commit_patch()`, implemented in `src/telegram_external.cpp` (the file of edit 12),
    and private patch-session members (`m_patch_pending`, `m_patch_keep_tree`, `m_patch_text_base`, `m_patch_growth`,
    `m_patch_new_text`).
    1. **`replace_text`** replaces `count` pieces of `parent` from child index `first` with `text` split as
       `append_text` splits it (`split_text`'s words, one `el_space` per whitespace character; always new pieces, even
       at the same count), through `element::m_children` as `element::replace_children` does. It re-points `m_over_element`
       and `m_active_element` away from a replaced piece to the parent, tries `replace_text_renderers` (the render tree
       is kept when the run's renderers are a run among the children of the parent's render item, which is its inline
       context or, for an inline element, its own item (a `<span>`'s pieces, which its inline context lays out), beside
       other children or not; only that run is replaced, the original under `#if 0`; otherwise the parent is a seed of
       the commit's replacement, edit 74, which is always correct), and collects the new pieces for `commit_patch`.
       `pieces` is assigned. WidgetRuntime's mirror then re-captures the inline context's runs (an inline element's
       through `ItemInfo::runOf`), and publishes anew where a paint group in the line holds a run of its own.
    2. **`can_replace_text`** is the single predicate, so a caller can plan before it changes anything: false for a
       raw-text parent (`<style>`, `<script>`), a parent inside a `select`, `option`, `optgroup`, `datalist`,
       `textarea`, `input`, `progress` or `meter` (their generated content reads the text; a `<button>`'s does not:
       `el_button` draws its bezel around its children, `testButtonTextIsReplacedInPlace`; an `<svg>` draws its subtree
       itself from its render item, an image, so text under it replaces the svg's render subtree through edit 74's
       boundary, `testStructureInsideAnSvg`), a
       run that is not `count` `el_text`/`el_space` pieces in range, and a text that would take the document
       past `max_text_elements` (+ the allowance of edit 10). The cap counts logically: `m_text_elements` at the start
       of a session plus the net growth of the session, and a caller's `pending_growth` for replacements planned and
       not yet made, because the replaced pieces stay alive until the render tree lets go of them. A refusal changes
       nothing and calls no container hook (`sanitizer_limit("text")` is not raised); it names why (edit 76), and
       WidgetRuntime walks the cut at the text-piece cap and hands any other refusal to its next path.
    3. **`commit_patch`** runs `restyle_after_patch` (the private function the template-hole path uses) over the new
       pieces with the tree kept or its seeds' boundaries replaced as above, `forget_positions()` when kept, and clears
       the paint-only and confined-region state, which describes only template patches. It does nothing when nothing was
       collected. The caller lays out afterwards (`render()`). Edits 17 and 18 (attributes, structure) collect into the
       same session: WidgetRuntime's structure flush replaces a kept Text's pieces after its insertions and removals, and
       a run whose parent's children the session changed is not one for one with its render item's, so the parent is a
       seed.
    Pinned by `tests/external_test.cpp` (`:TwidgetExternalTests`), which did not compile before the edit (none of the
    three existed): `testReplaceTextMatchesFresh` (same piece count, more words wrapping, fewer words, whitespace only
    both ways, inside `pre`, `li`, `div`, and two replacements in one session; each patched document's placements,
    height and draw calls equal a fresh build of the final text), `testReplaceTextBesideElements` (a run beside
    elements equals a fresh build), `testReplaceTextRefusals` (`<style>`, a `select`'s `option`, a
    `button`, a run out of range or not text, and the cap with `pending_growth` and a session that replaces and grows;
    each refusal leaves the document and `pieces` as they were), `testReplaceTextRepointsHover` and
    `testReplaceTextBesideStructure` (beside a removal and an insertion in another parent the run is replaced and its
    inline context kept; after an insertion before it or its sibling's removal in its own parent; each equals a fresh
    build). Mutation checks:
    keeping the tree when `replace_text_renderers` fails fails `testReplaceTextBesideElements`; restyling nothing at
    commit fails `testReplaceTextMatchesFresh`. WidgetRuntime's `testTextInAnInlineElementKeepsTheTree` pins the
    kept tree in a `<span>`, a `<b>`, beside an `<i>` and a `::before`, and the new mirror where a paint group follows.
    **macOS effect:** the entry points have no caller in the Objective-C++ layer, and the new members are only read by
    them; `replace_text_renderers` is also the template path's (a text hole), which since the amendment keeps the render
    tree for a hole in an inline element or beside other children (`TwidgetRenderingTests`' random text runs equal a
    fresh layout).

17. **Attributes and inline style patched in place** (2026-10-18, M1c Task 8 and its fix round; both platforms, insertions
    plus two `#if 0`/`#else` pairs). The flush of edit 16 extends to an attribute change. Fork `document.h` gains
    public `set_element_attributes(el, attrs)` and `can_set_element_attributes(el, attrs, pending)` (and the one-attribute
    `set_element_attribute` / `can_set_element_attribute`, thin wrappers), `attribute_growth`, `pseudo_content_possible()`,
    `attribute_rematches()` and `table_cells()` (tests), private `attribute_change_allowed`, `attribute_target`,
    `begin_patch_session`, `release_pieces`, and session members `m_patch_restyle`, `m_patch_hold`, `m_patch_released`;
    implemented in `src/telegram_external.cpp`.
    1. **`can_set_element_attributes`** is the single predicate, so a caller plans before it changes anything. `attrs` is
       the element's complete new attribute map (lowercased names). False for: an element outside the types `apply_retag`
       re-reads completely (`attribute_patch_kind`'s `html_tag`, `el_div`, `el_para`, `el_td`, `el_tr`, `el_body`,
       `el_break` (it reads none of its own) and `el_button`, which reads `disabled` again when restyled, and `el_image`, `el_anchor`, `el_input`, `el_svg` and
       `el_table`, whose `parse_attributes` maps its presentational attributes, checked against a fresh build; a select,
       option, textarea, font, style, link and the rest are seeds of a replacement, edit 74); one not under the document
       root or inside a `<select>` (a changed `id`, `class` or attribute name that a selector names in an ancestor
       position, or sibling selectors in the sheets, is matched over its reach: edit 77; counters run again in a build's
       order: edit 78); and the two caps a fresh build enforces where a match or a layout makes things:
       - **pseudo-element content.** Matching again makes the element's `::before`/`::after` content, asking
         `text_element_allowed()` for each word; a build makes all of it after the text, in document order, so at
         `max_text_elements` (or the pseudo-element cap) a patch and a fresh build cut at different words: the patch
         cuts the element it matched again, a build the later element's content (bounds on the pieces were tried and
         fell to function-name case and spacing, `ATTR(`, `attr (`, and to overlap with other elements' rules). Near a
         cap the commit replays the style pass in a build's order (edit 84), so the patch cuts where a build does.
         `pseudo_content_possible()`, computed from the selectors as litehtml parsed them (a pseudo-element
         `before`/`after` in the rightmost compound and a `content` declaration that is not empty or `none`; a rule naming
         a tag counts only when the document has an element with that tag, so the master sheet's `summary::before` and
         `details[open] > summary::before`, which declare content, matter only in a document with a `<summary>`; a rule
         for an `lh-*` part, or a `*` rule, wherever the document has an `input`, `select` or `textarea`), is read by the
         replay's gate. It is recomputed on the first query after each `commit_patch`. `text_element_allowed` (under
         `#if 0`/`#else`) counts logically in a patch session (not the pieces the session replaced or forgot, kept alive
         in `m_patch_hold` until `commit_patch`).
       - **table cells.** A `colspan`/`rowspan` change that raises the cell product (clamped to 1000 each, as
         `table_grid::add_cell` reads them) adds the rise to the caller's `pending.cells`. Nothing refuses it: a
         replacement that moves the cap's cut replaces the root, which recounts the cells as a build does (edits 74, 84).
       The container's `sanitize_element` is not asked: nothing validates (Ruling 2).
    2. **`set_element_attributes`** answers false, changing nothing, where the predicate does; true and nothing where the
       element already holds the map. Else it bumps `m_match_epoch`, joins the patch session of edit 16 (starting one),
       and re-matches the element ONCE with `apply_retag` (children swapped out, the sheets applied again,
       `parse_attributes` re-run; the render tree kept only for the first group of types and only when `apply_retag`
       finds the change neutral). litehtml's own `list_index` attribute is kept. An `input`'s generated `lh-*` parts are
       removed first (through `remove_child`, re-pointing hover), because `el_input::parse_attributes` removes them from
       the children it sees, and with them swapped out it would see none. An `a` loses its `:link` pseudo-classes first.
       **The match-epoch bump is load-bearing:** `apply_matching` keeps a memo keyed by (epoch, own attributes) and
       replays its rules through the non-virtual `apply_selector`, which never reaches `el_anchor::apply_stylesheet`, the
       only place `:link` is pushed; without the bump `href` x, y, x, y reuses the `{href:y}` memo and leaves an anchor
       with `href` and no `:link`. A `style` change goes through litehtml's own inline-style parsing at
       `compute_styles`.
    3. **`commit_patch`** (edit 16) also passes `m_patch_restyle` to `restyle_after_patch` (its one line set aside under
       `#if 0`/`#else`) and, after the restyle, lets go of what the session held.
    Pinned by `tests/external_test.cpp` (`:TwidgetExternalTests`): `testSetAttributeMatchesFresh` (class added, swapped
    and removed, id, local and background-only `style`, `hidden`, `checked`, `value`, `placeholder`, `type`, `img src`,
    `a href`, an svg shape's `fill` and `r`, several attributes in one session, same value), `testSetAttributeRefusals`
    (ancestor-position class, id and attribute, `:nth-child`, `:first-child`, `+`, a counter, `option`/`select`, `--`,
    `var(`, an inline `counter-reset`, table, textarea, button, an element outside the document, null and empty names)
    and
    `testSetAttributeFixRound` (`a:link span` both ways; href x, y, x, y keeps `:link`; one re-match for a map; the svg
    element, body's `style`, `viewBox`, `xlink:title`, `Fill`; five sheets with pseudo content (plain, `ATTR(`, `attr (`,
    the overlap shape, `:after`) at 0 to 5,004 filler words: an attribute and then a text patch equal a fresh build
    where no cap is reached, and both are refused once a build has reached one; sheets whose pseudo rules make no
    content (`color` only, `content:none`, content on a real element, `::first-line`) patch near the cap and equal a
    fresh build, limits included; the master's `summary::before` is pseudo content only in a document with a
    `<summary>`, which patches; a `type` change to `range` and a text patch refused near the cap under an `lh-*` part
    rule; the table-cell cap, with `pending`). Mutation checks: keeping the generated parts
    of an input, not resetting `:link`, keeping the tree always, dropping the scope check, dropping the epoch bump (only
    the href round trip sees it), dropping `:link` from `collect_ancestor_names`, dropping the refusal after a reached
    cap, dropping the part-content refusal and the cell refusal each fail their cases.
    **macOS effect:** none; the entry points have no caller in the Objective-C++ layer, and the new members are only
    read by them. `text_element_allowed` counts as before outside a patch session (`m_patch_released` is 0).
    **Custom properties and `var()`** (`html_tag::reads_var`, `declares_custom_properties`; `document::var_readers`,
    `m_patch_custom_tops`, `commit_patch`). A restyle substitutes no `var()` again: `subst_vars` replaces an element's
    `var()`s in its style with what they resolved to. So an element that declares custom properties (in its matched
    style, or its inline or animated style) before or after `rematch` matches it again is a custom-property top, and
    `commit_patch`, before its restyle, matches again each element below the tops whose style read a `var()` when it
    was computed (`reads_var`, kept by `compute_styles` and `compute_background_style`, counted by the document so that
    `var_readers` walks nothing in a document where no style reads one), and the owner of a `::before` or `::after`
    that read one (matching the owner again makes its pseudo-elements again), as a pseudo-class reach is matched
    (`set_pseudo_classes`); the commit takes the session's seeds, boxes and kept-tree verdict (edit 74) only after those
    matches, so a reader whose pseudo-elements are made again has its render subtree replaced even when nothing else of
    the session gave up the kept tree (a paint-only hover on an element declaring a custom property). An inline `style`
    or animated style is patched whatever it holds (a custom property, `var()`, or a counter, which litehtml reads from
    matched rules alone: `handle_counter_properties` runs in `add_style`, never for the inline style
    `compute_styles` adds). WidgetRuntime lists `var_readers` of what a flush
    matches again in its selector step plan. Pinned by `external_test.cpp` `testCustomPropertiesInInlineStyle` (a
    parent's custom property under a child's `var()`, a child's own `var()`, a property and its `var()` on one element,
    a `display` from a `var()`, each also through the animated style, a hover declaring the parent's custom property,
    and a paint-only hover over readers with `::before` content, alone and beside a structure change),
    `testPseudoElementsReadingVar` (a class, an inline style and a hover declaring the custom property a
    `::before` reads) and WidgetRuntime's render oracle group "custom properties".

18. **Structure patched in place** (2026-10-18, M1c Task 9 and its fix rounds; both platforms, insertions plus five lines
    set aside under `#if 0`/`#else`: four in `html_tag.cpp`, one in `render_table.cpp`; items 6 and 7 change output on
    macOS and in today's iOS renderer). The flush of
    edits 16 and 17 extends to inserted, removed and moved subtrees. Fork `document.h` gains public `insert_subtree(parent, index,
    subtree)`, `remove_subtree(subtree)`, their predicates `can_insert_subtree` and
    `can_remove_subtree` (each taking a `structure_growth* pending`: the pieces planned removals
    release, the net elements and the cells planned insertions add), `structure_reaches_siblings()`,
    `make_text_pieces(parent, text, pieces)`, `max_external_depth` (= `max_build_depth`, public), private
    `structure_parent_allowed`, `structure_insertable`, `structure_removable`, `link_subtree`, `unlink_subtree`, the
    session member `m_patch_inserted`, and `m_content_tags`/`m_content_parts` (the tags the `::before`/`::after` content
    rules name and whether one could make a form control's parts' content, naming an `lh-*` part or `*`, read from the
    sheets once: they never change after finalize);
    implemented in `src/telegram_external.cpp`.
    1. **The predicates** are what a caller plans with before it changes anything; each entry point asks its own again
       and answers false, changing nothing, where it does. Refused (litehtml.md section (c) 1, 2, 4): a subtree holding
       a document-level element (`update_structure`'s list, `document.cpp` `has_document_level_element`: html head body
       link base meta title script frameset select option optgroup datalist; a `<style>` is not, edit 81), removed or
       inserted; a parent that is
       not in the document, is raw text (`<style>`, `<script>`), is generated content, or is inside a select, option,
       optgroup, datalist, textarea, input, progress or meter (edit 16's list: their generated content reads their
       children; a `<button>` is not on it, `testStructureInsideAButton`, nor an `<svg>`, whose render subtree a change
       under it replaces through edit 74's boundary, `testStructureInsideAnSvg`); a parent's own `appendChild` refusal, which a build leaves out (`el_table` takes
       tbody, thead, tfoot and caption only; WidgetRuntime asks `accepts_child` first and never builds one, edit 83).
       Sheets with sibling combinators or positional pseudo-classes refuse nothing: the commit matches again the other
       children a rule can reach (edit 90). The commit's match makes an inserted element's
       generated content in its place, as a fresh build does, and near a cap replays the style pass in a build's order
       (edit 84; `testStructureBesidePseudoContent`). The caps the caller cuts at before it asks (WidgetRuntime's walk)
       are checked as defence: an element at `max_build_depth` or deeper, `max_build_elements` (`m_build_elements`,
       which `insert_subtree` raises and `remove_subtree` lowers by the subtree's elements, generated content left out),
       and the document's own text pieces (edit 84's `document_text_pieces`, less what `pending` releases: a planned
       subtree's pieces are alive, and counted, already). A subtree that is attached, the root, a detached element,
       generated content (`::before`, `::after`, a form control's `lh-*` parts) and an index past the end are refused
       too.
    2. **The changes** each join edit 16's patch session (starting one), bump `m_match_epoch`, and name the parent a
       seed of the commit's replacement (edit 74). `insert_subtree` links through `insert_child` (edit 12);
       `remove_subtree` goes through `remove_child` (edit 12, which re-points hover and active) and releases the
       subtree's pieces (edit 17's `release_pieces`: alive until `commit_patch`, uncounted from now on). **Styling is deferred to `commit_patch`:** it styles every subtree linked in the session
       and still in the document as `update_structure` styles a fresh one (the master sheet for all, then
       `parse_attributes`, then the author sheets, then the user sheet), after every structure change of the session, so
       a positional match (`li:last-child`) reads the final children; the subtrees join the restyle roots, and the
       seeds' boundaries are replaced (edit 74).
    3. **`make_text_pieces`** makes the pieces `append_text` would append (one in a raw-text parent, else `split_text`'s
       words and spaces) with no parent and without asking `text_element_allowed`, for a subtree the predicate counts:
       built while the pieces it replaces are still alive, `append_text` would ask the cap of both and could report a
       limit no build would hit.
    Pinned by `tests/external_test.cpp` (`:TwidgetExternalTests`), which did not link before the edit (none of the
    entry points existed): `testInsertRemoveMatchesFresh` (append, insert at 0, removing the middle child, a move between
    parents in one session, a table row into a tbody, a list item, text pieces inserted and removed; each patched
    document's placements, height, draw calls, text-piece count and reported limits equal a fresh build's),
    `testStructureRefusals` (a `<style>`, inside one, a `<select>` in a div and removed, a `<body>`, an option into the
    select and a span into its option, a circle into an svg, a span into a button, a tr into a table, `:nth-child`, `+`
    and `~`, an input with an `lh-*` part rule,
    an attached subtree, a detached parent, an index past the end, a `<style>`'s text, the root, a detached element, an
    `lh-*` part; each leaves the document and the piece count as they were and reports no limit; the same sheets let what
    they do not reach through), `testStructureCaps` (depth 255 accepted and 256 refused; 20,000 elements with `pending`;
    the text cap with a planned removal's release, accepted at 9,998 and equal to a fresh build; 199,001 cells accepted
    and 200,001 refused) and `testReplaceChildrenUnderPositionalSelectors` (`:nth-child`, `+`, `~`, `:last-child`,
    `:first-child`, and an ordered list's items under counters: the replaced children equal a fresh build, down to one
    and to none); and `testFontSizeZeroMatchesFresh` (RED before item 7). Mutation
    checks: styling each subtree as it is linked instead of at commit fails the positional case; dropping the scope
    refusal, the element count's decrement, the release of removed pieces, the subtree's pseudo-content tags or the
    table's `appendChild` rule each fail their cases.
    4. **One selector-step budget per build or patch session** (Ruling E19). litehtml gave every outermost
       `apply_stylesheet` 4,000,000 counted selector tests of its own (`html_tag.cpp`'s `apply_scope` reset the count,
       `select` refused past it), so `commit_patch` matching N inserted roots against 3 sheets had 3N budgets where a build
       has 3 (the reviewer's probes: 5,000 roots 7.3x a fresh build, 200 roots at depth 250 5.1 s against 0.05 s; and a
       build cut at 4,000,000 left the last divs uncoloured while an appended div was coloured). `document.h` gains
       `selector_step_session` (`limit`, `used`, `owner`) and `set_selector_step_session`; `document` gains
       `begin_selector_steps(limit)` (default `default_selector_steps`, 4,000,000), `end_selector_steps()` (the steps used:
       more than the limit when a test was refused, so a cut shows), `selector_steps_used()`. While a session is open on the
       thread, every outermost pass over that document's elements (`apply_scope(this)` from `apply_stylesheet`, the line
       set aside under `#if 0`/`#else`; the pass's document is its element's) carries the count over from the session's
       last pass and refuses at the session's limit (three more lines set aside: the reset in `apply_scope`'s
       constructor, its destructor's, which now keeps what the pass used for the session, and the `select` check); a pass over
       another document's elements counts into none. A patch session (edits 16-18) opens one itself with the default limit
       when its caller has not, and `commit_patch` closes it; a build has one when its caller opens it (WidgetRuntime does,
       around `finalize_from_external_root`). `~document` closes an open one (an insertion in `document.cpp`). Matching
       replayed from an element's memo (`apply_matching`) runs outside any pass and counts nothing, as before.
    5. **The counts a caller charges by.** `selector_count()` is the three sheets' selectors (a caller weighs a match's
       filter loop by it), and `max_external_elements` (= `max_build_elements`) is public. The content-rule tags of item
       1 are cached once per document. A caller asks a parent's `accepts_child` before it makes an element (edit 83), so
       a build counts only what it links.
    6. **A table's rows are placed once per layout.** `render_item_table::_render` moved each row down by its top
       captions with `+=`, and nothing else places a row, so every pass of the table's layout moved the rows, and the
       placements of the cells under them, down again, and so did every later layout of a kept render tree (a text or
       attribute patch of edits 16-17); the line is set aside under `#if 0`/`#else` for `=`. This changes fresh builds
       too: a row's `pos().y` under a 16 px caption is 16 where it was 32 in block flow (two passes), 48 inline-block or
       floated (three), 64 in a flex item (four). The cells' own positions, which drawing uses (the table draws each cell
       at its position from the table), are unchanged; their placements (`get_placement`, which adds every ancestor's
       position) move with their rows (in the measured shape a cell at y 63 is at 47). Found when Task 9's fix round
       gave the random oracle captions.
    7. **No font has no metrics.** `document::get_font` answered 0 for a size of 0 and left the caller's `font_metrics`
       as they were; `css_properties::compute_font` passes the element's own, so an element restyled to `font-size: 0`
       (an attribute patch of edit 17, on a kept render tree) kept its old line height: 24 px where a fresh build has 0
       (8 against 0 with `line-height: 0`), and a `<caption>` so restyled moved its table's cells. It now writes
       `font_metrics()` (an insertion), what a fresh element's metrics are. This changes today's iOS renderer as well as
       Telegram-Mac: `LHDocument.mm` restyles kept render trees (`update_styles`, `:877`; `update_holes`, `:949`), so an
       element it restyles to `font-size: 0` loses its old line height there too.
    8. **Fix round 2 (Ruling E21).** `finalize_from_external_root` asks an optional matching gate (`set_matching_gate`, `matching_gated()`; two inserted
       checks) before the master-and-host pass and before the author pass, with the pass's rule count, so a caller can
       refuse `apply_selector`'s filter loop (every rule against every element, which no step counts) before it runs,
       without charging inside litehtml; declined, finalize returns before that pass and the document is left unfinished
       for the caller to drop.
    9. **Fix round 3 (Ruling E22): the filter loop's elements.** A `::before`/`::after` rule that can create
       pseudo-elements makes `apply_stylesheet` match them too, every rule against each, so the gate's count of elements
       was low by up to two per element. `document.h` gains `pseudo_element_tags` and `pseudo_element_creators(sheets)`
       (one pass over the rules: the tags a `::before`/`::after` rule whose content is not `none` names, or every tag for a
       `*` with more than the pseudo-element, `html_tag::apply_selector`'s `create`; and whether that reaches a form
       control's `lh-*` parts), `matching_weight(el, creators)` (an html_tag 1, its two pseudo-elements when its tag is
       creatable, a form control's three parts with theirs) and `matching_bound(root, creators)` (the weights of a subtree,
       generated elements left out as their owner's, so a tree's bound is the same before matching and after, before
       `parse_attributes` makes the parts and after). The gate now takes the bound: it is asked before the master pass
       with the master sheet's rule count and creators, and before the author and host passes (the host sheet is matched
       after the author's: a correction of item 8, which counted it with the master's, and no change where no gate is
       set, as on macOS) with theirs and all three sheets' creators; it may lower
       the open session's step limit (`set_selector_step_limit`, `selector_step_limit`) by what it set aside for the loop.
       Pinned by
       `testMatchingBoundCountsPseudoElementsAndParts` (six sheets: a div's, a `*`'s, `content: none`, `.x::after` for
       every tag, an `lh-input-text` part rule; the master sheet's `summary::before` creates for a summary only). RED:
       without the pseudo-element term four checks fail; counting generated elements again, the bound of a matched input
       and a matched `.x` div differ from their fresh ones.
    Also pinned (fix round): `testSelectorStepsAreOneBudgetPerSession` (one div's steps; two roots under a limit of a div
    and a half: the first coloured, the second not; the reviewer's parity probe: a build of 4,099 divs under 1,000 rules
    passes the budget, and a session limited to what it left colours an appended div no more than a build does; 300
    roots under a 16,000-selector rule share one budget, 250 roots' worth; a session counts only its own document) and
    `testTableRowsArePlacedOncePerLayout` (three more layouts leave a captioned table's placements as they were). RED:
    with the per-pass reset restored, four checks of the first fail (one div's steps read 0, both roots coloured, the
    build not cut, the append coloured); without the binding the other document counts into the session; without the patch session's own budget
    all 300 roots are coloured; with `+=` the placements move.
    **macOS effect:** items 1-5: none; the entry points have no caller in the Objective-C++ layer, the new members are
    only read by them (`commit_patch`'s styling runs only for subtrees `insert_subtree` linked), and
    with no session open (Telegram-Mac opens none) every outermost pass has litehtml's 4,000,000 steps as before.
    Items 6 and 7 apply on macOS. Item 6: in a table with a top caption, a row's position is the captions' height once,
    where it was that height once per layout pass (two to four by formatting context, as above) and grew with every later
    layout; drawing is unaffected, the placements of the rows and of the cells under them move with them, and so does hit
    testing by reading: `render_item::get_element_by_point` subtracts each level's `m_pos` before it descends
    (`render_item.cpp`, the `el_pos.x = x - el_pos.x` lines), so a point inside a captioned table's rows is matched against
    the cells at a different offset than before. Edit 59 stops shifting the rows themselves, so a cell's placement is
    where it is drawn. Item 7: an element at
    `font-size: 0` on a kept render tree (Telegram-Mac's template-hole patches can restyle one) gets no line height, as
    a fresh one does; a fresh document is unchanged (the same holds for the iOS renderer's `LHDocument.mm` restyles, item
    7). Items 8 and 9: the gate is unset on macOS, and the bounds and creators have no caller there.

19. **Pseudo-elements never nest, and their content is capped** (2026-10-18, M1c Task 9b, Rulings E23 and E26; both
    platforms, as insertions only). Two remote crash/DoS shapes in unchanged upstream code, reachable from widget CSS in a
    message; **today's iOS path (`LHDocument`) and Telegram-Mac are affected and fixed** (both parse through this code).
    1. **Nesting** (`html_tag.cpp`, `apply_stylesheet`'s `apply_before_after`). A `::before` element matches
       `:not(p)::before` itself and so got a `::before` of its own, without bound (`apply_stylesheet` -> `apply_selector`
       -> `_add_before_after`): stack overflow, exit 139 through WidgetRuntime's build, with
       `<style>:not(p)::before{content:'x'}</style><div>a</div>`. The lambda now returns for an element whose tag is
       `::before`/`::after`: a pseudo-element has no pseudo-elements of its own, whatever the sheets say. (The existing
       `*::before` guard in `html_tag::select` already did this for the bare-star selector.)
    2. **Content amplification** (`el_before_after.cpp`, `element.cpp`, `document.*`). A pseudo-element made one element
       per `content` item; text pieces were capped by edit 10, `url()` images were not, and the pseudo-elements
       themselves were not counted: `div::before{content:url(a) x1000}` on 1,000 divs made 1,002,004 elements in 8.3 s.
       `add_style` keeps at most `max_css_list` (32, edit 15's constant) items, strings and functions alike. The
       pseudo-element and each `url()` image (an `el_pseudo_image`, an `el_image` subclass; the upstream `make_shared<el_image>` line is set aside under `#if 0`) are counted alive in
       `document::m_pseudo_elements` (their constructors and destructors), and `document::pseudo_element_allowed()`
       answers false once `m_build_elements + m_pseudo_elements` reaches `max_build_elements`, reporting
       `sanitizer_limit("elements")` once. A refused pseudo-element is not created (`_add_before_after` returns null)
       and `apply_before_after` does not then style the parent with the rule; a refused image is not made.
    Pinned by `tests/pseudo_nesting_test.cpp` (`:TwidgetPseudoNestingTests`, on a 512 KiB thread): the nesting case
    crashed before (exit 138), the capped cases failed 5 checks; ordinary `p::before` and `attr()` content are
    unchanged. **macOS and today's iOS:** a document with a nested-pseudo selector no longer overflows the stack, one
    whose content lists run past 32 items shows the first 32, and one whose pseudo-elements would pass 20,000 elements
    stops creating them (the limit is reported to the container, which Telegram-Mac's ignores). Nothing else changes: a
    page within the bounds renders identically.
    3. **Patches near the cap.** A build hands the pseudo-element budget out in document order, which a patch's
       matching does not follow; near the cap the commit replays the style pass in a build's order (edit 84), and
       `pseudo_element_allowed` does not count the pseudo-elements a patch session released (held to its commit).

20. **The paint walk and the render observer** (2026-10-18, M1c Task 10b; both platforms, as insertions only: eleven item
    draw sites set aside under `#if 0`/`#else`, everything else added). WidgetRuntime's layer mirror (`W/Sources/Render/
    LayerMirror.h`) mirrors litehtml's painting as nodes with stable identity and keeps it current from what the fork
    reports at its own mutation points, comparing nothing itself.
    1. **The walk** (`render_item.h`, `render_item.cpp`, `render_table.cpp`, `document.cpp`). `walk_paint_order(doc,
       visitor, hdc, x, y)` is `document::draw` with a `paint_visitor` installed (the thread-local `g_paint_visitor`,
       `with_paint_visitor`), so the walk *is* draw()'s loop and nothing about stacking contexts, z-index or passes is
       re-implemented: the container receives every call draw() makes outside an item's own paint (overflow clips,
       `begin_group`, `set_clip_path`, `draw_backdrop`, `draw_filtered`, `suspend_clips`), in draw()'s order. Three kinds of
       hook tell the visitor the rest:
       - `paint_context_scope`, at the top of `draw_stacking_context` (root, positioned: `stacking`; float or inline box:
         `pseudo`) and of `draw_group` (`group`): `open_context`/`close_context`;
       - `paint_pass_scope`, at the top of `render_item::draw_children`: `open_pass(item, pass, zindex)`/`close_pass`, the
         scope draw_children opens its overflow clip in;
       - `paint_or_visit`, at every item draw site: `draw_children`'s five (fixed and other positioned, block, floats,
         inlines), `draw_group`'s two (filtered or not), `render_item_table::draw_children`'s caption, row
         (`draw_background`) and cell, and the root's in `document::draw`. Each upstream line is under `#if 0`, its
         replacement under `#else`; with no visitor `paint_or_visit` makes exactly that call. With one, the visitor's
         `paint_element(item, pass, x, y, paint)` gets the paint as a callback, run with no visitor installed.
       Helpers for a mirror that updates without walking: `paint_origin` (the x, y an item's own draw gets, by
       draw_children's, the table's and draw_group's arithmetic; optionally before the item's own sticky offset) and
       `paint_clip` (the clip draw_children opens for an item). draw() is unchanged: no hook does anything while no walk
       runs.
    2. **The render observer** (`document.h`, `document.cpp`, `telegram_external.cpp`, `render_item.*`).
       `document::set_render_observer`; null by default, and with none set nothing is reported or saved.
       - `replace_text_renderers` (edit 16) reports the inline context's old children removed, its new ones added and
         `text_replaced(context)`;
       - `finalize`'s build reports nothing (an observer walks the new tree whole); after it nothing re-creates the
         tree: a patch that gives up
         the kept tree (every structural patch of edit 18, every attribute patch `apply_retag` does not call neutral,
         text pieces `replace_text_renderers` cannot place), `media_changed` and `viewport_changed` replace render
         subtrees in place and report `subtree_replaced(old, new)` (edit 74);
       - `commit_patch` reports each element `restyle_after_patch` restyled with the tree kept,
         `element_restyled(el, paint_order)`, where `apply_retag` set `paint_order` when a rule that started or stopped
         matching declares `opacity`, `transform`, `transform-origin`, `filter`, `visibility` or `-lh-anim`;
       - layout reports each box it changed, `item_geometry_changed(item, moved | resized | reflowed)`, compared at the
         write: an item saves its box (position, size, padding, borders; an inline context also its inline content's
         boxes, inline boxes and fragments, which layout writes without `render()`; a table its parts' and rows') the first
         time the running layout writes it (`render()`'s entry, `forget_positions` before it zeroes them, a table's
         `render()` for its rows), and `document::render` compares those, and only those, with what it leaves, exactly
         (`observed_change`'s `same`: not within litehtml's pixel epsilon, since a layout on a kept render tree can move
         a box by less than 0.0001 px, and the mirror must hold what a fresh walk records; on macOS, which registers no
         render observer, nothing changes). The layout cache's dirty roots bound what is written.
    Pinned by `tests/external_test.cpp`: `testWalkVisitsWhatDrawPaints` (for Task 4's fixture and a second one with
    floats, positioned items at -1 and 2, an inline-block and a table: a walk that paints every visit makes draw()'s calls
    in draw()'s order, one that paints none makes only the traversal's own calls, every paint call is a visit's, in visit
    order, each render item is visited once, and a walk changes nothing a later draw() makes) and
    `testObserverReportsEveryRenderTreeChange` (after a text patch and a neutral class patch the items reported added and
    removed are exactly the difference of the render trees, every box layout changed is reported (an inline item's
    through its inline context's reflow) and nothing unchanged is; an opacity class change is reported with paint order; a
    structural patch and a `style` patch report `subtree_replaced`). Both failed to compile before the edit.
    **macOS and today's iOS:** nothing changes. Neither sets a visitor or an observer, every hook falls through to the
    upstream call, and the observer's bookkeeping (a few fields per render item) is never written.
    litehtml's block pass does not enter an inline-flex or inline-grid (edit 86), so each item's own paint happens once.

21. **A style-byte budget** (2026-10-18, M1c Task 11b, Ruling E46; both platforms, as insertions only). litehtml copies
    every declared value into each element it matches (`html_tag::add_style` -> `style::combine` ->
    `add_parsed_property`), so one 16 KiB custom property on `*` over 9,000 elements held 353.6 MB that no limit
    counted. That is a jetsam shape in the shipped renderer as well as in WidgetRuntime.
    - **The charge** (`style.h`/`style.cpp`, `html_tag.cpp`). `add_style` asks `document::style_admit(style, m_style,
      charged)` before the copy. The charge is the heap payload the copy adds: a `std::string` value's capacity beyond the
      small-string buffer, a `string_vector`'s elements and strings, a `css_token_vector`'s elements, string capacities
      and nested tokens (`style::payload_growth_over`). A value replacing one of the same property charges only what it
      holds beyond the one it replaces, because a cascade of rules for one property keeps one value (a sheet of 16,000
      `div{...}` rules costs one value, not 16,000). Fixed-size values (enums, lengths, colours, images) charge nothing,
      and nothing is shared or interned here: that is the deferred real fix.
    - **Which sheets.** Only the author (`m_styles`) and user (`m_user_css`) sheets, so the master sheet always applies.
      `html_tag::apply_stylesheet` and the match-memo replay in `apply_matching` open a `style_charge_scope` (off for
      `master_css()`, on otherwise); `used_selector::m_author` records which a matched rule came from, so
      `refresh_styles` (media, language, viewport) replays under the same rule. A replay gives back what the element held
      first (`html_tag::m_style_charged`, `document::style_refund`), as it also clears `m_style`, so repeated refreshes do
      not accumulate; `forget_matched_styles` gives it back too. `restore_base_style` does not (cumulative, below). Where
      the document is limited, or a replay could reach the budget, `document::refresh_all_styles` (media, viewport and
      language changes; `refresh_styles` is kept under `#if 0`) charges again from zero in a build's order instead: it
      clears every element, replays the master rules over the tree, `parse_attributes`, the author rules, then the user
      rules (`used_selector::m_sheet`), so the result equals a fresh build at the new viewport.
    - **`var()` splices are charged** (Ruling E47; `style.cpp` `resolve_vars`, `html_tag::find_custom_property` /
      `charge_splice`). `subst_vars` copies a custom property's value into each element's declaration, outside any sheet
      pass, so the splice is charged unconditionally (author- and user-derived values) and BEFORE the copy: the size of the
      found value, or of the fallback, is known without copying it (`find_custom_property` returns a pointer). It counts
      against the same budget and in the element's `m_style_charged`, so a refresh stays balanced (inline `style=` values
      reach the same path). A refused splice drops the declaration: its tokens are cleared and it is not re-added, and
      `style-bytes` posts once. Charging precedes every copy, so a doubling chain (`--b:var(--a) var(--a)`) stops at the
      budget; once limited, every further `var()` fails at once, so the work is bounded too. The inherited font-family
      string is cut at 1 KiB (`cap_font_family`, at parse) as well as by the helper below.
    - **Inherited strings are bounded at one helper** (Ruling E50; `css_properties.cpp` `bound_inherited_string`). A value
      an element inherits as a `std::string` is copied into every descendant's computed style, which no charge on the
      declaring element bounds (16 KiB on `html` over 9,000 elements held +176 MB each). Every inherited string member of
      `css_properties` (`cursor`, the base URL of `list-style-image`, `font-family`, `text-emphasis-style`,
      `font-variant-numeric`; `list-style-image` itself is shared and charged instead, edit 60) is passed through it after `get_property<std::string>(..., true, ...)`: an element that
      declares a string itself (`html_tag::declares_value`: the stored value is a `std::string`, exactly what
      `get_property<std::string>` tests, so `inherit` and an unresolved or refused `var()` do not count) keeps it (it is
      charged), and the copy a descendant inherits is cut at 1 KiB (at a comma
      or character boundary), or dropped when it is a URL (or holds `url(`), because a cut URL loads another image. A new
      inherited string member must call it. The grep for other inherited heap-valued computed members found none: the
      other inherited members are colours, ints and lengths; `text-shadow` is capped by edit 15; custom properties walk
      their parents; `content` and the background image are not inherited. Now +11 MB each at 9,000 elements.
    - **Past the budget** (`document::max_style_bytes`, 16 MiB; see the measurement; Ruling E48). The admission that
      would pass it fails and `sanitizer_limit("style-bytes")` is posted once. From then on, in the order the sheets are
      applied, a declaration that holds heap payload (a value that would charge, and a raw copy kept for animation) is
      dropped, and fixed-size declarations (enums, lengths, colours) still apply (`style::combine_fixed`). The same rule
      holds on the build, refresh and patch paths. The document stays renderable.
    - **Deterministic.** A new document charges from zero in that order; two builds of one document dump identically.
    - **Patches** (`telegram_external.cpp`, `document.cpp`, `html_tag.cpp`). A patched document holds what a fresh build
      of it holds (`style_bytes_charged()`). An element leaving the tree gives back what it and its subtree hold
      (`document::release_style_charges`, `html_tag::release_style_charges`): `document::remove_child`, which removals
      and a form control's parts go through, does it, and so do `forget_matched_styles` for each pseudo-element it drops
      (one a match puts back takes the new one's charges: edit 91) and a match whose `content:none` drops one. A rematch
      gives back before it charges. `subst_vars` replaces a matched `var()` in the style with what it resolved to, so a
      restyle splices again only what it adds again (the inline and animated style, and the matched style
      `restore_base_style` puts back): each property's splices are charged to that property (`html_tag::begin_splice`,
      `m_splice_charges`), and a property spliced again gives back what it held first, while one substituted earlier
      keeps its charge. So a patch's charge is its own and exact, and the patch predicates ask the budget nothing; a
      patch that passes it, or one in a document past it, is followed by edit 84's
      replay at the commit, which charges from zero in a build's order. `style_budget_in_play(n)` (true once the limit
      was hit, or when the running charge plus `n` elements each holding the largest value of every property the author
      and user sheets declare, plus up to 64 `var()` uses of the largest custom property value, could reach the budget;
      the cached sum reset when the sheets are parsed or added) is left to `refresh_all_styles`. Pinned by
      `external_test.cpp` `testStyleBytesFollowPatches`, by `structureMatchesFresh` and `attributePatchedMatchesFresh`,
      which compare `style_bytes_charged()` with a fresh document's, and by WidgetRuntime's render oracle, which compares
      it with a fresh build's after every flush.
    - **Measured** (WidgetRuntime, `:WidgetRuntimeRenderCorpusTests`): the corpus's largest charge is 585,504 bytes
      (`common/heavy/01-long-table.html`, `var()` splices included); a plainly styled 10,000-element document (5,000 divs with 6 declared properties
      each, 5,000 spans with 3, a `body` font-family) charges 879,872. The budget is `max(16 MiB, 4 x the larger)`:
      4 x 879,872 is 3.4 MB, so it is 16 MiB (16,777,216). The `var()` cases at 9,000 elements (3,000 before the fix grew
      2.8 GB) now grow +16.2 MB (`--y:var(--x)`), +15.8 MB (`transition`), +12.1 MB (`font-family`), +21.0 MB (inline
      style) and +6.9 MB (10-level doubling chain), each with one `style-bytes` post. With it, 16 KiB `--x` on `*` over 9,000 elements charges
      16,764,720 bytes and grows the heap 20.4 MB over the baseline (353.6 MB before); 40-entry `font-family` on `*`
      charges 3.2 MB (+7.5 MB, unchanged, under the budget); 16 KiB `content` on `*::before` is +0.1 MB.
    Pinned by `tests/external_test.cpp` (also `testInheritedStringsAreBounded`: nine shapes on `html`, short values
    unchanged): `testStyleBytesAreBudgeted` (the 16 KiB case posts `style-bytes` exactly once,
    grows the heap under twice the budget and still lays out; a plain document of the same size posts nothing) and
    `testStyleBudgetIsDeterministic`, `testVarSplicesAreBudgeted` (six var() shapes) and
    `testRefreshAfterTheLimitEqualsARebuild` (a width change after the limit equals a fresh build at that width). All
    failed before the edit (uncharged splices did not finish within the test timeout). WidgetRuntime pins the patch gate
    (`testPatchPastTheStyleBudgetMatchesRebuild`) and the three amplification cases.
    **Insertion-only check** (`git diff 751715a0ba`, deleted lines per file; edit 21 adds none, the others are earlier
    edits'): `css_selector.h` 0, `document.h` 1, `html_tag.h` 0, `style.h` 0, `css_properties.cpp` 1, `document.cpp` 17,
    `html_tag.cpp` 0, `style.cpp` 0, `telegram_external.cpp` 0. Every line of edit 21 that replaced another is kept under
    `#if 0` (old) / `#else` (new) (the scope constructor and its call sites, `refresh_styles` at its three callers,
    `m_style_charged`, the `resolve_vars` lookup).
    **macOS and today's iOS:** a document under the budget is not cut by it, but it does not render exactly as before: the
    1 KiB font-family cut and the inherited-string bounds (`bound_inherited_string`) apply under the budget too; the cost
    is a payload sum per admitted rule and one `get_document()` per element and sheet pass. One that passed the budget
    renders without its later heap-holding author declarations.

22. **A host-support surface over `LHContainer`** (2026-10-19, M1d plan, Tasks 5 and 6 and the `WRSession` review
    fixes: `a0925b4ddf`, `8e3dbafe4f`, `eca6a3ffb7`; both platforms, as insertions only). WidgetRuntime lays out and
    paints without `LHDocument`, but its iOS half (`WidgetRuntimeIOS`) reuses `LHContainer`'s CoreText, ImageIO and
    CoreGraphics code rather than a copy of it. `LiteHTML/LHHostSupport.h` (new; C++, so `BUILD` keeps it out of `srcs`
    and exports it in `textual_hdrs`, like `lhx_painter.h`) declares `LHHostContainer`, one `LHContainer` behind a
    pimpl, driven without an `LHDocument`. Its implementation is appended to `LHContainer.mm`, after `get_language`,
    because it uses that file's own helpers (`LoadImageFromData`, `DrawRasterized`, `DrawCGImage`):
    - **Layout** (Task 5, for `CoreTextRenderHost`): `createFont` (the handle is `LHContainer`'s, valid until the
      static `deleteFont`, and any `LHHostContainer` can measure or draw with it), `nativeFont`, `textWidth`,
      `createTextBreaker`, `transformText`, `pathContains` (`point_in_clip_path`), `defaultFontSize` and
      `defaultFontName` (16 px), and the static `createImage(bytes, length, svg, size, maxPixelBytes)`:
      `LoadImageFromData`, edit 5's policy on iOS (PNG, JPEG, GIF or WebP as ImageIO sniffs it, at most 4096 px a side
      and 16 Mpx; SVG through `LHCreateSVGImage`), refusing more than `kMaxDataImageBytes` (24 MiB) of bytes; a +1
      image and its CSS size, or null. `maxPixelBytes` (4 bytes a pixel) refuses an image before it is drawn: a raster
      image from its header (`TelegramImageSourceAllowed`), an SVG once laid out and before `copyImageWithMaxWidth`
      (`LHCreateSVGImage`'s new last parameter, unlimited by default, so its other callers are unchanged). The host
      passes what is left of a widget's 24 MiB decoded-image total (M1d fix pass).
    - **Painting** (Task 6, for `LayerTreePainter`): `container()`, the `document_container` a layer tree's items are
      replayed through (`hdc` is the `CGContextRef`); `beginPaint`/`endPaint`, what `LHDocument`'s
      `drawLockedInContext` does around a draw (pixel snapping from the CTM, saved on a `thread_local` stack of scopes,
      the source-filter scope and text batching; `endPaint` flushes the batched text); `drawImage(ctx, layer, image,
      uint64_t identity)` and `drawListMarkerImage`, `draw_image`'s and `draw_list_marker`'s drawing for an image the
      host already decoded (no URL lookup), with the same clips, tiling and raster cache; and `setBackdropSource`, the
      source of a backdrop filter that `LHDocument`'s `backdropLockedForOwner` otherwise gives. The raster cache key
      takes `identity`, a serial the host makes unique for the process (`eca6a3ffb7`), not the image's address: the
      cache outlives the image, and another image can reuse its address.
    - `LHContainer.h`: `friend class LHHostContainer;` at the top of the private section, so the painting half can call
      the private `apply_clips`, `clip_background_layer` and `for_each_tile`.

    Nothing in twidget calls any of it. On macOS it is the same insertions (nothing is guarded), and `createImage` there
    is `LoadImageFromData` without edit 5's type and size check. Pinned by
    `//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS:WidgetRuntimeIOSTests`: `CoreTextRenderHostTests`
    (`testFontMetricsMatchLHContainer`, `testDecodesPngJpegGifAndSvg`, `testHostileImagesAreRefused`,
    `testAnImageOverTheTotalIsRefusedBeforeItIsDrawn`, …) and
    `LayerTreePainterTests.testPaintsLikeLHDocument` (16 fixtures painted through it equal, pixel for pixel, `LHDocument`
    drawing the same HTML at 2x).

23. **Lookups for getComputedStyle** (2026-10-20, V3 plan, Task 4; both platforms, as insertions only).
    `string_id.h`/`string_id.cpp`: `_find_id(str, id)`, the id of a name the table already holds, without adding it.
    `_id` adds every name it is asked for to a process-wide table that never shrinks, so a widget calling
    `getPropertyValue('--' + random)` in a loop would grow it without bound; WidgetRuntime looks custom properties up
    through `_find_id` (a name the table does not hold is no property any element has). `css_properties.h`:
    `get_overflow_x()` and `get_overflow_y()`, the two axes (`get_overflow()` is their merged value).

24. **A media keyword is looked up, not interned** (2026-10-20, V3b plan, Task 1; both platforms, three lines in
    `media_query.cpp`'s `verify_and_convert_units`). A keyword-valued feature (`prefers-color-scheme`, `orientation`, …)
    interned the widget's ident with `_id`, so `matchMedia('(prefers-color-scheme: ' + i + ')')` in a loop grew the
    process-wide id table, which never shrinks, for every widget. Every keyword a feature accepts is interned already,
    so `_find_id` (edit 23) answers the same: an ident that was never interned is not one of them. Pinned by
    WidgetRuntime's `MatchMediaTests.testAnUnknownMediaKeywordDoesNotGrowTheIdTable`.
25. *Reserved* for the parked z-index pass charge (a patch in `feature/message-widgets`'s history), not applied.
26. **The host's root declarations** (2026-10-20, V2a plan, Task 4; both platforms, as insertions only:
    `document.h`, `html_tag.h`, `html_tag.cpp`). SDK v1 §2.3 puts the theme's `--tg-theme-*` and `--tg-color-scheme`
    on the widget's root, inline and `!important`, so that neither a sheet (`:root { … !important }`) nor the widget's
    own style on its root replaces them. `document::set_root_declarations` parses the host's declarations once, on
    their own; `html_tag::add_root_declarations` combines them into the root's style after its `style` attribute, in
    both places that add it (`compute_styles` and `compute_background_style`), so they are the last important word
    (`style::add_parsed_property` replaces an important value only with a later important one). Appending the text to
    the root's `style` attribute would not do: a widget's attribute ending in an unclosed construct
    (`--y: (`) swallows what follows into its own value. The root then never shares a style. Pinned by WidgetRuntime's
    `ThemeParamsTests` (`testTheRootCarriesTheVariablesNoWidgetRuleReplaces`,
    `testAnUnclosedRootStyleCannotSwallowTheVariables`). New declarations in place: edit 80.
27. **Animated declarations** (2026-10-21, V5e plan, Task 6; both platforms, as insertions only: `html_tag.h`,
    `html_tag.cpp`, `telegram_external.cpp`). Web Animations' values are the animations origin of the cascade: above
    every normal declaration, the element's own `style` included, and below every `!important` one. WidgetRuntime
    hands an animated element its sampled declarations in a render-only attribute, `animated_style_attribute`
    (`"animated style"`: the space makes it a name no DOM attribute, parsed or set, can have), and
    `html_tag::add_animated_style` parses it on its own and combines it right after the `style` attribute, in both
    places that add that (`compute_styles` and `compute_background_style`), saving the base style first as the `style`
    attribute does, so a restyle starts from the matched rules. Being an attribute, it rides the attribute patch, and
    the element never shares a style (only `class`, `id` and `data-*` attributes allow sharing). Pinned by WidgetRuntime's
    `AnimationRenderTests`.
    Second part (Task 7, `document.cpp`): the attribute changes on every frame of a running animation, so
    `apply_retag` treats it as it treats `class` rather than as any other attribute, which always replaces the
    element's render subtree (edit 74). It sets the two texts aside before comparing the rest, and keeps the tree when
    every property whose declaration differs between them (`changed_declarations`) is a `paint_only_property`: so
    `transform`, `opacity`, colours and the rest of that list are restyled in place and republished as mirror operations
    (and, since edit 63, a box's geometry), while a property that shapes the render tree (`display`, `position`, …)
    still replaces it (edit 74). The changed properties feed the region as a changed rule's do, and
    one of `paint_order_property`'s six (the list edit 20 tests a rule against, now one helper) tells the render
    observer that paint order may have changed. Pinned by `AnimationRenderTests` (`testAPaintOnlyFrameKeepsTheTree`:
    the render tree kept on every frame, on an in-flow block and on a positioned element).
28. **A rounded border's sides cover its ring** (2026-10-21, V5f plan, Task 8; iOS only: `LHContainer.mm`'s
    `draw_borders`). A border whose sides differ is painted side by side, each a polygon clipped to the ring (the
    outer rounded rect less the inner one). Each polygon ended at the inner rect, so where the inner corners are
    rounded the ring's parts inside the inner rect's corners belonged to no side and stayed unpainted: the CSS
    spinner (`border-radius: 50%`, one side coloured) drew a square hole in its round ring. Each side now closes
    through the inner rect's centre, so the four partition the box; inside the border band the joins are the miters
    as before. Pinned by WidgetRuntimeIOS's `LayerTreePainterTests.testARoundedBorderWithOneSideColouredFillsItsRing`.
29. **The profile hooks** (2026-10-21, V4 plan, Task 3a; both platforms, as insertions only). New virtuals on
    `document_container` (`document_container.h`) that WidgetRuntime's `WidgetContainer` answers with its profile
    policy; every default keeps litehtml's behaviour, so `LHContainer`, which overrides none of them, is unchanged.
    Pinned by `:TwidgetProfileHooksTests` (`tests/profile_hooks_test.cpp`).
    - **29.1** `profile_declaration(std::string& name, css_token_vector& value, bool& important)`, called in
      `style::add` (`style.cpp`) where `sanitize_declaration` was (that line under `#if 0`); the default calls
      `sanitize_declaration`. It may rewrite the declaration before it is added (sticky → relative, a pruned filter
      list, a reduced font list); false drops it.
    - **29.2** `sanitize_selector_list(std::vector<css_token_vector>& groups)`, in `css::parse_style_rule`
      (`stylesheet.cpp`): the prelude's comma groups (`parse_comma_separated_list`) go to the container, which may erase
      or rewrite them; the kept groups, rejoined with comma tokens, are parsed strictly as before (the old
      `parse_selector_list(rule->prelude, …)` line under `#if 0`). `parse_selector_list` splits the joined tokens back
      into the same groups, so a container that changes nothing parses exactly what it did, and a malformed group still
      drops the whole rule. No group left drops the rule.
    - **29.3** `sanitize_media_query(const css_token_vector& prelude)`, before an `@media` rule's query list is parsed
      (`stylesheet.cpp`, false: the rule is dropped with its rules) and before a stylesheet's `media` is
      (`document.cpp`, false: that sheet is not applied; `document.cpp` now includes `css_parser.h` for `normalize`).
      The second site serves `<link media>` only: the fork's `<style>` (`el_style`) is an `element` and keeps no
      attributes, so a `<style media>` sheet has always applied whatever its media.
    - **29.4** `evaluate_supports(const css_token_vector& condition)`, for an `@supports` condition (`stylesheet.cpp`,
      the `eval_supports_condition` line under `#if 0`): 1 true, 0 false, -1 (the default) litehtml's own evaluation.
    - **29.5** `prefers-reduced-motion`, as edit 13 added `prefers-color-scheme`: `media_features::reduced_motion` (0
      no-preference, 1 reduce; filled by the container, default 0, `types.h`), the string ids
      `_prefers_reduced_motion_`, `_no_preference_` and `_reduce_` (`string_id.h`), a `supported_media_features` row and
      a `media_feature::check` case (`media_query.cpp`). In a boolean context, `(prefers-reduced-motion)`, only reduce
      matches. On macOS `(prefers-reduced-motion: no-preference)` now matches where it was unknown.
    - **29.6** `profile_substituted(const std::string& name, css_token_vector& value)`, in `style::subst_vars`
      (`style.cpp`) for a non-custom property once `var()` is substituted, before it is added: it may rewrite the value;
      false drops it as edit 21's splice budget does (value cleared, `m_has_var` off). Custom properties were judged by
      29.1 where they were declared.
    - **29.7** `sanitizer_key() const`, four bytes mixed into the declaration cache key (`style.cpp`), the author-sheet
      `styles_key` and the master sheet's `master_key` (`document.cpp`, the old key under `#if 0`). The three caches are
      process-wide and keyed on text, so a hook must be a pure function of its text, and containers whose hooks differ
      must never share an entry: the test container and `WidgetContainer` build in one test process.

30. **Computed values the runtime reads** (2026-10-22, fidelity plan, Task 1; insertions only).
    - **30.1** `touch-action` joins the raw declarations (`raw_declaration_names`, `style.cpp`), as `pointer-events`
      did: litehtml does not model it, and WidgetRuntime's getComputedStyle reads the element's own value.
    - **30.2** `svg_computed_property(el, name)` (`el_svg.h`/`el_svg.cpp`): the painter's own lookup (`svg_property`,
      inherited), public, so getComputedStyle's `fill`, `stroke` and `stroke-width` answer what is painted.

31. **Small fidelity fixes** (2026-10-22, fidelity plan, Task 2; the conformance set's expectations, Chromium's).
    - **31.1** CSS Color 4's `IndianRed`, `Indigo` and `RebeccaPurple` join the named colours, and `MediumPurple`
      (`#9370DB`) and `PaleVioletRed` (`#DB7093`) take their CSS values (`web_color.cpp`).
    - **31.2** `table_grid::calc_table_width` (`table.cpp`): auto columns whose max widths sum to 0 share what is left
      equally, instead of leaving it to the fixed columns (a width-50 cell beside an empty one: `0/50 50/150`, as
      upstream litehtml and browsers have it; the fork's rewrite had regressed it).
    - **31.3** `list_style_type_strings` has 21 entries, `css_units_strings` and `appearance_strings` 16
      (`css_values.h`): an extra empty slot matched any non-identifier token, whose `ident()` is "", so
      `list-style: url(…)` set list-style-type 21 and never its image. `parse_keyword` (`style.h`) now takes identifiers
      only.
    - **31.4** `:lang()` (`html_tag.cpp`) matches the element's own or nearest ancestor's `lang` attribute (Selectors
      4: ASCII case-insensitive, the range or the range and a hyphen), never the container's default language, and
      `lang` joins the attributes whose change re-matches beyond the element (`collect_ancestor_names`,
      `document.cpp`), on the subject compound too.
    - **31.5** `:empty` (`string_id.h` `_empty_`, `html_tag.cpp`): no children but `::before`/`::after`, a text piece of
      any data counting. A sheet using it sets `selector_scope()` bit 8 (`uses_empty`, `document.cpp`): a change of an
      element's children changes how the element itself matches, which the structure patches match again (edit 88).
      Matched again in place
      (`document::apply_retag` sets the element's children aside, so that matching makes only its `::before`/`::after`),
      `:empty` reads the children set aside (`html_tag::set_children_for_matching`, cleared by a scope guard): an
      attribute patch on an element with children never makes it `:empty`. Pinned by `testSetAttributeMatchesFresh` (a
      `span` and a `p` with text under `span:empty` and `p:not(:empty)`; not setting the children fails both). **macOS
      effect:** the template path (`update_document` → `apply_retag`) matched `:empty` on every element it re-matched;
      it now reads the element's children there too.

32. **Text properties litehtml lacked** (2026-10-22, fidelity plan, Task 5; string ids `_word_break_`,
    `_word_spacing_`, `_font_feature_settings_`, `_quotes_`).
    - **32.1** `font-feature-settings`, kept as its text and inherited (`style.cpp`, `css_properties`): `compute_font`
      sets `font_description::tabular_nums` for `"tnum"` (on, or a non-zero value), as `font-variant-numeric:
      tabular-nums` does. Other features are not read.
    - **32.2** `word-break` (`normal|break-all|keep-all|break-word`, inherited, `css_values.h`): `el_text` breaks a
      break-all (or legacy break-word) text anywhere, as `overflow-wrap: anywhere`; keep-all is not modelled.
    - **32.3** `word-spacing` (a length or `normal`, inherited, converted as `letter-spacing`): `el_text` widens each
      space piece by it, over the width it measured (`m_measured_width`, so a re-style never adds twice).
    - **32.4** `quotes`, kept as its text and inherited (`css_properties::get_quotes()`, "" for auto), for
      getComputedStyle; the quote keywords of `content` are not drawn (the runtime's UA sheet gives `<q>` literal
      marks).
33. **The CSS-wide keywords** (2026-10-22, fidelity plan, Task 6). Only `inherit` was handled; `initial`, `unset`,
    `revert` and `revert-layer` fell to each property's parser, which refused them, so the declaration vanished and an
    earlier one stood.
    - **33.1** `style.h`: `initial`, `unset` and `revert` marker types, appended to `property_value`'s variant (the
      replaced line under `#if 0`). `style::add_property` stores them as it stores `inherit`, over a shorthand's
      longhands (`global_keyword_property`); `revert-layer` was `revert` (there were no layers; edit 50 stops it at the
      master's layer). The raw declaration
      copies keep the keyword's text, as they keep `inherit`'s.
    - **33.2** `html_tag::get_property` answers `initial` with the property's initial value (its `default_value`);
      `unset` falls through as no declaration does, so it inherits an inherited property and is initial otherwise.
      `has_own_property` counts `unset` as no declaration (the replaced lines under `#if 0`).
    - **33.3** `revert`: before `subst_vars`, `compute_styles` and `compute_background_style` call
      `html_tag::resolve_reverts`, which replaces each `revert` with `master_value(name)`: the element's matched master
      sheet rules (`m_used_styles` with `m_sheet == 0` and `m_used`, less those styling a pseudo-element), in the
      order they applied, as `add_parsed_property` would combine them. Presentational hints are author level, so a
      revert passes them. No master value is `unset`. A copy that holds heap is charged as a var() splice (edit 21;
      refused, the property is `unset`). Being derived from `m_used_styles` on every compute, it follows every
      restyle path. A pseudo-element has no master rules of its own, so a `revert` on one is `unset`.
    - **33.4** A custom property set to `initial` has no value: `find_custom_property` and `get_custom_property`
      stop there, so `var()` takes its fallback.
34. **The individual transform properties** (2026-10-22, fidelity plan, Task 7; string ids `_translate_`,
    `_rotate_`, `_scale_`). `translate`, `rotate` and `scale` were kept only as raw declarations (for transitions), so
    they were neither painted nor measured, and an animated value (whose layer keeps no raw declarations) was lost.
    - **34.1** `style.cpp` stores each as its token list, as `transform`'s.
    - **34.2** `parse_individual_transform` (`css_effects`) reads one as a transform function, 2D only (the profile
      refuses a z component and an axis): `translate` one or two lengths or percentages, `rotate` an angle (or `z` and
      an angle), `scale` one or two numbers or percentages; `none` and anything else give nothing.
    - **34.3** `css_properties::compute_effects` puts them before `transform`'s functions in `m_transform`, in the
      order translate, rotate, scale (CSS Transforms 2 §6), so painting, hit testing and `get_visual_transform` follow
      them unchanged; `get_transform_individual_count()` says how many there are, so the runtime's getComputedStyle
      reports `transform`'s own functions alone.
    - Not done: an SVG shape still takes a CSS transform only when it declares `transform` (`el_svg.cpp`'s
      `has_own_property(_transform_)`), so a shape's `translate` alone is not applied.
35. **Colour-stop fix-up** (2026-10-22, fidelity plan, Task 8; `background.cpp`
    `gradient_base::prepare_color_points`, the replaced body under `#if 0`). CSS Images 3 §3.4.3: a stop with no
    position stays unplaced until the first and last get 0 and 1; a position below an earlier one is raised to the
    largest before it (`conic-gradient(a 0 25%, b 0 50%)` gave CG the locations 0, .25, 0, .5); the unplaced are spaced
    evenly between their placed neighbours (the upstream spaced them from the sum of the two, so
    `linear-gradient(a 20%, b, c 80%)` put b at 70%); only then do a non-repeating gradient's implicit 0 and 1 ends
    join. An explicit 0 on the last stop is no longer read as "unplaced" and moved to 1.
36. **Blink's dash metrics** (2026-10-22, fidelity plan, Task 8; `LHContainer.mm`, both platforms, the replaced lines
    under `#if 0`). A dashed border's dash is 2w long with a gap of w from 3px up (3w and 2w below), a dotted border's dots
    are round and w across with a gap of w (Blink's `StyledStrokeData`), and the gap is then fitted
    (`SelectBestDashGap`, `FitDashes`) so a side starts and ends with a dash or dot, its corner squares inked; fewer than
    two that fit draw the side solid. Each side is stroked from corner to corner (`StrokeStyledSegment`); a uniform
    border takes that per-side path unless it is rounded, which strokes one closed path fitted to its length
    (`RoundedRectLength`). The upstream drew dashes `{2.5w, 1.5w}` and dots every 2w from phase 0, unfitted. The CSS
    specification leaves the pattern to the UA; this copies Chromium, which widget-sandbox's references are.
37. **object-fit and object-position** (2026-10-22, fidelity plan, Task 8; string ids `_object_fit_`,
    `_object_position_`). Neither existed, so an `<img>` was stretched over its content box. `object-fit`
    (`fill|contain|cover|none|scale-down`) is a keyword property and `object-position` is read as `background-position`
    is (default 50% 50%); `el_image::draw` hands the painter the object rect (CSS Images 3 §5.5) as the layer's
    `origin_box`, its `clip_box` staying the content box.
38. **SVG `<use>` and text runs** (2026-10-22, fidelity plan, Task 9; `el_svg.cpp`'s `svg_painter`, the replaced
    lines under `#if 0`).
    - **38.1** `<use>` drew nothing. `draw_use` resolves its `href` (or `xlink:href`) fragment against the document's
      ids (`document::svg_element_by_id`: the first element with an id wins, gathered again when the match epoch, which
      every attribute and structure patch moves, or the paint generation has moved), and draws the target
      translated by `x` and `y` inside the use's own transform: a `symbol` (or `svg`) in a viewport of the use's
      `width` and `height` (else the target's, else 100%) mapped from its `viewBox` by its `preserveAspectRatio`
      (xMidYMid meet by default), with no clip; any other element as itself (`draw_children`'s new `only` parameter).
      A target that is the use, one of its ancestors or an instance being drawn is refused; instances nest at most 8
      deep (`kMaxUseDepth`) and the document's svgs draw at most 8,192 elements inside instances together
      (`kMaxUseElements`), which bounds a `<use>` chain's exponential fan-out: each svg may draw what its own last paint
      drew plus what the others' last paints left (`el_svg::use_budget`, `note_use_drawn`; a destroyed svg gives its share
      back), and a hit test draws within the same share. A budget per painter let every `<svg>` draw 8,192, so a few KB
      of small svgs using one fan-out recorded gigabytes of paths (the final review; `testUseBudgetIsTheDocuments`). The
      target is drawn alone, not found by a walk over its siblings. A hit inside an instance is the outermost use. `svg_group_key` and
      `cacheable_paint_key` already refuse a subtree holding a `<use>`, so no cached paint goes stale when a
      referenced element changes.
    - **38.2** `draw_text` drew the text's whole content as one run in the `<text>`'s fill. It now draws each Text
      node as its own run in its element's font and fill (the text's, a `tspan`'s or an `a`'s); a `tspan`'s `x` and
      `y` set the position and start a chunk, its `dx` and `dy` move it, and the move persists after it; whitespace
      collapses across the runs as across one string; `text-anchor` shifts each chunk by its width. A hit is the run's
      element. Per-character position lists use their first value, as before.
39. **Intrinsic widths** (2026-10-22, fidelity plan, Task 12). `width` and `height` take `min-content`,
    `max-content` and `fit-content` (`width_keyword`, predefined values beside `auto`; `style.cpp`), which everything
    else reads as `auto`. A block whose width is one of them (not the root, not a table cell, not measured for content)
    sizes its content box in `render_item_block::_render`: min-content from its content pass, max-content from one more
    content pass with nothing to wrap at (1,000,000 px wide), fit-content as `min(max-content, max(min-content,
    available))`; the content is then laid out again at that width. The two measuring passes lay every nested keyword
    box out as `auto` (`document::intrinsic_measuring`, and no layout cache entry is read or written while one runs),
    and only the fitted pass lays them out in full, at most 8 keyword boxes deep (`intrinsic_depth`); deeper ones lay
    out as `auto`. When every pass laid every nested keyword box out in full, 40 nested `div{width:max-content}` never
    finished (the work doubled per level, uncharged; the final review, pinned in `fork_test.cpp`).
40. **`text-overflow: ellipsis`** (2026-10-22, fidelity plan, Task 12; string id `_text_overflow_`, `clip|ellipsis`,
    not inherited). At the end of an inline context's content pass (`render_item_inline_context::apply_ellipsis`), in a
    block that clips (`overflow-x` not `visible`), on each line wider than the content box the first text piece reaching
    past the box less the ellipsis's width is cut after the code points that fit (`render_item::set_ellipsis`), and
    every text part after it on the line (an atomic inline at the cut too) is not drawn (`draw_children` skips it, so
    the paint walk does too). The cut piece draws its kept text and then `…` on its baseline in the block's font and
    colour, as part of its own paint (`el_text::draw`), so the layer mirror records it with the piece. Inline boxes' own
    backgrounds after the cut still draw.
41. **A master `@layer` is an origin above the master** (2026-10-22, widget-sandbox v0.1.1 plan, Task 1). litehtml read a
    `@layer` block's rules as unlayered. In the master sheet (`css::set_layered_origins`, set by `document` before the
    master's parse) each block now numbers its rules (`css_selector::m_layer`), and the selector order is (layer,
    specificity, order), so a layered master rule beats every engine master rule whatever their specificity (the profile's
    UA layer over litehtml's `ul ul ul{list-style-type:square}`, `table[border] td`, `body{margin:8px}`), and
    `html_tag::master_value` (edit 33.3) skips layered rules, so `revert` rolls back to litehtml's own sheet, as a
    browser rolls an author layer back to its UA sheet. Author sheets are unchanged (their `@layer` stays unlayered; the
    profile drops it anyway). The parsed master is cached with its selectors, and the match memo and
    `refresh_replay_styles` keep the sorted order, so every restyle path follows.
42. **Positions in a rule's subject alone** (2026-10-22, widget-sandbox v0.1.1 plan, Task 2). The UA layer brought
    positional pseudo-classes into every document's master (`body>:first-child`, `th:last-child`, …), and any of them
    made `selector_scope` refuse every attribute patch and every insertion and removal (or widen it to all of a parent's
    children). Edit 42 tells them apart:
    - **42.1** `scan_positions` (`document.cpp`, beside `scan_selector`, which the replaced call under `#if 0` used): a
      positional pseudo-class in a rule's subject compound (or a selector list inside it) records the rule's subject and,
      under a child combinator, parent tag (`m_subject_positions`, scope bit 16) instead of setting bit 2; anywhere else,
      or with a sibling combinator or `of S`, the bits are as before.
    - **42.2** An attribute patch refuses only on bits 1 and 4 (`can_set_element_attributes`): a position is read from an
      element's place, which no attribute changes, and `:empty` (8) from its children.
    - **42.3** An insertion or a removal is allowed under bit 16 (and under bits 1 and 2, edit 90) (`can_insert_subtree`, `can_remove_subtree`); a parent it
      touches whose element children such a rule can match (`positions_reach`: the parent's tag, a child's tag) is noted
      (`note_position_parent`), and `commit_patch` matches its other element children again in place (`apply_retag` with
      their own attributes, checked: one whose box or more than its paint changes is a seed, edit 89) once the fresh
      subtrees are styled, adding them to the restyle. A parent is asked once in a
      session however many of its children it changes: one noted stays noted, and one no rule reaches stays so while
      its children only go (`m_patch_position_unreached`), until an element a rule names is inserted under it. Pinned by
      `testPositionParentsAreAskedOncePerSession`. `update_structure` (the HTML path) treats bit 16 as bit 2.
43. **A rule's declarations in their written order** (2026-10-22, widget-sandbox v0.1.1 plan, Task 2; `style::combine`
    and `combine_fixed`, the replaced loops under `#if 0`). The upstream copied a rule's properties onto an element in
    its map's order (by string id), which renumbered them, so `subst_vars` could take a longhand written before a `var()`
    shorthand for one written after it and keep it: the UA layer's `hr{border:0;border-top:1px solid var(…)}` drew no
    rule. They are copied by their `m_order` now.
44. **A relatively positioned inline box moves its content** (2026-10-22, widget-sandbox v0.1.1 plan, Task 2;
    `line_box::finish`, the replaced call under `#if 0`). The upstream shifted an inline element's own render item once
    for its start item and again for its end, so its text (whose placement adds it) painted twice as far and its inline
    box (which the edges make, and which `getBoundingClientRect` reads) not at all; the UA layer's `sup{position:relative;
    top:-.5em}` measured on the baseline. An inline's render item keeps no offset now; each line item takes the offsets
    of its inline ancestors, an inline box's edges their own too, and a text piece or an atomic inline its own as before.

45. **`user-select` read back** (2026-10-22, widget-sandbox v0.1.1 plan, Task 7; string ids `_user_select_`,
    `__webkit_user_select_`). `user-select` joins the raw declarations (`raw_declaration_names`, `style.cpp`), as
    `touch-action` did (edit 30.1): litehtml does not model it, and WidgetRuntime's getComputedStyle reads the element's
    own value. `add_property` writes `-webkit-user-select` as `user-select` before keeping the copy, as it writes
    `-webkit-backdrop-filter` as `backdrop-filter`, so the two names are one property and the later declaration wins.

46. **`direction`, phase 1 of right-to-left** (2026-10-22, fidelity plan, Task 11; string id `_direction_`, `ltr|rtl`).
    - **46.1** `direction` is an inherited keyword (`css_properties::get_direction`), stored with the other single
      keywords (`style.cpp`). `unicode-bidi` is not modeled.
    - **46.2** `text-align: start`/`end` keep their computed values; where a line box is built
      (`render_inline_context.cpp`, the old call under `#if 0`) they resolve against the block's direction, so an RTL
      line starts at the right edge and `end` is the left. `line_box` takes the physical alignment and `rtl`, which puts
      a justified paragraph's last line at the right edge.
    - **46.3** `calc_auto_margins`: a block whose margins are both set, in a right-to-left containing block, ignores
      `margin-left` (CSS 2.1 §10.3.3) and ends at its right margin; the shift is returned like an auto margin's.
    - Not yet: floats, the absolutely positioned static position and table columns are as in LTR (the order of a
      line's items is edit 47). The `[dir]` rules and `dir=auto` are WidgetRuntime's (its UA sheet and the Builder; since
      the review minors the rules match the host marker `data-tg-dir`, so an author's `[dir]` sees `dir` as written).

47. **Bidi reordering of a line's items, phase 2 of right-to-left** (2026-10-22, fidelity plan, Task 13).
    - **47.1** `document_container::bidi_levels(runs, rtl, levels)`: a hook (default: false, the logical order kept)
      that answers each unit's embedding level from the line's text (UAX #9 up to rule I2). WidgetRuntime's container
      answers from its own UAX #9 (`Sources/Render/Bidi.cpp`: ICU's `ubidi` is not public API on iOS); the test
      container leaves it unset.
    - **47.2** `line_box::reorder_bidi`, called after the first pass of `finish` (alignment and justification already
      laid out): a unit is one content item (a text piece, or an atomic inline as U+FFFC) with the inline start and
      continuation edges before it and the end edges after it; rule L2 reverses runs from the highest level down to the
      lowest odd one, and each unit's slot (its start to the next unit's start) is laid again in visual order, so the
      alignment shift and the justification spacing are kept. A left-to-right line asks only when its text holds a
      right-to-left character or control.
    - **47.3** An inline's box (the second pass, the old code under `#if 0`) covers every item met while it is open,
      its edges included, rather than its start edge to its end edge, which reordering can move apart; in logical order
      the two are the same.
    - Each text piece is drawn by the container in one call, so the order inside a piece (a word mixing scripts) is
      the text engine's. An inline's start edge stays with its first logical content, so in a reversed span it sits
      on the inside.
48. **Math functions that mix a percentage with a length** (2026-10-22, fidelity plan, Task 10): `calc()`, `min()`,
    `max()` and `clamp()` whose percentage resolves against the containing block at layout (`calc(50% - 10px)`,
    `clamp(20px, 50%, 60px)`). The parse-time fold already turns math of one kind into a value; what it leaves is now a
    tree rather than a dropped declaration.
    - **48.1** `calc_node.h`/`calc_node.cpp` (new): an immutable tree (a sum of px, %, em, rem, ex and ch terms plus
      children with factors; min, max, clamp), parsed from the function token by recursive descent (absolute units at
      96 px per inch, a `<number>` zero allowed in a sum, nesting to 16, at most 32 arguments; a type mismatch, an unknown
      unit or a division by zero or by a length is no tree). A tree holds at most 64 nodes (`calc_node::max_nodes`),
      refused while parsing as soon as a sum's children pass it: a cached declaration's one tree is evaluated for every
      element it styles at every layout, uncharged, and a `var()` splice can make one declaration as large as the style
      budget (a 50,000-term sum under a million factors took 15 s to parse before the cap, every factor walking every
      child). Trees are shared by an atomic count (`calc_ref`), because a
      laid-out document's lengths are copied into trees another thread reads. `calc_node::live()` counts the nodes alive
      in the process, for the leak pin.
    - **48.2** `css_length` (insertions only, the old members under `#if 0`) holds the tree in its union beside the
      value, flagged by `m_is_calc`; it grows from 8 bytes to 16 (the pointer's alignment). Copy, move and assignment share or release the tree; `set_value`,
      `predef` and `operator=(float)` release it. A calc with a percentage reports `css_units_percentage`, one without
      `css_units_px`; `val()` is its value with the percentage at 0, and `calc_percent(base)` evaluates the whole tree,
      which is what every percentage consumer (gaps, flex-basis, font-size, the containing-block context) already calls.
      `from_token` accepts a function token where the property takes a length, and a percentage only where it takes one
      too; where the property takes no negative value (`f_positive`) the tree is wrapped as `max(0px, …)`
      (`calc_node::at_least_zero`), as CSS clamps a math function to the property's range, so `flex-basis: calc(50% -
      8px)` is a basis and not `auto`. A term or factor a float cannot hold makes no tree, as the parse-time fold refuses
      an overflow. `to_string` prints `calc{…}`, for layout dumps.
    - **48.3** `document::cvt_units` folds the font-relative terms at compute (`calc_fonts_for`: em is the element's
      font size, rem the root's, ex and ch the font's x-height and `0` width); a tree left with no percentage becomes a
      plain px length, one with a percentage stays a tree to layout. `to_pixels` evaluates a tree at the size it is given.
    - **48.4** A gradient stop at a calc is placed at the line's length (`normalize_length`, `background.cpp`). A table
      column whose width is a calc with a percentage lays out as `auto` (`table.cpp`, both the auto and the fixed
      algorithm), the browsers' answer for a mixed percentage in a column being a separate algorithm litehtml lacks.
    - Pinned by `fork_test.cpp` (the widths at a 200 px container, the font-relative fold, an in-place patch through
      `style::combine`, the cap at 64 nodes and the oversized sum refused at once, and no tree outliving its lengths: a parsed length copied, moved and reassigned leaves none
      alive, and a second layout and patch of the same page leaves no more alive than the first, the rest being
      `style::add`'s process-wide declaration cache (edit 11)), and by `FidelityRenderTests.testMathWithPercentages`.

49. **Calc consumers the review found** (2026-10-22, review-minors plan, Task 1). A calc's `val()` is its value at a
    zero percentage base (edit 48.2), so two sites read it wrong: the three `text-indent` gates in
    `render_inline_context.cpp` (`val() != 0`, and the content-mode fast path's `val() == 0`) also pass for a calc, so
    `text-indent: min(10%, 40px)` indents; and a calc font size with a percentage (`css_properties.cpp`) evaluates with
    `calc_value(parent_sz, calc_fonts_for(…))`, its em the parent's size as the non-percentage path's `to_pixels` reads
    it, not 16. The replaced lines are under `#if 0`. Pinned by `fork_test.cpp` ("Edit 49"); WidgetRuntime's font cache
    key keys a calc length by its tree for the same reason (`WidgetContainer.cpp` `appendLength`,
    `FidelityRenderTests.testCalcDecorationThicknessKeysTheFont`).

50. **`revert-layer` stops at the master's layer** (2026-10-22, review-minors plan, Task 3). Edit 33 read `revert-layer`
    as `revert`, which skips the master's `@layer` (edit 41) to the engine's own rules. In the reference renderer the
    UA layer is an author-origin layer, so an unlayered author `revert-layer` rolls back to it: `struct revert` gains
    `layer`, set for `revert-layer`, and `html_tag::master_value(name, layer)` answers the layered master rules' value
    when they set one, else the engine's (a property the layer does not set rolls back as `revert` does).
    `style::resolve_reverts`' callback takes the flag. Pinned by `FidelityRenderTests.testRevertLayerStopsAtTheUALayer`.

51. **Raw declarations for getComputedStyle** (2026-10-22, computed-style plan, Task 1). profile 1's properties litehtml
    keeps no value of (`counter-increment`, `counter-reset`, `unicode-bidi`, `color-scheme`, `grid-template-areas`,
    `grid-auto-columns`, `grid-auto-flow`, `font-feature-settings`, `font-variant-numeric`) join `raw_declaration_names`
    (`style.cpp`), as `touch-action` did (edit 30.1), so WidgetRuntime's getComputedStyle answers what the element
    declared, `var()` substituted, rather than the initial value. So do properties litehtml keeps in a form that
    cannot tell an undeclared value from a declared one (`justify-content` and `align-content`, which default to
    flex-start and stretch where CSS's initial value is normal) or computes only on flex or grid containers or flex
    items (`flex-direction`, `flex-wrap`, `align-items`, `row-gap`, `column-gap`, `flex-shrink`, `flex-basis`; since
    edit 54 getComputedStyle reads litehtml's own parse of these, `flex-basis`'s copy telling a declared basis from the
    `flex` shorthand's, and each copy stays the cascaded value a CSS animation's implicit keyframe starts from), and
    properties whose spelling litehtml's value loses (`aspect-ratio`, kept as one float; `flex`, whose omitted basis it
    stores as 0px where CSS writes 0%; `place-content`, whose `normal` and `stretch` it stores as the defaults). Insertions only; a raw copy exists only on an element that declares the property, counted as its other
    declarations are. `z-index` is one too, for the cascaded value a CSS animation's implicit keyframe starts from
    (getComputedStyle reads litehtml's own, edit 53).
52. **Caret offsets for text selection** (2026-10-22, text-selection plan, Task 3). `LHContainer::caret_offsets` (and
    `LHHostContainer::caretOffsets`) reads back where `draw_text` puts each UTF-16 boundary of a text: the simple
    shaper's per-glyph xs and its width for printable ASCII (one glyph per byte), otherwise the cached `CTLine`'s caret
    offsets, enumerated in one pass (`CTLineEnumerateCaretOffsets`: a boundary is its character's leading edge, the end
    the last character's trailing edge; a boundary inside a surrogate pair takes the pair's start, one CoreText reports
    nothing for the boundary before it; right-to-left text descends). A query per index
    (`CTLineGetOffsetForStringIndex`) costs the line's length each, which made a long run quadratic (final review C1:
    minutes at the text cap). WidgetRuntime's iOS host answers `RenderHost::caretOffsets` with it, so a selection's knobs sit where
    the glyphs are drawn on both paths. Additions only.
53. **z-index as kept** (getComputedStyle). `css_properties::get_z_index_length()` returns the stored `css_length`, whose
    predefined value is `auto`, so a read tells `auto` from `0` without a raw copy of the declaration; litehtml
    validates the value itself (an integer or `auto`), so an invalid declaration never reads back. One accessor,
    insertions only.
54. **The element's own parsed values** (getComputedStyle). `html_tag::own_property(name)` returns the element's
    cascaded `property_value` of `name` as litehtml parsed it. litehtml computes the flex longhands, `align-items`,
    `justify-items` and `justify-self` only on the containers or items they lay out, and a gap's `normal` as 0, but it
    parses them on every element, expanding `flex`, `flex-flow`, `gap` and `place-*` into their longhands in cascade
    order: WidgetRuntime reads that parse where litehtml computed nothing. One accessor, insertions only.
55. **The box alignment shorthands in the shorthand table** (`style.cpp` `shorthands`). `gap` (and its alias `grid-gap`),
    `place-content`, `place-items` and `place-self` join `flex` and `flex-flow` there, so `inherit`, `initial`,
    `unset` and `revert` on them reach their longhands (they were kept under the shorthand's own name, which nothing
    reads), and `subst_vars` keeps a longhand written after one of them holding a `var()`, in layout as in
    WidgetRuntime's getComputedStyle. Insertions only.

56. **A translation's math functions** (`css_effects.cpp`). `parse_transform`'s translate functions and the `translate`
    property hand a math function argument whole to `css_length::from_token`, whose tree (edit 48) holds one that mixes
    a percentage with a length (`translateX(calc(100% + 10px))`, nested products, `min()`); the fold of one unit, which
    every other transform argument still goes through, refused it and the whole transform was dropped. Layout and the
    painter already evaluate a translation with `calc_percent` against the border box. Pinned by `fork_test.cpp`
    ("Edit 56") and widget-sandbox v0.1.3's `auto/09-transforms-effects-a`.

57. **A var() that never resolves unsets the property** (`style.cpp` `style::subst_vars`). A declaration whose `var()`
    has no such custom property and no fallback (or is a cycle) is invalid at computed-value time: the property is
    `unset` (edit 33's marker), a shorthand's longhands with it through `global_keyword_property`, while a longhand
    written after the shorthand keeps its value. litehtml re-added the unparsable value, which dropped the declaration,
    so an earlier longhand stood (`flex-grow: 3; flex: var(--nope)` grew 3; Chrome 0). Custom properties keep their
    tokens: a `var()` reading one fails where it is read. The replaced call is under `#if 0`. Pinned by `fork_test.cpp`
    ("Edit 57") and WidgetRuntime's `testAnUnresolvedVarIsInvalidAtComputedTime`.

58. **A `<use>`'s instance inherits from the use** (`el_svg.cpp`, SVG 2 §5.6.3). The instance draws its target's own
    elements (edit 38), whose inherited presentation properties came from where the target sits (a `<symbol>` in
    `<defs>`), so `<use href="#star" fill="#e83">` drew a fill-less symbol's path black. While `draw_use` draws an
    instance it holds the target and the use on a thread-local stack (`use_instance_scope`: tiles are drawn in parallel),
    and `svg_property`'s inheritance walk goes from the target to the use (`svg_inheritance_parent`); `currentColor`
    takes the nearest `color` declared along that chain, else the use's own computed colour (`svg_current_color`).
    The replaced loop head is under `#if 0`. Pinned by `fork_test.cpp` ("Edit 58") and widget-sandbox's
    `visual/09-svg-a` (the two stars, orange and purple).
59. **A top caption moves a table's cells once** (`render_table.cpp` `render_item_table::_render`). Upstream moves each
    row and each cell under it down by the captions' height. A cell's position is the table's (drawing adds it to the
    table's own, `draw_children`), but placement and hit testing add the row's on the way down (`get_placement`,
    `get_element_by_point`), so a cell under a 40 px caption drawn at y=40 was placed, and hit, at y=80. The row now
    stays at the table's top, as in a table without a caption; its boxes come from its cells (`for_inline_boxes`), so
    its background is drawn where it was. Pinned by `fork_test.cpp` ("Edit 59") and WidgetRuntime's
    `testACaptionedTablesCellsAreWhereTheyAreDrawn` (boxes and hits against the same table under a 40 px block).
60. **An image bullet set on a list reaches its items** (`css_properties.cpp` `computed_list_style_image`,
    `charge_inherited_list_style_image`; `html_tag.cpp` `charge_inherited`, `refund_inherited`; `document.h`
    `style_charge_bullet`, `style_budget_epoch`). Edit 21 dropped an inherited `list-style-image` over 1 KiB, so
    `ul { list-style: url(data:…) }` lost its bullets when the URL was longer. `m_list_style_image` is now one
    `shared_ptr<const std::string>`: an element that declares the URL makes it, the elements that inherit it share their
    parent's, and the shared-style table and the class-swap cache copy a pointer. Only a list item reads the URL (it
    hashes and copies it as it lays out and paints its marker, and only it calls `load_image`), so a list item that
    inherits a URL over 1 KiB is charged its length to the style budget (`style_charge_bullet`), as is one that takes
    such a style from the shared-style table. Bullets take at most half the budget, so the declarations keep the
    rest: past it, an item falls back to its type and nothing latches or is reported. The element gives the charge back
    before it is computed again (`compute_styles`), unless the budget restarted from zero in between
    (`refresh_all_styles` counts its restarts). A class flip (`flip_class`, Telegram for macOS's template patches)
    restores cached styles without computing them and so keeps the charges of each element's last compute; WidgetRuntime
    never patches templates, and its attribute patches forget the flips (`set_element_attributes`).
    `get_list_style_image` is defined in `css_properties.cpp`: its empty string, a static in a header's inline
    function, was constant-initialized in read-only memory by a C++20 caller (WidgetRuntime) and then constructed at
    run time by the fork's gnu++17 code, which crashed. Pinned by `external_test.cpp` (`testInheritedUrlsAreSharedAndCharged`:
    one string, the charge per list item, the refund, a refresh, a template's class changes back and forth; 9,000 list
    items stay under half the budget, 0.1 MB over a document without the rule) and WidgetRuntime's
    `testAListsLongImageBulletReachesItsItems`.
61. **A table's rows and row groups have a box** (`render_table.h`/`.cpp` `render_item_table::part_placement`, new). The
    table keeps its cells in its grid and never `init()`s a row or a row group, so neither registers a render item with
    its element and `getBoundingClientRect` had nothing to measure (0×0). `part_placement` gives a row's border box from
    the grid, across the columns (the first's left to the last's right) over the row's top to bottom, and a group's over
    its rows, placed as the cells are (a row's `get_placement`, then the top captions' height). WidgetRuntime's
    `elementClientRects` asks the nearest table for an element of a row or row-group display that has no render item.
    Pinned by `fork_test.cpp` ("Edit 61") and WidgetRuntime's `testATableRowsAndGroupsHaveTheirBoxes` (rows, a row a
    cell spans into, a header group and a body group, under a caption).
62. **An inline style change keeps the render tree when it changes only paint** (`document.cpp` `apply_retag` and
    `changed_declarations`). A script that animates by writing `el.style.transform` on every frame changed the `style`
    attribute, which `apply_retag` never called neutral, so every frame re-created the render tree. `apply_retag` now
    sets the `style` texts aside as it does the animated declarations (edit 27; the old comparison under `#if 0`), and
    their changed properties join the animated ones: the tree is kept when every one is a `paint_only_property`, with
    their regions and paint order told as a changed rule's, and a property that shapes the tree still replaces it.
    `changed_declarations` compares values without the whitespace around them, since CSSOM writes the whole attribute
    again (`width: 40px;` for `width:40px`) the first time a script sets one property. Pinned by WidgetRuntime's
    `testAPaintOnlyInlineStyleKeepsTheTree` (`transform`, `opacity` and `color` frames keep the tree from the first;
    `display`, and `float` beside `transform`, replace it; each equal to a fresh build); comparing the style texts as
    before, and comparing untrimmed values, each fail it. **macOS effect:** the template path (`update_document` →
    `apply_retag`) keeps the render tree for a patch whose inline style changes only paint-only properties, where it
    re-created it; the restyle and layout are the same code, but no macOS test covers it in this repo.
63. **A change of a box's geometry alone keeps the render tree** (`document.cpp` `geometry_only_property`, read by
    `apply_retag` beside `paint_only_property` for an inline style's, an animated declarations' and a changed rule's
    properties; the two `paint_only_property` tests it joins). Creating and initialising render items reads `display`,
    `position`, `float`, `list-style-type`, `white-space` and `flex-direction`; a box's size (`width`, `height` and
    their `min-`/`max-`), margins, padding, offsets (`top` … `left`, `inset`), gaps and flex sizes (`flex-grow`,
    `-shrink`, `-basis`) only layout reads, so a change of only those and paint-only properties keeps the tree for a box
    that is not `display: inline` (an inline element's geometry is its line's, which a kept tree did not lay out again:
    the padding of a `<span>` left the line as it was; it is replaced): the restyle marks the box's layout dirty up to
    its relayout boundary (`compute_styles` → `mark_layout_dirty`), the caller lays the document out again after every
    `commit_patch`, and edit 20 reports every box that moved or resized, exactly. A progress bar whose script sets
    `style.width` on every frame no longer re-creates the tree. Pinned by `external_test.cpp` (a `padding` style patch
    keeps the tree and reports what it moved; `float` replaces it) and WidgetRuntime's `testAGeometryChangeKeepsTheTree`
    (widths, a relative box's `left`, margin and padding, `gap` and `flex-grow`, a class whose rule sets `width` and
    `padding`, and a resize below the pixel epsilon kept; `display`, `position`, and `width` beside `float` replaced;
    each equal to a fresh build). Comparing geometry within the epsilon fails the resize below it; not testing
    `geometry_only_property` fails every kept step.
64. **A filter's and a backdrop's result: made only where it shows, and once for a host's paints** (`LHContainer.mm`
    `draw_filtered`, `draw_backdrop`, `allow_backdrops`, `EffectKey`; `LHHostSupport.h` `LHEffectStore`,
    `LHHostContainer::setEffectStore`, `allowBackdrops`). A filter's result draws inside its target and a backdrop's
    inside its box, so a paint whose clip misses it (a tile of WidgetRuntime's painter) makes neither: the cull comes
    after `FilterTargetFor` succeeds (its fallback paints the content unfiltered and unclipped) and, for a backdrop,
    after `backdrop_allowed`. A host's paints can share an `LHEffectStore`: each result is made once per key (the
    effect's owner and steps, the colour space, the target's rect rounded to a millionth of a pixel, its scales,
    orientation and reduction) by the first paint to ask, and one asking meanwhile waits; the entry is marked ready on
    every way out, a throw included. Past 32 MiB kept, a result is made where it is drawn and not kept. A backdrop's
    source paint gets no store, so no making waits for one that may be waiting for it. A culled or shared filter's
    inner backdrops are not drawn by every paint, so the host registers a paint's backdrops in tree order first
    (`allow_backdrops`): every paint allows the same 8 (`kMaxBackdrops`), as drawing them all in order did. In the
    widget harness's app, a 360 × 260 widget with a pulsing blurred glow, a backdrop counter and a rotating card drew a
    frame (9 tiles at 3×) in 137 ms before and 81–87 ms after; without the card's box shadows, 117 ms and 17 ms. Pinned
    by WidgetRuntimeIOS's `LayerTreePainterTests` (a filter and a backdrop across four tiles made once each; none for a
    tile they miss; tiles drawn together wait for and share them, a backdrop inside a filter included; every tile
    allows the same backdrops past the limit) and the widget harness's `WidgetHarnessEffectTests` (in the app process,
    where Core Image paints: each tile painted through a draw's store equals it painted alone). Without
    `allow_backdrops` a tile the filter misses allows 8 backdrops, not 6; without the culls a tile makes effects it
    does not show. **macOS effect:** none visible: LHDocument sets no store, and the culls skip only work its clip
    would discard.
65. **A box shadow's blur past 24 device pixels: one low-resolution raster, through any transform** (`LHContainer.mm`
    `draw_box_shadow`, `DrawDownsampled`, `DeviceScale`, `paint_box_shadow`'s `clip`). Such a shadow takes the
    downsampled path first (it was the exact path's fallback): its raster spans the shadow's own ink and three of its
    pixels more (so that an inset shadow has raster on both sides of the box's edge), is keyed by the shadow alone, with
    no sub-pixel phase, and is not clipped to the box, whose edge the clip at full resolution draws, so scaling it up
    darkens no ring along it (with the raster clipped, the parity test's largest difference was 112 levels).
    `DrawDownsampled` takes any CTM: the raster is in user space, sized by the CTM's columns and drawn through it, so a
    text shadow under a rotation is downsampled too. A smaller blur keeps the exact, sliced raster, which no longer
    falls back to the downsampled one (it never succeeds there). `LH_EXACT_SHADOWS` draws a big blur at full resolution,
    as before, for the parity test. A shadow that moves by fractions of a pixel or turns keeps one cache entry, where it
    painted a full-resolution Core Graphics blur in every tile it reached, every frame: the widget harness's widget with
    a rotating card under three 25–55 px shadows drew a frame in 81–87 ms before and 18 ms after. Pinned by
    `ShadowRasterTests` (a moved and a turned shadow keep one raster; against `LH_EXACT_SHADOWS` at 2× and 3×, a plain
    shadow still, moved and turned is within 2 levels, an inset, a spread, a rounded and a layered one within 8, in
    their gradients, where CoreGraphics' blur is shaped slightly differently at 24 px than at its full radius); its
    slice-parity and cache tests hold unchanged. **macOS effect:** LHDocument draws such shadows the same way, within 8
    levels of before.
66. **`grid-template`** (`style.cpp`, `string_id.h`'s `_grid_template_`, the `shorthands` table). `none` and `<rows> /
    <columns>` set `grid-template-rows` and `grid-template-columns`; the areas form (strings) drops the declaration, as
    an invalid one. It was unknown, so `grid-template: repeat(3,1fr)/repeat(3,1fr)` left a single column
    (widget-sandbox v0.3.0's `auto/29`, a tic-tac-toe board). Pinned by `FidelityRenderTests`'
    `testGridTemplateSetsRowsThenColumns`. **macOS effect:** LHDocument lays such grids out too.
67. **An aspect ratio follows the width min-width and max-width leave** (`render_block.cpp` `_render`). The ratio's
    height was taken from the available width, before `max-width` clamped it: `max-width: 264px; aspect-ratio: 1` in a
    374 px column was 264 × 374. `testAspectRatioFollowsTheMaxWidth`. **macOS effect:** the same in LHDocument.
68. **A replaced element sized by a percentage is compressible** (`render_image.cpp`; CSS Sizing 3 §5.2.2). Its
    min-content contribution resolves a percentage `width` or `max-width` against zero (its padding and border remain),
    so an `<svg>` at 58 % of a grid cell no longer widens the cell's track to 58 % of the whole grid. **macOS effect:**
    visible in LHDocument: an `img { max-width: 100% }` in an auto-width table cell no longer keeps the cell at the
    image's width (common in HTML mail), as in browsers.
69. **A replaced element's percentage height against an indefinite height is auto** (`render_image.cpp`; CSS 2.1
    §10.5). `calc_cb_length` resolves a percentage against whatever value the containing block carries, definite or
    not; an image now treats such a height as auto (its width and natural ratio decide), so a grid measuring its rows
    lays an auto-height cell out at its content's height, not 58 % of the grid's. Blocks keep litehtml's resolution.
    **macOS effect:** an `<img height="50%">` in an auto-height block takes its natural ratio in LHDocument too.
70. **A definite height's flexible rows take the size of an fr** (`render_grid.cpp` `expand_flexible_tracks`, shared
    with the columns; Grid §12.7.1). The free space was added on top of each row's content height, so a row holding a
    51 px mark in `repeat(3,1fr)` over 264 px came out 122 px and the others 71 (**macOS effect:** the same in
    LHDocument). Edits 66–70 together pin
    `testABoardsMarksSitInTheirCells` (the board as `corpus/bot-demos/04-tic-tac-toe` builds it, marks placed).
71. **A percentage width counts as auto for a block's min-content contribution** (`render_block.cpp` `_render`'s
    return; a calc() with a percentage included; CSS Sizing 3 §5.2.1, cyclic percentages). A block with a percentage
    width reported that width, resolved against the measuring width, as its minimum: a poll's fill at `width: 60%` gave
    its bar 60 % of the row as its min-content, and the bar, spanning `1fr auto`, widened the auto column
    (`auto/28`, `testAPollRowsAutoColumnFitsItsCount`). Not done: Grid §12.5's rule that an item spanning a flexible
    track is left out of the intrinsic tracks' sizing; the fork still spreads its min-content over them. **macOS
    effect:** in LHDocument a percentage-width block in a table cell or float now gives its content's min-content.
72. **`transform-box: fill-box` on SVG shapes, and the transform the painter applies** (`style.cpp`, `css_effects.h`'s
    `transform_box`, `css_properties`' `m_transform_box`, `el_svg.cpp` `svg_css_transform`, `element_transform`,
    `svg_path_bounds`, `svg_element_transform`). `fill-box` (and `content-box`, `stroke-box`, `border-box`, mapped to it:
    the stroke is not added) makes a shape's geometry box its reference box, with that box's top left as the initial
    origin, so `transform-origin: center` scales a chart's pulse dot about the dot (`auto/30`) where it scaled about the
    view box; an element with no geometry of its own (a group, text) keeps the view box. `svg_path_bounds` is the tight
    box (curve extrema) WidgetRuntime's getBBox used, moved here so the painter and the queries share it, and
    `svg_element_transform` exports the painter's per-element transform: WidgetRuntime maps a shape's box through it
    and its ancestors' up to the `<svg>` for `getBoundingClientRect`, which ignored SVG transforms.
    `testFillBoxScalesAShapeAboutItself` (a moved shape takes its box along, as a rebuild does). **macOS effect:**
    LHDocument's SVG shapes honour `transform-box: fill-box` too.

73. **Why render subtrees were replaced** (`document.h` `rebuild_reason`, `note_rebuild`; `telegram_external.cpp` at
    every place a patch session gives up its kept render tree; `document.cpp` `apply_retag`, `media_changed`,
    `viewport_changed`). `rebuild_reason()` names why the last `commit_patch`, `media_changed` or `viewport_changed`
    replaced render subtrees (edit 74), and is empty when it replaced none (a session whose every seed renders nothing
    included); it is set before the first replacement: `structure: <op>: <why>` (edit 89's refusals),
    `text: pieces not placeable`, `media`, `viewport`, and from `apply_retag` `element: <tag>` (an
    element it does not check: an image, an anchor, an input, an svg, or one it does not know), `pseudo-element
    children` (an element with a `::before` or `::after` before or after the match whose old ones do not go back: edit
    91), `attribute: <name>` (the first attribute other than `class`, `style` and the animated declarations whose
    value changed), `property: <name>` (the first changed inline or animated property neither paint-only nor
    geometry-only) and `rule: <property>` (of the such properties the rules that started or stopped matching declare,
    the smallest by name: the rules come sorted by address, which a first one would follow). The first reason of a
    session is kept. Tests read it to tell which change replaced subtrees. Pinned by `external_test.cpp`'s
    `testRebuildReasonsNameTheChange` (an insert, a removal, a circle's `cx`, an inline `display`, a class whose rule
    sets `position`, two rules at once (`rule: float` of `position`, `z-index` and `float`), a class change beside a
    `::before`, a paint-only inline style that keeps the tree, a media query that flips).
74. **A patch replaces the render subtree of its nearest boundary** (`document.h`/`document.cpp`
    `replace_render_subtrees`, `replace_root_render`, `replacement_boundaries`, `inside_any`, `outer_box`,
    `record_boxes`, `note_replacement`, `live_item`, `m_replaced_hold`, `replacement_steps`; `telegram_external.cpp` at
    the sites edit 73 names and in `commit_patch`; `element.h`/`.cpp` `remove_render`; `table.h`/`table.cpp` and
    `render_table.h`/`.cpp` `cells_taken`). After the boot litehtml's render tree is never re-created. Each site that
    gives up the kept tree names the element it changed (a seed: an insertion's, a removal's or new children's parent
    that edit 89 does not link,
    the owner of text pieces `replace_text_renderers` cannot place, which it now tries whatever else the session
    replaces, an element `apply_retag` does not call neutral) and records, as its first statement, the outer box
    (`display`, `float`, `position`: what a parent's `init` reads of a child) of it and its ancestors as they were.
    After the restyle, `commit_patch` walks each seed in the document up to its boundary: the first element whose outer
    box is what it was, that stands alone (`block`, `list-item`, `inline-block`, `table`, `inline-table`, `flex`,
    `inline-flex`, `grid`, `inline-grid`, or a replaced element) and has one live render item (`live_item`: registered,
    reachable from the root, outermost, distinct). Not `inline` (its block parent splits it around block children), nor
    a table part whatever it is (the table's grid holds its item: an `<img>` displayed as a cell), nor an item in an
    anonymous block made from it (`render_item_flex::init` wraps a flex item that is not a block box, an `inline-grid`,
    in a block that inherits from it and is outside its subtree). A seed under an element that rendered nothing and
    still does not is dropped, unless the document has had an `<svg>` (`has_svg`): a `<use>` or a `url(#…)` paint
    resolves ids anywhere in the document (`svg_element_by_id`), so the walk goes on to a boundary. A walk that reaches
    the root, or a document the table-cell cap has cut, replaces the root (which counts cells in tree order, as a build
    does); of nested boundaries the outer one is replaced. Every walk is memoised (each element a walk passes keeps
    where it led; `inside_any`), so a commit steps through each element once whatever its number of seeds: a thousand
    seeds under a 200-deep chain took 7,404 steps, where pairwise checks took 203 million. The boundaries' old subtrees
    leave `m_layout_marked`, `m_relayout_roots` and `m_observed` in one pass and their elements (`remove_render`, so
    `get_render_item`, which answers the first entry, answers the new item), and give back their tables' granted cells
    (summed over every `init` of a table: the flex wrapper inits its item twice and a build counts both; a grid sums its
    grants, not its asks). Each subtree is made as a build makes it (`create_render_item`, `fix_tables_layout` over its
    own tabular items, `init`), each parent's children are swapped in one pass, the new items are marked dirty up to
    their relayout boundary, and the old ones are kept alive until the next full layout (line boxes, flex lines and
    positioned lists can point at them until then). The root's replacement is a build's, and `media_changed` and
    `viewport_changed` make it too (so they now run `fix_tables_layout`). The render observer hears, within one
    `commit_patch`: the in-place piece replacements' `item_removed`, `item_added` and `text_replaced` as they happen;
    then one `subtree_replaced(old, new)` per boundary, told at the end of the commit (`report_replacements`, the old
    items kept alive until then) with each new one linked under `new->parent()`; a commit that replaced the root (a
    replacement that moved the table-cell cap's cut makes the root's too) tells the root's alone, from the root as it
    was; a root that appears or goes (`display: none` on the document element) is told too, its missing side null, and
    a root that goes leaves no size, as a fresh document's (`replace_root_render`); then `element_restyled` for each
    restyled element outside every replaced subtree; geometry at the next layout.
    Pinned by `external_test.cpp` (`testAfterTheBootSubtreesAreReplaced`,
    `testStructurePatchKeepsTheTreeOutsideItsBoundary`, `testReplacementBoundaries`: an inline parent, a display flip, a
    table part, an svg child, a circle in a hidden svg, an `<img>` as a table cell, an `inline-grid` flex item, a hidden
    subtree with and without an svg in the document, media; `testReplacedItemsLeaveTheirElements`,
    `testReplacementGivesBackTableCells`, `testReplacementGivesBackTableCellsUnderFlex`,
    `testReplacementWalksAreLinear`, `testReplacementAtTheTableCellCap`,
    `testACapCrossingReplacementReportsTheRootAlone`, `testAnInlineBoxInALineIsReplacedInPlace`,
    `testAPositionedDescendantFollowsItsContainingBlock`, `testListItemsAreNumberedAgain`, `testSeedsInOneSession`) and
    WidgetRuntime's `testAStructurePatchKeepsTheRenderTreeOutsideItsSubtree`, `testEditsNoOracleGeneratesPatch` (the
    document element hidden and shown, by its style and by a class),
    `testAHiddenSvgReferenceTargetRepaintsItsUsers` and `testAHiddenSpriteChangeRepaintsItsUsers` (a dropped seed leaves
    the `<use>` and the gradient that draw a hidden target stale), besides the render oracle, which holds every flush to
    a fresh build. Replacing the root every time fails the identity checks; not unregistering the old items fails
    `get_render_item` on the elements they belonged to; without the wrapper rule an `inline-grid` flex item is its own
    boundary; giving back one grid's cells drifts the count by a table per replacement.
75. **Elements' pseudo-classes change in place** (`document.h`/`document.cpp` `rematch`, `collect_ancestor_names`'s
    `m_left_pseudo`; `telegram_external.cpp` `pseudo_reach`, `can_set_pseudo_classes`, `set_pseudo_classes`;
    `element.h`/`html_tag.h` `has_pseudo_class`). WidgetRuntime sets `:hover` and `:active` on a tap's chain; the change
    is a patch, not a new document. `set_pseudo_classes` takes the flush's flips together (`pseudo_flip`: an element and
    its classes), sets or clears the classes, then matches again what they reach: each element; its descendants when a
    rule names a changed class in a compound that is not its subject (`m_left_pseudo`, collected as `m_left_classes`
    is); its siblings and their descendants when the sheets have sibling combinators or `of S` lists
    (`selector_scope() & 1`: a combinator reaches the later siblings, an `nth-last-child(… of S)` the earlier ones). The
    reach is one walk that stops at what it already took with its subtree, so a tap's nested chain visits each element
    once. Of those, only an element that some rule naming a changed class (`m_pseudo_class_rules`, collected with the
    scope) matches differently with the changes and without them is matched again (the changes made and undone once per
    run of 256 elements: edit 77's `differing_matches`, and its `rematch_reach` matches them), so a tap's chain leaves the root and the body (and their `::before` content and render items)
    alone when no rule reads their state. Each element matched again is matched as an attribute change matches it
    (`rematch`, `apply_retag`'s tail, with no attribute reset, so an element type with no attribute patch is matched
    too; an `<a>`'s `:link` entries dropped first, as `set_element_attributes` drops them) and keeps the render tree or
    seeds a replacement (edit 74) by the same rule; the reach's tops are restyled with their subtrees. The predicate
    refuses an element inside a `<select>` and generated content (counters run again at the commit: edit 78); each
    element visited is a predicate step. The caps are no refusal: near one the commit replays the style pass (edit 84).
    Pinned by
    `external_test.cpp` `testPseudoClassStateRematchesItsReach` (a paint-only rule, a rule on a descendant, a rule on the
    next sibling, `::before` content, a `<table>`, an earlier sibling by `nth-last-child(… of S)`, an ancestor no rule
    reads, a chain of two set together, a link's `:link`, and a hover incrementing a counter the next element reads),
    each against a document built with the
    classes set, `testRefusalsSayWhy` (both caps accepted), and WidgetRuntime's `testAPressChangesOnlyWhatItRestyles` and
    `testADeepTapPatches`.

76. **A predicate names why it refused** (`document.h` `refusal`, `refuse`; `telegram_external.cpp`
    `can_replace_text`, `can_set_element_attributes`, `attribute_change_allowed`, `structure_parent_allowed`, `structure_insertable`,
    `structure_removable`, `can_insert_subtree`, `can_remove_subtree`, `can_set_pseudo_classes`).
    Each refusing answer of those predicates goes through `refuse(why)`, which keeps a string literal that `refusal()`
    returns until the next refusal; a predicate that passes an inner one's false on leaves the inner reason. The reasons:
    not a rendered element; an element type with no attribute patch; positional or sibling selectors in the sheets;
    inside a `<select>`; a document-level element; a parent whose children an element
    reads; generated content; a subtree a parent's own append refuses; an invalid subtree; the depth cap; the element
    cap; the text-piece cap. WidgetRuntime keeps the latest refusal and its reason (`RenderTree::refusedBy`,
    `lastPatchRefusal`) and hands the change to its next path. Pinned by `external_test.cpp` `testRefusalsSayWhy` and
    `testReplaceTextRefusals`.

77. **An attribute change matches what its names reach** (`document.cpp` `collect_names`, `selector_scope`'s
    `m_class_rules`, `m_id_rules`, `m_attr_rules`; `telegram_external.cpp` `changed_names`, `names_reach_others`,
    `attribute_reach`, `match_attribute_reach`, `differing_matches`, `rematch_reach`, `take_reach`). A change of a class,
    id or attribute that a selector names in an ancestor position (`m_left_*`, as `collect_ancestor_names` fills them,
    `:link` naming `href` and a custom property's rule its subject's names), or any attribute change when the sheets have
    sibling combinators or `of S` lists (`selector_scope() & 1`), is no longer refused: `set_element_attributes` records
    the element with its attributes before the session, and the session matches the recorded changes over their reach
    at the first of `set_pseudo_classes` and `commit_patch`, so before its pseudo-class flips and each filter compares
    one step of the chain. The reach (`attribute_reach`, one walk that stops at what it already took with its subtree,
    as `pseudo_reach`, each change and each element visited a predicate step): the element's subtree when a changed
    name is in an ancestor position, and with sibling selectors in the sheets every sibling's subtree when some rule
    names a changed name, each parent's children taken once however many of them changed. A change of names no rule
    names reaches nothing and is not recorded (an animated style on every frame, beside an unrelated `+` rule). A recorded element in the reach
    is matched again whatever its match (it was matched with the other changes' attributes as they were); any other is
    matched again when a rule naming a changed name (`m_class_rules`, `m_id_rules`, `m_attr_rules`: every rule naming the
    name anywhere, `:checked`, `:disabled`, `:enabled`, `:link` and `:lang()` naming the attributes they read) matches it
    differently with every recorded element's attributes before and after (`differing_matches`, edit 75's run-of-256
    filter, flipping the attributes with `reset_attributes`), except for an `href` change, which matches the whole reach
    again because `:link` follows `href` only at a match. Each is matched as edit 75 matches (`rematch_reach`, also edit
    75's and edit 17's `var()` readers'), in a new match epoch, since a match memo of the epoch replays its rules without
    `el_anchor::apply_stylesheet`, which gives back the `:link` the rematch strips; an element of the reach whose paint
    order or paint group changed is restyled itself, so that the render observer hears of it (edit 20). Counters run
    again at the commit (edit 78). WidgetRuntime lists `attribute_reach` of a flush's changes in its selector
    step plan, and its style-change step (CSS transitions and animations) looks at every element below the restyle tops
    and the subtrees styled fresh the commits handed it (`take_restyled`: a moved node, which the structure patch
    builds again where it lands, is a fresh subtree), as it looks at every element after a build. Pinned by
    `external_test.cpp` `testAttributeChangeRematchesItsReach` (a class, an id and an attribute an ancestor position names,
    the next and an earlier sibling, an `href` under `a:link`, `details[open]`, a descendant's display, a class declaring a
    custom property, a class and a hover one rule reads together, and nested changes reaching once), the patched cases of
    `testSetAttributeRefusals` and `testSetAttributeFixRound`, and WidgetRuntime's `testARootClassPatches`, `testAnAncestorsClassStartsTransitions`,
    `testAHoverStartsTransitions`, `testAPlayStateChangeBesideAnInsertionIsHeard` and the render oracle group "names in
    ancestor positions".

78. **Counters run again in a build's order** (`document.h`/`document.cpp` `rematch_begin`, `rematch_pass`,
    `rematch_finish`, `rematch_state`; `telegram_external.cpp` `rerun_counters`, `counted_elements`,
    `counters_in_sheets`, `note_counted_subtree`, `m_patch_counters`, `commit_patch`; `html_tag.h`/`.cpp` `counted`,
    `apply_matching_pass`; `el_before_after.h`/`.cpp` `reads_counters`). litehtml's counters are state a build makes as
    it goes: each `add_style` runs `handle_counter_properties` on the style so far, which resets a counter on the
    element or increments the one `element::find_counter` finds (on the element, a previous sibling, an ancestor or an
    ancestor's previous sibling), and a `::before`/`::after` takes `counter()`/`counters()` text as it is made. A build
    runs the master pass, the attributes and the author pass, and the user pass, each over the tree in order. A patch
    matches an element out of that order, so an element is counted (`html_tag::counted`: its style declares
    `counter-reset` or `counter-increment`, it holds counter values, or a `::before`/`::after` of it reads a counter or
    is counted itself) when
    the session matches it again, counted before or after (`rematch_finish`), removes a subtree holding one
    (`unlink_subtree`) or inserts one (`commit_patch`'s styling of the new subtrees); then `commit_patch`, after every
    other match of the commit and before its seeds are taken, runs `rerun_counters`: one walk collects the counted
    elements in tree order and clears every element's counter values, and each counted element is matched again
    (`rematch_begin`, its pieces released and an `<a>`'s `:link` dropped, as `rematch_reach` does), pass by pass over
    them in tree order (`rematch_pass` → `apply_matching_pass`: the element's selectors alone, its children left in place
    so that a counter's sibling lookups read what a build's read, set aside only for `parse_attributes`, which
    recurses; `:link` added per pass as `el_anchor::apply_stylesheet` adds it; then the pass's rules applied to its
    generated children where a build's recursion reaches them, `apply_matching_pass_generated`: its `::before` and
    `lh-*` parts at once, its `::after` once the counted elements below it have had the pass, so a `*` or `li > *` rule
    reaches them, and in a build's order), then each kept or replaced
    (`rematch_finish`) and the tops restyled. The custom-property tops the replay notes are dropped (the elements are
    matched with what they were matched with). `rematch` is `rematch_begin`, the three passes through the match memo
    (`apply_matching`) and `rematch_finish`, as before. Nothing runs when the sheets use no counters (`selector_scope() &
    4`): an inline style's counters are inert in litehtml (`compute_styles` adds the `style` attribute with
    `style::add`, never `add_style`), so the predicates' counter refusals are gone (edits 17, 18, 75, 76, 77).
    `find_counter`'s search (the element, then the siblings before it, nearest first, at every
    level up to the root) reads the siblings in place, and every element it visits is a selector step of the matching
    pass (`counter_lookup_step`, in builds and patches alike: past the pass's budget the counter is not found, as a
    selector past it matches nothing); `get_counters_value`'s walk up counts a step per level. So a numbered list's
    quadratic lookups are counted and cut by the steps' budget. Pinned by
    `external_test.cpp` `testCountersRunAgainInBuildOrder` (a hover on a numbered item, an item that stops counting, one
    inserted first, the third removed, the first moved last; `li > *` and a `*` reset reaching the `::before`, an
    `::after` that counts reached by `*` after its owner's nested list, a `::before` that counts and reads nothing,
    hovered beside and inserted), the counter cases of `testRefusalsSayWhy`,
    `testSetAttributeRefusals`, `testStructureRefusals`, `testReplaceChildrenUnderPositionalSelectors` and
    `testPseudoClassStateRematchesItsReach`, and WidgetRuntime's `testCountersPatch` (02-weekly-bare's tap, a story
    appended and removed, a tap under a `*` reset, a counter reset on `<body>`), `testCounterLookupsCountAsSelectorSteps` (300
    numbered items patch within their bound, counting their lookups; 2,000 cut at the boot and patched, replayed uncut) and the
    render oracle's "counters" groups.

79. **The environment changes in place** (`media_query.h`/`.cpp` `would_flip`; `style.h`/`style.cpp` `environment`,
    `environment_viewport`, `environment_scheme`, `note_environment`, `text_may_hold_viewport_unit`, the declaration
    cache's `cached_declaration`; `css_effects.cpp` `fold_math`; `stylesheet.h` `replace_selectors`; `html_tag.h`
    `style_environment`; `document.h`/`document.cpp` `parsed_master`, `parsed_author`, `environment_key`,
    `m_master_styles`, `author_css`; `telegram_external.cpp` `environment_reach`, `environment_changed`,
    `reparse_environment`, `environment_users`, `media_users`). A width, a height or a media feature changes without a
    new render tree. `environment_changed` reads the container's media features again and, in the patch session (opened
    unless one is), applies them to the media lists. It matches again (`rematch_reach`) the elements whose
    `m_used_styles` hold a rule under a list that flipped, since litehtml records a rule that matches while its list is
    off, so no selector is tested to find them. A viewport unit folds to pixels while a declaration is parsed (edit 11),
    so a parse records what it read of the environment: `fold_math` notes `environment_viewport` into the declaration
    being parsed (`style::add_property`'s scope), `combine` carries it into an element's style, and the declaration
    cache keeps it with each entry. When the viewport moved, the master and author sheets are parsed again under it
    (finalize's parses, now `parsed_master`/`parsed_author`, through their caches, whose keys carry the viewport where a
    text may hold a viewport unit: `environment_key`; they did not, so a build at another width took a stale fold), each
    rule whose style read the viewport is replaced by a copy holding the new parse's style and keeping its media list
    (the same text parses to the same sorted rules, paired by position: `testEnvironmentParsesPairUp`), media lists no
    rule uses are dropped, and every element whose style, or a `::before`'s or `::after`'s, read the viewport is matched
    again (rules, inline styles and `var()` values folded at compute alike). What the document derived from its sheets
    is made again when next asked (`forget_sheet_derivations`: `selector_scope`'s indexes hold rules by pointer, and a
    replaced copy can be freed), and a match again keeps the rules the element held alive while it compares them
    (`rematch_state::held_before`): a copy an earlier change made has no owner but what matched it
    (`testEnvironmentChangesTwiceKeepNoFreedRule`, a use-after-free under AddressSanitizer before). A match
    again keeps the render tree where only paint or geometry changed (edit 75). `environment_reach(next, …)` answers
    without changing anything what the change matches again (`would_flip`), for a caller's selector step plan.
    `media_changed`/`viewport_changed` stay as `LHDocument`'s. WidgetRuntime's `setWidth` and `setReducedMotion` mark
    the journal's environment (`Journal::markEnvironment`): the next flush applies it as its patch session's first
    change, lays out at the new width, and has the style step look at every element. Pinned by `external_test.cpp`
    `testEnvironmentParsesPairUp` and `testEnvironmentChangesMatchFresh` (a breakpoint over `::before` content and
    counters both ways, viewport units, counters under a media rule, reduced motion, a paint-only one that keeps the
    tree), and WidgetRuntime's `testWidthChangePatches` and `testReducedMotionPatches`.
80. **The theme changes in place** (`web_color.cpp` `parse_light_dark_color`, `style.cpp` `color-scheme`: the
    scheme mark; `document.h` `change_root_declarations`, `root_declarations_text`, `environment_change`;
    `telegram_external.cpp` `change_root_declarations`, `environment_reach`, `environment_changed`,
    `reparse_environment`). The scheme is edit 79's second part of the environment. Edit 13 resolves `light-dark()` and
    a `color-scheme` naming both while a declaration is parsed, and each notes `environment_scheme` there (with a
    container), so a rule, an inline or animated style, a `var()` value substituted at compute (`subst_vars` parses it
    through `add_property`) and the root declarations all carry the mark into the element's style. A value kept as
    tokens and resolved later (a shadow or a filter at compute, an SVG paint at draw) is marked where `add_property`
    keeps it when it names `light-dark()` (a custom property's readers are marked instead), and an SVG `fill` or
    `stroke` attribute naming it marks the element's style (`html_tag::note_paint_attributes`; pinned by
    `testSchemeChangeRestylesSvgPaint` and `testSchemeChangeMatchesFresh`'s box-shadow). A scheme change is
    then edit 79's path with the scheme bit: the sheets parsed again under it through their scheme-keyed caches, each
    marked rule swapped for the new parse's (`testSchemeParsesPairUp`), the root declarations parsed again from their
    text when they read it, and every element whose style read it matched again with its subtree; a
    `prefers-color-scheme` list flips as any media list does. `change_root_declarations` sets new root declarations
    (edit 26) in the patch session and matches the root again (a restyle would keep the old ones, which its style
    combined in), which notes it as a custom-property top, so the commit matches the `var()` readers below it again
    (edit 17); equal text changes nothing. `environment_reach(next, declarations_changed)` lists the elements whose
    style read the scheme when it changes, and the root when the declarations do. WidgetRuntime's `setTheme` marks the
    journal's environment, as a change of the content safe area's does (WidgetRuntime's root declarations are the theme's
    then the safe area's, `rootDeclarationsOf`); the flush calls `change_root_declarations` before `environment_changed`.
    Pinned by `external_test.cpp` `testSchemeParsesPairUp` and
    `testSchemeChangeMatchesFresh` (`light-dark()` in a sheet, inline, inherited, through `var()` and in unchanged root
    declarations; a `prefers-color-scheme` rule; a `color-scheme` over an `<input>`; new root declarations read
    through `var()`; the paint-only ones keep the tree), and WidgetRuntime's `testThemeChangePatches` and
    `testAThemeSwitchKeepsTheTree`.
81. **Sheets change in place** (`stylesheet.h` `parsed`, `sheet_ends`, `end_sheet`, `replace_selectors`; `el_style.h`
    `sheet_pieces`, `replace_pieces`; `document.cpp` `add_stylesheet`, `parsed_author`, `m_sheets_parsed`;
    `document.h` `replace_style_text`, `apply_sheets`, `m_patch_sheets`; `telegram_external.cpp` `replace_style_text`,
    `apply_sheets`, `commit_patch`, `count_pieces`, `document_level_element`, `subtree_shape::sheets`, `link_subtree`,
    `unlink_subtree`). A `<style>`'s text, and a `<style>` inserted or removed, change the author sheets without a new
    render tree. `replace_style_text` gives a `<style>` one piece holding the new text (or none) in the patch session;
    `insert_subtree` and `remove_subtree` note a subtree holding a `<style>` (a `<style>` is no longer
    a document-level element). Then `commit_patch` first runs `apply_sheets`: the `<style>` texts read from the tree in
    tree order (finalize's `parse_attributes` order; `add_stylesheet` adds nothing once finalize has parsed the sheets,
    so a `<style>` an inserted subtree's `parse_attributes` meets is read here), paired with the current ones by their
    common ends and a longest common subsequence (none past a 2^20-cell table: every sheet there is new), and parsed as
    finalize parses them, through the styles cache. A paired sheet keeps its rules: `css` keeps its selectors in parse
    order and each sheet's end there (`parsed`, `sheet_ends`), so the new parse's k-th rule of the sheet is replaced by
    the old parse's k-th (`css_selector::m_order` is read only by the sort, which never runs again), and what holds those
    rules keeps its match. Matched again (`rematch_reach`): each element that holds a rule the sheets lost (or whose
    `::before` or `::after` does), and each one a new rule matches, every new rule apply_selector's tag and class filter
    lets through tested against every element without pseudo-classes, in a counted pass (`counted_selection`,
    html_tag.cpp: every step select takes is the session's, and none past its limit, the session then cut); subtrees the
    session linked are left to the commit's fresh styling. The same applied texts change nothing and parse nothing.
    `differing_matches` (edits 75, 77: the rules naming a changed state or name tested over its reach) runs in a counted
    pass too, and the commit's attribute reach fills the indexes it reads first (`selector_scope`), which a sheet change
    forgot (pinned by `testSheetTestsCountIntoTheSession`, `testUnchangedSheetsParseNothing` and
    `testAClassChangeBesideASheetChangeMatchesFresh`). The media lists no rule uses are dropped and the features applied to the new ones, and
    what was derived from the sheets is computed again when next asked (`forget_sheet_derivations`: `selector_scope` and
    its indexes, the content tags, the pseudo-element facts, the style-rule bytes, the share cache). A `<style>`'s piece is in its own list, which
    `element::children()` never holds, so `count_pieces` counts it. `<style media>` is never applied, by a build or a
    patch: `el_style` holds no attributes (upstream `element::set_attr` is empty). WidgetRuntime routes every journal
    that touches a `<style>` (its children, its Text, its attributes, a subtree holding one) to the structure path:
    `RenderTree::planSheets` reads each `<style>` again where its children or Text changed, checks every sheet of the
    patched tree in tree order against Ruling 7's 64 KiB and profile 1's budgets (past one, the flush walks the cut and
    leaves out the sheets a fresh build leaves out), and the commit calls `replace_style_text`, keeps each sheet's piece in its `<style>`'s entry and
    each sheet in `RenderBuild::sheets`, splices the render input and has the style step read `@keyframes` again; a
    `<style>` in an inserted subtree is built (`Builder::styleSheet`). Pinned by `external_test.cpp`
    `testSheetChangesMatchFresh` (a rule added and removed, two equal rules swapped, a paint-only change keeping the
    tree, an `@media` block, counters added and removed, a sheet emptied and filled, a `<style>` inserted before and
    after another and removed, one in the body, a subtree holding one inserted and removed), and WidgetRuntime's
    `testSheetChangesPatch`, `testStructureFallsBack` and `testASheetPatchReadsNewKeyframes`.
82. **The document element replaced in place** (`document.h` `replace_root`, `can_replace_root`;
    `telegram_external.cpp` `replace_root`, `can_replace_root`). `replace_root` takes a detached
    `html_tag` subtree the caller built as `insert_subtree`'s, in the patch session: the old tree goes as a removal does
    (`unlink_subtree`: its counted elements noted, its elements uncounted, its pieces released and held to the commit;
    its style charges given back, the pointer elements cleared, `:root` taken off), and the new one comes as an
    insertion does (counted, `:root` set, styled fresh at the commit, where `add_root_declarations` gives it the root
    declarations, and `m_patch_sheets` set when either tree holds a `<style>`, so edit 81 applies its sheets); the root
    is the session's replacement seed, so the render tree is made again from it. `can_replace_root` asks what
    `can_remove_subtree` asks of the old tree and the depth, element and text-piece caps of the new one; it
    takes html, head and body, which an insertion refuses. WidgetRuntime replaces the document element when the document's children changed and
    it is another node (`RenderTree::flushRoot`): everything published goes, the new document element is built detached
    as a build walks it (`buildRenderRoot`, an empty `<html>` under Ruling 11), its sheets are planned (edit 81), and the
    render input after the doctype, the maps (each node that stays keeping its mirror key) and every count are the new
    tree's. The root's render item is made again, which the mirror re-places as any replaced subtree, the root Context
    keeping its id. A comment or the doctype
    beside the document element renders nothing: that flush is clean, and a document element that went and came back
    is replaced by itself. A change of the document element's children replaces it too when it changes which head or
    body is the document's own or moves either (no subtree build makes those, `RenderTree::ownHeadAndBodyStay`); any
    other is reconciled as any element's children are, the root's render subtree replaced (edit 74). An own attribute change of the document's html, head or body beside structure (no subtree
    build makes one of those; a body whose `dir` is `auto` hears every change under it) is set in place with
    `set_element_attributes` in the structure session, its start tag and budgets kept in step. Pinned by `external_test.cpp` `testRootReplacementMatchesFresh`, and WidgetRuntime's
    `testDocumentChildrenPatch`, `testATapOnAReplacedDocument`, `testChangesUnderTheDocumentAreJournaled`,
    `testAnHtmlChildBesideTheBodyPatchesInPlace` and the oracle's "document children" group (edit kind 28).
83. **Only what renders counts** (`element.h`/`element.cpp`, `html_tag.h`, `el_table.h`/`el_table.cpp`, `el_style.h`,
    `el_script.h` `accepts_child`, `accepts_text`; `document.h` `build_elements`, `pseudo_elements`). Each element
    answers whether its own `appendChild` would link an element with a given `tag()`, or a text piece: `html_tag` takes
    both, `el_table` takes tbody, thead, tfoot and caption and no text (its `appendChild` asks `accepts_child`, so the
    two cannot disagree), `el_style` takes text only, `el_script` both, and a plain `element` neither. WidgetRuntime's
    Builder asks before any limit counts an element: one its parent refuses (a `<div>` or a `<tr>` straight under a
    `<table>`) renders nothing, counts toward no cap or budget, and its subtree is not walked; a Text under a parent that
    takes no text stays in the render input (its bytes and units count) but makes no pieces and asks the piece cap
    nothing. So a build's counts are what litehtml holds, a patch's agree with them, and inserting, changing or removing
    a refused element renders nothing. `build_elements` (what `external_element_allowed` counted) and `pseudo_elements`
    (those alive) are read by WidgetRuntime's oracles. Pinned by `external_test.cpp`
    `testAcceptsChildMatchesAppendChild`, and WidgetRuntime's `testRefusedChildrenCountNothing`,
    `testRefusedInsertionsPatch`, `testRefusedElementsCountNothing` and `testARefusedElementsOwnChangeRendersNothing`.

84. **Near a cap the commit replays the style pass in build order** (`document.h`/`telegram_external.cpp`
    `document_text_pieces`, `generated_cut_in_play`, `replay_generated_content`, `set_replay_step_limit`,
    `last_replay_*`, `generated_replays`, `style_pass_limits`, `generated_fingerprint`, `table_limited`; `el_text.h`
    `generated`; `el_before_after.cpp`, `el_form.cpp` `generated_scope`; `html_tag.h`/`.cpp` `parse_own_attributes`,
    `adopt_matched`, `used_rules`; `document.cpp` `rematch_begin`, `rematch_finish`, `rematch_settle`,
    `pseudo_element_allowed`, `replace_root_render`). A build makes the document's own text first and the generated
    content (`::before`/`::after` content, a form control's `lh-*` parts) while it matches, in match order: the master
    pass over the tree, the attributes (where a control makes its parts), the author sheets, the host sheet. A patch
    matches in its own order, so near the text-piece, pseudo-element or style-byte cap its cut can differ from a build's.
    - Generated pieces are made inside a `generated_scope` and counted apart (`m_generated_pieces`), so
      `document_text_pieces()` is the document's own text, which every `can_*` text check counts against
      `max_text_elements`; `release_pieces` counts the generated pieces and pseudo-elements it releases too
      (`unrelease_pieces` takes them back for those a match puts back, edit 91), and
      `pseudo_element_allowed` leaves the released pseudo-elements out.
    - `generated_cut_in_play()`, asked by `commit_patch` after `rerun_counters`, answers whether the session changed what
      the cut reads (generated content made or dropped and not made again equal, which `rematch_finish` judges by
      `generated_fingerprint`; the document's text; the style bytes) while the style budget or the pseudo-element cap
      was reached, or the text-piece cap was with content rules in the sheets, or the generated pieces could reach it:
      the document's text, the generated pieces and the most a pseudo-element held while it made its next content (one
      rule's content after another's: `note_generated_transient`) reach `max_text_elements`. A build's master pass gives
      every element a master content rule names (`summary`) its content before the author pass can drop it, all of it at
      once, so those elements count at their most toward both caps: `m_master_content_elements` (counted at finalize and
      by `link_subtree`, `unlink_subtree` and `replace_root` through `shape_of`) times the most pieces one such rule
      makes (`master_content_pieces`, read from the master sheet when first asked; content that is not literal strings
      counts as `max_text_elements`).
    - `replay_generated_content()` then sets every element's generated content aside (held to the commit), counts the
      document's own pieces in the tree (replaced render items can keep others alive until a layout), resets the caps'
      flags and the style budget (`m_style_budget_epoch++`), and matches every element again pass by pass in a build's
      order, as edit 78's `rerun_counters` does, with every element's attributes parsed between the master and author
      passes. An element whose generated content comes out the same (shape, text, and the rules each part matched) gets
      its old content back with the new match (`adopt_matched`), so its render items stay; elsewhere it is a
      replacement seed, and near the style budget the root is (a match can keep its rules and lose declarations). Every
      element is restyled at the commit. Its steps are a counted session limited to `set_replay_step_limit` (the
      session's total), reported with the weight it matched every rule against (`last_replay_weight`: `matching_weight` summed, as a patch's re-match is weighed) and the nodes its
      walks visited (`last_replay_visits`, linear in the tree: where an owner's `::after` waits for its subtree, each
      element's subtree end is known from the tree order, never climbed to).
    - The limits the latest style pass reached are kept in the order reached (`style_pass_limits`, "table" last when the
      cell cap cut the render tree). A root made again counts its cells from zero, and a cap it had reached is not
      reported again.
    - A build whose matching its selector-step session cut (`note_match_cut`, which WidgetRuntime calls after a boot
      litehtml's 4,000,000 steps cut) is matched where a fresh build with no cut would match every element:
      `generated_cut_in_play` answers true at the next commit whatever the session changed, the replay runs within its
      limit, and the mark goes unless the replay was cut too.

    The refusals that only kept a patch from cutting elsewhere go: `pseudo_content_possible()` with a cap reached,
    `part_content_possible()`, `pseudo_cap_in_play()`, `style_budget_in_play()` in the structure predicates,
    `m_pseudo_limited`, and the table-cell cap in `can_set_element_attributes`, `structure_insertable` and
    `can_replace_root`. WidgetRuntime sets the replay's limit to its patch's step limit (`kPatchSelectorSteps`), stops
    the widget (`stopInternally`) when it is cut (litehtml's document then patched and never laid out, the published
    tree kept), and publishes `style_pass_limits()` after its own walk's limits as the
    patch's. Pinned by `external_test.cpp` `testTwoContentRulesAtTheCapReplayAsABuild`, `testReplayFollowsBuildOrder`,
    `testStyleBytesReplayFromZero`, `testPaintOnlyChangeDoesNotReplay`, `testMasterContentCountsAtTheTextCap`,
    `testMasterContentCountsAtThePseudoCap`, `testReplayWalksAreLinear`, `testACutBootReplaysAtItsFirstCommit`, the I2
    shapes and the range shape in `testSetAttributeMatchesFresh`, `testStructureCaps`, `testRefusalsSayWhy`, and
    WidgetRuntime's `testPseudoContentAtTheCapPatches`, `testStructureBesidePseudoContentPatches`,
    `testSpanChangeCutsAtTheCellCap`, `testMasterContentNearTheTextCapPatchesAsABuild`,
    `testAReplayCutLeavesNothingToSelect` and `testACutBootsFirstPatchReplaysUncut`.

85. **The tabular items are let go after the table fix** (`document.cpp` `fix_tables_layout`). A build, a replaced
    subtree and the HTML path fill `m_tabular_elements` with the tabular render items `create_render_item` made, and
    `fix_tables_layout` reads them to make the anonymous table boxes; then each item's `init()` can replace it with an
    item of another type. The list is cleared at the end of `fix_tables_layout`, which the replaced-subtree path already
    did after it: kept from a build, it held the items `init()` replaced, and with them the elements under them, so a text
    replaced under a block in a `<tr>` with no `<table>` stayed alive, one piece more than a fresh build counts. Pinned by
    `external_test.cpp` `testFixedTablesHoldNoReplacedText`.

86. **An inline-flex or inline-grid paints its children once** (`render_item.cpp` `draw_children`). The inline pass
    paints an `inline-flex` or `inline-grid` and its own stacking context, as it does an `inline-block`; the block and
    float passes recursed into it all the same (only `inline-block` stopped them), so its blockified flex or grid items
    were painted twice, translucent paint composited twice (a `box-shadow` at `rgba(0,0,0,.1)` read about 0.19), as
    Chromium never paints them. Those passes now stop at all three, as the hit test (`get_child_by_point`) already did.
    WidgetRuntime's mirror, which walks the same loop, no longer meets an item painted in several places. Pinned by
    `external_test.cpp` `testAnInlineFlexPaintsItsChildrenOnce` and WidgetRuntime's
    `testAMovedInlineFlexPublishesOperations`.

87. **A restyle reuses the positioned lists only while what files them holds** (`document.cpp`, `restyle_after_patch`'s
    `positioned_fresh`). A restyle that keeps the render tree reuses the positioned lists when no element's `position`
    changed. `add_positioned` also files a positioned box under its nearest transformed or `contain: layout`/`paint`
    ancestor, so the snapshot holds those too: a transform going (a class removed, an animation ended) left the box on the
    list of an ancestor that no longer paints positioned boxes, and nothing painted it, where a fresh build does. Pinned by
    `external_test.cpp` `testATransformGoingKeepsPositionedPaint` and WidgetRuntime's
    `testAnEndedTransformAnimationPaintsItsPositionedChild`.

88. **Structure beside `:empty` patches** (`telegram_external.cpp` `can_insert_subtree`, `can_remove_subtree`,
    `note_empty_parent`, `commit_patch`; `document.h` `empty_in_sheets`, `sibling_combinators`).
    `:empty` in the sheets (bit 8) no longer refuses an insertion or a removal. With it,
    each parent the session changes the children of is noted with whether it matched `:empty` before the session's
    first change, and `commit_patch` matches again (`apply_retag`, its `::before`/`::after` pieces released first) each
    one whose answer flipped, checked (a replacement seed where more than paint changed: edit 89 may keep its render
    tree), and with sibling combinators in the sheets (bit 1) every
    element of its later siblings' subtrees (`.e:empty + p`, `.e:empty ~ div span`). Those are outside the parent's
    replacement and such a rule can change their boxes and content (`display:none`, a float, `::before` content), so
    each is matched as an attribute's reach is: its outer box recorded before any match (`record_boxes`), and a
    replacement seed where more than paint changed. A parent's children are walked once, from its first flipped
    child, and each subtree once, whatever the number of flipped siblings before it; a subtree inserted in the session
    is styled afresh. The parent's own descendants never read it (an empty element has none), and the `var()` readers
    below what is matched again follow (edit 17). Pinned by
    `external_test.cpp` `testStructureBesideEmptyMatchesFresh` (sibling rules that hide, float and give content
    included) and WidgetRuntime's `testStructureBesideEmptySiblingsPatches` and randomized oracles (their
    `:empty` groups patch).
89. **A block-level child links into and unlinks from a block formatting context** (`document.h`/`document.cpp`
    `render_observer::subtree_linked`, `subtree_unlinked`, `plan_link`, `link_render_children`,
    `release_render_subtrees`, `make_render_subtree`, `report_replacements`, `m_patch_structure`, `m_pending_links`,
    `m_pending_unlinks`; `telegram_external.cpp` `note_structure`, `insert_subtree`, `remove_subtree`, `commit_patch`).
    An insertion or a removal no longer seeds its parent (edit 74): each notes the parent once, with its first
    operation (`insert`, `remove`). After the restyle and
    the style-budget replay, `commit_patch` asks of each such parent in the document and outside a subtree the session
    inserted whether its render children follow by links alone (`plan_link`): its one live item is a
    `render_item_block_context`, and the children `render_item_block::init` would make from its children now (each
    child that is not inline alone, each run of inline children an anonymous block when it holds more than white space,
    a run of white space alone dropped, a child with `display: none` or a comment nothing) are its render children,
    position by position, but the fresh block-level ones and the items of the children it lost. Otherwise the parent is
    a seed (edit 74) under `structure: <op>: <why>`, the first of: `at the table-cell cap` (the document is cut there),
    `renders nothing` (no render item: a seed the walk drops, unless the document has an `<svg>`), `several render
    items` (an inline split around a block), `in a replaced element`, `in an inline context`, `in an inline`, `in a flex container`, `in a
    grid`, `in a table` (a table, row or part), `elsewhere` (any other item class), `in a closed details`, `a table
    part outside a table` (a rendered child that is one, an anonymous table among the render children, or a removed one:
    `fix_table_parent` wraps it with its like siblings in an anonymous table, which a link does not follow), `the
    formatting context flips` (no rendered child left that is a non-float block box), `an inline holding blocks` (a
    render child that is neither a child's item, nor an anonymous block made from the parent, nor a removed child's: a
    block `split_inlines` put there), `a float or an out-of-flow box` (a child linked or unlinked floats or is absolutely
    or fixed positioned), `inline content` (any other difference: an inline child inserted or removed, a run split or
    merged). A parent whose `:empty` answer flipped (edit 88) is matched again with the check, so one whose box or more
    than its paint the flip changes is a seed, and its boundary holds its links (an empty parent holding a block-level
    `::before` is a block formatting context, and a flip to `display: flex` must not link into it). The refusals' seeds
    join the session's.
    After the boundaries are replaced, each linkable parent outside every boundary links (`link_render_children`): the
    removed children's render subtrees leave the parent's item (their tables' cells given back, out of the layout's
    lists and their elements, kept alive until the next layout), each fresh block-level child's is made as a build
    makes it and put where it goes, the new items and a parent that lost one are marked dirty, and the parent's list
    items are numbered again as `render_item_block::init` numbers them (from its `start`, every list item counted, the
    number in `list_index`). A replacement swaps a child's item where it was, so the plan holds; one that did not would
    replace the root (no known change does). A link that moves the table-cell cap's cut replaces the root, as a
    replacement does. Edit 74's positional re-match (edit 42) now checks: a child whose box or more than its paint the
    match changes is a seed, its box recorded before any match, since its parent's render tree is kept. The observer
    hears, at the end of the commit, the replacements, then `subtree_unlinked(old)` for each unlinked item (alive until
    then), then `subtree_linked(item)` for each linked one; a commit that replaced the root tells the root's alone. A
    commit that only linked or unlinked has an empty `rebuild_reason()`. `element_restyled` leaves out the elements of a
    linked subtree, and is told for each list item whose number changed. The classification and the link step through
    the parent's children once each (and an anonymous block's children). Pinned by `external_test.cpp`
    (`testBlockChildrenLinkAndUnlink`, `testStructureRefusalsNameTheirCase`, `testAPositionalChangeBesideALink`,
    `testAnEmptyParentsFlipBesideALink`,
    `testALinkedTableTakesAndGivesBackItsCells`, `testALinkBesideAReplacement`, `testListItemsAreNumberedAgain`,
    `testRebuildReasonsNameTheChange`) and WidgetRuntime's `LayerChurnTests` (an appended, removed or inserted list item
    and a child of `<html>` re-create no other layer; a moved item only its own),
    `testAnOrderedListRenumbersInPlace` and randomized oracles.

90. **Structure beside sibling and positional selectors matches the reached siblings again in place**
    (`document.h`/`document.cpp` `backward_positions`, `m_backward_positions`, `scan_positions`, `selector_scope`;
    `telegram_external.cpp` `can_insert_subtree`, `can_remove_subtree`, `note_structure`, `insert_subtree`,
    `remove_subtree`, `commit_patch`). Sibling combinators, `of S` and positional pseudo-classes outside a rule's subject
    (scope bits 1 and 2) no longer refuse an insertion or a removal. Each parent whose children the session changes keeps
    the earliest child index any change took (an insertion's index, a removed child's place before it went; the
    minimum, since a change at index j moves only the children from j on). With bit 1 or 2, `commit_patch` matches again
    the element children of each such parent in the document and outside a subtree the session inserted, from that index,
    and their subtrees: those rules read only preceding siblings (`+`, `~`, `:first-child`, `:first-of-type`,
    `:nth-child`, `:nth-of-type`, their `of S` forms), so a change at index i can change how the children from i on and
    their descendants match, never those before. When a positional pseudo-class that reads following siblings
    (`:last-child`, `:last-of-type`, `:only-child`, `:only-of-type`, `:nth-last-child`, `:nth-last-of-type`) is outside a
    rule's subject compound (`backward_positions`, found by `scan_positions` with the scope), every element child's
    subtree is matched again. One in the subject alone stays edit 42's (the other children, not their subtrees). Each is
    matched as an attribute's reach is: every box recorded before any match (`record_boxes`), `apply_retag` checked, a
    replacement seed where more than paint changed; each element walked once with edit 88's reach, and matched again
    unless the commit's own re-matches (edit 42's, edit 88's) took it (its subtree still walked): one matched earlier in
    the session (an environment change, an attribute patch) is matched again, since the structure may have changed what
    it matches; a subtree the session inserted is styled afresh. With a `:nth-last-child` or `:nth-last-of-type` with an
    `of S` list in the sheets, subject or not (`backward_of_lists`), edit 88's walk starts at the flipped element's first
    sibling, not the one after it: such a rule reads what S matches in the following siblings, their `:empty` included. The other children's render items and layers stay (a parent edit 89 links keeps them), unless a
    match changes their box. A re-match of the commit (this one, edit 42's or edit 88's) that newly restyles an element
    and changes nothing it matches (no rule started or stopped matching, no declaration changed: `rematch_settle` sets
    `m_rematch_changed`) is restyled but not told to the observer (`m_patch_quiet`; a later rematch that changes it, or
    a style replay, takes it out), so the mirror re-captures only what a change reaches; an element with a `::before` or
    `::after` is one when they go back (edit 91).
    WidgetRuntime makes every change of a parent's children insertions and removals (the document has no other structure
    change of children). Pinned by `external_test.cpp`
    (`testStructureUnderPositionalSelectorsMatchesFresh`, `testStructureSessionsUnderPositionalSelectors`: a float
    another item's insertion starts replaces the list, every other session keeps every item's render item;
    `testSiblingReachFollowsTheSelectors`: what is matched again under `li + li` and under `li:last-child b`;
    `testAnUnchangedReachIsNotReported`; `testASessionsEarlierMatchIsMatchedAgainByTheReach`;
    `testAnEmptyFlipReachesEarlierSiblingsThroughOfS`;
    `testStructureBesideEmptyMatchesFresh`, which inserts and removes under its sibling sheets) and WidgetRuntime's
    `testAppendingUnderSiblingSelectorsChurnsNothing`, `testSiblingsKeepTheirRenderItemsUnderSiblingSelectors`,
    `testAnAppendUnderSiblingSelectorsPatches`, `testAnEnvironmentChangeBesideStructureUnderSiblingRules`,
    `testAnEmptyFlipThroughOfSReachesEarlierSiblings` and the randomized oracles' sibling groups (one with the
    environment).
91. **A match that changes nothing keeps its element's `::before` and `::after`** (`document.h` `rematch_state`'s
    `generated_aside` and `generated_reads_var`, `take_back_generated`, `unrelease_pieces`; `document.cpp`
    `rematch_begin`, `rematch_settle`; `telegram_external.cpp`). `rematch_begin` keeps the element's `::before` and
    `::after` (and whether one's style read a `var()`) before `forget_matched_styles` drops them and gives their charges
    back; the match makes new ones. `rematch_settle` puts the old ones back in the new ones' places, so the element is
    matched again in place (`m_rematch_changed` false, no replacement seed), only when the match changes nothing: the
    element was matched checked; its attributes other than `class` are the same; no inline or animated declaration
    changed; no rule started or stopped matching (`::before` and `::after` rules are the element's own used rules); the
    match made the same sides; each side prints as it did (`print_generated`, as `generated_fingerprint`: tags, text,
    `src`, which holds what a rule change cannot show: `counter()` values, `attr()`); each element of an old one is
    matched by the same rules as its counterpart (`used_rules`); and no old one's style read a `var()` (it held what the
    custom properties were). Every side goes back or none; otherwise the element is a seed with the reason
    `pseudo-element children`, as before. This is the style replay's put-back (edit 84) on a re-match: the old ones take
    the new ones' styles, charges and counter values (`html_tag::adopt_matched`, pair by pair over `pair_subtrees`), so
    the restyle computes them as a build's and the style budget holds what a build's would (a match charges only what
    it makes, as before). Every re-match path releases the old ones' pieces before the match (`release_pieces`), so what
    it makes counts within the caps; a put-back releases the new ones (held to the commit) and takes the old ones'
    pieces back (`unrelease_pieces`, the inverse of `release_pieces`'s three counts; the hold keeps its reference).
    Pinned by `external_test.cpp` (`testAnUnchangedPseudoElementKeepsItsIdentity`: an item inserted under `li + li`, the
    later items' `::before` the same elements with the same render items and nothing replaced;
    `testGeneratedContentFollowsItsPrint`: renumbered by a counter, an `attr()` whose attribute changed, a `::before`
    appearing and going, all made again or dropped as a fresh build has them, and one kept under `li:first-child`;
    `testAKeptPseudoElementNeedsNoStyleRoom`: with room for one more `::before` and not two, the insertion replays
    nothing; `testPseudoElementsReadingVar`, which a put-back of a `var()` reader fails) and WidgetRuntime's
    `testAnUnchangedReMatchKeepsPseudoLayers` (the `::before` layers stay).

## The iOS font resolver

`ResolveFont`'s twin keeps the macOS resolution order and generic-family names verbatim: each
comma-separated family in turn; the system names (`-apple-system`, `system-ui`, …) to the system font
with the CSS weight on its `wght` axis (`WithCSSWeight`, the same CoreText calls macOS makes on the
bridged NSFont); `serif` → `Times`, `sans-serif` → `Helvetica`, `monospace` → `Courier`,
`cursive` → `Apple Chancery`, `fantasy` → `Papyrus`, other names as given; the system font when
no family resolves; then italic through the italic trait, else the same 0.2 skew. CSS weight maps to
the `NSFontWeight*` values (UltraLight −0.8 … Black 0.62) and NSFontManager's 2…11 ladder as on
macOS.

- **Family existence.** NSFontManager's `availableMembersOfFontFamily:` becomes
  `CTFontDescriptorCreateMatchingFontDescriptors` with the family name mandatory.
  `CTFontCreateWithName` cannot stand in: it substitutes Helvetica for a name it does not know, so
  `NoSuchFamily, Georgia` would never reach Georgia.
- **Member choice (`FamilyFont`) follows NSFontManager's chain step by step.** macOS asks
  `fontWithFamily:traits:(italic | bold) weight:mw`, then `traits:0 weight:mw`, then
  `traits:0 weight:5`, where `mw` is the NSFontManager weight of the CSS weight.
  1. When the family has a member with the requested italic, the pick is among those: from CSS 600
     (NSBoldFontMask, with which NSFontManager ignores the weight) a face with the bold trait and at
     least Bold's weight (9); else the nearest face weight, a tie going to the face nearer regular. A
     family with no bold face still answers here (Futura 700 italic is MediumItalic).
  2. Otherwise the traits are dropped, bold's preference with them, and the face nearest `mw` is taken
     (an upright one first). So American Typewriter 600 italic, which has no italic face, is its
     Semibold, then skewed. (The twin as `8e86935fcc` wrote it kept the bold preference here and picked Bold.)
  3. Never reached: step 2 always finds a member.

  Face weights are `weightOfFont:`'s scale, read from CoreText's weight trait (UltraLight 2, Thin and
  Light 3, Regular 5, Medium 6, Semibold 8, Bold 9, Heavy 10, Black 11).
- **Italic keeps the weight.** The italic is the italic-trait copy of the face's descriptor, which
  carries the upright's `wght` variation on macOS and on iOS 27. Below iOS 27 the system font's italic
  at text sizes does not (iOS 26.5: `.SFUI-RegularItalic` with no variation below 20 px), so bold
  italic drew at regular weight: at 16 px, the ink of a line in 700 italic equalled 400 italic's (692
  against 692; upright 700 is 1,062). The twin sets the upright's `wght` on the italic again when the
  italic lost it (now 1,058). macOS and iOS 27 are unchanged by this.
- **No public CoreText route to the system designs**, so these take what the macOS functions use
  before 10.15: `ui-monospace`/`sf mono` → Menlo (Menlo-Bold from Semibold up, as that fallback
  does), `ui-serif` → Times New Roman (its face picked by weight, as it has no `wght` axis),
  `ui-rounded`/`sf pro rounded` → the system font.

### Measured against NSFontManager

The twin is CoreText only, so it also runs on macOS, against the same fonts as the NSFont original.
Over **every family installed on macOS 27** (181 families × CSS 100…900 × upright and italic, 3,258
combinations) it picks NSFontManager's face in 3,222. The other 36, in 10 families, come from the
weight scale, not the order: CoreText's weight trait is not what `weightOfFont:` reports.

- Hiragino Sans, 400…800 upright and italic (10): W3 has the trait 0.0 and the weight 4, W5 0.3 and 6,
  W6 0.4 and 8, so the twin picks one face lighter.
- The two lightest faces at 200 (9): Thin on macOS against UltraLight or ExtraLight in the twin for
  Apple SD Gothic Neo, Noto Sans Kannada, Noto Sans Syriac and Noto Serif Myanmar (upright and
  italic), and Helvetica Neue 200 italic (LightItalic on macOS, ThinItalic in the twin; both
  weight 3).
- Bodoni 72 Oldstyle 100…500 (5): all three faces carry the trait 0.0, so Book and Bold tie.
- Google Sans Code and Google Sans Code Proportional, 300 italic (2): Italic against LightItalic.
- Skia (10): its condensed and extended faces, which the twin does not tell from the regular width.

Before the member-choice fix the same run differed in 49 combinations: 14 more, all a 600 italic in a
family without italic faces (American Typewriter, Apple SD Gothic Neo, Damascus, ITF Devanagari and
ITF Devanagari Marathi, Kohinoor Bangla, Devanagari, Gujarati and Telugu, Mukta Mahee, Noto Sans
Kannada, Noto Sans Syriac, Noto Serif Myanmar, Sukhumvit Set: Bold where macOS takes Semibold), and
one fewer: Hiragino Sans 600 italic, which matched only through the old order and now differs like
Hiragino's other weights.

The check made with `8e86935fcc` was narrower: for 11 families picked as installed on both systems (Helvetica,
Helvetica Neue, Avenir, Avenir Next, Gill Sans, Futura, Georgia, Courier, Courier New, Papyrus, and
`NoSuchFamily, Georgia`), the twin in the iOS 27.0 simulator against the NSFont original on macOS 27
agreed on 197 of those 198 combinations, the other being Helvetica Neue 200 italic. None of those 11
is a family with no italic face and a bold one, the shape that shows the order; the fix changes none
of the 198. Family names match case-insensitively on both (`georgia`, `HELVETICA NEUE`,
`avenir next`, `times new roman`: the same faces, the same tie).

On iOS the fix changes 5 of 1,548 combinations (86 families, iOS 26.5; the same 5 of 1,566 on 27.0):
American Typewriter, Apple SD Gothic Neo, Damascus and Noto Sans Syriac 600 italic to the Semibold
macOS picks, and Hiragino Sans 600 italic (above).

`tests/LiteHTMLTests/TelegramFontTests.mm` pins the resolver in the iOS test bundle (below).

### Where iOS resolves differently (the fonts, not the code)

- `serif` (`Times`) is Times New Roman on iOS: CoreText aliases the family. The ascent bump at
  `LHContainer.mm:1179` matches the family names Times, Helvetica and Courier, so serif text is laid
  out without it on iOS: its ascent is shorter by 15% of ascent + descent than on macOS, before the
  two fonts' own metrics differ. Times New Roman also has no ligatures, where macOS's Times has fi.
- `cursive` (`Apple Chancery`) is not installed on iOS: the next family in the list, else the system
  font.
- `ui-monospace`, `ui-serif` and `ui-rounded` (above).
- The system font is `.SFUI` on iOS and `.SFNS` on macOS. Their vertical metrics differ: at 14 px
  the ascent is 13.33 on iOS and 13.54 on macOS, which round to 13 and 14 (the advances of `l` and
  space at 15 px agree).

## Tests

### Host

- `tests/test_container.h`: the branch's `third-party/litehtml/tests/test_container.h` (that fork is
  deleted; see edit 4), unchanged.
- `tests/smoke_test.cpp`: a flex row with `gap` lays out 30 px tall. It compares
  `float(doc->height())`, since `pixel_t == int` is ambiguous at C++17 (`pixel_float_t` converts to
  both `float` and `int`).
- `tests/fork_test.cpp` (`:TwidgetForkTests`): Telegram's fork changes (edits 4, 8, 9 and 10). A float
  holding a wrapped flex row with `gap` keeps its 165 px box (170 px of content); `tabular-nums` reaches
  the `font_description` the container is asked for; non-finite `transform` and `box-shadow` values, and
  finite ones whose pixels are not (`1e38em`), leave no shadow and no transform function, while finite
  ones still parse; and drawing a transform that composes to a non-finite matrix (two `1e20` scales,
  `translate(3e38%)`, `transform-origin: 3e38% 0`) hands the painter's `begin_group` the identity, while a
  finite one arrives as itself. Edit 8: a point between the items of a flex row inside a relative box hits
  the row, and the row has a placement. Edit 9: at 15 px, `line-height` `1.35`, `1.35em` and `20.25px`
  each make a 20.25 px block, each starting where the one above ends. Edit 10: text pieces stop at the
  document's cap through a text node, a whitespace run, `::before` content and patches, the count follows
  what patches and restyles release, a structure patch past the cap is refused, and one under it keeps its
  whole text.

- `tests/external_test.cpp` (`:TwidgetExternalTests`): edits 12, 16, 17, 18 and 20, as listed in their entries.
- `tests/scheme_test.cpp` (`:TwidgetSchemeTests`): edit 13, as listed in its entry.
- `tests/css_nesting_test.cpp` (`:TwidgetCssNestingTests`): edit 14, as listed in its entry.
- `tests/css_lists_test.cpp` (`:TwidgetCssListsTests`): edit 15, as listed in its entry.
- `tests/pseudo_nesting_test.cpp` (`:TwidgetPseudoNestingTests`): edit 19, as listed in its entry.

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/twidget:TwidgetLitehtmlSmokeTests
//third-party/twidget:TwidgetForkTests //third-party/twidget:TwidgetExternalTests //third-party/twidget:TwidgetSchemeTests //third-party/twidget:TwidgetCssNestingTests
//third-party/twidget:TwidgetCssListsTests //third-party/twidget:TwidgetPseudoNestingTests`.

### iOS: `:TwidgetRenderingTests`

twidget's own tests, run in the simulator: `tests/LiteHTMLTests/*.mm` (Objective-C++, against the
`LiteHTML` layer and the icon set) and `tests/DocumentTests/*.swift` (`import LiteHTML`). Run with
`Make.py … test --target //third-party/twidget:TwidgetRenderingTests`.

**176 cases execute on iOS:** 146 of twidget's 150 LiteHTMLTests (4 guarded), the 7
`TelegramFontTests`, the 5 `TelegramPolicyTests`, and 18 of the 20 Swift cases (2 guarded).

Every edit to the copied tests is an insertion, as in the sources: a guard, or an iOS line under the
`#else` of a guard whose `#if TARGET_OS_OSX` branch is twidget's line. The macOS preprocessed output of
every edited `.mm` is identical to its pristine copy's (`__FILE__` and `__LINE__` held fixed, blank
lines ignored).

Added (Telegram-authored):
- `tests/LiteHTMLTests/LHTestShim.h`, force-included into every LiteHTMLTests source (`-include` in
  the BUILD), empty on macOS. On iOS it spells what the tests use from AppKit's NSGeometry:
  `NSRect`, `NSSize`, `NSRectFromCGRect`, `NSSizeFromCGSize`, `NSStringFromRect`,
  `NSStringFromSize`; it declares `-[NSValue rectValue]` and `-sizeValue` without defining them (iOS
  Foundation implements both and reads `@encode(CGRect)` values with them, measured on iOS 26.5 and
  27.0; a category definition would replace Foundation's methods process-wide); and it gives the iOS
  path of the corpus, `LHTestExamplesChatsDirectory`, the test bundle's `Examples/chats`.
- `tests/DocumentTests/NSValueRect.swift`: `NSValue.rectValue` for Swift on iOS.
- `tests/LiteHTMLTests/TelegramFontTests.mm` (iOS only): the font each text run is drawn with is the
  `CTFontRef` the document hands its painter (`lhx::TextStyle::nativeFont`), so no accessor was
  added. `NoSuchFamily, Georgia` is Georgia; `serif` is `TimesNewRomanPSMT`; American Typewriter
  italic (no italic face) is the upright face skewed 0.2, measured on the font's matrix and on the
  drawn glyph's slant; `-apple-system` 700 carries `wght` 700; `-apple-system` 700 italic keeps it
  and draws wider than 400 italic (fails on iOS 26.5 without the italic-weight fix); American
  Typewriter 600 italic is `AmericanTypewriter-Semibold`, 600 upright `-Bold` (fails without the
  member-choice fix). `tabular-nums` gives `1111` and `0000` one width where the system font's
  proportional digits differ, and the run is drawn with a font whose digits share one advance at the
  same size and weight (fails without edit 4.1's `AcquireSharedFont` block).
- `tests/LiteHTMLTests/TelegramPolicyTests.mm` (iOS only): edit 5. A PNG data image decodes at its
  size, as does an `image/svg+xml` data image (also one with remote `<image>` references, which
  draws and fetches nothing); TIFF bytes behind `image/png` and a 5000 x 1 PNG lay out 0 wide; author markup's `@import`, `<link>`, `url()` and `<img src>` to `https:` are removed by the
  sanitizer (one `css-dropped`, one `tag-dropped`, two `url-blocked`) and `refusedRequests` stays 0,
  while the host's `css:` background to `https:` reaches the renderer and is counted (3 times by the
  time the document is laid out and drawn), and a document patched from it starts from that count
  (4 after the patch). All but the PNG and SVG cases fail without edit 5.

No twidget case is guarded for the image policy, and all of them pass under it. Since SVG data images
are allowed, `IconAssetTests.testHostileSVGDataNeverFetchesOrRecurses` renders its SVG payloads on
iOS, `testRenderingIsDeterministic` compares two renders with its SVG image, and the corpus's 82
`image/svg+xml` data images (12 of the 13 chats) are drawn by `DocumentFuzzTests`,
`GroupBoundsTests`, `SubtreeCullingTests` and `TextBatchingTests`.

Guarded out on iOS (`#if TARGET_OS_OSX`, or `#if canImport(TwidgetRenderer)` in Swift):
- `SimpleTextTests.testGlyphAtlasRunsMatchCoreTextRuns`, its `RenderGPU` helper and the
  `<Metal/Metal.h>` import: the Metal glyph atlas (`LHGPURenderer`), which iOS does not use.
- `SimpleTextTests.testTransparentLeadingShadowMatchesVisibleShadowOnGPU` (new at b5878f9): the same `RenderGPU`.
- `PainterTests.mm`'s `ImageProviderTests` class (`testProviderSuppliesImagesForAllowedSchemes` and
  its `tearDown`): the NSImage provider, macOS only (edit 1.2).
- `IconAssetTests.testManifestMatchesTheCompiledTable`: it reads twidget's `icons.json` and its
  1,452 source SVGs, not vendored (above). Upstream checks the generated `twa_icon_data.inc`
  against them, and the `.inc` is vendored verbatim.
- `IconAssetTests`' `tearDown` line `[LHImages setProvider:nil]`, and in
  `testHostileSVGDataNeverFetchesOrRecurses` only the block that installs a provider: there is no
  provider on iOS. The case still runs and renders every hostile payload; its two assertions about
  what the provider was asked hold trivially, because on iOS nothing can be fetched through one.
- `WebKitParityTests.testFontSmoothingDilatesGlyphsUnlessAntialiased`: iOS has no font smoothing.
- `CompositorClipTests`' `@testable import TwidgetRenderer`, its `track` clip and two cases,
  `testCornerFreeBandsHoldTheElement` and `testClipIsInertOnlyAwayFromEdgesAndCorners`: they test
  `WidgetCompositor`, the macOS renderer's compositor in `Sources/TwidgetRenderer`, not vendored. The
  file's other three cases test `LHDocument` and run.

The corpus (`#else` branch, four sites): `DocumentFuzzTests`, `GroupBoundsTests`,
`SubtreeCullingTests` and `TextBatchingTests` read `__FILE__/../../Examples/chats`. A test bundle
has no source tree, so on iOS they read the bundle's copy. Without it `testMutatedDocumentsDoNotCrash`
(more than 3 seeds) and `testCorpusIsByteIdenticalWithExactGroupBounds` (more than 0 files) fail,
and the other two run on their built-in seeds only.

iOS expectations (`#else` branch), each measured, each a difference of the system's fonts:
- `FormControlTests.testTextInputsStretchInGridAndSelectIgnoresAuthorPadding`: the 14 px system-ui
  select is 20.8 tall on iOS and 21.8 on macOS, so iOS expects `22 - 1` with twidget's tolerance
  (±1): the 14 px system font's ascent rounds to 13 on iOS and to 14 on macOS (above).
- `SimpleTextTests.testLigaturesAndNonASCIIStayOnCoreText`: iOS's Times is Times New Roman, which
  has no ligatures, so its "fi", "ffi" and "offi" are simple text and the learned shaper rightly
  takes them (6 hits; the drawn pixels matched CoreText's). On iOS the case uses Palatino, which
  ligates as macOS's Times does (fi, not ffi).
- `WebKitParityTests.testTimesHelveticaCourierGetWebKitAscentAndTheSystemFontIsTheDefault`: 13 px
  `serif` is 16 tall on iOS (Times New Roman: no ascent bump, ascent 11.58, descent 2.81, line gap
  0.55) and 15 on macOS; `sans-serif` and `Courier` are 15 on both.
- `WebKitParityTests.testWordsKeepFractionalPositionsLikeOneShapedRun`: the layout is the same (the
  system font's `l` and space advance 3.5596 and 3.9844 pt on both), but the one step where the
  drawn glyph moves to the next pixel phase measures 15.725 px on iOS and 15.52 on macOS, under
  twidget's 0.3 threshold. iOS uses 0.2; a snapped layout makes every step whole (the other ten are
  exactly 15).

All 170 passed in the iOS 26.5 and 27.0 simulators before the controller's run, from a bundle built
by hand with the BUILD's flags (every vendored source and test compiled for
`arm64-apple-ios15.0-simulator`, loaded by the platform's `xctest` agent): about 100 s, of which
`DamageBandTests` take 40. The first run, before the four iOS expectations, failed exactly those four.
With edits 4 and 5 (2026-10-13), all 176 passed the same way in both simulators (83 s on 26.5, 97 s on
27.0).

## HTMLScript and HTMLSandbox (twidget 80dad8c, identical at b5878f9) — removed 2026-10-15

**Removed 2026-10-15**, when message widgets became sandbox-only: every `tgwidget` source runs in
widget-sandbox's runtime, so twidget's HTML messages, `HTMLScript/`, `HTMLSandbox/`, `tests/HTMLScriptTests/` and
their four targets are gone, with edits H1–H9. `Examples/chats` stays, only as `TwidgetRenderingTests`' fixture (the
app's corpus sender posts widget-sandbox's corpus instead). The record below is what they were, for a re-vendor.


Scripted HTML messages: a script whose `render()` returns HTML. Taken verbatim from `Sources/HTMLSandbox/*`
(`JSThread.swift`, `CpuBudget.swift`) into `HTMLSandbox/` and from `Sources/HTMLScript/*` into `HTMLScript/`
(`HTMLScript`, `HTMLScriptClock`, `HTMLScriptEngine`, `HTMLScriptPrelude`, `HTMLScriptRuntime`, `IntlBridge`,
`QuickJS`, `QuickJSScriptRuntime`), except `JSCScriptRuntime.swift` (the JavaScriptCore runtime; QuickJS is the
one used here). Targets `:HTMLSandbox`, `:HTMLScript` (depends on `//third-party/quickjs-ng:CQuickJS`) and
`:HTMLScriptTests` (`tests/HTMLScriptTests/`). Vendored Swift is not built with `-warnings-as-errors`.

These files landed with H1-H7 already applied (`diff -r` against `~/build/twidget/Sources` at 80dad8c shows
them; the two directories are identical at b5878f9). H8 came later (2026-10-14).

Local edits:

- **H1 iOS clock.** `HTMLScriptClock.swift`: the CVDisplayLink class is under `#if os(macOS)`; the iOS class
  (`#else`) is a `CADisplayLink` added to the engine thread's run loop, with the same members the engine uses
  (`init(deliver:tick:)`, `interval`, `isRunning`, `start()`, `stop()`).
- **H1b Clock start off the call.** `HTMLScriptEngine.requestFrame(for:)` subscribes at once but no longer
  creates the display link inline (that runs inside the script's host call, where a slow creation is charged to
  its 50 ms call and CPU budget, and blocks main when the boot is in `performAndWait`): it queues the start on
  the engine's thread, guarded against a double start, the manual clock and an emptied subscriber set. No unit
  test: the hostless runner cannot create a link cheaply; checked on the simulator with the app.
- **H2 No display id on iOS.** `HTMLScriptEngine.swift` builds the clock with `display:` only on macOS;
  `setDisplay(_:)` there and `HTMLScript.setDisplay(_:)` are macOS only. New `deliverFrameForTesting()`
  runs one tick on the engine's thread (tests: a hostless process has no display link), and
  `useManualClockForTesting()` stops the engine from ever starting its clock (`HTMLScriptTests.setUp` calls it):
  in a hostless xctest process creating a `CADisplayLink` blocks about 5 s, which a script that calls
  `requestAnimationFrame` during boot is charged for (its CPU budget then defers every frame).
- **H3 Pasteboard.** `HTMLScript.swift` imports UIKit instead of AppKit on iOS; `copyText` writes
  `UIPasteboard.general` on the main queue, under the same only-while-handling-an-action guard.
- **H4 Stack.** `JSThread.jsStackLimit = 2 << 20` (was `6 << 20`); `stackSize` stays `8 << 20`.
- **H5 Host-call deadline.** `QuickJS.swift`: `admitsHostCall()`, `throwInterrupted()` and `fallbackLimit`
  (0.5 s, the value of the renderer's `SandboxConfig.defaultCpuLimitMs`, which is not vendored here) are
  ported from `MessageWidget`'s `QuickJSContext.swift`, and `hostTrampoline` refuses a call past the deadline
  before converting its arguments, so a loop of host calls stops at the deadline even inside `try`/`catch`.
- **H6 Heap.** `QuickJSScriptRuntime.init(memoryLimitBytes: Int = 64 << 20)` (was 128 MB).
- **H7 No HTML3D helpers.** `QuickJSArgument`, `registerArgumentFunction`, `argumentTrampoline` and their
  storage are deleted from `QuickJS.swift`: they call `qjs_typed_array_bytes`, which `CQuickJS` does not
  have, and only HTML3D (not taken) uses them.
- **H8 Linear extraction.** `HTMLScript.swift`: `make(html:)` took the scripts, the `app:` libraries and the
  static HTML, and `init` the static HTML's styles, with four patterns over the whole message:
  - `<script\b[^>]*>([\s\S]*?)</script\s*>` (the scripts, and the blocks `stripScripts` removes);
  - `<script\b[^>]*\bsrc\s*=\s*["']app:([a-zA-Z0-9-]+)["'][^>]*>` (the libraries);
  - `</?script\b[^>]*>` (the stray tags `stripScripts` removes);
  - `<style\b[^>]*>[\s\S]*?</style\s*>` (`styleBlocks`).

  Each is quadratic where its matches fail, as every later start scans to the end again: a tag with no `>`
  after it, a body with no closing tag, many `<script` sharing one `>`. `make` runs on the main thread in a
  bubble's layout pass (`MessageWidgetInstance`), on any received message. Measured on the Mac at -O, for
  `<script>function render(){return ''}</script>` followed by N × `<script a` (unclosed), the whole `make` took
  0.32 s at 9 KB, 1.24 s at 18 KB and 4.93 s at 37 KB. Per pattern over 29-37 KB of its shape: 0.87 s (blocks),
  2.32 s (libraries, unclosed tags), 1.98 s (libraries, 4,096 `<script` sharing one `>`), 0.77 s (stray tags)
  and 1.00 s (styles).

  The patterns are replaced by one-pass scans that find the same matches:
  - `elements(_:open:close:)` for scripts and styles: a tag ends at the first `>` after its name, a body at the
    first closing tag after that, and the scan stops where either is missing, as no later start can have it.
  - `libraries(_:)`: a script tag's last `src="app:…"`, which is what the greedy `[^>]*` found by backtracking
    from the tag's end. A tag without one is skipped whole.
  - `stripScripts(_:blocks:)`: the same scan for stray tags.

  `make` goes through the new internal `extract(_:)` (an `Extraction`: source, libraries, untrimmed static HTML),
  and `styleBlocks(_:)` is internal, for the tests. The same four shapes now take under 1 ms each.
  `HTMLScriptTests.testExtractionIsUpstreams` holds `extract` and `styleBlocks` to upstream's patterns, which the
  test keeps as its reference: a multi-script message with literal expectations, edge cases, and 5,000 tag-soup
  strings from a fixed seed. `testHostileMarkupIsExtractedInLinearTime` bounds `make` and the boot under 0.2 s on
  each shape at 28-37 KB.

  Checked here, beyond the tests: a 600,000-case differential fuzz on the Mac found no difference, and neither did
  the 73 scripted bodies of `Examples/chats`.

- **H9 A budget of work, not of time** (2026-10-15).
  A call is stopped by the work it does, never by elapsed time, and there is no rate limit:
  - `WorkBudget.swift` (new, `HTMLScript/`): one call's budget, summing what QuickJS counts (quickjs-ng local
    edit 2) and the host calls' bytes.
  - `QuickJS.swift`: `deadline` becomes `budget: WorkBudget?` with `settle()`, `stopped` and
    `chargeHostWork(bytes:)`; the interrupt handler and `admitsHostCall()` settle the budget instead of reading
    the clock (H5's refusal inside `try`/`catch` stands); the trampoline charges a call's argument bytes before it
    runs and settles after; `fallbackLimit` becomes `fallbackBudget`.
  - `HTMLScriptRuntime.swift`: `makeContext(name:callWork:)`, `evaluate(_:name:work:)`, `install(in:work:)`,
    `HTMLScriptError.Kind.workLimit` (was `timeLimit`).
  - `QuickJSScriptRuntime.swift`: `perform(work:)` gives each call a fresh `WorkBudget`.
  - `HTMLScriptEngine.swift`: `callWork` (units) replaces `callLimit` (50 ms), `libraryWork` (unlimited) replaces
    `libraryLimit`; the per-call footprint sampling is gone.
  - `HTMLScript.swift`: the `CpuBudget` (200 ms per 1 s, deferral of timers and frames) is gone; the stop reason
    reads "a call did more than N units of work"; the out-of-memory stop is QuickJS's own heap limit only — the
    process-footprint check (sampled after a call slower than 2 ms) made the verdict depend on time and on the rest
    of the process.
  - `HTMLSandbox/CpuBudget.swift` is deleted (HTMLScript was its only user).
  - Calibration (2026-10-15, Task 6): a native call charges `QuickJSContext.hostCallUnits` (250) before its argument
    bytes — the crossing encodes and decodes JSON both ways, and a loop of `update()` at 1 unit per call ran 12× the
    reference loop's wall time per unit (`testANativeCallLoopCostsNoMorePerUnitThanJS` holds it under 2×; 1.0–1.1×
    measured). `callWork` is 5,000,000 (~50 ms at the reference rate); the corpus's heaviest call is 13-3d-lab#2's boot,
    580,889 units.
  - `HTMLScriptContext.lastCallWork` (`QuickJSScriptContext` records each call's spent budget) and
    `HTMLScript.largestCallWorkForTesting` (the largest budgeted call since boot, for the corpus table); library
    installs run as `call("library")` and are left out of it.
  - DEBUG: `workTripwire` (in `WorkBudget.swift`) logs a call whose wall time per unit is past 4× this build's own rate
    on the reference loop (`workReferenceUnitsPerMillisecond`, measured once per process), and `WorkWatchdog` logs a
    call still running at 4× what its budget is worth; neither stops anything.
  - Final review (2026-10-15): `HTMLRebuildCost.swift` (new) is what building a document costs — its bytes at 1 per 4
    plus 100 per tag, word and whitespace character, since litehtml makes an element of each.
    `QuickJSScriptContext.invoke` charges a `callRender` result's build inside that call: the host builds it later,
    outside any call, and it had not been charged at all. MessageWidget charges its sandbox rebuilds the same way.
  - The boot and the later calls have budgets of their own (the user, 2026-10-15): `HTMLScriptEngine.bootWork`
    (5,000,000) is shared by the prelude, the message's script and its first render through
    `HTMLScriptContext.beginSharedBudget`/`endSharedBudget` (a library's install keeps its unlimited one); each later
    call has `callWork` (5,000,000). The stop reason says which ("its boot did more than …" / "a call did more than
    …"); `bootWorkForTesting` and `largestCallWorkForTesting` report them.
