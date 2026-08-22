import Foundation
import XCTest

final class AccessibilityUITests: XCTestCase {
    private static let initialTreeElementBudget = 500
    private static let traversalSampleCount = 10
    private static let averageTraversalBudget: TimeInterval = 2.0
    private static let maximumTraversalBudget: TimeInterval = 5.0
    private static let settingsTreeElementBudget = 250
    private static let typingUpdateAverageBudget: TimeInterval = 3.0
    private static let typingUpdateMaximumBudget: TimeInterval = 6.0

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        if ProcessInfo.processInfo.environment["VOICEOVER_USE_EXISTING_DATA"] != "1" {
            app.launchArguments.append("--ui-test")
        }
        app.launchArguments.append("--voiceover-release-gate")
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @available(iOS 17.0, *)
    func testInitialAccessibilityTree() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))
        try app.performAccessibilityAudit()
    }

    func testStableMessageIdentifiersAreUnique() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let messages = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "message.")
        )
        var identifiers = Set<String>()
        for index in 0 ..< messages.count {
            let identifier = messages.element(boundBy: index).identifier
            XCTAssertFalse(identifier.isEmpty)
            XCTAssertTrue(identifiers.insert(identifier).inserted, "Duplicate message accessibility identifier: \(identifier)")
        }
    }

    func testInitialAccessibilityTreeStaysWithinBudget() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let elementCount = app.descendants(matching: .any).count
        let attachment = XCTAttachment(string: "Initial accessibility tree elements: \(elementCount)")
        attachment.name = "Accessibility tree size"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertLessThanOrEqual(
            elementCount,
            Self.initialTreeElementBudget,
            "Initial accessibility tree exceeded its budget; inspect hidden or decorative duplicate elements"
        )
    }

    func testAccessibilityTreeTraversalPerformance() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        _ = app.descendants(matching: .any).count

        var samples: [TimeInterval] = []
        for _ in 0 ..< Self.traversalSampleCount {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = app.descendants(matching: .any).count
            samples.append(CFAbsoluteTimeGetCurrent() - startTime)
        }

        let average = samples.reduce(0.0, +) / Double(samples.count)
        let maximum = samples.max() ?? 0.0
        let attachment = XCTAttachment(
            string: "Traversal samples: \(samples)\nAverage: \(average)\nMaximum: \(maximum)"
        )
        attachment.name = "Accessibility traversal performance"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertLessThanOrEqual(average, Self.averageTraversalBudget)
        XCTAssertLessThanOrEqual(maximum, Self.maximumTraversalBudget)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = app.descendants(matching: .any).count
        }
    }

    func testPopulatedChatMessageContractWhenFixtureIsAvailable() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let messages = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "message.")
        )
        guard messages.count != 0 else {
            throw XCTSkip("Run with VOICEOVER_USE_EXISTING_DATA=1 and open a populated chat before launching the test")
        }

        var identifiers = Set<String>()
        for index in 0 ..< messages.count {
            let message = messages.element(boundBy: index)
            XCTAssertFalse(message.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(message.identifier.isEmpty)
            XCTAssertTrue(identifiers.insert(message.identifier).inserted)
            XCTAssertGreaterThan(message.frame.width, 0.0)
            XCTAssertGreaterThan(message.frame.height, 0.0)
        }
    }

    func testChatInputHitTargetWhenFixtureIsAvailable() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let input = app.descendants(matching: .any)["chat.input"]
        guard input.waitForExistence(timeout: 2.0) else {
            throw XCTSkip("Run with VOICEOVER_USE_EXISTING_DATA=1 and open a writable chat before launching the test")
        }
        XCTAssertGreaterThanOrEqual(input.frame.width, 44.0)
        XCTAssertGreaterThanOrEqual(input.frame.height, 44.0)
        XCTAssertTrue(input.isHittable)
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2.0))
    }

    func testSettingsVoiceControlContractAndPerformanceWhenFixtureIsAvailable() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let settingsItems = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@",
                "peerInfo.disclosure.",
                "peerInfo.action."
            )
        )
        guard settingsItems.count >= 5 else {
            throw XCTSkip("Run with VOICEOVER_USE_EXISTING_DATA=1 and leave the main Settings tab visible")
        }

        var identifiers = Set<String>()
        for index in 0 ..< settingsItems.count {
            let item = settingsItems.element(boundBy: index)
            XCTAssertFalse(item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(identifiers.insert(item.identifier).inserted)
            XCTAssertGreaterThan(item.frame.width, 0.0)
            XCTAssertGreaterThan(item.frame.height, 0.0)
        }

        let elementCount = app.descendants(matching: .any).count
        XCTAssertLessThanOrEqual(elementCount, Self.settingsTreeElementBudget)
        let attachment = XCTAttachment(string: "Settings accessibility tree elements: \(elementCount)")
        attachment.name = "Settings accessibility performance"
        attachment.lifetime = .keepAlways
        add(attachment)

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = app.descendants(matching: .any).count
        }
    }

    func testChatTypingAccessibilityPerformanceWhenFixtureIsAvailable() throws {
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10.0))

        let input = app.descendants(matching: .any)["chat.input"]
        guard input.waitForExistence(timeout: 2.0) else {
            throw XCTSkip("Run with VOICEOVER_USE_EXISTING_DATA=1 and open a writable chat before launching the test")
        }
        input.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2.0))

        var samples: [TimeInterval] = []
        for _ in 0 ..< Self.traversalSampleCount {
            let startTime = CFAbsoluteTimeGetCurrent()
            input.typeText("a")
            _ = app.descendants(matching: .any).count
            input.typeText(XCUIKeyboardKey.delete.rawValue)
            samples.append(CFAbsoluteTimeGetCurrent() - startTime)
        }

        let average = samples.reduce(0.0, +) / Double(samples.count)
        let maximum = samples.max() ?? 0.0
        let attachment = XCTAttachment(
            string: "Typing accessibility samples: \(samples)\nAverage: \(average)\nMaximum: \(maximum)"
        )
        attachment.name = "Voice Control typing performance"
        attachment.lifetime = .keepAlways
        add(attachment)

        XCTAssertLessThanOrEqual(average, Self.typingUpdateAverageBudget)
        XCTAssertLessThanOrEqual(maximum, Self.typingUpdateMaximumBudget)
    }
}
