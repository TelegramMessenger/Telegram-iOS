import XCTest
@testable import CoreListDemo

final class SampleItemsTests: XCTestCase {
    func testIdentifiableFixedHeightItem_sameId_isEqual() {
        let id = UUID()
        let a = IdentifiableFixedHeightItem(id: id, height: 50)
        let b = IdentifiableFixedHeightItem(id: id, height: 60)  // different height!
        XCTAssertTrue(a.isEqual(to: b),
                      "Identifiable items compare by id, not by content")
    }

    func testIdentifiableFixedHeightItem_differentId_isNotEqual() {
        let a = IdentifiableFixedHeightItem(id: UUID(), height: 50)
        let b = IdentifiableFixedHeightItem(id: UUID(), height: 50)
        XCTAssertFalse(a.isEqual(to: b))
    }

    func testSelfUpdatingItem_simulateContentChange_firesHook() {
        let view = SelfUpdatingItemView(initialHeight: 50)
        var captured: Bool?
        view.onContentDidChange = { animated in captured = animated }
        view.simulateContentChange(newHeight: 80, animated: true)
        XCTAssertEqual(captured, true)
        XCTAssertEqual(view.update(width: 100, transition: .immediate), 80, accuracy: 0.001)
    }

    func testSelfUpdatingItem_nonAnimatedFlagPropagates() {
        let view = SelfUpdatingItemView(initialHeight: 50)
        var captured: Bool?
        view.onContentDidChange = { animated in captured = animated }
        view.simulateContentChange(newHeight: 30, animated: false)
        XCTAssertEqual(captured, false)
    }
}
