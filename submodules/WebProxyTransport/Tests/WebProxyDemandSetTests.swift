import XCTest
@testable import WebProxyTransport

final class WebProxyDemandSetTests: XCTestCase {
    func testEmptyByDefault() {
        let demand = WebProxyDemandSet()
        XCTAssertTrue(demand.isEmpty)
    }

    func testFirstLeaseFlipsAndRepeatDoesNot() {
        var demand = WebProxyDemandSet()
        XCTAssertTrue(demand.set("a", wanted: true))
        XCTAssertFalse(demand.isEmpty)
        XCTAssertFalse(demand.set("a", wanted: true))
        XCTAssertFalse(demand.isEmpty)
    }

    func testLastReleaseFlipsAndRepeatDoesNot() {
        var demand = WebProxyDemandSet()
        _ = demand.set("a", wanted: true)
        XCTAssertTrue(demand.set("a", wanted: false))
        XCTAssertTrue(demand.isEmpty)
        XCTAssertFalse(demand.set("a", wanted: false))
        XCTAssertTrue(demand.isEmpty)
    }

    func testSecondHolderKeepsItAliveUntilBothRelease() {
        var demand = WebProxyDemandSet()
        XCTAssertTrue(demand.set("a", wanted: true))
        XCTAssertFalse(demand.set("b", wanted: true))
        XCTAssertFalse(demand.set("a", wanted: false))
        XCTAssertFalse(demand.isEmpty)
        XCTAssertTrue(demand.set("b", wanted: false))
        XCTAssertTrue(demand.isEmpty)
    }

    func testReleasingAnUnknownTokenIsInert() {
        var demand = WebProxyDemandSet()
        _ = demand.set("a", wanted: true)
        XCTAssertFalse(demand.set("never-added", wanted: false))
        XCTAssertFalse(demand.isEmpty)
    }

    func testDistinctTokenTypesDoNotCollide() {
        var demand = WebProxyDemandSet()
        XCTAssertTrue(demand.set(UUID(), wanted: true))
        XCTAssertFalse(demand.set(UUID(), wanted: true))
    }
}
