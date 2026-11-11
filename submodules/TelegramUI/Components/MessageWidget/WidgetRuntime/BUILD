load("@rules_cc//cc:cc_library.bzl", "cc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

# The message-widget native runtime (docs/message-widgets-native-runtime.md): a
# C++ DOM whose nodes are QuickJS objects, with bindings generated from WebIDL by //build-system/WidgetIDL. Optimized
# in every configuration, as quickjs-ng and the litehtml fork are: its work runs inside the chat's layout waits.
# Host tests: ./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/...
WR_COPTS = [
    "-std=c++20",
    "-O2",
    "-Wall",
    "-Wextra",
    "-Werror",
    "-Wno-unused-parameter",
    "-Wno-missing-field-initializers",
]

cc_library(
    name = "WidgetRuntimeSupport",
    srcs = glob(["Sources/Support/*.cpp", "Sources/Runtime/*.cpp"]),
    hdrs = glob(["Sources/Support/*.h", "Sources/Runtime/*.h"]),
    includes = ["."],
    copts = WR_COPTS,
    deps = ["//third-party/quickjs-ng:quickjs"],
)

genrule(
    name = "TestBindingsGenerated",
    testonly = True,
    srcs = ["Tests/IDL/test.webidl"],
    outs = ["Generated/TestBindings.h", "Generated/TestBindings.cpp"],
    tools = ["//build-system/WidgetIDL"],
    cmd = " ".join([
        "$(execpath //build-system/WidgetIDL)",
        "--impl-namespace wr::testidl",
        "--table-namespace wr::testidl",
        "--header-name Generated/TestBindings.h",
        "--include Tests/TestImpl.h",
        "--output-header $(location Generated/TestBindings.h)",
        "--output-source $(location Generated/TestBindings.cpp)",
        "$(location Tests/IDL/test.webidl)",
    ]),
)

cc_library(
    name = "WidgetRuntimeTestBindings",
    testonly = True,
    srcs = ["Generated/TestBindings.cpp", "Tests/TestImpl.cpp"],
    hdrs = ["Generated/TestBindings.h", "Tests/TestImpl.h"],
    includes = ["."],
    copts = WR_COPTS,
    deps = [":WidgetRuntimeSupport"],
)

cc_library(
    name = "WidgetRuntimeTestSupport",
    testonly = True,
    srcs = ["Tests/JSHarness.cpp", "Tests/TestMain.cpp"],
    hdrs = ["Tests/JSHarness.h", "Tests/wr_test.h"],
    includes = ["."],
    copts = WR_COPTS,
    deps = [":WidgetRuntimeSupport"],
)

cc_test(
    name = "WidgetRuntimeBindingTests",
    srcs = ["Tests/BindingTests.cpp"],
    copts = WR_COPTS,
    deps = [
        ":WidgetRuntimeTestBindings",
        ":WidgetRuntimeTestSupport",
    ],
)

genrule(
    name = "BindingsGenerated",
    srcs = ["IDL/dom.webidl", "IDL/html.webidl", "IDL/events.webidl", "IDL/hr-time.webidl", "IDL/window.webidl", "IDL/webidl.webidl", "IDL/telegram.webidl", "IDL/cssom.webidl", "IDL/cssom-properties.webidl", "IDL/cssom-view.webidl", "IDL/resize-observer.webidl", "IDL/intersection-observer.webidl", "IDL/inert.webidl", "IDL/storage.webidl", "IDL/builtins.webidl", "IDL/canvas.webidl", "IDL/web-animations.webidl", "IDL/css-animations.webidl"],
    outs = ["Generated/Bindings.h", "Generated/Bindings.cpp"],
    tools = ["//build-system/WidgetIDL"],
    cmd = " ".join([
        "$(execpath //build-system/WidgetIDL)",
        "--impl-namespace wr",
        "--table-namespace wr::idl",
        "--header-name Generated/Bindings.h",
        "--include Sources/DOM/DOM.h",
        "--include Sources/Events/Events.h",
        "--include Sources/Host/Globals.h",
        "--include Sources/Canvas/Canvas.h",
        "--include Sources/Animation/WebAnimations.h",
        "--output-header $(location Generated/Bindings.h)",
        "--output-source $(location Generated/Bindings.cpp)",
        "$(location IDL/dom.webidl)",
        "$(location IDL/html.webidl)",
        "$(location IDL/events.webidl)",
        "$(location IDL/hr-time.webidl)",
        "$(location IDL/window.webidl)",
        "$(location IDL/webidl.webidl)",
        "$(location IDL/telegram.webidl)",
        "$(location IDL/cssom.webidl)",
        "$(location IDL/cssom-properties.webidl)",
        "$(location IDL/cssom-view.webidl)",
        "$(location IDL/resize-observer.webidl)",
        "$(location IDL/intersection-observer.webidl)",
        "$(location IDL/inert.webidl)",
        "$(location IDL/storage.webidl)",
        "$(location IDL/builtins.webidl)",
        "$(location IDL/canvas.webidl)",
        "$(location IDL/web-animations.webidl)",
        "$(location IDL/css-animations.webidl)",
    ]),
)

cc_library(
    name = "WidgetRuntime",
    srcs = glob([
        "Sources/Animation/*.cpp",
        "Sources/Canvas/*.cpp",
        "Sources/DOM/*.cpp",
        "Sources/Events/*.cpp",
        "Sources/Host/*.cpp",
        "Sources/Render/*.cpp",
    ]) + ["Generated/Bindings.cpp"],
    hdrs = glob([
        "Sources/Animation/*.h",
        "Sources/Canvas/*.h",
        "Sources/DOM/*.h",
        "Sources/Events/*.h",
        "Sources/Host/*.h",
        "Sources/Render/*.h",
    ]) + ["Generated/Bindings.h"],
    # The supported CSS properties (IDL/generate-css-properties.py), included by StyleDeclaration.cpp.
    # Profile 1's tables (IDL/generate-profile-tables.py), included by Profile.cpp.
    textual_hdrs = ["Sources/DOM/CSSProperties.inc", "Sources/Host/ProfileTables.inc"],
    includes = ["."],
    copts = WR_COPTS,
    deps = [
        ":WidgetRuntimeSupport",
        "//third-party/gumbo",
        # Selectors parse with litehtml's CSS Syntax tokenizer (Sources/DOM/Selectors.cpp), the policy layer's.
        "//third-party/twidget:litehtml_fork",
        # The CPU quota and the main-thread window (Sources/Host/EventLoop.cpp).
        "//third-party/widget-sandbox:CpuBudget",
        "//third-party/widget-sandbox:GesturePolicy",
        "//third-party/widget-sandbox:SdkPolicy",
    ],
    # The system ICU's public part only (Sources/Host/ICU.h): URL's IDNA, case mapping, the bidi classes.
    linkopts = ["-licucore"],
    visibility = ["//visibility:public"],
)

cc_test(
    name = "WidgetRuntimeTests",
    # About 250 s on an idle machine (the randomized oracles), past the default 300 s timeout under load.
    size = "large",
    srcs = glob(["Tests/*Tests.cpp"], exclude = [
        "Tests/BindingTests.cpp",
        "Tests/MeasurementTests.cpp",
        "Tests/BuilderHtml5libTests.cpp",
        "Tests/CorpusBootTests.cpp",
        "Tests/RenderCorpusTests.cpp",
        "Tests/CorpusGoldenTests.cpp",
        "Tests/CorpusIncrementalTests.cpp",
        "Tests/NoIOScanTests.cpp",
        "Tests/NoWorkUnitsScanTests.cpp",
        "Tests/URLDataTests.cpp",
        "Tests/IntlCasesTests.cpp",
        "Tests/BidiTests.cpp",
    ]) + [
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/IncrementalEdits.cpp",
        "Tests/IncrementalEdits.h",
        "Tests/LayerChurn.cpp",
        "Tests/LayerChurn.h",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
        "Tests/WPT/WPTSupport.cpp",
        "Tests/WPT/WPTSupport.h",
    ],
    copts = WR_COPTS,
    # Profile 1's definition, for ProfileTablesTests.
    data = ["//third-party/widget-sandbox:ProfileJSON"],
    env = {"WR_PROFILE_JSON": "$(location //third-party/widget-sandbox:ProfileJSON)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
        # WidgetContainerTests lays fixtures out through litehtml_test::TestContainer as the metrics' oracle.
        "//third-party/twidget:litehtml_test_container",
    ],
)

# The headless WPT runner (M1b plan, Task 17): the vendored testharness pages, booted on a virtual clock and compared
# with wpt-expectations.txt, which only ratchets up. Its own main (flags in Tests/WPT/WPTRunner.cpp), so it lists the
# harness sources instead of :WidgetRuntimeTestSupport (whose TestMain has a main too).
cc_test(
    name = "WidgetRuntimeWPTTests",
    size = "large",
    srcs = glob(["Tests/WPT/*.cpp", "Tests/WPT/*.h"]) + [
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/JSHarness.cpp",
        "Tests/JSHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
        "Tests/wr_test.h",
    ],
    copts = WR_COPTS,
    data = [
        "Tests/WPT/wpt-report.js",
        "wpt-expectations.txt",
        "wpt-skip.txt",
        "//third-party/wpt:LICENSE.md",
        "//third-party/wpt:TestFiles",
    ],
    env = {
        "WR_WPT_EXPECTATIONS": "$(rootpath wpt-expectations.txt)",
        "WR_WPT_LICENSE": "$(rootpath //third-party/wpt:LICENSE.md)",
        "WR_WPT_REPORT_SHIM": "$(rootpath Tests/WPT/wpt-report.js)",
        "WR_WPT_SKIP": "$(rootpath wpt-skip.txt)",
    },
    deps = [":WidgetRuntime"],
)

# html5lib's tree-construction suite through our DOM builder (M1b Task 15): the parsing coverage of spec 9.3.
cc_test(
    name = "WidgetRuntimeBuilderHtml5libTests",
    srcs = [
        "Tests/BuilderHtml5libTests.cpp",
        "Tests/Html5libDump.cpp",
        "Tests/Html5libDump.h",
    ],
    args = [
        "$(location Tests/builder-html5lib-expected-failures.txt)",
        "$(locations //third-party/gumbo:Html5libTreeConstruction)",
    ],
    copts = WR_COPTS,
    data = [
        "Tests/builder-html5lib-expected-failures.txt",
        "//third-party/gumbo:Html5libTreeConstruction",
    ],
    deps = [
        ":WidgetRuntime",
        "//third-party/gumbo:html5lib_dat",
    ],
)

cc_test(
    name = "WidgetRuntimeMeasurementTests",
    srcs = [
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/MeasurementTests.cpp",
    ],
    copts = WR_COPTS,
    data = ["//third-party/widget-sandbox:CorpusFiles"],
    env = {"WR_CORPUS_FILES": "$(locations //third-party/widget-sandbox:CorpusFiles)"},
    tags = ["manual"],
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# WPT's URL data (V5b plan, Task 5): every urltestdata.json and toascii.json case through URL, against
# Tests/url-data-expected-failures.txt, which only shrinks.
cc_test(
    name = "WidgetRuntimeURLDataTests",
    srcs = [
        "Tests/URLDataTests.cpp",
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = ["//third-party/wpt:URLData", "Tests/url-data-expected-failures.txt"],
    env = {"WR_URL_DATA": "$(locations //third-party/wpt:URLData) $(location Tests/url-data-expected-failures.txt)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# UAX #9 (Sources/Render/Bidi.cpp) against a sample of Unicode's BidiCharacterTest.txt; the whole file through
# --test_env=WR_BIDI_CHARACTER_TEST=<path> (Tests/BidiTests.cpp).
cc_test(
    name = "WidgetRuntimeBidiTests",
    srcs = ["Tests/BidiTests.cpp"],
    copts = WR_COPTS,
    data = ["Tests/bidi-character-test-sample.txt"],
    env = {"WR_BIDI_CHARACTER_TEST": "$(rootpath Tests/bidi-character-test-sample.txt)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# widget-sandbox v0.1.1's Intl fixture as a protocol check (Tests/IntlCasesTests.cpp): every case as a widget makes it,
# over a host answering only the fixture's own requests.
cc_test(
    name = "WidgetRuntimeIntlCasesTests",
    srcs = [
        "Tests/IntlCasesTests.cpp",
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = ["//third-party/widget-sandbox:IntlCases", ":IntlCasesSupport"],
    env = {"WR_INTL_CASES": "$(location //third-party/widget-sandbox:IntlCases) $(locations :IntlCasesSupport)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# The Intl cases' mapping and drift list, for the host test above and WidgetRuntimeIOS's WRIntlCasesTests.swift.
filegroup(
    name = "IntlCasesSupport",
    testonly = True,
    srcs = ["Tests/IntlCases.js", "Tests/intl-cases-expected-failures.txt"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# The headless corpus boot (M1b plan, Task 18): every non-attack corpus document booted on a virtual clock, its
# units, memory and failures by missing global or member; and the Window's cost on the DOM context. Manual, -c opt.
cc_test(
    name = "WidgetRuntimeCorpusBootTests",
    srcs = [
        "Tests/CorpusBootTests.cpp",
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = ["//third-party/widget-sandbox:CorpusFiles"],
    env = {"WR_CORPUS_FILES": "$(locations //third-party/widget-sandbox:CorpusFiles)"},
    tags = ["manual"],
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# The corpus and attack gates (M1c plan, Task 11): every corpus document booted with a render tree, run, flushed and
# held to build-path and mirror parity; every attack document loads nothing. The whole corpus, so it is large.
cc_test(
    name = "WidgetRuntimeRenderCorpusTests",
    size = "large",
    srcs = [
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/RenderCorpusTests.cpp",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = ["//third-party/widget-sandbox:CorpusFiles"],
    env = {"WR_CORPUS_FILES": "$(locations //third-party/widget-sandbox:CorpusFiles)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# The corpus goldens (spec section 9 item 2): every non-attack corpus document's results in deterministic mode, compared
# with Tests/CorpusGoldens/. `WR_GOLDENS_UPDATE=1 bazel run` this target to record them (the header of the source).
cc_test(
    name = "WidgetRuntimeCorpusGoldenTests",
    size = "large",
    srcs = [
        "Tests/CorpusGoldenTests.cpp",
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = ["//third-party/widget-sandbox:CorpusFiles"] + glob(["Tests/CorpusGoldens/**"], allow_empty = True),
    env = {"WR_CORPUS_FILES": "$(locations //third-party/widget-sandbox:CorpusFiles)"},
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# Every corpus document and client fixture runs incrementally: one build, at the boot, and no inconsistency.
cc_test(
    name = "WidgetRuntimeCorpusIncrementalTests",
    size = "large",
    srcs = [
        "Tests/DOMHarness.cpp",
        "Tests/DOMHarness.h",
        "Tests/FakeRenderHost.cpp",
        "Tests/FakeRenderHost.h",
        "Tests/HostHarness.cpp",
        "Tests/HostHarness.h",
        "Tests/LayerChurn.cpp",
        "Tests/LayerChurn.h",
        "Tests/CorpusIncrementalTests.cpp",
        "Tests/RenderHarness.cpp",
        "Tests/RenderHarness.h",
        "Tests/VirtualTime.cpp",
        "Tests/VirtualTime.h",
    ],
    copts = WR_COPTS,
    data = [
        "//third-party/widget-sandbox:CorpusFiles",
        "//submodules/TelegramUI/Components/MessageWidget/Fixtures:WidgetFixtures",
    ],
    env = {
        "WR_CORPUS_FILES": "$(locations //third-party/widget-sandbox:CorpusFiles)",
        "WR_FIXTURES": "$(locations //submodules/TelegramUI/Components/MessageWidget/Fixtures:WidgetFixtures)",
    },
    deps = [
        ":WidgetRuntime",
        ":WidgetRuntimeTestSupport",
    ],
)

# Nothing in the runtime may open a URL, a file or a socket (spec hard rules): the sources compiled into :WidgetRuntime,
# scanned with comments and strings stripped.
filegroup(
    name = "ScanSources",
    testonly = True,
    srcs = glob([
        "Sources/**/*.cpp",
        "Sources/**/*.h",
    ]) + [
        "Generated/Bindings.cpp",
        "Generated/Bindings.h",
        "//third-party/gumbo:ScanSources",
        "//third-party/quickjs-ng:ScanSources",
        "//third-party/twidget:ScanSources",
    ],
)

cc_test(
    name = "WidgetRuntimeNoIOScanTests",
    srcs = [
        "Tests/NoIOScanTests.cpp",
        "Tests/SourceScan.h",
        "Tests/TestMain.cpp",
        "Tests/wr_test.h",
    ],
    copts = WR_COPTS,
    data = [":ScanSources"],
    env = {"WR_SCAN_FILES": "$(locations :ScanSources)"},
    includes = ["."],
)

# No work units in the runtime, its iOS glue or quickjs-ng (the CPU-clock limits plan, Task 7):
# `./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeNoWorkUnitsScanTests`.
filegroup(
    name = "WorkScanSources",
    testonly = True,
    srcs = glob([
        "Sources/**/*.cpp",
        "Sources/**/*.h",
    ]) + [
        "//submodules/TelegramUI/Components/MessageWidget/WidgetRuntimeIOS:ScanSources",
        "//third-party/quickjs-ng:ScanSources",
    ],
)

cc_test(
    name = "WidgetRuntimeNoWorkUnitsScanTests",
    srcs = [
        "Tests/NoWorkUnitsScanTests.cpp",
        "Tests/SourceScan.h",
        "Tests/TestMain.cpp",
        "Tests/wr_test.h",
    ],
    copts = WR_COPTS,
    data = [":WorkScanSources"],
    env = {"WR_SCAN_FILES": "$(locations :WorkScanSources)"},
    includes = ["."],
)
