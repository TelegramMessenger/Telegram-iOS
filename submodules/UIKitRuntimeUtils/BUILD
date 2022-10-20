
objc_library(
    name = "UIKitRuntimeUtils",
    enable_modules = True,
    module_name = "UIKitRuntimeUtils",
    srcs = glob([
        "Source/UIKitRuntimeUtils/*.m",
    ]),
    copts = [
        "-Werror",
    ],
    hdrs = glob([
        "Source/UIKitRuntimeUtils/*.h",
    ]),
    includes = [
      #"Source",
    ],
    deps = [
      "//submodules/AsyncDisplayKit:AsyncDisplayKit",
      "//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    ],
    sdk_frameworks = [
      "Foundation",
      "UIKit",
    ],
    visibility = [
        "//visibility:public",
    ],
)
