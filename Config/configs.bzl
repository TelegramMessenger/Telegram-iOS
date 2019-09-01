load("//Config:utils.bzl", "config_with_updated_linker_flags", "configs_with_config")
load("//Config:app_configuration.bzl", "appConfig")

DEVELOPMENT_LANGUAGE = "en"

def merge_dict(a, b):
    d = {}
    d.update(a)
    d.update(b)
    return d

def pretty(dict, current = ""):
    current = "\n"
    indent = 0
    for key, value in dict.items():
        current = current + str(key) + ": "
        if type(value) == type({}):
            current = current + "\n"
            indent = 1
            for key2, value2 in value.items():
                current = current + "\t" * indent + str(key2)
                current = current + ": " + str(value2) + "\n"
        else:
            current = current + "\t" * (indent + 1) + str(value) + "\n"

    return current

SHARED_CONFIGS = {
    "IPHONEOS_DEPLOYMENT_TARGET": "8.0",
    "SDKROOT": "iphoneos",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "SWIFT_WHOLE_MODULE_OPTIMIZATION": "NO",
    "ONLY_ACTIVE_ARCH": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "@executable_path/Frameworks",
    "ENABLE_BITCODE": "NO",
}

def optimization_config():
    return {
        "SWIFT_OPTIMIZATION_LEVEL": native.read_config('custom', 'optimization'),
    }

# Adding `-all_load` to our binaries works around https://bugs.swift.org/browse/SR-6004.
ALL_LOAD_LINKER_FLAG = "-all_load"

def bundle_identifier(name):
    return "org.telegram.Telegram-iOS.%s" % name

def library_configs():
    lib_specific_config = {
        "SWIFT_WHOLE_MODULE_OPTIMIZATION": "NO",

        # Setting SKIP_INSTALL to NO for static library configs would create
        # create a generic xcode archive which can not be uploaded the app store
        # https://developer.apple.com/library/archive/technotes/tn2215/_index.html
        "SKIP_INSTALL": "YES",
    }
    library_config = merge_dict(SHARED_CONFIGS, lib_specific_config)
    library_config = merge_dict(library_config, optimization_config())
    configs = {
        "Debug": library_config,
        "Profile": library_config,
        "Release": library_config,
    }
    return configs

def framework_library_configs(name):
    lib_specific_config = {
        "SWIFT_WHOLE_MODULE_OPTIMIZATION": "NO",

        # Setting SKIP_INSTALL to NO for static library configs would create
        # create a generic xcode archive which can not be uploaded the app store
        # https://developer.apple.com/library/archive/technotes/tn2215/_index.html
        "SKIP_INSTALL": "YES",
        "MACH_O_TYPE": "mh_dylib",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(name),
        "CODE_SIGNING_ALLOWED": "NO",
    }

    library_config = merge_dict(SHARED_CONFIGS, lib_specific_config)
    library_config = merge_dict(library_config, optimization_config())
    library_config = config_with_updated_linker_flags(library_config, ALL_LOAD_LINKER_FLAG)
    configs = {
        "Debug": library_config,
        "Profile": library_config,
        "Release": library_config,
    }
    return configs

def app_binary_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "Telegram-iOS/Telegram-iOS-Hockeyapp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "Telegram",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def share_extension_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS." + name,
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "Share/Share-HockeyApp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.Share",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "ShareExtension",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def widget_extension_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS." + name,
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "Widget/Widget-HockeyApp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.Widget",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "WidgetExtension",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def notification_content_extension_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS." + name,
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "NotificationContent/NotificationContent-HockeyApp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.NotificationContent",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "NotificationContentExtension",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def notification_service_extension_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS." + name,
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "NotificationService/NotificationService-HockeyApp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.NotificationService",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "NotificationServiceExtension",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def intents_extension_configs(name):
    binary_specific_config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS." + name,
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "CODE_SIGN_ENTITLEMENTS": "SiriIntents/SiriIntents-HockeyApp.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.SiriIntents",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "IntentsExtension",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

def watch_extension_binary_configs(name):
    config = {
        "SDKROOT": "watchos",
        "WATCHOS_DEPLOYMENT_TARGET": "4.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier("watchkitapp.watchkitextension"),
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.watchkitapp.watchkitextension",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS",
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier("watchkitapp"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": "org.telegram.Telegram-iOS",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "ENABLE_BITCODE": "YES",
    }
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(config)

def watch_binary_configs(name):
    config = {
        "SDKROOT": "watchos",
        "WATCHOS_DEPLOYMENT_TARGET": "4.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier("watchkitapp"),
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS.watchkitapp",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS",
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier("watchkitapp"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": "org.telegram.Telegram-iOS",
        "BUILD_NUMBER": appConfig()["buildNumber"],
        "ENABLE_BITCODE": "YES",
    }
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(config)

def info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(name),
        "PRODUCT_NAME": name,
        "CURRENT_PROJECT_VERSION": "1",
    }
    return substitutions

def app_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS",
        "PRODUCT_NAME": name,
        "APP_NAME": name,
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def share_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.Share",
        "PRODUCT_NAME": name,
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def widget_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.Widget",
        "PRODUCT_NAME": name,
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def notification_content_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.NotificationContent",
        "PRODUCT_NAME": name,
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def notification_service_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.NotificationService",
        "PRODUCT_NAME": name,
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def intents_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.SiriIntents",
        "PRODUCT_NAME": name,
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def watch_extension_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.watchkitapp.watchkitextension",
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": "org.telegram.Telegram-iOS",
        "PRODUCT_NAME": name,
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions

def watch_info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.Telegram-iOS.watchkitapp",
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": "org.telegram.Telegram-iOS",
        "PRODUCT_NAME": name,
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
        "BUILD_NUMBER": appConfig()["buildNumber"],
    }
    return substitutions
