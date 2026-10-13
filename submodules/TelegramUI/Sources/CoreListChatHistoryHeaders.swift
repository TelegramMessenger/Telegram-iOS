import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import CoreList
import ComponentFlow
import ComponentDisplayAdapters
import TelegramPresentationData
import ChatMessageItem
import ChatMessageItemImpl

// Adapts a ListViewItemHeader onto CoreList's attachment feature.
//
// The mapping is near-exact rather than a translation, because CoreList's attachment solve
// (AttachmentOffsetMap) IS ListViewImpl.updateItemHeaders' math — same two clamp cases in the same
// order, with the degenerate-band comment citing Display/Source/ListView.swift:4019 and :4032.
// CoreListAttachedItem.combines(with:) exists because of ChatMessageAvatarHeader's 10-minute rule.
//
// Architecture and deferred items: docs/chat/corelist-chat-history-backend.md
final class CoreListHeaderAttachedItem: CoreListAttachedItem {
    let header: ListViewItemHeader
    // Weak, and read at `view()` time rather than stored as a value: a view is created whenever a run
    // enters the loaded window, which happens during a scroll rebalance long after this descriptor
    // was built. Only the backend knows whether headers are flashing RIGHT NOW.
    private weak var backend: CoreListChatHistoryBackend?

    // The chat's horizontal insets, laid out against by the header node rather than applied by framing
    // the attachment — the attachment-side half of the same decision, see `coreListInsets`.
    let leftInset: CGFloat
    let rightInset: CGFloat

    init(header: ListViewItemHeader, backend: CoreListChatHistoryBackend?, leftInset: CGFloat, rightInset: CGFloat) {
        self.header = header
        self.backend = backend
        self.leftInset = leftInset
        self.rightInset = rightInset
    }

    // Chat rows already reserve the header's height in their own layout insets
    // (`layoutConstants.timestampHeaderHeight` folded into `layoutInsets.top` — see
    // ChatMessageBubbleItemNode.swift:3742 and its four sibling item nodes), so the attachment
    // overlays a gap it was already given. `.reservesSpace` would double it.
    var placement: CoreListAttachmentPlacement {
        return .overlay
    }

    // A direct mapping, not a flip. ListViewImpl(rotated: true) and CoreVirtualListView both lay
    // index 0 at their own top and let the chat wrapper's π put it at the screen bottom, and
    // ChatMessageDateHeader/ChatMessageAvatarHeader already resolve stickDirection against
    // controllerInteraction.chatIsRotated. `.topEdge` is unreachable from chat — no chat header
    // declares it — and `.top` is its nearest meaning.
    var edge: CoreListAttachmentEdge {
        switch self.header.stickDirection {
        case .top, .topEdge:
            return .top
        case .bottom:
            return .bottom
        }
    }

    var isFloating: Bool {
        return self.header.isSticky
    }

    // `ChatMessageDateHeader` is `true` (ChatMessageDateHeader.swift:96) and `ChatMessageAvatarHeader`
    // is `false` (:928) — so only the gutter avatar trims, which is right: the avatar's run has
    // already reserved its own 34pt inside each member row's `layoutInsets.top`, and without the trim
    // it rides that far into the NEXT sender's run before being pushed out.
    var spansMemberInsets: Bool {
        return self.header.stickOverInsets
    }

    // `7.0 + 20.0` from Display/Source/ListView.swift:4047 — the gap plus the date pill's visual
    // height inside its 34pt band. A chat visual fact, so it stays on this side; CoreList never
    // learns it.
    private static let stackingGap: CGFloat = 27.0

    // The header's own space IS the group. In a monoforum two spaces coexist: the date pill is
    // space 2, keyed on a rounded timestamp, and the topic header is space 3, keyed on the
    // separableThreadId with the timestamp zeroed (ChatMessageDateHeader.swift:80-88). A tag rather
    // than a type — see CoreListAttachedItem.
    var stackingGroup: AnyHashable? {
        return AnyHashable(self.header.id.space)
    }

    // `stackingId` means "I coexist with the header for this space and must not overlap it".
    var stackingYield: (group: AnyHashable, gap: CGFloat)? {
        guard let stackingId = self.header.stackingId else {
            return nil
        }
        return (group: AnyHashable(stackingId.space), gap: Self.stackingGap)
    }

    // The flashing state must be seeded HERE, from the backend's live value.
    //
    // `setHeadersFlashing` pushes only on a CHANGE, so a view created while the flag is already true
    // — which is exactly what happens as new date runs stream in during a fling — would otherwise
    // never receive it and would seed its node from its own default `false`. Within that same frame
    // `renderAttachments` then delivers the first stick distance; if the run arrives already parked,
    // the factor crosses 0.5 and `updateFlashing` computes `false || false` and hides the pill. It
    // reappears only on the next flag flip, i.e. the user's next drag.
    func view() -> UIView & CoreListAttachedItemView {
        return CoreListHeaderHostView(header: self.header,
                                      isFlashingOnScrolling: self.backend?.isFlashingHeaders ?? false,
                                      leftInset: self.leftInset,
                                      rightInset: self.rightInset,
                                      backend: self.backend)
    }

    // Content equality, NOT instance equality. Chat rebuilds its header instances on every
    // transaction, so `===` would reconcile and re-measure every visible attachment on every pass.
    // These are the fields the header's own `updateNode` pushes into the node — nothing else can
    // change what the node renders.
    func isEqual(to other: CoreListAttachedItem) -> Bool {
        guard let other = other as? CoreListHeaderAttachedItem else {
            return false
        }
        if other.header.id != self.header.id {
            return false
        }
        // The node lays itself out against these, so a change is a content change. Checked before the
        // per-type comparisons below, each of which returns.
        if other.leftInset != self.leftInset || other.rightInset != self.rightInset {
            return false
        }
        if let lhs = self.header as? ChatMessageDateHeader,
           let rhs = other.header as? ChatMessageDateHeader {
            return lhs.presentationData === rhs.presentationData
        }
        if let lhs = self.header as? ChatMessageAvatarHeader,
           let rhs = other.header as? ChatMessageAvatarHeader {
            return lhs.presentationData === rhs.presentationData
                && lhs.peer?.id == rhs.peer?.id
                && lhs.storyStats == rhs.storyStats
        }
        // An unrecognised header type reconciles every pass rather than going stale.
        return false
    }

    func apply(to view: UIView & CoreListAttachedItemView, transition: CoreListTransition) {
        (view as? CoreListHeaderHostView)?.setHeader(self.header,
                                                     leftInset: self.leftInset,
                                                     rightInset: self.rightInset)
    }

    // The reason CoreListAttachedItem has this at all: ChatMessageAvatarHeader folds its day bucket
    // into its id and STILL needs "break the run if these two are ≥10 minutes apart", which is a
    // delta between neighbours that no key can express.
    func combines(with other: CoreListAttachedItem) -> Bool {
        guard let other = other as? CoreListHeaderAttachedItem else {
            return false
        }
        return self.header.combinesWith(other: other.header)
    }
}

// Hosts a ListViewItemHeaderNode inside CoreVirtualListView's attachment container. The
// attachment-side sibling of CoreListNodeHostView.
final class CoreListHeaderHostView: UIView, CoreListAttachedItemView {
    private(set) var header: ListViewItemHeader
    private(set) var headerNode: ListViewItemHeaderNode?
    private var appliedStickDistance: CGFloat?
    private var isFlashingOnScrolling = false
    private var leftInset: CGFloat
    private var rightInset: CGFloat

    var onContentDidChange: ((_ animated: Bool) -> Void)? = nil

    // Held only to read `prefersSynchronousResourceLoading` at node-build time. Weak, like the
    // reference on `CoreListHeaderAttachedItem` above and for the same reason.
    private weak var backend: CoreListChatHistoryBackend?

    init(header: ListViewItemHeader, isFlashingOnScrolling: Bool, leftInset: CGFloat, rightInset: CGFloat, backend: CoreListChatHistoryBackend?) {
        self.header = header
        self.isFlashingOnScrolling = isFlashingOnScrolling
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.backend = backend
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // A strict PASSTHROUGH, for the same reason `AttachmentContainerView` is one: this host spans the
    // full content width (`update` frames the node at `width` × `header.height`) and floats above the
    // rows, so anything it claims and does not use is a touch a message bubble never sees.
    //
    // Delegating to the node's `hitTest` — not its `point(inside:)` — is the load-bearing part. The
    // node's view is full-width too, so its `point(inside:)` is true across the whole band; only
    // `hitTest` knows where the interactive content actually is, and both chat header nodes implement
    // exactly that. `ChatMessageDateHeaderNode` returns its view only inside the date/peer pill's
    // `backgroundNode.frame` and `nil` everywhere else, and `ChatMessageAvatarHeaderNode` forwards to
    // its `containerNode`, so a tap beside the pill or beside a gutter avatar belongs to the bubble
    // underneath. Testing `point(inside:)` one level down would reproduce the bug one level down.
    //
    // Overriding `point(inside:)` rather than `hitTest` is deliberate: `AttachmentContainerView`
    // decides whether to claim a point by asking each attachment's `point(inside:)`, so that is the
    // question this view has to answer correctly. `hitTest` then composes for free — UIKit's default
    // implementation recurses into the node view, whose own `hitTest` returns the right target.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard let nodeView = self.headerNode?.view else {
            return false
        }
        return nodeView.hitTest(self.convert(point, to: nodeView), with: event) != nil
    }

    func setHeader(_ header: ListViewItemHeader, leftInset: CGFloat, rightInset: CGFloat) {
        self.header = header
        self.leftInset = leftInset
        self.rightInset = rightInset
    }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        let headerNode: ListViewItemHeaderNode
        if let existing = self.headerNode {
            headerNode = existing
        } else {
            // The header half of the same pass-scoped question the row half asks — see
            // `CoreListChatHistoryBackend.prefersSynchronousResourceLoading`. `ChatMessageAvatarHeader`
            // forwards it into `AvatarNode.setPeer(..., synchronousLoad:)`
            // (ChatMessageDateHeader.swift:944, :1025), so hard-coding `true` decoded a gutter avatar
            // on the main thread for every sender run that scrolled in.
            headerNode = self.header.node(synchronousLoad: self.backend?.prefersSynchronousResourceLoading ?? false)
            self.headerNode = headerNode
            self.addSubview(headerNode.view)
            // ListViewImpl seeds a new header node the same way
            // (Display/Source/ListView.swift:4162). `isFlashingOnScrolling` came from the backend's
            // live value at `view()` time, so a header built mid-fling starts out correctly flashed
            // rather than hiding itself the moment its first stick distance crosses 0.5.
            headerNode.updateFlashingOnScrolling(self.isFlashingOnScrolling, animated: false)
        }

        // ListViewImpl's own guard (Display/Source/ListView.swift:4137 and :4158): push the new
        // descriptor into the node exactly when the instance changed.
        if headerNode.item !== self.header {
            self.header.updateNode(headerNode, previous: nil, next: nil)
            headerNode.item = self.header
        }

        // The node carries its own π when the chat is rotated, exactly as item nodes do, so it
        // counter-rotates inside this host and composes to upright content. Assigning `frame` on a
        // π-rotated node is what ListViewImpl does too (:4098) — the rotation preserves the bounding
        // box.
        let size = CGSize(width: width, height: self.header.height)
        headerNode.frame = CGRect(origin: CGPoint(), size: size)

        // Full width plus the real insets, as ListViewImpl hands header nodes
        // (Display/Source/ListView.swift:4098) — the attachment-side half of `coreListInsets`. The
        // avatar's `leftInset + 7.0` then lands on the screen side the chat named, because the inset is
        // applied inside a node carrying its own π; and the date pill centres in the same band
        // ListViewImpl centres it in.
        headerNode.updateLayoutInternal(
            size: size,
            leftInset: self.leftInset,
            rightInset: self.rightInset,
            transition: ComponentTransition(transition).containedViewLayoutTransition
        )
        return size.height
    }

    // CoreList delivers points; ListViewImpl's header nodes take a 0…1 factor AND the raw distance.
    // The clamp is `max(0.0, min(1.0, distance / height))` verbatim from
    // Display/Source/ListView.swift:4024 — it lives here rather than in the engine because the
    // consumer is the side that knows its own height, and because the raw value is meaningful too
    // (a band shorter than its attachment reports a negative distance).
    //
    // `.immediate` matches ListViewImpl, whose scroll-driven updateItemHeaders calls pass the
    // default immediate transition.
    func stickDistanceUpdated(_ distance: CGFloat) {
        guard let headerNode = self.headerNode else {
            return
        }
        if let applied = self.appliedStickDistance, applied == distance {
            return
        }
        self.appliedStickDistance = distance
        let height = self.header.height
        let factor = height > 0.0 ? max(0.0, min(1.0, distance / height)) : 0.0
        headerNode.updateStickDistanceFactor(factor, distance: distance, transition: .immediate)
    }

    // The flag is stored even when no node exists yet, because `update(width:transition:)` seeds a
    // freshly built node from it. Both halves are needed: the backend pushes at transaction end
    // (which a view created during that pass receives), while a view created mid-scroll gets nothing
    // — `setHeadersFlashing` only pushes on a CHANGE, and the flag stays true throughout a scroll.
    func updateFlashingOnScrolling(_ isFlashing: Bool, animated: Bool) {
        guard self.isFlashingOnScrolling != isFlashing else {
            return
        }
        self.isFlashingOnScrolling = isFlashing
        self.headerNode?.updateFlashingOnScrolling(isFlashing, animated: animated)
    }
}

extension CoreListChatHistoryBackend {
    // The live header nodes, in the settled window's attachment order.
    //
    // `loadedAttachmentViews` is CoreList's own live set — a departed run is carried by the fade-out
    // path and never appears there — so this needs no liveness guard of its own. Same argument
    // `itemNodes` makes for rows.
    var itemHeaderNodes: some Sequence<ListViewItemHeaderNode> {
        return self.coreList.loadedAttachmentViews.lazy.compactMap {
            ($0 as? CoreListHeaderHostView)?.headerNode
        }
    }

    // Entering selection mode shifts bubbles right by 42pt and the gutter avatars must follow. The
    // backend contributes NOTHING to that beyond the set above, which its `forEachItemHeaderNode`
    // exposes:
    //
    // - Live nodes are pushed by the app. `ChatController.updateItemNodesSelectionStates`
    //   (ChatController.swift:8382) walks `historyNode.forEachItemHeaderNode` and calls
    //   `updateSelectionState(animated:)` itself, backend-agnostically.
    // - A node built later seeds itself: `ChatMessageAvatarHeaderNodeImpl.init` ends with
    //   `updateSelectionState(animated: false)`, and the node reads
    //   `controllerInteraction.selectionState` directly.
    //
    // ListViewImpl's `attachedHeaderNodes` route (deferred here) is NOT the animated toggle: its
    // `attachedHeaderNodesUpdated` push is `animated: false` (ChatMessageItemView.swift:924), i.e.
    // the same seeding job `init` already does.
    //
    // What that leaves out, and the one thing to know before adding a caller: an ALREADY-BUILT node
    // is corrected only by the app's push. ListViewImpl's walk re-fires as rows scroll, so it would
    // eventually re-seed a node a missed push had left stale; nothing here does. That is safe only
    // because `controllerInteraction.selectionState` is assigned in exactly one place
    // (UpdateChatPresentationInterfaceState.swift:585), which pushes on the next line. A second
    // assignment site must push too — it cannot rely on the list to notice.
    //
    // A backend-side re-push is therefore not merely redundant, it is destructive, and this is the
    // one place that records why. `updateSelectionState` animates the `"sublayerTransform"` keyPath,
    // and `CALayer.animate` keys the animation BY its keyPath (CAAnimationUtils.swift:248), so a
    // second call lands on `add(_:forKey:)` with the first still in flight and replaces it. The
    // second caller computes `from == to` — the offset is already applied — so what replaces the
    // 0→42 glide is a degenerate 42→42 animation, and the avatar snaps. That was a real regression
    // here, in both directions, while the bubbles beside it animated correctly.

    // The avatar's long-press context menu is a ContextControllerSourceNode inside the header node,
    // so starting a scroll must cancel it exactly as it does for a bubble's. Nothing more is needed:
    // `attachmentContainer` is a subview of `engine.contentHost`
    // (CoreVirtualListView.swift:677), so it already sits inside the
    // PhysicsScrollEngine.gestureRecognizer(_:shouldBeRequiredToFailBy:) gate that makes
    // press-and-hold recognize at all under this list.
    func cancelAttachmentContextGestures() {
        func cancelContextGestures(view: UIView) {
            if let gestureRecognizers = view.gestureRecognizers {
                for gesture in gestureRecognizers {
                    if let gesture = gesture as? ContextGesture {
                        gesture.cancel()
                    }
                }
            }
            for subview in view.subviews {
                cancelContextGestures(view: subview)
            }
        }
        for view in self.coreList.loadedAttachmentViews {
            cancelContextGestures(view: view)
        }
    }

    // Parity with ListViewImpl's `scroller.isDragging || isDeceleratingAfterTracking ||
    // flashNodesDelayTimer != nil` (Display/Source/ListView.swift:859).
    //
    // This is NOT cosmetic and NOT separable from the stick distance. The date pill's alpha is
    // `flashingOnScrolling || stickDistanceFactor < 0.5` (ChatMessageDateHeader.swift,
    // updateFlashing), so a backend that reports the factor without this would hide the pill for
    // exactly as long as it is parked at the display edge.
    //
    // No new CoreList seam is needed: onVisibleWindowChanged is the engine.onScroll sink and
    // therefore ticks through momentum as well as dragging, so "no content movement for 0.3s" is the
    // same predicate ListViewImpl's timer expresses with the drag and deceleration terms folded in.
    func noteHeaderFlashingActivity() {
        self.headerFlashTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
            guard let self else {
                return
            }
            self.headerFlashTimer = nil
            self.setHeadersFlashing(false, animated: true)
        }, queue: Queue.mainQueue())
        self.headerFlashTimer = timer
        timer.start()
        self.setHeadersFlashing(true, animated: true)
    }

    func setHeadersFlashing(_ flashing: Bool, animated: Bool) {
        guard self.isFlashingHeaders != flashing else {
            return
        }
        self.isFlashingHeaders = flashing
        self.pushHeaderFlashingState(animated: animated)
    }

    // Also called at transaction end, un-animated: a header view built during that pass has just
    // been seeded with this backend's flag, but one that already existed needs the current value
    // pushed to it.
    func pushHeaderFlashingState(animated: Bool) {
        for view in self.coreList.loadedAttachmentViews {
            (view as? CoreListHeaderHostView)?.updateFlashingOnScrolling(self.isFlashingHeaders,
                                                                         animated: animated)
        }
    }
}
