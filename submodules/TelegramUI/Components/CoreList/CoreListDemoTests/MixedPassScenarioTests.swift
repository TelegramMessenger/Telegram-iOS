import XCTest
@testable import CoreListDemo

final class MixedPassScenarioTests: XCTestCase {
    func testSameSeedProducesIdenticalStepsAndFinalState() {
        var lhs = MixedPassScenario(seed: 0xC0DE, itemCount: 120)
        var rhs = MixedPassScenario(seed: 0xC0DE, itemCount: 120)

        let lhsSteps = (0..<40).map { _ in lhs.nextStep().description }
        let rhsSteps = (0..<40).map { _ in rhs.nextStep().description }

        XCTAssertEqual(lhsSteps, rhsSteps)
        XCTAssertEqual(lhs.items, rhs.items)
        XCTAssertEqual(lhs.size, rhs.size)
        XCTAssertEqual(lhs.insets, rhs.insets)
    }

    func testGeneratedStepsRemainValid() {
        var scenario = MixedPassScenario(seed: 0x5157, itemCount: 120)

        for _ in 0..<200 {
            let step = scenario.nextStep()
            XCTAssertFalse(step.items.isEmpty)
            XCTAssertEqual(Set(step.items.map(\.id)).count, step.items.count)
            XCTAssertGreaterThan(step.size.width, step.insets.left + step.insets.right)
            XCTAssertGreaterThan(step.size.height, step.insets.top + step.insets.bottom)
            if let scrollTo = step.scrollTo {
                XCTAssertTrue(step.items.indices.contains(scrollTo.index))
            }
            XCTAssertEqual(
                step.actions.map(\.description).joined(separator: " + "),
                step.actionDescription
            )
        }
    }

    func testFailureContextContainsReplayCoordinates() {
        var scenario = MixedPassScenario(seed: 42, itemCount: 120)
        _ = scenario.nextStep()
        let context = scenario.failureContext(
            pass: 1,
            size: CGSize(width: 390, height: 800),
            insets: .zero,
            offset: 125,
            loadedIndices: Array(3...14),
            crossingIdentities: [7, 8],
            ghostDescriptions: ["block=1 root=250"]
        )

        XCTAssertTrue(context.contains("seed=42 pass=1"))
        XCTAssertTrue(context.contains("actions="))
        XCTAssertTrue(context.contains("size=(390.0, 800.0)"))
        XCTAssertTrue(context.contains("offset=125.0"))
        XCTAssertTrue(context.contains("loaded=3...14"))
        XCTAssertTrue(context.contains("crossing=[7, 8]"))
        XCTAssertTrue(context.contains("block=1 root=250"))
    }
}
