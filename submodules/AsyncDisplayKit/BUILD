
ASYNCDISPLAYKIT_EXPORTED_HEADERS = glob([
  "Source/*.h",
  "Source/Details/**/*.h",
  "Source/Layout/*.h",
  "Source/Base/*.h",
  "Source/Debug/AsyncDisplayKit+Debug.h",
  "Source/TextKit/ASTextNodeTypes.h",
  "Source/TextKit/ASTextKitComponents.h"
], exclude = ["Source/AsyncDisplayKit.h"])

ASYNCDISPLAYKIT_PRIVATE_HEADERS = glob([
    "Source/**/*.h"
  ],
  exclude = ASYNCDISPLAYKIT_EXPORTED_HEADERS + ["Source/AsyncDisplayKit.h"],
)

exported_headers_rule_name = "AsyncDisplayKit_ExportedHeaders"
private_headers_rule_name = "AsyncDisplayKit_PrivateHeaders"
exported_headers_path = "includedir"
private_headers_path = "privateincludedir"
name = "AsyncDisplayKit"
headers = ASYNCDISPLAYKIT_EXPORTED_HEADERS

genrule(
  name = exported_headers_rule_name,
  srcs = headers,
  # Headers can be nested multiple levels, so we use `x.split('/')[::-1][0] for x in headers` to get their basenames
  outs = [exported_headers_path + "/" + name + "/" + x.split('/')[::-1][0] for x in headers],
  # Finally we copy all headers to the `exported_headers_path` directory
  cmd  = "cp $(SRCS) $(RULEDIR)" + "/" + exported_headers_path + "/" + name,
)
exported_headers = [":" + exported_headers_rule_name]

genrule(
  name = private_headers_rule_name,
  srcs = ASYNCDISPLAYKIT_PRIVATE_HEADERS,
  outs = [private_headers_path + "/" + name + "/" + x.split('/')[::-1][0] for x in ASYNCDISPLAYKIT_PRIVATE_HEADERS],
  cmd  = "cp $(SRCS) $(RULEDIR)" + "/" + private_headers_path + "/" + name,
)
private_headers = [":" + private_headers_rule_name]

objc_library(
    name = "AsyncDisplayKit",
    enable_modules = True,
    module_name = "AsyncDisplayKit",
    srcs = glob([
        "Source/**/*.m",
        "Source/**/*.mm",
        "Source/Base/*.m",
    ]) + private_headers,
    hdrs = exported_headers,
    defines = [
        "MINIMAL_ASDK",
    ],
    copts = [
      #"-I$(locations :AsyncDisplayKit_PrivateHeaders)",
    ],
    includes = [
      exported_headers_path,
      private_headers_path,
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
