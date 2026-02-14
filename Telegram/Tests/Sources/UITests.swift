import XCTest

class UITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--ui-test")
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 10.0))
    }
}
