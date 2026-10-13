#if canImport(UIKit)
import XCTest
import RichTextEditorDifferentialHarness

/// Task 9a, Step 5 — **the vendored decoder and the vendored corpus agree, before any Telegram code
/// exists.**
///
/// Nothing in this file is Telegram-specific and nothing in it touches the editor. It exists to
/// prove three things at once, all of which are prerequisites for Tasks 9b-9d:
///
/// 1. The Objective-C harness target **compiles, links and is callable from Swift** on the
///    simulator. That is Task 9a's GO/NO-GO; if `import RichTextEditorDifferentialHarness` does not
///    resolve, Phase 0b has no build system.
/// 2. The corpus **decodes through the vendored `IDLoadTextInputScenarios`** — not through a
///    reimplementation of it. The loader is strict: it rejects a fixture whose top-level keys are
///    not exactly `{schema, runtime, family, scenarios}`, whose `schema` is not 1, whose `runtime`
///    is not iOS **26.5 / 23F73**, whose transactions leave an undo group unbalanced or contain no
///    checkpoint, or whose comparison contract names a formatting field outside the
///    inline-formatting family. A decode failure here is therefore a real signal, not a parse
///    detail — and the runtime pin means this suite is also the tripwire for limitation 2 (the
///    corpus's provenance is a *specific* OS build).
/// 3. The counts are the ones Phase 0b's plan was written against: **68 scenarios / 612
///    transactions**. Task 9d's baseline document and Stage 2's Stage D both re-derive from these
///    numbers, so they are asserted here at their source rather than restated downstream.
///
/// The counts are asserted per family AND in total. Per-family alone would let two files trade
/// scenarios; the total alone would let a family vanish.
final class DifferentialCorpusLoadTests: XCTestCase {

    private struct Family {
        let fileName: String
        let family: IDTextInputScenarioFamily
        let scenarios: Int
        let transactions: Int
        /// The exact `provenance.targetRuntime` every scenario in the family carries. It is NOT
        /// uniform across the corpus and that is a fact worth pinning rather than papering over
        /// with a prefix match: the 54 IME / autocorrection / inline-prediction scenarios say
        /// `iOS 26.5 (23F73)`, while all 14 inline-formatting scenarios say `iOS 26.5 (23F73), K3`
        /// — they were captured later, on the K3 simulator. Task 9d's baseline document records the
        /// pinned `(device, OS)` pair, and this is the only place the corpus itself names a device.
        let targetRuntime: String
    }

    /// Measured 2026-08-23 against `/Users/isaac/Documents/InputDec/TestFixtures/TextInputScenarios/`,
    /// which is also where these four files were vendored from byte-for-byte.
    private static let expected: [Family] = [
        Family(fileName: "ime-ios26.5-v1", family: .IME,
               scenarios: 24, transactions: 256, targetRuntime: "iOS 26.5 (23F73)"),
        Family(fileName: "autocorrection-ios26.5-v1", family: .autocorrection,
               scenarios: 21, transactions: 177, targetRuntime: "iOS 26.5 (23F73)"),
        Family(fileName: "inline-formatting-ios26.5-v1", family: .inlineFormatting,
               scenarios: 14, transactions: 98, targetRuntime: "iOS 26.5 (23F73), K3"),
        Family(fileName: "inline-prediction-ios26.5-v1", family: .inlinePrediction,
               scenarios: 9, transactions: 81, targetRuntime: "iOS 26.5 (23F73)"),
    ]

    func test_everyCorpusFamilyDecodesThroughTheVendoredLoader() throws {
        let directory = try DifferentialCorpus.directory()
        var totalScenarios = 0
        var totalTransactions = 0

        for expected in Self.expected {
            let url = directory.appendingPathComponent(expected.fileName).appendingPathExtension("json")
            var error: NSError?
            guard let scenarios = IDLoadTextInputScenarios(url, &error) else {
                XCTFail("\(expected.fileName).json did not decode: \(error?.localizedDescription ?? "no error reported")")
                continue
            }

            XCTAssertEqual(scenarios.count, expected.scenarios,
                           "\(expected.fileName).json scenario count")
            let transactions = scenarios.reduce(0) { $0 + $1.transactions.count }
            XCTAssertEqual(transactions, expected.transactions,
                           "\(expected.fileName).json transaction count")

            for scenario in scenarios {
                XCTAssertEqual(scenario.family, expected.family,
                               "\(scenario.identifier) decoded into the wrong family")
                XCTAssertEqual(scenario.schemaVersion, 1,
                               "\(scenario.identifier) schema version")
                // Limitation 2, asserted rather than merely documented: the corpus was captured on
                // one OS build, and a scenario that claims a different one is not comparable.
                XCTAssertEqual(scenario.provenance["targetRuntime"] as? String, expected.targetRuntime,
                               "\(scenario.identifier) provenance runtime")
            }

            // A scenario whose identifier repeats would silently halve the corpus's coverage while
            // keeping the counts right; the loader rejects duplicates *within* a file, so this is
            // the cross-file half of that guarantee.
            let identifiers = Set(scenarios.map(\.identifier))
            XCTAssertEqual(identifiers.count, scenarios.count,
                           "\(expected.fileName).json has duplicate scenario identifiers")

            totalScenarios += scenarios.count
            totalTransactions += transactions
        }

        XCTAssertEqual(totalScenarios, 68, "corpus scenario total")
        XCTAssertEqual(totalTransactions, 612, "corpus transaction total")
    }

    /// The loader's strictness is load-bearing for the two assertions above — if it accepted
    /// anything, "it decoded" would prove nothing. Pin one rejection so a future vendoring that
    /// silently relaxes the decoder is caught here rather than in a green differential run.
    func test_theVendoredLoaderRejectsAFixtureItDoesNotUnderstand() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("id-corpus-not-a-fixture-\(UUID().uuidString).json")
        try Data(#"{"schema": 2, "runtime": {"osVersion": "26.5", "osBuild": "23F73"}, "family": "ime", "scenarios": []}"#.utf8)
            .write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        var error: NSError?
        XCTAssertNil(IDLoadTextInputScenarios(url, &error),
                     "the vendored loader accepted an unsupported schema version")
        XCTAssertEqual(error?.domain, IDTextInputScenarioErrorDomain)
    }

}
#endif
