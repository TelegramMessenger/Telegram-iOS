load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "objc_library",
)

public_headers = glob([
  "Source/PublicHeaders/AsyncDisplayKit/*.h",
])

private_headers = glob([
  "Source/*.h",
])

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
    ]) + private_headers,
    hdrs = public_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
      "QuartzCore",
      "CoreMedia",
      "CoreText",
      "CoreGraphics",
    ],
    visibility = [
        "//visibility:public",
    ],
)
