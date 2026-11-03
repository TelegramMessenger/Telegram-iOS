#if canImport(UIKit)
import Darwin
import UIKit
import XCTest
import RichTextEditorDifferentialHarness
@testable import RichTextEditorUIKit

/// Task 9d — **the four family tests: the differential corpus, driven against the LEGACY backend.**
///
/// Each test takes one corpus file, runs every scenario in it through the vendored
/// `IDTextInputDifferentialRunner` (which builds three hosts — stock `UITextView`, and two
/// independently constructed Telegram editors — and drives all three through the vendored
/// transaction list), and compares the resulting snapshots with the vendored comparator.
///
/// Four things about how the comparison is invoked are load-bearing and none of them is cosmetic.
///
/// **1. The comparison field list is FILTERED, never `scenario.comparisonFields` verbatim.**
/// `IDCompareTextInputSnapshotPair` decides equality with
/// `leftValue == rightValue || [leftValue isEqual:rightValue]`, and **`nil == nil` is TRUE** — so a
/// field absent from BOTH snapshots is reported as agreement on something nobody measured. A field
/// absent from only one side is not safe either: the comparator returns on the FIRST inequality, so
/// one permanently-differing field at snapshot 0 masks every later snapshot. `IDTelegramComparable-
/// Fields()` subtracts the two fields a Telegram host cannot sample (`storageMutationTrace`,
/// `traits`), each of which carries a stated reason. Passing the unfiltered list makes the run fail
/// immediately and confusingly — pinned by `test_theUnfilteredFieldListFailsAtTheFirstSnapshotOnADeclinedField`.
///
/// **2. The comparator is called ONCE PER FIELD.** It returns on the first inequality, so a single
/// call per scenario would let one diverging field hide every other field of that scenario. One
/// call per field costs nothing (the snapshots are already captured) and turns a first-difference
/// oracle into a per-field one. The vendored comparator is used exactly as vendored; only the
/// `comparisonFields` argument changes.
///
/// **3. The running simulator's BUILD is asserted, not the fixture's metadata.** See
/// `assertPinnedRuntimeBuild()`.
///
/// **4. An execution failure is a FINDING, not an error to swallow.** When the driver cannot apply a
/// transaction — an undo that is unavailable, a range the document cannot represent — the runner
/// returns `nil` and the scenario produces no snapshots at all. That is reported per scenario with
/// the driver's message (which names the host kind), never counted as a pass.
final class LegacyDifferentialTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TelegramDifferentialInputFactory.install()
    }

    override func tearDown() {
        TelegramDifferentialInputFactory.uninstall()
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

    // MARK: - Step 3b: the running runtime build

    /// **The corpus pins `26.5 / 23F73` inside the JSON; nothing else checks the machine.**
    ///
    /// The vendored decoder rejects a fixture whose `runtime` is not `{osVersion: "26.5", osBuild:
    /// "23F73"}` verbatim — but that is the fixture's own self-description, compared against a
    /// string constant compiled into the decoder. Measured on this host 2026-08-23 and re-confirmed
    /// 2026-08-24: **two iOS 26.5 runtimes are installed, `23F73` and the beta `23F5069b`, and they
    /// SHARE the identifier `com.apple.CoreSimulator.SimRuntime.iOS-26-5`.** `simctl list devices`
    /// groups both under one bare `-- iOS 26.5 --` heading and a device's `device.plist` records
    /// only that identifier, so **from outside the process there is no way to tell which of the two
    /// a device will boot** (verified: `iPhone 17 Pro K1`'s plist says only the identifier; the
    /// booted runtime root, `/Library/Developer/CoreSimulator/Volumes/iOS_23F73`, is visible only
    /// from the running process's own file handles).
    ///
    /// A run on the beta would decode the corpus happily and then report **stock UIKit's** changes
    /// as Telegram's. Every number this oracle produced would be wrong in a direction nobody would
    /// question.
    ///
    /// So it is asserted from INSIDE the process, where the truth is available, and it **fails
    /// loudly with both the expected and the actual build rather than skipping**. A skipped
    /// differential run reads as a pass in every summary that matters.
    ///
    /// The expected build is read from the CORPUS (`provenance.targetRuntime`), not from a constant
    /// here: a re-captured corpus then moves this assertion with it instead of silently disagreeing
    /// with it.
    func test_theRunningSimulatorIsTheCorpusCaptureBuild() throws {
        let scenarios = try DifferentialCorpus.allScenarios()
        let expected = try Self.pinnedCaptureBuilds(of: scenarios)
        XCTAssertEqual(expected, ["23F73"],
                       "the corpus names more than one capture build; the assertion below compares "
                       + "against a single one and would be ambiguous")
        let actual = Self.runningRuntimeBuild()
        let crossCheck = Self.runtimeSystemVersionBuild()
        XCTAssertFalse(crossCheck.isEmpty,
                       "SIMULATOR_ROOT is unset, so the runtime's own SystemVersion.plist could not "
                       + "be read; the build below rests on a single source")
        XCTAssertEqual(actual, crossCheck,
                       "ProcessInfo and the runtime's own SystemVersion.plist disagree about the "
                       + "build; one of the two is not describing the running runtime")
        print("=== DIFFERENTIAL RUNTIME\n" + Self.runtimeBuildDiagnostics())
        XCTAssertTrue(expected.contains(actual), """
            DIFFERENTIAL RUN IS ON THE WRONG SIMULATOR RUNTIME.
              expected build : \(expected.sorted().joined(separator: ", ")) (the corpus's capture build)
              actual build   : \(actual.isEmpty ? "<unreadable>" : actual)
            \(Self.runtimeBuildDiagnostics())
            Two iOS 26.5 runtimes share the identifier com.apple.CoreSimulator.SimRuntime.iOS-26-5 on \
            this host (23F73 and the beta 23F5069b), and a device.plist records only the identifier, \
            so the wrong one can be booted without any outward sign. On the wrong build this oracle \
            reports STOCK UIKIT's behaviour changes as Telegram's.
            """)
    }

    /// The **simulator runtime's** build, read from inside the test process.
    ///
    /// **NOT `kern.osversion`, and not `/System/Library/CoreServices/SystemVersion.plist` either.
    /// Both of those return the HOST MAC's build, and that correction is the whole point of this
    /// comment.** The plan's Step 3b suggested `kern.osversion`; on a real device it is right, but a
    /// simulator process runs on the host Mac's kernel and in the host Mac's filesystem namespace
    /// (the runtime is mounted at `$SIMULATOR_ROOT`, and an absolute `/System/...` path is NOT
    /// redirected). MEASURED 2026-08-24 on this host, all four sources side by side:
    ///
    ///     ProcessInfo.operatingSystemVersionString : Version 26.5 (Build 23F73)   <- CORRECT
    ///     sysctl kern.osversion                    : 25G76                        <- host macOS
    ///     /System/…/SystemVersion.plist            : 25G76                        <- host macOS
    ///     SIMULATOR_RUNTIME_VERSION (env)          : 26.5                         <- no build
    ///
    /// `25G76` is a perfectly plausible-looking build string. Adopting either wrong source and then
    /// "fixing" the resulting permanent failure by comparing against `25G76` would produce an
    /// assertion that passes on BOTH iOS 26.5 runtimes and therefore certifies nothing — the exact
    /// vacuity Step 3b exists to prevent, reached by an entirely reasonable-looking route.
    ///
    /// Foundation resolves the runtime's own `SystemVersion.plist` under `$SIMULATOR_ROOT`, which is
    /// why `operatingSystemVersionString` is right; `runtimeSystemVersionBuild()` reads that same
    /// file directly as an independent cross-check.
    static func runningRuntimeBuild() -> String {
        buildFromOperatingSystemVersionString()
    }

    /// The parenthesised `(Build 23F73)` of `ProcessInfo.operatingSystemVersionString`.
    static func buildFromOperatingSystemVersionString() -> String {
        let text = ProcessInfo.processInfo.operatingSystemVersionString
        guard let open = text.lastIndex(of: "("), let close = text.lastIndex(of: ")"), open < close
        else { return "" }
        let inner = text[text.index(after: open)..<close]
        return String(inner.split(separator: " ").last ?? "")
    }

    /// `ProductBuildVersion` of the RUNTIME's `SystemVersion.plist`, found under `$SIMULATOR_ROOT`.
    /// Empty when the environment variable is absent (i.e. not running under a simulator), which the
    /// caller reports rather than treating as agreement.
    static func runtimeSystemVersionBuild() -> String {
        guard let root = ProcessInfo.processInfo.environment["SIMULATOR_ROOT"], !root.isEmpty else {
            return ""
        }
        let path = root + "/System/Library/CoreServices/SystemVersion.plist"
        guard let plist = NSDictionary(contentsOfFile: path),
              let build = plist["ProductBuildVersion"] as? String else { return "" }
        return build
    }

    /// Every source of the build, for the failure message. The two WRONG ones are included
    /// deliberately — seeing the host Mac's build sitting beside the runtime's is what makes the
    /// distinction obvious to the next reader instead of a footnote they skip.
    static func runtimeBuildDiagnostics() -> String {
        var size = 0
        var kernel = "<unreadable>"
        if sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0, size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            if sysctlbyname("kern.osversion", &buffer, &size, nil, 0) == 0 {
                kernel = String(cString: buffer)
            }
        }
        let hostPlist = NSDictionary(contentsOfFile: "/System/Library/CoreServices/SystemVersion.plist")
        let hostBuild = (hostPlist?["ProductBuildVersion"] as? String) ?? "<absent>"
        let environment = ProcessInfo.processInfo.environment
        let runtimeBuild = runtimeSystemVersionBuild()
        var lines: [String] = []
        lines.append("      ProcessInfo.operatingSystemVersionString  : "
                     + ProcessInfo.processInfo.operatingSystemVersionString
                     + "   <- the RUNTIME (authoritative)")
        lines.append("      $SIMULATOR_ROOT/…/SystemVersion.plist     : "
                     + (runtimeBuild.isEmpty ? "<SIMULATOR_ROOT unset>" : runtimeBuild)
                     + "   <- the RUNTIME (cross-check)")
        lines.append("      /System/…/SystemVersion.plist             : " + hostBuild
                     + "   <- the HOST MAC, not the runtime")
        lines.append("      sysctl kern.osversion                     : " + kernel
                     + "   <- the HOST MAC's kernel, not the runtime")
        lines.append("      SIMULATOR_RUNTIME_VERSION (env)           : "
                     + (environment["SIMULATOR_RUNTIME_VERSION"] ?? "<unset>")
                     + "   <- a version, never a build")
        return lines.joined(separator: "\n")
    }

    /// The build(s) the corpus itself names, parsed out of `provenance.targetRuntime`.
    ///
    /// **Step 3c: `targetRuntime` is NOT one string.** All 14 inline-formatting scenarios say
    /// `iOS 26.5 (23F73), K3`; the other 54 say `iOS 26.5 (23F73)`. Both spellings are pinned
    /// EXACTLY by the vendored decoder (not prefix-matched), and this is the only place the corpus
    /// names a capture DEVICE. Parsing the parenthesised build tolerates both spellings without
    /// normalising either away.
    static func pinnedCaptureBuilds(of scenarios: [IDTextInputScenario]) throws -> Set<String> {
        var builds: Set<String> = []
        for scenario in scenarios {
            guard let runtime = scenario.provenance["targetRuntime"] as? String,
                  let open = runtime.firstIndex(of: "("),
                  let close = runtime.firstIndex(of: ")"), open < close else {
                throw NSError(domain: "RichTextEditorDifferentialTests", code: 5, userInfo: [
                    NSLocalizedDescriptionKey:
                        "scenario \(scenario.identifier) has no parenthesised build in its "
                        + "provenance.targetRuntime",
                ])
            }
            builds.insert(String(runtime[runtime.index(after: open)..<close]))
        }
        return builds
    }

    // MARK: - Step 2b, proved rather than asserted

    /// The unfiltered field list is not merely untidy — it fails, at snapshot 0, on `traits`, and
    /// masks every later field of the scenario. This pins the reason `IDTelegramComparableFields()`
    /// exists, so that a future reader who "simplifies" the call site sees what they are undoing.
    func test_theUnfilteredFieldListFailsAtTheFirstSnapshotOnADeclinedField() throws {
        let scenario = try DifferentialCorpus.firstScenario(inFile: "ime-ios26.5-v1")
        let result = try IDTextInputDifferentialRunner()
            .run(scenario, order: .stockReferenceMinimal)

        XCTAssertTrue(scenario.comparisonFields.contains("traits"))
        XCTAssertFalse(IDTelegramComparableFields(scenario.comparisonFields).contains("traits"))

        let unfiltered = IDCompareTextInputSnapshots(result.stockSnapshots,
                                                     result.referenceSnapshots,
                                                     scenario.comparisonFields,
                                                     scenario.geometryTolerance)
        XCTAssertEqual(unfiltered?.fieldPath, "traits",
                       "the unfiltered list is expected to fail on the first declined field it reaches")
        XCTAssertEqual(unfiltered?.phase, result.stockSnapshots.first?.phase,
                       "…and to do so at the FIRST snapshot, masking every later snapshot's every field")
    }

    // MARK: - The run

    private func runFamily(inFile fileName: String) throws {
        try assertPinnedRuntimeBuild()

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

    private func assertPinnedRuntimeBuild() throws {
        let expected = try Self.pinnedCaptureBuilds(of: DifferentialCorpus.allScenarios())
        let actual = Self.runningRuntimeBuild()
        guard expected.contains(actual) else {
            XCTFail("""
                DIFFERENTIAL RUN ABORTED — WRONG SIMULATOR RUNTIME BUILD.
                  expected : \(expected.sorted().joined(separator: ", "))
                  actual   : \(actual.isEmpty ? "<unreadable>" : actual)
                \(Self.runtimeBuildDiagnostics())
                This is a hard failure and never a skip: on the wrong build the oracle reports stock \
                UIKit's own behaviour changes as Telegram's, and a skipped differential run reads as \
                a pass in every summary that matters.
                """)
            throw NSError(domain: "RichTextEditorDifferentialTests", code: 6, userInfo: [
                NSLocalizedDescriptionKey: "wrong simulator runtime build: \(actual)",
            ])
        }
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

        var explained: [(ObservedDifference, TelegramDifferentialExpectation)] = []
        var unexplained: [ObservedDifference] = []
        for difference in observed {
            if let entry = TelegramDifferentialExpectations.expectation(for: difference) {
                explained.append((difference, entry))
            } else {
                unexplained.append(difference)
            }
        }

        var lines: [String] = []
        lines.append("=== DIFFERENTIAL \(family) (\(fileName))")
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

        // A reference-vs-minimal difference is never excusable — see the `minimal-is-not-a-second-
        // backend` caveat. Assert it rather than trusting the table not to grow one.
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
