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
        "SWIFT_OPTIMIZATION_LEVEL": native.read_config("custom", "optimization"),
    }

# Adding `-all_load` to our binaries works around https://bugs.swift.org/browse/SR-6004.
ALL_LOAD_LINKER_FLAG = "-all_load"

def read_config_nonempty(name):
    value = native.read_config("custom", name)
    if value == None:
        fail("Configuration paramter custom.%s should be defined" % name)
    elif len(value) == 0:
        fail("Configuration paramter custom.%s should not be empty" % name)
    else:
        return value

def get_codesign_identity(environment):
    if environment == "development":
        return read_config_nonempty("developmentCodeSignIdentity")
    elif environment == "distribution":
        return read_config_nonempty("distributionCodeSignIdentity")
    else:
        fail("Unknown environment " + environment)

def get_provisioning_profile(environment, type):
    if type == "app":
        return read_config_nonempty(environment + "ProvisioningProfileApp")
    elif type == "share":
        return read_config_nonempty(environment + "ProvisioningProfileExtensionShare")
    elif type == "widget":
        return read_config_nonempty(environment + "ProvisioningProfileExtensionWidget")
    elif type == "notification_service":
        return read_config_nonempty(environment + "ProvisioningProfileExtensionNotificationService")
    elif type == "notification_content":
        return read_config_nonempty(environment + "ProvisioningProfileExtensionNotificationContent")
    elif type == "intents":
        return read_config_nonempty(environment + "ProvisioningProfileExtensionIntents")
    elif type == "watch_app":
        return read_config_nonempty(environment + "ProvisioningProfileWatchApp")
    elif type == "watch_extension":
        return read_config_nonempty(environment + "ProvisioningProfileWatchExtension")
    else:
        fail("Unknown provisioning profile type " + type)

def get_development_team():
    return read_config_nonempty("developmentTeam")

def add_item_to_subdict(superdict, key, subkey, item):
    subdict = dict(superdict[key])
    subdict[subkey] = item
    superdict[key] = subdict

valid_configurations = ["Debug", "Profile", "Release"]

def add_provisioning_profile_specifier(configs, type):
    for configuration in configs:
        if configuration not in valid_configurations:
            fail("Unknown configuration " + configuration)

    configs = dict(configs)
    for configuration in valid_configurations:
        if configuration == "Debug":
            add_item_to_subdict(configs, configuration, "PROVISIONING_PROFILE_SPECIFIER", get_provisioning_profile(environment="development", type=type))
        elif configuration == "Profile":
            add_item_to_subdict(configs, configuration, "PROVISIONING_PROFILE_SPECIFIER", get_provisioning_profile(environment="development", type=type))
        elif configuration == "Release":
            add_item_to_subdict(configs, configuration, "PROVISIONING_PROFILE_SPECIFIER", get_provisioning_profile(environment="distribution", type=type))
    return configs

def add_codesign_identity(configs):
    for configuration in configs:
        if configuration not in valid_configurations:
            fail("Unknown configuration " + configuration)

    configs = dict(configs)
    for configuration in valid_configurations:
        if configuration == "Debug":
            add_item_to_subdict(configs, configuration, "CODE_SIGN_IDENTITY", get_codesign_identity(environment="development"))
        elif configuration == "Profile":
            add_item_to_subdict(configs, configuration, "CODE_SIGN_IDENTITY", get_codesign_identity(environment="development"))
        elif configuration == "Release":
            add_item_to_subdict(configs, configuration, "CODE_SIGN_IDENTITY", get_codesign_identity(environment="distribution"))
    return configs

def get_codesign_entitlements(type):
    if type == "app":
        return read_config_nonempty("entitlementsApp")
    elif type == "share":
        return read_config_nonempty("entitlementsExtensionShare")
    elif type == "widget":
        return read_config_nonempty("entitlementsExtensionWidget")
    elif type == "notification_service":
        return read_config_nonempty("entitlementsExtensionNotificationService")
    elif type == "notification_content":
        return read_config_nonempty("entitlementsExtensionNotificationContent")
    elif type == "intents":
        return read_config_nonempty("entitlementsExtensionIntents")
    else:
        fail("unknown provisioning profile type")

def get_build_number():
    return read_config_nonempty("buildNumber")

def bundle_identifier(suffix):
    return read_config_nonempty("baseApplicationBundleId") + suffix

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

def dynamic_library_configs():
    lib_specific_config = {
        "SWIFT_WHOLE_MODULE_OPTIMIZATION": "NO",

        # Setting SKIP_INSTALL to NO for static library configs would create
        # create a generic xcode archive which can not be uploaded the app store
        # https://developer.apple.com/library/archive/technotes/tn2215/_index.html
        "SKIP_INSTALL": "YES",
        "MACH_O_TYPE": "mh_dylib",
        "CODE_SIGNING_ALLOWED": "NO",
    }

    library_config = merge_dict(SHARED_CONFIGS, lib_specific_config)
    library_config = merge_dict(library_config, optimization_config())
    #library_config = config_with_updated_linker_flags(library_config, ALL_LOAD_LINKER_FLAG)
    configs = {
        "Debug": library_config,
        "Profile": library_config,
        "Release": library_config,
    }
    return configs

def app_binary_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("app"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "BUILD_NUMBER": get_build_number(),
        "APP_NAME": "Telegram",
        "PRODUCT_NAME": "Telegram",
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
        "APP_NAME": "Telegram",
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
        "APP_NAME": "Telegram",
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
        "APP_NAME": "Telegram",
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
        "APP_NAME": "Telegram",
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
        "APP_NAME": "Telegram",
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
        "WATCHOS_DEPLOYMENT_TARGET": "4.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp.watchkitextension"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "BUILD_NUMBER": get_build_number(),
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
        "WATCHOS_DEPLOYMENT_TARGET": "4.0",
        "TARGETED_DEVICE_FAMILY": "4",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks",
        "WK_COMPANION_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "WK_APP_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "BUILD_NUMBER": get_build_number(),
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
        "PRODUCT_NAME": "Telegram",
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
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
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions

def widget_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WidgetExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".Widget"),
        "PRODUCT_NAME": "Widget",
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions

def notification_content_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "NotificationContentExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationContent"),
        "PRODUCT_NAME": "Telegram",
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions

def notification_service_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "NotificationServiceExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".NotificationService"),
        "PRODUCT_NAME": "Telegram",
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions

def intents_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "IntentsExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".SiriIntents"),
        "PRODUCT_NAME": "Telegram",
        "APP_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "APP_SPECIFIC_URL_SCHEME": appConfig()["appSpecificUrlScheme"],
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_MODULE_NAME": "SiriIntents",
    }
    return substitutions

def watch_extension_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WatchAppExtension",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=".watchkitapp.watchkitextension"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "PRODUCT_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions

def watch_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "WatchApp",
        "PRODUCT_BUNDLE_IDENTIFIER":bundle_identifier(suffix=".watchkitapp"),
        "APP_NAME": "Telegram",
        "APP_BUNDLE_ID": bundle_identifier(suffix=""),
        "PRODUCT_NAME": "Telegram",
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
    }
    return substitutions
