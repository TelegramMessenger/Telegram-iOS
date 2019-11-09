
ASYNCDISPLAYKIT_EXPORTED_HEADERS = glob([
  "Source/*.h",
  "Source/Details/**/*.h",
  "Source/Layout/*.h",
  "Source/Base/*.h",
  "Source/Debug/AsyncDisplayKit+Debug.h",
  "Source/TextKit/ASTextNodeTypes.h",
  "Source/TextKit/ASTextKitComponents.h",
], exclude = ["_Source/AsyncDisplayKit.h"]
)

ASYNCDISPLAYKIT_PRIVATE_HEADERS = glob([
    "Source/**/*.h"
  ],
  exclude = ASYNCDISPLAYKIT_EXPORTED_HEADERS + ["_Source/AsyncDisplayKit.h"],
)

exported_headers_rule_name = "AsyncDisplayKit_ExportedHeaders"
exported_headers_path = "includedir"
name = "AsyncDisplayKit"
headers = ASYNCDISPLAYKIT_EXPORTED_HEADERS

genrule(
  name = exported_headers_rule_name,
  srcs = headers,
  outs = [exported_headers_path + "/" + name + "/" + x.split('/')[::-1][0] for x in headers],
  cmd  = "cp $(SRCS) $(RULEDIR)" + "/" + exported_headers_path + "/" + name,
)
exported_headers = [":" + exported_headers_rule_name]

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
        "Source/Base/*.m",
    ]) + ASYNCDISPLAYKIT_EXPORTED_HEADERS + ASYNCDISPLAYKIT_PRIVATE_HEADERS,
    hdrs = exported_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    includes = [
      exported_headers_path,
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
