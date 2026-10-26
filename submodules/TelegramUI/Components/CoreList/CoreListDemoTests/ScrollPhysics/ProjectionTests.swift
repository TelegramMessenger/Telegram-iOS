import XCTest
import CoreGraphics
import Foundation
@testable import CoreListDemo

final class ProjectionTests: XCTestCase {
    private let lnRate = log(0.998) // ≈ -0.0020020027

    func testProjectsForwardByAnalyticDecayIntegral() {
        // lnRate < 0, so −(v−0.01)/lnRate = +(v−0.01)/|lnRate|: 100 + (2.0−0.01)/0.0020020027 ≈ 1094.005
        XCTAssertEqual(Projection.target(offset: 100, velocity: 2.0, lnRate: lnRate),
                       1094.005, accuracy: 0.01)
    }

    func testNegativeVelocityProjectsBackward() {
        // 100 − (2.0−0.01)/|lnRate| ≈ −894.005
        XCTAssertEqual(Projection.target(offset: 100, velocity: -2.0, lnRate: lnRate),
                       -894.005, accuracy: 0.01)
    }

    func testBelowVelocityFloorReturnsOffsetUnchanged() {
        XCTAssertEqual(Projection.target(offset: 100, velocity: 0.005, lnRate: lnRate),
                       100, accuracy: 1e-9)
    }
}
