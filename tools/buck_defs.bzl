SHARED_CONFIGS = {
    'IPHONEOS_DEPLOYMENT_TARGET': '8.0',  # common target version
    'SDKROOT': 'iphoneos', # platform
    'GCC_OPTIMIZATION_LEVEL': '0',  # clang optimization
    'SWIFT_OPTIMIZATION_LEVEL': '-Onone',  # swiftc optimization
    'SWIFT_WHOLE_MODULE_OPTIMIZATION': 'NO',  # for build performance
    'ONLY_ACTIVE_ARCH': 'YES',
    'LD_RUNPATH_SEARCH_PATHS': '@executable_path/Frameworks', # To allow source files in binary
}

LIB_SPECIFIC_CONFIG = {
    'SKIP_INSTALL': 'YES',
}

EXTENSION_LIB_SPECIFIC_CONFIG = {
    'SKIP_INSTALL': 'YES',
    'APPLICATION_EXTENSION_API_ONLY': 'YES',
}
