OTHER_LINKER_FLAGS_KEY = 'OTHER_LDFLAGS'

def configs_with_config(config):
    return {
        "Debug": config,
        "Profile": config,
        "Release": config,
    }

def configs_with_updated_linker_flags(configs, other_linker_flags):
    if other_linker_flags == None:
        return configs
    else:
        updated_configs = { }
        for build_configuration in configs:
            updated_configs[build_configuration] = config_with_updated_linker_flags(
                configs[build_configuration],
                other_linker_flags)
        return updated_configs

def config_with_updated_linker_flags(config, other_linker_flags, config_key=OTHER_LINKER_FLAGS_KEY):
    new_config = { }
    config_key_found = False
    for key in config:
        if key == config_key:
            new_config[key] = config[key] + (" %s" % other_linker_flags)
            config_key_found = True
        else:
            new_config[key] = config[key]

    if config_key_found == False:
        # If `config` does not currently contain `config_key`, add it. Inherit for good measure.
        new_config[config_key] = '$(inherited) ' + other_linker_flags

    return new_config

def merge_dict(a, b):
    d = {}
    d.update(a)
    d.update(b)
    return d

DEVELOPMENT_LANGUAGE = "en"

SHARED_CONFIGS = {
    "IPHONEOS_DEPLOYMENT_TARGET": "9.0",
    "SDKROOT": "iphoneos",
    "GCC_OPTIMIZATION_LEVEL": "0",
    "SWIFT_WHOLE_MODULE_OPTIMIZATION": "NO",
    "ONLY_ACTIVE_ARCH": "YES",
    "LD_RUNPATH_SEARCH_PATHS": "@executable_path/Frameworks",
    "ENABLE_BITCODE": "NO",
}

# Adding `-all_load` to our binaries works around https://bugs.swift.org/browse/SR-6004.
ALL_LOAD_LINKER_FLAG = "-all_load"

def optimization_config():
    return {
        "SWIFT_OPTIMIZATION_LEVEL": native.read_config("custom", "optimization"),
    }

def read_config_nonempty(name):
    value = native.read_config("custom", name)
    if value == None:
        fail("Configuration parameter custom.%s should be defined" % name)
    elif len(value) == 0:
        fail("Configuration parameter custom.%s should not be empty" % name)
    else:
        return value

def get_codesign_identity(environment):
    if environment == "development":
        return read_config_nonempty("developmentCodeSignIdentity")
    elif environment == "distribution":
        return read_config_nonempty("distributionCodeSignIdentity")
    else:
        fail("Unknown environment " + environment)

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

def get_build_number():
    return read_config_nonempty("buildNumber")

def get_short_version():
    return read_config_nonempty("appVersion")

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
    configs = {
        "Debug": library_config,
        "Profile": library_config,
        "Release": library_config,
    }
    return configs

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
