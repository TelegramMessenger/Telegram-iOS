load("@build_bazel_rules_swift//swift:swift.bzl", "swift_binary")

# The TL code generator, built for the host and run by the TelegramApiGenerated genrule in
# submodules/TelegramApi/BUILD. SwiftPM builds the same sources for the generator's own tests and
# for submodules/TelegramApi/generate-swiftpm.sh.
swift_binary(
    name = "SwiftTL",
    module_name = "SwiftTL",
    srcs = glob(["Sources/SwiftTL/**/*.swift"]),
    # SchemaBlob compresses the schema table with zlib.
    linkopts = ["-lz"],
    visibility = ["//submodules/TelegramApi:__pkg__"],
)
