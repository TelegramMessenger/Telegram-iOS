import XCTest
import UIKit
import SwiftSignalKit
import Display

/// A row's visibility (`ListViewItemNode.visibility`) in a list whose top inset is room the rows scroll into, as the
/// vertical inline results list's (TelegramUI's `VerticalListContextResultsChatInputContextPanelNode`): it places its first
/// row low with a large top inset, and a widget result's preview runs only while its row is visible. Visibility ends at
/// the list's insets unless `visibilityIgnoresTopInset` is set, which zeroes the top of the rect the list computes from
/// its applied insets (so it cannot run ahead of them, as a separate visual inset written before a deferred transaction
/// did; by construction, not tested here). The bottom inset still ends it: behind it is the keyboard.
///
/// Here, not in `DisplayTests`, because `ListViewImpl` needs a host app: its display link is nil in a hostless test
/// process and its init traps.
final class ListViewVisibilityTests: XCTestCase {
    private final class FixedHeightItem: ListViewItem {
        let height: CGFloat

        init(height: CGFloat) {
            self.height = height
        }

        var neighborDescriptor: AnyEquatable {
            return .noNeighborInfluence
        }

        func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
            let node = ListViewItemNode(layerBacked: false)
            node.contentSize = CGSize(width: params.width, height: self.height)
            node.insets = UIEdgeInsets()
            completion(node, {
                return (nil, { _ in })
            })
        }

        func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
            completion(ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: self.height), insets: UIEdgeInsets()), { _ in })
        }
    }

    private let size = CGSize(width: 400.0, height: 800.0)
    private let topInset: CGFloat = 400.0

    /// Ten 100 pt rows under a 400 pt top inset, scrolled `scroll` pt up (300: rows 0-2 lie in the top inset's room,
    /// 100…400), with `bottomInset` at the bottom.
    private func makeScrolledList(ignoringTopInset: Bool, bottomInset: CGFloat = 0.0, scroll: CGFloat = 300.0) -> ListViewImpl {
        let listView = ListViewImpl()
        listView.frame = CGRect(origin: CGPoint(), size: self.size)
        if ignoringTopInset {
            listView.visibilityIgnoresTopInset = true
        }
        let insertions = (0 ..< 10).map { index in
            ListViewInsertItem(index: index, previousIndex: nil, item: FixedHeightItem(height: 100.0), directionHint: nil)
        }
        listView.transaction(deleteIndices: [], insertIndicesAndItems: insertions, updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: self.size, insets: UIEdgeInsets(top: self.topInset, left: 0.0, bottom: bottomInset, right: 0.0), duration: 0.0, curve: .Default(duration: nil)), updateOpaqueState: nil)
        self.spin()
        listView.scroller.setContentOffset(CGPoint(x: 0.0, y: listView.scroller.contentOffset.y + scroll), animated: false)
        self.spin()
        return listView
    }

    private func spin() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
    }

    /// The rows by their position on screen, top first, with whether each is visible.
    private func rows(_ listView: ListViewImpl) -> [(minY: CGFloat, visible: Bool)] {
        var result: [(minY: CGFloat, visible: Bool)] = []
        listView.forEachItemNode { node in
            guard let node = node as? ListViewItemNode else {
                return
            }
            if case .visible = node.visibility {
                result.append((node.apparentFrame.minY, true))
            } else {
                result.append((node.apparentFrame.minY, false))
            }
        }
        return result.sorted(by: { $0.minY < $1.minY })
    }

    func testARowInTheTopInsetIsNotVisibleByDefault() throws {
        let rows = self.rows(self.makeScrolledList(ignoringTopInset: false))
        let first = try XCTUnwrap(rows.first(where: { $0.minY > 50.0 && $0.minY < 150.0 }), "precondition: no row scrolled to 100: \(rows)")
        XCTAssertFalse(first.visible, "\(rows)")
        let below = try XCTUnwrap(rows.first(where: { $0.minY > 350.0 && $0.minY < 450.0 }), "\(rows)")
        XCTAssertTrue(below.visible, "\(rows)")
    }

    func testARowInTheTopInsetIsVisibleWhenTheListIgnoresTheTopInset() throws {
        let rows = self.rows(self.makeScrolledList(ignoringTopInset: true))
        let first = try XCTUnwrap(rows.first(where: { $0.minY > 50.0 && $0.minY < 150.0 }), "precondition: no row scrolled to 100: \(rows)")
        XCTAssertTrue(first.visible, "\(rows)")
    }

    /// Scrolled 550 pt: the first row lies wholly above the list's top (−150…−50, clear of the edge), the third at 50.
    func testARowAboveTheListIsNotVisibleWhenTheListIgnoresTheTopInset() throws {
        let rows = self.rows(self.makeScrolledList(ignoringTopInset: true, scroll: 550.0))
        let above = rows.filter { $0.minY + 100.0 < 0.0 }
        XCTAssertFalse(above.isEmpty, "precondition: no row wholly above the list's top: \(rows)")
        XCTAssertTrue(above.allSatisfy { !$0.visible }, "a row above the list's top is visible: \(rows)")
        let inRoom = try XCTUnwrap(rows.first(where: { $0.minY > 25.0 && $0.minY < 75.0 }), "\(rows)")
        XCTAssertTrue(inRoom.visible, "\(rows)")
    }

    /// The bottom inset still ends visibility with the flag set (for the inline results, the input panel and the keyboard).
    /// With a 200 pt bottom inset the list's visible area ends at 600: the row at 700 lies wholly in the inset.
    func testTheBottomInsetStillEndsVisibility() throws {
        let rows = self.rows(self.makeScrolledList(ignoringTopInset: true, bottomInset: 200.0))
        let last = try XCTUnwrap(rows.first(where: { $0.minY > 650.0 && $0.minY < 750.0 }), "precondition: no row at 700: \(rows)")
        XCTAssertFalse(last.visible, "a row in the bottom inset is visible: \(rows)")
        let lastVisible = try XCTUnwrap(rows.first(where: { $0.minY > 450.0 && $0.minY < 550.0 }), "\(rows)")
        XCTAssertTrue(lastVisible.visible, "\(rows)")
        let inRoom = try XCTUnwrap(rows.first(where: { $0.minY > 50.0 && $0.minY < 150.0 }), "\(rows)")
        XCTAssertTrue(inRoom.visible, "the flag's top edge with a bottom inset too: \(rows)")
    }
}
