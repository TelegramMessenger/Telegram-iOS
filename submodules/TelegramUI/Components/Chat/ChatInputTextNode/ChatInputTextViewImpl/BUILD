
objc_library(
    name = "ChatInputTextViewImpl",
    enable_modules = True,
    module_name = "ChatInputTextViewImpl",
    srcs = glob([
        "Sources/**/*.m",
        "Sources/**/*.c",
        "Sources/**/*.h",
    ], allow_empty=True),
    hdrs = glob([
        "PublicHeaders/**/*.h",
    ]),
    includes = [
        "PublicHeaders",
    ],
    sdk_frameworks = [
        "Foundation",
    ],
    visibility = [
        "//visibility:public",
    ],
)
