load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

# Pure-UIKit virtualized list library, vendored from the standalone CoreListDemo
# project (which keeps its own Xcode infrastructure alongside this BUILD file).
# The demo app entry points, demo view controllers, demo item, and demo-side
# loading policy are excluded so only the reusable library compiles here.
swift_library(
    name = "CoreList",
    module_name = "CoreList",
    srcs = glob(
        ["CoreListDemo/**/*.swift"],
        exclude = [
            "CoreListDemo/AppDelegate.swift",
            "CoreListDemo/SceneDelegate.swift",
            "CoreListDemo/ViewController.swift",
            "CoreListDemo/PhysicsScrollDemoViewController.swift",
            "CoreListDemo/ScrollComparisonViewController.swift",
            "CoreListDemo/PipelineDepthProbe.swift",
            "CoreListDemo/PipelineDepthViewController.swift",
            "CoreListDemo/DemoRow.swift",
            "CoreListDemo/AutoLoadResponseScheduler.swift",
        ],
    ),
    visibility = [
        "//visibility:public",
    ],
)
