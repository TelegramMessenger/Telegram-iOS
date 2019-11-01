
ASYNCDISPLAYKIT_EXPORTED_HEADERS = glob([
  "Source/*.h",
  "Source/Details/**/*.h",
  "Source/Layout/*.h",
  "Source/Base/*.h",
  "Source/Debug/AsyncDisplayKit+Debug.h",
  "Source/TextKit/ASTextNodeTypes.h",
  "Source/TextKit/ASTextKitComponents.h"
])

ASYNCDISPLAYKIT_PRIVATE_HEADERS = glob([
    "Source/**/*.h"
  ],
  exclude = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
)

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
        "Source/Base/*.m",
    ]) + ASYNCDISPLAYKIT_PRIVATE_HEADERS,
    hdrs = ASYNCDISPLAYKIT_EXPORTED_HEADERS,
    defines = [
        "MINIMAL_ASDK",
    ],
    sdk_frameworks = [
        "QuartzCore",
        "CoreMedia",
        "CoreText",
        "CoreGraphics",
    ],
    visibility = [
        "//visibility:public",
    ],
)
