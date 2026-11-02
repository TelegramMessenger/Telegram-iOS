import Foundation

/// The run file of widget-sandbox v0.3.0's `conformance/run.schema.json`, which `tools/report.mjs` judges: one per
/// renderer, every run of the automatic set.
public enum ConformanceRunFile {
    public static let platform = "ios"
    public static let renderer = "telegram-native"
    /// The vendored conformance set (`third-party/widget-sandbox`, VENDOR.md).
    public static let framework = "v0.5.0"
    public static let commit = "3a7acf1"

    /// `crops`: run key (`ConformanceRun.key`) → stage name → the crop's path, relative to the run file.
    public static func encode(runs: [ConformanceRun], crops: [String: [String: String]], engine: String, date: Date) throws -> Data {
        let formatter = ISO8601DateFormatter()
        let file: [String: Any] = [
            "platform": ConformanceRunFile.platform,
            "renderer": ConformanceRunFile.renderer,
            "engine": engine,
            "framework": ConformanceRunFile.framework,
            "commit": ConformanceRunFile.commit,
            "policy": "strict",
            "features": ["webAnimations"],
            "date": formatter.string(from: date),
            "runs": runs.map { run -> [String: Any] in
                let stages: [[String: String]] = (crops[run.key] ?? [:]).keys.sorted().map { name in
                    ["name": name, "crop": crops[run.key]![name]!]
                }
                return [
                    "id": run.id,
                    "theme": run.theme,
                    "width": Double(run.width),
                    "loaded": run.loaded,
                    "dead": run.dead.map { $0 as Any } ?? NSNull(),
                    "status": run.status.map { $0 as Any } ?? NSNull(),
                    "checks": run.checks,
                    "stages": stages,
                    "observed": [
                        "bridge": run.observed.bridge.map { ["method": $0.method, "args": $0.args] as [String: Any] },
                        "height": run.observed.height,
                        "chatFocused": run.observed.chatFocused,
                        "syntheticInput": run.observed.syntheticInput,
                    ] as [String: Any],
                    "skippedActions": run.skippedActions,
                    "errors": run.errors,
                ]
            },
        ]
        return try JSONSerialization.data(withJSONObject: file, options: [.prettyPrinted, .sortedKeys])
    }
}
