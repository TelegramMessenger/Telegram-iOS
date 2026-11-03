load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")
# Bazel 9 removed the built-in `objc_library`; it must be loaded explicitly.
load("@rules_cc//cc:objc_library.bzl", "objc_library")

swift_library(
    name = "RichTextEditorCore",
    module_name = "RichTextEditorCore",
    srcs = glob([
        "Sources/RichTextEditorCore/**/*.swift",
    ]),
    visibility = [
        "//visibility:public",
    ],
)

plist_fragment(
    name = "RichTextEditorUIKitResourcesBundleInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.RichTextEditorUIKitResources</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>RichTextEditorUIKitResources</string>
    """
)

apple_resource_bundle(
    name = "RichTextEditorUIKitResources",
    infoplists = [
        ":RichTextEditorUIKitResourcesBundleInfoPlist",
    ],
    resources = glob([
        "Sources/RichTextEditorUIKit/Resources/Media.xcassets/**",
    ]),
)

# NO `copts` ATTRIBUTE ON EITHER TARGET — and as of Task 40b that is ORDINARY, not load-bearing.
#
# For the length of the input-backend seam's Phase 5 (Tasks 35-40b) this note said the opposite, and
# emphatically: `DocumentCanvasView.anchor`/`.head` carried DEPRECATED setters whose warnings WERE
# the conversion worklist (over a thousand of them at the peak), so adding `-warnings-as-errors` to
# match the 676 sibling BUILD files that do pass it would have turned that worklist into build errors
# and stranded the phase mid-conversion. **Task 40b deleted those setters.** The properties are now
# read-only projections of the backend, they emit zero deprecation warnings, and adding `copts` here
# strands nothing. The prohibition is RETIRED; the matching paragraph in `DocumentCanvasView.swift`'s
# `anchor` doc comment was retired in the same commit.
#
# Adding `-warnings-as-errors` is therefore now an ordinary change — worth doing, and deliberately
# NOT folded into Task 40b's diff, which is a single-authority gate and should not also be the commit
# that turns a thousand-file package's warning policy over. Whoever does it should expect to fix real
# warnings, not to discover a hidden dependency.
#
# One lesson from the retired note is worth keeping, because it is about verification and not about
# this attribute: the note originally handed the reader `grep -c "copts\|warnings-as-errors"` and said
# "expect 0". It returns 3 — because THAT COMMENT contains both tokens — and the sibling count reads
# 677 for the same reason. The invariant was intact the whole time; only the check was broken, and it
# pointed the reader at exactly the wrong conclusion. **A verification command recorded next to the
# thing it verifies must survive being written down there.** Match on structure
# (`grep -nE '^[[:space:]]*copts[[:space:]]*='`), then re-run it where it will live.
# Vendored InputDec UIKit behavior kernel. These sources live OUTSIDE Sources/RichTextEditorUIKit,
# whose glob is `**/*.swift` and would silently ignore .m/.h files.
# DO NOT HAND-EDIT — see Sources/RichTextInputDecObjC/Vendor/VENDOR.md.
objc_library(
    name = "RichTextInputDecObjC",
    module_name = "RichTextInputDecObjC",
    enable_modules = True,
    srcs = glob([
        "Sources/RichTextInputDecObjC/**/*.m",
        "Sources/RichTextInputDecObjC/**/*.h",
    ], exclude = [
        "Sources/RichTextInputDecObjC/include/**/*.h",
    ], allow_empty = False),
    hdrs = glob([
        "Sources/RichTextInputDecObjC/include/**/*.h",
    ]),
    includes = [
        "Sources/RichTextInputDecObjC/include",
        "Sources/RichTextInputDecObjC/include/Kernel",
    ],
    copts = [
        "-fobjc-arc",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# The InputDec text engine (78 files, 16,492 lines), brought across from ~/Documents/InputDec and
# OWNED HERE since 2026-09-15: that tree lost its .git and is an archive, so these files are edited
# in this repo like any other source. The SHA-256 lists and Scripts/verify-ported-files.sh that used
# to keep the two copies in step are deleted with the workflow they served. Where the code came
# from, the revision each file was last taken at, and every deviation from that tree are recorded in
# Sources/RichTextInputDecUpstream/PROVENANCE.md — read it before editing, those deviations are
# facts about the code.
#
# Headers are FLAT in include/ although upstream keeps them under TextView/, TextView/Autoscroll/
# and PrivateUIKit/. That is deliberate and load-bearing: every quoted #import in these 78 files
# is a bare basename, and three of them cross an upstream directory boundary
# (IDBlockTextViewInternal.h -> IDVerticalAutoscrollGeometry.h and two kernel headers). Flat
# headers make every header-to-header import resolve sibling-relative, so neither build system
# needs a search path to compile a header — which matters because SwiftPM propagates only
# publicHeadersPath to dependents, not cSettings header search paths. The .m files keep upstream's
# TextView/ vs PrivateUIKit/ grouping; they import headers via `includes` below.
#
# NO `-warnings-as-errors`, matching the RichTextInputDecObjC sibling above and unlike most of
# this repo. Deliberate: this is verbatim third-party source, and the alternative to tolerating
# its warnings is editing it to silence them, which is precisely what the port exists to avoid.
objc_library(
    name = "RichTextInputDecUpstream",
    module_name = "RichTextInputDecUpstream",
    enable_modules = True,
    srcs = glob([
        "Sources/RichTextInputDecUpstream/**/*.m",
        "Sources/RichTextInputDecUpstream/Internal/**/*.h",
    ], allow_empty = False),
    hdrs = glob([
        "Sources/RichTextInputDecUpstream/include/**/*.h",
    ]),
    includes = [
        # PUBLIC only. `includes` propagates transitively, so anything listed here lands on the
        # header search path of every dependent -- which is exactly what deviation 6 exists to
        # prevent for Internal/. That one is a private -I in copts below instead.
        "Sources/RichTextInputDecUpstream/include",
    ],
    copts = [
        "-fobjc-arc",
        "-Isubmodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecUpstream/Internal",
    ],
    deps = [
        # For the vendored behavior kernel headers: IDBlockTextViewInternal.h imports
        # IDUIKitBehaviorBackend.h / IDUIKitBehaviorCapabilities.h, and IDBlockTextView.m imports
        # IDUIKitBehaviorKernel.h. Their include dirs are propagated by that target's `includes`.
        ":RichTextInputDecObjC",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# The HOST LAYER over the ported engine: observation and host-driven content replacement, added by
# subclass and handler-chaining. It edits no ported file.
#
# It needs the engine's Internal/ headers, which `RichTextInputDecUpstream` deliberately does NOT
# propagate (that module keeps Internal/ as a private -I precisely so dependents do not inherit it).
# So this target repeats the private -I for itself.
objc_library(
    name = "RichTextInputDecHost",
    module_name = "RichTextInputDecHost",
    enable_modules = True,
    srcs = glob([
        "Sources/RichTextInputDecHost/**/*.m",
    ], allow_empty = False),
    hdrs = glob([
        "Sources/RichTextInputDecHost/include/**/*.h",
    ]),
    includes = [
        "Sources/RichTextInputDecHost/include",
    ],
    copts = [
        "-fobjc-arc",
        "-Isubmodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecUpstream/Internal",
    ],
    deps = [
        ":RichTextInputDecUpstream",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# The engine-backed editor. THIS TARGET IS WHY THE ENGINE IS IN THE APP AT ALL.
#
# Until upstream 442f395 no target here could depend on `:RichTextInputDecUpstream`, because
# `IDBlockTextView.m` declared a `+load` that ran before `main()` and `@throw`s on four paths — a
# launch-time abort no runtime flag could gate. That commit moved the install into the initializer's
# `@try`, so the throw is now a failed CONSTRUCTION, reached only when the `useInputDecEngine` Debug
# Settings flag asks for this editor, and the edge is safe. No host falls back yet: with the flag on,
# a construction that fails (a runtime whose private surface moved) raises through Swift.
#
# The guarantee is mechanically pinned, and the pin moved with the reason:
# `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift` used to
# assert these two targets could not exist. It now asserts they DO exist and that the port contains
# no `+load` at all — the real invariant rather than a proxy for it.
swift_library(
    name = "RichTextEngineEditor",
    module_name = "RichTextEngineEditor",
    srcs = glob([
        "Sources/RichTextEngineEditor/**/*.swift",
    ], allow_empty = False),
    copts = [
        "-warnings-as-errors",
    ],
    deps = [
        ":RichTextEditorCore",
        ":RichTextEditorUIKit",
        ":RichTextInputDecUpstream",
        ":RichTextInputDecHost",
    ],
    visibility = [
        "//visibility:public",
    ],
)

swift_library(
    name = "RichTextEditorUIKit",
    module_name = "RichTextEditorUIKit",
    srcs = glob([
        "Sources/RichTextEditorUIKit/**/*.swift",
    ], exclude = [
        # PHASE 2 OF THE INPUTDEC PORT — the adapter over the REAL upstream engine
        # (`IDUpstreamInputBackend`). It `import`s `RichTextInputDecUpstream`, so compiling it into
        # this target would need a `deps` edge to that module, which this target does not take: the
        # app build does not compile these files, and the SwiftPM package (TEST-ONLY here — Bazel
        # builds the app) does, by adding the dependency there.
        #
        # This exclusion is no longer what keeps the engine out of the app. The engine IS in the app,
        # through `:RichTextEngineEditor` (see that target), so
        # `bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'` is NOT empty. And
        # the reason this note used to give — `IDBlockTextView.m`'s pre-`main()` `+load` that
        # `@throw`s an uncaught NSException — is gone: upstream 442f395 moved it into the
        # initializer, and `test_thePortContainsNoLoadMethod` pins that no `+load` is left.
        #
        # THE DIVERGENCE IS MECHANICALLY PINNED, because "a file missing from a target's srcs
        # silently does not exist" is a trap this repo has paid for:
        # `Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift`
        # asserts this exclude line is here, that it matches live files, and that `deps` below still
        # has NO edge to `:RichTextInputDecUpstream`. Deleting the exclude without adding the edge
        # is a loud compile error (`no such module`); adding the edge is what the boundary test
        # catches.
        #
        # Remove BOTH — this exclude and the `deps` prohibition — in the same commit, if this
        # adapter is ever to compile into the app.
        "Sources/RichTextEditorUIKit/InputBackend/InputDec/Upstream/**/*.swift",
    ]),
    # Task B6: enables the InputDec backend's isSupported() gate (Swift needs `swiftc -D`, not a
    # C preprocessor define, hence `copts` rather than `defines`). Mirrors Package.swift's
    # `swiftSettings: [.define(...)]` on the same target. Production selects `.legacy` unless the
    # Debug Settings flag `inputDecTextBackend` (default off) asks for `.inputDecIfSupported`
    # (RichTextInputCanvasFactory).
    copts = [
        "-DTG_RICHTEXT_INPUTDEC_ENABLED",
    ],
    data = [
        ":RichTextEditorUIKitResources",
    ],
    deps = [
        ":RichTextEditorCore",
        ":RichTextInputDecObjC",
        # NO EDGE TO :RichTextInputDecUpstream, DELIBERATELY: the only files here that would need
        # it are the excluded phase-2 adapter (see `exclude` above). The engine reaches the app
        # through `:RichTextEngineEditor` instead. (This note used to forbid the edge because of a
        # pre-`main()` `+load` in the engine; that `+load` is gone, upstream 442f395.)
        #
        # What keeps the adapter from rotting while it is out of the app build: the SwiftPM test
        # target depends on the engine and InputDecUpstreamHostSmokeTests cannot pass unless it
        # compiles AND runs for iOS.
        "//submodules/AppBundle",
        "//submodules/MosaicLayout:MosaicLayout",
    ],
    visibility = [
        "//visibility:public",
    ],
)
