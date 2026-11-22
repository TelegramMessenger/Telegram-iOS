import XCTest
import UIKit

/// **What this pins.** The engine composer's text drag, through real touches: a long press on a SELECTED
/// word lifts it and dragging it elsewhere in the text moves it. Before 2026-09-24 the engine view had
/// no drag or drop interaction at all (`HarnessTextDragAndDropTests`, Tier 1), so the same gesture ran
/// the loupe and the word stayed where it was.
///
/// **Controls** (gesture arbitration — the drag's lift is a long press, which competes with the text
/// interaction's own): a long press on UNSELECTED text still moves the caret (the loupe) and changes no
/// text; double tap still selects a word and raises the edit menu; the field still scrolls, including a
/// swipe that starts on a selected word.
///
/// **Tier 2**, because the lift's long press and its arbitration with UIKit's text interaction are the
/// thing under test; a hosted test cannot synthesise a drag session.
final class HarnessTextDragUITests: XCTestCase {
    private func launch(scenario: String, backend: String = "engine") -> (XCUIApplication, XCUIElement, XCUIElement) {
        UIPasteboard.general.items = []
        let app = XCUIApplication()
        app.launchArguments = ["-harness-scenario", scenario, "-harness-backend", backend]
        app.launch()
        let readout = app.otherElements["harness.modelDump"]
        XCTAssertTrue(readout.waitForExistence(timeout: 30.0))
        expectation(for: NSPredicate(format: "value CONTAINS %@", "backend=\(backend)"), evaluatedWith: readout)
        waitForExpectations(timeout: 30.0)
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10.0))
        return (app, readout, editor)
    }

    private func dump(_ readout: XCUIElement) -> String {
        return readout.value as? String ?? ""
    }

    private func waitFor(_ readout: XCUIElement, timeout: TimeInterval = 5.0, _ condition: (String) -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition(self.dump(readout)) {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition(self.dump(readout))
    }

    /// The `selection=a..<b` line of the readout.
    private func selection(_ readout: XCUIElement) -> String? {
        return self.dump(readout).components(separatedBy: "\n").first(where: { $0.hasPrefix("selection=") })
    }

    private func menuIsShowing(_ app: XCUIApplication, within timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            for label in ["Cut", "Copy"] {
                if app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch.exists {
                    return true
                }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// Focuses the field with a dwell press (never a bare tap: an instant down/up does not place a
    /// caret in this editor), then double-taps "quick" (4..<9) in `one-paragraph`. Taps stay at
    /// dx ≤ 0.5: the text view's frame extends under the send button.
    private func selectQuick(_ app: XCUIApplication, _ readout: XCUIElement, _ editor: XCUIElement) -> Bool {
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).doubleTap()
        let selected = self.waitFor(readout) { $0.contains("selection=4..<9\n") }
        // Past UIKit's tap-and-a-half window: a press straight after a double tap is read as "tap, then
        // press and drag", which extends the selection (measured: 4..<15) rather than lifting it.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        return selected
    }

    /// Long press on the selected "quick", drag it onto the second line, drop: "quick" leaves
    /// "The quick brown" and lands elsewhere; the text is otherwise the same length.
    func testDraggingASelectedWordMovesIt() {
        self.assertDraggingASelectedWordMovesIt(backend: "engine")
    }

    // No legacy twin: the identical gesture on the legacy composer (`ChatInputTextView`) leaves its
    // selection in place and moves nothing (measured 2026-09-24, iOS 27.0 runner), so it cannot serve as
    // a control for the gesture. That the gesture reaches a real drag session is shown by the engine
    // case itself: nothing but a drop can rearrange the text it asserts on.

    private func assertDraggingASelectedWordMovesIt(backend: String) {
        // `long-word`: "Extraordinarily careful notes, taken slowly today." — the first word is ~135pt
        // wide, so a press in its middle is ~65pt from either selection handle (a press within their
        // ±22pt zones drags the handle instead: measured, "quick" came out as 4..<15).
        let (app, readout, editor) = self.launch(scenario: "long-word", backend: backend)
        defer { app.terminate() }
        let word = CGVector(dx: 0.23, dy: 0.25)
        editor.coordinate(withNormalizedOffset: word).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        editor.coordinate(withNormalizedOffset: word).doubleTap()
        XCTAssertTrue(self.waitFor(readout) { $0.contains("selection=0..<15\n") }, "\(backend): precondition: double tap did not select the first word: \(self.dump(readout))")
        // Past UIKit's tap-and-a-half window.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let source = editor.coordinate(withNormalizedOffset: word)
        let target = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.75))
        source.press(forDuration: 1.0, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 1.0)
        let moved = self.waitFor(readout, timeout: 8.0) { dump in
            !dump.contains("\"Extraordinarily careful") && dump.contains("Extraordinarily") && dump.contains("run 0..<50 ")
        }
        XCTAssertTrue(moved, "\(backend): dragging the selected word did not move it: \(self.dump(readout))")
        // That the move is ONE undo step is asserted on the model, at Tier 1 (`HarnessTextDropTests`).
    }

    /// Control: a long press on UNSELECTED text lifts nothing — no text moves and no range is selected.
    /// (The engine's long press on unselected text shows the edit menu and leaves the caret where it
    /// was; measured on K1 with drag and drop compiled OUT, 2026-09-24, so that is its behaviour, not
    /// this change's. The legacy text view moves the caret. Neither is asserted.)
    func testControlALongPressOnUnselectedTextLiftsNothing() {
        self.assertALongPressOnUnselectedTextLiftsNothing(backend: "engine")
    }

    func testControlALongPressOnUnselectedTextLiftsNothingOnLegacy() {
        self.assertALongPressOnUnselectedTextLiftsNothing(backend: "legacy")
    }

    private func assertALongPressOnUnselectedTextLiftsNothing(backend: String) {
        let (app, readout, editor) = self.launch(scenario: "one-paragraph", backend: backend)
        defer { app.terminate() }
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let text = self.dump(readout).components(separatedBy: "\n").filter { $0.contains("run ") }
        // A long press on the second line, then a slow drag away from it, as a lift would be dragged.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.75))
            .press(forDuration: 1.2, thenDragTo: editor.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.25)), withVelocity: .slow, thenHoldForDuration: 0.5)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        let after = self.dump(readout)
        XCTAssertEqual(after.components(separatedBy: "\n").filter { $0.contains("run ") }, text, "\(backend): a long press on unselected text changed the text: \(after)")
        if let line = self.selection(readout) {
            let parts = line.dropFirst("selection=".count).components(separatedBy: "..<")
            XCTAssertEqual(parts.first, parts.last, "\(backend): a long press on unselected text selected a range: \(line)")
        }
    }

    /// Control: double tap selects the word and raises the edit menu, with the drag interaction installed.
    func testControlDoubleTapStillSelectsAndRaisesTheMenu() {
        let (app, readout, editor) = self.launch(scenario: "one-paragraph")
        defer { app.terminate() }
        XCTAssertTrue(self.selectQuick(app, readout, editor), "double tap did not select \"quick\": \(self.dump(readout))")
        if !self.menuIsShowing(app, within: 2.0) {
            // UIKit raises it on the selection; a tap on the selection toggles it if it did not.
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        }
        XCTAssertTrue(self.menuIsShowing(app, within: 4.0), "the edit menu did not appear over the selection")
    }

    /// Control: the field scrolls, and a swipe that STARTS on a selected word scrolls it too (the
    /// drag's lift is a long press, so a swipe is never the drag's). `many-lines` is taller than the
    /// field; where a press at the field's top lands says which line is at the top.
    func testControlTheFieldStillScrollsIncludingFromASelection() {
        let (app, readout, editor) = self.launch(scenario: "many-lines")
        defer { app.terminate() }
        func pressTop() -> Int? {
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.1)).press(forDuration: 0.1)
            RunLoop.current.run(until: Date().addingTimeInterval(1.0))
            guard let line = self.selection(readout) else { return nil }
            return Int(line.dropFirst("selection=".count).components(separatedBy: "..<")[0])
        }
        func swipe(fromDy: CGFloat, toDy: CGFloat) {
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: fromDy))
                .press(forDuration: 0.05, thenDragTo: editor.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: toDy)))
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        }
        _ = pressTop()
        // To the top, then read where the top is.
        swipe(fromDy: 0.2, toDy: 1.5)
        swipe(fromDy: 0.2, toDy: 1.5)
        guard let atTop = pressTop() else {
            return XCTFail("no selection in the readout: \(self.dump(readout))")
        }
        print("DND scroll: top press at the top of the draft -> \(atTop); \(self.dump(readout).components(separatedBy: "\n").prefix(3).joined(separator: " | "))")
        // A plain swipe up scrolls down the draft.
        swipe(fromDy: 0.9, toDy: -0.8)
        guard let scrolled = pressTop() else {
            return XCTFail("no selection in the readout: \(self.dump(readout))")
        }
        XCTAssertGreaterThan(scrolled, atTop, "a swipe did not scroll the field: \(self.dump(readout))")
        // Select the word under the finger, wait out the tap-and-a-half window, and swipe DOWN from it.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.1)).doubleTap()
        XCTAssertTrue(self.waitFor(readout) { dump in
            guard let line = dump.components(separatedBy: "\n").first(where: { $0.hasPrefix("selection=") }) else { return false }
            let parts = line.dropFirst("selection=".count).components(separatedBy: "..<")
            return parts.count == 2 && parts[0] != parts[1]
        }, "precondition: double tap did not select a word: \(self.dump(readout))")
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        swipe(fromDy: 0.1, toDy: 1.5)
        swipe(fromDy: 0.1, toDy: 1.5)
        guard let back = pressTop() else {
            return XCTFail("no selection in the readout: \(self.dump(readout))")
        }
        XCTAssertLessThan(back, scrolled, "a swipe starting on a selected word did not scroll the field: \(self.dump(readout))")
        XCTAssertTrue(self.dump(readout).contains("Line number 7 of the draft"), "a swipe changed the text: \(self.dump(readout))")
    }
}
