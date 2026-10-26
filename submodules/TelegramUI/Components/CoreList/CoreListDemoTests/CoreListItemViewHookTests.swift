import XCTest
@testable import CoreListDemo

final class CoreListItemViewHookTests: XCTestCase {
    func testFixedHeightItemView_onContentDidChange_isAssignable() {
        let view = FixedHeightItemView(height: 50)
        var fired = false
        view.onContentDidChange = { _ in fired = true }
        view.onContentDidChange?(true)
        XCTAssertTrue(fired)
    }

    func testFixedHeightItemView_onContentDidChange_animatedFlagPropagates() {
        let view = FixedHeightItemView(height: 50)
        var capturedAnimated: Bool?
        view.onContentDidChange = { animated in capturedAnimated = animated }
        view.onContentDidChange?(false)
        XCTAssertEqual(capturedAnimated, false)
    }
}
