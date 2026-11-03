load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")
load("@rules_cc//cc:objc_library.bzl", "objc_library")
load("@build_bazel_rules_apple//apple:ios.bzl", "ios_unit_test")
load("@build_bazel_rules_apple//apple/testing/default_runner:ios_test_runner.bzl", "ios_test_runner")

# The generated sources are build outputs, made from swift_scheme.tl on every build. The file list
# is fixed (SwiftTL --swift-file-count), so it can be declared here. Changing the count only
# changes how the types are spread over the files.
SWIFT_FILE_COUNT = 44

GENERATED_SWIFT = ["Generated/Api%d.swift" % index for index in range(SWIFT_FILE_COUNT)]

GENERATED_TEST_SWIFT = [
    "Generated/Tests/SchemaFixtures.swift",
    "Generated/Tests/SchemaAccessorProbes.swift",
]

genrule(
    name = "TelegramApiGenerated",
    srcs = ["swift_scheme.tl"],
    outs = GENERATED_SWIFT + ["Generated/TLApiSchemaData.m"] + GENERATED_TEST_SWIFT,
    tools = ["//build-system/SwiftTL:SwiftTL"],
    cmd = " ".join([
        "$(execpath //build-system/SwiftTL:SwiftTL)",
        "$(execpath swift_scheme.tl)",
        "$(RULEDIR)/Generated",
        "--swift-file-count=%d" % SWIFT_FILE_COUNT,
        "--objc-output=$(RULEDIR)/Generated",
        "--fixtures-output=$(RULEDIR)/Generated/Tests/SchemaFixtures.swift",
    ]),
)

# The globs below are deliberately not recursive: the */SwiftPMGenerated directories hold the
# SwiftPM copy of the generated sources (generate-swiftpm.sh), which Bazel must never compile.
objc_library(
    name = "TelegramApiObjC",
    enable_modules = True,
    module_name = "TelegramApiObjC",
    # MRC via copts (they follow Bazel's -fobjc-arc); TLObject.m #errors if ARC is on.
    # TLObjectInternal.h is private to TLObject.m and TLEngine.m; listing it makes it an input of
    # their compiles (cache keys, sandbox).
    srcs = glob(["ObjC/Sources/*.m", "ObjC/Sources/*.h"]) + ["Generated/TLApiSchemaData.m"],
    hdrs = glob(["ObjC/PublicHeaders/**/*.h"]),
    includes = ["ObjC/PublicHeaders"],
    copts = ["-fno-objc-arc", "-Werror", "-Wall"],
    # Propagates to dependents (and Swift's clang importer): see TL_DIRECT in TLObject.h.
    defines = ["TL_OBJC_DIRECT=1"],
    sdk_frameworks = ["Foundation"],
    sdk_dylibs = ["libz"],
    # Only TelegramCore talks to the API layer: see TelegramApi's visibility below.
    visibility = ["//submodules/TelegramCore:__pkg__"],
)

swift_library(
    name = "TelegramApi",
    module_name = "TelegramApi",
    copts = [
        "-warnings-as-errors",
    ],
    srcs = glob([
        "Sources/*.swift",
    ]) + GENERATED_SWIFT,
    deps = [
        ":TelegramApiObjC",
    ],
    # Only TelegramCore (and its tests) may depend on the API layer; every other module goes
    # through TelegramCore's own types. Keeps the Api surface out of the rest of the app.
    visibility = [
        "//submodules/TelegramCore:__pkg__",
    ],
)

objc_library(
    name = "TLRuntimeFixture",
    testonly = True,
    enable_modules = True,
    module_name = "TLRuntimeFixture",
    srcs = ["TestSupport/RuntimeFixture/TLRuntimeFixture.m"],
    copts = ["-fno-objc-arc"],
    hdrs = ["TestSupport/RuntimeFixture/include/TLRuntimeFixture.h"],
    includes = ["TestSupport/RuntimeFixture/include"],
    deps = [":TelegramApiObjC"],
)

swift_library(
    name = "TelegramApiTestsLib",
    testonly = True,
    module_name = "TelegramApiTests",
    srcs = glob(["Tests/*.swift"]) + GENERATED_TEST_SWIFT,
    deps = [
        ":TelegramApi",
        ":TelegramApiObjC",
        ":TLRuntimeFixture",
    ],
)

ios_test_runner(
    name = "TelegramApiTestRunner",
    device_type = "iPhone 17",
    os_version = "26.5",
)

ios_unit_test(
    name = "TelegramApiTests",
    minimum_os_version = "15.0",
    runner = ":TelegramApiTestRunner",
    deps = [":TelegramApiTestsLib"],
)
