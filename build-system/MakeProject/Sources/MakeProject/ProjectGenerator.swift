import Foundation
import PathKit
import XcodeProj

class ProjectGenerator {
    let modulesPath: Path
    let outputDir: Path
    let projectRoot: Path

    init(modulesPath: Path, outputDir: Path, projectRoot: Path) {
        self.modulesPath = modulesPath
        self.outputDir = outputDir
        self.projectRoot = projectRoot
    }

    func generate() throws {
        print("Loading modules from \(modulesPath)...")
        let modules = try loadModules(from: modulesPath.string)
        print("Loaded \(modules.count) modules")

        // Filter out empty modules, but keep:
        // - Modules with source files (excluding .a)
        // - Static library modules (only .a files)
        // - XCFramework imports
        let validModules = modules.filter { name, module in
            let nonStaticSources = module.sources.filter { !$0.hasSuffix(".a") }
            let staticLibs = module.sources.filter { $0.hasSuffix(".a") }
            return !nonStaticSources.isEmpty ||
                   !staticLibs.isEmpty ||
                   module.type == "apple_static_xcframework_import"
        }
        print("Processing \(validModules.count) non-empty modules")

        // Setup output directory
        try outputDir.mkpath()

        // Create symlink manager
        let symlinkManager = SymlinkManager(outputDir: outputDir, projectRoot: projectRoot)
        symlinkManager.scanExistingFiles()

        // Create project
        let projectPath = outputDir + "Telegram.xcodeproj"
        let pbxproj = PBXProj()

        // Create main group
        let mainGroup = PBXGroup(children: [], sourceTree: .group)
        pbxproj.add(object: mainGroup)

        // Create project-level build configurations
        let projectDebugSettings: BuildSettings = [
            "ALWAYS_SEARCH_USER_PATHS": "NO",
            "CLANG_CXX_LANGUAGE_STANDARD": "c++17",
            "CLANG_ENABLE_MODULES": "YES",
            "CLANG_ENABLE_OBJC_ARC": "YES",
            "CLANG_ENABLE_EXPLICIT_MODULES": "NO",  // Disable explicit module builds for ObjC-Swift interop
            "SWIFT_ENABLE_EXPLICIT_MODULES": "NO",  // Disable explicit module builds for Swift
            "ENABLE_STRICT_OBJC_MSGSEND": "YES",
            "GCC_NO_COMMON_BLOCKS": "YES",
            "IPHONEOS_DEPLOYMENT_TARGET": "13.0",
            "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
            "ONLY_ACTIVE_ARCH": "YES",
            "SDKROOT": "iphoneos",
            "SWIFT_VERSION": "5.0",
            "TARGETED_DEVICE_FAMILY": "1,2",
            "DEBUG_INFORMATION_FORMAT": "dwarf",
            "ENABLE_BITCODE": "NO",
        ]

        var projectReleaseSettings = projectDebugSettings
        projectReleaseSettings["DEBUG_INFORMATION_FORMAT"] = "dwarf-with-dsym"
        projectReleaseSettings["MTL_ENABLE_DEBUG_INFO"] = "NO"
        projectReleaseSettings["ONLY_ACTIVE_ARCH"] = "NO"

        let projectDebugConfig = XCBuildConfiguration(name: "Debug", buildSettings: projectDebugSettings)
        let projectReleaseConfig = XCBuildConfiguration(name: "Release", buildSettings: projectReleaseSettings)
        pbxproj.add(object: projectDebugConfig)
        pbxproj.add(object: projectReleaseConfig)

        let projectConfigList = XCConfigurationList(
            buildConfigurations: [projectDebugConfig, projectReleaseConfig],
            defaultConfigurationName: "Release"
        )
        pbxproj.add(object: projectConfigList)

        // Create project
        let project = PBXProject(
            name: "Telegram",
            buildConfigurationList: projectConfigList,
            compatibilityVersion: "Xcode 14.0",
            preferredProjectObjectVersion: 56,
            minimizedProjectReferenceProxies: 0,
            mainGroup: mainGroup
        )
        pbxproj.add(object: project)

        // Create target builder
        let targetBuilder = TargetBuilder(
            project: project,
            pbxproj: pbxproj,
            mainGroup: mainGroup,
            outputDir: outputDir,
            symlinkManager: symlinkManager
        )

        // Build targets
        print("Creating targets...")
        var builtCount = 0
        for (name, module) in validModules.sorted(by: { $0.key < $1.key }) {
            do {
                if let _ = try targetBuilder.buildTarget(for: module, allModules: validModules) {
                    builtCount += 1
                    if builtCount % 50 == 0 {
                        print("  Created \(builtCount) targets...")
                    }
                }
            } catch {
                print("Warning: Failed to build target \(name): \(error)")
            }
        }
        print("Created \(builtCount) targets")

        // Wire up dependencies
        print("Wiring up dependencies...")
        try targetBuilder.wireUpDependencies(modules: validModules)

        // Write project
        print("Writing project to \(projectPath)...")
        pbxproj.rootObject = project
        let xcodeproj = XcodeProj(workspace: XCWorkspace(), pbxproj: pbxproj)
        try xcodeproj.write(path: projectPath)

        // Generate scheme for main target
        if let telegramTarget = targetBuilder.getTarget(named: "TelegramUI") {
            print("Generating scheme...")
            let schemeGenerator = SchemeGenerator(projectPath: projectPath, pbxproj: pbxproj)
            try schemeGenerator.generateScheme(for: telegramTarget, named: "TelegramUI")
        } else {
            print("Warning: Could not find TelegramUI target for scheme")
        }

        // Clean up stale files
        print("Cleaning up stale symlinks...")
        symlinkManager.cleanupStaleFiles()

        print("Done! Project written to \(projectPath)")
    }
}
