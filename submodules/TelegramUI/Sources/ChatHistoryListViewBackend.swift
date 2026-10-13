import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import ChatMessageItemImpl

// A chat-specific abstraction of the list-view backend used by ChatHistoryListNodeImpl.
//
// This is the minimal surface ChatHistoryListNodeImpl actually accesses on its list view — exactly
// the distinct `listView.<member>` accesses in ChatHistoryListNode.swift. It is standalone BY DESIGN:
// it does NOT refine the shared `ListView` protocol even though ~37 members overlap. The duplication
// is intentional (a deliberate design choice) so the chat history surface owns its own contract on
// the path toward an eventual alternative backend.
//
// See docs/superpowers/specs/2026-07-23-chat-history-listview-backend-protocol-design.md
public protocol ChatHistoryListViewBackend: ASDisplayNode {
    // MARK: - Narrow scroll-view accessors (replacing the previously-exposed `scroller: ListViewScroller`).
    var bounces: Bool { get set }
    var contentHeight: CGFloat { get }

    // Hold the newest-message edge displaced `distance` points beyond where it rests, as if a finger
    // were still holding the overscroll open; `0` releases the hold. Its one caller is the
    // overscroll-action landing in ChatHistoryListNode (`endedInteractiveDragging`), which keeps the
    // "you are all caught up" control on screen for a beat and then ramps the displacement back to
    // zero.
    //
    // This used to be spelled `setTopContentInset(_:)`, and the rename is the fix for a bug the raw
    // spelling caused rather than cosmetics. On `ListViewImpl` that name means `scroller.contentInset`
    // — a SECOND inset, zero at rest and independent of the list's own `insets` — so `set(0.0)` is a
    // restore to neutral. `CoreListChatHistoryBackend` reasonably read it as the list's own top inset
    // and wrote `currentInsets.top`, where `set(0.0)` DESTROYS the real inset (in the rotated chat,
    // the input-panel band; `ChatControllerNode.swift:2510`). Every later content-offset read then
    // reported a permanent fake overscroll, so the overscroll control was rebuilt on every emission
    // and never removed — a dead 94pt band at the bottom of the chat that ate touches until the next
    // layout pass. A member named for the raw mechanism invites each backend to pick its own
    // referent; one named for the intent has a single meaning both can implement.
    //
    // Contract: the hold is a DISPLAY displacement, invisible to the list's own inset accounting.
    // `insets` does not change, and `visibleContentOffset()` keeps reporting against the resting
    // edge — so while held it reads `.known(-distance)`, which is what keeps the control alive and
    // sized. Both backends must preserve that or the control disappears the moment it is held.
    //
    // `movesContent` picks which of the two readings of an edge move the caller wants, and both are
    // needed by the SAME caller at different moments:
    //
    // - `false` (engaging, or handing the edge back) — hold the presented position and let the
    //   overscroll re-measure against the new edge. The finger is holding the content still, or a
    //   spring is in flight that should simply retarget.
    // - `true` (the release ramp) — carry the content with the edge. That is what walks it back down
    //   as the hold closes.
    //
    // Getting this wrong is a teleport by the edge's travel, not a subtle error.
    func holdOverscrollAction(distance: CGFloat, movesContent: Bool)

    // Whether this backend can hold the edge open DURING a drag without moving content. It matters
    // because the physics reads the edge before the host ever hears about the release —
    // `PhysicsScrollEngine.launchFlight` integrates its release hand-off and bakes the whole flight
    // inside the pan's `.ended`, and only then fires `didEndDragging` — so a hold applied at release
    // is always one step late, and out of bounds that step is spring-shaped and proportional to the
    // overscroll. Holding from the moment the control fills gives the gesture ONE edge.
    //
    // False on `ListViewImpl`, deliberately: its lever is `scroller.contentInset`, which UIKit
    // answers by moving `contentOffset`, so it cannot move the edge without moving content — and it
    // needs none of this, since `UIScrollView` owns its own bounce and never reads a stale edge.
    var holdsOverscrollActionDuringDrag: Bool { get }

    // The view the backend's scroll pan gesture recognizer is attached to. NOT `self.view`: only
    // `ListViewImpl` happens to put the pan on its own view, and asking a backend for `.view` and
    // assuming the pan is on it is the bug this member exists to make unrepresentable.
    //
    // Two callers, both of which fail SILENTLY on the wrong view — no build error, no exception,
    // just a gesture that never fires:
    //
    // - `ChatControllerNode`'s previewing-mode `hitTest` force-routes the touch by returning this
    //   view. UIKit binds the touch to the returned view and then collects recognizers from it
    //   UPWARD, so an ancestor of the pan excludes the pan from the touch and previewing mode simply
    //   cannot scroll. (Ordinary scrolling is unaffected either way, because normal hit-testing
    //   descends to a row and the pan host is an ancestor of THAT — which is what makes the wrong
    //   answer look correct in every other mode.)
    // - `addContentGestureRecognizer` and the chat's two-touch selection pan attach here so they
    //   arbitrate against the scroll pan. Arbitration is by same-view enumeration, not by UIKit's
    //   general rules: both backends' `gestureRecognizerShouldBegin` scans
    //   `pan.view.gestureRecognizers` for a `minimumNumberOfTouches == 2` pan to defer to
    //   (`Display/Source/ListViewScroller.swift:22`, and its port in `PhysicsScrollEngine`), so a
    //   recognizer parked on an ancestor is invisible to that scan while still receiving touches.
    var scrollGestureHostView: UIView { get }

    // MARK: - Members shared with the `ListView` protocol (signatures copied from ListViewProtocol.swift).
    var scrollEnabled: Bool { get set }
    var preloadPages: Bool { get set }
    var experimentalSnapScrollToItem: Bool { get set }
    var stackFromBottom: Bool { get set }
    var enableExtractedBackgrounds: Bool { get set }
    var autoScrollWhenReordering: Bool { get set }
    var defaultToSynchronousTransactionWhileScrolling: Bool { get set }
    var verticalScrollIndicatorColor: UIColor? { get set }
    var accessibilityPageScrolledString: ((String, String) -> String)? { get set }

    var insets: UIEdgeInsets { get }
    var visibleSize: CGSize { get }
    // One member rather than the raw `trackingOffset`/`beganTrackingAtTopOrigin` pair those two used to
    // be. Its only consumer needs them combined, and as separate members a backend could implement one
    // and stub the other — which is exactly what happened: `CoreListChatHistoryBackend` stubbed both to
    // constants, silently disabling the chat's keyboard-dismissal snap-back rather than failing to build.
    var didInteractivelyDragFromTopOrigin: Bool { get }
    var displayedItemRange: ListViewDisplayedItemRange { get }
    var opaqueTransactionState: Any? { get }

    var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void { get set }
    var visibleContentOffsetChanged: (ListViewVisibleContentOffset, ContainedViewLayoutTransition) -> Void { get set }
    var beganInteractiveDragging: (CGPoint) -> Void { get set }
    var endedInteractiveDragging: (CGPoint) -> Void { get set }
    var didEndScrolling: ((Bool) -> Void)? { get set }
    var didEndScrollingWithOverscroll: (() -> Void)? { get set }
    // Consulted once at each interactive release, with the release velocity, BEFORE the backend decides
    // whether momentum follows; `true` releases the list as if the finger had come to rest, while an
    // overscrolled release still springs back. Pre-existing on `ListViewImpl`
    // (`Display/Source/ListView.swift:266`, and the chat list already installs one), so this is a
    // widening of the contract rather than new behavior on that backend — nothing installs one here
    // unless the CoreList backend is active. See `ChatControllerNode.dismissedInputByCurrentGesture`
    // for the one predicate the chat supplies.
    var shouldStopScrolling: ((CGFloat) -> Bool)? { get set }
    var updateFloatingHeaderOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)? { get set }
    var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? { get set }
    var addContentOffset: ((CGFloat, ListViewItemNode?) -> Void)? { get set }
    var tapped: (() -> Void)? { get set }
    var reorderItem: (Int, Int, Any?) -> Signal<Bool, NoError> { get set }

    // `maintainsUnreadItemAlignment` asks the backend to keep the unread separator pinned to the
    // bottom inset edge across this pass's geometry change — the chat's `enableUnreadAlignment`
    // policy. It is ONE member rather than the measure-then-reapply pair it decomposes into, because
    // the predicate ("is the separator currently pinned?") must be evaluated against the OLD insets
    // and the re-pin applied with the NEW ones. As two members a backend could implement one and
    // stub the other, which is exactly how `trackingOffset`/`beganTrackingAtTopOrigin` silently
    // disabled keyboard-dismissal snap-back until they were collapsed into
    // `didInteractivelyDragFromTopOrigin`.
    //
    // This lived in `ChatHistoryListNodeImpl.updateLayout` and read `itemNode.index`, which is
    // `public internal(set)` to Display and therefore always nil for a hosted node — so under the
    // CoreList backend the whole behavior was dead code with no build error. The nav bar changing
    // height mid-open (a Report Spam bar appearing) is what makes it load-bearing: without the
    // re-pin the separator keeps the position computed against the pre-panel geometry.
    func chatHistoryTransaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        updateIndicesAndItems: [ChatHistoryListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem?,
        additionalScrollDistance: CGFloat,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets?,
        stationaryItemRange: (Int, Int)?,
        customAnimationTransition: ControlledTransition?,
        maintainsUnreadItemAlignment: Bool,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    )

    // A loaded item node's frame in LIST space, or nil when the node is not currently loaded.
    //
    // `ListViewItemNode.frame` is list-space only on `ListViewImpl`. Under a hosting backend the
    // node's view is a subview of its host at (0, 0, width, height), so its own frame is host-local
    // and every chat-layer geometry comparison against it silently reads the wrong space. The nil
    // case is the liveness guard: `ListViewImpl` answers it from `index != nil`, CoreList from
    // absence from the loaded window.
    func itemNodeFrame(_ node: ListViewItemNode) -> CGRect?

    // The header-node twin, and it exists for exactly the same reason: a header node's view is a
    // subview of its attachment host under a hosting backend, so its own frame is `(0, 0, w, h)` and
    // any position read off it is silently zero. `forEachItemHeaderNode` handing out real nodes is
    // what makes this reachable — the enumerator being right does not make the geometry right.
    func itemHeaderNodeFrame(_ node: ListViewItemHeaderNode) -> CGRect?

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void)
    func visibleContentOffset() -> ListViewVisibleContentOffset

    // Both content offsets, sampled together in the SETTLED geometry — where the content will be once
    // whatever is animating finishes.
    //
    // One member rather than the `visibleContentOffset()` / `visibleBottomContentOffset()` pair it
    // replaces, for two reasons. It is a question about the list's STATE, asked while a transaction is
    // being prepared, so the mid-animation position is the wrong instant: on `ListViewImpl` the two
    // coincide (its model IS its presented geometry), but under a hosting backend they diverge by the
    // whole remaining travel of any pass in flight. And the caller COMPARES the two, so sampling them
    // separately lets them describe different instants — the failure the single member makes
    // unrepresentable. The thresholds stay in the chat layer; this only fixes the instant.
    func settledContentOffsets() -> (top: ListViewVisibleContentOffset, bottom: ListViewVisibleContentOffset)

    func transferVelocity(_ velocity: CGFloat)
    func resetScrolledToItem()

    func forEachItemNode(_ f: (ASDisplayNode) -> Void)
    func forEachVisibleItemNode(_ f: (ASDisplayNode) -> Void)
    func enumerateItemNodes(_ f: (ASDisplayNode) -> Bool)
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void)

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve)

    // MARK: - Members NOT in the `ListView` protocol (signatures copied from ListView.swift).
    func updateVisibleItemRange(force: Bool)
    func itemNodeAtIndex(_ index: Int) -> ListViewItemNode?
    func itemNodeRelativeOffset(_ node: ListViewItemNode) -> CGFloat?
    func itemNodeVisibleInsideInsets(_ node: ListViewItemNode) -> Bool
    func isStrictlyScrolledToPinToEdgeItem() -> Bool
    func scrollWithDirection(_ direction: ListViewScrollDirection, distance: CGFloat) -> Bool
    var generalScrollDirectionUpdated: (GeneralScrollDirection) -> Void { get set }
    var getCustomItemDeleteAnimationDuration: ((ListViewItemNode) -> Double?)? { get set }
    var globalIgnoreScrollingEvents: Bool { get set }
}

// Swift protocol requirements cannot carry default parameter values, so — mirroring the
// `public extension ListView { ... }` block in ListViewProtocol.swift — provide the default-argument
// convenience overloads that ChatHistoryListNodeImpl relies on. They forward to the full requirement.
public extension ChatHistoryListViewBackend {
    func chatHistoryTransaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        updateIndicesAndItems: [ChatHistoryListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem? = nil,
        additionalScrollDistance: CGFloat = 0.0,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets? = nil,
        stationaryItemRange: (Int, Int)? = nil,
        customAnimationTransition: ControlledTransition? = nil,
        maintainsUnreadItemAlignment: Bool = false,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void = { _ in }
    ) {
        self.chatHistoryTransaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems,
            updateIndicesAndItems: updateIndicesAndItems,
            options: options,
            scrollToItem: scrollToItem,
            additionalScrollDistance: additionalScrollDistance,
            updateSizeAndInsets: updateSizeAndInsets,
            stationaryItemRange: stationaryItemRange,
            customAnimationTransition: customAnimationTransition,
            maintainsUnreadItemAlignment: maintainsUnreadItemAlignment,
            updateOpaqueState: updateOpaqueState,
            completion: completion
        )
    }

    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool = true, overflow: CGFloat = 0.0, allowIntersection: Bool = false, atTop: Bool = false, curve: ListViewAnimationCurve = .Default(duration: 0.25)) {
        self.ensureItemNodeVisible(node, animated: animated, overflow: overflow, allowIntersection: allowIntersection, atTop: atTop, curve: curve)
    }
}

// Almost all members declared above are already `public` on ListViewImpl. The narrow scroll-view
// accessors bridge to ListViewImpl's `scroller`, keeping the ListViewScroller concrete type off the
// protocol contract.
extension ListViewImpl: ChatHistoryListViewBackend {
    public var bounces: Bool {
        get { self.scroller.bounces }
        set { self.scroller.bounces = newValue }
    }
    public var contentHeight: CGFloat {
        return self.scroller.contentSize.height
    }
    // `scroller.contentInset` is the right lever precisely because it is NOT `self.insets`: UIKit
    // moves `contentOffset` to honour it, `scrollViewDidScroll` carries that through to the item
    // nodes, and the list's own inset accounting — `insets`, the visible-range scans,
    // `visibleContentOffset()` — is untouched. Which is the contract stated on the declaration.
    // `movesContent` is ignored: `scroller.contentInset` cannot express the other mode — UIKit moves
    // `contentOffset` to honour it — which is exactly what `holdsOverscrollActionDuringDrag` reports.
    public func holdOverscrollAction(distance: CGFloat, movesContent: Bool) {
        self.scroller.contentInset = UIEdgeInsets(top: distance, left: 0.0, bottom: 0.0, right: 0.0)
    }

    public var holdsOverscrollActionDuringDrag: Bool { return false }

    // The one backend where the pan and the list share a view: `ListView.swift:526` adds
    // `scroller.panGestureRecognizer` to `self.view`.
    public var scrollGestureHostView: UIView {
        return self.view
    }
    
    public func itemNodeFrame(_ node: ListViewItemNode) -> CGRect? {
        // On ListViewImpl a node's own frame IS list space; `index != nil` is its liveness guard,
        // skipping removed-but-still-animating nodes exactly as its internal scans do.
        guard node.index != nil else {
            return nil
        }
        return node.frame
    }

    public func itemHeaderNodeFrame(_ node: ListViewItemHeaderNode) -> CGRect? {
        // Header nodes are direct subviews of the list here, so their frame is already list space.
        // There is no `index`-style liveness flag on a header node; `forEachItemHeaderNode` only ever
        // hands out live ones, and a caller holding a stale node past that is out of contract.
        return node.frame
    }

    // Settled and presented are the same thing here: `replayOperations` writes final item-node frames
    // immediately and animates the layers additively, so these two reads already return the endpoint.
    // This is the pair the chat used to sample separately, which on this backend is exactly equivalent.
    public func settledContentOffsets() -> (top: ListViewVisibleContentOffset, bottom: ListViewVisibleContentOffset) {
        return (self.visibleContentOffset(), self.visibleBottomContentOffset())
    }

    public func chatHistoryTransaction(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        updateIndicesAndItems: [ChatHistoryListViewUpdateItem],
        options: ListViewDeleteAndInsertOptions,
        scrollToItem: ListViewScrollToItem?,
        additionalScrollDistance: CGFloat,
        updateSizeAndInsets: ListViewUpdateSizeAndInsets?,
        stationaryItemRange: (Int, Int)?,
        customAnimationTransition: ControlledTransition?,
        maintainsUnreadItemAlignment: Bool,
        updateOpaqueState: Any?,
        completion: @escaping (ListViewDisplayedItemRange) -> Void
    ) {
        // Measured against the OLD insets, before the transaction below installs the new ones — this
        // is the code that used to sit in ChatHistoryListNodeImpl.updateLayout, moved here verbatim
        // (including its 6.0, which is ChatUnreadItem's scrollPositioningInsets.bottom). ListViewImpl
        // cannot compose the re-pin into the same pass, so it is re-issued as a second transaction
        // from the completion, exactly as before.
        var postScrollToItem: ListViewScrollToItem?
        if maintainsUnreadItemAlignment, let updateSizeAndInsets, updateSizeAndInsets.insets.bottom != self.insets.bottom {
            self.forEachVisibleItemNode { itemNode in
                if let itemNode = itemNode as? ChatUnreadItemNode, let index = itemNode.index {
                    if abs(itemNode.frame.maxY - (self.visibleSize.height - self.insets.bottom + 6.0)) < 1.0 {
                        postScrollToItem = ListViewScrollToItem(index: index, position: .bottom(0.0), animated: updateSizeAndInsets.duration != 0.0, curve: updateSizeAndInsets.curve, directionHint: .Up)
                    }
                }
            }
        }

        let wrappedCompletion: (ListViewDisplayedItemRange) -> Void
        if let postScrollToItem {
            wrappedCompletion = { [weak self] displayedRange in
                guard let self else {
                    completion(displayedRange)
                    return
                }
                self.transaction(
                    deleteIndices: [],
                    insertIndicesAndItems: [],
                    updateIndicesAndItems: [],
                    options: [.Synchronous, .LowLatency],
                    scrollToItem: postScrollToItem,
                    additionalScrollDistance: 0.0,
                    updateSizeAndInsets: nil,
                    stationaryItemRange: nil,
                    updateOpaqueState: nil,
                    completion: completion
                )
            }
        } else {
            wrappedCompletion = completion
        }

        self.transaction(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems.map { item in
                return ListViewInsertItem(
                    index: item.index,
                    previousIndex: item.previousIndex,
                    item: item.item,
                    directionHint: item.directionHint,
                    forceAnimateInsertion: item.forceAnimateInsertion
                )
            },
            updateIndicesAndItems: updateIndicesAndItems.map { item in
                return ListViewUpdateItem(
                    index: item.index,
                    previousIndex: item.previousIndex,
                    item: item.item,
                    directionHint: item.directionHint
                )
            },
            options: options,
            scrollToItem: scrollToItem,
            additionalScrollDistance: additionalScrollDistance,
            updateSizeAndInsets: updateSizeAndInsets,
            stationaryItemRange: stationaryItemRange,
            customAnimationTransition: customAnimationTransition,
            updateOpaqueState: updateOpaqueState,
            completion: wrappedCompletion
        )
    }
}
