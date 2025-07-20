#! /usr/bin/env python3

import sys
import os
import sys
import json
import shutil
import hashlib

# Read the modules JSON file
modules_json_path = "bazel-bin/Telegram/spm_build_root_modules.json"

with open(modules_json_path, 'r') as f:
    modules = json.load(f)

# Clean spm-files
spm_files_dir = "spm-files"

previous_spm_files = set()

def scan_spm_files(path: str):
    global previous_spm_files
    if not os.path.exists(path):
        return
    for item in os.listdir(path):
        if item == ".build":
            continue
        item_path = os.path.join(path, item)
        if os.path.isfile(item_path) or os.path.islink(item_path):
            previous_spm_files.add(item_path)
        elif os.path.isdir(item_path):
            previous_spm_files.add(item_path)
            scan_spm_files(item_path)

scan_spm_files(spm_files_dir)

current_spm_files = set()

def create_spm_file(path: str, contents: str):
    global current_spm_files
    current_spm_files.add(path)
    
    # Track all parent directories
    parent_dir = os.path.dirname(path)
    while parent_dir and parent_dir != path:
        current_spm_files.add(parent_dir)
        parent_dir = os.path.dirname(parent_dir)
    
    with open(path, "w") as f:
        f.write(contents)

def link_spm_file(source_path: str, target_path: str):
    global current_spm_files
    current_spm_files.add(target_path)
    
    # Track all parent directories
    parent_dir = os.path.dirname(target_path)
    while parent_dir and parent_dir != target_path:
        current_spm_files.add(parent_dir)
        parent_dir = os.path.dirname(parent_dir)
    
    # Remove existing file/symlink if it exists and is different
    if os.path.islink(target_path):
        if os.readlink(target_path) != source_path:
            os.unlink(target_path)
        else:
            return  # Symlink already points to the correct target
    elif os.path.exists(target_path):
        os.unlink(target_path)
    
    os.symlink(source_path, target_path)

def create_spm_directory(path: str):
    global current_spm_files
    current_spm_files.add(path)
    if not os.path.exists(path):
        os.makedirs(path)

if not os.path.exists(spm_files_dir):
    os.makedirs(spm_files_dir)
    
# Track the root directory
current_spm_files.add(spm_files_dir)

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

# Parses -D flag into a tuple of (define_flag, define_value)
# Example: flag="ABC" -> (ABC, None)
# Example: flag="ABC=123" -> (ABC, 123)
# Example: flag="ABC=\"str\"" -> (ABC, "str")
def parse_define_flag(flag: str) -> tuple[str, str | None]:
    if flag.startswith("-D"):
        define_part = flag[2:]
    else:
        define_part = flag
    
    # Check if there's an assignment
    if "=" in define_part:
        key, value = define_part.split("=", 1)  # Split on first = only
        
        # Handle quoted values - remove surrounding quotes if present
        if (value.startswith('"') and value.endswith('"')) or (value.startswith("'") and value.endswith("'")):
            value = value[1:-1]  # Remove quotes
        value = value.replace("\\\"", "\"")

        #if key == "PACKAGE_VERSION":
        #    print(f"PACKAGE_VERSION={value}")
        
        return (key, value)
    else:
        # No assignment, just a flag name
        return (define_part, None)

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

spm_products = []
spm_targets = []
module_to_source_files = dict()
modulemaps = dict()

combined_lines = []
combined_lines.append("// swift-tools-version: 6.0")
combined_lines.append("// The swift-tools-version declares the minimum version of Swift required to build this package.")
combined_lines.append("")
combined_lines.append("import PackageDescription")
combined_lines.append("import Foundation")
combined_lines.append("""
func parseProduct(product: [String: Any]) -> Product {
    let name = product[\"name\"] as! String
    let targets = product[\"targets\"] as! [String]
    return .library(name: name, targets: targets)
}""")
combined_lines.append("""
func parseTarget(target: [String: Any]) -> Target {
    let name = target["name"] as! String
    let type = target["type"] as! String
    let dependencies = target["dependencies"] as! [String]
                      
    if type == "library" {
        var swiftSettings: [SwiftSetting]?
        if let swiftSettingList = target["swiftSettings"] as? [[String: Any]] {
            var swiftSettingsValue: [SwiftSetting] = []
            swiftSettingsValue.append(.swiftLanguageMode(.v5))
            for swiftSetting in swiftSettingList {
                if swiftSetting["type"] as! String == "define" {
                    swiftSettingsValue.append(.define(swiftSetting["name"] as! String))
                } else if swiftSetting["type"] as! String == "unsafeFlags" {
                    swiftSettingsValue.append(.unsafeFlags(swiftSetting["flags"] as! [String]))
                } else {
                    print("Unknown swift setting type: \\(swiftSetting["type"] as! String)")
                    preconditionFailure("Unknown swift setting type: \\(swiftSetting["type"] as! String)")
                }
            }
                        
            swiftSettings = swiftSettingsValue
        }
                        
        var cSettings: [CSetting]?
        if let cSettingList = target["cSettings"] as? [[String: Any]] {
            var cSettingsValue: [CSetting] = []
            for cSetting in cSettingList {
                if cSetting["type"] as! String == "define" {
                    if let value = cSetting["value"] as? String {
                        cSettingsValue.append(.define(cSetting["name"] as! String, to: value))
                    } else {
                        cSettingsValue.append(.define(cSetting["name"] as! String))
                    }
                } else if cSetting["type"] as! String == "unsafeFlags" {
                    cSettingsValue.append(.unsafeFlags(cSetting["flags"] as! [String]))
                } else {
                    print("Unknown c setting type: \\(cSetting["type"] as! String)")
                    preconditionFailure("Unknown c setting type: \\(cSetting["type"] as! String)")
                }
            }
            cSettings = cSettingsValue
        }

        var cxxSettings: [CXXSetting]?
        if let cxxSettingList = target["cxxSettings"] as? [[String: Any]] {
            var cxxSettingsValue: [CXXSetting] = []
            for cxxSetting in cxxSettingList {
                if cxxSetting["type"] as! String == "define" {
                    if let value = cxxSetting["value"] as? String {
                        cxxSettingsValue.append(.define(cxxSetting["name"] as! String, to: value))
                    } else {
                        cxxSettingsValue.append(.define(cxxSetting["name"] as! String))
                    }
                } else if cxxSetting["type"] as! String == "unsafeFlags" {
                    cxxSettingsValue.append(.unsafeFlags(cxxSetting["flags"] as! [String]))
                } else {
                    print("Unknown cxx setting type: \\(cxxSetting["type"] as! String)")
                    preconditionFailure("Unknown cxx setting type: \\(cxxSetting["type"] as! String)")
                }
            }
            cxxSettings = cxxSettingsValue
        }
                        
        var linkerSettings: [LinkerSetting]?
        if let linkerSettingList = target["linkerSettings"] as? [[String: Any]] {
            var linkerSettingsValue: [LinkerSetting] = []
            for linkerSetting in linkerSettingList {
                if linkerSetting["type"] as! String == "framework" {
                    linkerSettingsValue.append(.linkedFramework(linkerSetting["name"] as! String))
                } else if linkerSetting["type"] as! String == "library" {
                    linkerSettingsValue.append(.linkedLibrary(linkerSetting["name"] as! String))
                } else {
                    print("Unknown linker setting type: \\(linkerSetting["type"] as! String)")
                    preconditionFailure("Unknown linker setting type: \\(linkerSetting["type"] as! String)")
                }
            }
            linkerSettings = linkerSettingsValue
        }

        return .target(
            name: name,
            dependencies: dependencies.map({ .target(name: $0) }),
            path: (target["path"] as? String)!,
            exclude: target["exclude"] as? [String] ?? [],
            sources: sourceFileMap[name]!,
            resources: nil,
            publicHeadersPath: target["publicHeadersPath"] as? String,
            packageAccess: true,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings,
            plugins: nil
        )
    } else if type == "xcframework" {
        return .binaryTarget(name: name, path: (target["path"] as? String)! + "/" + (target["name"] as? String)! + ".xcframework.zip")
    } else {
        print("Unknown target type: \\(type)")
        preconditionFailure("Unknown target type: \\(type)")
    }
}
""")
combined_lines.append("")
combined_lines.append("let packageData: [String: Any] = try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: \"PackageData.json\")), options: []) as! [String: Any]")
combined_lines.append("let sourceFileMap: [String: [String]] = packageData[\"sourceFileMap\"] as! [String: [String]]")
combined_lines.append("let products: [Product] = (packageData[\"products\"] as! [[String: Any]]).map(parseProduct)")
combined_lines.append("let targets: [Target] = (packageData[\"targets\"] as! [[String: Any]]).map(parseTarget)")
combined_lines.append("")
combined_lines.append("let package = Package(")
combined_lines.append("    name: \"Telegram\",")
combined_lines.append("    platforms: [")
combined_lines.append("        .iOS(.v13)")
combined_lines.append("    ],")
combined_lines.append("    products: products,")

for name, module in sorted(modules.items()):
    if parsed_modules[name]["is_empty"]:
        continue
    
    if module["type"] == "objc_library" or module["type"] == "swift_library" or module["type"] == "cc_library" or module["type"] == "apple_static_xcframework_import":
        spm_products.append({
            "name": module["name"],
            "targets": [module["name"]],
        })

combined_lines.append("    targets: targets,")

for name, module in sorted(modules.items()):
    if parsed_modules[name]["is_empty"]:
        continue

    module_type = module["type"]
    if module_type == "objc_library" or module_type == "cc_library" or module_type == "swift_library" or module_type == "apple_static_xcframework_import":
        spm_target = dict()

        spm_target["name"] = name
        
        relative_module_path = module["path"]
        module_directory = spm_files_dir + "/" + relative_module_path
        create_spm_directory(module_directory)

        module_public_headers_prefix = ""
        if module_type == "objc_library" or module_type == "cc_library":
            if len(module["includes"]) > 1:
                print("{}: Multiple includes are not yet supported: {}".format(name, module["includes"]))
                sys.exit(1)
            elif len(module["includes"]) == 1:
                for include_directory in module["includes"]:
                    if include_directory != ".":
                        #print("{}: Include directory: {}".format(name, include_directory))
                        module_public_headers_prefix = include_directory
                        break

        spm_target["dependencies"] = []
        for dep in module.get("deps", []):
            if not parsed_modules[dep]["is_empty"]:
                spm_target["dependencies"].append(dep)
        
        spm_target["path"] = relative_module_path

        include_source_files = []
        exclude_source_files = []
        public_include_files = []
        
        sources_zip_directory = None
        if module["type"] == "apple_static_xcframework_import":
            pass
        
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
            symlink_location = os.path.join(module_directory, source_file_name)

            # Create parent directory for symlink if it doesn't exist
            symlink_parent = os.path.dirname(symlink_location)
            create_spm_directory(symlink_parent)
            
            # Calculate relative path from symlink back to original file
            # Count directory depth: spm-files/module_name/... -> spm-files
            num_parent_dirs = symlink_location.count(os.path.sep)
            relative_prefix = "".join(["../"] * num_parent_dirs)
            symlink_target = relative_prefix + source
            
            # Create the symlink
            link_spm_file(symlink_target, symlink_location)
            
            # Add to sources list (exclude certain file types)
            if source.endswith(('.h', '.hpp', '.a', '.inc')):
                if len(module_public_headers_prefix) != 0 and source_file_name.startswith(module_public_headers_prefix):
                    public_include_files.append(source_file_name[len(module_public_headers_prefix) + 1:])
                exclude_source_files.append(source_file_name)
            else:
                include_source_files.append(source_file_name)

        if name in module_to_source_files:
            print(f"{name}: duplicate module")
            sys.exit(1)
        module_to_source_files[name] = include_source_files
        
        ignore_sub_folders = []
        for other_name, other_module in sorted(modules.items()):
            if other_module["path"] != module["path"] and other_module["path"].startswith(module["path"] + "/"):
                exclude_path = other_module["path"][len(module["path"]) + 1:]
                ignore_sub_folders.append(exclude_path)
        if len(ignore_sub_folders) != 0:
            spm_target["exclude"] = ignore_sub_folders
        
        if module_type == "objc_library" or module_type == "cc_library":
            modulemap_path = os.path.join(os.path.join(os.path.join(module_directory), module_public_headers_prefix), "module.modulemap")
            if modulemap_path not in modulemaps:
                modulemaps[modulemap_path] = []
            modulemaps[modulemap_path].append({
                "name": name,
                "public_include_files": public_include_files
            })
                
        if module_type == "objc_library" or module_type == "cc_library":
            if module_public_headers_prefix is not None and len(module_public_headers_prefix) != 0:
                spm_target["publicHeadersPath"] = module_public_headers_prefix
            else:
                spm_target["publicHeadersPath"] = ""

            if len(module["includes"]) > 1:
                print("{}: Multiple includes are not yet supported: {}".format(name, module["includes"]))

            defines = module.get("defines", [])
            copts = module.get("copts", [])
            cxxopts = module.get("cxxopts", [])

            if defines or copts or (module_public_headers_prefix is not None):
                spm_target["cSettings"] = []

                if defines:
                    for define in defines:
                        if "=" in define:
                            print("{}: Defines with = are not yet supported: {}".format(name, define))
                            sys.exit(1)
                        else:
                            spm_target["cSettings"].append({
                                "type": "define",
                                "name": define
                            })
                if copts:
                    unsafe_flags = []
                    for flag in copts:
                        if flag.startswith("-D"):
                            define_flag, define_value = parse_define_flag(flag)
                            if define_value is None:
                                spm_target["cSettings"].append({
                                    "type": "define",
                                    "name": define_flag
                                })
                            else:
                                spm_target["cSettings"].append({
                                    "type": "define",
                                    "name": define_flag,
                                    "value": define_value
                                })
                        else:
                            escaped_flag = escape_swift_string_literal_component(flag)
                            unsafe_flags.append(escaped_flag)
                    spm_target["cSettings"].append({
                        "type": "unsafeFlags",
                        "flags": unsafe_flags
                    })

            if defines or cxxopts: # Check for defines OR cxxopts
                spm_target["cxxSettings"] = []
                if defines: # Add defines again if present, for C++ context
                    for define in defines:
                        if "=" in define:
                            print("{}: Defines with = are not yet supported: {}".format(name, define))
                            sys.exit(1)
                        else:
                            spm_target["cxxSettings"].append({
                                "type": "define",
                                "name": define
                            })
                if cxxopts:
                    unsafe_flags = []
                    for flag in cxxopts:
                        if flag.startswith("-std=") and True:
                            if flag != "-std=c++17":
                                print("{}: Unsupported C++ standard: {}".format(name, flag))
                                sys.exit(1)
                            else:
                                continue
                        escaped_flag = escape_swift_string_literal_component(flag)
                        unsafe_flags.append(escaped_flag)
                    spm_target["cxxSettings"].append({
                        "type": "unsafeFlags",
                        "flags": unsafe_flags
                    })

            spm_target["linkerSettings"] = []
            if module_type == "objc_library":
                for framework in module["sdk_frameworks"]:
                    spm_target["linkerSettings"].append({
                        "type": "framework",
                        "name": framework
                    })
                for dylib in module["sdk_dylibs"]:
                    spm_target["linkerSettings"].append({
                        "type": "library",
                        "name": dylib
                    })
                    spm_target["linkerSettings"].append({
                        "type": "library",
                        "name": dylib
                    })
        
        elif module_type == "swift_library":
            defines = module.get("defines", [])
            swift_copts = module.get("copts", []) # These are actual swiftc flags

            # Handle cSettings for defines if they exist
            if defines:
                spm_target["cSettings"] = []
                for define in defines:
                    spm_target["cSettings"].append({
                        "type": "define",
                        "name": define
                    })

            spm_target["swiftSettings"] = []
            # Handle swiftSettings
            if defines:
                for define in defines:
                    # For Swift settings, the define is passed as a single string, e.g., "KEY=VALUE" or "FLAG"
                    escaped_define = escape_swift_string_literal_component(define) # Escape the whole define string
                    spm_target["swiftSettings"].append({
                        "type": "define",
                        "name": escaped_define
                    })

            # Add copts (swiftc flags) to unsafeFlags in swiftSettings
            if swift_copts:
                unsafe_flags = []
                for flag in swift_copts:
                    escaped_flag = escape_swift_string_literal_component(flag)
                    unsafe_flags.append(escaped_flag)
                spm_target["swiftSettings"].append({
                    "type": "unsafeFlags",
                    "flags": unsafe_flags
                })

        if module_type == "apple_static_xcframework_import":
            spm_target["type"] = "xcframework"
        else:
            spm_target["type"] = "library"

        spm_targets.append(spm_target)
    elif module["type"] == "root":
        pass
    else:
        print("Unknown module type: {}".format(module["type"]))
        sys.exit(1)

combined_lines.append("    cxxLanguageStandard: .cxx17")
combined_lines.append(")")
combined_lines.append("")

package_data = {
    "sourceFileMap": module_to_source_files,
    "products": spm_products,
    "targets": spm_targets
}
package_data_json = json.dumps(package_data, indent=4)
external_data_hash = hashlib.sha256(package_data_json.encode()).hexdigest()
combined_lines.append(f"// External data hash: {external_data_hash}")

create_spm_file("spm-files/Package.swift", "\n".join(combined_lines))
create_spm_file("spm-files/PackageData.json", package_data_json)

for modulemap_path, modulemap in modulemaps.items():
    module_map_contents = ""
    for module in modulemap:
        module_map_contents += "module {} {{\n".format(module["name"])
        for public_include_file in module["public_include_files"]:
            module_map_contents += "    header \"{}\"\n".format(public_include_file)
        module_map_contents += "}\n"
    create_spm_file(modulemap_path, module_map_contents)

# Clean up files and directories that are no longer needed
files_to_remove = previous_spm_files - current_spm_files

# Sort by path depth (deeper paths first) to ensure we remove files before their parent directories
sorted_files_to_remove = sorted(files_to_remove, key=lambda x: x.count(os.path.sep), reverse=True)

for file_path in sorted_files_to_remove:
    try:
        if os.path.islink(file_path):
            os.unlink(file_path)
            #print(f"Removed symlink: {file_path}")
        elif os.path.isfile(file_path):
            os.unlink(file_path)
            #print(f"Removed file: {file_path}")
        elif os.path.isdir(file_path):
            # Try to remove directory if empty, otherwise use rmtree
            try:
                os.rmdir(file_path)
                #print(f"Removed empty directory: {file_path}")
            except OSError:
                shutil.rmtree(file_path)
                #print(f"Removed directory tree: {file_path}")
    except OSError as e:
        print(f"Failed to remove {file_path}: {e}")

