import Foundation
import XCTest

final class AccessibilityUITests: XCTestCase {
    private static let initialTreeElementBudget = 500
    private static let traversalSampleCount = 10
    private static let averageTraversalBudget: TimeInterval = 2.0
    private static let maximumTraversalBudget: TimeInterval = 5.0

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["--ui-test", "--voiceover-release-gate"]
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
}
