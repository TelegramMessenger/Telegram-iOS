import XCTest
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import CoreList
@testable import ListViewItemCoreListHost

/// A row's node that records what its host gave it.
private final class RecordingNode: ListViewItemNode {
    var params: ListViewItemLayoutParams?
    var neighbors: ListViewItemNeighbors?
    var applyCount = 0

    init() {
        super.init(layerBacked: false)
    }
}

/// An item that builds and updates its node synchronously, as the inline results' rows do on the main queue.
private final class RecordingItem: ListViewItem {
    let height: CGFloat
    let insets: UIEdgeInsets

    var neighborDescriptor: AnyEquatable {
        return .noNeighborInfluence
    }

    init(height: CGFloat, insets: UIEdgeInsets = UIEdgeInsets()) {
        self.height = height
        self.insets = insets
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let node = RecordingNode()
        let layout = self.layout(params)
        node.contentSize = layout.contentSize
        node.insets = layout.insets
        completion(node, {
            return (nil, { _ in self.apply(node, params, neighbors) })
        })
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        guard let node = node() as? RecordingNode else {
            return XCTFail("not the item's node")
        }
        completion(self.layout(params), { _ in self.apply(node, params, neighbors) })
    }

    private func layout(_ params: ListViewItemLayoutParams) -> ListViewItemNodeLayout {
        return ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: self.height - self.insets.top - self.insets.bottom), insets: self.insets)
    }

    private func apply(_ node: RecordingNode, _ params: ListViewItemLayoutParams, _ neighbors: ListViewItemNeighbors) {
        node.params = params
        node.neighbors = neighbors
        node.applyCount += 1
    }
}

/// `ListViewItemCoreListItem`: a `ListViewItem` hosted as a CoreList row (the chat's inline bot results list).
final class ListViewItemCoreListHostTests: XCTestCase {
    private func row(_ listItem: ListViewItem, content: Int = 0, neighbors: ListViewItemNeighbors = .none, leftInset: CGFloat = 0.0, rightInset: CGFloat = 0.0) -> ListViewItemCoreListItem {
        return ListViewItemCoreListItem(identity: AnyHashable("row"), content: AnyEquatable(content), listItem: listItem, neighbors: neighbors, leftInset: leftInset, rightInset: rightInset)
    }

    private func node(_ view: UIView & CoreListItemView) throws -> RecordingNode {
        return try XCTUnwrap((view as? ListViewItemCoreListView)?.itemNode as? RecordingNode, "the row built no node")
    }

    func testTheRowIsTheItemsNodeAtItsHeight() throws {
        let view = self.row(RecordingItem(height: 75.0)).view()
        XCTAssertEqual(view.update(width: 300.0, transition: .immediate), 75.0)
        let node = try self.node(view)
        XCTAssertTrue(node.view.superview === view, "the node is not in the row")
        XCTAssertEqual(node.frame, CGRect(x: 0.0, y: 0.0, width: 300.0, height: 75.0))
        XCTAssertEqual(node.params?.width, 300.0)
        XCTAssertEqual(node.applyCount, 1)
    }

    /// As `ListViewImpl` passes them: the side insets as layout params (the row still spans the width), and the
    /// neighbours.
    func testTheSideInsetsAndTheNeighboursReachTheNode() throws {
        let neighbors = ListViewItemNeighbors(previous: .noNeighborInfluence, next: nil)
        let view = self.row(RecordingItem(height: 75.0), neighbors: neighbors, leftInset: 12.0, rightInset: 8.0).view()
        _ = view.update(width: 300.0, transition: .immediate)
        let node = try self.node(view)
        XCTAssertEqual(node.params?.leftInset, 12.0)
        XCTAssertEqual(node.params?.rightInset, 8.0)
        XCTAssertEqual(node.neighbors, neighbors)
        XCTAssertEqual(node.frame.width, 300.0)
    }

    /// A reused row given a changed item lays the same node out again from it (`updateNode`), at its new height.
    func testAChangedItemIsLaidOutAgainInTheSameNode() throws {
        let item = self.row(RecordingItem(height: 75.0))
        let view = item.view()
        _ = view.update(width: 300.0, transition: .immediate)
        let node = try self.node(view)

        let changed = self.row(RecordingItem(height: 120.0), content: 1)
        XCTAssertFalse(changed.isEqual(to: item))
        changed.apply(to: view, transition: .immediate)
        XCTAssertEqual(view.update(width: 300.0, transition: .immediate), 120.0)
        XCTAssertTrue(try self.node(view) === node, "the row built a new node")
        XCTAssertEqual(node.applyCount, 2)
        XCTAssertEqual(node.frame.height, 120.0)
    }

    func testEqualityFollowsContentNeighboursAndInsets() {
        let listItem = RecordingItem(height: 75.0)
        let row = self.row(listItem)
        XCTAssertTrue(row.isEqual(to: self.row(listItem)))
        XCTAssertTrue(row.isEqual(to: self.row(RecordingItem(height: 75.0))), "a new item for the same content is the same row")
        XCTAssertFalse(row.isEqual(to: self.row(listItem, content: 1)))
        XCTAssertFalse(row.isEqual(to: self.row(listItem, neighbors: ListViewItemNeighbors(previous: nil, next: .noNeighborInfluence))))
        XCTAssertFalse(row.isEqual(to: self.row(listItem, leftInset: 4.0)))
        XCTAssertFalse(row.isEqual(to: self.row(listItem, rightInset: 4.0)))
    }

    /// `ListViewImpl`'s visibility: the visible part's overlap with the content box (the row less its insets) over the
    /// box's height, with the visible rect; none when the row is not visible.
    func testTheVisibleRectIsTheNodesVisibility() throws {
        let view = self.row(RecordingItem(height: 75.0, insets: UIEdgeInsets(top: 5.0, left: 0.0, bottom: 5.0, right: 0.0))).view()
        _ = view.update(width: 300.0, transition: .immediate)
        let node = try self.node(view)
        XCTAssertEqual(node.visibility, .none)

        let rect = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 30.0)
        view.visibleRectUpdated(rect)
        XCTAssertEqual(node.visibility, .visible(25.0 / 65.0, rect))
        view.visibleRectUpdated(nil)
        XCTAssertEqual(node.visibility, .none)
    }

    /// A rect that arrives before the node exists reaches it when it is built.
    func testARectBeforeTheNodeReachesIt() throws {
        let view = self.row(RecordingItem(height: 75.0)).view()
        let rect = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 75.0)
        view.visibleRectUpdated(rect)
        _ = view.update(width: 300.0, transition: .immediate)
        XCTAssertEqual(try self.node(view).visibility, .visible(1.0, rect))
    }

    /// In a list whose visible band ends above its bottom (the inline results under the keyboard,
    /// `CoreVirtualListView.visibleRectInsets`): rows wholly past the band are not visible, a row under the list's bottom
    /// inset but inside the band is.
    func testInAListTheBandDecidesWhichNodesAreVisible() throws {
        let list = CoreVirtualListView(forEmbedding: CGRect(x: 0.0, y: 0.0, width: 300.0, height: 400.0))
        list.visibleRectInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 100.0, right: 0.0)
        let items: [CoreListItem] = (0 ..< 6).map { index in
            ListViewItemCoreListItem(identity: AnyHashable(index), content: AnyEquatable(index), listItem: RecordingItem(height: 75.0), neighbors: .none, leftInset: 0.0, rightInset: 0.0)
        }
        // A bottom inset of 150 (the input panel and the keyboard together): row 3 (225...300) is under it, inside the
        // band; row 4 (300...375) is past the band.
        list.applyChanges(items: items, newSize: CGSize(width: 300.0, height: 400.0), newInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: 150.0, right: 0.0), transition: .immediate)

        var visibilities: [Int: ListViewItemNodeVisibility] = [:]
        for (index, view) in list.loadedItemEntries {
            visibilities[index] = (view as? ListViewItemCoreListView)?.itemNode?.visibility
        }
        XCTAssertEqual(visibilities[3], .visible(1.0, CGRect(x: 0.0, y: 0.0, width: 300.0, height: 75.0)), "\(visibilities)")
        XCTAssertEqual(visibilities[4], ListViewItemNodeVisibility.none, "\(visibilities)")
    }
}
