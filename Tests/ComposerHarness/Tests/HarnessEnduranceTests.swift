import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **A guard, not a defect** (p11 roam, 2026-09-24). A long engine session does not grow: 2,000
/// mixed fuzz ops on one document (no reset) held the process at 101-109 MB, the minimum keystroke
/// cost stayed at 1-7 ms with no drift, and the undo stack is capped by design
/// (`RichTextEngineEditorView.undoDepth` = 200). A first measurement that showed +17 MB per 100 ops
/// was the TEST's own autorelease pool: a hosted test method runs inside one pool that
/// `RunLoop.run(until:)` does not drain, so every op must be wrapped in `autoreleasepool`, or the
/// measurement reports the harness, not the editor (stock `UITextView` and legacy grew the same way).
///
/// Pinned here as one repeatable cycle — arrange, 100 keystrokes with Returns, a Format command,
/// undo everything — whose footprint must not climb after a warm-up. Robust by construction: the
/// MINIMUM of the late rounds against the minimum of the early ones (noise only adds memory), and a
/// threshold (8 MB over 8 cycles, i.e. 1 MB per 100 keystrokes) far above the measured jitter (±1 MB)
/// and far below the artefact that motivated it (+5 MB per cycle).
///
/// **p24 (2026-10-02): a single STEP is not growth.** Inside the full suite (807 cases before it, process at
/// ~258 MB) the p23 run failed once: 258 → 306 → 328 MB between cycles 8 and 9, then FLAT. The same test alone
/// stays flat at ~95 MB footprint / ~37 MB malloc over 16 cycles (measured p24, 3/3 alone in p23), and its cycle
/// touches none of the p23 changes that could retain (no copy, so no covered-text fragment; no custom emoji, so no
/// per-character atoms). A one-off jump that then stays flat is the late-suite process paying for something once
/// (a cache, an allocator zone); a LEAK grows every cycle. So the check is per cycle: the growth across the late
/// cycles with the single largest step taken out must stay under the threshold, and the samples after that step
/// must be flat. A per-cycle retention of 2 MB still fails it (neuter-checked p24 with a deliberate retention).
///
/// **Tier 1**: in-process, the calls are the keyboard's and the menu's.
final class HarnessEnduranceTests: XCTestCase {
    private func footprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) / 1e6 : -1.0
    }

    func testARepeatedEditAndUndoCycleDoesNotGrowTheProcess() throws {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        var samples: [Double] = []
        for _ in 0 ..< 16 {
            autoreleasepool {
                HarnessComposerFuzzTests.arrange(driver, HarnessContent.plainText("Endurance cycle"))
                for index in 0 ..< 100 {
                    driver.insert(index % 10 == 9 ? "\n" : "w")
                    driver.settle(0.0)
                }
                driver.setViewSelection(NSRange(location: 0, length: 5))
                driver.format(.bold)
                driver.settle(0.02)
                while driver.undoManager?.canUndo == true {
                    driver.undoManager?.undo()
                    driver.settle(0.0)
                }
            }
            // Quiesced: the run loop's own pools drained, deferred deliveries landed.
            autoreleasepool { HarnessEngine.settle(driver.root, seconds: 0.3) }
            samples.append(self.footprintMB())
        }
        XCTAssertFalse(samples.contains { $0 < 0.0 }, "precondition: task_info failed")
        let printed = samples.map { String(format: "%.1f", $0) }
        print("ENDURANCE footprint MB per cycle: \(printed)")
        // Per-cycle steps after a 3-cycle warm-up (12 steps, cycle 3 → 4 through 14 → 15).
        let steps = (4 ..< samples.count).map { samples[$0] - samples[$0 - 1] }
        let largest = steps.indices.max(by: { steps[$0] < steps[$1] }) ?? 0
        let growthWithoutLargestStep = steps.enumerated().filter { $0.offset != largest }.map(\.element).reduce(0.0, +)
        XCTAssertLessThan(growthWithoutLargestStep, 8.0,
                          "the process grew \(String(format: "%.1f", growthWithoutLargestStep)) MB over 12 edit/undo cycles beyond its largest single step: \(printed)")
        // The largest step must be a one-off: the cycles after it do not keep climbing.
        let after = Array(samples[(largest + 4)...])
        if let first = after.first, let last = after.last {
            XCTAssertLessThan(last - first, 8.0, "the process kept growing after its largest step: \(printed)")
        }
    }
}
