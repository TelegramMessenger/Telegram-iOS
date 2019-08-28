load("//Config:utils.bzl", "config_with_updated_linker_flags", "configs_with_config")

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
    return {"SWIFT_OPTIMIZATION_LEVEL": native.read_config('custom', 'optimization')}

# Adding `-all_load` to our binaries works around https://bugs.swift.org/browse/SR-6004. See the
# longer comment in `ViewController.swift` for more details.
ALL_LOAD_LINKER_FLAG = "-all_load"

def bundle_identifier(name):
    return "org.telegram.%s" % name

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
        "CODE_SIGN_ENTITLEMENTS": "Telegram-iOS.entitlements",
        "DEVELOPMENT_TEAM": "X834Q8SBVP",
        "PROVISIONING_PROFILE_SPECIFIER": "match Development org.telegram.Telegram-iOS",
    }
    binary_config = merge_dict(SHARED_CONFIGS, binary_specific_config)
    binary_config = merge_dict(binary_config, optimization_config())
    binary_config = config_with_updated_linker_flags(binary_config, ALL_LOAD_LINKER_FLAG)
    return configs_with_config(binary_config)

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
        "CURRENT_PROJECT_VERSION": "1",
        "CODE_SIGN_IDENTITY": "iPhone Developer: Peter Iakovlev (9J4EJ3F97G)",
    }
    return substitutions
