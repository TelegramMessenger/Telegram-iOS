import XCTest
import UIKit

/// **What broke.** On the engine backend, deleting a selection with Backspace leaves the
/// SELECTION edit menu on screen — Cut / Copy / Paste / Format — floating over what is now a
/// collapsed caret (over an empty composer after Select All). The legacy backend dismisses the menu
/// the moment the selection is deleted, as `UITextView` does. Typing a character over the same
/// selection does dismiss it on the engine, so it is specific to the Backspace path.
///
/// **How it was seen.** On K1, engine backend: `one-paragraph` → caret → Select All → Backspace left
/// "Cut Copy Paste Format >" on screen with `hasText=false`; the same with `empty` after typing
/// twelve paragraphs, and with a single selected word in `one-paragraph`. Legacy control: the menu
/// is gone after the same Backspace.
///
/// **Suspected cause.** `TGIDObservingBlockTextView.deleteBackward` reroutes a selection deletion
/// to `replaceRange:withText:@""` (so it reaches the structural gate) and returns without
/// `[super deleteBackward]`, which is the path on which UIKit's text interaction hides its edit menu.
///
/// **Tier 2**, because the defect is the system edit menu's presence, which exists only through a
/// real selection gesture and UIKit's `UIEditMenuInteraction`; no panel API raises it.
final class HarnessEditMenuUITests: XCTestCase {
    private func menuItem(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func launch(scenario: String) -> (XCUIApplication, XCUIElement) {
        let app = XCUIApplication()
        app.launchArguments = ["-harness-scenario", scenario, "-harness-backend", "engine"]
        app.launch()
        let readout = app.otherElements["harness.modelDump"]
        XCTAssertTrue(readout.waitForExistence(timeout: 30.0))
        let predicate = NSPredicate(format: "value CONTAINS %@", "backend=engine")
        expectation(for: predicate, evaluatedWith: readout)
        waitForExpectations(timeout: 30.0)
        return (app, readout)
    }

    /// Focus with one dwell press at a character that is NOT the seeded caret (so it only moves
    /// the caret), then a second press on the caret, which is the gesture that raises the menu.
    /// Coordinates are re-derived from the editor each time: the keyboard moves the panel.
    private func raiseEditMenu(_ app: XCUIApplication) {
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10.0))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        editor.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.25)).press(forDuration: 0.1)
    }

    private func menuIsShowing(_ app: XCUIApplication, within timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if self.menuItem(app, "Cut").exists || self.menuItem(app, "Copy").exists {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return false
    }

    /// **Second defect in this family: the FIRST, focusing tap raises the edit menu.**
    ///
    /// Tapping an unfocused composer at (or right of) the end of its text — where a restored draft
    /// leaves the caret, and the most natural place to tap to continue typing — focuses it AND
    /// shows "Paste / Select / Select All", as if the user had tapped twice. Seen on K1 with
    /// `one-paragraph` in 5 of 7 engine launches; 0 of 5 on legacy with the identical tap. The
    /// engine keeps its seeded selection while unfocused, so the focusing tap lands ON the caret
    /// and UIKit's selection interaction reads it as "tap on the caret → show commands".
    /// `TGIDObservingBlockTextView._findBoundaryPositionClosestToPosition:withGranularity:` was
    /// added for exactly this user report ("tapping the field to focus opens a context menu like I
    /// tapped twice") but only covers a tap that snaps to a word boundary, not a tap at the caret.
    ///
    /// Intermittent, so five fresh launches are tried and ANY menu fails the test.
    func testTheFocusingTapDoesNotRaiseTheEditMenu() {
        // An empty pasteboard owned by the runner: the menu build must not be masked (or joined)
        // by the paste-permission alert from `HarnessPastePromptUITests`.
        UIPasteboard.general.items = []

        var raised = 0
        for _ in 0 ..< 5 {
            let (app, _) = self.launch(scenario: "one-paragraph")
            let editor = app.textViews.firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 10.0))
            // Right of the last line's end ("…the lazy dog."), where the seed already put the caret.
            // NOT further right: the text view's frame extends under the send button, and a tap at
            // dx 0.95 lands on Send instead — which is why the first version of this test passed.
            editor.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)).press(forDuration: 0.1)
            if self.menuItem(app, "Select All").waitForExistence(timeout: 2.0)
                || self.menuItem(app, "Paste").exists
                || app.buttons["Allow Paste"].exists {
                raised += 1
            }
            app.terminate()
        }
        XCTAssertEqual(raised, 0, "the focusing tap raised the edit menu in \(raised) of 5 launches")
    }

    func testBackspaceOverSelectAllDismissesTheEditMenu() {
        // See the note in the test above: keep the paste-permission alert out of this one.
        UIPasteboard.general.items = []
        let (app, readout) = self.launch(scenario: "one-paragraph")
        self.raiseEditMenu(app)

        let selectAll = self.menuItem(app, "Select All")
        XCTAssertTrue(selectAll.waitForExistence(timeout: 5.0), "precondition: no edit menu appeared")
        selectAll.tap()
        XCTAssertTrue(self.menuIsShowing(app, within: 3.0),
                      "precondition: Select All did not raise the selection menu")

        app.typeText(XCUIKeyboardKey.delete.rawValue)

        let emptied = NSPredicate(format: "value CONTAINS %@", "hasText=false")
        expectation(for: emptied, evaluatedWith: readout)
        waitForExpectations(timeout: 10.0)

        // Give UIKit's own dismissal time to happen, then require the menu to be GONE.
        RunLoop.current.run(until: Date().addingTimeInterval(2.0))
        XCTAssertFalse(self.menuItem(app, "Cut").exists,
                       "the selection edit menu (Cut) stayed on screen after Backspace deleted the selection")
        XCTAssertFalse(self.menuItem(app, "Format").exists,
                       "the selection edit menu (Format) stayed on screen after Backspace deleted the selection")
    }
}
