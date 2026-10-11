import XCTest
import UIKit

/// **What broke.** On the engine backend, a long press on UNSELECTED text in a focused composer does
/// not move the caret to the pressed point: it raises the edit menu (Select / Select All / AutoFill /
/// Speak) and leaves the caret where it was. A stock `UITextView` — the legacy composer here, the
/// control below — moves the caret under the loupe to where the finger is held.
///
///     one-paragraph, focus with a press in "quick" (caret 6), long press 1.3 s on "lazy" (line 2)
///       engine  → caret stays 6..<6, the edit menu appears
///       legacy  → caret moves onto line 2 (42..<42 on K1)
///
/// **How it was seen.** The drag-and-drop wave, 2026-09-24, while writing the long-press control for
/// the text drag (`HarnessTextDragUITests`). Verified PRE-EXISTING on K1 with drag and drop compiled out
/// of the engine: identical behaviour, so it is not the drag interaction's.
///
/// **Cause (fixed 2026-09-24).** The loupe moved the caret when it began and UIKit moved it BACK on
/// release: a loupe that begins within 40pt of the caret is read as dragging the caret by its offset,
/// unless the text interaction assistant's `autoscrolled` bit is set by then. The stock view sets it on
/// the first tick of an autoscroll session, which in a field this short starts for every point; the
/// engine declined the session and never set the bit. It now reports the tick wherever the stock
/// session would have started (`IDVerticalAutoscrollStockSessionWouldStart`,
/// `-[IDUIKitInteractionCapability autoscrollDidTick]`). The geometry matters: both presses here are
/// within 40pt of each other, which is what makes the loupe take the near-caret path at all.
///
/// **Tier 2**, because the loupe's long press through UIKit's text interaction IS the path under test.
final class HarnessLongPressCaretUITests: XCTestCase {
    private func caretAfterLongPress(backend: String) -> (before: Int?, after: Int?, dump: String) {
        UIPasteboard.general.items = []
        let app = XCUIApplication()
        app.launchArguments = ["-harness-scenario", "one-paragraph", "-harness-backend", backend]
        app.launch()
        defer { app.terminate() }
        let readout = app.otherElements["harness.modelDump"]
        XCTAssertTrue(readout.waitForExistence(timeout: 30.0))
        expectation(for: NSPredicate(format: "value CONTAINS %@", "backend=\(backend)"), evaluatedWith: readout)
        waitForExpectations(timeout: 30.0)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10.0))
        func caret() -> Int? {
            let dump = readout.value as? String ?? ""
            guard let line = dump.components(separatedBy: "\n").first(where: { $0.hasPrefix("selection=") }) else { return nil }
            let parts = line.dropFirst("selection=".count).components(separatedBy: "..<")
            guard parts.count == 2, parts[0] == parts[1] else { return nil }
            return Int(parts[0])
        }
        // Focus with a dwell press in "quick" on line 1 (never a bare tap; dx ≤ 0.5 keeps off Send).
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let before = caret()
        // Long press on "lazy" on line 2 ("the lazy dog." starts at 31).
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75)).press(forDuration: 1.3)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        return (before, caret(), readout.value as? String ?? "")
    }

    func testALongPressOnUnselectedTextMovesTheCaretOnTheEngine() {
        let result = self.caretAfterLongPress(backend: "engine")
        XCTAssertNotNil(result.before, "precondition: no caret after the focusing press: \(result.dump)")
        guard let after = result.after else {
            return XCTFail("engine: a long press left a range selected, or no caret: \(result.dump)")
        }
        XCTAssertTrue((31 ... 44).contains(after), "engine: a long press on line 2 left the caret at \(after) (was \(result.before.map(String.init) ?? "nil")): \(result.dump)")
    }

    /// Control: the legacy composer (`UITextView`) moves the caret to the held point.
    func testControlALongPressOnUnselectedTextMovesTheCaretOnLegacy() {
        let result = self.caretAfterLongPress(backend: "legacy")
        guard let after = result.after else {
            return XCTFail("legacy: a long press left a range selected, or no caret: \(result.dump)")
        }
        XCTAssertTrue((31 ... 44).contains(after), "legacy: a long press on line 2 left the caret at \(after): \(result.dump)")
    }
}
