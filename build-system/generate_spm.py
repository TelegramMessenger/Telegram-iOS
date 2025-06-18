#! /usr/bin/env python3

import sys
import os
import sys
import json
import shutil
import re

# Read the modules JSON file
modules_json_path = "bazel-bin/Telegram/spm_build_root_modules.json"

with open(modules_json_path, 'r') as f:
    modules = json.load(f)

# Clean spm-files
spm_files_dir = "spm-files"
if os.path.exists(spm_files_dir):
    for item in os.listdir(spm_files_dir):
        if item != ".build":
            item_path = os.path.join(spm_files_dir, item)
            if os.path.isfile(item_path):
                os.unlink(item_path)
            elif os.path.isdir(item_path):
                shutil.rmtree(item_path)
if not os.path.exists(spm_files_dir):
    os.makedirs(spm_files_dir)

def escape_swift_string_literal_component(text: str) -> str:
    # Handle -D defines that use shell-style quoting like -DPACKAGE_STRING='""'
    # In Bazel, this gets processed by shell to become -DPACKAGE_STRING=""
    # In SwiftPM, we need to manually do this processing
    if text.startswith("-D") and "=" in text:
        # Split on the first = to get key and value parts
        define_part, value_part = text.split("=", 1)
        
        # Check if value is wrapped in single quotes (shell-style escaping)
        if value_part.startswith("'") and value_part.endswith("'") and len(value_part) >= 2:
            # Remove the outer single quotes
            inner_value = value_part[1:-1]
            # Escape the inner value for Swift string literal
            escaped_inner = inner_value.replace('\\', '\\\\').replace('"', '\\"')
            return f"{define_part}={escaped_inner}"
    
    # For non-define flags or defines without shell quoting, just escape for Swift string literal
    return text.replace('\\', '\\\\').replace('"', '\\"')

parsed_modules = {}
for name, module in sorted(modules.items()):
    is_empty = False
    all_source_files = []
    for source in module.get("hdrs", []) + module.get("textual_hdrs", []) + module["sources"]:
        if source.endswith(('.a')):
            continue
        all_source_files.append(source)
    if module["type"] == "objc_library" or module["type"] == "swift_library" or module["type"] == "cc_library":
        if all_source_files == []:
            is_empty = True
    parsed_modules[name] = {
        "is_empty": is_empty,
    }

combined_lines = []
combined_lines.append("// swift-tools-version: 6.0")
combined_lines.append("// The swift-tools-version declares the minimum version of Swift required to build this package.")
combined_lines.append("")
combined_lines.append("import PackageDescription")
combined_lines.append("")
combined_lines.append("let package = Package(")
combined_lines.append("    name: \"Telegram\",")
combined_lines.append("    platforms: [")
combined_lines.append("        .iOS(.v12)")
combined_lines.append("    ],")
combined_lines.append("    products: [")

for name, module in sorted(modules.items()):
    if parsed_modules[name]["is_empty"]:
        continue
    
    if module["type"] == "objc_library" or module["type"] == "swift_library" or module["type"] == "cc_library":
        combined_lines.append("        .library(name: \"%s\", targets: [\"%s\"])," % (module["name"], module["name"]))

combined_lines.append("    ],")
combined_lines.append("    targets: [")

for name, module in sorted(modules.items()):
    if parsed_modules[name]["is_empty"]:
        continue

    module_type = module["type"]
    if module_type == "objc_library" or module_type == "cc_library" or module_type == "swift_library":
        combined_lines.append("        .target(")
        combined_lines.append("            name: \"%s\"," % name)
        
        relative_module_path = module["path"] + "/Module_" + name
        module_directory = spm_files_dir + "/" + relative_module_path
        os.makedirs(module_directory, exist_ok=True)

        module_sources_directory = module_directory + "/Sources"
        if not os.path.exists(module_sources_directory):
            os.makedirs(module_sources_directory)
        
        module_public_includes_directory = module_directory + "/PublicIncludes"
        if not os.path.exists(module_public_includes_directory):
            os.makedirs(module_public_includes_directory)

        module_public_headers_prefix = None
        if len(module["includes"]) > 1:
            print("{}: Multiple includes are not yet supported: {}".format(name, module["includes"]))
            sys.exit(1)
        elif len(module["includes"]) == 1:
            for include_directory in module["includes"]:
                if include_directory != ".":
                    #print("{}: Include directory: {}".format(name, include_directory))
                    module_public_headers_prefix = include_directory
                    break

        combined_lines.append("            dependencies: [")
        for dep in module["deps"]:
            if not parsed_modules[dep]["is_empty"]:
                combined_lines.append("                .target(name: \"%s\")," % dep)
        combined_lines.append("            ],")

        # All modules now use the symlinked directory path
        combined_lines.append("            path: \"%s\"," % relative_module_path)

        # Since we control the entire directory structure, we don't need exclude logic
        combined_lines.append("            exclude: [")
        combined_lines.append("            ],")
        
        combined_lines.append("            sources: [")
        for source in module["sources"] + module.get("hdrs", []) + module.get("textual_hdrs", []):
            # Process all sources (both regular and generated) with symlinks
            if source.startswith("bazel-out/"):
                # Generated file - extract relative path within module
                if module["path"] in source:
                    source_file_name = source[source.index(module["path"]) + len(module["path"]) + 1:]
                else:
                    print("Source {} is not inside module path {}".format(source, module["path"]))
                    sys.exit(1)
            else:
                # Regular file - must be within module path
                if not source.startswith(module["path"]):
                    print("Source {} is not inside module path {}".format(source, module["path"]))
                    sys.exit(1)
                source_file_name = source[len(module["path"]) + 1:]

            # Create symlink for this source file
            is_public_include = False
            if module_public_headers_prefix is not None:
                if source_file_name.startswith(module_public_headers_prefix):
                    symlink_location = os.path.join(module_public_includes_directory, source_file_name[len(module_public_headers_prefix) + 1:])
                    #print("{}: Public include: {}".format(source_file_name, symlink_location))
                    is_public_include = True

            if not is_public_include:
                symlink_location = os.path.join(module_sources_directory, source_file_name)

            # Create parent directory for symlink if it doesn't exist
            symlink_parent = os.path.dirname(symlink_location)
            if not os.path.exists(symlink_parent):
                os.makedirs(symlink_parent)
            
            # Calculate relative path from symlink back to original file
            # Count directory depth: spm-files/module_name/... -> workspace root
            num_parent_dirs = symlink_location.count(os.path.sep)
            relative_prefix = "".join(["../"] * num_parent_dirs)
            symlink_target = relative_prefix + source
            
            # Create the symlink
            if os.path.lexists(symlink_location):
                os.unlink(symlink_location)
            os.symlink(symlink_target, symlink_location)
            
            # Add to sources list (exclude certain file types)
            if not source.endswith(('.h', '.hpp', '.a', '.inc')):
                combined_lines.append("                \"%s\"," % ("Sources/" + source_file_name))
                
        combined_lines.append("            ],")
        if module_type == "objc_library" or module_type == "cc_library":
            combined_lines.append("            publicHeadersPath: \"PublicIncludes\",")

            if len(module["includes"]) > 1:
                print("{}: Multiple includes are not yet supported: {}".format(name, module["includes"]))

            defines = module.get("defines", [])
            copts = module.get("copts", [])
            cxxopts = module.get("cxxopts", [])

            if defines or copts or (module_public_headers_prefix is not None):
                combined_lines.append("            cSettings: [")
                if defines:
                    for define in defines:
                        if "=" in define:
                            print("{}: Defines with = are not yet supported: {}".format(name, define))
                            sys.exit(1)
                        else:
                            combined_lines.append(f'                .define("{define}"),')
                if copts:
                    combined_lines.append("                .unsafeFlags([")
                    for flag in copts:
                        escaped_flag = escape_swift_string_literal_component(flag)
                        combined_lines.append(f'                    "{escaped_flag}",')
                        if escaped_flag.startswith("-I"):
                            include_path = escaped_flag[2:]
                            print("{}: Include path: {}".format(name, include_path))
                            for another_module_name, another_module in sorted(modules.items()):
                                another_module_path = another_module["path"]
                                if include_path.startswith(another_module_path):
                                    relative_module_include_path = include_path[len(another_module_path) + 1:]
                                    #print("    {}: Matches module: {}".format(another_module_name, another_module_path))

                                    combined_lines.append(f'                    "-I{another_module_path}/Sources/{relative_module_include_path}",')

                                another_module_public_headers_prefix = None
                                if len(another_module["includes"]) == 1:
                                    for include_directory in another_module["includes"]:
                                        if include_directory != ".":
                                            another_module_public_headers_prefix = another_module_path + "/" + include_directory
                                            print("    {}: Another module public include: {}".format(another_module_name, another_module_public_headers_prefix))
                                if another_module_public_headers_prefix is not None:
                                    if include_path.startswith(another_module_public_headers_prefix):
                                        relative_module_include_path = include_path[len(another_module_public_headers_prefix) + 1:]
                                        print("    {}: Matches module public include: {}".format(another_module_name, another_module_public_headers_prefix))

                                        combined_lines.append(f'                    -"-I{another_module_path}/PublicIncludes/{relative_module_include_path}",')
                    combined_lines.append("                ]),")
                if module_public_headers_prefix is not None:
                    combined_lines.append(f"                .headerSearchPath(\"{module_public_headers_prefix}\"),")
                combined_lines.append("            ],")

            if defines or cxxopts: # Check for defines OR cxxopts
                combined_lines.append("            cxxSettings: [")
                if defines: # Add defines again if present, for C++ context
                    for define in defines:
                        if "=" in define:
                            print("{}: Defines with = are not yet supported: {}".format(name, define))
                            sys.exit(1)
                        else:
                            combined_lines.append(f'                .define("{define}"),')
                if cxxopts:
                    combined_lines.append("                .unsafeFlags([")
                    for flag in cxxopts:
                        if flag.startswith("-std=") and True:
                            if flag != "-std=c++17":
                                print("{}: Unsupported C++ standard: {}".format(name, flag))
                                sys.exit(1)
                            else:
                                continue
                        escaped_flag = escape_swift_string_literal_component(flag)
                        combined_lines.append(f'                    "{escaped_flag}",')
                    combined_lines.append("                ])")
                combined_lines.append("            ],")

            combined_lines.append("            linkerSettings: [")
            if module_type == "objc_library":
                for framework in module["sdk_frameworks"]:
                    combined_lines.append("                .linkedFramework(\"%s\")," % framework)
                for dylib in module["sdk_dylibs"]:
                    combined_lines.append("                .linkedLibrary(\"%s\")," % dylib)
            combined_lines.append("            ]")
            
        elif module_type == "swift_library":
            defines = module.get("defines", [])
            swift_copts = module.get("copts", []) # These are actual swiftc flags

            # Handle cSettings for defines if they exist
            if defines:
                combined_lines.append("            cSettings: [")
                for define in defines:
                    combined_lines.append(f'                .define("{define}"),')
                combined_lines.append("            ],")

            # Handle swiftSettings
            combined_lines.append("            swiftSettings: [")
            combined_lines.append("                .swiftLanguageMode(.v5),")
            # Add defines to swiftSettings as simple .define("STRING") flags
            if defines:
                for define in defines:
                    # For Swift settings, the define is passed as a single string, e.g., "KEY=VALUE" or "FLAG"
                    escaped_define = escape_swift_string_literal_component(define) # Escape the whole define string
                    combined_lines.append(f'                .define("{escaped_define}"),')

            # Add copts (swiftc flags) to unsafeFlags in swiftSettings
            if swift_copts:
                combined_lines.append("                .unsafeFlags([")
                for flag in swift_copts:
                    escaped_flag = escape_swift_string_literal_component(flag)
                    combined_lines.append(f'                    "{escaped_flag}",')
                combined_lines.append("                ])")
            combined_lines.append("            ]")
        combined_lines.append("        ),")
    elif module["type"] == "root":
        pass
    else:
        print("Unknown module type: {}".format(module["type"]))
        sys.exit(1)

combined_lines.append("    ],")
combined_lines.append("    cxxLanguageStandard: .cxx17")
combined_lines.append(")")
combined_lines.append("")

with open("spm-files/Package.swift", "w") as f:
    f.write("\n".join(combined_lines))
