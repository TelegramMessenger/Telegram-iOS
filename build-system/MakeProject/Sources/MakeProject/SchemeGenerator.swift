import Foundation
import PathKit
import XcodeProj

class SchemeGenerator {
    let projectPath: Path
    let pbxproj: PBXProj

    init(projectPath: Path, pbxproj: PBXProj) {
        self.projectPath = projectPath
        self.pbxproj = pbxproj
    }

    func generateScheme(for target: PBXNativeTarget, named schemeName: String) throws {
        let schemesDir = projectPath + "xcshareddata" + "xcschemes"
        try schemesDir.mkpath()

        let buildableReference = XCScheme.BuildableReference(
            referencedContainer: "container:Telegram.xcodeproj",
            blueprint: target,
            buildableName: "\(target.name).framework",
            blueprintName: target.name
        )

        let buildAction = XCScheme.BuildAction(
            buildActionEntries: [
                XCScheme.BuildAction.Entry(
                    buildableReference: buildableReference,
                    buildFor: [.running, .testing, .profiling, .archiving, .analyzing]
                )
            ],
            parallelizeBuild: true,
            buildImplicitDependencies: true
        )

        let launchAction = XCScheme.LaunchAction(
            runnable: nil,
            buildConfiguration: "Debug"
        )

        let testAction = XCScheme.TestAction(
            buildConfiguration: "Debug",
            macroExpansion: buildableReference
        )

        let profileAction = XCScheme.ProfileAction(
            runnable: nil,
            buildConfiguration: "Release",
            macroExpansion: buildableReference
        )

        let analyzeAction = XCScheme.AnalyzeAction(buildConfiguration: "Debug")

        let archiveAction = XCScheme.ArchiveAction(
            buildConfiguration: "Release",
            revealArchiveInOrganizer: true
        )

        let scheme = XCScheme(
            name: schemeName,
            lastUpgradeVersion: nil,
            version: nil,
            buildAction: buildAction,
            testAction: testAction,
            launchAction: launchAction,
            profileAction: profileAction,
            analyzeAction: analyzeAction,
            archiveAction: archiveAction
        )

        let schemePath = schemesDir + "\(schemeName).xcscheme"
        try scheme.write(path: schemePath, override: true)
    }
}
