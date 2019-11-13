
public_headers = glob([
  "Source/Public/AsyncDisplayKit/*.h",
])

private_headers = glob([
  "Source/Implementation/AsyncDisplayKit/*.h",
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
    copts = [
      "-w",
      "-isystem",
      "submodules/AsyncDisplayKit/Source/Implementation",
    ],
    includes = [
      "Source/Public",
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
