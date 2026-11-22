import Foundation
import UIKit
import XCTest
@testable import TelegramCallsUI

/// Pins where a participant's context menu puts its item back while dismissing: an item of the main list (rows, and
/// video tiles when there is no separate video column) returns beneath the list's bottom shadow, as it rests, so the
/// shadow never blinks off over it; an item drawn above the shadow (the separate video column) keeps the menu's
/// default path.
final class VideoChatParticipantsContextMenuTransitionTests: XCTestCase {
    private func topLevelIndex(of view: UIView, in root: UIView) -> Int? {
        var current: UIView? = view
        while let candidate = current, candidate.superview !== root {
            current = candidate.superview
        }
        guard let current else {
            return nil
        }
        return root.subviews.firstIndex(of: current)
    }
    
    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                result.append(scrollView)
            }
            result.append(contentsOf: self.scrollViews(in: subview))
        }
        return result
    }
    
    func testMainListItemsReturnBeneathTheBottomShadow() throws {
        let view = VideoChatParticipantsComponent.View(frame: CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0))
        let shadowIndex = try XCTUnwrap(view.subviews.firstIndex(of: view.scrollViewBottomShadowView))
        
        let scrollViews = self.scrollViews(in: view)
        XCTAssertEqual(scrollViews.count, 2, "the main list and the separate video column; a new scroll view needs its side of the shadow pinned here")
        
        var checkedBeneath = 0
        var checkedAbove = 0
        for scrollView in scrollViews {
            let item = UIView()
            scrollView.addSubview(item)
            let scrollIndex = try XCTUnwrap(self.topLevelIndex(of: scrollView, in: view))
            
            if scrollIndex < shadowIndex {
                let surface = try XCTUnwrap(view.contextMenuTransitionSurface(for: item))
                let surfaceIndex = try XCTUnwrap(view.subviews.firstIndex(of: surface))
                XCTAssertGreaterThan(surfaceIndex, scrollIndex, "the returning item must draw over the list it returns to")
                XCTAssertLessThan(surfaceIndex, shadowIndex, "the returning item must draw beneath the bottom shadow")
                XCTAssertFalse(surface.clipsToBounds, "clipping would also clip the menu's portal mirror of the item")
                XCTAssertFalse(surface.isUserInteractionEnabled)
                checkedBeneath += 1
            } else {
                XCTAssertNil(view.contextMenuTransitionSurface(for: item))
                checkedAbove += 1
            }
        }
        XCTAssertEqual(checkedBeneath, 1)
        XCTAssertEqual(checkedAbove, 1)
    }
    
    func testItemNoLongerInTheListKeepsTheDefaultPath() {
        let view = VideoChatParticipantsComponent.View(frame: CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0))
        XCTAssertNil(view.contextMenuTransitionSurface(for: UIView()))
    }
}
