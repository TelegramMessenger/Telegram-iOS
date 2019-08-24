load("//Config:configs.bzl", "library_configs", "framework_library_configs", "info_plist_substitutions")

def apple_third_party_lib(**kwargs):
    apple_lib(
        warning_as_error = False,
        suppress_warnings = True,
        **kwargs
    )

def apple_lib(
        name,
        visibility = ["PUBLIC"],
        srcs = [],
        headers = [],
        exported_headers = [],
        extra_xcode_files = [],
        deps = [],
        frameworks = [],
        swift_version = None,
        modular = True,
        compiler_flags = None,
        swift_compiler_flags = None,
        warning_as_error = False,
        suppress_warnings = False,
        framework = False):
    swift_version = swift_version or native.read_config('swift', 'version')
    compiler_flags = compiler_flags or []
    swift_compiler_flags = swift_compiler_flags or []

    if native.read_config("xcode", "beta") == "True":
        warning_as_error = False

    if warning_as_error:
        compiler_flags.append("-Werror")
        swift_compiler_flags.append("-warnings-as-errors")
    elif suppress_warnings:
        compiler_flags.append("-w")
        swift_compiler_flags.append("-suppress-warnings")

    if framework:
        if native.read_config("custom", "mode") == "project":
            native.apple_library(
                name = name + "",
                srcs = srcs,
                header_namespace = name,
                module_name = name,
                headers = headers,
                exported_headers = exported_headers,
                deps = deps,
                extra_xcode_files = extra_xcode_files,
                frameworks = frameworks,
                visibility = visibility,
                swift_version = swift_version,
                configs = framework_library_configs(name),
                modular = modular,
                compiler_flags = compiler_flags,
                swift_compiler_flags = swift_compiler_flags,
                preferred_linkage = "shared",
                link_style = "static",
                linker_flags = ["-Wl,-install_name,@rpath/%sFramework.framework/%sFramework" % (name, name)],
            )
            native.apple_bundle(
                name = name + "Framework",
                visibility = visibility,
                binary = ":" + name + "#shared",
                extension = "framework",
                info_plist = "Info.plist",
                info_plist_substitutions = info_plist_substitutions(name),
            )
        else:
            native.apple_library(
                name = name,
                srcs = srcs,
                header_namespace = name,
                headers = headers,
                exported_headers = exported_headers,
                deps = deps,
                extra_xcode_files = extra_xcode_files,
                frameworks = frameworks,
                visibility = visibility,
                swift_version = swift_version,
                configs = framework_library_configs(name),
                modular = modular,
                compiler_flags = compiler_flags,
                swift_compiler_flags = swift_compiler_flags,
                preferred_linkage = "shared",
                link_style = "static",
                linker_flags = ["-Wl,-install_name,@rpath/%s.dylib" % (name)],
            )
            native.apple_bundle(
                name = name + "Framework",
                visibility = visibility,
                binary = ":" + name + "#shared",
                extension = "framework",
                info_plist = "Info.plist",
                info_plist_substitutions = info_plist_substitutions(name),
            )
    else:
        native.apple_library(
            name = name,
            srcs = srcs,
            headers = headers,
            exported_headers = exported_headers,
            deps = deps,
            visibility = visibility,
            swift_version = swift_version,
            configs = library_configs(),
            modular = modular,
            compiler_flags = compiler_flags,
            swift_compiler_flags = swift_compiler_flags,
        )

def static_library(
        name,
        visibility = ["PUBLIC"],
        has_cpp = False,
        srcs = [],
        headers = [],
        exported_headers = [],
        extra_xcode_files = [],
        deps = [],
        frameworks = [],
        info_plist = None,
        info_plist_substitutions = {},
        modular = True,
        compiler_flags = None,
        swift_compiler_flags = None,
        warning_as_error = False,
        suppress_warnings = True):
    lib = apple_cxx_lib if has_cpp else apple_lib
    lib(
        name = name,
        srcs = srcs,
        exported_headers = exported_headers,
        headers = headers,
        modular = modular,
        compiler_flags = compiler_flags,
        swift_compiler_flags = swift_compiler_flags,
        extra_xcode_files = extra_xcode_files,
        deps = deps,
        frameworks = frameworks,
        warning_as_error = warning_as_error,
        suppress_warnings = suppress_warnings
    )

def framework(
        name,
        visibility = ["PUBLIC"],
        has_cpp = False,
        srcs = [],
        headers = [],
        exported_headers = [],
        extra_xcode_files = [],
        deps = [],
        frameworks = [],
        info_plist = None,
        info_plist_substitutions = {},
        modular = True,
        compiler_flags = None,
        swift_compiler_flags = None,
        warning_as_error = False,
        suppress_warnings = True):
    lib = apple_cxx_lib if has_cpp else apple_lib
    lib(
        name = name,
        srcs = srcs,
        exported_headers = exported_headers,
        headers = headers,
        modular = modular,
        compiler_flags = compiler_flags,
        swift_compiler_flags = swift_compiler_flags,
        extra_xcode_files = extra_xcode_files,
        deps = deps,
        frameworks = frameworks,
        warning_as_error = warning_as_error,
        suppress_warnings = suppress_warnings,
        framework = True
    )
    

CXX_SRC_EXT = ["mm", "cpp", "S"]
def apple_cxx_lib(
        srcs = [],
        additional_exported_linker_flags = [],
        **kwargs):
    c_srcs, cxx_srcs = [], []

    cxx_compile_flags = native.read_config("cxx", "cxxflags").split(" ")
    cxx_compile_flags.append("-w")

    for file_ in srcs:
        if file_.split(".")[-1] in CXX_SRC_EXT:
            cxx_srcs.append((file_, cxx_compile_flags))
        else:
            c_srcs.append(file_)
    apple_lib(
        srcs = c_srcs + cxx_srcs,
        exported_linker_flags = [
            "-lc++",
            "-lz"
        ] + additional_exported_linker_flags,
        **kwargs
    )

def apple_cxx_third_party_library(
        **kwargs):
    apple_cxx_lib(
        warning_as_error = False,
        suppress_warnings = True,
        **kwargs
    )

def framework_binary_dependencies(names):
    result = []
    if native.read_config("custom", "mode") == "project":
        for name in names:
            result.append(name + "")
    else:
        for name in names:
            result.append(name + "#shared")
    return result

def framework_bundle_dependencies(names):
    result = []
    if native.read_config("custom", "mode") == "project":
        for name in names:
            #result.append(name + "#shared")
            pass
    else:
        for name in names:
            result.append(name + "Framework")
            pass
    return result
