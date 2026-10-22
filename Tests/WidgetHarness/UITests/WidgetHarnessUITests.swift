import XCTest

/// Tier 2: real touches on the real chat bubbles, read back through `harness.readout`.
final class WidgetHarnessUITests: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    /// The readout is a label: a static text whose value is the whole readout.
    private func readout(_ app: XCUIApplication) -> String {
        let element = app.staticTexts["harness.readout"]
        guard element.exists else {
            return ""
        }
        return (element.value as? String) ?? ""
    }

    /// Waits until the readout satisfies `condition`, for at most `timeout` seconds; returns the last readout.
    @discardableResult
    private func waitForReadout(_ app: XCUIApplication, timeout: TimeInterval = 20.0, _ condition: (String) -> Bool) -> String {
        let deadline = Date(timeIntervalSinceNow: timeout)
        var value = self.readout(app)
        while !condition(value) && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
            value = self.readout(app)
        }
        return value
    }

    /// The centre of the first bubble whose line contains `path`, in the app's coordinates.
    private func centre(of path: String, in readout: String) -> CGVector? {
        guard let line = readout.split(separator: "\n").first(where: { $0.hasPrefix("bubble ") && $0.contains(path) }),
              let at = line.split(separator: " ").first(where: { $0.hasPrefix("@") }) else {
            return nil
        }
        let numbers = at.dropFirst().split(separator: ",").compactMap { Double($0) }
        return numbers.count == 2 ? CGVector(dx: numbers[0], dy: numbers[1]) : nil
    }

    private func attachScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        self.add(attachment)
    }

    func testATapOnAWidgetButtonOpensTheLinkPrompt() throws {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "open-link"])
        let ready = self.waitForReadout(app) { $0.contains("open-link.html") && $0.contains(" widget") }
        let point = try XCTUnwrap(self.centre(of: "open-link", in: ready), ready)
        app.coordinate(withNormalizedOffset: .zero).withOffset(point).press(forDuration: 0.1)
        let after = self.waitForReadout(app, timeout: 5.0) { $0.contains("openLink https://example.org/harness") }
        XCTAssertTrue(after.contains("openLink https://example.org/harness"), after)
        XCTAssertFalse(after.contains("(not concealed)"), after)
    }

    /// A long press opens the bubble's context menu and must not also click the widget when the finger lifts (the
    /// task 7 fix-wave review's N2: the menu's gesture recognizes alongside the widget's recognizer).
    func testALongPressOpensTheMenuAndDoesNotClick() throws {
        let app = self.launch(["-widget-set", "fixture", "-widget-post", "open-link"])
        let ready = self.waitForReadout(app) { $0.contains("open-link.html") && $0.contains(" widget") }
        let point = try XCTUnwrap(self.centre(of: "open-link", in: ready), ready)
        let coordinate = app.coordinate(withNormalizedOffset: .zero).withOffset(point)
        coordinate.press(forDuration: 1.2)
        let afterPress = self.waitForReadout(app, timeout: 5.0) { $0.contains("contextMenuEnded") }
        self.attachScreenshot(app, "after the long press")
        XCTAssertTrue(afterPress.contains("contextMenu fixture/open-link.html"), afterPress)
        XCTAssertFalse(afterPress.contains("openLink"), afterPress)
        coordinate.press(forDuration: 0.1)
        let afterTap = self.waitForReadout(app, timeout: 5.0) { $0.contains("openLink") }
        XCTAssertTrue(afterTap.contains("openLink https://example.org/harness"), afterTap)
    }

    func testTheKillSwitchPillAndItsCaption() {
        let app = self.launch(["-widget-kill-switch", "on", "-widget-post", "visual/01-boxes"])
        let value = self.waitForReadout(app) { $0.contains(" pill") }
        self.attachScreenshot(app, "kill switch engaged")
        let bubbles = value.split(separator: "\n").filter { $0.hasPrefix("bubble ") }
        XCTAssertFalse(bubbles.isEmpty, value)
        for line in bubbles {
            XCTAssertTrue(line.contains(" pill +caption"), String(line))
        }
    }

    func testTheConformanceSetLoadsInOrder() {
        for theme in ["light", "dark"] {
            let app = self.launch(["-widget-set", "conformance", "-harness-theme", theme])
            let value = self.waitForReadout(app) { $0.contains(" widget") }
            self.attachScreenshot(app, "conformance set, \(theme)")
            XCTAssertTrue(value.contains("bubble 0 "), value)
            app.terminate()
        }
    }
}
