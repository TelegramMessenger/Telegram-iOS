import XCTest
import UIKit
@testable import ChatTitleView

final class ChatTitleGlassPillContentWrapperTests: XCTestCase {
    // The title lays the lent contents out about the wrapper's centre. A navigation transition that resizes the wrapper
    // afterwards (lent at the wide pill a chat header has before its right button, its capsule made at the narrow one)
    // must not leave them centred on the old width: they stood half the difference off the pill until the hand-over and
    // then snapped (issue #88, a forum topic opened from its topic list).
    func testContentsStayCentredWhenTheTransitionResizesTheWrapper() {
        let wrapper = makeChatTitleGlassPillContentWrapper(size: CGSize(width: 312.0, height: 44.0))
        let contents = UIView()
        wrapper.addSubview(contents)
        // The title's layout: the narrow pill's size about the (still wide) wrapper's centre.
        contents.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 252.0, height: 44.0))
        contents.center = CGPoint(x: wrapper.bounds.midX, y: wrapper.bounds.midY)

        // The transition's capsule takes the narrow pill's size.
        wrapper.bounds = CGRect(origin: CGPoint(), size: CGSize(width: 252.0, height: 44.0))
        wrapper.layoutIfNeeded()

        XCTAssertEqual(contents.center, CGPoint(x: 126.0, y: 22.0))
        XCTAssertEqual(contents.bounds.size, CGSize(width: 252.0, height: 44.0))
    }
}
