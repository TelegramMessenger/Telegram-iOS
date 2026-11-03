# UI Testing

## Running Tests

```bash
xcodebuild test \
  -project Telegram/Telegram.xcodeproj \
  -scheme iOSAppUITestSuite \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1'
```

Pick any available simulator. List them with `xcrun simctl list devices available iPhone`.

## Test Environment

Tests launch the app with the `--ui-test` argument. When the app detects this flag:

- It uses an isolated data directory (`telegram-ui-tests-data/` inside the app group container), completely separate from production data.
- That directory is wiped on every launch, so each test run starts with a clean slate.
- The app connects to Telegram **test servers** (not production). Test server accounts are independent of production accounts.

This means every test begins with the app in its first-launch state: no accounts, no data, showing the welcome/auth screen.

## Writing Tests

Test files live in `Telegram/Tests/Sources/`. The test target is `iOSAppUITestSuite`.

Tests use Apple's XCUITest framework. Each test class extends `XCTestCase` and interacts with the app through `XCUIApplication`.

### Template

```swift
import XCTest

class MyFeatureTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-test")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testSomething() throws {
        app.launch()

        // Find elements
        let button = app.buttons["Start Messaging"]

        // Wait for elements to appear
        XCTAssert(button.waitForExistence(timeout: 5.0))

        // Interact
        button.tap()

        // Assert
        XCTAssert(app.textFields["Phone Number"].waitForExistence(timeout: 3.0))
    }
}
```

### Key Patterns

**Always pass `--ui-test`** in `launchArguments`. Without it, the app uses production servers and the real database.

**Wait for elements** rather than assuming they exist immediately. Use `element.waitForExistence(timeout:)` before interacting.

**Find elements** by accessibility identifier, label, or type:
```swift
app.buttons["Continue"]           // by label
app.textFields["Phone Number"]    // by placeholder/label
app.staticTexts["Welcome"]        // static text
app.navigationBars["Settings"]    // navigation bar
```

**Relaunch between tests** if needed. Each `app.launch()` call with `--ui-test` wipes the database, so every test method that calls `launch()` gets a fresh app state.

**Type text** into fields:
```swift
let field = app.textFields["Phone Number"]
field.tap()
field.typeText("9996621234")
```

### Adding a New Test File

1. Create a new `.swift` file in `Telegram/Tests/Sources/`.
2. The file is automatically picked up by the `iOSAppUITestSuite` target via the Bazel build — no manual target membership changes needed.
3. Run with the same `xcodebuild test` command.

## Telegram Test Servers

The test environment uses 3 separate Telegram datacenters, completely independent from production.

### OS Environment

Test logins are guarded behind a specialized OS environment. The simulator or device must be configured for the test environment before test accounts can authenticate.

### Test Phone Numbers

Test phone numbers follow the format `99966XYYYY`:
- `X` is the DC number (1, 2, or 3)
- `YYYY` are random digits

The country code for test numbers is `999`, and the remaining digits are `66XYYYY`.

Examples: `+999 66 2 1234`, `+999 66 1 0000`, `+999 66 3 0001`.

### Verification Codes

Test accounts do not receive real SMS. The confirmation code is **the DC number repeated 5 times**:
- DC 1 (`+999 661 YYYY`) -> code `11111`
- DC 2 (`+999 662 YYYY`) -> code `22222`
- DC 3 (`+999 663 YYYY`) -> code `33333`

### Flood Limits

Test numbers are still subject to flood limits. If a number gets rate-limited, pick a different `YYYY` suffix.

### Deleting Test Accounts

Tests that exercise the sign-up flow create an account on the test servers. Re-running the same test with the same phone number will skip sign-up because the account already exists. To get a fresh sign-up screen, delete the account before running the test.

The app supports a `--delete-test-account <phone>` launch argument. When combined with `--ui-test`, the app logs into the test account, deletes it, and exits — no UI is shown. The verification code is derived automatically from the phone number (DC digit repeated 5 times).

In UI tests, use this by launching a separate app instance:

```swift
private func deleteTestAccount(phone: String) {
    let cleanupApp = XCUIApplication()
    cleanupApp.launchArguments += ["--ui-test", "--delete-test-account", phone]
    cleanupApp.launch()
    let terminated = cleanupApp.wait(for: .notRunning, timeout: 30)
    XCTAssert(terminated, "test account cleanup did not complete in 30s")
}
```

Call `deleteTestAccount(phone:)` at the start of any test that needs a clean sign-up flow. The phone number format is `99966XYYYY` (no `+` prefix needed).

### Security

Do not store any important or private information in test accounts. Anyone can use the simplified authorization mechanism to access them.
