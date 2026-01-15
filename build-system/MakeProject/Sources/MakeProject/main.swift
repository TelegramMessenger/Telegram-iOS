import Foundation
import ArgumentParser
import PathKit

struct MakeProject: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "MakeProject",
        abstract: "Generate Xcode project from Bazel module definitions"
    )

    @Option(name: .long, help: "Path to modules JSON file")
    var modulesJson: String = "bazel-bin/Telegram/spm_build_root_modules.json"

    @Option(name: .long, help: "Output directory for generated project")
    var output: String = "xcode-files"

    func run() throws {
        // Determine project root (where we find the modules JSON)
        let currentDir = Path.current
        var projectRoot = currentDir

        // Walk up to find project root (contains bazel-bin or the modules file)
        var searchDir = currentDir
        for _ in 0..<5 {
            if (searchDir + modulesJson).exists {
                projectRoot = searchDir
                break
            }
            searchDir = searchDir.parent()
        }

        let modulesPath = projectRoot + modulesJson
        let outputDir = projectRoot + output

        guard modulesPath.exists else {
            print("Error: Modules JSON not found at \(modulesPath)")
            print("Run 'bazel build //Telegram:spm_build_root' first")
            throw ExitCode.failure
        }

        let generator = ProjectGenerator(
            modulesPath: modulesPath,
            outputDir: outputDir,
            projectRoot: projectRoot
        )

        try generator.generate()
    }
}

MakeProject.main()
