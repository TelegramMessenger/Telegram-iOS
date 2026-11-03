import XCTest
@testable import CoreListDemo

final class WillBeginDraggingTests: XCTestCase {
    func testInteractiveDragStartFiresWillBeginDragging() {
        let fixture = PhysicsListFixture(itemCount: 50)
        var count = 0
        fixture.listView.willBeginDragging = { count += 1 }

        fixture.engine.beginDrag()
        XCTAssertEqual(count, 1, "an interactive drag start must fire willBeginDragging")

        fixture.engine.beginDrag()
        XCTAssertEqual(count, 2, "each drag start fires it again")
    }

    func testProgrammaticScrollDoesNotFireWillBeginDragging() {
        let fixture = PhysicsListFixture(itemCount: 50)
        var count = 0
        fixture.listView.willBeginDragging = { count += 1 }

        fixture.engine.setOffset(120)
        fixture.engine.applyShift(30)
        XCTAssertEqual(count, 0, "programmatic scroll/shift must not fire willBeginDragging")
    }
}
