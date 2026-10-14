# Message Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render a `tgwidget` code block in a rich message as a live HTML widget inside the bubble. The widget's JS (QuickJS) and its layout (litehtml) run synchronously on the main thread, and it is drawn as a native layer tree.

**Architecture:**
- **JavaScript.** Widget JS runs in QuickJS against widget-sandbox's DOM shim. Every mutation passes widget-sandbox's validator, which runs in a second QuickJS runtime.
- **Layout.** The validated ops drive a C++ core, derived from widget-sandbox's renderer-litehtml, which lays the document out with a forked litehtml.
- **Drawing.** Each element with a node id becomes one `CALayer`. The layer draws its own backgrounds, borders and text with the core's CoreGraphics painter; opacity, transform, shadow and clipping are layer properties.
- **Hosting.** InstantPage V2 lays the block out through a host protocol. `ChatMessageRichDataBubbleContentNode` implements that protocol with a registry whose runtimes live as long as the bubble.

**Tech Stack:** quickjs-ng 0.17.0 (C), litehtml `4a651c52` with gumbo (C++20), CoreGraphics/CoreText/ImageIO, Swift + UIKit, Bazel (`cc_library`, `objc_library`, `swift_library`, `cc_test`, `ios_unit_test`).

**Spec:** `docs/superpowers/specs/2026-10-13-message-widgets-design.md`, as amended in the same commit as this plan (see "Deviations from the spec").

**Source repo for vendored and ported code:** `~/build/widget-sandbox` at commit `862eec8`. Its `node_modules` are installed, so the Node harness `./node_modules/.bin/tsx packages/core/scripts/sandbox-node.ts` runs from that directory.

## Global Constraints

- iOS 15.0 and later; iOS only. Every new `ios_unit_test` uses `minimum_os_version = "15.0"` and an `ios_test_runner` pinned to `device_type = "iPhone 17"`, `os_version = "26.5"`.
- The language name is exactly `tgwidget`, compared after `normalizedCodeBlockLanguage` (trim + lowercase).
- Widgets render only in rich messages (`RichTextMessageAttribute`). Plain messages are untouched.
- The widget's JS runs and its layout is computed synchronously in the layout pass, through `MessageWidgetExecutor`: inline on the main thread, or on a dedicated 8 MB thread while the main thread waits.
- QuickJS stack limit: `MessageWidgetExecutor.jsStackLimit = 2 << 20` (2 MB) for both runtimes.
- Engine limits as in widget-sandbox:
  - memory 64 MB;
  - `cpuLimitMs` 500;
  - CPU quota 300 ms per 1000 ms;
  - 256 timers;
  - the validator's heap is 256 MB.
- Widget height is clamped to `24...900` pt; CSS px == points.
- No network, ever: the litehtml container accepts only `data:` images (PNG/JPEG/GIF/WebP) and refuses everything else.
- Gate: `ExperimentalUISettings.messageWidgets == true` and no app config key `ios_killswitch_disable_message_widgets`. When it is closed, the block draws as the code block it is today.
- `sendMessage` sends immediately as the user via `controllerInteraction.sendMessage(text, messageId)`, but only during a task started by a real tap, at most once per tap, and capped at `UserLimitsConfiguration.maxMessageLength`.
- Third-party code goes in `third-party/` (vendored copies, edited in place). Our code goes in `submodules/TelegramUI/Components/MessageWidget/`.
- Warnings are errors for every new `swift_library` (`copts = ["-warnings-as-errors"]`). Vendored C/C++ builds with `-w`.
- New Swift classes are `final`. A new non-final method crashes dependents that weren't rebuilt (stale vtable).
- **Bazel builds and tests are run by the controller (the main session), never by a subagent.** A subagent writes code and reports. The controller runs the commands in each task's test steps.
- Never install the app on a simulator or device; the user installs and verifies.
- Commands:
  - Host C++ tests: `./build-input/bazel-9.2.0-darwin-arm64 test <label> --test_output=errors`
  - iOS unit tests: `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache test --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --target <label>`
  - Full app build: `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --continueOnError --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64`
  - Read a build's own exit code. A background task's exit code is only the last command's status.

## Deviations from the spec

These are amended into the spec in the same commit as this plan:

1. **Drawing (spec §3).** Each node layer draws its own commands through the core's existing CoreGraphics painter (`mwc_draw_node`). The spec described separate background, gradient and border sublayers. Opacity, transform, shadow, clipping and z-order remain layer properties.
2. **Node identity (spec §3).** One node per element with a node id, framed by the element's border box. The spec keyed nodes by (node id, fragment index). An inline element that wraps across lines draws all of its fragments in one layer.
3. **Module boundary (spec §1, §4).** InstantPageUI does not depend on `MessageWidget`. It declares `InstantPageV2WidgetHost`, and the rich bubble node supplies an adapter over `MessageWidgetRegistry`. The registry lives in `MessageWidget`, so it is unit-testable; that existing test target can't link `AccountContext` from the node module.
4. **Paint properties (spec §3).** The litehtml fork only stores `opacity`, `transform` and `box-shadow` as raw token lists. The core parses them.
5. **Visibility (spec §4).** Driven per bubble, from the node's `visibility`, not per item view.
6. **A refused `sendMessage` (spec §5)** is dropped with a diagnostic. The vendored shim's bridge call has no return value to make `false`.
7. **An edited widget (spec §4)** is destroyed at the end of the layout pass that stops using it. Its view keeps its last drawn frame, so the outgoing page view still shows it during the crossfade.
8. **Test fixtures.** Byte-identical copies of examples 01–05 and 10 are committed under `submodules/TelegramUI/Components/MessageWidget/Fixtures/` as test inputs. The docs examples stay uncommitted.
9. **Attribution (spec §3).** The spec walked the render tree by hand. Instead, the fork passes the render item as `hdc` at litehtml's 8 element-draw call sites, and litehtml's own `document::draw` pass records the commands. That keeps litehtml's paint order, positioning and table-cell handling. Grepping `src/` confirms every drawing callback is reached only through those sites.

## Review Focus

Each line pins a test to its task:

1. **Empty `tgwidget` block.** Expected: it draws as an ordinary code block; no runtime is created. Tests: `testEmptyWidgetBlockLaysOutAsCode` (Task 13) and `testEmptySourceGetsNoWidget` (Task 11).
2. **Boot script throws before any DOM exists.** Expected: the bubble gets a 24 pt widget, `lastError` holds the error, and nothing crashes. Test: `testBootErrorKeepsMinimumHeight` (Task 9).
3. **Two widget blocks in one message.** Expected: two independent runtimes, keyed by path. A tap in one never reaches the other. Tests: `testTwoPathsGetTwoInstances` (Task 11) and `testTwoWidgetBlocksGetDistinctPaths` (Task 13).
4. **The message is edited while a crossfade is in flight.** Expected: the outgoing view keeps its last frame and nothing draws from a destroyed runtime. Test: `testDestroyedInstanceViewStillDraws` (Task 10).
5. **The gate closes between measure and apply.** Expected: an item view whose host returns no view is empty, and nothing crashes. Tests: `testDestroyAllDropsViews` (Task 11) and `testWidgetViewToleratesMissingHostView` (Task 13).

---

## File structure

```
third-party/quickjs-ng/                  vendored quickjs-ng 0.17.0 + qjs_shim (Task 1)
  BUILD, VENDOR.md, LICENSE
  include/{quickjs.h,qjs_shim.h}
  quickjs/*.c *.h, shim/qjs_shim.c
  tests/quickjs_smoke_test.c
third-party/litehtml/                    vendored litehtml 4a651c52 + gumbo, our fork (Tasks 2–4)
  BUILD, VENDOR.md, LICENSE, VERSION
  include/**, src/**
  tests/{test_container.h,smoke_test.cpp,flex_gap_test.cpp,fork_properties_test.cpp}
third-party/widget-sandbox/              built artifacts only (Task 7)
  BUILD, VENDOR.md
  WidgetJS/{sandbox-bundle.js,.qbc,validator-bundle.js,.qbc,libraries.json}
  WidgetJS/libs/{chart.umd.js,.qbc,d3.min.js,.qbc}
  corpus/attacks/*                       test fixtures only, never in the app
submodules/TelegramUI/Components/MessageWidget/
  Fixtures/                              BUILD + 01..05, 10 html + *.ops.json (Task 5)
  MessageWidgetCore/                     C++ core + C API (Tasks 5–6)
    BUILD, PROVENANCE.md
    PublicHeaders/MessageWidgetCore/MessageWidgetCore.h
    Sources/{renderer.h,renderer.cpp,backend.h,display_list.h,layout_nodes.h,layout_nodes.cpp,paint_properties.h,paint_properties.cpp,mwc.cpp}
    Sources/apple/{coregraphics.h,coregraphics.cpp}
    Sources/twidget/json.h
    Tests/{core_tests.cpp,layout_tests.cpp}
  MessageWidget/                         Swift module (Tasks 7–11)
    BUILD, PROVENANCE.md
    Sources/{JSThread,QuickJSContext,MessageWidgetExecutor,MessageWidgetResources,CpuBudget,TrustedValidator,
             IntlBridge,MessageWidgetEngine,WidgetCore,MessageWidgetInstance,MessageWidgetView,MessageWidgetRegistry}.swift
    Tests/{ExecutorAndValidatorTests,EngineTests,InstanceTests,ViewTests,RegistryTests,TestSupport}.swift
```

Modified: `submodules/InstantPageUI/{BUILD?,Sources/InstantPageV2Layout.swift,Sources/InstantPageRenderer.swift}`, new `submodules/InstantPageUI/Sources/InstantPageV2Widget.swift`, `submodules/TextFormat/Sources/InstantPageSyntaxHighlightSpecs.swift`, `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/{BUILD,Sources/*}`, `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift`, `submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift`, `submodules/DebugSettingsUI/Sources/DebugController.swift`, `Telegram/Telegram-iOS/en.lproj/Localizable.strings`, `Telegram/BUILD`, `Telegram/Telegram-iOS/main.m` (launch log, Task 12), `CLAUDE.md`.

---

### Task 1: Vendor quickjs-ng

**Files:**
- Create: `third-party/quickjs-ng/{BUILD,VENDOR.md,LICENSE}`, `third-party/quickjs-ng/include/`, `third-party/quickjs-ng/quickjs/`, `third-party/quickjs-ng/shim/`
- Test: `third-party/quickjs-ng/tests/quickjs_smoke_test.c`

**Interfaces:**
- Produces: `//third-party/quickjs-ng:quickjs` (`cc_library`, headers `quickjs.h`, `qjs_shim.h` via `includes = ["include"]`); `//third-party/quickjs-ng:CQuickJS` (`objc_library`, `module_name = "CQuickJS"`, importable from Swift as `import CQuickJS`).

- [ ] **Step 1: Copy the sources**

```bash
S=~/build/widget-sandbox/packages/ios/Sources/CQuickJS
D=third-party/quickjs-ng
mkdir -p $D/include $D/quickjs $D/shim $D/tests
cp $S/include/quickjs.h $S/include/qjs_shim.h $D/include/
cp $S/quickjs/*.c $S/quickjs/*.h $D/quickjs/
cp $S/quickjs/LICENSE $D/LICENSE
cp $S/shim/qjs_shim.c $D/shim/
```

Do not copy `module.modulemap`; Bazel generates the module.

- [ ] **Step 2: Write `third-party/quickjs-ng/VENDOR.md`**

```markdown
# quickjs-ng (vendored)

quickjs-ng v0.17.0 plus a 40-line C shim (`shim/qjs_shim.c`, `include/qjs_shim.h`) that hides
`JSValue` macros from Swift. Copied from widget-sandbox `packages/ios/Sources/CQuickJS` at
commit 862eec8; the four `.c` files are upstream, unmodified.

Built `-O2` in every configuration, debug included: message widgets run QuickJS with a 2 MB stack
limit, and a debug quickjs-ng spends ~10 KB of C stack per JS call (css-tree in the validator
recurses deeply). The widget-sandbox bytecode (`third-party/widget-sandbox/WidgetJS/*.qbc`) is
built by this exact version: upgrading quickjs-ng means re-vendoring those `.qbc` files from a
widget-sandbox build of the same version, or every bundle falls back to source.
```

- [ ] **Step 3: Write the failing smoke test `third-party/quickjs-ng/tests/quickjs_smoke_test.c`**

```c
// Host smoke test for the vendored quickjs-ng + qjs_shim: evaluation, exceptions,
// bytecode round trip, and that the stack limit turns deep recursion into a catchable
// RangeError instead of a crash.
#include "quickjs.h"
#include "qjs_shim.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)

static JSValue eval(JSContext *ctx, const char *code) {
    return qjs_eval(ctx, code, strlen(code), "t.js", false);
}

int main(void) {
    JSRuntime *rt = JS_NewRuntime();
    JS_SetMaxStackSize(rt, 2 << 20);
    JSContext *ctx = JS_NewContext(rt);

    JSValue v = eval(ctx, "1 + 2");
    CHECK(qjs_is_number(v) && qjs_to_float64(ctx, v) == 3.0);
    qjs_free_value(ctx, v);

    v = eval(ctx, "throw new TypeError('boom')");
    CHECK(qjs_is_exception(v));
    char *desc = qjs_take_exception_description(ctx);
    CHECK(desc && strstr(desc, "boom"));
    free(desc);

    const char *src = "globalThis.answer = 6 * 7;";
    size_t len = 0;
    uint8_t *blob = qjs_compile_bytecode(ctx, src, strlen(src), "b.js", &len);
    CHECK(blob && len > 0);
    JSValue r = qjs_eval_bytecode(ctx, blob, len, src, strlen(src));
    CHECK(!qjs_is_exception(r));
    qjs_free_value(ctx, r);
    qjs_free_bytecode(ctx, blob);
    v = eval(ctx, "answer");
    CHECK(qjs_is_number(v) && qjs_to_float64(ctx, v) == 42.0);
    qjs_free_value(ctx, v);

    v = eval(ctx, "function f(n) { return f(n + 1) + 1; } f(0)");
    CHECK(qjs_is_exception(v));
    desc = qjs_take_exception_description(ctx);
    CHECK(desc && strstr(desc, "RangeError"));
    free(desc);

    JS_FreeContext(ctx);
    JS_FreeRuntime(rt);
    if (failures) { printf("%d failure(s)\n", failures); return 1; }
    printf("quickjs smoke: OK\n");
    return 0;
}
```

- [ ] **Step 4: Write `third-party/quickjs-ng/BUILD`**

```python
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

quickjs_copts = [
    "-O2",
    "-w",
    "-D_GNU_SOURCE",
    "-DQUICKJS_NG_BUILD",
    "-Ithird-party/quickjs-ng/include",
    "-Ithird-party/quickjs-ng/quickjs",
]

cc_library(
    name = "quickjs",
    srcs = [
        "quickjs/quickjs.c",
        "quickjs/dtoa.c",
        "quickjs/libregexp.c",
        "quickjs/libunicode.c",
        "shim/qjs_shim.c",
    ] + glob(["quickjs/*.h"]),
    hdrs = [
        "include/quickjs.h",
        "include/qjs_shim.h",
    ],
    includes = ["include"],
    copts = quickjs_copts,
    visibility = ["//visibility:public"],
)

objc_library(
    name = "CQuickJS",
    module_name = "CQuickJS",
    enable_modules = True,
    hdrs = [
        "include/quickjs.h",
        "include/qjs_shim.h",
    ],
    includes = ["include"],
    deps = [":quickjs"],
    visibility = ["//visibility:public"],
)

cc_test(
    name = "QuickJSSmokeTests",
    srcs = ["tests/quickjs_smoke_test.c"],
    copts = quickjs_copts,
    deps = [":quickjs"],
)
```

- [ ] **Step 5: Run the test**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/quickjs-ng:QuickJSSmokeTests --test_output=errors`
Expected: PASS (`quickjs smoke: OK`). If a header is missing, `ls ~/build/widget-sandbox/packages/ios/Sources/CQuickJS/quickjs` and copy it into `quickjs/`.

- [ ] **Step 6: Commit**

```bash
git add third-party/quickjs-ng
git commit -m "third-party: vendor quickjs-ng 0.17.0 with the qjs_shim for message widgets"
```

---

### Task 2: Vendor litehtml

**Files:**
- Create: `third-party/litehtml/{BUILD,VENDOR.md}`, plus `include/`, `src/`, `LICENSE` and `VERSION` copied from upstream
- Test: `third-party/litehtml/tests/test_container.h`, `third-party/litehtml/tests/smoke_test.cpp`

**Interfaces:**
- Produces: `//third-party/litehtml:litehtml` (`cc_library`, C++20, `#include <litehtml.h>`, `#include <litehtml/render_item.h>`); `//third-party/litehtml:gumbo` (C); and `third-party/litehtml/tests/test_container.h`, which defines `litehtml_test::TestContainer`, a `document_container` with deterministic metrics: every glyph is 8 px wide, ascent 12, descent 4, and it records every drawing callback with its `hdc`. Tasks 3 and 4 use it.

- [ ] **Step 1: Copy the sources**

```bash
S=~/build/widget-sandbox/apps/renderer-litehtml/third_party/litehtml
D=third-party/litehtml
mkdir -p $D/tests
cp -R $S/include $S/src $D/
cp $S/LICENSE $S/VERSION $D/
rm -rf $D/src/gumbo/visualc
```

- [ ] **Step 2: Write `third-party/litehtml/VENDOR.md`**

```markdown
# litehtml (vendored, forked)

litehtml master 4a651c52 (2026-10-04, see VERSION) with its bundled gumbo, taken from
widget-sandbox `apps/renderer-litehtml/third_party/litehtml` at commit 862eec8 (upstream,
unmodified at that point; `src/gumbo/visualc` dropped). BSD-3-Clause (litehtml), Apache-2.0 (gumbo).

This copy is a FORK, edited in place for message widgets. Every change is listed here:

(none yet)
```

- [ ] **Step 3: Write `third-party/litehtml/tests/test_container.h`**

```cpp
// A deterministic document_container for host tests of the vendored litehtml: every glyph is
// 8 px wide, fonts have ascent 12 / descent 4, images are refused, and every drawing callback is
// recorded with the `hdc` it arrived with (the fork's per-element token, see VENDOR.md).
#pragma once

#include <litehtml.h>

#include <cstdio>
#include <string>
#include <vector>

namespace litehtml_test {

struct DrawCall {
    std::string kind;
    litehtml::uint_ptr hdc = 0;
};

class TestContainer : public litehtml::document_container {
public:
    std::vector<DrawCall> calls;
    std::vector<litehtml::font_description> fonts;
    int width = 300;

    litehtml::uint_ptr create_font(const litehtml::font_description& descr, const litehtml::document*, litehtml::font_metrics* fm) override {
        fonts.push_back(descr);
        if (fm) {
            fm->font_size = descr.size;
            fm->ascent = 12;
            fm->descent = 4;
            fm->height = 16;
            fm->x_height = 6;
            fm->ch_width = 8;
            fm->draw_spaces = false;
            fm->sub_shift = 2;
            fm->super_shift = 4;
        }
        return litehtml::uint_ptr(fonts.size());
    }
    void delete_font(litehtml::uint_ptr) override {}
    litehtml::pixel_t text_width(const char* text, litehtml::uint_ptr) override {
        return litehtml::pixel_t(float(8 * std::string(text).size()));
    }
    void draw_text(litehtml::uint_ptr hdc, const char*, litehtml::uint_ptr, litehtml::web_color, const litehtml::position&) override { calls.push_back({"text", hdc}); }
    litehtml::pixel_t pt_to_px(float pt) const override { return litehtml::pixel_t(pt * 96.0f / 72.0f); }
    litehtml::pixel_t get_default_font_size() const override { return 16; }
    const char* get_default_font_name() const override { return "sans-serif"; }
    void draw_list_marker(litehtml::uint_ptr hdc, const litehtml::list_marker&) override { calls.push_back({"marker", hdc}); }
    void load_image(const char*, const char*, bool) override {}
    void get_image_size(const char*, const char*, litehtml::size& sz) override { sz.width = 0; sz.height = 0; }
    void draw_image(litehtml::uint_ptr hdc, const litehtml::background_layer&, const std::string&, const std::string&) override { calls.push_back({"image", hdc}); }
    void draw_solid_fill(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::web_color&) override { calls.push_back({"fill", hdc}); }
    void draw_linear_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::linear_gradient&) override { calls.push_back({"linear", hdc}); }
    void draw_radial_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::radial_gradient&) override { calls.push_back({"radial", hdc}); }
    void draw_conic_gradient(litehtml::uint_ptr hdc, const litehtml::background_layer&, const litehtml::background_layer::conic_gradient&) override { calls.push_back({"conic", hdc}); }
    void draw_borders(litehtml::uint_ptr hdc, const litehtml::borders&, const litehtml::position&, bool) override { calls.push_back({"borders", hdc}); }
    void set_caption(const char*) override {}
    void set_base_url(const char*) override {}
    void link(const std::shared_ptr<litehtml::document>&, const litehtml::element::ptr&) override {}
    void on_anchor_click(const char*, const litehtml::element::ptr&) override {}
    void on_mouse_event(const litehtml::element::ptr&, litehtml::mouse_event) override {}
    void set_cursor(const char*) override {}
    void transform_text(std::string&, litehtml::text_transform) override {}
    void import_css(std::string& text, const std::string&, std::string&) override { text.clear(); }
    void set_clip(const litehtml::position&, const litehtml::border_radiuses&) override {}
    void del_clip() override {}
    void get_viewport(litehtml::position& v) const override { v.x = 0; v.y = 0; v.width = litehtml::pixel_t(float(width)); v.height = 600; }
    litehtml::element::ptr create_element(const char*, const litehtml::string_map&, const std::shared_ptr<litehtml::document>&) override { return nullptr; }
    void get_media_features(litehtml::media_features& m) const override {
        m.type = litehtml::media_type_screen;
        m.width = litehtml::pixel_t(float(width));
        m.height = 600;
        m.device_width = m.width;
        m.device_height = m.height;
        m.color = 8;
        m.color_index = 256;
        m.monochrome = 0;
        m.resolution = 96;
    }
    void get_language(std::string& language, std::string& culture) const override { language = "en"; culture.clear(); }
};

/// Parses and lays `html` out at `width`; the container is reused so callers can inspect it.
inline litehtml::document::ptr layout(TestContainer& c, const std::string& html, int width = 300) {
    c.width = width;
    auto doc = litehtml::document::createFromString(litehtml::estring(html), &c);
    doc->render(litehtml::pixel_t(float(width)));
    return doc;
}

} // namespace litehtml_test

#define CHECK(c) do { if (!(c)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)
```

If a `document_container` virtual's signature differs from the above, the compiler names it. Match the vendored header (`include/litehtml/document_container.h`), not this listing.

- [ ] **Step 4: Write the smoke test `third-party/litehtml/tests/smoke_test.cpp`**

```cpp
#include "test_container.h"

#include <cstdio>

static int failures = 0;

int main() {
    litehtml_test::TestContainer c;
    auto doc = litehtml_test::layout(c, "<html><body style='margin:0'><div style='height:100px;background:red'>hi</div></body></html>");
    CHECK(doc != nullptr);
    CHECK(int(float(doc->height())) == 100);
    litehtml::position clip(0, 0, 300, 600);
    doc->draw(0, 0, 0, &clip);
    bool sawFill = false, sawText = false;
    for (auto& call : c.calls) {
        sawFill |= call.kind == "fill";
        sawText |= call.kind == "text";
    }
    CHECK(sawFill);
    CHECK(sawText);
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("litehtml smoke: OK\n");
    return 0;
}
```

- [ ] **Step 5: Write `third-party/litehtml/BUILD`**

```python
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

cc_library(
    name = "gumbo",
    srcs = glob(["src/gumbo/*.c"]) + glob(["src/gumbo/include/gumbo/*.h"]),
    hdrs = ["src/gumbo/include/gumbo.h"],
    includes = ["src/gumbo/include"],
    copts = [
        "-w",
        "-Ithird-party/litehtml/src/gumbo/include/gumbo",
    ],
    visibility = ["//visibility:private"],
)

litehtml_copts = [
    "-std=c++20",
    "-w",
    "-Ithird-party/litehtml/include/litehtml",
    "-Ithird-party/litehtml/src/gumbo/include",
]

cc_library(
    name = "litehtml",
    srcs = glob(["src/*.cpp"]),
    hdrs = glob(["include/**/*.h"]),
    includes = ["include"],
    copts = litehtml_copts,
    deps = [":gumbo"],
    visibility = ["//visibility:public"],
)

test_copts = [
    "-std=c++20",
    "-w",
    "-Ithird-party/litehtml/tests",
]

cc_test(
    name = "LitehtmlSmokeTests",
    srcs = ["tests/smoke_test.cpp", "tests/test_container.h"],
    copts = test_copts,
    deps = [":litehtml"],
)
```

- [ ] **Step 6: Run the test**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/litehtml:LitehtmlSmokeTests --test_output=errors`
Expected: PASS. Two kinds of failure are not code bugs:
- An unresolved include: add the include path that litehtml's own `CMakeLists.txt` uses (`target_include_directories`) to `litehtml_copts`.
- A missing source file: compare `srcs` with the list in that `CMakeLists.txt`.

- [ ] **Step 7: Commit**

```bash
git add third-party/litehtml
git commit -m "third-party: vendor litehtml 4a651c52 with gumbo for message widgets"
```

---

### Task 3: litehtml fork — flex `gap`, `row-gap`, `column-gap`

litehtml drops `gap` at parse time. Examples 02–05 use it and it changes layout, so it has to be implemented in the fork.

**Files:**
- Modify:
  - `third-party/litehtml/include/litehtml/string_id.h` (the `STRING_ID(` list, next to `_flex_basis_`)
  - `third-party/litehtml/include/litehtml/css_values.h` (next to `flex_basis_strings`)
  - `third-party/litehtml/src/style.cpp` (`style::add_property`, next to `case _flex_basis_:`)
  - `third-party/litehtml/include/litehtml/css_properties.h`
  - `third-party/litehtml/src/css_properties.cpp`
  - `third-party/litehtml/include/litehtml/flex_line.h`
  - `third-party/litehtml/src/flex_line.cpp`
  - `third-party/litehtml/include/litehtml/render_flex.h`
  - `third-party/litehtml/src/render_flex.cpp`
  - `third-party/litehtml/VENDOR.md`
- Test: `third-party/litehtml/tests/flex_gap_test.cpp`, plus a `cc_test` in `third-party/litehtml/BUILD`

**Interfaces:**
- Produces: `css_properties::get_row_gap()` and `get_column_gap()` (`const css_length&`, resolved to px; predefined means `normal`, which is 0). Flex layout honours them.

- [ ] **Step 1: Write the failing test `third-party/litehtml/tests/flex_gap_test.cpp`**

```cpp
#include "test_container.h"

#include <cstdio>

static int failures = 0;

static float x_of(const litehtml::document::ptr& doc, const char* id) {
    auto el = doc->root()->select_one(std::string("#") + id);
    return el ? float(el->get_placement().x) : -1.0f;
}
static float y_of(const litehtml::document::ptr& doc, const char* id) {
    auto el = doc->root()->select_one(std::string("#") + id);
    return el ? float(el->get_placement().y) : -1.0f;
}

int main() {
    litehtml_test::TestContainer c;
    const char* item = "style='width:50px;height:10px;flex:none'";

    // Row: three 50px items, gap 10 → x = 0, 60, 120.
    auto row = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='display:flex;gap:10px'>") +
        "<div id=a " + item + "></div><div id=b " + item + "></div><div id=c " + item + "></div></div></body>");
    CHECK(x_of(row, "a") == 0.0f);
    CHECK(x_of(row, "b") == 60.0f);
    CHECK(x_of(row, "c") == 120.0f);

    // column-gap alone, and justify-content keeps working with it: space-between ignores gap's leftover.
    auto cg = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='display:flex;column-gap:6px'>") +
        "<div id=a " + item + "></div><div id=b " + item + "></div></div></body>");
    CHECK(x_of(cg, "b") == 56.0f);

    // Wrap: container 120px; 50 + 10 + 50 = 110 fits, the third wraps; row-gap 4 between lines.
    auto wrap = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='display:flex;flex-wrap:wrap;gap:4px 10px;width:120px'>") +
        "<div id=a " + item + "></div><div id=b " + item + "></div><div id=c " + item + "></div></div></body>");
    CHECK(x_of(wrap, "b") == 60.0f);
    CHECK(x_of(wrap, "c") == 0.0f);
    CHECK(y_of(wrap, "c") == 14.0f);

    // Growing items share the space left after the gaps: 300 - 2*10 = 280 → 140 each.
    auto grow = litehtml_test::layout(c, "<body style='margin:0'><div style='display:flex;gap:20px'>"
        "<div id=a style='flex:1;height:10px'></div><div id=b style='flex:1;height:10px'></div></div></body>");
    CHECK(x_of(grow, "b") == 160.0f);

    // Column direction: row-gap separates items vertically.
    auto col = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='display:flex;flex-direction:column;row-gap:8px'>") +
        "<div id=a " + item + "></div><div id=b " + item + "></div></div></body>");
    CHECK(y_of(col, "b") == 18.0f);

    // `normal` and absent are 0.
    auto none = litehtml_test::layout(c, std::string("<body style='margin:0'><div style='display:flex;gap:normal'>") +
        "<div id=a " + item + "></div><div id=b " + item + "></div></div></body>");
    CHECK(x_of(none, "b") == 50.0f);

    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("flex gap: OK\n");
    return 0;
}
```

Add to `third-party/litehtml/BUILD`:

```python
cc_test(
    name = "LitehtmlFlexGapTests",
    srcs = ["tests/flex_gap_test.cpp", "tests/test_container.h"],
    copts = test_copts,
    deps = [":litehtml"],
)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/litehtml:LitehtmlFlexGapTests --test_output=errors`
Expected: FAIL. `x_of(row, "b") == 60` fails because b sits at 50.

- [ ] **Step 3: Parse the properties**

In `include/litehtml/string_id.h`, extend the flex line of the `STRING_ID(` list:

```cpp
        _align_self_, _flex_grow_, _flex_shrink_, _flex_basis_, _gap_, _row_gap_, _column_gap_,
```

In `include/litehtml/css_values.h`, next to `flex_basis_strings`:

```cpp
    inline constexpr auto gap_strings = split_css_values<1>("normal");
```

In `src/style.cpp` `style::add_property`, after the `case _flex_basis_:` block:

```cpp
        case _row_gap_:
        case _column_gap_:
            add_length_property(name, val, gap_strings, f_length_percentage | f_positive, important);
            break;

        case _gap_:
        {
            css_length len[2];
            if(value.size() == 1 && val.ident() == "normal")
            {
                add_parsed_property(_row_gap_, property_value(css_length::predef_value(0), important));
                add_parsed_property(_column_gap_, property_value(css_length::predef_value(0), important));
            } else if(parse_two_lengths(value, len, f_length_percentage | f_positive))
            {
                add_parsed_property(_row_gap_, property_value(len[0], important));
                add_parsed_property(_column_gap_, property_value(len[1], important));
            }
            break;
        }
```

`parse_two_lengths` duplicates a single value into both slots, as for `border-spacing`. If it doesn't, set `len[1] = len[0]` when `value.size() == 1`.

- [ ] **Step 4: Compute them**

In `include/litehtml/css_properties.h`, next to `m_flex_basis`:

```cpp
        css_length           m_row_gap;
        css_length           m_column_gap;
```

and next to `get_flex_grow()`:

```cpp
        const css_length&    get_row_gap() const { return m_row_gap; }
        const css_length&    get_column_gap() const { return m_column_gap; }
```

In `src/css_properties.cpp`, in the `compute` function that sets `m_flex_justify_content`, inside the block that runs for flex containers (the one that sets `m_flex_align_content`):

```cpp
        m_row_gap    = el->get_property<css_length>(_row_gap_, false, css_length::predef_value(0), offset(m_row_gap));
        m_column_gap = el->get_property<css_length>(_column_gap_, false, css_length::predef_value(0), offset(m_column_gap));
        doc->cvt_units(m_row_gap, m_font_metrics, 0_px);
        doc->cvt_units(m_column_gap, m_font_metrics, 0_px);
```

- [ ] **Step 5: Lay out with them**

In `include/litehtml/flex_line.h`, add to `flex_line`:

```cpp
        pixel_t  gap = 0; // main-axis gap between adjacent items (column-gap for rows, row-gap for columns)

        pixel_t total_gap() const
        {
            return items.size() > 1 ? gap * pixel_t(static_cast<int>(items.size()) - 1) : 0_px;
        }
```

In `src/flex_line.cpp`:
- In `flex_line::init`, change the free-space call to

  ```cpp
      distribute_free_space(container_main_size - total_gap());
  ```

- At the very end of `flex_line::init`, after both branches have recomputed `main_size`, add

  ```cpp
      main_size += total_gap();
  ```

- In `flex_line::calculate_items_position`, change the advance

  ```cpp
      main_pos += item->get_el_main_size() + add_after_item;
  ```

  to

  ```cpp
      main_pos += item->get_el_main_size() + add_after_item + gap;
  ```

`free_main_size = container_main_size - main_size` already sees the gaps, because `main_size` now includes them.

In `include/litehtml/render_flex.h`, add a trailing `pixel_t main_gap` parameter to `get_lines` and change its definition in `src/render_flex.cpp` to match. In `get_lines`:
- Construct the first line and every later line with `line.gap = main_gap;` (set it right after each `flex_line line(...)` / `line = flex_line(...)`).
- Change the wrap test to

  ```cpp
          if(!line.items.empty() && !single_line &&
             line.main_size + main_gap * pixel_t(static_cast<int>(line.items.size())) + item->main_size > container_main_size)
  ```

In `render_item_flex::_render`, before `m_lines = get_lines(...)`:

```cpp
    auto gap_px = [](const css_length& len) -> pixel_t {
        if(len.is_predefined() || len.units() == css_units_percentage)
        {
            return 0_px;
        }
        return pixel_t(len.val());
    };
    pixel_t main_gap  = is_row_direction ? gap_px(css().get_column_gap()) : gap_px(css().get_row_gap());
    pixel_t cross_gap = is_row_direction ? gap_px(css().get_row_gap()) : gap_px(css().get_column_gap());
```

Then:
- Pass `main_gap` to `get_lines`.
- In the loop that calls `ln.init`, change `ret_width += ln.base_size;` to `ret_width += ln.base_size + ln.total_gap();`.
- After that loop, add

  ```cpp
      if(m_lines.size() > 1)
      {
          sum_cross_size += cross_gap * pixel_t(static_cast<int>(m_lines.size()) - 1);
      }
  ```

- In the line-placement loop, change `line_pos += ln.cross_size + add_after_line;` to `line_pos += ln.cross_size + add_after_line + cross_gap;`.

- [ ] **Step 6: Run the tests**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/litehtml:LitehtmlFlexGapTests //third-party/litehtml:LitehtmlSmokeTests --test_output=errors`
Expected: both PASS.

- [ ] **Step 7: Record the fork change in `VENDOR.md`**

Replace `(none yet)` with:

```markdown
1. Flex `gap` / `row-gap` / `column-gap` (Task 3 of docs/superpowers/plans/2026-10-13-message-widgets.md):
   string ids, `style::add_property` cases, `css_properties::m_row_gap`/`m_column_gap`, a
   `flex_line::gap` honoured by `init` (free space minus gaps), `calculate_items_position` and
   `render_item_flex::get_lines` (wrapping), plus the cross-axis gap between lines. px/em only;
   a percentage gap resolves to 0.
```

- [ ] **Step 8: Commit**

```bash
git add third-party/litehtml
git commit -m "third-party/litehtml: flex gap, row-gap and column-gap"
```

---

### Task 4: litehtml fork — per-element draw token, paint properties, letter-spacing, tabular figures

**Files:**
- Modify:
  - `third-party/litehtml/src/document.cpp:570`
  - `third-party/litehtml/src/render_item.cpp:971,975,985,991,1000`
  - `third-party/litehtml/src/render_table.cpp:466,484`
  - `include/litehtml/string_id.h`, `css_values.h`, `css_properties.h`, `font_description.h`
  - `src/style.cpp`, `src/css_properties.cpp`
  - `VENDOR.md`
- Test: `third-party/litehtml/tests/fork_properties_test.cpp`, plus a `cc_test`

**Interfaces:**
- Produces:
  - **The draw token.** Every `document_container` drawing callback receives, as `hdc`, `(uint_ptr)` of the `litehtml::render_item*` being drawn. `document::draw`'s own `hdc` argument is ignored.
  - **Paint-property getters:** `css_properties::get_opacity_tokens()`, `get_transform_tokens()` and `get_box_shadow_tokens()`, each returning `const css_token_vector&` (raw, unparsed; empty when unset).
  - **Font fields:** `font_description::letter_spacing` (`pixel_t`, 0 = normal) and `font_description::tabular_nums` (`bool`), both part of `hash()`.

- [ ] **Step 1: Write the failing test `third-party/litehtml/tests/fork_properties_test.cpp`**

```cpp
#include "test_container.h"

#include <litehtml/render_item.h>

#include <cstdio>

static int failures = 0;

int main() {
    // 1. Every drawing callback carries the render item it belongs to as hdc.
    {
        litehtml_test::TestContainer c;
        auto doc = litehtml_test::layout(c, "<body style='margin:0'><div id=box style='height:20px;background:#f00;border:1px solid #000'>"
            "<span id=t>hi</span></div><ul><li>x</li></ul></body>");
        litehtml::position clip(0, 0, 300, 600);
        c.calls.clear();
        doc->draw(0, 0, 0, &clip);
        CHECK(!c.calls.empty());
        for (auto& call : c.calls) {
            CHECK(call.hdc != 0);
            auto* ri = reinterpret_cast<litehtml::render_item*>(call.hdc);
            CHECK(ri && ri->src_el());
        }
        auto box = doc->root()->select_one("#box");
        bool fillOnBox = false;
        for (auto& call : c.calls) {
            if (call.kind == "fill" && reinterpret_cast<litehtml::render_item*>(call.hdc)->src_el() == box) fillOnBox = true;
        }
        CHECK(fillOnBox);
    }
    // 2. Paint properties are kept as tokens, not dropped.
    {
        litehtml_test::TestContainer c;
        auto doc = litehtml_test::layout(c, "<body><div id=a style='opacity:.5;transform:rotate(45deg) translate(2px,3px);"
            "box-shadow:0 0 0 6px rgba(255,210,63,.25)'>x</div><div id=b>y</div></body>");
        auto a = doc->root()->select_one("#a");
        auto b = doc->root()->select_one("#b");
        CHECK(a->css().get_opacity_tokens().size() == 1);
        CHECK(a->css().get_transform_tokens().size() == 2);
        CHECK(!a->css().get_box_shadow_tokens().empty());
        CHECK(b->css().get_opacity_tokens().empty());
        CHECK(b->css().get_transform_tokens().empty());
    }
    // 3. letter-spacing (px and em) and tabular-nums reach the font description.
    {
        litehtml_test::TestContainer c;
        litehtml_test::layout(c, "<body style='font-size:20px'><div style='letter-spacing:.05em;font-variant-numeric:tabular-nums'>12</div>"
            "<p style='letter-spacing:2px'>a</p></body>");
        bool sawEm = false, sawPx = false, sawTabular = false;
        for (auto& f : c.fonts) {
            if (float(f.letter_spacing) == 1.0f) sawEm = true;
            if (float(f.letter_spacing) == 2.0f) sawPx = true;
            if (f.tabular_nums) sawTabular = true;
        }
        CHECK(sawEm);
        CHECK(sawPx);
        CHECK(sawTabular);
    }
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("fork properties: OK\n");
    return 0;
}
```

Add to `third-party/litehtml/BUILD`:

```python
cc_test(
    name = "LitehtmlForkPropertiesTests",
    srcs = ["tests/fork_properties_test.cpp", "tests/test_container.h"],
    copts = test_copts,
    deps = [":litehtml"],
)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/litehtml:LitehtmlForkPropertiesTests --test_output=errors`
Expected: compile FAIL (`get_opacity_tokens`, `letter_spacing`, `tabular_nums` are unknown).

- [ ] **Step 3: Replace the draw token at the eight call sites**

These are the only places litehtml enters an element's `draw`, and every drawing callback is reached through one of them (checked with `grep -n 'container()->draw_\|src_el()->draw(' src/*.cpp`).
- `src/document.cpp:570`: `m_root->draw(hdc, x, y, clip, m_root_render);` becomes `m_root->draw((uint_ptr) m_root_render.get(), x, y, clip, m_root_render);`.
- `src/render_item.cpp:971,975,985,991,1000`: in each `el->src_el()->draw(hdc, ...)`, replace the first argument `hdc` with `(uint_ptr) el.get()`. Leave the `draw_stacking_context(hdc, ...)` and `draw_children(hdc, ...)` calls unchanged; they only recurse.
- `src/render_table.cpp:466`: `caption->src_el()->draw((uint_ptr) caption.get(), pos.x, pos.y, clip, caption);`
- `src/render_table.cpp:484`: `cell->el->src_el()->draw((uint_ptr) cell->el.get(), pos.x, pos.y, clip, cell->el);`

- [ ] **Step 4: Paint properties as tokens**

In `string_id.h`, add `_opacity_, _transform_, _box_shadow_, _letter_spacing_, _font_variant_numeric_,` to the line with `_text_transform_`.

In `css_values.h`: `inline constexpr auto letter_spacing_strings = split_css_values<1>("normal");`

In `src/style.cpp` `style::add_property`, a block before the `default:` branch:

```cpp
        case _opacity_:
        case _transform_:
        case _box_shadow_:
            // Paint-only properties: kept as raw tokens for the host to parse (message widgets fork).
            add_parsed_property(name, property_value(value, important));
            break;

        case _letter_spacing_:
            add_length_property(name, val, letter_spacing_strings, f_length, important);
            break;

        case _font_variant_numeric_:
            add_parsed_property(name, property_value(get_repr(value, 0, -1, true), important));
            break;
```

In `css_properties.h`, add members and getters:

```cpp
        css_token_vector     m_opacity_tokens;
        css_token_vector     m_transform_tokens;
        css_token_vector     m_box_shadow_tokens;
        css_length           m_letter_spacing;
        std::string          m_font_variant_numeric;
```

```cpp
        const css_token_vector& get_opacity_tokens() const { return m_opacity_tokens; }
        const css_token_vector& get_transform_tokens() const { return m_transform_tokens; }
        const css_token_vector& get_box_shadow_tokens() const { return m_box_shadow_tokens; }
```

(Add `#include "css_tokenizer.h"` to `css_properties.h` if it isn't already reachable.)

In `src/css_properties.cpp` `compute` (next to `m_css_text_indent`):

```cpp
    static const css_token_vector no_tokens;
    m_opacity_tokens    = el->get_property<css_token_vector>(_opacity_, false, no_tokens, offset(m_opacity_tokens));
    m_transform_tokens  = el->get_property<css_token_vector>(_transform_, false, no_tokens, offset(m_transform_tokens));
    m_box_shadow_tokens = el->get_property<css_token_vector>(_box_shadow_, false, no_tokens, offset(m_box_shadow_tokens));
```

- [ ] **Step 5: letter-spacing and tabular figures in the font**

In `include/litehtml/font_description.h`, add to the struct:

```cpp
        pixel_t     letter_spacing = 0;                              // Extra advance per character (CSS letter-spacing), px
        bool        tabular_nums   = false;                          // font-variant-numeric: tabular-nums
```

and append to `hash()` before `return out;`:

```cpp
            out += ":ls=" + std::to_string(letter_spacing.value());
            out += ":tn=" + std::to_string(tabular_nums ? 1 : 0);
```

In `src/css_properties.cpp`, in the font computation, where `descr` is built (`descr.family = m_font_family; ...`, around line 501), add before `descr` is used:

```cpp
    m_letter_spacing = el->get_property<css_length>(_letter_spacing_, true, css_length::predef_value(0), offset(m_letter_spacing));
    m_font_variant_numeric = el->get_property<std::string>(_font_variant_numeric_, true, "", offset(m_font_variant_numeric));
    pixel_t letter_spacing = 0_px;
    if(!m_letter_spacing.is_predefined())
    {
        if(m_letter_spacing.units() == css_units_em)
        {
            letter_spacing = pixel_t(m_letter_spacing.val() * float(font_size.value()));
        } else if(m_letter_spacing.units() == css_units_px || m_letter_spacing.units() == css_units_none)
        {
            letter_spacing = pixel_t(m_letter_spacing.val());
        }
    }
    descr.letter_spacing = letter_spacing;
    descr.tabular_nums   = m_font_variant_numeric.find("tabular-nums") != std::string::npos;
```

`font_size` is the variable that function already uses for `descr.size = std::round(font_size.value());`. If the local is named differently, use that one.

- [ ] **Step 6: Run the tests**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/litehtml:all --test_output=errors`
Expected: `LitehtmlSmokeTests`, `LitehtmlFlexGapTests` and `LitehtmlForkPropertiesTests` all PASS.

- [ ] **Step 7: Record the fork changes in `VENDOR.md`**

Append:

```markdown
2. The draw token (Task 4): the eight `src_el()->draw(` call sites (document.cpp:570,
   render_item.cpp ×5, render_table.cpp ×2) pass `(uint_ptr)` of the render item being drawn as
   `hdc`, so every `document_container` drawing callback knows its element. `document::draw`'s
   `hdc` is therefore ignored. Every drawing callback in `src/` is reached through these sites.
3. `opacity`, `transform`, `box-shadow` stored as raw token lists
   (`css_properties::get_*_tokens()`); the message-widget core parses them.
4. `letter-spacing` (px/em) and `font-variant-numeric: tabular-nums` reach the font as
   `font_description::letter_spacing` / `tabular_nums` (both in `hash()`).
```

- [ ] **Step 8: Commit**

```bash
git add third-party/litehtml
git commit -m "third-party/litehtml: per-element draw token, paint-property tokens, letter-spacing, tabular figures"
```

---

### Task 5: MessageWidgetCore — the litehtml core, the no-network container, the C API

**Files:**
- Create:
  - `submodules/TelegramUI/Components/MessageWidget/Fixtures/{BUILD,README.md}`
  - The fixtures `01-weather-card.html` … `05-countdown.html`, `10-sandbox-probe.html` and `01…05.ops.json`
  - `submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore/{BUILD,PROVENANCE.md}`
  - `PublicHeaders/MessageWidgetCore/MessageWidgetCore.h`
  - `Sources/{renderer.h,renderer.cpp,backend.h,display_list.h,mwc.cpp}`, `Sources/apple/{coregraphics.h,coregraphics.cpp}`, `Sources/twidget/json.h`
- Test: `MessageWidgetCore/Tests/core_tests.cpp`

**Interfaces:**
- Consumes: `//third-party/litehtml:litehtml` (Tasks 2–4).
- Produces the C API in `MessageWidgetCore.h` (later tasks use these exact names):

```c
typedef struct mwc_core mwc_core;
mwc_core *mwc_create(double width, double dpr, bool dark);
void mwc_destroy(mwc_core *core);
char *mwc_receive(mwc_core *core, const char *json);          // host → core message; JSON array of core → host messages
char *mwc_set_width(mwc_core *core, double width);
char *mwc_set_theme(mwc_core *core, bool dark);
char *mwc_touch(mwc_core *core, int32_t action, double x, double y, int32_t pointer, bool primary); // 0 down 1 move 2 up 3 cancel
double mwc_document_height(mwc_core *core);                     // clamped to [24, 900]
uint64_t mwc_generation(mwc_core *core);                        // bumps on every rebuild
int32_t mwc_network_refusals(mwc_core *core);                   // non-data: URLs that reached the container
char *mwc_html(mwc_core *core);                                 // diagnostics: the last serialised document
void mwc_string_free(char *s);
```

`Backend::create_font` gains `float letter_spacing, bool tabular_nums` parameters.

- [ ] **Step 1: Copy the fixtures and generate the ops fixtures**

```bash
F=submodules/TelegramUI/Components/MessageWidget/Fixtures
mkdir -p $F
for f in 01-weather-card 02-split-bill 03-faq-accordion 04-poll 05-countdown 10-sandbox-probe; do
  cp docs/widget-messages/examples/$f.html $F/
done
cd ~/build/widget-sandbox
for f in 01-weather-card 02-split-bill 03-faq-accordion 04-poll 05-countdown; do
  ./node_modules/.bin/tsx packages/core/scripts/sandbox-node.ts \
    ~/build/telegram/telegram-ios/$F/$f.html --ops-file ~/build/telegram/telegram-ios/$F/$f.ops.json
done
cd ~/build/telegram/telegram-ios
```

Each `.ops.json` is `[{"type":"ops","ops":[...]}]`: the validated ops of a boot, ready for `mwc_receive`. They are committed and never regenerated by the build.

`Fixtures/README.md`:

```markdown
Test inputs for MessageWidget: byte-identical copies of docs/widget-messages/examples 01–05 and
10 (the docs copies are deliberately not committed), and `*.ops.json`, the validated ops of
booting 01–05, generated once with widget-sandbox's Node harness:
`./node_modules/.bin/tsx packages/core/scripts/sandbox-node.ts <file>.html --ops-file <file>.ops.json`
(run from ~/build/widget-sandbox). Regenerate them by hand when the vendored bundles change.
```

`Fixtures/BUILD`:

```python
filegroup(
    name = "WidgetFixtures",
    testonly = True,
    srcs = glob(["*.html"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

filegroup(
    name = "OpsFixtures",
    testonly = True,
    srcs = glob(["*.ops.json"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# Single files, so a cc_test can name one in `$(location …)` and derive the directory from it.
exports_files(
    glob(["*.ops.json", "*.html"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)
```

- [ ] **Step 2: Copy the core sources**

```bash
S=~/build/widget-sandbox/apps/renderer-litehtml
C=submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore
mkdir -p $C/Sources/apple $C/Sources/twidget $C/PublicHeaders/MessageWidgetCore $C/Tests
cp $S/src/renderer.h $S/src/renderer.cpp $S/src/backend.h $S/src/display_list.h $C/Sources/
cp $S/src/apple/coregraphics.h $S/src/apple/coregraphics.cpp $C/Sources/apple/
cp ~/build/widget-sandbox/packages/desktop/sandbox/include/twidget/json.h $C/Sources/twidget/
cp $S/tests/test_main.cpp $C/Tests/core_tests.cpp
```

`PROVENANCE.md`:

```markdown
# MessageWidgetCore provenance

Derived from widget-sandbox (commit 862eec8):
- Sources/renderer.{h,cpp}, backend.h, display_list.h ← apps/renderer-litehtml/src
- Sources/apple/coregraphics.{h,cpp} ← apps/renderer-litehtml/src/apple
- Sources/twidget/json.h ← packages/desktop/sandbox/include/twidget/json.h (unchanged)
- Tests/core_tests.cpp ← apps/renderer-litehtml/tests/test_main.cpp

Changed here: the C API is `mwc_*` (Sources/mwc.cpp, PublicHeaders) instead of `twl_*`; the
container counts every non-data: URL that reaches it (`network_refusals`); fonts carry
letter-spacing and tabular figures; the container records draw commands per element (Task 6).
This copy is ours: edit it here.
```

- [ ] **Step 3: The no-network counter, the font fields and per-call letter spacing**

In `Sources/renderer.h`, add to the `Renderer` public section:

```cpp
    /// Every non-`data:` URL litehtml handed the container (images, @import, links). The validator
    /// strips them all before they get here, so anything above 0 is a validator hole.
    int network_refusals() const;
    uint64_t generation() const { return generation_; }
    double clamped_height() const;
```

and to the private members `uint64_t generation_ = 0;`.

In `Sources/renderer.cpp`:
- `Container` gets `int network_refusals_ = 0;` and a getter `int network_refusals() const { return network_refusals_; }`.
- In `Container::load_image`, the `else` branch (non-`data:`) adds `network_refusals_++;` before pushing the violation.
- `Container::import_css` becomes

  ```cpp
      void import_css(std::string& text, const std::string& url, std::string&) override {
          if (!url.empty()) network_refusals_++;
          text.clear();
      }
  ```

- `Container::link` becomes `void link(const std::shared_ptr<litehtml::document>&, const litehtml::element::ptr&) override { network_refusals_++; }`. litehtml calls it only for `<link>`, which the validator drops.
- `Renderer::rebuild()` ends with `generation_++;`.
- `Container::create_font` passes `float(descr.letter_spacing)` and `descr.tabular_nums` through to `backend_.create_font(...)`.
- `Container::measure_text` calls `backend_.create_font(family, size, weight, italic, 0.0f, false, fm)`.

Add the definitions:

```cpp
int Renderer::network_refusals() const { return container_->network_refusals(); }
double Renderer::clamped_height() const { return std::clamp(doc_height_, MIN_HEIGHT, MAX_HEIGHT); }
```

In `Sources/backend.h`, change the signature to

```cpp
    virtual int create_font(const std::string& families, float size_px, int weight, bool italic, float letter_spacing, bool tabular_nums, FontMetrics& out) = 0;
```

In `Sources/apple/coregraphics.h`:
- Change `CGBackend::create_font` the same way.
- Add `float letter_spacing = 0; bool tabular = false;` to `CGBackend::Font`.
- Add a public method used by Task 6:

  ```cpp
      /// Paints `list` (CSS px, y-down) into `ctx`, translated by (-origin_x, -origin_y).
      void paint_into(const DisplayList& list, CGContextRef ctx, float origin_x, float origin_y);
  ```

In `Sources/apple/coregraphics.cpp`:
- At the end of `create_font`, before computing metrics, apply tabular figures:

  ```cpp
      if (tabular_nums) {
          int type = kNumberSpacingType, selector = kMonospacedNumbersSelector;
          CFHolder t(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &type));
          CFHolder s(CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &selector));
          const void* fkeys[] = {kCTFontFeatureTypeIdentifierKey, kCTFontFeatureSelectorIdentifierKey};
          const void* fvals[] = {t.ref, s.ref};
          CFHolder feature(CFDictionaryCreate(kCFAllocatorDefault, fkeys, fvals, 2, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
          const void* features[] = {feature.ref};
          CFHolder featureArray(CFArrayCreate(kCFAllocatorDefault, features, 1, &kCFTypeArrayCallBacks));
          const void* akeys[] = {kCTFontFeatureSettingsAttribute};
          const void* avals[] = {featureArray.ref};
          CFHolder attrs(CFDictionaryCreate(kCFAllocatorDefault, akeys, avals, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks));
          CFHolder desc(CTFontDescriptorCreateWithAttributes((CFDictionaryRef)attrs.ref));
          if (CTFontRef tab = CTFontCreateCopyWithAttributes(font, size, nullptr, (CTFontDescriptorRef)desc.ref)) {
              CFRelease(font);
              font = tab;
          }
      }
  ```

  and store `f.letter_spacing = letter_spacing; f.tabular = tabular_nums;`.
- `make_line` adds a kern attribute when `f.letter_spacing != 0`:

  ```cpp
      CFHolder kern(CFNumberCreate(kCFAllocatorDefault, kCFNumberFloatType, &f.letter_spacing));
      const void* keys[] = {kCTFontAttributeName, kCTForegroundColorAttributeName, kCTKernAttributeName};
      const void* values[] = {f.font, color, kern.ref};
  ```

  Keep the order so that `color` may be `nullptr`. When there is no colour, build the dictionary from keys 0 and 2 only.
- Split the body of `CGBackend::paint` into `paint_into(list, ctx, 0, 0)`:
  - `paint` creates the bitmap context, flips it to y-down CSS px (its existing `TranslateCTM`/`ScaleCTM`), and calls `paint_into`.
  - `paint_into` starts with `CGContextSaveGState(ctx); CGContextTranslateCTM(ctx, -origin_x, -origin_y); CGContextSetTextMatrix(ctx, CGAffineTransformMakeScale(1, -1));`, runs the existing command loop, and ends with `CGContextRestoreGState(ctx);` (after unwinding its own clip depth).

- [ ] **Step 4: Write the public header `PublicHeaders/MessageWidgetCore/MessageWidgetCore.h`**

```c
// C API of the message-widget core: validated RenderOps in, litehtml layout, per-element drawing
// out. One core per widget behind an opaque handle; every call from the thread that runs the
// widget (the main thread, or the widget JS thread while the main thread waits). Strings
// returned by mwc_* are released with mwc_string_free.
#ifndef MESSAGE_WIDGET_CORE_H
#define MESSAGE_WIDGET_CORE_H

#include <CoreGraphics/CoreGraphics.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct mwc_core mwc_core;

/// One laid-out element (Task 6). Coordinates are CSS px == points, in document space.
typedef struct {
    int64_t id;            // the element's node id (data-twid)
    int64_t parent_id;     // the nearest ancestor that is a node; 0 for the root
    float x, y, width, height;          // border box
    float opacity;                      // 1 when unset
    int32_t has_transform;
    float transform[6];                 // a b c d tx ty, CSS matrix() order; applied around the box centre
    int32_t has_shadow;
    float shadow_x, shadow_y, shadow_blur, shadow_spread;
    uint32_t shadow_argb;
    int32_t clips;                      // overflow is not visible
    float radii[8];                     // border radii: tlx tly trx try brx bry blx bly
    int32_t z_index;                    // for positioned elements; 0 otherwise
} mwc_layout_node;

mwc_core *mwc_create(double width, double dpr, bool dark);
void mwc_destroy(mwc_core *core);
char *mwc_receive(mwc_core *core, const char *json);
char *mwc_set_width(mwc_core *core, double width);
char *mwc_set_theme(mwc_core *core, bool dark);
char *mwc_touch(mwc_core *core, int32_t action, double x, double y, int32_t pointer, bool primary);
double mwc_document_height(mwc_core *core);
uint64_t mwc_generation(mwc_core *core);
int32_t mwc_network_refusals(mwc_core *core);
char *mwc_html(mwc_core *core);
/// Task 6: the laid-out nodes in document order, valid until the next mutating call.
size_t mwc_layout_nodes(mwc_core *core, const mwc_layout_node **out);
/// Task 6: draws node `id`'s own commands into `ctx` (y-down, CSS px, origin at the node's border box).
void mwc_draw_node(mwc_core *core, int64_t id, CGContextRef ctx);
void mwc_string_free(char *s);

#ifdef __cplusplus
}
#endif
#endif
```

- [ ] **Step 5: Write `Sources/mwc.cpp`**

```cpp
// C API over twlite::Renderer (renderer.h). Exceptions never cross the boundary: they are
// logged and the call answers its default.
#include "MessageWidgetCore/MessageWidgetCore.h"
#include "renderer.h"
#include "apple/coregraphics.h"

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <exception>
#include <memory>
#include <string>
#include <vector>

using twidget::Json;

struct mwc_core {
    std::unique_ptr<twlite::CGBackend> backend;
    std::unique_ptr<twlite::Renderer> renderer;
};

namespace {

char* ret_string(const std::string& s) {
    char* out = (char*)std::malloc(s.size() + 1);
    if (!out) return nullptr;
    std::memcpy(out, s.c_str(), s.size() + 1);
    return out;
}

std::string messages(const std::vector<Json>& out) {
    Json arr = Json::array();
    for (const Json& m : out) arr.push(m);
    return arr.dump();
}

template <typename T, typename F>
T guarded(mwc_core* h, T def, const char* what, F f) {
    if (!h || !h->renderer) return def;
    try {
        return f(*h);
    } catch (const std::exception& e) {
        std::fprintf(stderr, "MessageWidgetCore [ERROR] %s: %s\n", what, e.what());
    } catch (...) {
        std::fprintf(stderr, "MessageWidgetCore [ERROR] %s: unknown exception\n", what);
    }
    return def;
}

} // namespace

extern "C" {

mwc_core* mwc_create(double width, double dpr, bool dark) {
    try {
        auto h = std::make_unique<mwc_core>();
        h->backend = std::make_unique<twlite::CGBackend>();
        h->renderer = std::make_unique<twlite::Renderer>(width, dpr, dark, *h->backend);
        return h.release();
    } catch (...) {
        return nullptr;
    }
}

void mwc_destroy(mwc_core* core) {
    if (!core) return;
    core->renderer.reset();  // the document releases its fonts through the backend
    core->backend.reset();
    delete core;
}

char* mwc_receive(mwc_core* core, const char* json) {
    return guarded<char*>(core, ret_string("[]"), "receive", [&](mwc_core& h) {
        auto msg = Json::parse(json ? json : "");
        if (!msg) return ret_string("[]");
        return ret_string(messages(h.renderer->receive(*msg)));
    });
}

char* mwc_set_width(mwc_core* core, double width) {
    return guarded<char*>(core, ret_string("[]"), "set_width", [&](mwc_core& h) {
        std::vector<Json> out;
        h.renderer->set_width(width, out);
        return ret_string(messages(out));
    });
}

char* mwc_set_theme(mwc_core* core, bool dark) {
    return guarded<char*>(core, ret_string("[]"), "set_theme", [&](mwc_core& h) {
        std::vector<Json> out;
        h.renderer->set_theme(dark, out);
        return ret_string(messages(out));
    });
}

char* mwc_touch(mwc_core* core, int32_t action, double x, double y, int32_t pointer, bool primary) {
    return guarded<char*>(core, ret_string("[]"), "touch", [&](mwc_core& h) {
        return ret_string(messages(h.renderer->touch(action, x, y, pointer, primary)));
    });
}

double mwc_document_height(mwc_core* core) {
    return guarded<double>(core, 24.0, "height", [](mwc_core& h) { return h.renderer->clamped_height(); });
}

uint64_t mwc_generation(mwc_core* core) {
    return guarded<uint64_t>(core, 0, "generation", [](mwc_core& h) { return h.renderer->generation(); });
}

int32_t mwc_network_refusals(mwc_core* core) {
    return guarded<int32_t>(core, 0, "refusals", [](mwc_core& h) { return int32_t(h.renderer->network_refusals()); });
}

char* mwc_html(mwc_core* core) {
    return guarded<char*>(core, ret_string(""), "html", [](mwc_core& h) { return ret_string(h.renderer->last_html()); });
}

void mwc_string_free(char* s) { std::free(s); }

} // extern "C"
```

widget-sandbox's `twl_*` glue (`src/apple/ffi.cpp`) is not copied: `mwc.cpp` replaces it. `mwc_layout_nodes` and `mwc_draw_node` arrive in Task 6. Until then the header declares them but nothing calls them, and the linker only complains if something does.

- [ ] **Step 6: Port the existing tests and add the fixture and refusal tests**

In `Tests/core_tests.cpp`:
- Change the includes to `#include "../Sources/apple/coregraphics.h"` and `#include "../Sources/renderer.h"`.
- Update the `CGBackend` font calls, if the old tests call `create_font` directly, to the new signature (`..., 0.0f, false, fm)`).
- Rename `main` to `int legacy_tests()` returning `failures`, and add:

```cpp
#include "MessageWidgetCore/MessageWidgetCore.h"
#include <fstream>
#include <sstream>

static std::string read_file(const std::string& path) {
    std::ifstream f(path);
    std::stringstream s;
    s << f.rdbuf();
    return s.str();
}

/// Boot ops of examples 01–05 (generated by widget-sandbox's harness) lay out to plausible heights,
/// deterministically, and reflow narrower → taller.
static void fixture_heights(const std::string& dir) {
    const char* names[] = {"01-weather-card", "02-split-bill", "03-faq-accordion", "04-poll", "05-countdown"};
    for (const char* name : names) {
        std::string msgs = read_file(dir + "/" + name + ".ops.json");
        CHECK(!msgs.empty());
        auto parsed = Json::parse(msgs);
        CHECK(parsed.has_value());
        if (!parsed) continue;
        mwc_core* core = mwc_create(360, 3, false);
        for (const Json& m : parsed->arr()) {
            char* out = mwc_receive(core, m.dump().c_str());
            mwc_string_free(out);
        }
        double h360 = mwc_document_height(core);
        std::printf("%s: %.0f pt at 360\n", name, h360);
        CHECK(h360 > 60 && h360 <= 900);
        mwc_string_free(mwc_set_width(core, 240));
        double h240 = mwc_document_height(core);
        CHECK(h240 >= h360);
        CHECK(mwc_network_refusals(core) == 0);
        mwc_destroy(core);
    }
}

/// The container refuses (and counts) anything but data: — even when handed one directly.
static void container_refuses_network() {
    mwc_core* core = mwc_create(360, 2, false);
    const char* ops = R"({"type":"ops","ops":[
      {"op":"el","id":2,"tag":"html","adopt":"html","attrs":[]},
      {"op":"el","id":3,"tag":"head","adopt":"head"},
      {"op":"el","id":4,"tag":"body","adopt":"body"},
      {"op":"el","id":5,"tag":"img","attrs":[["src","https://example.com/x.png"]]},
      {"op":"ins","id":5,"parent":4},
      {"op":"el","id":6,"tag":"style"},
      {"op":"css","id":6,"text":"body{background:url(https://example.com/bg.png)}@import url(https://example.com/a.css);"},
      {"op":"ins","id":6,"parent":3}
    ]})";
    mwc_string_free(mwc_receive(core, ops));
    CHECK(mwc_network_refusals(core) >= 2);
    mwc_destroy(core);
}

int main(int argc, char** argv) {
    legacy_tests();
    std::string dir = argc > 1 ? std::string(argv[1]) : std::string();
    if (!dir.empty()) {
        size_t slash = dir.rfind('/');
        dir = dir.substr(0, slash);
    }
    fixture_heights(dir);
    container_refuses_network();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("MessageWidgetCore: OK\n");
    return 0;
}
```

The refusal test feeds raw (unvalidated) ops on purpose: this is the container's own guarantee, and it must hold even if the validator lets something through.

- [ ] **Step 7: Write `MessageWidgetCore/BUILD`**

```python
load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")
load("@rules_cc//cc:objc_library.bzl", "objc_library")

core_copts = [
    "-std=c++20",
    "-Wno-unused-parameter",
    "-Isubmodules/TelegramUI/Components/MessageWidget/MessageWidgetCore/Sources",
    "-Isubmodules/TelegramUI/Components/MessageWidget/MessageWidgetCore/PublicHeaders",
]

cc_library(
    name = "MessageWidgetCoreLib",
    srcs = glob([
        "Sources/**/*.cpp",
        "Sources/**/*.h",
    ]),
    hdrs = glob(["PublicHeaders/**/*.h"]),
    includes = ["PublicHeaders"],
    copts = core_copts,
    linkopts = [
        "-framework", "CoreGraphics",
        "-framework", "CoreText",
        "-framework", "ImageIO",
        "-framework", "CoreFoundation",
    ],
    deps = ["//third-party/litehtml"],
    visibility = ["//visibility:private"],
)

objc_library(
    name = "MessageWidgetCore",
    module_name = "MessageWidgetCore",
    enable_modules = True,
    hdrs = glob(["PublicHeaders/**/*.h"]),
    includes = ["PublicHeaders"],
    deps = [":MessageWidgetCoreLib"],
    sdk_frameworks = ["CoreGraphics", "CoreText", "ImageIO"],
    visibility = ["//visibility:public"],
)

cc_test(
    name = "MessageWidgetCoreTests",
    srcs = ["Tests/core_tests.cpp"],
    copts = core_copts,
    data = [
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:OpsFixtures",
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:01-weather-card.ops.json",
    ],
    args = ["$(location //submodules/TelegramUI/Components/MessageWidget/Fixtures:01-weather-card.ops.json)"],
    deps = [":MessageWidgetCoreLib"],
)
```

The test derives the fixture directory from the one file passed in `args`, as libprisma's `SyntaxHighlighterTests` does with `grammars.dat`.

- [ ] **Step 8: Run the tests**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore:MessageWidgetCoreTests --test_output=all`
Expected:
- PASS, printing five heights between 60 and 900.
- The legacy renderer-litehtml tests pass unchanged. If one asserts exact pixel output that the font changes moved, compare against the widget-sandbox run first. Only a real behaviour change is a bug.

- [ ] **Step 9: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget
git commit -m "MessageWidgetCore: litehtml core with a counting no-network container and the mwc C API"
```

---

### Task 6: MessageWidgetCore — per-element command lists, layout nodes, node drawing

**Files:**
- Create: `MessageWidgetCore/Sources/{paint_properties.h,paint_properties.cpp,layout_nodes.h,layout_nodes.cpp}`
- Modify: `MessageWidgetCore/Sources/renderer.{h,cpp}`, `MessageWidgetCore/Sources/mwc.cpp`
- Test: `MessageWidgetCore/Tests/layout_tests.cpp`, plus a `cc_test`

**Interfaces:**
- Consumes: the draw token from Task 4 (`hdc` is a `litehtml::render_item*`), and the token getters.
- Produces:
  - `mwc_layout_nodes` and `mwc_draw_node`, as declared in Task 5;
  - `twlite::parse_opacity`, `twlite::parse_transform` and `twlite::parse_box_shadow` (`paint_properties.h`);
  - `Renderer::layout_nodes()` returning `const std::vector<mwc_layout_node>&`;
  - `Renderer::draw_node(int64_t id, CGContextRef ctx, CGBackend& backend)`.

- [ ] **Step 1: Write the failing tests `Tests/layout_tests.cpp`**

```cpp
#include "MessageWidgetCore/MessageWidgetCore.h"
#include "../Sources/paint_properties.h"
#include "twidget/json.h"

#include <litehtml/css_parser.h>
#include <litehtml/css_tokenizer.h>

#include <cmath>
#include <cstdio>
#include <set>
#include <string>

static int failures = 0;
#define CHECK(c) do { if (!(c)) { std::printf("FAIL %s:%d: %s\n", __FILE__, __LINE__, #c); failures++; } } while (0)

static litehtml::css_token_vector tokens(const std::string& css) {
    // The shape style::add_property receives: component values (functions are CV_FUNCTION with
    // their arguments in `value`), whitespace removed.
    return litehtml::normalize(css, litehtml::f_componentize | litehtml::f_remove_whitespace);
}

static const char* OPS = R"({"type":"ops","ops":[
  {"op":"el","id":2,"tag":"html","adopt":"html","attrs":[]},
  {"op":"el","id":3,"tag":"head","adopt":"head"},
  {"op":"el","id":4,"tag":"body","adopt":"body","attrs":[["style","margin:0"]]},
  {"op":"el","id":5,"tag":"div","attrs":[["style","height:40px;background:#ff0000;opacity:.5;border-radius:8px;overflow:hidden"]]},
  {"op":"ins","id":5,"parent":4},
  {"op":"el","id":6,"tag":"span","attrs":[["style","color:#0000ff"]]},
  {"op":"text","id":7,"data":"hello"},
  {"op":"ins","id":7,"parent":6},
  {"op":"ins","id":6,"parent":5},
  {"op":"el","id":8,"tag":"div","attrs":[["style","width:20px;height:20px;background:#00ff00;transform:rotate(90deg);box-shadow:2px 3px 4px 1px rgba(0,0,0,.5)"]]},
  {"op":"ins","id":8,"parent":4}
]})";

static void paint_parsers() {
    CHECK(twlite::parse_opacity(tokens(".5")) == 0.5f);
    CHECK(twlite::parse_opacity(tokens("40%")) == 0.4f);
    CHECK(twlite::parse_opacity({}) == 1.0f);
    float m[6];
    CHECK(twlite::parse_transform(tokens("rotate(90deg)"), m));
    CHECK(std::fabs(m[0]) < 1e-5 && std::fabs(m[1] - 1) < 1e-5 && std::fabs(m[2] + 1) < 1e-5 && std::fabs(m[3]) < 1e-5);
    // translate then rotate (CSS order): the point is rotated first, then moved.
    CHECK(twlite::parse_transform(tokens("translate(10px, 5px) rotate(90deg)"), m));
    CHECK(std::fabs(m[4] - 10) < 1e-4 && std::fabs(m[5] - 5) < 1e-4);
    CHECK(twlite::parse_transform(tokens("matrix(1,2,3,4,5,6)"), m));
    CHECK(m[0] == 1 && m[1] == 2 && m[2] == 3 && m[3] == 4 && m[4] == 5 && m[5] == 6);
    CHECK(!twlite::parse_transform(tokens("none"), m));
    twlite::Shadow s;
    CHECK(twlite::parse_box_shadow(tokens("2px 3px 4px 1px rgba(0,0,0,.5)"), s));
    CHECK(s.x == 2 && s.y == 3 && s.blur == 4 && s.spread == 1 && s.argb == 0x80000000u);
    CHECK(!twlite::parse_box_shadow(tokens("inset 0 0 4px #000"), s));
}

static void nodes_and_attribution() {
    mwc_core* core = mwc_create(300, 2, false);
    mwc_string_free(mwc_receive(core, OPS));
    const mwc_layout_node* nodes = nullptr;
    size_t n = mwc_layout_nodes(core, &nodes);
    std::set<int64_t> ids;
    const mwc_layout_node* box = nullptr;
    const mwc_layout_node* rot = nullptr;
    for (size_t i = 0; i < n; i++) {
        ids.insert(nodes[i].id);
        if (nodes[i].id == 5) box = &nodes[i];
        if (nodes[i].id == 8) rot = &nodes[i];
    }
    CHECK(ids.count(2) && ids.count(4) && ids.count(5) && ids.count(6) && ids.count(8));
    CHECK(ids.size() == n);
    CHECK(box && box->parent_id == 4 && box->height == 40 && box->opacity == 0.5f && box->clips && box->radii[0] == 8);
    CHECK(rot && rot->has_transform && rot->has_shadow && rot->shadow_x == 2);
    // The span (6) is a child of the box (5).
    for (size_t i = 0; i < n; i++) if (nodes[i].id == 6) CHECK(nodes[i].parent_id == 5);
    // Identity survives a rebuild that does not change the tree (a width change).
    std::set<int64_t> before = ids;
    mwc_string_free(mwc_set_width(core, 280));
    n = mwc_layout_nodes(core, &nodes);
    std::set<int64_t> after;
    for (size_t i = 0; i < n; i++) after.insert(nodes[i].id);
    CHECK(before == after);
    mwc_destroy(core);
}

/// The box's own fill lands in the box's layer: drawing node 5 alone paints red; drawing node 8
/// alone paints green; neither paints the other's colour.
static void draw_node_pixels() {
    mwc_core* core = mwc_create(300, 1, false);
    mwc_string_free(mwc_receive(core, OPS));
    auto pixel_of = [&](int64_t id, int x, int y) -> uint32_t {
        uint8_t buf[64 * 64 * 4] = {0};
        CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(buf, 64, 64, 8, 64 * 4, rgb, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        CGContextTranslateCTM(ctx, 0, 64);
        CGContextScaleCTM(ctx, 1, -1);  // y-down, like a CALayer's context on iOS
        mwc_draw_node(core, id, ctx);
        CGContextRelease(ctx);
        CGColorSpaceRelease(rgb);
        const uint8_t* p = buf + (y * 64 + x) * 4;
        return (uint32_t(p[0]) << 16) | (uint32_t(p[1]) << 8) | p[2];
    };
    uint32_t inBox = pixel_of(5, 2, 30);  // left edge of the 40px box, below the text line
    CHECK((inBox >> 16) > 200 && ((inBox >> 8) & 0xff) < 50);
    uint32_t inRot = pixel_of(8, 10, 10);
    CHECK(((inRot >> 8) & 0xff) > 200 && (inRot >> 16) < 50);
    mwc_destroy(core);
}

int main() {
    paint_parsers();
    nodes_and_attribution();
    draw_node_pixels();
    if (failures) { std::printf("%d failure(s)\n", failures); return 1; }
    std::printf("layout nodes: OK\n");
    return 0;
}
```

Add to `MessageWidgetCore/BUILD`:

```python
cc_test(
    name = "MessageWidgetLayoutTests",
    srcs = ["Tests/layout_tests.cpp"],
    copts = core_copts,
    deps = [":MessageWidgetCoreLib"],
)
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore:MessageWidgetLayoutTests --test_output=errors`
Expected: compile FAIL (`paint_properties.h` doesn't exist yet).

- [ ] **Step 3: Write `Sources/paint_properties.h` / `.cpp`**

```cpp
// Parsers for the paint-only properties the litehtml fork keeps as raw tokens (opacity,
// transform, box-shadow). They never affect layout; the native layer tree applies them.
#pragma once

#include <litehtml/css_tokenizer.h>

#include <cstdint>

namespace twlite {

struct Shadow {
    float x = 0, y = 0, blur = 0, spread = 0;
    uint32_t argb = 0;
};

/// `<number>` or `<percentage>`, clamped to [0, 1]; 1 when absent or invalid.
float parse_opacity(const litehtml::css_token_vector& v);
/// 2D transform list → affine matrix `m` (a b c d tx ty, CSS matrix() order) composed in CSS order.
/// False for `none`, empty, or anything it cannot parse (the element then draws untransformed).
bool parse_transform(const litehtml::css_token_vector& v, float m[6]);
/// The first, outer shadow (px lengths, colour via litehtml); false for none, inset or invalid.
bool parse_box_shadow(const litehtml::css_token_vector& v, Shadow& out);

} // namespace twlite
```

```cpp
#include "paint_properties.h"

#include <litehtml/web_color.h>

#include <algorithm>
#include <cctype>
#include <cmath>
#include <string>
#include <vector>

namespace twlite {

namespace {

std::string lower(std::string s) {
    for (auto& c : s) c = char(std::tolower((unsigned char)c));
    return s;
}

/// A length in px: NUMBER 0, or DIMENSION in px. False otherwise.
bool px_of(const litehtml::css_token& t, float& out) {
    if (t.type == litehtml::NUMBER && t.n.number == 0) { out = 0; return true; }
    if (t.type == litehtml::DIMENSION && lower(t.unit()) == "px") { out = t.n.number; return true; }
    return false;
}

/// An angle in radians.
bool angle_of(const litehtml::css_token& t, float& out) {
    if (t.type == litehtml::NUMBER && t.n.number == 0) { out = 0; return true; }
    if (t.type != litehtml::DIMENSION) return false;
    std::string u = lower(t.unit());
    if (u == "deg") out = t.n.number * float(M_PI) / 180.0f;
    else if (u == "rad") out = t.n.number;
    else if (u == "turn") out = t.n.number * 2.0f * float(M_PI);
    else if (u == "grad") out = t.n.number * float(M_PI) / 200.0f;
    else return false;
    return true;
}

struct Affine { float a = 1, b = 0, c = 0, d = 1, tx = 0, ty = 0; };

/// `first` applied, then `second` (CGAffineTransformConcat semantics).
Affine concat(const Affine& t1, const Affine& t2) {
    Affine r;
    r.a = t1.a * t2.a + t1.b * t2.c;
    r.b = t1.a * t2.b + t1.b * t2.d;
    r.c = t1.c * t2.a + t1.d * t2.c;
    r.d = t1.c * t2.b + t1.d * t2.d;
    r.tx = t1.tx * t2.a + t1.ty * t2.c + t2.tx;
    r.ty = t1.tx * t2.b + t1.ty * t2.d + t2.ty;
    return r;
}

/// The arguments of a function token, commas dropped.
std::vector<litehtml::css_token> args_of(const litehtml::css_token& f) {
    std::vector<litehtml::css_token> out;
    for (const auto& t : f.value) if (t.type != litehtml::COMMA && t.type != litehtml::WHITESPACE) out.push_back(t);
    return out;
}

bool function_matrix(const litehtml::css_token& f, Affine& m) {
    std::string name = lower(f.name());
    auto a = args_of(f);
    float v0 = 0, v1 = 0;
    if (name == "translate" || name == "translatex" || name == "translatey") {
        if (a.empty() || !px_of(a[0], v0)) return false;
        if (name == "translate" && a.size() > 1 && !px_of(a[1], v1)) return false;
        m = Affine{};
        if (name == "translatey") m.ty = v0; else { m.tx = v0; m.ty = name == "translate" ? v1 : 0; }
        return true;
    }
    if (name == "scale" || name == "scalex" || name == "scaley") {
        if (a.empty() || a[0].type != litehtml::NUMBER) return false;
        v0 = a[0].n.number;
        v1 = (name == "scale" && a.size() > 1 && a[1].type == litehtml::NUMBER) ? a[1].n.number : v0;
        m = Affine{};
        if (name != "scaley") m.a = v0;
        if (name != "scalex") m.d = name == "scale" ? v1 : v0;
        return true;
    }
    if (name == "rotate") {
        if (a.size() != 1 || !angle_of(a[0], v0)) return false;
        m = Affine{std::cos(v0), std::sin(v0), -std::sin(v0), std::cos(v0), 0, 0};
        return true;
    }
    if (name == "skewx" || name == "skewy") {
        if (a.size() != 1 || !angle_of(a[0], v0)) return false;
        m = Affine{};
        if (name == "skewx") m.c = std::tan(v0); else m.b = std::tan(v0);
        return true;
    }
    if (name == "matrix") {
        if (a.size() != 6) return false;
        float v[6];
        for (int i = 0; i < 6; i++) {
            if (a[i].type != litehtml::NUMBER) return false;
            v[i] = a[i].n.number;
        }
        m = Affine{v[0], v[1], v[2], v[3], v[4], v[5]};
        return true;
    }
    return false;
}

} // namespace

float parse_opacity(const litehtml::css_token_vector& v) {
    if (v.size() != 1) return 1.0f;
    if (v[0].type == litehtml::NUMBER) return std::clamp(v[0].n.number, 0.0f, 1.0f);
    if (v[0].type == litehtml::PERCENTAGE) return std::clamp(v[0].n.number / 100.0f, 0.0f, 1.0f);
    return 1.0f;
}

bool parse_transform(const litehtml::css_token_vector& v, float out[6]) {
    if (v.empty()) return false;
    std::vector<Affine> fs;
    for (const auto& t : v) {
        if (t.type != litehtml::CV_FUNCTION) return false;
        Affine m;
        if (!function_matrix(t, m)) return false;
        fs.push_back(m);
    }
    // CSS applies the rightmost function to the point first.
    Affine acc;
    for (auto it = fs.rbegin(); it != fs.rend(); ++it) acc = concat(acc, *it);
    out[0] = acc.a; out[1] = acc.b; out[2] = acc.c; out[3] = acc.d; out[4] = acc.tx; out[5] = acc.ty;
    return true;
}

bool parse_box_shadow(const litehtml::css_token_vector& v, Shadow& out) {
    std::vector<float> lengths;
    litehtml::web_color color(0, 0, 0, 255);
    bool has_color = false;
    for (const auto& t : v) {
        if (t.type == litehtml::COMMA) break;  // first shadow only
        if (t.type == litehtml::IDENT && lower(t.name()) == "inset") return false;
        if (t.type == litehtml::IDENT && lower(t.name()) == "none") return false;
        float px;
        if (px_of(t, px)) { lengths.push_back(px); continue; }
        litehtml::web_color c;
        if (litehtml::parse_color(t, c, nullptr)) { color = c; has_color = true; continue; }
        return false;
    }
    if (lengths.size() < 2) return false;
    out.x = lengths[0];
    out.y = lengths[1];
    out.blur = lengths.size() > 2 ? lengths[2] : 0;
    out.spread = lengths.size() > 3 ? lengths[3] : 0;
    (void)has_color;
    out.argb = (uint32_t(color.alpha) << 24) | (uint32_t(color.red) << 16) | (uint32_t(color.green) << 8) | uint32_t(color.blue);
    return true;
}

} // namespace twlite
```

If `litehtml::parse_color` rejects a `nullptr` container, pass the core's container instead. The test feeds `rgba(...)`, which must parse.

- [ ] **Step 4: Record commands per element and collect nodes**

In `Sources/renderer.cpp` `Container`:
- Add the members `std::unordered_map<int64_t, DisplayList> node_lists_;` and `std::vector<mwc_layout_node> nodes_;` (include `MessageWidgetCore/MessageWidgetCore.h` and `paint_properties.h`).
- Add the helper

  ```cpp
      /// The node a drawing callback belongs to: the render item it arrived with (the fork's token),
      /// its element, the nearest element carrying a node id. 0 when none.
      int64_t owner_of(litehtml::uint_ptr hdc) const {
          auto* ri = reinterpret_cast<litehtml::render_item*>(hdc);
          if (!ri || !ri->src_el()) return 0;
          return widget_id(ri->src_el(), nullptr);
      }
      void push(litehtml::uint_ptr hdc, Command&& c) {
          int64_t id = owner_of(hdc);
          if (id) node_lists_[id].push_back(c);
          list_.push_back(std::move(c));
      }
  ```

- In every drawing callback, name the `hdc` parameter and replace `list_.push_back(std::move(c))` (and the `l` / underline pushes in `draw_text`) with `push(hdc, std::move(c))`. This covers `draw_text`, `draw_list_marker`, `draw_image`, `draw_solid_fill`, the three gradients and the two strip/stroke pushes in `draw_borders`. `set_clip` and `del_clip` keep pushing to `list_` only: layers clip with masks, not commands.
- At the end of `build()`, after `elements_` is filled, record and collect:

  ```cpp
          node_lists_.clear();
          list_.clear();
          litehtml::position clip(0, 0, litehtml::pixel_t(float(r_.width_)), litehtml::pixel_t(1e6f));
          doc_->draw(0, 0, 0, &clip);
          list_.clear();
          collect_nodes();
  ```

- Add `collect_nodes()`:

  ```cpp
      void collect_nodes() {
          nodes_.clear();
          if (!doc_ || !doc_->root()) return;
          std::function<void(const litehtml::element::ptr&, int64_t)> walk = [&](const litehtml::element::ptr& el, int64_t parent) {
              int64_t here = parent;
              if (el->get_render_item() && el->css().get_display() != litehtml::display_none) {
                  if (const char* a = el->get_attr("data-twid")) {
                      mwc_layout_node n{};
                      n.id = std::strtoll(a, nullptr, 10);
                      n.parent_id = parent;
                      Rect r = border_box_of(el);
                      n.x = r.x; n.y = r.y; n.width = r.w; n.height = r.h;
                      const auto& css = el->css();
                      n.opacity = parse_opacity(css.get_opacity_tokens());
                      n.has_transform = parse_transform(css.get_transform_tokens(), n.transform) ? 1 : 0;
                      Shadow s;
                      if (parse_box_shadow(css.get_box_shadow_tokens(), s)) {
                          n.has_shadow = 1;
                          n.shadow_x = s.x; n.shadow_y = s.y; n.shadow_blur = s.blur; n.shadow_spread = s.spread; n.shadow_argb = s.argb;
                      }
                      n.clips = css.get_overflow() > litehtml::overflow_visible ? 1 : 0;
                      auto radii = css.get_borders().radius.calc_percents(litehtml::pixel_t(r.w), litehtml::pixel_t(r.h));
                      const float q[8] = {float(radii.top_left_x), float(radii.top_left_y), float(radii.top_right_x), float(radii.top_right_y),
                                          float(radii.bottom_right_x), float(radii.bottom_right_y), float(radii.bottom_left_x), float(radii.bottom_left_y)};
                      for (int i = 0; i < 8; i++) n.radii[i] = q[i];
                      n.z_index = el->is_positioned() && !css.get_z_index().is_predefined() ? int32_t(css.get_z_index().val()) : 0;
                      nodes_.push_back(n);
                      here = n.id;
                  }
              } else if (el->get_attr("data-twid")) {
                  return;  // display:none — nothing below it is rendered
              }
              for (auto& child : el->children()) walk(child, here);
          };
          walk(doc_->root(), 0);
      }
      const std::vector<mwc_layout_node>& nodes() const { return nodes_; }
      const DisplayList* commands_of(int64_t id) const {
          auto it = node_lists_.find(id);
          return it == node_lists_.end() ? nullptr : &it->second;
      }
  ```

  If `css_borders::radius` or `calc_percents` is named differently in this litehtml, use the expression `render_item::draw_children` uses (`src_el()->css().get_borders().radius.calc_percents(...)`). It is in the same file.
- `Renderer` gains:

  ```cpp
  const std::vector<mwc_layout_node>& Renderer::layout_nodes() const { return container_->nodes(); }
  void Renderer::draw_node(int64_t id, CGContextRef ctx, CGBackend& backend) const {
      const DisplayList* list = container_->commands_of(id);
      if (!list) return;
      for (const auto& n : container_->nodes()) {
          if (n.id == id) { backend.paint_into(*list, ctx, n.x, n.y); return; }
      }
  }
  ```

  Declare both in `renderer.h`; include `<CoreGraphics/CoreGraphics.h>` and forward-declare `class CGBackend;` there.

- [ ] **Step 5: Add the C API functions to `mwc.cpp`**

```cpp
size_t mwc_layout_nodes(mwc_core* core, const mwc_layout_node** out) {
    return guarded<size_t>(core, 0, "layout_nodes", [&](mwc_core& h) {
        const auto& nodes = h.renderer->layout_nodes();
        if (out) *out = nodes.data();
        return nodes.size();
    });
}

void mwc_draw_node(mwc_core* core, int64_t id, CGContextRef ctx) {
    if (!ctx) return;
    guarded<int>(core, 0, "draw_node", [&](mwc_core& h) {
        h.renderer->draw_node(id, ctx, *h.backend);
        return 0;
    });
}
```

- [ ] **Step 6: Run the tests**

Run: `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore:all --test_output=errors`
Expected: `MessageWidgetCoreTests` and `MessageWidgetLayoutTests` both PASS.

- [ ] **Step 7: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore
git commit -m "MessageWidgetCore: per-element command lists, layout nodes with paint properties, node drawing"
```

---

### Task 7: MessageWidget — vendored bundles, executor, QuickJS wrapper, validator

**Files:**
- Create: `third-party/widget-sandbox/{BUILD,VENDOR.md}`, `third-party/widget-sandbox/WidgetJS/**`, `third-party/widget-sandbox/corpus/attacks/**`
- Create:
  - `submodules/TelegramUI/Components/MessageWidget/MessageWidget/{BUILD,PROVENANCE.md}`
  - `Sources/{JSThread,QuickJSContext,MessageWidgetExecutor,MessageWidgetResources,CpuBudget,TrustedValidator}.swift`
- Test: `MessageWidget/Tests/{TestSupport,ExecutorAndValidatorTests}.swift`

**Interfaces:**
- Consumes: `CQuickJS` (Task 1).
- Produces:
  - `MessageWidgetExecutor`: `Mode` (`.mainThread` / `.dedicatedThread`), `shared`, `jsStackLimit`, `mainThreadHeadroom`, `mainThreadStackSize()`, `preferredMode()`, `init(mode:)`, `isCurrent`, `sync<T>(_:)`, `after(_:_:) -> Scheduled`, and `Scheduled.cancel()`.
  - `MessageWidgetResources`: `shared` (`MessageWidgetResources?`), `init?(bundle:)`, `sandboxBundle`, `sandboxBytecode`, `validatorBundle`, `validatorBytecode`, `library(for:)`, `librarySource(_:)`, `libraryBytecode(_:)`.
  - `QuickJSContext(memoryLimitBytes:maxStackBytes:)`, as in widget-sandbox.
  - `TrustedValidator(theme:resources:executor:onDiag:) throws`, with `processOps`, `validateQuery`, `validateListen`, `validatePreventDefault`, `setTheme`, `rewriteMediaQuery` and `nodeCount`.

- [ ] **Step 1: Vendor the built artifacts**

```bash
W=~/build/widget-sandbox
T=third-party/widget-sandbox
mkdir -p $T/WidgetJS/libs $T/corpus
cp $W/packages/ios/Sources/WidgetSandbox/WidgetJS/{sandbox-bundle.js,sandbox-bundle.qbc,validator-bundle.js,validator-bundle.qbc,libraries.json} $T/WidgetJS/
cp $W/packages/ios/Sources/WidgetSandbox/WidgetJS/libs/* $T/WidgetJS/libs/
cp -R $W/corpus/attacks $T/corpus/attacks
```

Each `.js` is copied together with its `.qbc` in this one step. A `.qbc` from a different build is refused at load time, and the bytecode test then fails for the wrong reason.

`third-party/widget-sandbox/VENDOR.md`:

```markdown
# widget-sandbox artifacts (vendored)

Built output of ~/build/widget-sandbox at commit 862eec8 (`pnpm build:ios`), not its sources:
- WidgetJS/sandbox-bundle.{js,qbc} — the DOM shim (linkedom) that widget JS runs against
- WidgetJS/validator-bundle.{js,qbc} — the trusted validator / CSS sanitizer / URL policy
- WidgetJS/libraries.json + libs/ — Chart.js 4 and D3 7, substituted for their CDN URLs
- corpus/attacks/ — the exfiltration corpus, TEST FIXTURES ONLY (never in the app bundle)

The renderer bundle is not vendored (no WKWebView). Every `.js` must travel with the `.qbc` of
the same build: a mismatched blob is refused at load time and the bundle is evaluated from
source (slower, and `MessageWidgetTests` fails). The `.qbc` were compiled by quickjs-ng 0.17.0,
the version in third-party/quickjs-ng. A change to the shim or validator is made in
widget-sandbox and re-vendored as a whole.
```

`third-party/widget-sandbox/BUILD`:

```python
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

filegroup(
    name = "WidgetJSFiles",
    srcs = glob(["WidgetJS/**"]),
)

plist_fragment(
    name = "WidgetSandboxJSInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WidgetSandboxJS</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WidgetSandboxJS</string>
    """
)

# Flat: every file lands at the bundle root (the names do not collide); the loader looks up by name.
apple_resource_bundle(
    name = "WidgetSandboxJS",
    infoplists = [":WidgetSandboxJSInfoPlist"],
    resources = [":WidgetJSFiles"],
    visibility = ["//visibility:public"],
)

filegroup(
    name = "AttackCorpus",
    testonly = True,
    srcs = glob(["corpus/attacks/**"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)
```

- [ ] **Step 2: Port the Swift files**

```bash
P=~/build/widget-sandbox/packages/ios/Sources/WidgetSandbox
M=submodules/TelegramUI/Components/MessageWidget/MessageWidget
mkdir -p $M/Sources $M/Tests
cp $P/JSThread.swift $P/QuickJS.swift $P/CpuBudget.swift $M/Sources/
mv $M/Sources/QuickJS.swift $M/Sources/QuickJSContext.swift
```

Edits:
- `QuickJSContext.swift`: change the type declarations to internal (drop `public` from `QuickJSError`, `HostReturn`, `JSResult`, `QuickJSContext` and its members). Keep everything else verbatim.
- `JSThread.swift`: drop `public` everywhere. Remove `jsStackLimit`; it now lives in `MessageWidgetExecutor`.
- `CpuBudget.swift`: drop `public`. Keep the rest verbatim.

`PROVENANCE.md`:

```markdown
# MessageWidget provenance

Ported from widget-sandbox packages/ios/Sources/WidgetSandbox (commit 862eec8):
- JSThread.swift, QuickJSContext.swift (was QuickJS.swift), CpuBudget.swift — verbatim, made internal
- TrustedValidator.swift — runs on MessageWidgetExecutor instead of its own JSThread; no pools
- MessageWidgetEngine.swift (was SandboxEngine.swift) — synchronous entry points through
  MessageWidgetExecutor, timers on the main run loop in .common modes, task hooks; no prewarm
- IntlBridge.swift — split out of SandboxEngine.swift, verbatim
- MessageWidgetResources.swift (was SandboxResources in SandboxEngine.swift) — flat resource
  bundle WidgetSandboxJS.bundle, optional `shared`

New here: MessageWidgetExecutor, WidgetCore, MessageWidgetInstance, MessageWidgetView,
MessageWidgetRegistry. This copy is ours: edit it here.
```

- [ ] **Step 3: Write `Sources/MessageWidgetExecutor.swift`**

```swift
import Foundation

/// Where widget JavaScript runs. A message widget's JS and layout run synchronously in the
/// bubble's layout pass, so its height is known there. QuickJS detects overflow against a limit
/// counted from where JS is entered; the real stack below that point must be larger, or deep
/// recursion crashes the app instead of throwing a catchable RangeError. When the main thread's
/// stack is big enough (the app raises it with `-stack_size`, Telegram/BUILD), JS runs inline on
/// main. Otherwise every entry runs on one dedicated 8 MB thread while the main thread waits:
/// still synchronous for the caller, and deadlock-free because JS never waits on main.
public final class MessageWidgetExecutor {
    public enum Mode: Equatable {
        case mainThread
        case dedicatedThread
    }

    /// QuickJS stack limit for every runtime, widget and validator alike.
    public static let jsStackLimit: Int = 2 << 20
    /// Stack the main thread must have beyond the limit: UIKit, the list and the layout pass sit above the entry.
    public static let mainThreadHeadroom: Int = 2 << 20

    public static let shared = MessageWidgetExecutor(mode: MessageWidgetExecutor.preferredMode())

    public static func mainThreadStackSize() -> Int {
        return Int(pthread_get_stacksize_np(pthread_main_thread_np()))
    }

    public static func preferredMode() -> Mode {
        return mainThreadStackSize() >= jsStackLimit + mainThreadHeadroom ? .mainThread : .dedicatedThread
    }

    public let mode: Mode
    private let thread: JSThread?

    public init(mode: Mode) {
        self.mode = mode
        self.thread = mode == .dedicatedThread ? JSThread(name: "message-widget.js") : nil
    }

    deinit {
        self.thread?.stop()
    }

    /// True on the thread that runs widget JS.
    public var isCurrent: Bool {
        if let thread = self.thread {
            return thread.isCurrent
        }
        return Thread.isMainThread
    }

    /// Runs `body` where JS runs and returns its result. Called on the main thread, or from inside
    /// another `sync` body (then inline).
    public func sync<T>(_ body: @escaping () -> T) -> T {
        if self.isCurrent {
            return body()
        }
        precondition(Thread.isMainThread, "MessageWidgetExecutor.sync from a thread that is neither main nor the JS thread")
        return self.thread!.sync(body)
    }

    public final class Scheduled {
        fileprivate var timer: Timer?
        fileprivate var cancelled = false

        /// Safe from the JS thread; the block will not run after this returns.
        public func cancel() {
            self.cancelled = true
            if Thread.isMainThread {
                self.timer?.invalidate()
                self.timer = nil
            }
        }
    }

    /// Runs `block` through `sync` after `delay`, from a main-run-loop timer in the common modes so it
    /// keeps firing while a list scrolls. Callable from the JS thread (CFRunLoopAddTimer is thread-safe).
    public func after(_ delay: TimeInterval, _ block: @escaping () -> Void) -> Scheduled {
        let handle = Scheduled()
        let timer = Timer(timeInterval: max(0.0, delay), repeats: false, block: { [weak self, weak handle] _ in
            guard let self, let handle, !handle.cancelled else {
                return
            }
            handle.timer = nil
            self.sync(block)
        })
        handle.timer = timer
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
        return handle
    }
}
```

- [ ] **Step 4: Write `Sources/MessageWidgetResources.swift`**

Port `SandboxResources` and `BundledLibrary` from widget-sandbox's `SandboxEngine.swift` (from `public struct BundledLibrary` to the end of `SandboxResources`). Changes:
- Rename `SandboxResources` to `MessageWidgetResources`.
- Remove `rendererBundle`.
- `init?(bundle: Bundle)` returns nil instead of calling `fatalError` when a bundle file is missing.
- Look files up at the bundle root: `bundle.url(forResource: name, withExtension: ext)`, with no `subdirectory:`. That applies to `libraries.json`, the bundles and `libs` files. `libraries.json`'s `file` value is used as-is.
- Replace `shared` with:

```swift
    /// The resource bundle vendored from widget-sandbox (third-party/widget-sandbox), or nil when it
    /// is missing — callers then draw the block as code instead of running a widget.
    public static let shared: MessageWidgetResources? = {
        let outer = Bundle(for: MessageWidgetResources.self)
        guard let inner = Bundle(path: outer.bundlePath + "/WidgetSandboxJS.bundle") else {
            return nil
        }
        return MessageWidgetResources(bundle: inner)
    }()
```

The public surface is the five properties and three methods named in this task's Interfaces.

- [ ] **Step 5: Write `Sources/TrustedValidator.swift`**

Port widget-sandbox's `TrustedValidator.swift` with these changes:
- `final class TrustedValidator` (internal). Delete `sharedThread`, `background(...)`, `reset(theme:)`, `perform(_:)` and `ownsThread`.
- Replace `thread: JSThread` with `private let executor: MessageWidgetExecutor`.
- The initializer:

  ```swift
      init(theme: String, resources: MessageWidgetResources, executor: MessageWidgetExecutor, onDiag: @escaping (String, String) -> Void) throws {
          self.executor = executor
          self.onDiag = onDiag
          try executor.sync { Result { try self.build(theme: theme, resources: resources) } }.get()
      }
  ```

- In `build`, change `maxStackBytes: JSThread.jsStackLimit` to `maxStackBytes: MessageWidgetExecutor.jsStackLimit`.
- In `str(_:_:)` and `nodeCount`, change `thread.sync` to `executor.sync`.
- Delete `deinit`; there is no thread to stop.

- [ ] **Step 6: Write `Tests/TestSupport.swift` and the failing `Tests/ExecutorAndValidatorTests.swift`**

```swift
import XCTest
@testable import MessageWidget

/// Every MessageWidget test class runs in both executor modes: the subclass overrides `mode`.
class MessageWidgetTestCase: XCTestCase {
    class var mode: MessageWidgetExecutor.Mode { return .mainThread }

    private(set) var executor: MessageWidgetExecutor!

    override func setUp() {
        super.setUp()
        self.executor = MessageWidgetExecutor(mode: type(of: self).mode)
    }

    var resources: MessageWidgetResources {
        guard let resources = MessageWidgetResources.shared else {
            XCTFail("WidgetSandboxJS.bundle is missing from the test bundle")
            fatalError()
        }
        return resources
    }

    func fixture(_ name: String, ext: String = "html") -> String {
        let bundle = Bundle(for: MessageWidgetTestCase.self)
        guard let url = bundle.url(forResource: name, withExtension: ext), let text = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("missing fixture \(name).\(ext)")
            return ""
        }
        return text
    }

    /// Lets main-run-loop timers and deferred main-queue work run.
    func pump(_ seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Skips main-thread-mode tests that need a stack the test process's main thread lacks.
    func skipIfMainStackTooSmall() throws {
        if type(of: self).mode == .mainThread {
            try XCTSkipIf(MessageWidgetExecutor.mainThreadStackSize() < MessageWidgetExecutor.jsStackLimit + MessageWidgetExecutor.mainThreadHeadroom,
                          "main thread stack \(MessageWidgetExecutor.mainThreadStackSize()) too small for main-thread mode")
        }
    }
}
```

```swift
import XCTest
@testable import MessageWidget

class ExecutorAndValidatorTests: MessageWidgetTestCase {
    func testResourcesLoadWithBytecode() {
        let r = self.resources
        XCTAssertFalse(r.sandboxBundle.isEmpty)
        XCTAssertFalse(r.validatorBundle.isEmpty)
        XCTAssertNotNil(r.sandboxBytecode)
        XCTAssertNotNil(r.validatorBytecode)
        XCTAssertNotNil(r.library(for: "https://cdn.jsdelivr.net/npm/chart.js"))
    }

    func testSyncRunsOnTheExecutorThread() {
        let onExecutor = self.executor.sync { self.executor.isCurrent }
        XCTAssertTrue(onExecutor)
        XCTAssertEqual(self.executor.sync { 6 * 7 }, 42)
    }

    func testAfterFiresOnTheExecutorAndCancelStopsIt() {
        var fired = 0
        _ = self.executor.after(0.05) { fired += 1 }
        let cancelled = self.executor.after(0.05) { fired += 100 }
        cancelled.cancel()
        self.pump(0.3)
        XCTAssertEqual(fired, 1)
    }

    func testValidatorBuildsFromBytecodeAndValidatesOps() throws {
        var diags: [(String, String)] = []
        let validator = try TrustedValidator(theme: "light", resources: self.resources, executor: self.executor, onDiag: { diags.append(($0, $1)) })
        XCTAssertFalse(diags.contains { $0.0 == "bytecode" }, "validator fell back to source: \(diags)")
        let ops = """
        [{"op":"el","id":2,"tag":"html"},{"op":"el","id":3,"tag":"img","attrs":{"src":"https://example.com/x.png"}},
         {"op":"ins","parent":1,"id":2,"before":null},{"op":"ins","parent":2,"id":3,"before":null}]
        """
        let clean = validator.processOps(ops)
        XCTAssertNotEqual(clean, "[]")
        XCTAssertFalse(clean.contains("example.com"), "an external URL survived validation: \(clean)")
    }

    func testDeepRecursionThrowsRangeError() throws {
        try self.skipIfMainStackTooSmall()
        let thrown: String? = self.executor.sync {
            let js = QuickJSContext(memoryLimitBytes: 64 << 20, maxStackBytes: MessageWidgetExecutor.jsStackLimit)
            do {
                try js.evaluate("function f(n) { return f(n + 1) + 1; } f(0)", filename: "r.js")
                return nil
            } catch {
                return "\(error)"
            }
        }
        XCTAssertNotNil(thrown)
        XCTAssertTrue(thrown?.contains("RangeError") ?? false, "\(thrown ?? "nil")")
    }
}

final class ExecutorAndValidatorDedicatedThreadTests: ExecutorAndValidatorTests {
    override class var mode: MessageWidgetExecutor.Mode { return .dedicatedThread }
}
```

- [ ] **Step 7: Write `MessageWidget/BUILD`**

```python
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

swift_library(
    name = "MessageWidget",
    module_name = "MessageWidget",
    srcs = glob(["Sources/**/*.swift"]),
    copts = ["-warnings-as-errors"],
    data = ["//third-party/widget-sandbox:WidgetSandboxJS"],
    deps = [
        "//third-party/quickjs-ng:CQuickJS",
        "//submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore",
    ],
    visibility = ["//visibility:public"],
)

swift_library(
    name = "MessageWidgetTestsLib",
    testonly = True,
    srcs = glob(["Tests/**/*.swift"]),
    deps = [":MessageWidget"],
)

ios_test_runner(
    name = "MessageWidgetTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "MessageWidgetTests",
    minimum_os_version = "15.0",
    runner = ":MessageWidgetTestRunner",
    resources = [
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:WidgetFixtures",
        "//third-party/widget-sandbox:AttackCorpus",
    ],
    deps = [":MessageWidgetTestsLib"],
    visibility = ["//visibility:public"],
)
```

- [ ] **Step 8: Run the tests**

Run (controller): the iOS unit test command with `--target //submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests`
Expected: PASS for both classes. `testDeepRecursionThrowsRangeError` may be skipped in main-thread mode, and it must not crash.
- If `testResourcesLoadWithBytecode` fails because the bundle is missing, check where rules_apple put `WidgetSandboxJS.bundle` inside the `.xctest`: unzip the test bundle and look. Adjust `MessageWidgetResources.shared` to that location; the HlsBundle precedent puts it at the root of the bundle containing the code.
- Make sure the test really started: a failed bundle prints green.

- [ ] **Step 9: Commit**

```bash
git add third-party/widget-sandbox submodules/TelegramUI/Components/MessageWidget/MessageWidget
git commit -m "MessageWidget: vendored widget-sandbox bundles, executor with main/dedicated modes, QuickJS and validator"
```

---

### Task 8: MessageWidgetEngine — the sandbox engine on the executor

**Files:**
- Create: `MessageWidget/Sources/MessageWidgetEngine.swift`, `MessageWidget/Sources/IntlBridge.swift`
- Test: `MessageWidget/Tests/EngineTests.swift`

**Interfaces:**
- Consumes: `MessageWidgetExecutor`, `MessageWidgetResources`, `QuickJSContext`, `CpuBudget` (Task 7).
- Produces (all internal):
  - `struct SandboxConfig`, as in widget-sandbox;
  - `struct SandboxStats`;
  - `protocol MessageWidgetEngineDelegate: AnyObject` with the delegate calls listed in Step 1;
  - `final class MessageWidgetEngine` with:
    - `init(html: String, config: SandboxConfig, executor: MessageWidgetExecutor, resources: MessageWidgetResources)`;
    - `weak var delegate`;
    - `func boot()`, `event(json:)`, `frame(time:)`, `viewport(innerWidth:innerHeight:dpr:)`, `resize(entriesJson:)`, `theme(_:)`, `setVisible(_:)`, `terminate()`;
    - `var isDead: Bool`;
    - `func evaluateForTesting(_ code: String) -> String?`.

  Every entry point is synchronous: it runs inside `executor.sync` and returns after the task.

- [ ] **Step 1: Port `SandboxEngine.swift` to `MessageWidgetEngine.swift`**

```bash
P=~/build/widget-sandbox/packages/ios/Sources/WidgetSandbox
M=submodules/TelegramUI/Components/MessageWidget/MessageWidget/Sources
cp $P/SandboxEngine.swift $M/MessageWidgetEngine.swift
```

Then, in `MessageWidgetEngine.swift`:
1. Move `enum IntlBridge` (with its `style` helper) verbatim to `IntlBridge.swift`, and change its call to `MessageWidgetEngine.parse`.
2. Delete `BundledLibrary` and `SandboxResources`; they now live in `MessageWidgetResources.swift`.
3. Drop `public` everywhere. Rename `SandboxEngineDelegate` to `MessageWidgetEngineDelegate` and `SandboxEngine` to `MessageWidgetEngine` (`final class`). Rename the delegate methods' first parameter type accordingly.
4. In the delegate protocol, remove `engineLoaded` and `engine(_:stats:)`, and add:

   ```swift
       /// A task (boot, event, timer, frame, …) is about to run JS / has finished; on the JS thread.
       func engineWillStartTask(_ engine: MessageWidgetEngine, kind: String)
       func engineDidFinishTask(_ engine: MessageWidgetEngine, kind: String)
   ```

   Delete the corresponding calls:
   - `delegate?.engineLoaded(self)` in boot;
   - the `delegate?.engine(self, stats:)` calls, along with `postStats`, `trailingStats` and `lastStatsPost`. Keep counting into `stats`, since the instance doesn't read it.
5. Replace `public let queue = JSThread(name: "widget.sandbox")` with `let executor: MessageWidgetExecutor`. The types of `timers`, `wakeTimer` and `trailingStats` become `MessageWidgetExecutor.Scheduled`.
6. Replace both initializers with:

   ```swift
       init(html: String, config: SandboxConfig, executor: MessageWidgetExecutor, resources: MessageWidgetResources) {
           self.html = html
           self.config = config
           self.executor = executor
           self.resources = resources
           self.visible = config.visible
           self.budget = CpuBudget(config: config)
       }
   ```

   Delete `deinit`, `prewarm()`, `isPrewarmed`, `start()`, `start(html:config:)`, `prewarmed` and `prewarmRequested`.
7. Make the public entry points synchronous:

   ```swift
       func boot() { self.executor.sync { self.bootNow() } }
       func terminate() { self.executor.sync { self.kill("terminated") } }
       var isDead: Bool { return self.executor.sync { self.dead } }
   ```

   Rename the old private `boot()` to `bootNow()`. In `setVisible` and `enqueue`, replace `queue.async {` with `self.executor.sync {`. In `scheduleWake`, the `timer` host call and anywhere else, replace `queue.after(` with `self.executor.after(`.
8. In `createRuntime`, change `maxStackBytes: JSThread.jsStackLimit` to `maxStackBytes: MessageWidgetExecutor.jsStackLimit`.
9. In `task(_:sliceMs:_:)`, call `self.delegate?.engineWillStartTask(self, kind: kind)` as its first statement after the `dead` guard, and `self.delegate?.engineDidFinishTask(self, kind: kind)` as its last statement. Remove the `postStats(force:)` call.
10. Add the test hook:

    ```swift
        /// Tests only: evaluates `code` in the widget's context as one event-kind task and returns its
        /// string result (JSON.stringify inside `code` for objects).
        func evaluateForTesting(_ code: String) -> String? {
            return self.executor.sync {
                var result: String?
                self.task("event", sliceMs: self.config.cpuLimitMs) {
                    do {
                        result = try self.js.evaluate(code, filename: "test-eval.js").string
                    } catch {
                        self.handleError(error, where: "test-eval")
                    }
                }
                return result
            }
        }
    ```

11. Change `resources: SandboxResources` to `resources: MessageWidgetResources`.

- [ ] **Step 2: Write the failing tests `Tests/EngineTests.swift`**

```swift
import XCTest
@testable import MessageWidget

private final class RecordingDelegate: MessageWidgetEngineDelegate {
    var ops: [String] = []
    var diags: [(String, String)] = []
    var died: String?
    var frames = 0
    var tasks: [String] = []
    var depth = 0

    func engine(_ engine: MessageWidgetEngine, ops json: String) { self.ops.append(json) }
    func engine(_ engine: MessageWidgetEngine, query json: String) -> (json: String, binary: Data?) {
        if json.contains("\"rect\"") || json.contains("\"box\"") {
            return ("{\"x\":0,\"y\":0,\"width\":100,\"height\":20,\"top\":0,\"left\":0,\"right\":100,\"bottom\":20}", nil)
        }
        return ("{}", nil)
    }
    func engine(_ engine: MessageWidgetEngine, listen json: String) {}
    func engine(_ engine: MessageWidgetEngine, preventDefault json: String) {}
    func engineRequestsFrame(_ engine: MessageWidgetEngine) { self.frames += 1 }
    func engine(_ engine: MessageWidgetEngine, log level: String, text: String) {}
    func engine(_ engine: MessageWidgetEngine, diag kind: String, detail: String) { self.diags.append((kind, detail)) }
    func engine(_ engine: MessageWidgetEngine, bridge method: String, argsJson: String) {}
    func engine(_ engine: MessageWidgetEngine, died reason: String) { self.died = reason }
    func engineWillStartTask(_ engine: MessageWidgetEngine, kind: String) { self.depth += 1; XCTAssertEqual(self.depth, 1, "tasks must not nest") }
    func engineDidFinishTask(_ engine: MessageWidgetEngine, kind: String) { self.depth -= 1; self.tasks.append(kind) }
}

class EngineTests: MessageWidgetTestCase {
    private func makeEngine(_ html: String) -> (MessageWidgetEngine, RecordingDelegate) {
        var config = SandboxConfig(innerWidth: 360, innerHeight: 300, devicePixelRatio: 3, theme: "light")
        config.cpuLimitMs = 500
        let engine = MessageWidgetEngine(html: html, config: config, executor: self.executor, resources: self.resources)
        let delegate = RecordingDelegate()
        engine.delegate = delegate
        return (engine, delegate)
    }

    func testBootIsSynchronousAndUsesBytecode() throws {
        try self.skipIfMainStackTooSmall()
        let (engine, delegate) = self.makeEngine(self.fixture("02-split-bill"))
        engine.boot()
        XCTAssertFalse(delegate.ops.isEmpty, "boot returned before the widget's ops were flushed")
        XCTAssertTrue(delegate.tasks.contains("boot"))
        XCTAssertFalse(delegate.diags.contains { $0.0 == "bytecode" }, "\(delegate.diags)")
        XCTAssertTrue(delegate.diags.contains { $0.0 == "boot" && $0.1.contains("bytecode") }, "\(delegate.diags)")
        XCTAssertEqual(engine.evaluateForTesting("document.getElementById('each').textContent"), "€42.72")
    }

    func testIntervalFiresFromTheMainRunLoop() throws {
        try self.skipIfMainStackTooSmall()
        let (engine, delegate) = self.makeEngine(self.fixture("05-countdown"))
        engine.boot()
        let before = delegate.tasks.filter { $0 == "timer" }.count
        self.pump(1.3)
        XCTAssertGreaterThan(delegate.tasks.filter { $0 == "timer" }.count, before)
        XCTAssertNil(delegate.died)
    }

    func testRunawayTaskIsKilled() throws {
        try self.skipIfMainStackTooSmall()
        let (engine, delegate) = self.makeEngine("<button id=b onclick='for(;;){}'>x</button>")
        engine.boot()
        _ = engine.evaluateForTesting("document.getElementById('b').click(); 'clicked'")
        XCTAssertNotNil(delegate.died)
        XCTAssertTrue(delegate.died?.contains("CPU limit") ?? false, "\(delegate.died ?? "nil")")
        XCTAssertTrue(engine.isDead)
    }

    func testRequestAnimationFrameAsksTheHost() throws {
        try self.skipIfMainStackTooSmall()
        let (engine, delegate) = self.makeEngine("<script>requestAnimationFrame(function(){})</script>")
        engine.boot()
        XCTAssertGreaterThan(delegate.frames, 0)
    }
}

final class EngineDedicatedThreadTests: EngineTests {
    override class var mode: MessageWidgetExecutor.Mode { return .dedicatedThread }
}
```

`€42.72` is 148.60 × 1.15 / 4, example 02's initial state.

- [ ] **Step 3: Run the tests**

Run (controller): the iOS unit test command with `--target //submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests`
Expected: `EngineTests` and `EngineDedicatedThreadTests` PASS, along with Task 7's tests.

- [ ] **Step 4: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget/MessageWidget
git commit -m "MessageWidget: the sandbox engine on the widget executor with synchronous tasks"
```

---

### Task 9: MessageWidgetInstance — one widget: engine + validator + core

**Files:**
- Create: `MessageWidget/Sources/WidgetCore.swift`, `MessageWidget/Sources/MessageWidgetInstance.swift`
- Test: `MessageWidget/Tests/InstanceTests.swift`

**Interfaces:**
- Consumes: `MessageWidgetEngine` (Task 8), `TrustedValidator`, `MessageWidgetExecutor` (Task 7), and the `mwc_*` C API (Tasks 5–6).
- Produces:

```swift
final class WidgetCore {                                  // internal
    init?(width: Double, dpr: Double, dark: Bool)
    func receive(_ json: String) -> [[String: Any]]
    func setWidth(_ width: Double) -> [[String: Any]]
    func setTheme(dark: Bool) -> [[String: Any]]
    func touch(action: Int32, x: Double, y: Double, pointer: Int32, primary: Bool) -> [[String: Any]]
    var documentHeight: CGFloat { get }
    var generation: UInt64 { get }
    var networkRefusals: Int { get }
    var html: String { get }
    func nodes() -> [mwc_layout_node]
    func drawNode(_ id: Int64, in ctx: CGContext)
}

public final class MessageWidgetInstance {
    public enum Theme: Equatable { case light, dark }
    public enum BridgeCall: Equatable { case sendMessage(String), openLink(String) }
    public init?(source: String, theme: Theme, stoppedLabel: String, maxMessageLength: Int,
                 executor: MessageWidgetExecutor = .shared, resources: MessageWidgetResources? = .shared)
    public private(set) var layoutVersion: Int
    public private(set) var deadReason: String?
    public private(set) var lastError: String?
    public private(set) var failedToStart: Bool         // core or validator could not be created → draw as code
    public var onLayoutChange: (() -> Void)?            // delivered async on main after a task changed the height
    public var onBridge: ((BridgeCall) -> Void)?       // delivered async on main after the task
    public func layout(width: CGFloat) -> CGSize      // boots on first call; synchronous; main thread
    public var view: MessageWidgetView { get }          // Task 10
    public func setTheme(_ theme: Theme)
    public func setVisible(_ visible: Bool)
    public func destroy()
    // internal:
    let core: WidgetCore?
    var diagnostics: [(kind: String, detail: String)] { get }
    func touch(action: Int32, at point: CGPoint, pointer: Int32, primary: Bool)
    func evaluateForTesting(_ code: String) -> String?
}
```

- [ ] **Step 1: Write the failing tests `Tests/InstanceTests.swift`**

```swift
import XCTest
@testable import MessageWidget

class InstanceTests: MessageWidgetTestCase {
    func make(_ source: String, theme: MessageWidgetInstance.Theme = .light) -> MessageWidgetInstance {
        guard let instance = MessageWidgetInstance(source: source, theme: theme, stoppedLabel: "Widget stopped", maxMessageLength: 4096, executor: self.executor, resources: self.resources) else {
            XCTFail("instance not created")
            fatalError()
        }
        return instance
    }

    /// Taps the element matched by `selector` (a real down + up through the core's hit test).
    func tap(_ instance: MessageWidgetInstance, _ selector: String) {
        guard let json = instance.evaluateForTesting("JSON.stringify(document.querySelector(\(String(reflecting: selector))).getBoundingClientRect())"),
              let data = json.data(using: .utf8),
              let rect = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let x = rect["x"], let y = rect["y"], let w = rect["width"], let h = rect["height"] else {
            XCTFail("no rect for \(selector)")
            return
        }
        let p = CGPoint(x: x + w / 2.0, y: y + h / 2.0)
        instance.touch(action: 0, at: p, pointer: 0, primary: true)
        instance.touch(action: 2, at: p, pointer: 0, primary: true)
    }

    func testExamplesBootToAHeight() throws {
        try self.skipIfMainStackTooSmall()
        for name in ["01-weather-card", "02-split-bill", "03-faq-accordion", "04-poll", "05-countdown"] {
            let instance = self.make(self.fixture(name))
            let size = instance.layout(width: 360.0)
            XCTAssertEqual(size.width, 360.0)
            XCTAssertGreaterThan(size.height, 60.0, name)
            XCTAssertLessThanOrEqual(size.height, 900.0, name)
            XCTAssertNil(instance.deadReason, name)
            XCTAssertNil(instance.lastError, name)
            instance.destroy()
        }
    }

    func testTapChangesTextNotHeight() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("02-split-bill"))
        let before = instance.layout(width: 360.0)
        var notified = 0
        instance.onLayoutChange = { notified += 1 }
        self.tap(instance, "#plus")
        XCTAssertEqual(instance.evaluateForTesting("document.getElementById('n').textContent"), "5")
        self.pump(0.1)
        XCTAssertEqual(instance.layout(width: 360.0).height, before.height)
        XCTAssertEqual(notified, 0)
        XCTAssertEqual(instance.layoutVersion, 0)
    }

    func testTapThatGrowsTheWidgetBumpsTheVersion() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("03-faq-accordion"))
        let before = instance.layout(width: 360.0)
        let changed = self.expectation(description: "layout change")
        instance.onLayoutChange = { changed.fulfill() }
        self.tap(instance, ".q")
        self.wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(instance.layoutVersion, 1)
        XCTAssertGreaterThan(instance.layout(width: 360.0).height, before.height)
    }

    func testSendMessageOnlyFromATapAndOncePerTap() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("04-poll"))
        _ = instance.layout(width: 360.0)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.evaluateForTesting("TelegramWidget.sendMessage('spam'); 'ok'")
        self.pump(0.1)
        XCTAssertTrue(calls.isEmpty, "a script without a tap sent a message")
        XCTAssertTrue(instance.diagnostics.contains { $0.kind == "bridge-refused" })
        self.tap(instance, ".opt:nth-child(3)")
        self.tap(instance, "#send")
        self.pump(0.1)
        XCTAssertEqual(calls, [.sendMessage("My vote: Dubai")])
    }

    func testHangFreezesTheWidget() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("10-sandbox-probe"))
        _ = instance.layout(width: 360.0)
        self.tap(instance, "#hang")
        XCTAssertNotNil(instance.deadReason)
        XCTAssertTrue(instance.deadReason?.contains("CPU limit") ?? false)
        XCTAssertTrue(instance.core?.html.contains("data-tw-frozen") ?? false)
        XCTAssertTrue(instance.core?.html.contains("Widget stopped") ?? false)
    }

    func testBootErrorKeepsMinimumHeight() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make("<script>throw new Error('boom')</script>")
        XCTAssertEqual(instance.layout(width: 360.0).height, 24.0)
        XCTAssertTrue(instance.lastError?.contains("boom") ?? false, "\(instance.lastError ?? "nil")")
        XCTAssertNil(instance.deadReason)
    }

    func testWidthChangeReflowsWithoutJSAndThenTellsJS() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("01-weather-card"))
        let wide = instance.layout(width: 360.0)
        let narrow = instance.layout(width: 200.0)
        XCTAssertGreaterThanOrEqual(narrow.height, wide.height)
        self.pump(0.1)
        XCTAssertEqual(instance.evaluateForTesting("String(innerWidth)"), "200")
    }

    func testAttackCorpusRequestsNothing() throws {
        try self.skipIfMainStackTooSmall()
        let bundle = Bundle(for: MessageWidgetTestCase.self)
        let prefixes = ["api-", "css-", "markup-", "nav-", "cpu-", "fallback-", "mem-", "timer-"]
        let files = (bundle.paths(forResourcesOfType: "html", inDirectory: nil)).filter { path in
            let name = (path as NSString).lastPathComponent
            return prefixes.contains { name.hasPrefix($0) }
        }
        XCTAssertGreaterThan(files.count, 80, "attack corpus missing from the test bundle")
        for path in files {
            guard let source = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            let instance = self.make(source)
            _ = instance.layout(width: 360.0)
            self.pump(0.2)
            XCTAssertEqual(instance.core?.networkRefusals ?? -1, 0, (path as NSString).lastPathComponent)
            instance.destroy()
        }
    }
}

final class InstanceDedicatedThreadTests: InstanceTests {
    override class var mode: MessageWidgetExecutor.Mode { return .dedicatedThread }
}
```

`.opt:nth-child(3)` is Dubai: the options are `#opts`'s children in the order Lisbon, Tbilisi, Dubai, Bali.

- [ ] **Step 2: Run them to make sure they fail**

Run (controller): the iOS test command for `MessageWidgetTests`.
Expected: compile FAIL (`MessageWidgetInstance` is unknown).

- [ ] **Step 3: Write `Sources/WidgetCore.swift`**

```swift
import CoreGraphics
import Foundation
import MessageWidgetCore

/// Swift face of the C++ core (MessageWidgetCore.h). Messages come back as parsed JSON objects.
final class WidgetCore {
    private let handle: OpaquePointer

    init?(width: Double, dpr: Double, dark: Bool) {
        guard let handle = mwc_create(width, dpr, dark) else {
            return nil
        }
        self.handle = handle
    }

    deinit {
        mwc_destroy(self.handle)
    }

    private static func messages(_ raw: UnsafeMutablePointer<CChar>?) -> [[String: Any]] {
        guard let raw else {
            return []
        }
        defer { mwc_string_free(raw) }
        let data = Data(bytes: raw, count: strlen(raw))
        return (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []
    }

    func receive(_ json: String) -> [[String: Any]] {
        return WidgetCore.messages(json.withCString { mwc_receive(self.handle, $0) })
    }

    func setWidth(_ width: Double) -> [[String: Any]] {
        return WidgetCore.messages(mwc_set_width(self.handle, width))
    }

    func setTheme(dark: Bool) -> [[String: Any]] {
        return WidgetCore.messages(mwc_set_theme(self.handle, dark))
    }

    func touch(action: Int32, x: Double, y: Double, pointer: Int32, primary: Bool) -> [[String: Any]] {
        return WidgetCore.messages(mwc_touch(self.handle, action, x, y, pointer, primary))
    }

    var documentHeight: CGFloat {
        return CGFloat(mwc_document_height(self.handle))
    }

    var generation: UInt64 {
        return mwc_generation(self.handle)
    }

    var networkRefusals: Int {
        return Int(mwc_network_refusals(self.handle))
    }

    var html: String {
        guard let raw = mwc_html(self.handle) else {
            return ""
        }
        defer { mwc_string_free(raw) }
        return String(cString: raw)
    }

    func nodes() -> [mwc_layout_node] {
        var pointer: UnsafePointer<mwc_layout_node>?
        let count = mwc_layout_nodes(self.handle, &pointer)
        guard let pointer, count > 0 else {
            return []
        }
        return Array(UnsafeBufferPointer(start: pointer, count: count))
    }

    func drawNode(_ id: Int64, in ctx: CGContext) {
        mwc_draw_node(self.handle, id, ctx)
    }
}
```

If Swift imports `mwc_core *` as `OpaquePointer?` with a different shape, adjust the stored type. `mwc_create` returns `OpaquePointer?`.

- [ ] **Step 4: Write `Sources/MessageWidgetInstance.swift`**

```swift
import Foundation
import QuartzCore
import UIKit

/// One message widget: its QuickJS runtime (MessageWidgetEngine), its trusted validator and its
/// litehtml core. Everything that runs JS goes through the executor and is synchronous for the
/// caller. JS is entered from `layout(width:)` (boot, inside the bubble's layout pass), from
/// touches, and from main-run-loop timers and frames. No host callback is made while a JS task
/// runs: bridge calls and height changes are queued and delivered on the main queue after the
/// task, so a host reacting to them can never re-enter a widget mid-task.
public final class MessageWidgetInstance: MessageWidgetEngineDelegate {
    public enum Theme: Equatable {
        case light
        case dark

        var css: String { return self == .dark ? "dark" : "light" }
    }

    public enum BridgeCall: Equatable {
        case sendMessage(String)
        case openLink(String)
    }

    public private(set) var layoutVersion: Int = 0
    public private(set) var deadReason: String?
    public private(set) var lastError: String?
    /// The core or the validator could not be created: the host draws the block as code instead.
    public private(set) var failedToStart = false
    public var onLayoutChange: (() -> Void)?
    public var onBridge: ((BridgeCall) -> Void)?

    private let source: String
    private var theme: Theme
    private let stoppedLabel: String
    private let maxMessageLength: Int
    private let executor: MessageWidgetExecutor
    private let resources: MessageWidgetResources
    private(set) var core: WidgetCore?
    private var validator: TrustedValidator?
    private var engine: MessageWidgetEngine?
    private var width: CGFloat = 0.0
    private var reportedHeight: CGFloat = 24.0
    private var booted = false
    private var destroyed = false
    private var taskDepth = 0
    private var bootingInLayout = false
    /// Set while the events of one tap's touch-up are dispatched: one sendMessage, one openLink.
    private var activation: (sendMessage: Bool, openLink: Bool)?
    private var afterTaskCalls: [() -> Void] = []
    private var frameRequested = false
    private var visible = true
    private var displayLink: CADisplayLink?
    private var viewStorage: MessageWidgetView?
    private(set) var diagnostics: [(kind: String, detail: String)] = []

    public init?(source: String, theme: Theme, stoppedLabel: String, maxMessageLength: Int, executor: MessageWidgetExecutor = .shared, resources: MessageWidgetResources? = .shared) {
        guard let resources else {
            return nil
        }
        self.source = source
        self.theme = theme
        self.stoppedLabel = stoppedLabel
        self.maxMessageLength = maxMessageLength
        self.executor = executor
        self.resources = resources
    }

    deinit {
        self.displayLink?.invalidate()
    }

    // MARK: host API (main thread)

    public func layout(width: CGFloat) -> CGSize {
        dispatchPrecondition(condition: .onQueue(.main))
        guard self.assertNotInTask() else {
            return CGSize(width: width, height: self.reportedHeight)
        }
        if self.destroyed {
            return CGSize(width: width, height: self.reportedHeight)
        }
        if !self.booted {
            self.boot(width: width)
        } else if abs(width - self.width) > 0.5, let core = self.core {
            self.width = width
            self.executor.sync { _ = core.setWidth(Double(width)) }
            self.reportedHeight = core.documentHeight
            self.viewStorage?.update()
            DispatchQueue.main.async { [weak self] in
                guard let self, let engine = self.engine, !self.destroyed else {
                    return
                }
                engine.viewport(innerWidth: Double(width), innerHeight: Double(self.reportedHeight), dpr: Double(UIScreen.main.scale))
            }
        }
        return CGSize(width: width, height: self.reportedHeight)
    }

    public var view: MessageWidgetView {
        if let view = self.viewStorage {
            return view
        }
        let view = MessageWidgetView(instance: self)
        self.viewStorage = view
        view.update()
        if self.deadReason != nil {
            view.setDead()
        }
        return view
    }

    public func setTheme(_ theme: Theme) {
        guard self.theme != theme, self.assertNotInTask() else {
            return
        }
        self.theme = theme
        guard self.booted, !self.destroyed, let core = self.core, let validator = self.validator else {
            return
        }
        self.executor.sync {
            let ops = validator.setTheme(theme.css)
            if ops != "[]" {
                _ = core.receive("{\"type\":\"ops\",\"ops\":\(ops)}")
            }
            _ = core.setTheme(dark: theme == .dark)
        }
        self.noteHeightAfterHostChange()
        DispatchQueue.main.async { [weak self] in
            guard let self, let engine = self.engine, !self.destroyed else {
                return
            }
            engine.theme(theme.css)
        }
    }

    public func setVisible(_ visible: Bool) {
        guard self.visible != visible, self.assertNotInTask() else {
            return
        }
        self.visible = visible
        self.engine?.setVisible(visible)
        self.updateDisplayLink()
    }

    public func destroy() {
        if self.destroyed {
            return
        }
        self.destroyed = true
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.engine?.terminate()
        self.engine = nil
        self.validator = nil
        // The core stays: the view keeps drawing the last frame (a crossfading page view still shows it).
    }

    // MARK: internal (view, tests)

    func touch(action: Int32, at point: CGPoint, pointer: Int32, primary: Bool) {
        guard !self.destroyed, self.deadReason == nil, let core = self.core, let engine = self.engine, self.assertNotInTask() else {
            return
        }
        let messages = self.executor.sync { core.touch(action: action, x: Double(point.x), y: Double(point.y), pointer: pointer, primary: primary) }
        if action == 2 {
            self.activation = (sendMessage: true, openLink: true)
        }
        for message in messages where message["type"] as? String == "event" {
            guard let event = message["ev"], let data = try? JSONSerialization.data(withJSONObject: event), let json = String(data: data, encoding: .utf8) else {
                continue
            }
            engine.event(json: json)
            if self.deadReason != nil {
                break
            }
        }
        self.activation = nil
    }

    func evaluateForTesting(_ code: String) -> String? {
        return self.engine?.evaluateForTesting(code)
    }

    var currentWidth: CGFloat {
        return self.width
    }

    // MARK: boot and tasks

    private func boot(width: CGFloat) {
        self.booted = true
        self.width = width
        let scale = Double(UIScreen.main.scale)
        guard let core = self.executor.sync({ WidgetCore(width: Double(width), dpr: scale, dark: self.theme == .dark) }) else {
            self.diagnostics.append((kind: "core-error", detail: "mwc_create failed"))
            self.failedToStart = true
            return
        }
        self.core = core
        do {
            self.validator = try TrustedValidator(theme: self.theme.css, resources: self.resources, executor: self.executor, onDiag: { [weak self] kind, detail in
                self?.appendDiag(kind, detail)
            })
        } catch {
            self.diagnostics.append((kind: "validator-error", detail: "\(error)"))
            self.failedToStart = true
            return
        }
        var config = SandboxConfig(innerWidth: Double(width), innerHeight: 300.0, devicePixelRatio: scale, theme: self.theme.css)
        config.visible = self.visible
        let engine = MessageWidgetEngine(html: self.source, config: config, executor: self.executor, resources: self.resources)
        engine.delegate = self
        self.engine = engine
        self.bootingInLayout = true
        engine.boot()
        self.bootingInLayout = false
        self.reportedHeight = core.documentHeight
    }

    private func assertNotInTask() -> Bool {
        assert(self.taskDepth == 0, "MessageWidgetInstance entered from inside its own JS task")
        return self.taskDepth == 0
    }

    private func appendDiag(_ kind: String, _ detail: String) {
        if self.diagnostics.count < 500 {
            self.diagnostics.append((kind: kind, detail: detail))
        }
    }

    /// After a host-driven change (theme): no JS ran, so compare and notify here.
    private func noteHeightAfterHostChange() {
        guard let core = self.core else {
            return
        }
        let height = core.documentHeight
        if height != self.reportedHeight {
            self.reportedHeight = height
            self.layoutVersion += 1
            DispatchQueue.main.async { [weak self] in
                self?.onLayoutChange?()
            }
        }
        self.viewStorage?.update()
    }

    private func finishTask() {
        guard let core = self.core else {
            return
        }
        let height = core.documentHeight
        if !self.bootingInLayout && height != self.reportedHeight {
            self.reportedHeight = height
            self.layoutVersion += 1
            self.afterTaskCalls.append { [weak self] in
                self?.onLayoutChange?()
            }
        }
        let calls = self.afterTaskCalls
        self.afterTaskCalls.removeAll()
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.viewStorage?.update()
            for call in calls {
                call()
            }
        }
    }

    // MARK: MessageWidgetEngineDelegate (on the executor thread, inside a task)

    func engineWillStartTask(_ engine: MessageWidgetEngine, kind: String) {
        self.taskDepth += 1
    }

    func engineDidFinishTask(_ engine: MessageWidgetEngine, kind: String) {
        self.taskDepth -= 1
        self.finishTask()
    }

    func engine(_ engine: MessageWidgetEngine, ops json: String) {
        guard let validator = self.validator, let core = self.core else {
            return
        }
        let clean = validator.processOps(json)
        if clean != "[]" {
            for message in core.receive("{\"type\":\"ops\",\"ops\":\(clean)}") where message["type"] as? String == "violation" {
                self.appendDiag("renderer-violation", message["detail"] as? String ?? "")
            }
        }
    }

    func engine(_ engine: MessageWidgetEngine, query json: String) -> (json: String, binary: Data?) {
        guard let validator = self.validator, let core = self.core else {
            return ("{\"error\":\"dead\"}", nil)
        }
        guard var clean = validator.validateQuery(json) else {
            return ("{\"error\":\"invalid query\"}", nil)
        }
        if clean.contains("\"matchMedia\""), let data = clean.data(using: .utf8), var object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let query = object["query"] as? String {
            object["query"] = validator.rewriteMediaQuery(query)
            if let rewritten = try? JSONSerialization.data(withJSONObject: object), let text = String(data: rewritten, encoding: .utf8) {
                clean = text
            }
        }
        for message in core.receive("{\"type\":\"query\",\"qid\":1,\"query\":\(clean)}") where message["type"] as? String == "result" {
            if let result = message["result"], let data = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]), let text = String(data: data, encoding: .utf8) {
                return (text, nil)
            }
        }
        return ("{\"error\":\"no answer\"}", nil)
    }

    func engine(_ engine: MessageWidgetEngine, listen json: String) {
        guard let validator = self.validator, let core = self.core else {
            return
        }
        _ = core.receive("{\"type\":\"listen\",\"types\":\(validator.validateListen(json))}")
    }

    func engine(_ engine: MessageWidgetEngine, preventDefault json: String) {
        guard let validator = self.validator, let core = self.core else {
            return
        }
        _ = core.receive("{\"type\":\"preventDefault\",\"keys\":\(validator.validatePreventDefault(json))}")
    }

    func engineRequestsFrame(_ engine: MessageWidgetEngine) {
        self.frameRequested = true
        self.afterTaskCalls.append { [weak self] in
            self?.updateDisplayLink()
        }
    }

    func engine(_ engine: MessageWidgetEngine, log level: String, text: String) {
        if level == "error", text.hasPrefix("Uncaught ") {
            self.lastError = text
        }
    }

    func engine(_ engine: MessageWidgetEngine, diag kind: String, detail: String) {
        self.appendDiag(kind, detail)
    }

    func engine(_ engine: MessageWidgetEngine, bridge method: String, argsJson: String) {
        let args = (try? JSONSerialization.jsonObject(with: Data(argsJson.utf8), options: [.fragmentsAllowed])) as? [Any] ?? []
        let first = args.first as? String ?? ""
        switch method {
        case "sendMessage":
            guard self.activation?.sendMessage == true else {
                self.appendDiag("bridge-refused", "sendMessage outside a tap")
                return
            }
            self.activation?.sendMessage = false
            let text = String(first.prefix(self.maxMessageLength))
            guard !text.isEmpty else {
                return
            }
            self.afterTaskCalls.append { [weak self] in
                self?.onBridge?(.sendMessage(text))
            }
        case "openLink":
            guard self.activation?.openLink == true else {
                self.appendDiag("bridge-refused", "openLink outside a tap")
                return
            }
            self.activation?.openLink = false
            guard !first.isEmpty else {
                return
            }
            self.afterTaskCalls.append { [weak self] in
                self?.onBridge?(.openLink(first))
            }
        default:
            self.appendDiag("bridge-ignored", method)
        }
    }

    func engine(_ engine: MessageWidgetEngine, died reason: String) {
        if self.destroyed {
            return
        }
        self.deadReason = reason
        self.frameRequested = false
        if let core = self.core, let data = try? JSONSerialization.data(withJSONObject: ["type": "frozen", "reason": self.stoppedLabel, "fatal": true]), let json = String(data: data, encoding: .utf8) {
            _ = core.receive(json)
        }
        self.afterTaskCalls.append { [weak self] in
            self?.viewStorage?.setDead()
            self?.updateDisplayLink()
        }
    }

    // MARK: frames

    private final class DisplayLinkTarget: NSObject {
        weak var instance: MessageWidgetInstance?

        init(instance: MessageWidgetInstance) {
            self.instance = instance
            super.init()
        }

        @objc func tick(_ link: CADisplayLink) {
            self.instance?.frameTick(link)
        }
    }

    private func updateDisplayLink() {
        let wanted = self.frameRequested && self.visible && !self.destroyed && self.deadReason == nil
        if wanted, self.displayLink == nil {
            let link = CADisplayLink(target: DisplayLinkTarget(instance: self), selector: #selector(DisplayLinkTarget.tick(_:)))
            link.add(to: .main, forMode: .common)
            self.displayLink = link
        } else if !wanted, let link = self.displayLink {
            link.invalidate()
            self.displayLink = nil
        }
    }

    private func frameTick(_ link: CADisplayLink) {
        guard self.frameRequested, let engine = self.engine, self.taskDepth == 0 else {
            return
        }
        self.frameRequested = false
        engine.frame(time: CACurrentMediaTime() * 1000.0)
        self.updateDisplayLink()
    }
}
```

- [ ] **Step 5: Add a placeholder `MessageWidgetView` so this task compiles**

Create `Sources/MessageWidgetView.swift` with this minimal version. Task 10 replaces it.

```swift
import UIKit

public final class MessageWidgetView: UIView {
    weak var instance: MessageWidgetInstance?

    init(instance: MessageWidgetInstance) {
        self.instance = instance
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update() {
    }

    func setDead() {
        self.isUserInteractionEnabled = false
    }
}
```

- [ ] **Step 6: Run the tests**

Run (controller): the iOS test command for `MessageWidgetTests`.
Expected: `InstanceTests` and `InstanceDedicatedThreadTests` PASS.
- The attack scan takes a minute or two; the `cpu-*` files each run into the 500 ms limit.
- A failing attack file is a validator or container hole. Report it; don't weaken the test.

- [ ] **Step 7: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget/MessageWidget
git commit -m "MessageWidget: MessageWidgetInstance — synchronous boot in layout, tasks, tap-gated bridge, frozen state"
```

---

### Task 10: MessageWidgetView — the native layer tree

**Files:**
- Modify: `MessageWidget/Sources/MessageWidgetView.swift` (replacing the placeholder)
- Test: `MessageWidget/Tests/ViewTests.swift`

**Interfaces:**
- Consumes: `WidgetCore.nodes()`, `WidgetCore.drawNode`, `WidgetCore.generation`, and `MessageWidgetInstance.touch(action:at:pointer:primary:)`.
- Produces: `public final class MessageWidgetView: UIView` with `func update()` (internal; called by the instance) and `func setDead()`. The view's height follows the instance's layout; the owner sets the frame.

- [ ] **Step 1: Write the failing tests `Tests/ViewTests.swift`**

```swift
import XCTest
import UIKit
@testable import MessageWidget

class ViewTests: MessageWidgetTestCase {
    private func make(_ source: String) -> MessageWidgetInstance {
        return MessageWidgetInstance(source: source, theme: .light, stoppedLabel: "Widget stopped", maxMessageLength: 4096, executor: self.executor, resources: self.resources)!
    }

    private func render(_ view: UIView) -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { ctx in view.layer.render(in: ctx.cgContext) }
    }

    private func pixel(_ image: UIImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
        guard let cg = image.cgImage, let data = cg.dataProvider?.data, let bytes = CFDataGetBytePtr(data) else {
            return (0, 0, 0)
        }
        let scale = Int(image.scale)
        let offset = (y * scale) * cg.bytesPerRow + (x * scale) * 4
        return (Int(bytes[offset + 2]), Int(bytes[offset + 1]), Int(bytes[offset]))  // BGRA
    }

    func testOneLayerPerNodeAndIdentitySurvivesRelayout() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("01-weather-card"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        let nodeCount = instance.core?.nodes().count ?? 0
        XCTAssertGreaterThan(nodeCount, 10)
        XCTAssertEqual(view.nodeLayerCount, nodeCount)
        let before = view.layerIdentities()
        _ = instance.layout(width: 340.0)
        view.update()
        XCTAssertEqual(view.layerIdentities(), before)
    }

    func testDrawsTheHeroGradient() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("01-weather-card"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        let p = self.pixel(self.render(view), 20, 60)
        XCTAssertGreaterThan(p.b, 150, "hero gradient should be blue at (20, 60): \(p)")
        XCTAssertLessThan(p.r, 120)
    }

    func testDestroyedInstanceViewStillDraws() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("01-weather-card"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.update()
        instance.destroy()
        view.update()
        let p = self.pixel(self.render(view), 20, 60)
        XCTAssertGreaterThan(p.b, 150, "the last frame must stay visible after destroy: \(p)")
    }

    func testTouchesReachTheWidget() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make(self.fixture("02-split-bill"))
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        guard let json = instance.evaluateForTesting("JSON.stringify(document.getElementById('plus').getBoundingClientRect())"),
              let rect = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Double] else {
            return XCTFail("no rect")
        }
        let point = CGPoint(x: rect["x"]! + rect["width"]! / 2.0, y: rect["y"]! + rect["height"]! / 2.0)
        view.handleTouch(phase: .began, at: point)
        view.handleTouch(phase: .ended, at: point)
        XCTAssertEqual(instance.evaluateForTesting("document.getElementById('n').textContent"), "5")
    }

    func testDeadWidgetStopsTakingTouches() throws {
        try self.skipIfMainStackTooSmall()
        let instance = self.make("<button id=b onclick='for(;;){}' style='width:100px;height:40px'>x</button>")
        let size = instance.layout(width: 360.0)
        let view = instance.view
        view.frame = CGRect(origin: .zero, size: size)
        view.handleTouch(phase: .began, at: CGPoint(x: 20, y: 20))
        view.handleTouch(phase: .ended, at: CGPoint(x: 20, y: 20))
        self.pump(0.1)
        XCTAssertNotNil(instance.deadReason)
        XCTAssertFalse(view.isUserInteractionEnabled)
    }
}

final class ViewDedicatedThreadTests: ViewTests {
    override class var mode: MessageWidgetExecutor.Mode { return .dedicatedThread }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Expected: compile FAIL (`nodeLayerCount`, `layerIdentities` and `handleTouch` don't exist yet).

- [ ] **Step 3: Write `Sources/MessageWidgetView.swift`**

```swift
import MessageWidgetCore
import QuartzCore
import UIKit

/// One CALayer per laid-out element (a node of the core's layout tree), nested like the
/// elements. Each layer draws its own element's backgrounds, borders and text through the core's
/// CoreGraphics painter; opacity, transform, shadow, clipping and z-order are layer properties.
/// Layers are keyed by node id, so a relayout updates them in place. CSS px are points.
public final class MessageWidgetView: UIView {
    enum TouchPhase {
        case began
        case moved
        case ended
        case cancelled
    }

    weak var instance: MessageWidgetInstance?
    /// Strong: a destroyed instance's view keeps drawing its last frame. Taken from the instance
    /// once it has booted (a view asked for before the first layout picks it up on `update()`).
    private var core: WidgetCore?
    private var layers: [Int64: MessageWidgetNodeLayer] = [:]
    private var appliedGeneration: UInt64 = .max

    init(instance: MessageWidgetInstance) {
        self.instance = instance
        self.core = instance.core
        super.init(frame: .zero)
        self.clipsToBounds = true
        self.isMultipleTouchEnabled = false
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    var nodeLayerCount: Int {
        return self.layers.count
    }

    func layerIdentities() -> [Int64: ObjectIdentifier] {
        return self.layers.mapValues { ObjectIdentifier($0) }
    }

    func setDead() {
        self.isUserInteractionEnabled = false
    }

    /// Re-reads the core's layout tree. Cheap when nothing was rebuilt.
    func update() {
        if self.core == nil {
            self.core = self.instance?.core
        }
        guard let core = self.core else {
            return
        }
        let generation = core.generation
        if generation == self.appliedGeneration {
            return
        }
        self.appliedGeneration = generation
        let nodes = core.nodes()
        var origins: [Int64: CGPoint] = [:]
        var seen = Set<Int64>()
        let scale = self.window?.screen.scale ?? UIScreen.main.scale

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for node in nodes {
            seen.insert(node.id)
            let layer: MessageWidgetNodeLayer
            if let existing = self.layers[node.id] {
                layer = existing
            } else {
                layer = MessageWidgetNodeLayer()
                layer.nodeId = node.id
                layer.core = core
                self.layers[node.id] = layer
            }
            layer.contentsScale = scale
            let origin = CGPoint(x: CGFloat(node.x), y: CGFloat(node.y))
            origins[node.id] = origin
            let parentOrigin = node.parent_id == 0 ? .zero : (origins[node.parent_id] ?? .zero)
            let parentLayer: CALayer = node.parent_id == 0 ? self.layer : (self.layers[node.parent_id] ?? self.layer)
            parentLayer.addSublayer(layer)  // re-adding moves it to the end: sublayers end up in document order

            let size = CGSize(width: CGFloat(node.width), height: CGFloat(node.height))
            layer.setAffineTransform(.identity)
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.position = CGPoint(x: origin.x - parentOrigin.x + size.width / 2.0, y: origin.y - parentOrigin.y + size.height / 2.0)
            if node.has_transform != 0 {
                let m = node.transform
                layer.setAffineTransform(CGAffineTransform(a: CGFloat(m.0), b: CGFloat(m.1), c: CGFloat(m.2), d: CGFloat(m.3), tx: CGFloat(m.4), ty: CGFloat(m.5)))
            }
            layer.opacity = node.opacity
            layer.zPosition = CGFloat(node.z_index)

            let r = node.radii
            let radii = [r.0, r.1, r.2, r.3, r.4, r.5, r.6, r.7].map { CGFloat($0) }
            let uniform = radii.allSatisfy { $0 == radii[0] }
            if node.clips != 0 {
                if uniform {
                    layer.mask = nil
                    layer.cornerRadius = radii[0]
                    layer.masksToBounds = true
                } else {
                    let mask = CAShapeLayer()
                    mask.path = MessageWidgetView.roundedPath(size: size, radii: radii)
                    layer.mask = mask
                    layer.masksToBounds = false
                }
            } else {
                layer.mask = nil
                layer.masksToBounds = false
                layer.cornerRadius = 0.0
            }

            if node.has_shadow != 0 {
                let argb = node.shadow_argb
                let alpha = CGFloat((argb >> 24) & 0xff) / 255.0
                layer.shadowColor = UIColor(red: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: 1.0).cgColor
                layer.shadowOpacity = Float(alpha)
                layer.shadowOffset = CGSize(width: CGFloat(node.shadow_x), height: CGFloat(node.shadow_y))
                layer.shadowRadius = CGFloat(node.shadow_blur) / 2.0
                let spread = CGFloat(node.shadow_spread)
                layer.shadowPath = MessageWidgetView.roundedPath(size: size, radii: radii, inset: -spread, origin: CGPoint(x: -spread, y: -spread))
            } else {
                layer.shadowOpacity = 0.0
                layer.shadowPath = nil
            }
            layer.setNeedsDisplay()
        }
        for (id, layer) in self.layers where !seen.contains(id) {
            layer.removeFromSuperlayer()
            self.layers[id] = nil
        }
        CATransaction.commit()
    }

    private static func roundedPath(size: CGSize, radii: [CGFloat], inset: CGFloat = 0.0, origin: CGPoint = .zero) -> CGPath {
        let rect = CGRect(origin: origin, size: CGSize(width: size.width - 2.0 * inset, height: size.height - 2.0 * inset))
        let path = CGMutablePath()
        let tl = min(radii[0], radii[1]), tr = min(radii[2], radii[3]), br = min(radii[4], radii[5]), bl = min(radii[6], radii[7])
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY + tr), radius: tr)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.maxX - br, y: rect.maxY), radius: br)
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY - bl), radius: bl)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.minX + tl, y: rect.minY), radius: tl)
        path.closeSubpath()
        return path
    }

    // MARK: touches

    func handleTouch(phase: TouchPhase, at point: CGPoint) {
        let action: Int32
        switch phase {
        case .began: action = 0
        case .moved: action = 1
        case .ended: action = 2
        case .cancelled: action = 3
        }
        self.instance?.touch(action: action, at: point, pointer: 0, primary: true)
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.handleTouch(phase: .began, at: touch.location(in: self))
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.handleTouch(phase: .moved, at: touch.location(in: self))
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.handleTouch(phase: .ended, at: touch.location(in: self))
        }
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            self.handleTouch(phase: .cancelled, at: touch.location(in: self))
        }
    }
}

/// Draws one element's own commands (the core translates them to this layer's origin).
final class MessageWidgetNodeLayer: CALayer {
    var nodeId: Int64 = 0
    weak var core: WidgetCore?

    override func draw(in ctx: CGContext) {
        self.core?.drawNode(self.nodeId, in: ctx)
    }

    override func action(forKey event: String) -> CAAction? {
        return nil
    }
}
```

- [ ] **Step 4: Run the tests**

Run (controller): the iOS test command for `MessageWidgetTests`.
Expected: all `ViewTests` PASS in both modes, together with the earlier classes.
- If `testDrawsTheHeroGradient` sees the gradient upside down or offset, the layer context is not y-down at the origin `mwc_draw_node` assumes. Fix it in `MessageWidgetNodeLayer.draw(in:)`, for example with `ctx.translateBy` and `ctx.scaleBy` when `contentsAreFlipped()` is false. Don't change the C++ painter, which the host test pins.

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget/MessageWidget
git commit -m "MessageWidget: native layer tree — one CALayer per element, keyed by node id"
```

---

### Task 11: MessageWidgetRegistry — runtimes for one bubble

**Files:**
- Create: `MessageWidget/Sources/MessageWidgetRegistry.swift`
- Test: `MessageWidget/Tests/RegistryTests.swift`

**Interfaces:**
- Consumes: `MessageWidgetInstance` (Task 9).
- Produces:

```swift
public final class MessageWidgetRegistry {
    public struct Key: Hashable { public let path: [Int]; public let source: String }
    public typealias Factory = (_ source: String, _ theme: MessageWidgetInstance.Theme, _ stoppedLabel: String, _ maxMessageLength: Int) -> MessageWidgetInstance?
    public init(factory: Factory? = nil)
    public var stoppedLabel: String
    public var maxMessageLength: Int
    public var onLayoutChange: (() -> Void)?
    public var onBridge: ((MessageWidgetInstance.BridgeCall) -> Void)?
    public func beginPass(ownerId: AnyHashable, theme: MessageWidgetInstance.Theme)
    public func size(path: [Int], source: String, width: CGFloat) -> CGSize?   // nil: draw the block as code
    public func endPass()                     // destroys instances this pass did not use
    public func view(path: [Int], source: String) -> UIView?
    public func isLive(path: [Int]) -> Bool
    public var layoutVersions: [Key: Int] { get }
    public func setVisible(_ visible: Bool)
    public func destroyAll()
}
```

- [ ] **Step 1: Write the failing tests `Tests/RegistryTests.swift`**

```swift
import XCTest
@testable import MessageWidget

class RegistryTests: MessageWidgetTestCase {
    private func makeRegistry() -> MessageWidgetRegistry {
        let executor = self.executor!
        let resources = self.resources
        return MessageWidgetRegistry(factory: { source, theme, label, max in
            MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max, executor: executor, resources: resources)
        })
    }

    func testEmptySourceGetsNoWidget() {
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNil(registry.size(path: [0], source: "   \n", width: 360.0))
        registry.endPass()
        XCTAssertTrue(registry.layoutVersions.isEmpty)
    }

    func testTwoPathsGetTwoInstances() throws {
        try self.skipIfMainStackTooSmall()
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        XCTAssertNotNil(registry.size(path: [0], source: self.fixture("02-split-bill"), width: 360.0))
        XCTAssertNotNil(registry.size(path: [2], source: self.fixture("02-split-bill"), width: 360.0))
        registry.endPass()
        XCTAssertEqual(registry.layoutVersions.count, 2)
        let a = registry.view(path: [0], source: self.fixture("02-split-bill"))
        let b = registry.view(path: [2], source: self.fixture("02-split-bill"))
        XCTAssertNotNil(a)
        XCTAssertNotNil(b)
        XCTAssertFalse(a === b)
    }

    func testEditedSourceReplacesTheInstanceAtEndOfPass() throws {
        try self.skipIfMainStackTooSmall()
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<p>one</p>", width: 360.0)
        registry.endPass()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<p>two</p>", width: 360.0)
        registry.endPass()
        XCTAssertEqual(registry.layoutVersions.keys.map(\.source), ["<p>two</p>"])
    }

    func testNewOwnerDestroysEverything() throws {
        try self.skipIfMainStackTooSmall()
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<p>one</p>", width: 360.0)
        registry.endPass()
        registry.beginPass(ownerId: 2, theme: .light)
        registry.endPass()
        XCTAssertTrue(registry.layoutVersions.isEmpty)
        XCTAssertFalse(registry.isLive(path: [0]))
    }

    func testDestroyAllDropsViews() throws {
        try self.skipIfMainStackTooSmall()
        let registry = self.makeRegistry()
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: "<p>one</p>", width: 360.0)
        registry.endPass()
        registry.destroyAll()
        XCTAssertNil(registry.view(path: [0], source: "<p>one</p>"))
    }

    func testLayoutChangeIsForwarded() throws {
        try self.skipIfMainStackTooSmall()
        let registry = self.makeRegistry()
        let changed = self.expectation(description: "forwarded")
        registry.onLayoutChange = { changed.fulfill() }
        registry.beginPass(ownerId: 1, theme: .light)
        _ = registry.size(path: [0], source: self.fixture("03-faq-accordion"), width: 360.0)
        registry.endPass()
        guard let view = registry.view(path: [0], source: self.fixture("03-faq-accordion")) as? MessageWidgetView,
              let instance = view.instance,
              let json = instance.evaluateForTesting("JSON.stringify(document.querySelector('.q').getBoundingClientRect())"),
              let rect = try? JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Double] else {
            return XCTFail("no widget")
        }
        let p = CGPoint(x: rect["x"]! + 10.0, y: rect["y"]! + 10.0)
        view.handleTouch(phase: .began, at: p)
        view.handleTouch(phase: .ended, at: p)
        self.wait(for: [changed], timeout: 1.0)
        XCTAssertEqual(registry.layoutVersions.values.first, 1)
    }
}

final class RegistryDedicatedThreadTests: RegistryTests {
    override class var mode: MessageWidgetExecutor.Mode { return .dedicatedThread }
}
```

- [ ] **Step 2: Run them to make sure they fail**

Expected: compile FAIL (`MessageWidgetRegistry` is unknown).

- [ ] **Step 3: Write `Sources/MessageWidgetRegistry.swift`**

```swift
import UIKit

/// The widget runtimes of one bubble. A runtime lives as long as its bubble: the bubble node
/// calls `beginPass` with its message's stable id, and a different id destroys everything.
/// Within a message, a widget is keyed by its block's structural path plus its source, so an
/// edited source gets a fresh runtime and two widget blocks get two. Main thread only.
public final class MessageWidgetRegistry {
    public struct Key: Hashable {
        public let path: [Int]
        public let source: String
    }

    public typealias Factory = (_ source: String, _ theme: MessageWidgetInstance.Theme, _ stoppedLabel: String, _ maxMessageLength: Int) -> MessageWidgetInstance?

    public var stoppedLabel: String = "Widget stopped"
    public var maxMessageLength: Int = 4096
    public var onLayoutChange: (() -> Void)?
    public var onBridge: ((MessageWidgetInstance.BridgeCall) -> Void)?

    private let factory: Factory
    private var ownerId: AnyHashable?
    private var theme: MessageWidgetInstance.Theme = .light
    private var visible = true
    private var instances: [Key: MessageWidgetInstance] = [:]
    private var usedInPass = Set<Key>()

    public init(factory: Factory? = nil) {
        self.factory = factory ?? { source, theme, label, max in
            MessageWidgetInstance(source: source, theme: theme, stoppedLabel: label, maxMessageLength: max)
        }
    }

    deinit {
        for (_, instance) in self.instances {
            instance.destroy()
        }
    }

    public func beginPass(ownerId: AnyHashable, theme: MessageWidgetInstance.Theme) {
        if self.ownerId != ownerId {
            self.destroyAll()
            self.ownerId = ownerId
        }
        if self.theme != theme {
            self.theme = theme
            for (_, instance) in self.instances {
                instance.setTheme(theme)
            }
        }
        self.usedInPass.removeAll()
    }

    public func size(path: [Int], source: String, width: CGFloat) -> CGSize? {
        guard Thread.isMainThread, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        let key = Key(path: path, source: source)
        let instance: MessageWidgetInstance
        if let existing = self.instances[key] {
            instance = existing
        } else {
            guard let created = self.factory(source, self.theme, self.stoppedLabel, self.maxMessageLength) else {
                return nil
            }
            created.onLayoutChange = { [weak self] in
                self?.onLayoutChange?()
            }
            created.onBridge = { [weak self] call in
                self?.onBridge?(call)
            }
            created.setVisible(self.visible)
            self.instances[key] = created
            instance = created
        }
        let size = instance.layout(width: width)
        if instance.failedToStart {
            instance.destroy()
            self.instances[key] = nil
            return nil
        }
        self.usedInPass.insert(key)
        return size
    }

    public func endPass() {
        for (key, instance) in self.instances where !self.usedInPass.contains(key) {
            instance.destroy()
            self.instances[key] = nil
        }
    }

    public func view(path: [Int], source: String) -> UIView? {
        return self.instances[Key(path: path, source: source)]?.view
    }

    public func isLive(path: [Int]) -> Bool {
        return self.instances.contains { $0.key.path == path && $0.value.deadReason == nil }
    }

    public var layoutVersions: [Key: Int] {
        return self.instances.mapValues { $0.layoutVersion }
    }

    public func setVisible(_ visible: Bool) {
        self.visible = visible
        for (_, instance) in self.instances {
            instance.setVisible(visible)
        }
    }

    public func destroyAll() {
        for (_, instance) in self.instances {
            instance.destroy()
        }
        self.instances.removeAll()
        self.usedInPass.removeAll()
    }
}
```

- [ ] **Step 4: Run the tests**

Run (controller): the iOS test command for `MessageWidgetTests`.
Expected: PASS for every class in both modes. This ends the module's standalone work: **all MessageWidget tests green without an app build.**

- [ ] **Step 5: Commit**

```bash
git add submodules/TelegramUI/Components/MessageWidget/MessageWidget
git commit -m "MessageWidget: MessageWidgetRegistry — a bubble's widget runtimes keyed by block path and source"
```

---

### Task 12: Gate, strings, main-thread stack

**Files:**
- Modify:
  - `submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift` (next to `useInputDecEngine`: lines 86, 145, 204, 261, 324, 385)
  - `submodules/DebugSettingsUI/Sources/DebugController.swift` (next to `.inputDecEngineEditor`: lines ~735, ~790, ~943, ~1415, ~1965)
  - `Telegram/Telegram-iOS/en.lproj/Localizable.strings`
  - `Telegram/BUILD` (`ios_application(name = "Telegram")`, around lines 1894–1955)
  - `Telegram/Telegram-iOS/main.m`

**Interfaces:**
- Produces:
  - `ExperimentalUISettings.messageWidgets: Bool` (default `false`, coding key `"messageWidgets"`);
  - the Debug Settings switch "Message Widgets (tgwidget)";
  - the string `"Message.WidgetStopped" = "Widget stopped";`, read as `presentationData.strings.Message_WidgetStopped`;
  - a 16 MB main-thread stack on the app binary.

- [ ] **Step 1: Add the setting**

Follow `useInputDecEngine` exactly at each of its six sites in `ExperimentalUISettings.swift`:
- declare `public var messageWidgets: Bool`;
- `messageWidgets: false,` in `defaultSettings`;
- an `init` parameter `messageWidgets: Bool` with its assignment;
- decode: `self.messageWidgets = try container.decodeIfPresent(Bool.self, forKey: "messageWidgets") ?? false`;
- encode: `try container.encodeIfPresent(self.messageWidgets, forKey: "messageWidgets")`.

Check every `ExperimentalUISettings(` call site still compiles: `grep -rn 'ExperimentalUISettings(' submodules --include=*.swift`. The memberwise init gains a parameter, so pass `messageWidgets:` wherever the init is called explicitly.

- [ ] **Step 2: Add the Debug Settings row**

In `DebugController.swift`, mirror `inputDecEngineEditor`:
- a case `case messageWidgets(Bool)`;
- its section `DebugControllerSection.experiments.rawValue`;
- its `stableId`. The ids must match the append order, or ItemList traps (see the comment at ~938). Use the next free id in sequence and renumber the following cases if the new row is inserted between existing ones; appending it last in the experiments section avoids renumbering.
- the item:

```swift
        case let .messageWidgets(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Message Widgets (tgwidget)", value: value, sectionId: self.section, style: .blocks, updated: { value in
                let _ = arguments.sharedContext.accountManager.transaction ({ transaction in
                    transaction.updateSharedData(ApplicationSpecificSharedDataKeys.experimentalUISettings, { settings in
                        var settings = settings?.get(ExperimentalUISettings.self) ?? ExperimentalUISettings.defaultSettings
                        settings.messageWidgets = value
                        return EnginePreferencesEntry(settings)
                    })
                }).start()
            })
```

- appended under the same `#if DEBUG … #else if … appBuildType == .internal … #endif` guard as `inputDecEngineEditor`: `entries.append(.messageWidgets(experimentalSettings.messageWidgets))`.

- [ ] **Step 3: Add the string**

Append to `Telegram/Telegram-iOS/en.lproj/Localizable.strings`:

```
"Message.WidgetStopped" = "Widget stopped";
```

- [ ] **Step 4: Raise the main thread's stack and log it**

In `Telegram/BUILD`, add to `ios_application(name = "Telegram", …)`, next to `deps`:

```python
    # Message widgets run QuickJS synchronously on the main thread with a 2 MB limit
    # (MessageWidgetExecutor); below 4 MB they fall back to a dedicated thread. 16 MB, page-aligned.
    linkopts = ["-Wl,-stack_size,0x1000000"],
```

In `Telegram/Telegram-iOS/main.m`, as the first statement of `main` (add `#include <pthread.h>` at the top):

```objc
#if DEBUG
    NSLog(@"[MessageWidget] main thread stack: %zu bytes", pthread_get_stacksize_np(pthread_self()));
#endif
```

This log line is the device check for spec open item 1. The user reads it after installing; the executor picks its mode at runtime either way.

- [ ] **Step 5: Build the app**

Run (controller): the full app build command.
Expected: `Build completed successfully` (check the build's own exit code). The widget code isn't reachable yet; this checks the settings, strings and linker flag.

- [ ] **Step 6: Commit**

```bash
git add submodules/TelegramUIPreferences submodules/DebugSettingsUI Telegram/Telegram-iOS/en.lproj/Localizable.strings Telegram/BUILD Telegram/Telegram-iOS/main.m
git commit -m "Message widgets: Debug Settings gate, Widget stopped string, 16 MB main-thread stack"
```

---

### Task 13: InstantPage V2 — the widget item

**Files:**
- Create: `submodules/InstantPageUI/Sources/InstantPageV2Widget.swift`
- Modify:
  - `submodules/InstantPageUI/Sources/InstantPageV2Layout.swift`: the enum at :81, `frame`/`offsetBy`, `LayoutContext` at :735, `layoutInstantPageV2` at :496, and `layoutBlock`'s `.preformatted` case at :999
  - `submodules/InstantPageUI/Sources/InstantPageRenderer.swift`: `InstantPageV2ItemKind` at :40, `InstantPageV2StableItemId` at :33, `reuse` at :931, `stableId` at :1049, `makeItemView` at :1113, and the V2 view's public API
  - `submodules/TextFormat/Sources/InstantPageSyntaxHighlightSpecs.swift`
- Test: `submodules/InstantPageUI/Tests/InstantPageV2WidgetTests.swift`

**Interfaces:**
- Produces, in InstantPageUI:

```swift
public let instantPageWidgetLanguage = "tgwidget"
public protocol InstantPageV2WidgetHost: AnyObject {
    /// The widget's size at `width`, booting it on first use (synchronous, main thread). nil: draw the block as code.
    func instantPageWidgetSize(path: [Int], source: String, width: CGFloat) -> CGSize?
    /// The live view of the widget, for the item view to host.
    func instantPageWidgetView(path: [Int], source: String) -> UIView?
}
public struct InstantPageV2WidgetItem { public var frame: CGRect; public let path: [Int]; public let source: String }
case widget(InstantPageV2WidgetItem)                      // InstantPageV2LaidOutItem
func layoutWidgetBlock(text: RichText, language: String?, path: [Int], boundingWidth: CGFloat, host: InstantPageV2WidgetHost?) -> [InstantPageV2LaidOutItem]?  // internal
layoutInstantPageV2(..., widgetHost: InstantPageV2WidgetHost? = nil)
InstantPageV2View.widgetHost: InstantPageV2WidgetHost?    // weak, set before update(layout:)
InstantPageV2View.widgetPath(at point: CGPoint) -> [Int]?
```

- [ ] **Step 1: Write the failing tests `submodules/InstantPageUI/Tests/InstantPageV2WidgetTests.swift`**

```swift
import XCTest
import UIKit
import TelegramCore
@testable import InstantPageUI

private final class StubHost: InstantPageV2WidgetHost {
    var requests: [([Int], String, CGFloat)] = []
    var height: CGFloat = 123.0
    var viewToReturn: UIView?

    func instantPageWidgetSize(path: [Int], source: String, width: CGFloat) -> CGSize? {
        self.requests.append((path, source, width))
        return CGSize(width: width, height: self.height)
    }

    func instantPageWidgetView(path: [Int], source: String) -> UIView? {
        return self.viewToReturn
    }
}

final class InstantPageV2WidgetTests: XCTestCase {
    func testWidgetBlockLaysOutAtTheHostsHeight() {
        let host = StubHost()
        let items = layoutWidgetBlock(text: .plain("<p>hi</p>"), language: " TGWidget ", path: [3], boundingWidth: 320.0, host: host)
        guard let items, case let .widget(item) = items.first else {
            return XCTFail("not a widget item")
        }
        XCTAssertEqual(item.frame, CGRect(x: 0.0, y: 0.0, width: 320.0, height: 123.0))
        XCTAssertEqual(item.path, [3])
        XCTAssertEqual(item.source, "<p>hi</p>")
        XCTAssertEqual(host.requests.first?.2, 320.0)
    }

    func testWithoutAHostItIsCode() {
        XCTAssertNil(layoutWidgetBlock(text: .plain("<p>hi</p>"), language: "tgwidget", path: [0], boundingWidth: 320.0, host: nil))
    }

    func testOtherLanguagesAreCode() {
        XCTAssertNil(layoutWidgetBlock(text: .plain("let x = 1"), language: "swift", path: [0], boundingWidth: 320.0, host: StubHost()))
    }

    func testEmptyWidgetBlockLaysOutAsCode() {
        let host = StubHost()
        XCTAssertNil(layoutWidgetBlock(text: .plain("  \n"), language: "tgwidget", path: [0], boundingWidth: 320.0, host: host))
        XCTAssertTrue(host.requests.isEmpty)
    }

    func testTwoWidgetBlocksGetDistinctPaths() {
        let host = StubHost()
        _ = layoutWidgetBlock(text: .plain("<p>a</p>"), language: "tgwidget", path: [0], boundingWidth: 320.0, host: host)
        _ = layoutWidgetBlock(text: .plain("<p>b</p>"), language: "tgwidget", path: [2], boundingWidth: 320.0, host: host)
        XCTAssertEqual(host.requests.map { $0.0 }, [[0], [2]])
    }

    func testWidgetViewToleratesMissingHostView() {
        let host = StubHost()
        host.viewToReturn = nil
        let view = InstantPageV2WidgetView(item: InstantPageV2WidgetItem(frame: CGRect(x: 0, y: 0, width: 100, height: 50), path: [0], source: "x"), host: host)
        view.update(item: InstantPageV2WidgetItem(frame: CGRect(x: 0, y: 0, width: 100, height: 60), path: [0], source: "x"), host: host)
        XCTAssertTrue(view.subviews.isEmpty)
    }

    func testHostedViewMovesAndLeavesASnapshot() {
        let host = StubHost()
        let live = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 50))
        host.viewToReturn = live
        let item = InstantPageV2WidgetItem(frame: CGRect(x: 0, y: 0, width: 100, height: 50), path: [0], source: "x")
        let first = InstantPageV2WidgetView(item: item, host: host)
        XCTAssertTrue(live.superview === first)
        let second = InstantPageV2WidgetView(item: item, host: host)
        XCTAssertTrue(live.superview === second)
        XCTAssertFalse(first.subviews.contains(live))
    }

    func testSyntaxHighlightSkipsWidgets() {
        let specs = instantPageSyntaxHighlightSpecs(for: [.preformatted(.plain("<p>x</p>"), language: "tgwidget"), .preformatted(.plain("let x = 1"), language: "swift")])
        XCTAssertEqual(specs.map(\.language), ["swift"])
    }
}
```

Add the file to the existing `InstantPageUITestsLib` glob if `submodules/InstantPageUI/BUILD` lists test files explicitly rather than by `glob(["Tests/**/*.swift"])`. The test target needs `//submodules/TextFormat:TextFormat` for `instantPageSyntaxHighlightSpecs`; add it to the test library's deps if it isn't there.

- [ ] **Step 2: Run them to make sure they fail**

Run (controller): the iOS test command with `--target //submodules/InstantPageUI:InstantPageUITests`
Expected: compile FAIL.

- [ ] **Step 3: Write `Sources/InstantPageV2Widget.swift`**

```swift
import Foundation
import UIKit
import TelegramCore
import TextFormat

/// The code-block language that makes a block a message widget (until the widget `PageBlock` exists).
public let instantPageWidgetLanguage = "tgwidget"

/// Supplies message widgets to a V2 layout. Implemented by the chat's rich bubble over its widget
/// registry (MessageWidget); every other V2 surface passes none and draws the block as code.
public protocol InstantPageV2WidgetHost: AnyObject {
    /// The widget's size at `width`, booting it on first use (synchronous, main thread). nil: draw the block as code.
    func instantPageWidgetSize(path: [Int], source: String, width: CGFloat) -> CGSize?
    /// The live view of the widget, for the item view to host.
    func instantPageWidgetView(path: [Int], source: String) -> UIView?
}

public struct InstantPageV2WidgetItem {
    public var frame: CGRect
    public let path: [Int]
    public let source: String

    public init(frame: CGRect, path: [Int], source: String) {
        self.frame = frame
        self.path = path
        self.source = source
    }
}

/// A `tgwidget` code block laid out as a widget, or nil to lay it out as code (no host, another
/// language, an empty source, or a host that declines).
func layoutWidgetBlock(text: RichText, language: String?, path: [Int], boundingWidth: CGFloat, host: InstantPageV2WidgetHost?) -> [InstantPageV2LaidOutItem]? {
    guard let host, normalizedCodeBlockLanguage(language) == instantPageWidgetLanguage else {
        return nil
    }
    let source = text.plainText
    guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        return nil
    }
    guard let size = host.instantPageWidgetSize(path: path, source: source, width: boundingWidth) else {
        return nil
    }
    return [.widget(InstantPageV2WidgetItem(frame: CGRect(x: 0.0, y: 0.0, width: boundingWidth, height: size.height), path: path, source: source))]
}

/// Hosts the widget's live view. The view belongs to the widget, not to this item view: when a
/// crossfading page view asks for the same widget, the live view moves there and this one keeps a
/// static snapshot for the rest of the fade.
final class InstantPageV2WidgetView: UIView, InstantPageItemView {
    private(set) var item: InstantPageV2WidgetItem
    private weak var host: InstantPageV2WidgetHost?
    private weak var hostedView: UIView?
    private var snapshotView: UIView?

    var itemFrame: CGRect {
        return self.item.frame
    }

    init(item: InstantPageV2WidgetItem, host: InstantPageV2WidgetHost?) {
        self.item = item
        self.host = host
        super.init(frame: item.frame)
        self.attach()
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(item: InstantPageV2WidgetItem, host: InstantPageV2WidgetHost?) {
        self.item = item
        self.host = host
        self.frame = item.frame
        self.attach()
    }

    private func attach() {
        guard let host = self.host, let live = host.instantPageWidgetView(path: self.item.path, source: self.item.source) else {
            return
        }
        if live.superview !== self {
            if let previous = live.superview as? InstantPageV2WidgetView {
                previous.keepSnapshot(of: live)
            }
            self.addSubview(live)
        }
        live.frame = self.bounds
        self.hostedView = live
        self.snapshotView?.removeFromSuperview()
        self.snapshotView = nil
    }

    fileprivate func keepSnapshot(of live: UIView) {
        guard let snapshot = live.snapshotView(afterScreenUpdates: false) else {
            return
        }
        snapshot.frame = self.bounds
        self.addSubview(snapshot)
        self.snapshotView = snapshot
    }
}
```

- [ ] **Step 4: Wire the item into the layout**

In `InstantPageV2Layout.swift`:
- Add `case widget(InstantPageV2WidgetItem)` to `InstantPageV2LaidOutItem`. In `frame`, add `case let .widget(item): return item.frame`; in `offsetBy`, add `case var .widget(item): item.frame = item.frame.offsetBy(dx: delta.x, dy: delta.y); return .widget(item)`. Any other `switch` over the enum that the compiler flags (for example `lastTextLineFrame`) gets a `case .widget: break` or `continue` that treats it like a media block.
- Add `let widgetHost: InstantPageV2WidgetHost?` to `LayoutContext`.
- Add a trailing parameter to `layoutInstantPageV2`:

  ```swift
      /// Supplies `tgwidget` blocks as live widgets. Only the chat's rich bubble passes one, and only
      /// when it lays out on the main thread; nil draws them as code.
      widgetHost: InstantPageV2WidgetHost? = nil
  ```

  and pass `widgetHost: widgetHost` into the `LayoutContext(...)` initializer call.
- In `layoutBlock`, change the `.preformatted` case to:

  ```swift
      case let .preformatted(text, language):
          if let widget = layoutWidgetBlock(text: text, language: language, path: pathPrefix, boundingWidth: boundingWidth, host: context.widgetHost) {
              return widget
          }
          return layoutCodeBlock(text, language: language, boundingWidth: boundingWidth,
                                 horizontalInset: horizontalInset, context: &context)
  ```

In `InstantPageRenderer.swift`:
- `InstantPageV2StableItemId` gains `case widget([Int])`.
- `InstantPageV2ItemKind` gains `widget`.
- `stableId(for:atPosition:)` gains `case let .widget(w): return .widget(w.path)`.
- In `reuse`:

  ```swift
          case let .widget(widget):
              guard let v = existingView as? InstantPageV2WidgetView else { return nil }
              v.update(item: widget, host: self.widgetHost)
              return v
  ```

- In `makeItemView`: `case let .widget(widget): return InstantPageV2WidgetView(item: widget, host: self.widgetHost)`.
- On `InstantPageV2View`, add:

  ```swift
      /// Supplies live widgets to `.widget` items; set by the host before `update(layout:)`.
      public weak var widgetHost: InstantPageV2WidgetHost?

      /// The structural path of the widget under `point` (this view's coordinates), top-level items only.
      public func widgetPath(at point: CGPoint) -> [Int]? {
          guard let layout = self.currentLayout else {
              return nil
          }
          for item in layout.items {
              if case let .widget(widget) = item, widget.frame.contains(point) {
                  return widget.path
              }
          }
          return nil
      }
  ```

  Use whatever stored property `InstantPageV2View` keeps the applied layout in. `grep -n 'var currentLayout\|self.layout = \|private var layout' InstantPageRenderer.swift` finds it.

In `submodules/TextFormat/Sources/InstantPageSyntaxHighlightSpecs.swift`, in `instantPageSyntaxHighlightSpecs`, change the `.preformatted` guard to

```swift
                guard let language = normalizedCodeBlockLanguage(language), language != "tgwidget", !text.plainText.isEmpty else {
```

(TextFormat sits below InstantPageUI, so it spells out the literal; `instantPageWidgetLanguage` is not visible there.)

- [ ] **Step 5: Run the tests**

Run (controller): the iOS test command with `--target //submodules/InstantPageUI:InstantPageUITests`
Expected: the new tests and the existing InstantPageUI tests PASS.

- [ ] **Step 6: Commit**

```bash
git add submodules/InstantPageUI submodules/TextFormat
git commit -m "InstantPageUI: tgwidget blocks lay out as widget items through InstantPageV2WidgetHost"
```

---

### Task 14: The rich bubble hosts widgets; taps and long press

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/Sources/ChatMessageRichDataWidgetHost.swift`
- Modify:
  - `submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode/BUILD`
  - `…/Sources/ChatMessageRichDataBubbleContentNode.swift`: properties near :107, `visibility` at :165, `deinit` at :552, the asyncLayout capture at :559, the layout call and cache at :847–:888, the cache store at :1324, the pageView wiring at :1347, `tapActionAtPoint` at :1789
  - `submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode/Sources/ChatMessageBubbleItemNode.swift` (the `.ignore` arm at :6094)

**Interfaces:**
- Consumes: `MessageWidgetRegistry` (Task 11), `InstantPageV2WidgetHost`, `layoutInstantPageV2(widgetHost:)`, `InstantPageV2View.widgetHost` and `widgetPath(at:)` (Task 13), and `ExperimentalUISettings.messageWidgets` and `Message_WidgetStopped` (Task 12).

- [ ] **Step 1: Add the dependency**

In the node's `BUILD`, add `"//submodules/TelegramUI/Components/MessageWidget/MessageWidget",` to `deps`.

- [ ] **Step 2: Write `Sources/ChatMessageRichDataWidgetHost.swift`**

```swift
import Foundation
import UIKit
import InstantPageUI
import MessageWidget

/// The rich bubble's `InstantPageV2WidgetHost`: forwards to the bubble's widget registry.
final class ChatMessageRichDataWidgetHost: InstantPageV2WidgetHost {
    let registry: MessageWidgetRegistry

    init(registry: MessageWidgetRegistry) {
        self.registry = registry
    }

    func instantPageWidgetSize(path: [Int], source: String, width: CGFloat) -> CGSize? {
        return self.registry.size(path: path, source: source, width: width)
    }

    func instantPageWidgetView(path: [Int], source: String) -> UIView? {
        return self.registry.view(path: path, source: source)
    }
}

```

Add to the same file, with `import AccountContext` and `import TelegramUIPreferences` at the top:

```swift
/// Widgets render only when the Debug Settings gate is on and the server has not killed them.
func messageWidgetsEnabled(context: AccountContext) -> Bool {
    if !context.sharedContext.immediateExperimentalUISettings.messageWidgets {
        return false
    }
    if let _ = context.getAppConfigValue("ios_killswitch_disable_message_widgets") {
        return false
    }
    return true
}
```

- [ ] **Step 3: Own a registry in the node**

Add near the other per-node state:

```swift
    /// The bubble's widget runtimes (`tgwidget` blocks). They live as long as this node shows the same
    /// message: `beginPass` with another stable id destroys them.
    private let widgetRegistry = MessageWidgetRegistry()
    private lazy var widgetHost = ChatMessageRichDataWidgetHost(registry: self.widgetRegistry)
```

In `init` (or the first place `self.item` is available, if the strings come from the item), wire the callbacks once:

```swift
        self.widgetRegistry.onLayoutChange = { [weak self] in
            guard let self, let item = self.item else {
                return
            }
            item.controllerInteraction.requestMessageUpdate(item.message.id, false, nil)
        }
        self.widgetRegistry.onBridge = { [weak self] call in
            guard let self, let item = self.item else {
                return
            }
            switch call {
            case let .sendMessage(text):
                item.controllerInteraction.sendMessage(text, item.message.id)
            case let .openLink(url):
                item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: true))
            }
        }
```

In `deinit`, add `self.widgetRegistry.destroyAll()`.

In the `visibility` `didSet`, add `self.widgetRegistry.setVisible(self.visibility != .none)`.

- [ ] **Step 4: Pass the host into the layout and key the cache on widget versions**

At the top of `asyncLayoutContent` (next to `let currentExpandedQuotePaths = …`):

```swift
        let widgetRegistry = self.widgetRegistry
        let widgetHost = self.widgetHost
```

Extend the `currentPageLayout` tuple type with two fields before `layout`:

```swift
                                    widgetsEnabled: Bool,
                                    widgetLayoutVersions: [MessageWidgetRegistry.Key: Int],
```

In the measure closure, before the cache check:

```swift
                    let widgetsEnabled = messageWidgetsEnabled(context: item.context) && Thread.isMainThread
                    if !widgetsEnabled {
                        widgetRegistry.destroyAll()
                    }
```

Add to the cache-hit condition:

```swift
                       current.widgetsEnabled == widgetsEnabled,
                       current.widgetLayoutVersions == widgetRegistry.layoutVersions,
```

In the miss branch, around the `layoutInstantPageV2` call:

```swift
                        if widgetsEnabled {
                            widgetRegistry.stoppedLabel = item.presentationData.strings.Message_WidgetStopped
                            widgetRegistry.maxMessageLength = Int(item.context.userLimits.maxMessageLength)  // EngineConfiguration.UserLimits
                            widgetRegistry.beginPass(ownerId: AnyHashable(item.message.stableId), theme: isDark ? .dark : .light)
                        }
                        pageLayout = layoutInstantPageV2(
                            …existing arguments…,
                            contentScale: instantPageChatMessageContentScale(baseFontSize: baseFontSize),
                            widgetHost: widgetsEnabled ? widgetHost : nil
                        )
                        if widgetsEnabled {
                            widgetRegistry.endPass()
                        }
```

`isDark` is the local at :646. `item.context.userLimits` is `AccountContext.userLimits` (`EngineConfiguration.UserLimits`, `AccountContext.swift:1832`).

At the cache store (:1324), add the two new fields in tuple order: `messageWidgetsEnabled(context: item.context) && Thread.isMainThread` and `self.widgetRegistry.layoutVersions`.

At the pageView wiring (:1347, before `pageView.update(layout:…)`): `pageView.widgetHost = self.widgetHost`.

- [ ] **Step 5: Taps go to the widget; long press opens the menu**

In `tapActionAtPoint`, immediately after the `unsupportedActionContains` check:

```swift
        // A tap inside a live widget is the widget's: `.ignore` fails the bubble's tap recognizer at
        // touch-down, so a fast double tap on a widget button never becomes a quick reaction.
        // `hasLongTapAction: false` keeps the long-press context menu (ChatMessageBubbleItemNode's
        // `.ignore` arm honours it). TAP ONLY: for `.longTap` this falls through, so the `.none` arm
        // reaches `.openContextMenu`.
        if case .tap = gesture, let pageView = self.pageView, let path = pageView.widgetPath(at: self.view.convert(point, to: pageView)), self.widgetRegistry.isLive(path: path) {
            return ChatMessageBubbleContentTapAction(content: .ignore, hasLongTapAction: false)
        }
```

In `ChatMessageBubbleItemNode.swift`, edit both branches of the `.ignore` arm (around :6094):

```swift
                    case .ignore:
                        if let item = self.item, self.backgroundNode.frame.contains(CGPoint(x: self.frame.width - location.x, y: location.y)), let tapMessage = self.item?.controllerInteraction.tapMessage {
                            return .action(InternalBubbleTapAction.Action({
                                tapMessage(item.message)
                            }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                        } else {
                            return .action(InternalBubbleTapAction.Action({
                            }, contextMenuOnLongPress: !tapAction.hasLongTapAction))
                        }
```

`hasLongTapAction` defaults to `true` (`ChatMessageBubbleContentNode.swift:178`), so `contextMenuOnLongPress` stays `false` for every existing `.ignore` caller. Only the widget's `false` changes behaviour.

- [ ] **Step 6: Build the app**

Run (controller): the full app build command.
Expected: `Build completed successfully`. Then run the module tests once more: `--target //submodules/InstantPageUI:InstantPageUITests` and `--target //submodules/TelegramUI/Components/MessageWidget/MessageWidget:MessageWidgetTests`.

- [ ] **Step 7: Commit**

```bash
git add submodules/TelegramUI/Components/Chat/ChatMessageRichDataBubbleContentNode submodules/TelegramUI/Components/Chat/ChatMessageBubbleItemNode
git commit -m "Rich bubble hosts tgwidget widgets: registry per bubble, height through the layout cache, taps to the widget"
```

---

### Task 15: Docs and the device checklist

**Files:**
- Modify: `CLAUDE.md` (a new section after "InstantPage V2 & rich-text messages")
- Modify: `docs/widget-messages/examples/README.md`. It is uncommitted and stays uncommitted; edit it only if the recipe changed.

- [ ] **Step 1: Add the CLAUDE.md section**

```markdown
## Message widgets (`tgwidget`)

A code block with the language `tgwidget` in a RICH message renders as a live HTML widget (the
interim form of a future `PageBlock`). Spec: docs/superpowers/specs/2026-10-13-message-widgets-design.md;
plan: docs/superpowers/plans/2026-10-13-message-widgets.md. Off unless Debug Settings ▸ "Message
Widgets (tgwidget)" is on and the app config has no `ios_killswitch_disable_message_widgets`.

- **Everything is synchronous in the layout pass.** `MessageWidgetInstance.layout(width:)` boots
  the widget (QuickJS + widget-sandbox's DOM shim + its validator) and lays it out with litehtml
  before returning a height. JS runs through `MessageWidgetExecutor`: inline on main when the main
  stack has `jsStackLimit` (2 MB) + 2 MB headroom (the app links with `-stack_size 0x1000000`),
  otherwise on one 8 MB thread while main waits. Tests run every class in both modes.
- **No network is the container's job.** `third-party/litehtml` fetches only through the
  core's container (`MessageWidgetCore`), which accepts `data:` images only and counts anything
  else (`mwc_network_refusals`); the attack corpus must keep it at 0 (`MessageWidgetTests`).
- **litehtml is forked in place** (third-party/litehtml/VENDOR.md): flex gap, a per-element draw
  token (`hdc` = the render item), paint-property tokens, letter-spacing, tabular figures.
- **The bundles are vendored artifacts** (third-party/widget-sandbox): change the shim or the
  validator in ~/build/widget-sandbox and re-vendor `.js` + `.qbc` together.
- **Runtimes live as long as the bubble** (`MessageWidgetRegistry`, keyed by block path + source;
  a new message stable id destroys them). Height changes ride the layout cache key
  (`widgetLayoutVersions`) + `requestMessageUpdate`, like collapsible quotes.
- **Taps go to the widget, long press to the menu**: `.ignore` + `hasLongTapAction: false`, which
  `ChatMessageBubbleItemNode`'s `.ignore` arm turns into `contextMenuOnLongPress`.
```

- [ ] **Step 2: Final full build and test run**

Run (controller):
- the full app build;
- `MessageWidgetTests`;
- `InstantPageUITests`;
- the host tests `//third-party/quickjs-ng:all`, `//third-party/litehtml:all` and `//submodules/TelegramUI/Components/MessageWidget/MessageWidgetCore:all`.

Expected: all green. Report each command's result as run.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "CLAUDE.md: message widgets"
```

- [ ] **Step 4: Hand the device checklist to the user** (the user installs; no simulator installs from here):
  1. **Stack:** the debug console shows `[MessageWidget] main thread stack: … bytes`. At least 4 MB means JS runs on main. Less means the dedicated-thread mode is in use and the feature still works.
  2. Turn on Debug Settings ▸ "Message Widgets (tgwidget)".
  3. **Posting:** post 01–10 as rich messages with the README recipe (a `# Heading` line, then the fenced block). Confirm each arrives rich and its code block's language is `tgwidget` (spec open item 4).
  4. **01–05:** they render at the right height and respond:
     - 02's total changes;
     - 03 grows and the bubble grows with it;
     - 04 sends "My vote: …";
     - 05 ticks.
  5. **06–09** show what's still missing (SVG, grid, canvas, Chart.js), with no crash.
  6. **10:** every network row reads blocked, Open link asks first, and Hang stops the widget with "Widget stopped" while the app keeps running.
  7. **Gestures:** a long press on a widget opens the message menu; a quick double tap on 02's + doesn't add a reaction; scrolling over a widget scrolls the chat (spec open item 2).
