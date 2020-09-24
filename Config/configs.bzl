load("//Config:utils.bzl",
    "config_with_updated_linker_flags",
    "configs_with_config",
    "merge_dict",
    "DEVELOPMENT_LANGUAGE",
    "SHARED_CONFIGS",
    "ALL_LOAD_LINKER_FLAG",
    "read_config_nonempty",
    "optimization_config",
    "add_provisioning_profile_specifier",
    "add_codesign_identity",
    "get_build_number",
    "get_short_version",
    "bundle_identifier",
    "get_development_team",
    "get_provisioning_profile",
    "get_codesign_entitlements",
)

load("//Config:app_configuration.bzl",
    "appConfig",
)

def app_binary_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("app"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": appConfig()["productName"],
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "app")
    configs = add_codesign_identity(configs)
    return configs

def share_extension_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".Share"),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("share"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": "ShareExtension",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "share")
    configs = add_codesign_identity(configs)
    return configs

def widget_extension_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".Widget"),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("widget"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": "WidgetExtension",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "widget")
    configs = add_codesign_identity(configs)
    return configs

def notification_content_extension_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationContent"),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("notification_content"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": "NotificationContentExtension",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "notification_content")
    configs = add_codesign_identity(configs)
    return configs

def notification_service_extension_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationService"),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("notification_service"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": "NotificationServiceExtension",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "notification_service")
    configs = add_codesign_identity(configs)
    return configs

def intents_extension_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "NO",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".SiriIntents"),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("intents"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": appConfig()["appName"],
        "PRODUCT_NAME": "IntentsExtension",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "intents")
    configs = add_codesign_identity(configs)
    return configs

def watch_extension_binary_configs():
    config = {
        "SDKROOT": "watchos",
        "WATCHOS_DEPLOYMENT_TARGET": "5.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp.watchkitextension"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": appConfig()["appName"],
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "ENABLE_BITCODE": "YES",
    }
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "watch_extension")
    configs = add_codesign_identity(configs)
    return configs

def watch_binary_configs():
    config = {
        "SDKROOT": "watchos",
        "WATCHOS_DEPLOYMENT_TARGET": "5.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": appConfig()["appName"],
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "ENABLE_BITCODE": "YES",
    }
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "watch_app")
    configs = add_codesign_identity(configs)
    return configs

def info_plist_substitutions(name):
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": name,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(name),
        "PRODUCT_NAME": name,
        "CURRENT_PROJECT_VERSION": "1",
    }
    return substitutions

def app_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "Telegram",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "PRODUCT_NAME": appConfig()["productName"],
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    return substitutions

def share_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "ShareExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".Share"),
        "PRODUCT_NAME": "Share",
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
    }
    return substitutions

def widget_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WidgetExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".Widget"),
        "PRODUCT_NAME": "Widget",
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "MinimumOSVersion": "9.0",
    }
    return substitutions

def notification_content_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "NotificationContentExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationContent"),
        "PRODUCT_NAME": appConfig()["productName"],
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "MinimumOSVersion": "10.0",
    }
    return substitutions

def notification_service_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "NotificationServiceExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationService"),
        "PRODUCT_NAME": appConfig()["productName"],
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "MinimumOSVersion": "10.0",
    }
    return substitutions

def intents_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "IntentsExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".SiriIntents"),
        "PRODUCT_NAME": appConfig()["productName"],
        "APP_NAME": appConfig()["appName"],
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "PRODUCT_MODULE_NAME": "SiriIntents",
        "MinimumOSVersion": "10.0",
    }
    return substitutions

def watch_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WatchAppExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp.watchkitextension"),
        "APP_NAME": appConfig()["appName"],
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "PRODUCT_NAME": appConfig()["productName"],
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "MinimumOSVersion": "5.0",
    }
    return substitutions

def watch_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WatchApp",
        "PRODUCT_BUNDLE_IDENTIFIER":bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": appConfig()["appName"],
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "PRODUCT_NAME": appConfig()["productName"],
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "MinimumOSVersion": "5.0",
    }
    return substitutions
