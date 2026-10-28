import Foundation
import UIKit
import Display
import AsyncDisplayKit
import LegacyComponents
import Photos
import SparseItemGrid

protocol MediaPickerGridHostItem: AnyObject {
    var identifier: String { get }
    var tag: Int32? { get }
    var selectableItem: TGMediaSelectableItem? { get }

    func transitionView(snapshot: Bool) -> UIView
    func transitionImage() -> UIImage?
    func hideTransitionSource()
    func selectedListTransition() -> (UIView, ASDisplayNode?, (Bool) -> Void)
    func updateHiddenMedia()
    func updateGridSelectionState(animated: Bool)
}

protocol MediaPickerGridHost: AnyObject {
    var view: UIView { get }
    var cameraHostView: UIView { get }
    var headerHostNode: ASDisplayNode { get }
    var fastScrollView: UIScrollView? { get }
    var fastScrollTarget: SparseItemGridScrollingTarget? { get }
    var appliesFastScrollImmediately: Bool { get }
    var consumesEntries: Bool { get }
    var usesPickerSelectionGesture: Bool { get }
    var headerHeight: CGFloat { get set }
    var isContentUnderBar: Bool { get }
    var contentUnderBarChanged: (() -> Void)? { get set }

    var isHidden: Bool { get set }
    var isUserInteractionEnabled: Bool { get set }

    var scrollingInitiated: (() -> Void)? { get set }
    var zoomingStarted: (() -> Void)? { get set }
    var visibleContentOffsetChanged: (GridNodeVisibleContentOffset) -> Void { get set }
    var visibleItemsUpdated: (() -> Void)? { get set }

    var contentInsets: UIEdgeInsets { get }
    var contentHeight: CGFloat { get }
    var contentOffset: CGPoint { get }
    var scrollBounds: CGRect { get }
    var isDragging: Bool { get }
    var isDecelerating: Bool { get }

    func attach(to container: ASDisplayNode)
    func hostDidLoad()
    func updateFrame(_ frame: CGRect, transition: ContainedViewLayoutTransition)
    func updateLayout(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize, itemSpacing: CGFloat, cutouts: [CGRect], hasCamera: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void)
    func apply(_ transaction: MediaPickerGridTransaction)

    func visibleContentOffset() -> GridNodeVisibleContentOffset
    func setContentOffset(_ contentOffset: CGPoint, animated: Bool)
    func scrollToTop(animated: Bool)

    func updateAssets(fetchResult: PHFetchResult<PHAsset>, configuration: MediaPickerGridAssetsConfiguration, extras: [MediaPickerGridExtraItem])
    func updateMedia(_ items: [MediaPickerGridExtraItem])
    func setAccessoryView(_ view: UIView, layout: @escaping (CGSize) -> Void)
    func updateAccessoryFrame(_ view: UIView, frame: CGRect)
    func scrollingTag() -> Int32?
    func isCameraPreviewVisible(_ cameraView: UIView) -> Bool
    func cameraFrame(for rect: CGRect) -> CGRect
    func cameraAccessibilityFrame(for rect: CGRect) -> CGRect
    func updateItemsSelectionState(animated: Bool)
    func updateItemsHiddenMedia()

    func forEachVisibleItem(_ f: (MediaPickerGridHostItem) -> Void)
    func visibleItem(identifier: String) -> MediaPickerGridHostItem?
    func item(at point: CGPoint) -> MediaPickerGridHostItem?
    func defaultTransitionItem() -> MediaPickerGridHostItem?
}

extension MediaPickerGridItemNode: MediaPickerGridHostItem {
    func hideTransitionSource() {
        self.isHidden = true
    }

    func selectedListTransition() -> (UIView, ASDisplayNode?, (Bool) -> Void) {
        return (self.view, self.spoilerNode?.dustNode, { [weak self] animateCheckNode in
            self?.animateFadeIn(animateCheckNode: animateCheckNode, animateSpoilerNode: false)
        })
    }

    func updateGridSelectionState(animated: Bool) {
        self.updateSelectionState(animated: animated)
    }
}

final class MediaPickerGridNodeHost: MediaPickerGridHost {
    let gridNode: GridNode

    init() {
        self.gridNode = GridNode()
    }

    var view: UIView {
        return self.gridNode.view
    }

    var cameraHostView: UIView {
        return self.gridNode.scrollView
    }

    var headerHostNode: ASDisplayNode {
        return self.gridNode
    }

    var fastScrollView: UIScrollView? {
        return self.gridNode.scrollView
    }

    var fastScrollTarget: SparseItemGridScrollingTarget? {
        return nil
    }

    var appliesFastScrollImmediately: Bool {
        return false
    }

    var consumesEntries: Bool {
        return true
    }

    var usesPickerSelectionGesture: Bool {
        return true
    }

    var headerHeight: CGFloat = 0.0
    var contentUnderBarChanged: (() -> Void)?

    var isContentUnderBar: Bool {
        return false
    }

    var isHidden: Bool {
        get {
            return self.gridNode.isHidden
        }
        set {
            self.gridNode.isHidden = newValue
        }
    }

    var isUserInteractionEnabled: Bool {
        get {
            return self.gridNode.isUserInteractionEnabled
        }
        set {
            self.gridNode.isUserInteractionEnabled = newValue
        }
    }

    var isScrollEnabled: Bool {
        get {
            return self.gridNode.scrollView.isScrollEnabled
        }
        set {
            self.gridNode.scrollView.isScrollEnabled = newValue
        }
    }

    var scrollingInitiated: (() -> Void)? {
        get {
            return self.gridNode.scrollingInitiated
        }
        set {
            self.gridNode.scrollingInitiated = newValue
        }
    }

    var zoomingStarted: (() -> Void)?

    var visibleContentOffsetChanged: (GridNodeVisibleContentOffset) -> Void {
        get {
            return self.gridNode.visibleContentOffsetChanged
        }
        set {
            self.gridNode.visibleContentOffsetChanged = newValue
        }
    }

    var visibleItemsUpdated: (() -> Void)? {
        didSet {
            if let visibleItemsUpdated = self.visibleItemsUpdated {
                self.gridNode.visibleItemsUpdated = { _ in
                    visibleItemsUpdated()
                }
            } else {
                self.gridNode.visibleItemsUpdated = nil
            }
        }
    }

    var contentInsets: UIEdgeInsets {
        return self.gridNode.gridLayout.insets
    }

    var contentHeight: CGFloat {
        return self.gridNode.scrollView.contentSize.height
    }

    var contentOffset: CGPoint {
        return self.gridNode.scrollView.contentOffset
    }

    var scrollBounds: CGRect {
        return self.gridNode.scrollView.bounds
    }

    var isDragging: Bool {
        return self.gridNode.scrollView.isDragging
    }

    var isDecelerating: Bool {
        return self.gridNode.scrollView.isDecelerating
    }

    func attach(to container: ASDisplayNode) {
        container.addSubnode(self.gridNode)
    }

    func hostDidLoad() {
        self.gridNode.scrollView.alwaysBounceVertical = true
        self.gridNode.scrollView.showsVerticalScrollIndicator = false
    }

    func updateFrame(_ frame: CGRect, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.gridNode, frame: frame)
    }

    func updateLayout(size: CGSize, insets: UIEdgeInsets, preloadSize: CGFloat, itemSize: CGSize, itemSpacing: CGFloat, cutouts: [CGRect], hasCamera: Bool, transition: ContainedViewLayoutTransition, completion: @escaping () -> Void) {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: [], insertItems: [], updateItems: [], scrollToItem: nil, updateLayout: GridNodeUpdateLayout(layout: GridNodeLayout(size: size, insets: insets, scrollIndicatorInsets: nil, preloadSize: preloadSize, type: .fixed(itemSize: itemSize, fillWidth: true, lineSpacing: itemSpacing, itemSpacing: itemSpacing), cutouts: cutouts), transition: transition), itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil, updateOpaqueState: nil, synchronousLoads: false), completion: { _ in
            completion()
        })
    }

    func apply(_ transaction: MediaPickerGridTransaction) {
        self.gridNode.transaction(GridNodeTransaction(deleteItems: transaction.deletions, insertItems: transaction.insertions, updateItems: transaction.updates, scrollToItem: transaction.scrollToItem, updateLayout: nil, itemTransition: .immediate, stationaryItems: .none, updateFirstIndexInSectionOffset: nil), completion: { _ in })
    }

    func visibleContentOffset() -> GridNodeVisibleContentOffset {
        return self.gridNode.visibleContentOffset()
    }

    func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        self.gridNode.scrollView.setContentOffset(contentOffset, animated: animated)
    }

    func scrollToTop(animated: Bool) {
        self.gridNode.scrollView.setContentOffset(CGPoint(x: 0.0, y: -self.gridNode.scrollView.contentInset.top), animated: animated)
    }

    func updateAssets(fetchResult: PHFetchResult<PHAsset>, configuration: MediaPickerGridAssetsConfiguration, extras: [MediaPickerGridExtraItem]) {
    }

    func updateMedia(_ items: [MediaPickerGridExtraItem]) {
    }

    private var accessoryLayout: ((CGSize) -> Void)?

    func setAccessoryView(_ view: UIView, layout: @escaping (CGSize) -> Void) {
        self.accessoryLayout = layout
        self.gridNode.view.addSubview(view)
    }

    func updateAccessoryFrame(_ view: UIView, frame: CGRect) {
        view.frame = frame
        self.accessoryLayout?(frame.size)
    }

    func scrollingTag() -> Int32? {
        var tag: Int32?
        self.forEachVisibleItem { item in
            tag = item.tag
        }
        return tag
    }

    func isCameraPreviewVisible(_ cameraView: UIView) -> Bool {
        return self.scrollBounds.intersects(cameraView.frame)
    }

    func cameraFrame(for rect: CGRect) -> CGRect {
        return rect
    }

    func cameraAccessibilityFrame(for rect: CGRect) -> CGRect {
        return rect
    }

    func updateItemsSelectionState(animated: Bool) {
        self.forEachVisibleItem { item in
            item.updateGridSelectionState(animated: animated)
        }
    }

    func updateItemsHiddenMedia() {
        self.forEachVisibleItem { item in
            item.updateHiddenMedia()
        }
    }

    func forEachVisibleItem(_ f: (MediaPickerGridHostItem) -> Void) {
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? MediaPickerGridItemNode {
                f(itemNode)
            }
        }
    }

    func visibleItem(identifier: String) -> MediaPickerGridHostItem? {
        var result: MediaPickerGridItemNode?
        self.gridNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? MediaPickerGridItemNode, itemNode.identifier == identifier {
                result = itemNode
            }
        }
        return result
    }

    func item(at point: CGPoint) -> MediaPickerGridHostItem? {
        return self.gridNode.itemNodeAtPoint(point) as? MediaPickerGridItemNode
    }

    func defaultTransitionItem() -> MediaPickerGridHostItem? {
        return self.item(at: .zero)
    }
}
