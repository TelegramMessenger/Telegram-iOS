import XCTest

/// Tier 2 because it goes through the real keyboard. Typing is where this engine's defects
/// concentrate, and a hosted test calling `setInputContent` would not touch that path at all.
final class HarnessSendUITests: XCTestCase {
    /// **A press with a dwell, not `tap()`.** An instant down/up does not place a caret in this
    /// editor; it reads as the app ignoring the touch. This is a harness fact, not a defect.
    private func focusComposer(_ app: XCUIApplication) {
        let root = app.otherElements["harness.root"]
        XCTAssertTrue(root.waitForExistence(timeout: 30.0))
        let composer = root.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        composer.press(forDuration: 0.1)
    }

    func testTypedTextReachesTheModel() {
        let app = XCUIApplication()
        app.launchArguments = ["-harness-scenario", "empty", "-harness-backend", "engine"]
        app.launch()

        let readout = app.otherElements["harness.modelDump"]
        XCTAssertTrue(readout.waitForExistence(timeout: 30.0))
        self.focusComposer(app)
        app.typeText("hello")

        let predicate = NSPredicate(format: "value CONTAINS %@", "\"hello\"")
        expectation(for: predicate, evaluatedWith: readout)
        waitForExpectations(timeout: 30.0)

        let value = readout.value as? String ?? ""
        XCTAssertTrue(value.contains("hasText=true"), value)
        XCTAssertTrue(value.contains("backend=engine"), value)
    }
}
