import XCTest

class UITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-test")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testLaunch() throws {
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 10.0))
        let _ = app.buttons["___non_existing"].waitForExistence(timeout: 10000.0)
    }

    func testLoginToCodeEntry() throws {
        app.launch()

        // Welcome screen — tap Start Messaging
        let startButton = app.buttons["Auth.Welcome.StartButton"]
        XCTAssert(startButton.waitForExistence(timeout: 5.0))
        startButton.tap()

        // Phone entry screen — enter test phone number
        let countryCodeField = app.textFields["Auth.PhoneEntry.CountryCodeField"]
        XCTAssert(countryCodeField.waitForExistence(timeout: 5.0))
        countryCodeField.tap()
        countryCodeField.press(forDuration: 0.5)
        if app.menuItems["Select All"].waitForExistence(timeout: 2.0) {
            app.menuItems["Select All"].tap()
        }
        countryCodeField.typeText("999")

        let phoneNumberField = app.textFields["Auth.PhoneEntry.PhoneNumberField"]
        phoneNumberField.tap()
        phoneNumberField.typeText("6621234")

        let continueButton = app.buttons["Auth.PhoneEntry.ContinueButton"]
        XCTAssert(continueButton.waitForExistence(timeout: 3.0))
        XCTAssert(continueButton.isEnabled)
        continueButton.tap()

        // Confirmation dialog — tap Continue
        let confirmButton = app.buttons["Auth.PhoneConfirm.ContinueButton"]
        XCTAssert(confirmButton.waitForExistence(timeout: 5.0))
        confirmButton.tap()

        // Code entry screen — verify we arrived
        let codeEntryTitle = app.staticTexts["Auth.CodeEntry.Title"]
        XCTAssert(codeEntryTitle.waitForExistence(timeout: 10.0))
    }
}
