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
    copts = [
        "-Werror",
    ],
    hdrs = public_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    includes = [
      "Source/PublicHeaders",
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
