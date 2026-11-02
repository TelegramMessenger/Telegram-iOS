import XCTest
import UIKit
import AsyncDisplayKit
@testable import Display

/// `CollectionIndexNode` (the contact list's A–Z index) as one adjustable VoiceOver element: swiping up and down
/// selects the next and previous section through `indexSelected`, the path dragging along it takes.
final class CollectionIndexAccessibilityTests: XCTestCase {
    private func makeIndex(sections: [String]) -> (CollectionIndexNode, () -> [String]) {
        let node = CollectionIndexNode()
        var selected: [String] = []
        node.indexSelected = { selected.append($0) }
        node.update(size: CGSize(width: 20.0, height: 600.0), color: .black, sections: sections, transition: .immediate)
        return (node, { selected })
    }

    func testIndexIsOneAdjustableElementShowingTheFirstSection() {
        let (node, _) = self.makeIndex(sections: [CollectionIndexNode.searchIndex, "A", "B", "C"])
        XCTAssertTrue(node.isAccessibilityElement)
        XCTAssertTrue(node.accessibilityTraits.contains(.adjustable))
        XCTAssertEqual(node.accessibilityValue, "A")
    }

    func testIncrementAndDecrementSelectSections() {
        let (node, selected) = self.makeIndex(sections: [CollectionIndexNode.searchIndex, "A", "B", "C"])
        node.accessibilityIncrement()
        node.accessibilityIncrement()
        XCTAssertEqual(node.accessibilityValue, "C")
        node.accessibilityIncrement()
        XCTAssertEqual(node.accessibilityValue, "C")
        node.accessibilityDecrement()
        node.accessibilityDecrement()
        node.accessibilityDecrement()
        XCTAssertEqual(node.accessibilityValue, "A")
        XCTAssertEqual(selected(), ["B", "C", "B", "A"])
    }

    func testEmptyIndexIsNoElement() {
        let (node, _) = self.makeIndex(sections: [])
        XCTAssertFalse(node.isAccessibilityElement)
    }
}
