load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

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
swift_library(
    name = "RichTextEditorUIKit",
    module_name = "RichTextEditorUIKit",
    srcs = glob([
        "Sources/RichTextEditorUIKit/**/*.swift",
    ]),
    data = [
        ":RichTextEditorUIKitResources",
    ],
    deps = [
        ":RichTextEditorCore",
        "//submodules/AppBundle",
        "//submodules/MosaicLayout:MosaicLayout",
    ],
    visibility = [
        "//visibility:public",
    ],
)
