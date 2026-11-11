import Foundation
import UIKit
import XCTest
import AsyncDisplayKit
import Display
import ContextUI

/// Pins who lays out a `PinchSourceContainerNode`'s content node.
///
/// For a pinch the pinch controller moves `contentNode` into its own overlay and positions it there in
/// overlay (screen) coordinates, through the zoom and through the animation back, which also continues
/// after the fingers lift (`isActive` is already false then). A group call re-renders its expanded video
/// tile all the time (speaking state, audio levels); a layout pass that wrote `(0, 0, size)` to the content
/// node meanwhile put it at the screen's top-left, so wherever the tile does not sit at the screen origin (on iPad
/// below the header, on a phone below the status bar) the return animation ran towards the wrong place and the tile
/// snapped into place when the content came home.
///
/// These tests pin the container's side of that contract (`PinchSourceContainerNode` is in ContextUI, which has no
/// test target). The video tile's side, that `VideoChatParticipantVideoComponent` lays the content node out only
/// through `PinchSourceContainerNode.update(size:)`, cannot be tested here: the component needs `PresentationStrings`
/// and a call.
final class VideoChatPinchContentLayoutTests: XCTestCase {
    private let size = CGSize(width: 320.0, height: 180.0)

    func testUpdateLaysOutContentWhileItIsAtHome() {
        let node = PinchSourceContainerNode()
        node.update(size: self.size, transition: .immediate)

        XCTAssertEqual(node.contentNode.frame, CGRect(origin: CGPoint(), size: self.size))
    }

    func testUpdateLeavesContentHeldByPinchOverlayInPlace() {
        let node = PinchSourceContainerNode()
        node.update(size: self.size, transition: .immediate)

        // What `PinchController` does on animate-in and again on animate-out.
        let overlayFrame = CGRect(origin: CGPoint(x: 14.0, y: 92.0), size: self.size)
        let overlayNode = ASDisplayNode()
        overlayNode.addSubnode(node.contentNode)
        node.contentNode.frame = overlayFrame

        XCTAssertFalse(node.isActive)
        node.update(size: self.size, transition: .immediate)

        XCTAssertEqual(node.contentNode.frame, overlayFrame)
    }

    func testContentReturnsHomeWithSizeLaidOutWhileItWasAway() {
        let node = PinchSourceContainerNode()
        node.update(size: self.size, transition: .immediate)

        let overlayNode = ASDisplayNode()
        overlayNode.addSubnode(node.contentNode)
        node.contentNode.frame = CGRect(origin: CGPoint(x: 14.0, y: 92.0), size: self.size)

        let updatedSize = CGSize(width: 400.0, height: 225.0)
        node.update(size: updatedSize, transition: .immediate)

        // What `PinchController` does once the animation back has finished.
        node.restoreToNaturalSize()
        node.addSubnode(node.contentNode)

        XCTAssertEqual(node.contentNode.frame, CGRect(origin: CGPoint(), size: updatedSize))
    }
}
