load("@build_bazel_rules_swift//swift:swift.bzl", "swift_library")

swift_library(
    name = "EsimAuth",
    module_name = "EsimAuth",
    srcs = glob([
        "**/*.swift",
    ]),
    deps = [
        "//Nicegram/EsimModule/EsimApiClientDefinition:EsimApiClientDefinition",
        "//Nicegram/EsimModule/EsimKeychainWrapper:EsimKeychainWrapper",
        "//Nicegram/EsimModule/EsimModels:EsimModels",
        "//Nicegram/EsimModule/EsimPropertyWrappers:EsimPropertyWrappers",
        "//Vendor/DeviceKit:DeviceKit",
        "@FirebaseSDK//:FirebaseAnalytics",
        "@FirebaseSDK//:GTMSessionFetcher",
        "@FirebaseSDK//:FirebaseAuth",
        "@FirebaseSDK//:FirebaseCore",
        "@FirebaseSDK//:FirebaseCoreDiagnostics",
        "@FirebaseSDK//:FirebaseInstallations",
        "@FirebaseSDK//:GoogleAppMeasurement",
        "@FirebaseSDK//:GoogleDataTransport",
        "@FirebaseSDK//:GoogleUtilities",
        "@FirebaseSDK//:PromisesObjC",
        "@FirebaseSDK//:nanopb",
        "@FirebaseSDK//:FirebaseCrashlytics",
        "@FirebaseSDK//:AppAuth",
        "@FirebaseSDK//:GTMAppAuth",
        "@FirebaseSDK//:GoogleSignIn",
    ],
    visibility = ["//visibility:public"],
)
