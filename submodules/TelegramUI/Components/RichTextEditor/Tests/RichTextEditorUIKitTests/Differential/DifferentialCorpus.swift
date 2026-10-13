#if canImport(UIKit)
import Foundation
import RichTextEditorDifferentialHarness

/// Locating and loading the vendored corpus, shared by every `Differential/` suite.
///
/// Extracted from `DifferentialCorpusLoadTests` in Task 9b so the host tests read the same corpus
/// through the same vendored decoder. Nothing here reimplements the decoder — every path ends in
/// `IDLoadTextInputScenarios`.
///
/// It THROWS rather than skipping when the corpus cannot be found. A skip would be a vacuous pass,
/// which is the one failure mode a corpus oracle must not have.
enum DifferentialCorpus {

    /// The four JSON files are `resources:` of the Objective-C harness target, so at run time they
    /// live in a SwiftPM-generated resource bundle nested inside the test bundle. Its name is a
    /// build-system detail (`RichTextEditor_RichTextEditorDifferentialHarness.bundle` today), so
    /// this searches for the directory by its *content* instead of hard-coding that name.
    static func directory() throws -> URL {
        let fileManager = FileManager.default
        let anchor = "ime-ios26.5-v1.json"

        var roots: [URL] = []
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let resources = bundle.resourceURL { roots.append(resources) }
            roots.append(bundle.bundleURL)
        }
        var candidates = roots
        for root in roots {
            let nested = (try? fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for item in nested where item.pathExtension == "bundle" {
                candidates.append(Bundle(url: item)?.resourceURL ?? item)
            }
        }

        for candidate in candidates {
            let directory = candidate.appendingPathComponent("TextInputScenarios", isDirectory: true)
            if fileManager.fileExists(atPath: directory.appendingPathComponent(anchor).path) {
                return directory
            }
        }
        throw NSError(domain: "RichTextEditorDifferentialTests", code: 1, userInfo: [
            NSLocalizedDescriptionKey:
                "the vendored TextInputScenarios corpus is not in any loaded bundle; searched \(candidates.count) locations",
        ])
    }

    /// Every scenario in one corpus file, decoded through the vendored loader.
    static func scenarios(inFile fileName: String) throws -> [IDTextInputScenario] {
        let url = try directory().appendingPathComponent(fileName).appendingPathExtension("json")
        var error: NSError?
        guard let scenarios = IDLoadTextInputScenarios(url, &error) else {
            throw error ?? NSError(domain: "RichTextEditorDifferentialTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "\(fileName).json did not decode and reported no error",
            ])
        }
        return scenarios
    }

    /// Every scenario in the whole corpus, in file order.
    static func allScenarios() throws -> [IDTextInputScenario] {
        try fileNames.flatMap { try scenarios(inFile: $0) }
    }

    static let fileNames = [
        "ime-ios26.5-v1",
        "autocorrection-ios26.5-v1",
        "inline-formatting-ios26.5-v1",
        "inline-prediction-ios26.5-v1",
    ]

    /// The first scenario of a family, by corpus file. Tests that need "a real scenario of this
    /// shape" take it from the corpus rather than inventing one, so they exercise the same values
    /// the differential run will.
    static func firstScenario(inFile fileName: String) throws -> IDTextInputScenario {
        guard let first = try scenarios(inFile: fileName).first else {
            throw NSError(domain: "RichTextEditorDifferentialTests", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "\(fileName).json decoded to zero scenarios",
            ])
        }
        return first
    }

    // MARK: - Synthesised scenarios

    /// The ten `initialTraits` the decoder requires, all at their `UITextView` defaults.
    static let defaultTraits: [String: Any] = [
        "autocapitalizationType": 0, "autocorrectionType": 0, "spellCheckingType": 0,
        "smartQuotesType": 0, "smartDashesType": 0, "smartInsertDeleteType": 0,
        "inlinePredictionType": 0, "keyboardType": 0, "returnKeyType": 0,
        "secureTextEntry": false,
    ]

    /// Writes a one-scenario fixture and decodes it **through the vendored loader**, so a synthesised
    /// scenario is subject to exactly the same validation as a corpus one. Used for the handful of
    /// shapes the corpus does not contain (e.g. a scenario that asks for `annotationRanges`).
    static func synthesise(identifier: String,
                           family: String,
                           initialText: String,
                           selection: NSRange,
                           traits: [String: Any] = defaultTraits,
                           comparisonFields: [String],
                           transactions: [[String: Any]]) throws -> IDTextInputScenario {
        let fixture: [String: Any] = [
            "schema": 1,
            "runtime": ["osVersion": "26.5", "osBuild": "23F73"],
            "family": family,
            "scenarios": [[
                "identifier": identifier,
                "initial": [
                    "text": initialText,
                    "selection": ["location": selection.location, "length": selection.length],
                    "traits": traits,
                ],
                "transactions": transactions,
                "comparisonFields": comparisonFields,
                "geometryTolerance": 0,
                // The decoder requires exactly these three keys, all nonempty. `targetRuntime`
                // carries the corpus's own pinned spelling so a synthesised scenario cannot claim a
                // provenance the corpus does not have.
                "provenance": [
                    "sourceFixture": "RichTextEditorUIKitTests (synthesised)",
                    "stockEvidence": "none — this scenario is a probe, not a captured stock oracle",
                    "targetRuntime": "iOS 26.5 (23F73)",
                ],
            ]],
        ]
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("id-synth-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: fixture, options: []).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var error: NSError?
        guard let scenarios = IDLoadTextInputScenarios(url, &error), let scenario = scenarios.first else {
            throw error ?? NSError(domain: "RichTextEditorDifferentialTests", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "the synthesised fixture did not decode and reported no error",
            ])
        }
        return scenario
    }

    /// A checkpoint transaction, spelled the way the corpus spells it.
    static func checkpoint(_ phase: String) -> [String: Any] {
        ["kind": "checkpoint", "text": NSNull(), "range": NSNull(),
         "selectedRange": NSNull(), "traits": [String: Any](), "phase": phase]
    }
}
#endif
