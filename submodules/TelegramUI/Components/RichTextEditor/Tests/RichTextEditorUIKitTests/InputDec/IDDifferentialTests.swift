#if canImport(UIKit)
import UIKit
import XCTest
import RichTextEditorDifferentialHarness
import RichTextEditorCore
@testable import RichTextEditorUIKit

/// Task D4b — **the culminating measurement: the differential corpus, driven against `.inputDec`.**
///
/// Mirrors `LegacyDifferentialTests` (stage 1, Task 9d) exactly in shape — four family tests, one
/// corpus file each, the vendored `IDTextInputDifferentialRunner` building three hosts (stock
/// `UITextView` plus TWO independently constructed Telegram editors) and comparing snapshots with
/// the vendored comparator, filtered to the comparable field set and called once per field so one
/// diverging field cannot mask another (see `LegacyDifferentialTests`'s own doc comment for the full
/// rationale — unchanged here). The one thing that changes is WHICH factory is installed:
/// `TelegramInputDecDifferentialInputFactory` builds both non-stock hosts through
/// `RichTextInputCanvasFactory.make(.inputDecRequired)` instead of the legacy backend.
///
/// ## Deliberate difference from `LegacyDifferentialTests`: no hard runtime-build gate
///
/// Legacy's `assertPinnedRuntimeBuild()` ABORTS the whole run when the simulator is not on the
/// corpus's capture build (23F73) — correct for a suite whose whole job is reproducing ONE pinned
/// baseline number-for-number. This task's own brief requires the OPPOSITE for its second leg: Task
/// D4b Step 5 (and the controller supplement's point 1, "the multi-OS run is mandatory") runs this
/// same corpus on a DELIBERATELY uncertified OS band, specifically to see whether a semantic ABI
/// drift shows up where the manifest's OS-encoding check cannot. Reusing Legacy's hard gate here
/// would make that leg abort at `assertPinnedRuntimeBuild()` before comparing a single field —
/// exactly the vacuous result Legacy's own gate exists to PREVENT, produced by copying a check built
/// for a different purpose. So this suite prints the measured build in every family's report block
/// (via `LegacyDifferentialTests.runningRuntimeBuild()`, reused rather than re-derived) but never
/// fails on it — a reader of the report always knows which OS produced which counts, and the
/// certified-band leg and the uncertified-band leg are two SEPARATE invocations of this same suite
/// on two different simulators (see the task report for exactly which devices and why).
///
/// ## Expected: failures, and that is the deliverable
///
/// This is the first time this corpus has ever driven the ID backend. `IDDifferentialExpectations`
/// starts from names for the divergences already characterized in `DIVERGENCES.md` (a known kernel
/// limit, a new axis-conversion-class instance, an unimplemented witness); anything this table does
/// NOT name stays UNEXPLAINED and fails its family's test — that is by design, not a bug in this
/// suite. See the task report for the full, evidence-quoted classification.
@MainActor
final class IDDifferentialTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TelegramInputDecDifferentialInputFactory.install()
    }

    override func tearDown() {
        TelegramInputDecDifferentialInputFactory.uninstall()
        super.tearDown()
    }

    // MARK: - The four families

    func test_imeFamilyMatchesStock() throws {
        try runFamily(inFile: "ime-ios26.5-v1")
    }

    func test_autocorrectionFamilyMatchesStock() throws {
        try runFamily(inFile: "autocorrection-ios26.5-v1")
    }

    func test_inlineFormattingFamilyMatchesStock() throws {
        try runFamily(inFile: "inline-formatting-ios26.5-v1")
    }

    func test_inlinePredictionFamilyMatchesStock() throws {
        try runFamily(inFile: "inline-prediction-ios26.5-v1")
    }

    // MARK: - The run

    private func runFamily(inFile fileName: String) throws {
        let scenarios = try DifferentialCorpus.scenarios(inFile: fileName)
        XCTAssertFalse(scenarios.isEmpty, "\(fileName) decoded to zero scenarios")

        var observed: [ObservedDifference] = []
        var executionFailures: [String] = []
        var comparedTriples = 0
        var checkpointCount = 0
        var transactionCount = 0

        for scenario in scenarios {
            transactionCount += scenario.transactions.count
            let runner = IDTextInputDifferentialRunner()
            let result: IDTextInputDifferentialResult
            do {
                result = try runner.run(scenario, order: .stockReferenceMinimal)
            } catch {
                executionFailures.append(
                    "\(scenario.identifier): \((error as NSError).localizedDescription)")
                continue
            }
            checkpointCount += result.stockSnapshots.count

            let fields = IDTelegramComparableFields(scenario.comparisonFields)
            for field in fields {
                comparedTriples += 3
                let differences = IDCompareTextInputSnapshotTriplet(
                    result.stockSnapshots,
                    result.referenceSnapshots,
                    result.minimalSnapshots,
                    [field],
                    scenario.geometryTolerance)
                for difference in differences {
                    observed.append(ObservedDifference(
                        scenarioIdentifier: scenario.identifier,
                        family: scenario.family,
                        fieldPath: difference.fieldPath,
                        transactionIndex: Int(difference.transactionIndex),
                        phase: difference.phase,
                        leftHostKind: difference.leftHostKind,
                        rightHostKind: difference.rightHostKind,
                        leftValue: difference.leftValue,
                        rightValue: difference.rightValue))
                }
            }
        }

        report(fileName: fileName,
               scenarios: scenarios,
               transactionCount: transactionCount,
               checkpointCount: checkpointCount,
               comparedTriples: comparedTriples,
               observed: observed,
               executionFailures: executionFailures)
    }

    // MARK: - Reporting

    private func report(fileName: String,
                        scenarios: [IDTextInputScenario],
                        transactionCount: Int,
                        checkpointCount: Int,
                        comparedTriples: Int,
                        observed: [ObservedDifference],
                        executionFailures: [String]) {
        let family = scenarios.first.map { TelegramDifferentialExpectations.name(of: $0.family) } ?? "?"
        let build = LegacyDifferentialTests.runningRuntimeBuild()

        var explained: [(ObservedDifference, TelegramDifferentialExpectation)] = []
        var unexplained: [ObservedDifference] = []
        for difference in observed {
            if let entry = IDDifferentialExpectations.expectation(for: difference) {
                explained.append((difference, entry))
            } else {
                unexplained.append(difference)
            }
        }

        var lines: [String] = []
        lines.append("=== DIFFERENTIAL-INPUTDEC \(family) (\(fileName))"
                     + " [build \(build.isEmpty ? "<unreadable>" : build)]")
        lines.append("    scenarios \(scenarios.count) | transactions \(transactionCount)"
                     + " | checkpoints(stock arm) \(checkpointCount)"
                     + " | field comparisons \(comparedTriples)")
        lines.append("    execution failures \(executionFailures.count)"
                     + " | differences \(observed.count)"
                     + " (explained \(explained.count), UNEXPLAINED \(unexplained.count))")
        let byName = Dictionary(grouping: explained, by: { $0.1.name })
            .mapValues(\.count).sorted { $0.key < $1.key }
        for (name, count) in byName {
            lines.append("    expected[\(name)] = \(count)")
        }
        let byField = Dictionary(grouping: unexplained, by: { $0.fieldPath })
            .mapValues(\.count).sorted { $0.key < $1.key }
        for (field, count) in byField {
            lines.append("    UNEXPLAINED[\(field)] = \(count)")
        }
        print(lines.joined(separator: "\n"))

        for failure in executionFailures {
            print("    EXECUTION FAILURE: \(failure)")
        }
        for difference in unexplained {
            print("    UNEXPLAINED: \(difference.description)")
        }

        // Same rule as Legacy: a reference-vs-minimal difference is never excusable (the
        // "minimal-is-not-a-second-backend" caveat — here, "not a second ID-backend instance"
        // either). Assert it rather than trusting the table not to grow one.
        for (difference, entry) in explained where !difference.isAgainstStock {
            XCTFail("expectation '\(entry.name)' matched a reference-vs-minimal difference; that pair "
                    + "is a determinism check and a difference there is always a finding:\n"
                    + difference.description)
        }

        XCTAssertTrue(executionFailures.isEmpty,
                      "\(executionFailures.count) scenario(s) of the \(family) family could not be "
                      + "driven to completion:\n" + executionFailures.joined(separator: "\n"))
        XCTAssertTrue(unexplained.isEmpty,
                      "\(unexplained.count) difference(s) in the \(family) family are not accounted "
                      + "for by a named expectation:\n"
                      + unexplained.map(\.description).joined(separator: "\n"))
    }
}
#endif
