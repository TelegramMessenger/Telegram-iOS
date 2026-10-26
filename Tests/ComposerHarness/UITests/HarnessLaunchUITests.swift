import XCTest

/// Tier 2 exists to exercise real touch and keyboard delivery. This case proves the TIER works —
/// that an `ios_ui_test` can launch this app and see it — and nothing about the composer. Keep it
/// that way; it is the canary for the target type, not a behaviour test.
final class HarnessLaunchUITests: XCTestCase {
    func testTheHarnessLaunchesAndShowsItsRoot() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.otherElements["harness.root"].waitForExistence(timeout: 30.0))
    }

    /// The mechanism the whole Tier-2 tier depends on: model state, read out of process, as a
    /// string. If this breaks, every Tier-2 assertion degrades to "an element exists".
    func testTheModelDumpIsReadableFromOutsideTheProcess() {
        let app = XCUIApplication()
        app.launchArguments = ["-harness-scenario", "one-paragraph", "-harness-backend", "engine"]
        app.launch()

        let readout = app.otherElements["harness.modelDump"]
        XCTAssertTrue(readout.waitForExistence(timeout: 30.0))

        let predicate = NSPredicate(format: "value CONTAINS %@", "backend=engine")
        expectation(for: predicate, evaluatedWith: readout)
        waitForExpectations(timeout: 30.0)

        let value = readout.value as? String ?? ""
        XCTAssertTrue(value.contains("hasText=true"), value)
        XCTAssertTrue(value.contains("quick brown fox"), value)
    }
}
