# web-platform-tests at d2727a54348e (VENDOR.md): the test data WidgetRuntime's headless runner serves
# (//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeWPTTests). Test data only: never in
# the app.
exports_files(["LICENSE.md"])

filegroup(
    name = "TestFiles",
    testonly = True,
    srcs = glob(["resources/**", "common/**", "dom/**", "html/**", "css/**", "web-animations/**"]) + ["LICENSE.md"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:__pkg__"],
)

# The URL Standard's parsing and IDNA cases (V5b plan, Task 5), driven by
# //submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:WidgetRuntimeURLDataTests.
filegroup(
    name = "URLData",
    testonly = True,
    srcs = ["url/resources/toascii.json", "url/resources/urltestdata.json"],
    visibility = ["//submodules/TelegramUI/Components/MessageWidget/WidgetRuntime:__pkg__"],
)
