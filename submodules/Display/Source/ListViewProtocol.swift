import UIKit
import AsyncDisplayKit
import SwiftSignalKit

public protocol ListView: ASDisplayNode {
    // MARK: - Configuration Properties (get/set)
    var scroller: ListViewScroller { get }
    var scrollEnabled: Bool { get set }
    var preloadPages: Bool { get set }
    var rotated: Bool { get set }
    var experimentalSnapScrollToItem: Bool { get set }
    var useMainQueueTransactions: Bool { get set }
    var keepMinimalScrollHeightWithTopInset: CGFloat? { get set }
    var itemNodeHitTest: ((CGPoint) -> Bool)? { get set }
    var stackFromBottom: Bool { get set }
    var limitHitTestToNodes: Bool { get set }
    var keepTopItemOverscrollBackground: ListViewKeepTopItemOverscrollBackground? { get set }
    var allowInsetFixWhileTracking: Bool { get set }
    var visualInsets: UIEdgeInsets? { get set }
    var dynamicVisualInsets: (() -> UIEdgeInsets)? { get set }
    var verticalScrollIndicatorColor: UIColor? { get set }
    var verticalScrollIndicatorFollowsOverscroll: Bool { get set }
    var defaultToSynchronousTransactionWhileScrolling: Bool { get set }
    var enableExtractedBackgrounds: Bool { get set }
    var autoScrollWhenReordering: Bool { get set }
    var reorderedItemHasShadow: Bool { get set }
    var reorderingRequiresLongPress: Bool { get set }
    var tempTopInset: CGFloat { get set }
    var accessibilityPageScrolledString: ((String, String) -> String)? { get set }

    // MARK: - Read-only State Properties
    var insets: UIEdgeInsets { get }
    var visibleSize: CGSize { get }
    var isTracking: Bool { get }
    var trackingOffset: CGFloat { get }
    var beganTrackingAtTopOrigin: Bool { get }
    var isDragging: Bool { get }
    var edgeEffectExtension: CGFloat { get }
    var displayedItemRange: ListViewDisplayedItemRange { get }
    var opaqueTransactionState: Any? { get }

    // MARK: - Callbacks
    var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void { get set }
    var visibleContentOffsetChanged: (ListViewVisibleContentOffset, ContainedViewLayoutTransition) -> Void { get set }
    var visibleBottomContentOffsetChanged: (ListViewVisibleContentOffset) -> Void { get set }
    var beganInteractiveDragging: (CGPoint) -> Void { get set }
    var endedInteractiveDragging: (CGPoint) -> Void { get set }
    var didEndScrolling: ((Bool) -> Void)? { get set }
    var didEndScrollingWithOverscroll: (() -> Void)? { get set }
    var updateFloatingHeaderOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)? { get set }
    var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? { get set }
    var addContentOffset: ((CGFloat, ListViewItemNode?) -> Void)? { get set }
    var shouldStopScrolling: ((CGFloat) -> Bool)? { get set }
    var onContentsUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var onEdgeEffectExtensionUpdated: ((ContainedViewLayoutTransition) -> Void)? { get set }
    var tapped: (() -> Void)? { get set }
    var reorderItem: (Int, Int, Any?) -> Signal<Bool, NoError> { get set }
    var reorderCompleted: (Any?) -> Void { get set }

    // MARK: - Methods
    func transaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ListViewInsertItem],
        updateIndicesAndItems: [ListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem?,
        additionalScrollDistance: CGFloat,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets?,
        stationaryItemRange: (Int, Int)?,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    )

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void)
    func visibleContentOffset() -> ListViewVisibleContentOffset
    func visibleBottomContentOffset() -> ListViewVisibleContentOffset
    func stopScrolling()
    @discardableResult func scrollToOffsetFromTop(_ offset: CGFloat, animated: Bool) -> Bool
    func transferVelocity(_ velocity: CGFloat)
    func resetScrolledToItem()

    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
    func forEachVisibleItemNode(_ f: (ASDisplayNode) -> Void)
    func enumerateItemNodes(_ f: (ASDisplayNode) -> Bool)
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void)
    func forEachAccessoryItemNode(_ f: (ListViewAccessoryItemNode) -> Void)

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve)

    func clearHighlightAnimated(_ animated: Bool)
}

// MARK: - Default Parameter Values
// Swift protocols cannot have default parameter values, so we provide them via extensions.
public extension ListView {
    func transaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ListViewInsertItem],
        updateIndicesAndItems: [ListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem? = nil,
        additionalScrollDistance: CGFloat = 0.0,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets? = nil,
        stationaryItemRange: (Int, Int)? = nil,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void = { _ in }
    ) {
        self.transaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems,
            updateIndicesAndItems: updateIndicesAndItems,
            options: options,
            scrollToItem: scrollToItem,
            additionalScrollDistance: additionalScrollDistance,
            updateSizeAndInsets: updateSizeAndInsets,
            stationaryItemRange: stationaryItemRange,
            updateOpaqueState: updateOpaqueState,
            completion: completion
        )
    }

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool = true, overflow: CGFloat = 0.0, allowIntersection: Bool = false, atTop: Bool = false, curve: ListViewAnimationCurve = .Default(duration: 0.25)) {
        self.ensureItemNodeVisible(node, animated: animated, overflow: overflow, allowIntersection: allowIntersection, atTop: atTop, curve: curve)
    }
}
