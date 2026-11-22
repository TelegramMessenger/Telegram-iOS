import XCTest

/// **Exploratory, not yet a regression.** The multi-tap selection gestures could not be driven on K1
/// by hand (`axe` double/triple taps are not recognised by UIKit's text interaction), so this pass
/// could not observe them at all. These cases state the expected behaviour on BOTH backends; legacy
/// is the control. If an engine case fails while its legacy twin passes, that is a finding — record
/// it in `docs/findings.md` and rewrite this header as a regression header. If a legacy case fails
/// too, suspect the coordinates (the keyboard moves the panel; the text view's frame extends under
/// the send button, so taps stay at dx ≤ 0.5).
///
/// **Tier 2**, because the gesture recognisers of UIKit's text interaction ARE the thing under test;
/// no panel API selects a word "by double tap".
final class HarnessSelectionGestureUITests: XCTestCase {
    private func launch(scenario: String, backend: String) -> (XCUIApplication, XCUIElement, XCUIElement) {
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

    private func waitForSelection(_ readout: XCUIElement, _ selection: String, timeout: TimeInterval = 5.0) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (readout.value as? String ?? "").contains("selection=\(selection)\n") {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// `one-paragraph`: "The quick brown fox jumps over the lazy dog." wraps to two lines; dx 0.2 on
    /// the first line is inside "quick" (4..<9).
    private func assertDoubleTapSelectsTheWord(backend: String) {
        let (app, readout, editor) = self.launch(scenario: "one-paragraph", backend: backend)
        defer { app.terminate() }
        let point = editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25))
        point.press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        // Re-derive after focus: the keyboard moved the panel.
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).doubleTap()
        XCTAssertTrue(self.waitForSelection(readout, "4..<9"),
                      "\(backend): double tap on \"quick\" did not select it: \(readout.value as? String ?? "")")
    }

    func testDoubleTapSelectsTheWordOnTheEngine() {
        self.assertDoubleTapSelectsTheWord(backend: "engine")
    }

    func testDoubleTapSelectsTheWordOnLegacy() {
        self.assertDoubleTapSelectsTheWord(backend: "legacy")
    }

    /// Triple tap in the middle of the one paragraph selects all of it (0..<44).
    private func assertTripleTapSelectsTheParagraph(backend: String) {
        let (app, readout, editor) = self.launch(scenario: "one-paragraph", backend: backend)
        defer { app.terminate() }
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))
        editor.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        XCTAssertTrue(self.waitForSelection(readout, "0..<44"),
                      "\(backend): triple tap did not select the paragraph: \(readout.value as? String ?? "")")
    }

    func testTripleTapSelectsTheParagraphOnTheEngine() {
        self.assertTripleTapSelectsTheParagraph(backend: "engine")
    }

    func testTripleTapSelectsTheParagraphOnLegacy() {
        self.assertTripleTapSelectsTheParagraph(backend: "legacy")
    }
}
