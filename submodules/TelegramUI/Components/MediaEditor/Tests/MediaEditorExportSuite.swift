import Foundation
import UIKit
import Postbox
import TelegramCore
@testable import MediaEditor

let mediaEditorExportOutputDirectorySource = "MediaEditorExportHarness: TEST_UNDECLARED_OUTPUTS_DIR is absent, so NSTemporaryDirectory()/MediaEditorExportTests in the app data container (xcrun simctl get_app_container <udid> org.telegram.MediaEditorExportHarness data), copied to the host by Harness/run-export-harness.sh"

func mediaEditorExportOutputDirectory() -> URL {
    let url: URL
    if let path = ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"], !path.isEmpty {
        url = URL(fileURLWithPath: path)
    } else {
        url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MediaEditorExportTests")
    }
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private let mediaEditorExportLoggerInstalled: Void = {
    let path = NSTemporaryDirectory() + "MediaEditorExportLogs"
    try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    let logger = Logger(rootPath: path, basePath: path)
    logger.logToFile = false
    logger.logToConsole = false
    Logger.setSharedLogger(logger)
}()

private func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else {
        return 0.0
    }
    let sorted = values.sorted()
    if sorted.count % 2 == 1 {
        return sorted[sorted.count / 2]
    } else {
        return (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2.0
    }
}

private func format(_ value: Double, _ digits: Int) -> String {
    return String(format: "%.\(digits)f", value)
}

final class MediaEditorExportSuite {
    let outputDirectory: URL
    let postbox: Postbox
    private(set) var failures: [String] = []
    private let log: (String) -> Void

    init?(log: @escaping (String) -> Void = { print($0) }) {
        let _ = mediaEditorExportLoggerInstalled
        guard let postbox = MediaEditorExportRunner.makePostbox() else {
            return nil
        }
        self.postbox = postbox
        self.outputDirectory = mediaEditorExportOutputDirectory()
        self.log = log
        log("MediaEditorExport output directory: \(self.outputDirectory.path) (TEST_UNDECLARED_OUTPUTS_DIR \(ProcessInfo.processInfo.environment["TEST_UNDECLARED_OUTPUTS_DIR"] == nil ? "absent" : "present"))")
    }

    private func fail(_ message: String) {
        self.failures.append(message)
        self.log("FAILURE: \(message)")
    }

    private func compositionTimingError(_ scenario: MediaEditorExportScenario, _ run: MediaEditorExportRun) -> String? {
        guard scenario.kind == .video else {
            return nil
        }
        if run.compositionSeconds.isEmpty || run.compositionSeconds.count != run.frameCount {
            return "\(scenario.id): \(run.compositionSeconds.count) composition timings for \(run.frameCount) frames"
        }
        return nil
    }

    @discardableResult
    func runBenchmark(scenarios: [MediaEditorExportScenario] = mediaEditorExportScenarios, measuredRuns: Int = 5) -> String {
        var rows: [[String]] = []
        for scenario in scenarios {
            self.log("benchmark start \(scenario.id)")
            let warmUp = MediaEditorExportRunner.run(scenario, postbox: self.postbox, capturesFrames: false)
            if let error = warmUp.error {
                self.fail("\(scenario.id): \(error)")
                rows.append([scenario.id, "failed", "", "", ""])
                continue
            }
            var totals: [Double] = []
            var compositionMeans: [Double] = []
            var frames = 0
            var failure: String?
            for _ in 0 ..< measuredRuns {
                let run = MediaEditorExportRunner.run(scenario, postbox: self.postbox, capturesFrames: false)
                if let error = run.error ?? self.compositionTimingError(scenario, run) {
                    failure = error
                    break
                }
                totals.append(run.totalSeconds)
                if !run.compositionSeconds.isEmpty {
                    compositionMeans.append(run.compositionSeconds.reduce(0.0, +) / Double(run.compositionSeconds.count))
                }
                frames = run.compositionSeconds.count
            }
            if let failure {
                self.fail("\(scenario.id): \(failure)")
                rows.append([scenario.id, "failed", "", "", ""])
                continue
            }
            let row = [
                scenario.id,
                format(median(totals), 3),
                "\(format(totals.min() ?? 0.0, 3))–\(format(totals.max() ?? 0.0, 3))",
                format(median(compositionMeans) * 1000.0, 2),
                "\(frames)"
            ]
            self.log("benchmark \(row.joined(separator: " | "))")
            rows.append(row)
        }

        var table = "| id | median total s | min–max | median composition ms/frame | frames |\n|---|---|---|---|---|\n"
        var csv = "id,median_total_s,min_total_s,max_total_s,median_composition_ms_per_frame,frames\n"
        for row in rows {
            table += "| " + row.joined(separator: " | ") + " |\n"
            let range = row[2].components(separatedBy: "–")
            csv += [row[0], row[1], range.first ?? "", range.count > 1 ? range[1] : "", row[3], row[4]].joined(separator: ",") + "\n"
        }
        self.log("MediaEditorExport benchmark\n" + table)
        do {
            try csv.write(to: self.outputDirectory.appendingPathComponent("benchmark.csv"), atomically: true, encoding: .utf8)
            try table.write(to: self.outputDirectory.appendingPathComponent("benchmark.md"), atomically: true, encoding: .utf8)
        } catch {
            self.fail("cannot write benchmark results: \(error)")
        }
        if rows.count != scenarios.count {
            self.fail("benchmark produced \(rows.count) rows for \(scenarios.count) scenarios")
        }
        return table
    }

    func runExport(scenarios: [MediaEditorExportScenario] = mediaEditorExportScenarios) {
        for scenario in scenarios {
            self.log("export start \(scenario.id)")
            let run = MediaEditorExportRunner.run(scenario, postbox: self.postbox, capturesFrames: true)
            self.log("export run \(scenario.id) \(format(run.totalSeconds, 3)) s, \(run.frameCount) frames")
            if let error = run.error {
                self.fail("\(scenario.id): \(error)")
                continue
            }
            if run.frames.isEmpty {
                self.fail("\(scenario.id): no frames captured")
            }
            if let error = self.compositionTimingError(scenario, run) {
                self.fail(error)
            }
            for (index, frame) in run.frames.sorted(by: { $0.key < $1.key }) {
                let name = "\(scenario.id)-\(index).png"
                if !writePNG(frame, to: self.outputDirectory.appendingPathComponent(name)) {
                    self.fail("cannot write \(name)")
                }
            }
            if scenario.kind == .video && scenario.checksDecodedOutput {
                self.checkDecodedOutput(scenario: scenario, run: run)
            }
        }
    }

    private func checkDecodedOutput(scenario: MediaEditorExportScenario, run: MediaEditorExportRun) {
        guard let outputPath = run.outputPath, let decoded = MediaEditorExportRunner.decodeVideo(path: outputPath, frameIndices: Set(run.frames.keys)) else {
            self.fail("\(scenario.id): cannot decode the exported file")
            return
        }
        if let outputDimensions = run.outputDimensions, decoded.dimensions != outputDimensions {
            self.fail("\(scenario.id): decoded dimensions \(decoded.dimensions), expected \(outputDimensions)")
        }
        if let expectedDuration = run.expectedDuration, let tolerance = scenario.durationTolerance ?? run.frameDuration, abs(decoded.duration - expectedDuration) > tolerance + 0.0001 {
            self.fail("\(scenario.id): decoded duration \(decoded.duration) s, expected \(expectedDuration) s")
        }
        if abs(decoded.frameCount - run.frameCount) > 1 {
            self.fail("\(scenario.id): decoded \(decoded.frameCount) frames, composed \(run.frameCount)")
        }
        for index in run.frames.keys.sorted() {
            let frame = decoded.frames[index] ?? (index >= decoded.frameCount - 1 ? decoded.lastFrame : nil)
            let name = "\(scenario.id)-decoded-\(index).png"
            guard let frame else {
                self.fail("\(name): no decoded frame")
                continue
            }
            if !writePNG(frame, to: self.outputDirectory.appendingPathComponent(name)) {
                self.fail("cannot write \(name)")
            }
        }
    }
}
