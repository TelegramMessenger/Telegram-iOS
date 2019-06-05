load('//tools:buck_utils.bzl', 'config_with_updated_linker_flags', 'configs_with_config')
load('//tools:buck_defs.bzl', 'combined_config', 'SHARED_CONFIGS', 'LIB_SPECIFIC_CONFIG')

prebuilt_apple_framework(
  name = 'CrashReporter',
  framework = 'Vendor/CrashReporter.framework',
  preferred_linkage = 'static',
  visibility = ['//submodules/HockeySDK-iOS:...']
)

apple_library(
    name = 'HockeySDK',
    srcs = glob([
        'Classes/*.m',
        'Classes/*.mm',
    ]),
    headers = glob([
        'Classes/*.h',
    ]),
    header_namespace = 'HockeySDK',
    exported_headers = [
        'Classes/HockeySDKFeatureConfig.h',
        'Classes/HockeySDKEnums.h',
        'Classes/HockeySDKNullability.h',
        'Classes/BITAlertAction.h',

        'Classes/BITHockeyManager.h',

        'Classes/BITHockeyAttachment.h',

        'Classes/BITHockeyBaseManager.h',
        'Classes/BITCrashManager.h',
        'Classes/BITCrashAttachment.h',
        'Classes/BITCrashManagerDelegate.h',
        'Classes/BITCrashDetails.h',
        'Classes/BITCrashMetaData.h',

        'Classes/BITUpdateManager.h',
        'Classes/BITUpdateManagerDelegate.h',
        'Classes/BITUpdateViewController.h',
        'Classes/BITHockeyBaseViewController.h',
    ],
    modular = True,
    configs = configs_with_config(combined_config([SHARED_CONFIGS, LIB_SPECIFIC_CONFIG])),
    compiler_flags = [
        '-w',
        '-DBITHOCKEY_VERSION=@\"5.1.2\"',
        '-DBITHOCKEY_C_VERSION="5.1.2"',
        '-DBITHOCKEY_C_BUILD="108"',
        '-DHOCKEYSDK_FEATURE_CRASH_REPORTER=1',
        '-DHOCKEYSDK_FEATURE_UPDATES=1',
        '-DHOCKEYSDK_FEATURE_FEEDBACK=0',
        '-DHOCKEYSDK_FEATURE_AUTHENTICATOR=0',
        '-DHOCKEYSDK_FEATURE_METRICS=0',
    ],
    preprocessor_flags = ['-fobjc-arc'],
    visibility = ['PUBLIC'],
    deps = [
        ':CrashReporter',
    ],
    frameworks = [
        '$SDKROOT/System/Library/Frameworks/Foundation.framework',
        '$SDKROOT/System/Library/Frameworks/UIKit.framework',
    ],
)
