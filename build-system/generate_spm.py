#! /usr/bin/env python3

import sys
import os
import sys
import json
import shutil

# Read the modules JSON file
modules_json_path = "bazel-bin/Telegram/spm_build_root_modules.json"

with open(modules_json_path, 'r') as f:
    modules = json.load(f)

# Clean spm-files
spm_files_dir = "spm-files"
if os.path.exists(spm_files_dir):
    shutil.rmtree(spm_files_dir)
if not os.path.exists(spm_files_dir):
    os.makedirs(spm_files_dir)

def escape_swift_string_literal_component(text: str) -> str:
    return text.replace('\\', '\\\\').replace('"', '\\"')

parsed_modules = {}
for name, module in sorted(modules.items()):
    is_empty = False
    all_source_files = []
    for source in module.get("hdrs", []) + module["sources"]:
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

        linked_directory = None
        has_non_linked_sources = False
        for source in module["sources"] + module.get("hdrs", []):
            if source.startswith("bazel-out/"):
                linked_directory = "spm-files/" + name
            else:
                has_non_linked_sources = True
        if linked_directory and has_non_linked_sources:
            print("Module {} has both regular and generated sources".format(name))
            sys.exit(1)
        if linked_directory:
            os.makedirs(linked_directory)
        
        combined_lines.append("            dependencies: [")
        for dep in module["deps"]:
            if not parsed_modules[dep]["is_empty"]:
                combined_lines.append("                .target(name: \"%s\")," % dep)
        combined_lines.append("            ],")

        if linked_directory:
            combined_lines.append("            path: \"%s\"," % linked_directory)
        else:
            combined_lines.append("            path: \"%s\"," % module["path"])

        combined_lines.append("            exclude: [")
        exclude_files_and_dirs = []
        if not linked_directory:
            for root, dirs, files in os.walk(module["path"]):
                rel_path = os.path.relpath(root, module["path"])
                if rel_path == ".":
                    rel_path = ""
                else:
                    rel_path += "/"
                
                # Add directories that should be excluded
                for d in dirs:
                    dir_path = os.path.join(rel_path, d)
                    if any(component.startswith('.') for component in dir_path.split('/')):
                        continue
                    # Check if any source file is under this directory
                    has_source = False
                    for source in module["sources"] + module.get("hdrs", []):
                        rel_source = source[len(module["path"]) + 1:]
                        if rel_source.startswith(dir_path + "/"):
                            has_source = True
                            break
                    if not has_source:
                        exclude_files_and_dirs.append(dir_path)
                
                # Add files that should be excluded
                for f in files:
                    file_path = os.path.join(rel_path, f)
                    if any(component.startswith('.') for component in file_path.split('/')):
                        continue
                    if file_path not in [source[len(module["path"]) + 1:] for source in module["sources"] + module.get("hdrs", [])]:
                        exclude_files_and_dirs.append(file_path)
        for item in exclude_files_and_dirs:
            combined_lines.append("                \"%s\"," % item)
        combined_lines.append("            ],")
        
        combined_lines.append("            sources: [")
        for source in module["sources"] + module.get("hdrs", []):
            linked_source_file_names = []
            if not source.startswith(module["path"]):
                if source.startswith("bazel-out/"):
                    if not linked_directory:
                        print("Source {} is a generated file, but module {} has no linked directory".format(source, name))
                        sys.exit(1)
                    if module["path"] in source:
                        source_file_name = source[source.index(module["path"]) + len(module["path"]) + 1:]
                    else:
                        print("Source {} is not inside module path {}".format(source, module["path"]))
                        sys.exit(1)
                    if source_file_name in linked_source_file_names:
                        print("Source {} is a duplicate".format(source))
                        sys.exit(1)

                    linked_source_file_names.append(source_file_name)

                    # Create any parent directories needed for the source file
                    symlink_location = os.path.join(linked_directory, source_file_name)
                    source_dir = os.path.dirname(symlink_location)
                    if not os.path.exists(source_dir):
                        os.makedirs(source_dir)
                    
                    # Calculate the relative path from the symlink location back to the workspace root
                    num_parent_dirs = 2 + source_file_name.count(os.path.sep)
                    relative_prefix = "".join(["../"] * num_parent_dirs)
                    symlink_target = relative_prefix + source
                    
                    os.symlink(symlink_target, symlink_location)
                    relative_source = source_file_name
                    if not source.endswith(('.h', '.hpp', '.a')):
                        combined_lines.append("                \"%s\"," % relative_source)
                else:
                    print("Source {} is not inside module path {}".format(source, module["path"]))
                    sys.exit(1)
            else:
                relative_source = source[len(module["path"]) + 1:]
                combined_lines.append("                \"%s\"," % relative_source)
        combined_lines.append("            ],")
        if module_type == "objc_library" or module_type == "cc_library":
            if len(module["includes"]) == 0:
                combined_lines.append("            publicHeadersPath: \"\",")
            elif len(module["includes"]) == 1:
                combined_lines.append("            publicHeadersPath: \"%s\"," % module["includes"][0])
            else:
                print("{}: Multiple includes are not yet supported: {}".format(name, module["includes"]))
                sys.exit(1)

            defines = module.get("defines", [])
            copts = module.get("copts", [])
            cxxopts = module.get("cxxopts", [])

            if defines or copts:
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
                    combined_lines.append("                ])")
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
                        if flag.startswith("-std=") and False:
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

combined_lines.append("    ]")
#combined_lines.append("    cxxLanguageStandard: .cxx17")
combined_lines.append(")")
combined_lines.append("")

with open("Package.swift", "w") as f:
    f.write("\n".join(combined_lines))
