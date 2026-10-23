load("@build_bazel_rules_apple//apple:resources.bzl", "apple_resource_bundle", "apple_resource_group")
load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library", "swift_test")
load("//build-system/bazel-utils:plist_fragment.bzl", "plist_fragment")

# The corpus by folder (names repeat across folders: generated/with-profile and without-profile share 21), at
# corpus/<folder>/… in a test bundle. Test data: never in the app.
apple_resource_group(
    name = "WidgetCorpus",
    testonly = True,
    structured_resources = glob(["corpus/**"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# Profile 1's definition (VENDOR.md), for the host test that checks the generated tables against it.
filegroup(
    name = "ProfileJSON",
    testonly = True,
    srcs = ["profile/profile.json"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# The Intl parity fixture (VENDOR.md), for WidgetRuntime's host and iOS Intl tests.
filegroup(
    name = "IntlCases",
    testonly = True,
    srcs = ["fixtures/intl-cases.json"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# widget-sandbox's iOS glue for the `intl` capability (VENDOR.md): upstream's IntlBridge and CLDR plural rules,
# Foundation only, behind our entry point. WidgetRuntime's Intl asks it for every answer that needs locale data.
swift_library(
    name = "WidgetSandboxIntl",
    module_name = "WidgetSandboxIntl",
    srcs = [
        "ios/IntlBridge.swift",
        "ios/PluralRules.swift",
        "ios/WidgetSandboxIntl.swift",
    ],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

# The glue alone against the Intl fixture, on the host's Foundation:
# `./build-input/bazel-9.2.0-darwin-arm64 test //third-party/widget-sandbox:WidgetSandboxIntlTests`.
swift_test(
    name = "WidgetSandboxIntlTests",
    srcs = ["ios/Tests/WidgetSandboxIntlTests.swift"],
    data = [":IntlCases"],
    env = {"WR_INTL_CASES": "$(rootpath :IntlCases)"},
    deps = [":WidgetSandboxIntl"],
)

# The corpus' documents as plain files, for host tests (WidgetRuntime's measurements).
filegroup(
    name = "CorpusFiles",
    testonly = True,
    srcs = glob(["corpus/**/*.html"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

plist_fragment(
    name = "WidgetCorpusInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WidgetCorpus</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WidgetCorpus</string>
    """
)

# DEBUG app builds only (Debug Settings' widget corpus insertion): every folder but the attacks, at <folder>/….
apple_resource_bundle(
    name = "WidgetCorpusBundle",
    bundle_name = "WidgetCorpus",
    infoplists = [":WidgetCorpusInfoPlist"],
    structured_resources = glob(["corpus/**"], exclude = ["corpus/attacks/**"]),
    strip_structured_resources_prefixes = ["corpus"],
    visibility = ["//visibility:public"],
)

# The conformance set (CLIENTS.md) at conformance/… in a test bundle: the widgets, refs, channel.json, manifest.json,
# catalogue.json and the report tool. Test data: never in the app.
apple_resource_group(
    name = "WidgetConformance",
    testonly = True,
    structured_resources = glob(["conformance/**"]),
    visibility = ["//submodules/TelegramUI/Components/MessageWidget:__subpackages__"],
)

plist_fragment(
    name = "WidgetConformanceInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.WidgetConformance</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>WidgetConformance</string>
    """
)

# DEBUG app builds only (Debug Settings' conformance insertion into Saved Messages): the widgets, the reference
# pictures posted beside them, and channel.json, at <path>/… without the conformance/ prefix.
apple_resource_bundle(
    name = "WidgetConformanceBundle",
    bundle_name = "WidgetConformance",
    infoplists = [":WidgetConformanceInfoPlist"],
    structured_resources = glob([
        "conformance/auto/**",
        "conformance/visual/**",
        "conformance/refs/visual/**",
        "conformance/channel.json",
        # The conformance runner's test list (Tests/WidgetHarness).
        "conformance/manifest.json",
    ]),
    strip_structured_resources_prefixes = ["conformance"],
    visibility = ["//visibility:public"],
)

config_setting(
    name = "debug_build",
    values = {"compilation_mode": "dbg"},
    visibility = ["//visibility:public"],
)
