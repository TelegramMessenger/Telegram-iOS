load("//Config:utils.bzl",
    "config_with_updated_linker_flags",
    "configs_with_config",
    "merge_dict",
    "DEVELOPMENT_LANGUAGE",
    "SHARED_CONFIGS",
    "ALL_LOAD_LINKER_FLAG",
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
    "appConfig"
)

def app_binary_configs():
    config = {
        "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES": "YES",
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "Wallet",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "CODE_SIGN_ENTITLEMENTS": get_codesign_entitlements("app"),
        "DEVELOPMENT_TEAM": get_development_team(),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIconWallet",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "APP_NAME": "TON Wallet",
        "PRODUCT_NAME": "TON Wallet",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    config = merge_dict(SHARED_CONFIGS, config)
    config = merge_dict(config, optimization_config())
    config = config_with_updated_linker_flags(config, ALL_LOAD_LINKER_FLAG)
    configs = configs_with_config(config)
    configs = add_provisioning_profile_specifier(configs, "app")
    configs = add_codesign_identity(configs)
    return configs

def app_info_plist_substitutions():
    substitutions = {
        "DEVELOPMENT_LANGUAGE": DEVELOPMENT_LANGUAGE,
        "EXECUTABLE_NAME": "Wallet",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_identifier(suffix=""),
        "PRODUCT_NAME": "TON Wallet",
        "APP_NAME": "TON Wallet",
        "CURRENT_PROJECT_VERSION": "1",
        "BUILD_NUMBER": get_build_number(),
        "PRODUCT_BUNDLE_SHORT_VERSION": get_short_version(),
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIconWallet",
        "TARGETED_DEVICE_FAMILY": "1,2",
    }
    return substitutions
