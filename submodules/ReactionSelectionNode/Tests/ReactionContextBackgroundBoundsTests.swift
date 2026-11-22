import XCTest
import CoreGraphics
import ReactionContextGeometry

final class ReactionContextBackgroundBoundsTests: XCTestCase {
    private let largeCircleSize: CGFloat = 16.0
    private let smallCircleSize: CGFloat = 8.0

    // The tail's circles as `ReactionContextBackgroundNode.update` places them for a panel that is not left-aligned.
    private func contentBounds(panelSize: CGSize, cloudSourcePoint: CGFloat, displayTail: Bool) -> CGRect {
        let largeCircleFrame = CGRect(origin: CGPoint(x: cloudSourcePoint - floor(self.largeCircleSize / 2.0), y: panelSize.height - self.largeCircleSize / 2.0), size: CGSize(width: self.largeCircleSize, height: self.largeCircleSize))
        let smallCircleFrame = CGRect(origin: CGPoint(x: largeCircleFrame.minX + 3.0 - self.smallCircleSize, y: largeCircleFrame.maxY + 2.0), size: CGSize(width: self.smallCircleSize, height: self.smallCircleSize))
        return reactionContextBackgroundContentBounds(backgroundFrame: CGRect(origin: CGPoint(), size: panelSize), largeCircleFrame: largeCircleFrame, smallCircleFrame: smallCircleFrame, displayTail: displayTail)
    }

    // iPhone Duo, unfolded landscape: the story's 324pt card centres the 300pt picker at x 12, while the hidden tail is
    // anchored at the end of the input row, which is wider than the card (cloud source 396 in the card, 384 in the
    // panel). The glass must keep to the panel, not reach out to the hidden circles.
    func testHiddenTailPastThePanelDoesNotWidenIt() {
        let bounds = self.contentBounds(panelSize: CGSize(width: 300.0, height: 76.0), cloudSourcePoint: 384.0, displayTail: false)
        XCTAssertEqual(bounds.minX, -10.0)
        XCTAssertEqual(bounds.width, 320.0)
        // The hidden circles still give the height they always did (the glass takes 8pt off it again).
        XCTAssertEqual(bounds.minY, -10.0)
        XCTAssertEqual(bounds.maxY, 76.0 + 18.0)
    }

    // A visible tail is drawn where it points, so the background still covers it.
    func testVisibleTailPastThePanelWidensIt() {
        let bounds = self.contentBounds(panelSize: CGSize(width: 300.0, height: 76.0), cloudSourcePoint: 384.0, displayTail: true)
        XCTAssertEqual(bounds.maxX, 384.0 + 8.0)
    }

    // A phone's story (iPhone 16 Pro Max, 440pt): the 356pt picker centred, the hidden tail inside it at 354. Nothing
    // changes from the union of the panel and the circles.
    func testHiddenTailInsideThePanelKeepsTheUnion() {
        let panelSize = CGSize(width: 356.0, height: 76.0)
        let hidden = self.contentBounds(panelSize: panelSize, cloudSourcePoint: 354.0, displayTail: false)
        let visible = self.contentBounds(panelSize: panelSize, cloudSourcePoint: 354.0, displayTail: true)
        XCTAssertEqual(hidden, visible)
        XCTAssertEqual(hidden, CGRect(x: -10.0, y: -10.0, width: 376.0, height: 104.0))
    }
}
