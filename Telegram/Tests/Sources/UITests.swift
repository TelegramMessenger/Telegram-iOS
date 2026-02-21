import XCTest
import Foundation

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

    /// Deletes a test account so the sign-up flow can be exercised again.
    /// Launches the app with `--delete-test-account` which logs in and deletes the account.
    private func deleteTestAccount(phone: String) {
        let cleanupApp = XCUIApplication()
        cleanupApp.launchArguments += ["--ui-test", "--delete-test-account", phone]
        cleanupApp.launch()
        let success = cleanupApp.windows["DeleteAccount.Success"]
        XCTAssert(success.waitForExistence(timeout: 30), "test account cleanup did not complete in 30s")
        cleanupApp.terminate()
    }

    func testLaunch() throws {
        app.launch()
        XCTAssert(app.wait(for: .runningForeground, timeout: 10.0))
    }

    func testSignUp() throws {
        deleteTestAccount(phone: "9996629999")
        app.launch()

        // Welcome screen — tap Start Messaging
        let startButton = app.buttons["Auth.Welcome.StartButton"]
        XCTAssert(startButton.waitForExistence(timeout: 5.0))
        startButton.tap()

        // Phone entry screen — enter test phone number
        let countryCodeField = app.textFields["Auth.PhoneEntry.CountryCodeField"]
        XCTAssert(countryCodeField.waitForExistence(timeout: 10.0))
        countryCodeField.tap()
        for _ in 0..<10 {
            countryCodeField.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        countryCodeField.typeText("999")

        let phoneNumberField = app.textFields["Auth.PhoneEntry.PhoneNumberField"]
        phoneNumberField.tap()
        phoneNumberField.typeText("6629999")

        let continueButton = app.buttons["Auth.PhoneEntry.ContinueButton"]
        XCTAssert(continueButton.waitForExistence(timeout: 3.0))
        XCTAssert(continueButton.isEnabled)
        continueButton.tap()

        // Confirmation dialog — tap Continue
        let confirmButton = app.buttons["Auth.PhoneConfirm.ContinueButton"]
        XCTAssert(confirmButton.waitForExistence(timeout: 5.0))
        confirmButton.tap()

        // Code entry screen — enter verification code
        let codeEntryTitle = app.staticTexts["Auth.CodeEntry.Title"]
        XCTAssert(codeEntryTitle.waitForExistence(timeout: 15.0))

        let codeField = app.textFields["Auth.CodeEntry.CodeField"]
        XCTAssert(codeField.waitForExistence(timeout: 3.0))
        codeField.typeText("22222")

        // Set name screen — enter name and submit
        let firstNameField = app.textFields["Auth.SetName.FirstNameField"]
        XCTAssert(firstNameField.waitForExistence(timeout: 15.0))
        firstNameField.tap()
        firstNameField.typeText("Test")

        let lastNameField = app.textFields["Auth.SetName.LastNameField"]
        lastNameField.tap()
        lastNameField.typeText("User")

        let signUpButton = app.buttons["Auth.SetName.ContinueButton"]
        XCTAssert(signUpButton.waitForExistence(timeout: 3.0))
        signUpButton.tap()

        // Wait for post-signup UI to appear
        sleep(10)
        let description = app.debugDescription
        XCTFail("UI DUMP:\n\(description)")
    }
}
