import XCTest
import UIKit
@testable import CoreListDemo

/// `CoreVirtualListView.viewportAnimationOffset`: what a pass's viewport animation still adds to the content's
/// `bounds.origin.y`, apart from a flight's. A view riding the content motion mirror (the inline results panel's glass)
/// reads the mirror's whole presented motion and needs this part of it to tell the two apart: a later pass folds the
/// viewport part into its own track, while a flight carries on.
final class ViewportAnimationOffsetTests: XCTestCase {
    private func list() -> CoreVirtualListView {
        let list = CoreVirtualListView(forEmbedding: CGRect(x: 0, y: 0, width: 390, height: 400))
        let items = (0 ..< 30).map { _ in IdentifiableFixedHeightItem(id: UUID(), height: 50) }
        list.applyChanges(items: items, newSize: CGSize(width: 390, height: 400), newInsets: .zero, transition: .immediate)
        return list
    }

    func testNothingRunsAtRest() {
        XCTAssertEqual(self.list().viewportAnimationOffset, 0)
    }

    /// An animated jump moves the content's model at once; its viewport track keeps the content where it was, so at
    /// the start the offset is the whole travel back, as the presented frames say.
    func testAnAnimatedJumpAddsItsTravelBack() throws {
        let list = self.list()
        list.applyChanges(scrollTo: CoreListScrollTarget(index: 6, pointOffset: 0), transition: .linear(duration: 100))
        let row = try XCTUnwrap(list.loadedItemView(at: 6))
        XCTAssertEqual(list.settledFrame(of: row).minY, 0, accuracy: 1e-6, "precondition: the jump's destination")
        XCTAssertEqual(list.viewportAnimationOffset, -300, accuracy: 0.5)
        XCTAssertEqual(list.viewportAnimationOffset, list.settledFrame(of: row).minY - list.presentedFrame(of: row).minY, accuracy: 0.5,
                       "not what the viewport animation adds to the content")
    }

    func testAnImmediateJumpAddsNothing() {
        let list = self.list()
        list.applyChanges(scrollTo: CoreListScrollTarget(index: 6, pointOffset: 0), transition: .linear(duration: 100))
        list.applyChanges(scrollTo: CoreListScrollTarget(index: 2, pointOffset: 0), transition: .immediate)
        XCTAssertEqual(list.viewportAnimationOffset, 0)
    }
}
