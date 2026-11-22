import XCTest
@testable import CoreListDemo

final class CrossingSurvivorPlannerTests: XCTestCase {
    private let band = CrossingRetentionBand(
        minY: -200,
        maxY: 800,
        anchorY: 0,
        anchorIndex: 0
    )

    func testOutgoingUsesNearestSharedSettledDisplacement() throws {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 6, side: .old, oldIndex: 6, newIndex: 11,
                y: 450, height: 75, isMoveParticipant: false
            ),
            samples: [
                CrossingDisplacementSample(
                    identity: 5, oldIndex: 5, newIndex: 10,
                    oldY: 375, newY: 750
                )
            ],
            band: band
        )

        XCTAssertEqual(plan.source, .shared(AnyHashable(5)))
        XCTAssertEqual(plan.oldY, 450, accuracy: 1e-9)
        XCTAssertEqual(plan.newY, 825, accuracy: 1e-9)
    }

    func testIncomingUsesNearestSharedSettledDisplacement() throws {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 6, side: .new, oldIndex: 11, newIndex: 6,
                y: 450, height: 75, isMoveParticipant: false
            ),
            samples: [
                CrossingDisplacementSample(
                    identity: 5, oldIndex: 10, newIndex: 5,
                    oldY: 750, newY: 375
                )
            ],
            band: band
        )

        XCTAssertEqual(plan.source, .shared(AnyHashable(5)))
        XCTAssertEqual(plan.oldY, 825, accuracy: 1e-9)
        XCTAssertEqual(plan.newY, 450, accuracy: 1e-9)
    }

    func testNearestSampleProducesPiecewiseDisplacement() {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 7, side: .old, oldIndex: 7, newIndex: 5,
                y: 350, height: 50, isMoveParticipant: false
            ),
            samples: [
                CrossingDisplacementSample(
                    identity: 2, oldIndex: 2, newIndex: 3,
                    oldY: 100, newY: 150
                ),
                CrossingDisplacementSample(
                    identity: 8, oldIndex: 8, newIndex: 6,
                    oldY: 400, newY: 300
                )
            ],
            band: band
        )

        XCTAssertEqual(plan.source, .shared(AnyHashable(8)))
        XCTAssertEqual(plan.newY, 250, accuracy: 1e-9)
    }

    func testMoveParticipantFallsBackBeyondBottomBand() {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 9, side: .old, oldIndex: 9, newIndex: 2,
                y: 500, height: 75, isMoveParticipant: true
            ),
            samples: [
                CrossingDisplacementSample(
                    identity: 8, oldIndex: 8, newIndex: 8,
                    oldY: 450, newY: 500
                )
            ],
            band: band
        )

        XCTAssertEqual(plan.source, .retentionBoundary)
        XCTAssertEqual(plan.oldY, 500, accuracy: 1e-9)
        XCTAssertEqual(plan.newY, 800, accuracy: 1e-9)
    }

    func testSharedSampleAcrossStructuralRegionIsNotEligible() {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 5, side: .old, oldIndex: 5, newIndex: 105,
                y: 375, height: 75, isMoveParticipant: false
            ),
            samples: [
                CrossingDisplacementSample(
                    identity: 4, oldIndex: 4, newIndex: 4,
                    oldY: 300, newY: 300
                )
            ],
            band: band
        )

        XCTAssertEqual(plan.source, .retentionBoundary)
        XCTAssertEqual(plan.oldY, 375, accuracy: 1e-9)
        XCTAssertEqual(plan.newY, 800, accuracy: 1e-9)
    }

    func testMissingSampleFallsBackBeyondTopBand() {
        let plan = CrossingSurvivorPlanner.infer(
            endpoint: CrossingKnownEndpoint(
                identity: 1, side: .new, oldIndex: 9, newIndex: 1,
                y: 0, height: 75, isMoveParticipant: false
            ),
            samples: [],
            band: CrossingRetentionBand(
                minY: -200, maxY: 800,
                anchorY: 400, anchorIndex: 8
            )
        )

        XCTAssertEqual(plan.source, .retentionBoundary)
        XCTAssertEqual(plan.oldY, -275, accuracy: 1e-9)
        XCTAssertEqual(plan.newY, 0, accuracy: 1e-9)
    }

    func testOutgoingUnwitnessedRunBelowAnchorPreservesSpacing() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 5, side: .old, oldIndex: 5, newIndex: 10,
                                  y: 375, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 6, side: .old, oldIndex: 6, newIndex: 11,
                                  y: 450, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 7, side: .old, oldIndex: 7, newIndex: 12,
                                  y: 525, height: 75, isMoveParticipant: false)
        ]

        let plans = CrossingSurvivorPlanner.infer(endpoints: endpoints,
                                                  samples: [], band: band)

        XCTAssertEqual(plans.map(\.newY), [800, 875, 950])
        XCTAssertEqual(plans.map { $0.newY - $0.oldY }, [425, 425, 425])
        XCTAssertTrue(plans.allSatisfy { $0.source == .retentionBoundary })
    }

    func testIncomingUnwitnessedRunBelowAnchorIsInverseProjection() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 5, side: .new, oldIndex: 10, newIndex: 5,
                                  y: 375, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 6, side: .new, oldIndex: 11, newIndex: 6,
                                  y: 450, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 7, side: .new, oldIndex: 12, newIndex: 7,
                                  y: 525, height: 75, isMoveParticipant: false)
        ]

        let plans = CrossingSurvivorPlanner.infer(endpoints: endpoints,
                                                  samples: [], band: band)

        XCTAssertEqual(plans.map(\.oldY), [800, 875, 950])
        XCTAssertEqual(plans.map { $0.oldY - $0.newY }, [425, 425, 425])
    }

    func testUnwitnessedRunBelowAnchorClearsOccupiedWindowExtent() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 5, side: .old, oldIndex: 5, newIndex: 10,
                                  y: 375, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 6, side: .old, oldIndex: 6, newIndex: 11,
                                  y: 450, height: 75, isMoveParticipant: false)
        ]
        let band = CrossingRetentionBand(minY: -200, maxY: 800,
                                         anchorY: 0, anchorIndex: 0,
                                         occupiedMinY: -240, occupiedMaxY: 850)

        let plans = CrossingSurvivorPlanner.infer(endpoints: endpoints,
                                                  samples: [], band: band)

        XCTAssertEqual(plans.map(\.newY), [850, 925])
        XCTAssertEqual(plans.map { $0.newY - $0.oldY }, [475, 475])
    }

    func testUnwitnessedRunAboveAnchorClearsOccupiedWindowExtent() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 1, side: .old, oldIndex: 1, newIndex: 4,
                                  y: -150, height: 40, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 2, side: .old, oldIndex: 2, newIndex: 5,
                                  y: -90, height: 60, isMoveParticipant: false)
        ]
        let band = CrossingRetentionBand(minY: -200, maxY: 800,
                                         anchorY: 400, anchorIndex: 8,
                                         occupiedMinY: -240, occupiedMaxY: 850)

        let plans = CrossingSurvivorPlanner.infer(endpoints: endpoints,
                                                  samples: [], band: band)

        XCTAssertEqual(plans.map(\.newY), [-360, -300])
        XCTAssertEqual(plans.last!.newY + 60, -240)
    }

    func testUnwitnessedRunAboveAnchorPreservesVariableHeightsAndGaps() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 1, side: .old, oldIndex: 1, newIndex: 4,
                                  y: -150, height: 40, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 2, side: .old, oldIndex: 2, newIndex: 5,
                                  y: -90, height: 60, isMoveParticipant: false)
        ]

        let plans = CrossingSurvivorPlanner.infer(
            endpoints: endpoints,
            samples: [],
            band: CrossingRetentionBand(minY: -200, maxY: 800,
                                        anchorY: 400, anchorIndex: 8)
        )

        XCTAssertEqual(plans.map(\.newY), [-320, -260])
        XCTAssertEqual(plans[1].newY + 60, -200)
        XCTAssertEqual(plans[1].newY - plans[0].newY, 60)
    }

    func testBatchDoesNotJoinDifferentStructuralRegionsOrMoveParticipants() {
        let endpoints = [
            CrossingKnownEndpoint(identity: 5, side: .old, oldIndex: 5, newIndex: 10,
                                  y: 375, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 6, side: .old, oldIndex: 6, newIndex: 11,
                                  y: 450, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 7, side: .old, oldIndex: 7, newIndex: 13,
                                  y: 525, height: 75, isMoveParticipant: false),
            CrossingKnownEndpoint(identity: 8, side: .old, oldIndex: 8, newIndex: 14,
                                  y: 600, height: 75, isMoveParticipant: true)
        ]

        let plans = CrossingSurvivorPlanner.infer(endpoints: endpoints,
                                                  samples: [], band: band)

        XCTAssertEqual(plans.map(\.newY), [800, 875, 800, 800])
    }
}
