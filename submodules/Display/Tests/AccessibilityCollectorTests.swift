import XCTest
import UIKit
import AsyncDisplayKit
import SwiftSignalKit
@testable import Display

/// The ASDK accessibility collector behind `-[_ASDisplayView accessibilityElements]`: node overrides forwarded as-is,
/// invisible subtrees skipped, ListView rows limited to the visible ones, one walk per run loop turn, and the
/// `accessibilityUsesViewElements` opt-out.
final class AccessibilityCollectorTests: XCTestCase {
    private var window: UIWindow!

    override func setUp() {
        super.setUp()
        self.window = UIWindow(frame: CGRect(x: 0.0, y: 0.0, width: 1000.0, height: 1000.0))
        self.window.isHidden = false
    }

    override func tearDown() {
        self.window.isHidden = true
        self.window = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeRoot(frame: CGRect = CGRect(x: 0.0, y: 0.0, width: 400.0, height: 400.0)) -> ASDisplayNode {
        let root = ASDisplayNode()
        root.frame = frame
        self.window.addSubview(root.view)
        return root
    }

    private func labelledNode(_ label: String, frame: CGRect, layerBacked: Bool = false) -> ASDisplayNode {
        let node = ASDisplayNode()
        node.isLayerBacked = layerBacked
        node.frame = frame
        node.isAccessibilityElement = true
        node.accessibilityLabel = label
        return node
    }

    /// The labels VoiceOver would reach from `container`, depth first, following non-element containers.
    private func labels(of container: Any) -> [String] {
        guard let elements = (container as? NSObject)?.accessibilityElements else {
            return []
        }
        var result: [String] = []
        for element in elements {
            guard let object = element as? NSObject else {
                continue
            }
            if object.isAccessibilityElement {
                result.append(object.accessibilityLabel ?? "")
            } else {
                result.append(contentsOf: self.labels(of: object))
            }
        }
        return result
    }

    private func spinRunLoop(_ duration: Double = 0.05) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: duration))
    }

    private func makeListView(rowCount: Int) -> ListViewImpl {
        let listView = ListViewImpl()
        listView.frame = CGRect(x: 0.0, y: 0.0, width: 400.0, height: 300.0)
        self.window.addSubview(listView.view)

        var items: [ListViewInsertItem] = []
        for i in 0 ..< rowCount {
            items.append(ListViewInsertItem(index: i, previousIndex: nil, item: TestRowItem(label: "row \(i)"), directionHint: nil))
        }
        listView.transaction(deleteIndices: [], insertIndicesAndItems: items, updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: CGSize(width: 400.0, height: 300.0), insets: UIEdgeInsets(), duration: 0.0, curve: .Default(duration: nil)), updateOpaqueState: nil)

        let deadline = Date(timeIntervalSinceNow: 5.0)
        while Date() < deadline {
            var count = 0
            listView.forEachItemNode { _ in count += 1 }
            if count > 0 {
                break
            }
            self.spinRunLoop(0.01)
        }
        self.spinRunLoop()
        return listView
    }

    /// Row labels whose frames intersect the list's bounds, in index order.
    private func visibleRowLabels(_ listView: ListViewImpl) -> [String] {
        var rows: [(Int, String)] = []
        listView.forEachItemNode { node in
            guard let itemNode = node as? ListViewItemNode, let index = itemNode.index else {
                return
            }
            if !itemNode.frame.intersection(listView.bounds).isEmpty {
                rows.append((index, itemNode.accessibilityLabel ?? ""))
            }
        }
        return rows.sorted(by: { $0.0 < $1.0 }).map(\.1)
    }

    // MARK: - Tests

    func testNodeOverrideIsForwarded() {
        let a = UIAccessibilityElement(accessibilityContainer: self)
        a.accessibilityLabel = "a"
        let b = UIAccessibilityElement(accessibilityContainer: self)
        b.accessibilityLabel = "b"

        let node = OverridingNode(elements: [b, a])
        node.frame = CGRect(x: 0.0, y: 0.0, width: 100.0, height: 100.0)
        self.window.addSubview(node.view)

        let elements = node.view.accessibilityElements
        XCTAssertEqual(elements?.count, 2)
        XCTAssertTrue(elements?.first as AnyObject === b)
        XCTAssertTrue(elements?.last as AnyObject === a)
    }

    func testHiddenAndTransparentSubnodesExcluded() {
        let root = self.makeRoot()
        root.addSubnode(self.labelledNode("visible", frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 40.0)))

        let hidden = self.labelledNode("hidden", frame: CGRect(x: 0.0, y: 50.0, width: 100.0, height: 40.0))
        hidden.isHidden = true
        root.addSubnode(hidden)

        let transparent = self.labelledNode("transparent", frame: CGRect(x: 0.0, y: 100.0, width: 100.0, height: 40.0))
        transparent.alpha = 0.0
        root.addSubnode(transparent)

        root.addSubnode(self.labelledNode("zero", frame: CGRect(x: 0.0, y: 150.0, width: 0.0, height: 0.0)))

        let hiddenLayerBacked = self.labelledNode("hiddenLayer", frame: CGRect(x: 0.0, y: 200.0, width: 100.0, height: 40.0), layerBacked: true)
        hiddenLayerBacked.isHidden = true
        root.addSubnode(hiddenLayerBacked)

        XCTAssertEqual(self.labels(of: root.view), ["visible"])
    }

    func testOffscreenPagerPageIsExcluded() {
        let root = self.makeRoot(frame: CGRect(x: 0.0, y: 0.0, width: 900.0, height: 400.0))

        let pager = ASDisplayNode()
        pager.frame = CGRect(x: 0.0, y: 0.0, width: 400.0, height: 300.0)
        pager.clipsToBounds = true
        root.addSubnode(pager)

        for i in 0 ..< 2 {
            let page = ASDisplayNode()
            page.frame = CGRect(x: CGFloat(i) * 400.0, y: 0.0, width: 400.0, height: 300.0)
            page.addSubnode(self.labelledNode("page \(i)", frame: CGRect(x: 10.0, y: 10.0, width: 200.0, height: 40.0)))
            pager.addSubnode(page)
        }

        XCTAssertEqual(self.labels(of: root.view), ["page 0"])
    }

    func testListViewExposesOnlyVisibleRows() {
        let listView = self.makeListView(rowCount: 20)

        let expected = self.visibleRowLabels(listView)
        XCTAssertEqual(expected, ["row 0", "row 1", "row 2", "row 3"])
        XCTAssertEqual(self.labels(of: listView.view), expected)
    }

    func testLayerBackedLabelledNodeBecomesElement() {
        let root = self.makeRoot(frame: CGRect(x: 10.0, y: 20.0, width: 300.0, height: 300.0))
        root.addSubnode(self.labelledNode("layer", frame: CGRect(x: 5.0, y: 6.0, width: 50.0, height: 40.0), layerBacked: true))

        let elements = root.view.accessibilityElements ?? []
        XCTAssertEqual(elements.count, 1)
        guard let element = elements.first as? UIAccessibilityElement else {
            XCTFail("expected a UIAccessibilityElement, got \(String(describing: elements.first))")
            return
        }
        XCTAssertEqual(element.accessibilityLabel, "layer")
        let expectedFrame = UIAccessibility.convertToScreenCoordinates(CGRect(x: 5.0, y: 6.0, width: 50.0, height: 40.0), in: root.view)
        XCTAssertEqual(element.accessibilityFrame, expectedFrame)
    }

    func testCacheInvalidatesNextRunLoopTurn() {
        let root = self.makeRoot()
        root.addSubnode(self.labelledNode("first", frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 40.0)))
        XCTAssertEqual(self.labels(of: root.view), ["first"])

        root.addSubnode(self.labelledNode("second", frame: CGRect(x: 0.0, y: 50.0, width: 100.0, height: 40.0)))
        XCTAssertEqual(self.labels(of: root.view), ["first"], "same run loop turn reuses the cached walk")
        XCTAssertEqual(root.view.accessibilityElementCount(), 1)

        self.spinRunLoop()
        XCTAssertEqual(self.labels(of: root.view), ["first", "second"])
        XCTAssertEqual(root.view.accessibilityElementCount(), 2)
    }

    func testOptOutKeepsViewElements() {
        let root = self.makeRoot()
        let child = ASDisplayNode()
        child.frame = CGRect(x: 0.0, y: 0.0, width: 200.0, height: 200.0)
        child.addSubnode(self.labelledNode("inner", frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 40.0)))
        root.addSubnode(child)
        root.accessibilityUsesViewElements = true

        let plain = UIView(frame: root.frame)
        let plainChild = UIView(frame: child.frame)
        plain.addSubview(plainChild)
        self.window.addSubview(plain)

        XCTAssertEqual(root.view.accessibilityElements?.count, plain.accessibilityElements?.count)
        XCTAssertNil(root.view.accessibilityElements)
        // The opt-out covers the subtree, not only the node it is set on.
        XCTAssertEqual(child.view.accessibilityElements?.count, plainChild.accessibilityElements?.count)
        XCTAssertNil(child.view.accessibilityElements)

        root.accessibilityUsesViewElements = false
        self.spinRunLoop()
        XCTAssertEqual(self.labels(of: root.view), ["inner"])
    }

    func testListViewAccessibilityScrollStillForwarded() {
        let listView = self.makeListView(rowCount: 20)
        XCTAssertEqual(self.labels(of: listView.view), ["row 0", "row 1", "row 2", "row 3"])

        XCTAssertTrue(listView.view.accessibilityScroll(.down))
        self.spinRunLoop()

        let after = self.labels(of: listView.view)
        XCTAssertEqual(after, self.visibleRowLabels(listView))
        XCTAssertFalse(after.contains("row 0"))
        XCTAssertTrue(after.contains("row 5"))
    }

    func testPlainUIViewChildrenKept() {
        let root = self.makeRoot()
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 10.0, y: 10.0, width: 100.0, height: 44.0)
        button.isAccessibilityElement = true
        button.accessibilityLabel = "Plain"
        root.view.addSubview(button)

        XCTAssertTrue(self.labels(of: root.view).contains("Plain"))
    }

    func testExplicitlySetElementsAreReturned() {
        let root = self.makeRoot()
        root.addSubnode(self.labelledNode("auto", frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 40.0)))
        let element = UIAccessibilityElement(accessibilityContainer: root.view)
        element.accessibilityLabel = "explicit"
        root.view.accessibilityElements = [element]
        XCTAssertEqual(self.labels(of: root.view), ["explicit"])
        root.view.accessibilityElements = nil
        self.spinRunLoop()
        XCTAssertEqual(self.labels(of: root.view), ["auto"])
    }
}

private final class OverridingNode: ASDisplayNode {
    private let elements: [Any]

    init(elements: [Any]) {
        self.elements = elements
        super.init()
    }

    override var accessibilityElements: [Any]? {
        get {
            return self.elements
        }
        set {
        }
    }
}

private final class TestRowItem: ListViewItem {
    let label: String

    init(label: String) {
        self.label = label
    }

    var neighborDescriptor: AnyEquatable {
        return AnyEquatable.noNeighborInfluence
    }

    func nodeConfiguredForParams(async: @escaping (@escaping () -> Void) -> Void, params: ListViewItemLayoutParams, synchronousLoads: Bool, neighbors: ListViewItemNeighbors, completion: @escaping (ListViewItemNode, @escaping () -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void)) -> Void) {
        let node = ListViewItemNode(layerBacked: false)
        node.isAccessibilityElement = true
        node.accessibilityLabel = self.label
        node.contentSize = CGSize(width: params.width, height: 76.0)
        node.insets = UIEdgeInsets()
        completion(node, {
            return (nil, { _ in })
        })
    }

    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: @escaping () -> ListViewItemNode, params: ListViewItemLayoutParams, neighbors: ListViewItemNeighbors, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping (ListViewItemApply) -> Void) -> Void) {
        completion(ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: 76.0), insets: UIEdgeInsets()), { _ in })
    }

    var approximateHeight: CGFloat {
        return 76.0
    }
}
