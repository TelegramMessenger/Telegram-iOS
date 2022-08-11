load(
    "@build_bazel_rules_apple//apple:apple.bzl",
    "apple_static_xcframework_import"
)

apple_static_xcframework_import(
    name = "FirebaseAnalytics",
    xcframework_imports = glob([
                 "Firebase/FirebaseAnalytics/FirebaseAnalytics.xcframework/**",
            ]),
    deps = [
        ":FirebaseCore",
        ":FirebaseCoreDiagnostics",
        ":FirebaseInstallations",
        ":GoogleAppMeasurement",
        ":GoogleAppMeasurementIdentitySupport",
        ":GoogleDataTransport",
        ":GoogleUtilities",
        ":PromisesObjC",
        ":nanopb",
    ],
    visibility = ["//visibility:public"],
) #GTMSessionFetcher

apple_static_xcframework_import(
    name = "GTMSessionFetcher",
    xcframework_imports = glob([
        "Firebase/FirebaseAuth/GTMSessionFetcher.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseAuth",
    xcframework_imports = glob([
        "Firebase/FirebaseAuth/FirebaseAuth.xcframework/**",
    ]),
    deps = [
        ":GTMSessionFetcher"
    ],
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCore",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/FirebaseCore.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCoreDiagnostics",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/FirebaseCoreDiagnostics.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseInstallations",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/FirebaseInstallations.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurement",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/GoogleAppMeasurement.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleAppMeasurementIdentitySupport",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/GoogleAppMeasurementIdentitySupport.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleDataTransport",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/GoogleDataTransport.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleUtilities",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/GoogleUtilities.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "PromisesObjC",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/PromisesObjC.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "nanopb",
    xcframework_imports = glob([
        "Firebase/FirebaseAnalytics/nanopb.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseCrashlytics",
    xcframework_imports = glob([
        "Firebase/FirebaseCrashlytics/FirebaseCrashlytics.xcframework/**",
    ]),
    deps = [
        ":FirebaseAnalytics"
    ],
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseABTesting",
    xcframework_imports = glob([
        "Firebase/FirebaseRemoteConfig/FirebaseABTesting.xcframework/**",
    ]),
    deps = [
        
    ],
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "FirebaseRemoteConfig",
    xcframework_imports = glob([
        "Firebase/FirebaseRemoteConfig/FirebaseRemoteConfig.xcframework/**",
    ]),
    deps = [
        ":FirebaseABTesting"
    ],
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "AppAuth",
    xcframework_imports = glob([
        "Firebase/GoogleSignIn/AppAuth.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GTMAppAuth",
    xcframework_imports = glob([
        "Firebase/GoogleSignIn/GTMAppAuth.xcframework/**",
    ]),
    visibility = ["//visibility:public"],
)

apple_static_xcframework_import(
    name = "GoogleSignIn",
    xcframework_imports = glob([
        "Firebase/GoogleSignIn/GoogleSignIn.xcframework/**",
    ]),
    deps = [
        ":AppAuth",
        ":GTMAppAuth",
        ":GTMSessionFetcher",
    ],
    visibility = ["//visibility:public"],
)