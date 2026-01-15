import Foundation
import PathKit
import XcodeProj

class TargetBuilder {
    let project: PBXProject
    let pbxproj: PBXProj
    let mainGroup: PBXGroup
    let outputDir: Path
    let symlinkManager: SymlinkManager

    private var targetsByName: [String: PBXNativeTarget] = [:]
    private var groupsByPath: [String: PBXGroup] = [:]

    init(project: PBXProject, pbxproj: PBXProj, mainGroup: PBXGroup, outputDir: Path, symlinkManager: SymlinkManager) {
        self.project = project
        self.pbxproj = pbxproj
        self.mainGroup = mainGroup
        self.outputDir = outputDir
        self.symlinkManager = symlinkManager
    }

    // Track which modules are header-only (have no linkable code)
    private var headerOnlyModules: Set<String> = []
    // Track which modules are static library collections (.a files)
    private var staticLibraryModules: [String: [String]] = [:]  // module name -> list of .a file paths

    func isHeaderOnlyModule(_ name: String) -> Bool {
        return headerOnlyModules.contains(name)
    }

    func isStaticLibraryModule(_ name: String) -> Bool {
        return staticLibraryModules[name] != nil
    }

    func getStaticLibraries(for name: String) -> [String] {
        return staticLibraryModules[name] ?? []
    }

    func buildTarget(for module: ModuleDefinition, allModules: [String: ModuleDefinition]) throws -> PBXNativeTarget? {
        guard let moduleType = ModuleType(from: module) else {
            print("Warning: Unknown module type \(module.type) for \(module.name)")
            return nil
        }

        // Check for static library modules (only .a files)
        let staticLibs = module.sources.filter { $0.hasSuffix(".a") }
        let nonStaticLibs = module.sources.filter { !$0.hasSuffix(".a") }
        let isStaticLibOnly = !staticLibs.isEmpty && nonStaticLibs.allSatisfy { $0.hasSuffix(".h") || $0.hasSuffix(".hpp") }

        if isStaticLibOnly && moduleType != .xcframework {
            // This is a static library module - track its .a files but don't create a framework
            staticLibraryModules[module.name] = staticLibs
            return nil  // Don't create a target, just track the static libs
        }

        // Check if module is header-only (only header files, no real sources)
        let sourceFiles = module.sources.filter { source in
            !source.hasSuffix(".a") && !source.hasSuffix(".h") && !source.hasSuffix(".hpp")
        }
        let isHeaderOnly = sourceFiles.isEmpty && moduleType != .xcframework

        // Skip modules with no sources at all
        if module.sources.isEmpty && moduleType != .xcframework {
            return nil
        }

        switch moduleType {
        case .xcframework:
            return try buildXCFrameworkTarget(for: module)
        case .swiftLibrary, .objcLibrary, .ccLibrary:
            if isHeaderOnly {
                headerOnlyModules.insert(module.name)
                return try buildHeaderOnlyFrameworkTarget(for: module)
            } else {
                return try buildFrameworkTarget(for: module, moduleType: moduleType)
            }
        }
    }

    private func buildXCFrameworkTarget(for module: ModuleDefinition) throws -> PBXNativeTarget {
        // For xcframeworks, we create a reference but no build phases
        let target = PBXNativeTarget(
            name: module.name,
            buildConfigurationList: createConfigurationList(for: module, isXCFramework: true),
            buildPhases: [],
            productName: module.name,
            productType: .framework
        )
        pbxproj.add(object: target)
        project.targets.append(target)
        targetsByName[module.name] = target
        return target
    }

    private func buildFrameworkTarget(for module: ModuleDefinition, moduleType: ModuleType) throws -> PBXNativeTarget {
        // Create group for module
        let moduleGroup = try getOrCreateGroup(for: module.path)

        // Create symlinks and file references
        var sourceRefs: [PBXFileReference] = []
        var publicHeaderRefs: [PBXFileReference] = []
        var seenPublicHeaderNames: Set<String> = []  // Track header filenames to avoid duplicates in headers build phase

        // Determine public header detection:
        // 1. If hdrs is provided, use those (explicit public headers)
        // 2. Otherwise, headers in includes directories are public
        let explicitPublicHeaders = Set(module.hdrs ?? [])

        let allSourceFiles = module.sources + (module.hdrs ?? []) + (module.textualHdrs ?? [])

        for source in allSourceFiles {
            if source.hasSuffix(".a") { continue }

            let sourcePath = Path(source)
            let fileName = sourcePath.lastComponent

            // Calculate relative path within module
            let relativeToModule: String
            if source.hasPrefix(module.path + "/") {
                relativeToModule = String(source.dropFirst(module.path.count + 1))
            } else if source.hasPrefix("bazel-out/") {
                // Generated file
                if let range = source.range(of: module.path + "/") {
                    relativeToModule = String(source[range.upperBound...])
                } else {
                    relativeToModule = fileName
                }
            } else {
                relativeToModule = fileName
            }

            // Create symlink
            let symlinkPath = outputDir + module.path + relativeToModule
            try symlinkManager.createDirectory(symlinkPath.parent())
            try symlinkManager.createSymlink(from: Path(source), to: symlinkPath)

            // Create file reference
            let fileRef = try getOrCreateFileReference(
                path: relativeToModule,
                in: moduleGroup,
                modulePath: module.path,
                fileName: fileName
            )

            let isHeader = source.hasSuffix(".h") || source.hasSuffix(".hpp")

            // Determine if this is a public header:
            // 1. Explicitly in hdrs array
            // 2. Located in an includes directory
            let isPublicHeader: Bool
            if !isHeader {
                isPublicHeader = false
            } else if !explicitPublicHeaders.isEmpty {
                // If hdrs is provided, only those are public
                isPublicHeader = explicitPublicHeaders.contains(source)
            } else {
                // Headers in include directories are public (handles bazel-out paths)
                isPublicHeader = isInIncludesDirectory(source: source, modulePath: module.path, includes: module.includes)
            }

            if isPublicHeader {
                // Skip duplicate header filenames to avoid "multiple commands produce" errors
                if !seenPublicHeaderNames.contains(fileName) {
                    seenPublicHeaderNames.insert(fileName)
                    publicHeaderRefs.append(fileRef)
                }
            } else if !source.hasSuffix(".inc") && !isHeader {
                // Source files (not headers)
                sourceRefs.append(fileRef)
            }
            // Private headers are not added to any build phase
        }

        // Build phases
        var buildPhases: [PBXBuildPhase] = []

        // Sources build phase
        let sourcesBuildPhase = PBXSourcesBuildPhase(
            files: sourceRefs.map { ref in
                let buildFile = PBXBuildFile(file: ref)
                pbxproj.add(object: buildFile)
                return buildFile
            }
        )
        pbxproj.add(object: sourcesBuildPhase)
        buildPhases.append(sourcesBuildPhase)

        // Generate modulemap for ObjC/C++ modules (SPM-style explicit headers)
        var modulemapPath: Path? = nil
        if moduleType == .objcLibrary || moduleType == .ccLibrary {
            modulemapPath = try generateModulemap(for: module)

            // Headers build phase with public headers - needed for ObjC #import to work
            if !publicHeaderRefs.isEmpty {
                let headersBuildPhase = PBXHeadersBuildPhase(
                    files: publicHeaderRefs.map { ref in
                        let buildFile = PBXBuildFile(file: ref, settings: ["ATTRIBUTES": ["Public"]])
                        pbxproj.add(object: buildFile)
                        return buildFile
                    }
                )
                pbxproj.add(object: headersBuildPhase)
                buildPhases.append(headersBuildPhase)
            }
        }

        // Frameworks build phase
        let frameworksBuildPhase = PBXFrameworksBuildPhase(files: [])
        pbxproj.add(object: frameworksBuildPhase)
        buildPhases.append(frameworksBuildPhase)

        // Create target with custom modulemap if generated
        let configList = createConfigurationList(for: module, isXCFramework: false, modulemapPath: modulemapPath)

        let target = PBXNativeTarget(
            name: module.name,
            buildConfigurationList: configList,
            buildPhases: buildPhases,
            productName: module.name,
            productType: .framework
        )
        pbxproj.add(object: target)
        project.targets.append(target)
        targetsByName[module.name] = target

        return target
    }

    /// Build a framework target for header-only modules (just headers + modulemap, no sources)
    private func buildHeaderOnlyFrameworkTarget(for module: ModuleDefinition) throws -> PBXNativeTarget {
        // Create group for module
        let moduleGroup = try getOrCreateGroup(for: module.path)

        // Symlink header files and create file references
        var publicHeaderRefs: [PBXFileReference] = []
        var seenPublicHeaderNames: Set<String> = []  // Track header filenames to avoid duplicates
        let allHeaders = module.sources.filter { $0.hasSuffix(".h") || $0.hasSuffix(".hpp") } + (module.hdrs ?? []) + (module.textualHdrs ?? [])

        for source in allHeaders {
            let sourcePath = Path(source)
            let fileName = sourcePath.lastComponent
            let relativeToModule = relativePathInModule(source: source, modulePath: module.path)

            // Create parent group
            let parentPath = (Path(module.path) + Path(relativeToModule).parent()).string
            let parentGroup = try getOrCreateGroup(for: parentPath)

            // Create symlink
            let symlinkPath = outputDir + module.path + relativeToModule
            try symlinkManager.createDirectory(symlinkPath.parent())
            try symlinkManager.createSymlink(from: Path(source), to: symlinkPath)

            // Create file reference
            let fileType = lastKnownFileType(for: fileName)
            let fileRef = PBXFileReference(
                sourceTree: .group,
                name: fileName,
                lastKnownFileType: fileType,
                path: fileName
            )
            pbxproj.add(object: fileRef)
            parentGroup.children.append(fileRef)

            // Check if it's a public header (in includes directories)
            // Use helper that properly handles bazel-out paths
            let isPublic = isInIncludesDirectory(source: source, modulePath: module.path, includes: module.includes)
            if isPublic {
                // Skip duplicate header filenames to avoid "multiple commands produce" errors
                if !seenPublicHeaderNames.contains(fileName) {
                    seenPublicHeaderNames.insert(fileName)
                    publicHeaderRefs.append(fileRef)
                }
            }
        }

        // Generate modulemap for this header-only module
        let modulemapPath = try generateModulemap(for: module)

        // Create build phases
        var buildPhases: [PBXBuildPhase] = []

        // Headers build phase with public headers - needed for ObjC #import to work
        if !publicHeaderRefs.isEmpty {
            let headersBuildPhase = PBXHeadersBuildPhase(
                files: publicHeaderRefs.map { ref in
                    let buildFile = PBXBuildFile(file: ref, settings: ["ATTRIBUTES": ["Public"]])
                    pbxproj.add(object: buildFile)
                    return buildFile
                }
            )
            pbxproj.add(object: headersBuildPhase)
            buildPhases.append(headersBuildPhase)
        }

        // Empty frameworks phase (needed for Xcode, but won't link anything)
        let frameworksBuildPhase = PBXFrameworksBuildPhase(files: [])
        pbxproj.add(object: frameworksBuildPhase)
        buildPhases.append(frameworksBuildPhase)

        // Create target with custom modulemap
        let configList = createConfigurationList(for: module, isXCFramework: false, modulemapPath: modulemapPath)

        let target = PBXNativeTarget(
            name: module.name,
            buildConfigurationList: configList,
            buildPhases: buildPhases,
            productName: module.name,
            productType: .framework
        )
        pbxproj.add(object: target)
        project.targets.append(target)
        targetsByName[module.name] = target

        return target
    }

    /// Collect all transitive dependencies for a module
    private func collectAllDependencies(for moduleName: String, modules: [String: ModuleDefinition], visited: inout Set<String>) -> Set<String> {
        guard !visited.contains(moduleName) else { return [] }
        visited.insert(moduleName)

        guard let module = modules[moduleName], let deps = module.deps else {
            return []
        }

        var allDeps = Set(deps)
        for depName in deps {
            allDeps.formUnion(collectAllDependencies(for: depName, modules: modules, visited: &visited))
        }
        return allDeps
    }

    func wireUpDependencies(modules: [String: ModuleDefinition]) throws {
        for (name, module) in modules {
            guard let target = targetsByName[name],
                  let deps = module.deps else { continue }

            // Find frameworks build phase
            guard let frameworksPhase = target.buildPhases.compactMap({ $0 as? PBXFrameworksBuildPhase }).first else {
                continue
            }

            // Track all frameworks we've added to avoid duplicates
            var linkedFrameworks: Set<String> = []
            // Track library search paths for static libraries
            var staticLibSearchPaths: Set<String> = []

            // Add target dependency (only for direct deps)
            for depName in deps {
                if let depTarget = targetsByName[depName] {
                    let dependency = PBXTargetDependency(target: depTarget)
                    pbxproj.add(object: dependency)
                    target.dependencies.append(dependency)
                }
            }

            // Collect all transitive dependencies to link
            var visited = Set<String>()
            let allDeps = collectAllDependencies(for: name, modules: modules, visited: &visited)

            // Collect header paths from ALL dependencies (direct and transitive)
            var depHeaderPaths: [String] = []
            for depName in allDeps {
                if let depModule = modules[depName] {
                    depHeaderPaths.append(contentsOf: exportedHeaderPaths(for: depModule))
                }
            }

            // Link all dependencies (direct and transitive) that have targets
            for depName in allDeps {
                // Skip if already linked
                guard !linkedFrameworks.contains(depName) else { continue }

                // Check if this is a static library module - link .a files directly
                if isStaticLibraryModule(depName) {
                    // Link static libraries directly
                    for libPath in getStaticLibraries(for: depName) {
                        let libName = Path(libPath).lastComponent
                        // Create an absolute path to the project root then to the static library
                        // SRCROOT is xcode-files, so we need to go up one level to get to telegram-ios
                        let projectRoot = outputDir.parent()
                        let absoluteLibPath = (projectRoot + libPath).string
                        let libRef = PBXFileReference(
                            sourceTree: .absolute,
                            name: libName,
                            lastKnownFileType: "archive.ar",
                            path: absoluteLibPath
                        )
                        pbxproj.add(object: libRef)
                        let buildFile = PBXBuildFile(file: libRef)
                        pbxproj.add(object: buildFile)
                        frameworksPhase.files?.append(buildFile)

                        // Add the library's directory to LIBRARY_SEARCH_PATHS
                        let libDir = Path(absoluteLibPath).parent().string
                        if !staticLibSearchPaths.contains(libDir) {
                            staticLibSearchPaths.insert(libDir)
                        }
                    }
                    linkedFrameworks.insert(depName)
                    continue
                }

                // Skip header-only modules (no framework to link)
                if isHeaderOnlyModule(depName) { continue }

                // Regular framework dependency
                guard targetsByName[depName] != nil else { continue }

                linkedFrameworks.insert(depName)
                let frameworkRef = PBXFileReference(
                    sourceTree: .buildProductsDir,
                    name: "\(depName).framework",
                    lastKnownFileType: "wrapper.framework",
                    path: "\(depName).framework"
                )
                pbxproj.add(object: frameworkRef)
                let buildFile = PBXBuildFile(file: frameworkRef)
                pbxproj.add(object: buildFile)
                frameworksPhase.files?.append(buildFile)
            }

            // Update build configurations with dependency paths
            if !depHeaderPaths.isEmpty || !deps.isEmpty || !staticLibSearchPaths.isEmpty {
                for config in target.buildConfigurationList?.buildConfigurations ?? [] {
                    // Add header search paths
                    if !depHeaderPaths.isEmpty {
                        let existing = config.buildSettings["HEADER_SEARCH_PATHS"] as? String ?? "$(inherited)"
                        config.buildSettings["HEADER_SEARCH_PATHS"] = existing + " " + depHeaderPaths.joined(separator: " ")
                    }
                    // Ensure framework and module search paths include built products
                    config.buildSettings["FRAMEWORK_SEARCH_PATHS"] = "$(inherited) $(BUILT_PRODUCTS_DIR)"
                    config.buildSettings["SWIFT_INCLUDE_PATHS"] = "$(inherited) $(BUILT_PRODUCTS_DIR)"
                    // Add library search paths for static libraries
                    if !staticLibSearchPaths.isEmpty {
                        let existing = config.buildSettings["LIBRARY_SEARCH_PATHS"] as? String ?? "$(inherited)"
                        config.buildSettings["LIBRARY_SEARCH_PATHS"] = existing + " " + staticLibSearchPaths.sorted().joined(separator: " ")
                    }
                }
            }

            // Collect SDK frameworks from this module and all transitive dependencies
            var allSdkFrameworks: Set<String> = []
            if let sdkFrameworks = module.sdkFrameworks {
                allSdkFrameworks.formUnion(sdkFrameworks)
            }
            for depName in allDeps {
                if let depModule = modules[depName], let depFrameworks = depModule.sdkFrameworks {
                    allSdkFrameworks.formUnion(depFrameworks)
                }
            }

            // Add SDK frameworks
            for framework in allSdkFrameworks {
                let fileRef = PBXFileReference(
                    sourceTree: .sdkRoot,
                    name: "\(framework).framework",
                    lastKnownFileType: "wrapper.framework",
                    path: "System/Library/Frameworks/\(framework).framework"
                )
                pbxproj.add(object: fileRef)
                let buildFile = PBXBuildFile(file: fileRef)
                pbxproj.add(object: buildFile)
                frameworksPhase.files?.append(buildFile)
            }

            // Collect SDK dylibs from this module and all transitive dependencies
            var allSdkDylibs: Set<String> = []
            if let sdkDylibs = module.sdkDylibs {
                allSdkDylibs.formUnion(sdkDylibs)
            }
            for depName in allDeps {
                if let depModule = modules[depName], let depDylibs = depModule.sdkDylibs {
                    allSdkDylibs.formUnion(depDylibs)
                }
            }

            // Add SDK dylibs (system libraries like libz, libiconv, etc.)
            for dylib in allSdkDylibs {
                // Clean up the library name - remove 'lib' prefix if present
                let libName = dylib.hasPrefix("lib") ? String(dylib.dropFirst(3)) : dylib
                let fileRef = PBXFileReference(
                    sourceTree: .sdkRoot,
                    name: "lib\(libName).tbd",
                    lastKnownFileType: "sourcecode.text-based-dylib-definition",
                    path: "usr/lib/lib\(libName).tbd"
                )
                pbxproj.add(object: fileRef)
                let buildFile = PBXBuildFile(file: fileRef)
                pbxproj.add(object: buildFile)
                frameworksPhase.files?.append(buildFile)
            }
        }
    }

    /// Returns the header search paths that this module exports to its dependents
    private func exportedHeaderPaths(for module: ModuleDefinition) -> [String] {
        var paths: [String] = []
        if let includes = module.includes, !includes.isEmpty {
            for inc in includes {
                if inc == "." {
                    paths.append("$(SRCROOT)/\(module.path)")
                } else {
                    paths.append("$(SRCROOT)/\(module.path)/\(inc)")
                }
            }
        } else {
            // No includes specified, export module's own path
            paths.append("$(SRCROOT)/\(module.path)")
        }
        return paths
    }

    func getTarget(named name: String) -> PBXNativeTarget? {
        return targetsByName[name]
    }


    private func createConfigurationList(for module: ModuleDefinition, isXCFramework: Bool, modulemapPath: Path? = nil) -> XCConfigurationList {
        let debugSettings = createBuildSettings(for: module, isDebug: true, isXCFramework: isXCFramework, modulemapPath: modulemapPath)
        let releaseSettings = createBuildSettings(for: module, isDebug: false, isXCFramework: isXCFramework, modulemapPath: modulemapPath)

        let debugConfig = XCBuildConfiguration(name: "Debug", buildSettings: debugSettings)
        let releaseConfig = XCBuildConfiguration(name: "Release", buildSettings: releaseSettings)

        pbxproj.add(object: debugConfig)
        pbxproj.add(object: releaseConfig)

        let configList = XCConfigurationList(
            buildConfigurations: [debugConfig, releaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: configList)

        return configList
    }

    private func createBuildSettings(for module: ModuleDefinition, isDebug: Bool, isXCFramework: Bool, modulemapPath: Path? = nil) -> BuildSettings {
        var settings: BuildSettings = [
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "PRODUCT_BUNDLE_IDENTIFIER": "org.telegram.\(module.name)",
            "INFOPLIST_FILE": "",
            "SKIP_INSTALL": "YES",
            "GENERATE_INFOPLIST_FILE": "YES",
        ]

        let moduleType = ModuleType(from: module)

        // Swift settings
        if moduleType == .swiftLibrary {
            settings["SWIFT_VERSION"] = "5.0"
            settings["DEFINES_MODULE"] = "YES"

            if let copts = module.copts, !copts.isEmpty {
                let filtered = copts.filter { !$0.hasPrefix("-warnings") }
                if !filtered.isEmpty {
                    settings["OTHER_SWIFT_FLAGS"] = "$(inherited) " + filtered.joined(separator: " ")
                }
            }

            if let defines = module.defines, !defines.isEmpty {
                settings["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) " + defines.joined(separator: " ")
            }
        }

        // C/ObjC settings
        if moduleType == .objcLibrary || moduleType == .ccLibrary {
            // Always suppress deprecated warnings (e.g., OSSpinLock) and don't treat warnings as errors
            var cflags = ["-Wno-deprecated-declarations"]
            if let copts = module.copts, !copts.isEmpty {
                let filtered = copts.filter { !$0.hasPrefix("-warnings") && !$0.hasPrefix("-W") }
                cflags.append(contentsOf: filtered)
            }
            settings["OTHER_CFLAGS"] = "$(inherited) " + cflags.joined(separator: " ")
            settings["GCC_TREAT_WARNINGS_AS_ERRORS"] = "NO"

            if let cxxopts = module.cxxopts, !cxxopts.isEmpty {
                let filtered = cxxopts.filter { !$0.hasPrefix("-std=") }
                if !filtered.isEmpty {
                    settings["OTHER_CPLUSPLUSFLAGS"] = "$(inherited) " + filtered.joined(separator: " ")
                }
            }

            if let defines = module.defines, !defines.isEmpty {
                settings["GCC_PREPROCESSOR_DEFINITIONS"] = "$(inherited) " + defines.joined(separator: " ")
            }

            // Always include module's own path for header search
            var headerPaths = ["$(SRCROOT)/\(module.path)"]
            if let includes = module.includes {
                for inc in includes where inc != "." {
                    headerPaths.append("$(SRCROOT)/\(module.path)/\(inc)")
                }
            }
            settings["HEADER_SEARCH_PATHS"] = "$(inherited) " + headerPaths.joined(separator: " ")

            // Use custom modulemap if provided (SPM-style)
            if let modmap = modulemapPath {
                // Get relative path from SRCROOT
                let relativePath = modmap.string.replacingOccurrences(of: outputDir.string + "/", with: "")
                settings["MODULEMAP_FILE"] = "$(SRCROOT)/\(relativePath)"
            }
            settings["DEFINES_MODULE"] = "YES"
        }

        return settings
    }

    private func getOrCreateGroup(for path: String) throws -> PBXGroup {
        if let existing = groupsByPath[path] {
            return existing
        }

        let components = path.split(separator: "/").map(String.init)
        var currentGroup = mainGroup
        var currentPath = ""

        for component in components {
            currentPath = currentPath.isEmpty ? component : currentPath + "/" + component

            if let existing = groupsByPath[currentPath] {
                currentGroup = existing
            } else {
                let newGroup = PBXGroup(children: [], sourceTree: .group, name: component, path: component)
                pbxproj.add(object: newGroup)
                currentGroup.children.append(newGroup)
                groupsByPath[currentPath] = newGroup
                currentGroup = newGroup
            }
        }

        return currentGroup
    }

    private func getOrCreateFileReference(path: String, in group: PBXGroup, modulePath: String, fileName: String) throws -> PBXFileReference {
        let pathComponents = path.split(separator: "/").map(String.init)

        var currentGroup = group
        var currentPath = modulePath

        // Navigate/create intermediate groups
        for component in pathComponents.dropLast() {
            currentPath = currentPath + "/" + component
            if let existing = groupsByPath[currentPath] {
                currentGroup = existing
            } else {
                let newGroup = PBXGroup(children: [], sourceTree: .group, name: component, path: component)
                pbxproj.add(object: newGroup)
                currentGroup.children.append(newGroup)
                groupsByPath[currentPath] = newGroup
                currentGroup = newGroup
            }
        }

        // Create file reference
        let fileType = lastKnownFileType(for: fileName)
        let fileRef = PBXFileReference(
            sourceTree: .group,
            name: fileName,
            lastKnownFileType: fileType,
            path: fileName
        )
        pbxproj.add(object: fileRef)
        currentGroup.children.append(fileRef)

        return fileRef
    }

    private func lastKnownFileType(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "sourcecode.swift"
        case "m": return "sourcecode.c.objc"
        case "mm": return "sourcecode.cpp.objcpp"
        case "c": return "sourcecode.c.c"
        case "cc", "cpp", "cxx": return "sourcecode.cpp.cpp"
        case "h": return "sourcecode.c.h"
        case "hpp": return "sourcecode.cpp.h"
        case "metal": return "sourcecode.metal"
        case "json": return "text.json"
        case "plist": return "text.plist.xml"
        default: return "text"
        }
    }

    /// Extract the relative path within a module from a source path
    /// Handles both regular paths (submodules/Foo/...) and bazel-out paths (bazel-out/.../bin/submodules/Foo/...)
    private func relativePathInModule(source: String, modulePath: String) -> String {
        if source.hasPrefix(modulePath + "/") {
            return String(source.dropFirst(modulePath.count + 1))
        } else if source.hasPrefix("bazel-out/") {
            // Generated file - extract path after the module path portion
            if let range = source.range(of: modulePath + "/") {
                return String(source[range.upperBound...])
            } else {
                return Path(source).lastComponent
            }
        } else {
            return Path(source).lastComponent
        }
    }

    /// Check if a source file is in one of the includes directories
    private func isInIncludesDirectory(source: String, modulePath: String, includes: [String]?) -> Bool {
        guard let includes = includes, !includes.isEmpty else {
            return false
        }
        let relative = relativePathInModule(source: source, modulePath: modulePath)
        return includes.contains { inc in
            if inc == "." {
                return true  // All files in module are public
            } else {
                return relative.hasPrefix(inc + "/") || relative == inc
            }
        }
    }

    /// Generates an explicit module.modulemap for ObjC/C++ modules (SPM-style)
    /// Returns the path to the modulemap, or nil if no public headers
    func generateModulemap(for module: ModuleDefinition) throws -> Path? {
        let moduleType = ModuleType(from: module)
        guard moduleType == .objcLibrary || moduleType == .ccLibrary else {
            return nil
        }

        // Determine public header prefix from includes
        let publicHeaderPrefix: String
        if let includes = module.includes, !includes.isEmpty {
            let firstInclude = includes[0]
            publicHeaderPrefix = firstInclude == "." ? "" : firstInclude
        } else {
            publicHeaderPrefix = ""
        }

        // Determine public headers
        let explicitPublicHeaders = Set(module.hdrs ?? [])

        let allFiles = module.sources + (module.hdrs ?? []) + (module.textualHdrs ?? [])
        let allHeaders = allFiles.filter { $0.hasSuffix(".h") || $0.hasSuffix(".hpp") }

        // Determine which headers are public
        let publicHeaders: [String]
        if !explicitPublicHeaders.isEmpty {
            publicHeaders = allHeaders.filter { explicitPublicHeaders.contains($0) }
        } else if module.includes != nil && !module.includes!.isEmpty {
            // Use helper that properly handles bazel-out paths
            publicHeaders = allHeaders.filter { header in
                isInIncludesDirectory(source: header, modulePath: module.path, includes: module.includes)
            }
        } else {
            publicHeaders = []
        }

        guard !publicHeaders.isEmpty else {
            return nil
        }

        // Generate explicit modulemap content (SPM-style)
        var content = "// module.modulemap for \(module.name)\n"
        content += "// Auto-generated - do not edit\n\n"
        content += "module \(module.name) {\n"

        for header in publicHeaders {
            // Calculate the symlinked path - matches the symlink creation in buildFrameworkTarget
            // The symlink is at: outputDir + module.path + relativeToModule
            let relativeToModule = relativePathInModule(source: header, modulePath: module.path)
            let symlinkPath = outputDir + module.path + relativeToModule
            content += "    header \"\(symlinkPath.string)\"\n"
        }

        content += "    export *\n"
        content += "}\n"

        // Write modulemap to the public headers directory
        let modulemapDir: Path
        if !publicHeaderPrefix.isEmpty {
            modulemapDir = outputDir + module.path + publicHeaderPrefix
        } else {
            modulemapDir = outputDir + module.path
        }
        let modulemapPath = modulemapDir + "module.modulemap"

        try modulemapDir.mkpath()
        try modulemapPath.write(content)

        // Track this file so it doesn't get cleaned up
        symlinkManager.markFile(modulemapPath)

        return modulemapPath
    }
}
