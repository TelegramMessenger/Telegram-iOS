load(
    "@rules_apple_extras//apple:objc_library.bzl",
    "my_swift_library",
)

my_swift_library(
    name = "Display",
    module_name = "Display",
    srcs = glob([
        "Source/**/*.swift",
    ]),
    deps = [
    	"//submodules/ObjCRuntimeUtils:ObjCRuntimeUtils",
    	"//submodules/UIKitRuntimeUtils:UIKitRuntimeUtils",
        "//submodules/AppBundle:AppBundle",
    	"//submodules/SSignalKit/SwiftSignalKit:SwiftSignalKit",
        "//submodules/Markdown:Markdown",
        "//submodules/AsyncDisplayKit:AsyncDisplayKit",
    ],
    copts = [
        "-Isubmodules/AsyncDisplayKit/Source/PublicHeaders",
    ],
    visibility = [
        "//visibility:public",
    ],
)
