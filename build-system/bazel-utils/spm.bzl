load("@build_bazel_rules_swift//swift:swift.bzl", "SwiftInfo")
load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//lib:dicts.bzl", "dicts")

# Define provider to propagate data
SPMModulesInfo = provider(
    fields = {
        "modules": "Dictionary of module information",
        "transitive_sources": "Depset of all transitive source files",
    }
)

_IGNORE_CC_LIBRARY_ATTRS = [
    "data",
    "applicable_licenses",
    "alwayslink",
    "aspect_hints",
    "compatible_with",
    "deprecation",
    "exec_compatible_with",
    "exec_properties",
    "expect_failure",
    "features",
    "generator_function",
    "generator_location",
    "generator_name",
    "generator_platform",
    "generator_script",
    "generator_tool",
    "generator_toolchain",
    "generator_toolchain_type",
    "licenses",
    "linkstamp",
    "linkstatic",
    "name",
    "restricted_to",
    "tags",
    "target_compatible_with",
    "testonly",
    "to_json",
    "to_proto",
    "toolchains",
    "transitive_configs",
    "visibility",
    "win_def_file",
    "linkopts",
]

_IGNORE_CC_LIBRARY_EMPTY_ATTRS = [
    "additional_compiler_inputs",
    "additional_linker_inputs",
    "hdrs_check",
    "implementation_deps",
    "include_prefix",
    "strip_include_prefix",
    "local_defines",
    "conlyopts",
    "module_interfaces",
    "package_metadata",
]

_CC_LIBRARY_ATTRS = {
    "copts": [],
    "cxxopts": [],
    "defines": [],
    "deps": [],
    "hdrs": [],
    "includes": [],
    "srcs": [],
    "textual_hdrs": [],
}

_CC_LIBRARY_REQUIRED_ATTRS = {
}

_IGNORE_OBJC_LIBRARY_ATTRS = [
    "data",
    "alwayslink",
    "applicable_licenses",
    "aspect_hints",
    "compatible_with",
    "enable_modules",
    "exec_compatible_with",
    "exec_properties",
    "expect_failure",
    "features",
    "generator_function",
    "generator_location",
    "generator_name",
    "deprecation",
    "module_name",
    "name",
    "stamp",
    "tags",
    "target_compatible_with",
    "testonly",
    "to_json",
    "to_proto",
    "toolchains",
    "transitive_configs",
    "visibility",
    "package_metadata",
]

_IGNORE_OBJC_LIBRARY_EMPTY_ATTRS = [
    "implementation_deps",
    "linkopts",
    "module_map",
    "non_arc_srcs",
    "pch",
    "restricted_to",
    "textual_hdrs",
    "sdk_includes",
    "conlyopts",
]

_OBJC_LIBRARY_ATTRS = {
    "copts": [],
    "cxxopts": [],
    "defines": [],
    "deps": [],
    "hdrs": [],
    "srcs": [],
    "sdk_dylibs": [],
    "sdk_frameworks": [],
    "weak_sdk_frameworks": [],
    "includes": [],
}

_OBJC_LIBRARY_REQUIRED_ATTRS = [
    "module_name",
]

_IGNORE_SWIFT_LIBRARY_ATTRS = [
    "data",
    "always_include_developer_search_paths",
    "alwayslink",
    "applicable_licenses",
    "aspect_hints",
    "compatible_with",
    "deprecation",
    "exec_compatible_with",
    "exec_properties",
    "expect_failure",
    "features",
    "generated_header_name",
    "generates_header",
    "generator_function",
    "generator_location",
    "generator_name",
    "linkstatic",
    "module_name",
    "name",
    "package_name",
    "restricted_to",
    "tags",
    "target_compatible_with",
    "testonly",
    "to_json",
    "to_proto",
    "toolchains",
    "transitive_configs",
    "visibility",
    "library_evolution",
    "package_metadata",
]

_IGNORE_SWIFT_LIBRARY_EMPTY_ATTRS = [
    "plugins",
    "private_deps",
    "swiftc_inputs",
]

_SWIFT_LIBRARY_ATTRS = {
    "copts": [],
    "defines": [],
    "deps": [],
    "linkopts": [],
    "srcs": [],
}

_SWIFT_LIBRARY_REQUIRED_ATTRS = [
    "module_name",
]

"""
["alwayslink", "aspect_hints", "compatible_with", "data", "deprecation", "deps", "exec_compatible_with", "exec_properties", "expect_failure", "features", "generator_function", "generator_location", "generator_name", "has_swift", "includes", "library_identifiers", "linkopts", "name", "package_metadata", "restricted_to", "sdk_dylibs", "sdk_frameworks", "tags", "target_compatible_with", "testonly", "toolchains", "transitive_configs", "visibility", "weak_sdk_frameworks", "xcframework_imports"]
"""

_IGNORE_APPLE_STATIC_XCFRAMEWORK_IMPORT_ATTRS = [
    "name",
    "alwayslink",
    "aspect_hints",
    "compatible_with",
    "data",
    "deprecation",
    "exec_compatible_with",
    "exec_properties",
    "expect_failure",
    "features",
    "generator_function",
    "generator_location",
    "generator_name",
    "has_swift",
    "includes",
    "library_identifiers",
    "linkopts",
    "package_metadata",
    "restricted_to",
    "tags",
    "target_compatible_with",
    "testonly",
    "toolchains",
    "transitive_configs",
    "visibility",
    "weak_sdk_frameworks",
]

_IGNORE_APPLE_STATIC_XCFRAMEWORK_IMPORT_EMPTY_ATTRS = [
    "deps",
    "sdk_dylibs",
    "sdk_frameworks",
]

_APPLE_STATIC_XCFRAMEWORK_IMPORT_ATTRS = [
    "xcframework_imports",
]

_APPLE_STATIC_XCFRAMEWORK_IMPORT_REQUIRED_ATTRS = [
    "xcframework_imports",
]

_LIBRARY_CONFIGS = {
    "cc_library": {
        "ignore_attrs": _IGNORE_CC_LIBRARY_ATTRS,
        "ignore_empty_attrs": _IGNORE_CC_LIBRARY_EMPTY_ATTRS,
        "handled_attrs": _CC_LIBRARY_ATTRS,
        "required_attrs": _CC_LIBRARY_REQUIRED_ATTRS,
    },
    "objc_library": {
        "ignore_attrs": _IGNORE_OBJC_LIBRARY_ATTRS,
        "ignore_empty_attrs": _IGNORE_OBJC_LIBRARY_EMPTY_ATTRS,
        "handled_attrs": _OBJC_LIBRARY_ATTRS,
        "required_attrs": _OBJC_LIBRARY_REQUIRED_ATTRS,
    },
    "swift_library": {
        "ignore_attrs": _IGNORE_SWIFT_LIBRARY_ATTRS,
        "ignore_empty_attrs": _IGNORE_SWIFT_LIBRARY_EMPTY_ATTRS,
        "handled_attrs": _SWIFT_LIBRARY_ATTRS,
        "required_attrs": _SWIFT_LIBRARY_REQUIRED_ATTRS,
    },
    "apple_static_xcframework_import": {
        "ignore_attrs": _IGNORE_APPLE_STATIC_XCFRAMEWORK_IMPORT_ATTRS,
        "ignore_empty_attrs": _IGNORE_APPLE_STATIC_XCFRAMEWORK_IMPORT_EMPTY_ATTRS,
        "handled_attrs": _APPLE_STATIC_XCFRAMEWORK_IMPORT_ATTRS,
        "required_attrs": _APPLE_STATIC_XCFRAMEWORK_IMPORT_REQUIRED_ATTRS,
    },
}

def get_rule_atts(rule):
    if rule.kind in _LIBRARY_CONFIGS:
        config = _LIBRARY_CONFIGS[rule.kind]
        ignore_attrs = config["ignore_attrs"]
        ignore_empty_attrs = config["ignore_empty_attrs"]
        handled_attrs = config["handled_attrs"]
        required_attrs = config["required_attrs"]

        for attr_name in dir(rule.attr):
            if attr_name.startswith("_"):
                continue
            if attr_name in ignore_attrs:
                continue
            if attr_name in ignore_empty_attrs:
                attr_value = getattr(rule.attr, attr_name)
                if attr_value == [] or attr_value == None or attr_value == "":
                    continue
                else:
                    fail("Attribute {} is not empty: {}".format(attr_name, attr_value))
            if attr_name in handled_attrs:
                continue
            print("All attributes: {}".format(dir(rule.attr)))
            fail("Unknown attribute: {}".format(attr_name))

        result = dict()
        result["type"] = rule.kind
        for attr_name in handled_attrs:
            if hasattr(rule.attr, attr_name):
                result[attr_name] = getattr(rule.attr, attr_name)
            else:
                result[attr_name] = handled_attrs[attr_name] # Use default value
        for attr_name in required_attrs:
            if not hasattr(rule.attr, attr_name):
                if rule.kind == "objc_library" and attr_name == "module_name":
                    result[attr_name] = getattr(rule.attr, "name")
                else:
                    fail("Required attribute {} is missing".format(attr_name))
            else:
                result[attr_name] = getattr(rule.attr, attr_name)
        result["name"] = getattr(rule.attr, "name")
        return result
    elif rule.kind == "ios_application":
        result = dict()
        result["type"] = "ios_application"
        return result
    elif rule.kind == "generate_spm":
        result = dict()
        result["type"] = "root"
        return result
    elif rule.kind == "apple_static_xcframework_import":
        result = dict()
        result["type"] = "apple_static_xcframework_import"
        return result
    else:
        fail("Unknown rule kind: {}".format(rule.kind))

def _collect_spm_modules_impl(target, ctx):
    # Skip targets without DefaultInfo
    if not DefaultInfo in target:
        return []
    
    # Get module name
    module_name = ctx.label.name
    if hasattr(ctx.rule.attr, "module_name"):
        module_name = ctx.rule.attr.module_name or ctx.label.name

    # Collect all modules and transitive sources from dependencies first
    all_modules = {}
    dep_transitive_sources_list = []
    
    if hasattr(ctx.rule.attr, "deps"):
        for dep in ctx.rule.attr.deps:
            if SPMModulesInfo in dep:
                # Merge the modules dictionaries
                for label, info in dep[SPMModulesInfo].modules.items():
                    if label in all_modules:
                        if all_modules[label]["path"] != info["path"]:
                            fail("Duplicate module name: {}".format(label))
                    all_modules[label] = info
                # Add transitive sources depset from dependency to the list
                dep_transitive_sources_list.append(dep[SPMModulesInfo].transitive_sources)
    
    # Merge all transitive sources from dependencies
    transitive_sources_from_deps = depset(transitive = dep_transitive_sources_list)

    result_attrs = get_rule_atts(ctx.rule)

    sources = []
    current_target_src_files = []
    if "srcs" in result_attrs:
        for src_target in result_attrs["srcs"]:
            src_files = src_target.files.to_list()
            for f in src_files:
                if f.extension in ["swift", "cc", "cpp", "h", "m", "mm", "s", "S"]:
                    current_target_src_files.append(f)
            for src_file in src_files:
                sources.append(src_file.path)
    current_target_sources = depset(current_target_src_files)
    
    headers = []
    current_target_hdr_files = []
    if "hdrs" in result_attrs:
        for hdr_target in result_attrs["hdrs"]:
            hdr_files = hdr_target.files.to_list()
            for f in hdr_files:
                current_target_hdr_files.append(f)
            for hdr_file in hdr_files:
                headers.append(hdr_file.path)
    current_target_headers = depset(current_target_hdr_files)

    textual_hdrs = []
    current_target_textual_hdr_files = []
    if "textual_hdrs" in result_attrs:
        for textual_hdr_target in result_attrs["textual_hdrs"]:
            textual_hdr_files = textual_hdr_target.files.to_list()
            for f in textual_hdr_files:
                current_target_textual_hdr_files.append(f)
            for hdr_file in textual_hdr_files:
                textual_hdrs.append(hdr_file.path)
    current_target_textual_headers = depset(current_target_textual_hdr_files)

    current_target_xcframework_import_files = []
    if "xcframework_imports" in result_attrs:
        for src_target in result_attrs["xcframework_imports"]:
            src_files = src_target.files.to_list()
            for f in src_files:
                if f != ".DS_Store":
                    current_target_xcframework_import_files.append(f)
            for src_file in src_files:
                sources.append(src_file.path)
    current_target_xcframework_imports = depset(current_target_xcframework_import_files)

    module_type = result_attrs["type"]

    if module_type == "root":
        pass
    elif module_type == "apple_static_xcframework_import":
        if not str(ctx.label).startswith("@@//"):
            fail("Invalid label: {}".format(ctx.label))
        module_path = str(ctx.label).split(":")[0].split("@@//")[1]

        module_info = {
            "name": result_attrs["name"],
            "type": module_type,
            "path": module_path,
            "sources": sorted(sources),
            "module_name": module_name,
        }
        if result_attrs["name"] in all_modules:
            fail("Duplicate module name: {}".format(result_attrs["name"]))
        all_modules[result_attrs["name"]] = module_info
    elif module_type == "objc_library" or module_type == "swift_library" or module_type == "cc_library":
        # Collect dependency labels
        dep_names = []
        if "deps" in result_attrs:
            for dep in result_attrs["deps"]:
                if hasattr(dep, "label"):
                    dep_label = str(dep.label)
                    dep_name = dep_label.split(":")[-1]
                    dep_names.append(dep_name)
                else:
                    fail("Missing dependency label")
        
        if module_type == "objc_library" or module_type == "swift_library":
            if result_attrs["module_name"] != result_attrs["name"]:
                fail("Module name mismatch: {} != {}".format(result_attrs["module_name"], result_attrs["name"]))
        
        # Extract the path from the label
        # Example: @//path/ModuleName:ModuleSubname -> path/ModuleName
        if not str(ctx.label).startswith("@@//"):
            fail("Invalid label: {}".format(ctx.label))
        module_path = str(ctx.label).split(":")[0].split("@@//")[1]

        if module_type == "objc_library":
            module_info = {
                "name": result_attrs["name"],
                "type": module_type,
                "path": module_path,
                "defines": result_attrs["defines"],
                "deps": dep_names,
                "sources": sorted(sources + headers),
                "module_name": module_name,
                "copts": result_attrs["copts"],
                "cxxopts": result_attrs["cxxopts"],
                "sdk_frameworks": result_attrs["sdk_frameworks"],
                "sdk_dylibs": result_attrs["sdk_dylibs"],
                "weak_sdk_frameworks": result_attrs["weak_sdk_frameworks"],
                "includes": result_attrs["includes"],
            }
        elif module_type == "cc_library":
            module_info = {
                "name": result_attrs["name"],
                "type": module_type,
                "path": module_path,
                "defines": result_attrs["defines"],
                "deps": dep_names,
                "sources": sorted(sources + headers + textual_hdrs),
                "module_name": module_name,
                "copts": result_attrs["copts"],
                "cxxopts": result_attrs["cxxopts"],
                "includes": result_attrs["includes"],
            }
        elif module_type == "swift_library":
            module_info = {
                "name": result_attrs["name"],
                "type": module_type,
                "path": module_path,
                "defines": result_attrs["defines"],
                "deps": dep_names,
                "sources": sorted(sources),
                "module_name": module_name,
                "copts": result_attrs["copts"],
            }
        else:
            fail("Unknown module type: {}".format(module_type))
        
        if result_attrs["name"] in all_modules:
            fail("Duplicate module name: {}".format(result_attrs["name"]))
        all_modules[result_attrs["name"]] = module_info
    elif result_attrs["type"] == "ios_application":
        pass
    else:
        fail("Unknown rule type: {}".format(ctx.rule.kind))
    
    # Add current target's sources and headers to the transitive set
    final_transitive_sources = depset(transitive = [
        transitive_sources_from_deps, 
        current_target_sources, 
        current_target_headers,
        current_target_textual_headers,
        current_target_xcframework_imports,
    ])
    
    # Return both the SPM output files and the provider with modules data and sources
    return [
        SPMModulesInfo(
            modules = all_modules,
            transitive_sources = final_transitive_sources,
        ),
    ]

spm_modules_aspect = aspect(
    implementation = _collect_spm_modules_impl,
    attr_aspects = ["deps"],
)

def _generate_spm_impl(ctx):
    outputs = []
    dep_transitive_sources_list = []

    if len(ctx.attr.deps) != 1:
        fail("generate_spm must have exactly one dependency")
    if SPMModulesInfo not in ctx.attr.deps[0]:
        fail("generate_spm must have a dependency with SPMModulesInfo provider")

    spm_info = ctx.attr.deps[0][SPMModulesInfo]
    modules = spm_info.modules

    # Declare and write the modules JSON file
    modules_json_out = ctx.actions.declare_file("%s_modules.json" % ctx.label.name)
    ctx.actions.write(
        output = modules_json_out,
        content = json.encode_indent(modules, indent = "  "), # Use encode_indent for readability
    )
    outputs.append(modules_json_out)
    
    for dep in ctx.attr.deps:
        if SPMModulesInfo in dep:
            # Add transitive sources depset from dependency
            dep_transitive_sources_list.append(dep[SPMModulesInfo].transitive_sources)
    
    # Merge all transitive sources from dependencies
    transitive_sources_from_deps = depset(transitive = dep_transitive_sources_list)
    
    # Return DefaultInfo containing only the output files in the 'files' field,
    # but include the transitive sources in 'runfiles' to enforce the dependency.
    return [DefaultInfo(
        files = depset(outputs),
        runfiles = ctx.runfiles(transitive_files = transitive_sources_from_deps),
    )]

generate_spm = rule(
    implementation = _generate_spm_impl,
    attrs = {
        'deps' : attr.label_list(aspects = [spm_modules_aspect]),
    },
)
