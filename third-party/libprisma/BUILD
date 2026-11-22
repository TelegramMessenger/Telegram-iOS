load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@rules_cc//cc:cc_test.bzl", "cc_test")

load(
    "@build_bazel_rules_apple//apple:resources.bzl",
    "apple_resource_bundle",
    "apple_resource_group",
)
load("//build-system/bazel-utils:plist_fragment.bzl",
    "plist_fragment",
)

filegroup(
    name = "LibprismaResources",
    srcs = glob([
        "Resources/**/*.dat",
    ]),
    visibility = ["//visibility:public"],
)

plist_fragment(
    name = "LibprismaInfoPlist",
    extension = "plist",
    template =
    """
    <key>CFBundleIdentifier</key>
    <string>org.telegram.Libprisma</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleName</key>
    <string>Libprisma</string>
    """
)

apple_resource_bundle(
    name = "LibprismaBundle",
    infoplists = [
        ":LibprismaInfoPlist",
    ],
    resources = [
        ":LibprismaResources",
    ],
)
 
objc_library(
    name = "libprisma",
    enable_modules = True,
    module_name = "libprisma",
    srcs = glob([
        "Sources/**/*.c",
        "Sources/**/*.cpp",
        "Sources/**/*.m",
        "Sources/**/*.mm",
        "Sources/**/*.h",
        "Sources/**/*.hpp",
    ], allow_empty=True),
    hdrs = glob([
        "include/libprisma/*.h",
    ]),
    includes = [
        "include",
    ],
    data = [
        ":LibprismaBundle",
    ],
    copts = [
    ],
    deps = [
        "//third-party/boost_regex",
    ],
    sdk_frameworks = [
        "Foundation",
        "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)

# Host C++ regression test for the code-block highlighter. Compiles only the
# pure-C++ core (not Syntaxer.mm, which needs UIKit) plus the header-only
# boost_regex, and highlights the real shipped grammars.dat. Runs on the host
# via `bazel test`, like the tgcalls cc_tests. See Tests/*.cpp for the case.
cc_test(
    name = "SyntaxHighlighterTests",
    srcs = [
        "Tests/SyntaxHighlighterRecursionTests.cpp",
        "Sources/SyntaxHighlighter.cpp",
        "Sources/SyntaxHighlighter.h",
        "Sources/LanguageTree.cpp",
        "Sources/LanguageTree.h",
        "Sources/TokenList.cpp",
        "Sources/TokenList.h",
        "Sources/Highlight.cpp",
        "Sources/Highlight.h",
    ],
    copts = [
        "-std=c++17",
        "-Ithird-party/libprisma/Sources",
    ],
    data = [
        "Resources/grammars.dat",
    ],
    args = [
        "$(location Resources/grammars.dat)",
    ],
    deps = [
        "//third-party/boost_regex",
    ],
    visibility = [
        "//visibility:public",
    ],
)
