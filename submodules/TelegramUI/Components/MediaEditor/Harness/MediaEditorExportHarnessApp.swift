import Foundation
import UIKit
@testable import MediaEditorExportTestSupport

final class MediaEditorExportHarnessDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let thread = Thread {
            MediaEditorExportHarness.run(arguments: ProcessInfo.processInfo.arguments)
        }
        thread.stackSize = 16 * 1024 * 1024
        thread.start()
        return true
    }
}

@objc(MediaEditorExportHarnessSceneDelegate)
final class MediaEditorExportHarnessSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIViewController()
        window.makeKeyAndVisible()
        self.window = window
    }
}

enum MediaEditorExportHarness {
    static func run(arguments: [String]) {
        let mode = arguments.firstIndex(of: "--mode").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil } ?? "all"
        let outputDirectory = mediaEditorExportOutputDirectory()
        let statusURL = outputDirectory.appendingPathComponent("status.txt")
        try? FileManager.default.removeItem(at: statusURL)
        let logURL = outputDirectory.appendingPathComponent("harness.log")
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let logHandle = try? FileHandle(forWritingTo: logURL)
        let log: (String) -> Void = { line in
            print(line)
            logHandle?.write((line + "\n").data(using: .utf8)!)
        }

        let only = arguments.firstIndex(of: "--only").flatMap { $0 + 1 < arguments.count ? arguments[$0 + 1] : nil }
        let scenarios = mediaEditorExportScenarios(only: only)
        let measuredRuns = arguments.firstIndex(of: "--runs").flatMap { $0 + 1 < arguments.count ? Int(arguments[$0 + 1]) : nil } ?? 5
        var failures: [String] = []
        if mode == "compositor" || mode == "all" {
            failures.append(contentsOf: runCompositor(outputDirectory: outputDirectory, log: log))
        }
        if mode == "entities" || mode == "all" {
            failures.append(contentsOf: runEntities(outputDirectory: outputDirectory, log: log))
        }
        if mode == "composer" || mode == "all" {
            failures.append(contentsOf: report(results: MediaEditorComposerSuite().runAll(), to: outputDirectory.appendingPathComponent("composer.txt"), log: log))
        }
        if mode == "photo" || mode == "all" {
            failures.append(contentsOf: report(results: MediaEditorPhotoCompositionSuite().runAll(), to: outputDirectory.appendingPathComponent("photo.txt"), log: log))
        }
        if mode == "vignette" || mode == "all" {
            failures.append(contentsOf: report(results: MediaEditorVignetteSuite().runAll(), to: outputDirectory.appendingPathComponent("vignette.txt"), log: log))
        }
        if mode == "export" || mode == "benchmark" || mode == "all" {
            if scenarios.isEmpty {
                failures.append("no scenario matches \(only ?? "")")
            } else if let suite = MediaEditorExportSuite(log: log) {
                if mode == "export" || mode == "all" {
                    suite.runExport(scenarios: scenarios)
                }
                if mode == "benchmark" || mode == "all" {
                    suite.runBenchmark(scenarios: scenarios, measuredRuns: measuredRuns)
                }
                failures.append(contentsOf: suite.failures)
            } else {
                failures.append("cannot open a temporary Postbox")
            }
        }
        if mode == "decode-probe", #available(iOS 17.0, *) {
            failures.append(contentsOf: MediaEditorDecodeProbeRunner.run(arguments: arguments, outputDirectory: outputDirectory, log: log))
        }
        let failuresText = failures.map { $0 + "\n" }.joined()
        try? failuresText.write(to: outputDirectory.appendingPathComponent("failures.txt"), atomically: true, encoding: .utf8)
        log("MediaEditorExportHarness finished mode=\(mode) failures=\(failures.count)")
        try? logHandle?.close()
        try? "done \(failures.count)\n".write(to: statusURL, atomically: true, encoding: .utf8)
    }

    static func runCompositor(outputDirectory: URL, log: (String) -> Void) -> [String] {
        guard let suite = MediaEditorFrameCompositorSuite() else {
            log("FAIL compositor: no Metal device or compositor")
            return ["compositor: no Metal device or compositor"]
        }
        return report(results: suite.runAll(), to: outputDirectory.appendingPathComponent("compositor.txt"), log: log)
    }

    static func runEntities(outputDirectory: URL, log: (String) -> Void) -> [String] {
        guard let suite = MediaEditorComposerEntityFrameSuite() else {
            log("FAIL entities: no Metal device, compositor or Postbox")
            return ["entities: no Metal device, compositor or Postbox"]
        }
        return report(results: suite.runAll(), to: outputDirectory.appendingPathComponent("entities.txt"), log: log)
    }

    static func report(results: [MediaEditorFrameCompositorCaseResult], to url: URL, log: (String) -> Void) -> [String] {
        var failures: [String] = []
        var lines: [String] = []
        for result in results {
            let line = result.failures.isEmpty ? "PASS \(result.name)" : "FAIL \(result.name)"
            lines.append(line)
            log(line)
            for measurement in result.measurements {
                lines.append("    \(measurement)")
                log("    \(measurement)")
            }
            for failure in result.failures {
                lines.append("    failure: \(failure)")
                log("    failure: \(failure)")
                failures.append("\(result.name): \(failure)")
            }
        }
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return failures
    }
}

@main
struct MediaEditorExportHarnessMain {
    static func main() {
        let _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(MediaEditorExportHarnessDelegate.self))
    }
}
