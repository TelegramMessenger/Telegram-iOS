import UIKit
import AsyncDisplayKit
import SwiftSignalKit
import Display
import CoreList
import ComponentFlow
import ComponentDisplayAdapters
import ChatMessageItem
import ChatMessageItemImpl
import ChatMessageItemView

// Shared by the chat's diamonds; their existing animation clocks advance this spring on demand.
// All inputs are user-scroll deltas in screen coordinates, with downward content movement positive.
private final class CoreListChatScrollMotion {
    var holding = false
    private var pendingDelta: CGFloat = 0.0
    private var reported: CFTimeInterval?
    private var rate: CGFloat = 0.0
    private var stepped: CFTimeInterval?
    private var velocity: CGFloat = 0.0
    private var tiltValue: CGFloat = 0.0
    private var tiltSpeed: CGFloat = 0.0
    private var hold: CGFloat = 0.0

    func report(delta: CGFloat, at time: CFTimeInterval) {
        self.pendingDelta += delta
        guard let reported = self.reported else {
            self.reported = time
            self.pendingDelta = 0.0
            return
        }
        let dt = time - reported
        guard dt > 0.0005 else { return }
        let rate = self.pendingDelta / CGFloat(min(dt, 0.1))
        self.rate += (rate - self.rate) * min(1.0, CGFloat(dt) * 40.0)
        self.pendingDelta = 0.0
        self.reported = time
    }

    func tilt(at time: CFTimeInterval) -> Float {
        if let reported = self.reported, time - reported > 0.06 {
            self.rate = 0.0
        }
        guard let stepped = self.stepped else {
            self.stepped = time
            return Float(self.tiltValue)
        }
        let raw = time - stepped
        guard raw > 0.001 else { return Float(self.tiltValue) }
        self.stepped = time
        if raw > 0.2 {
            // No diamond has sampled us recently. Drop the old oscillation, keeping fresh input.
            self.resetOscillation()
            return 0.0
        }

        let dt = CGFloat(min(raw, 0.05))
        self.hold += ((self.holding ? 1.0 : 0.0) - self.hold) * min(1.0, dt * 8.0)
        self.velocity += (self.rate - self.velocity) * min(1.0, dt * (18.0 - 9.0 * self.hold))
        let target = 0.5 * tanh(self.velocity / 520.0)
        let a = min(max((abs(target) - 0.05) / 0.15, 0.0), 1.0)
        let drive = a * a * (3.0 - 2.0 * a)
        let damping: CGFloat = 0.13 + 0.75 * drive
        let frequency: CGFloat = 2.0 * .pi * (1.25 - 0.2 * drive)
        var remaining = dt
        while remaining > 0.0 {
            let step = min(remaining, 1.0 / 240.0)
            self.tiltSpeed += (frequency * frequency * (target - self.tiltValue) - 2.0 * damping * frequency * self.tiltSpeed) * step
            self.tiltValue += self.tiltSpeed * step
            remaining -= step
        }
        return Float(self.tiltValue)
    }

    func reset() {
        self.holding = false
        self.pendingDelta = 0.0
        self.reported = nil
        self.rate = 0.0
        self.stepped = nil
        self.resetOscillation()
    }

    private func resetOscillation() {
        self.velocity = 0.0
        self.tiltValue = 0.0
        self.tiltSpeed = 0.0
        self.hold = 0.0
    }
}

// CoreList cannot depend on ComponentFlow — its Bazel target has no `deps` and its demo builds
// standalone in Xcode — so it carries a case-for-case copy of the transition value model. This is
// where the two meet.
//
// The one asymmetry is interpretation, not data: CoreList treats a zero duration as immediate, while
// ComponentFlow animates it. That difference is preserved here rather than smoothed over — a
// zero-duration CoreList transition maps to `.immediate`, so a caller converting one and handing it
// to UIKit gets the behavior CoreList meant.
extension ComponentTransition {
    init(_ transition: CoreListTransition) {
        switch transition.animation {
        case .none:
            self.init(animation: .none)
        case let .curve(duration, curve):
            guard !transition.isImmediate else {
                self.init(animation: .none)
                return
            }
            self.init(animation: .curve(duration: duration,
                                        curve: ComponentTransition.Animation.Curve(curve)))
        }
    }
}

private extension ComponentTransition.Animation.Curve {
    init(_ curve: CoreListTransition.Animation.Curve) {
        switch curve {
        case .easeInOut: self = .easeInOut
        case .easeIn: self = .easeIn
        case .spring: self = .spring
        case .linear: self = .linear
        case let .custom(a, b, c, d): self = .custom(a, b, c, d)
        case let .bounce(stiffness, damping): self = .bounce(stiffness: stiffness, damping: damping)
        case .uiKitSmoothDeceleration:
            // Lossy, and the only lossy arm here: ComponentFlow has no critically-damped-spring
            // case, and its `.custom` is a cubic bezier, which is exactly what this curve is not.
            // `.spring` is the nearest family. This bridge only feeds item-internal
            // ContainedViewLayoutTransitions — the scroll itself is animated by CoreList from the
            // real CASpringAnimation, so the approximation never reaches the offset.
            self = .spring
        }
    }
}

// PoC alternative ChatHistoryListViewBackend backed by CoreVirtualListView (from the vendored
// CoreList module). Selected via the `coreListChatBackend` experimental flag; the default
// ListViewImpl path is unaffected.
//
// This is a proof of concept: it targets display / scroll / load-more only. Members outside that
// scope are safe stubs (no-ops / plain storage) and must never crash. Architecture, invariants, and
// deferred items: docs/chat/corelist-chat-history-backend.md
final class CoreListChatHistoryBackend: ASDisplayNode, ChatHistoryListViewBackend {
    // Matches ListViewImpl's rotation math: the wrapper (ChatHistoryListNodeImpl) applies the chat's
    // π rotation to itself, and each chat item node (ChatMessageItemView.init(rotated:)) applies its
    // own π rotation. Those two compose to upright content in a bottom-anchored inverted list (the
    // wrapper's π also flips stacking so index 0 = newest lands at the screen bottom, and flips touch
    // direction). The hosted CoreVirtualListView must therefore stay at IDENTITY — a third rotation
    // here renders the whole chat 180°-rotated. Stored for the makeListView contract; no transform.
    var rotated: Bool = false

    // Internal rather than private: the header adapter in CoreListChatHistoryHeaders.swift
    // enumerates attachments through it. Still invisible outside TelegramUI.
    let coreList: CoreVirtualListView

    private let scrollMotion = CoreListChatScrollMotion()
    fileprivate lazy var scrollTiltProvider: (CFTimeInterval) -> Float = { [weak self] time in
        guard let self, !self.globalIgnoreScrollingEvents else { return 0.0 }
        return self.scrollMotion.tilt(at: time)
    }

    // Ordered entry array: the source of truth for what CoreVirtualListView displays. Mirrors the
    // ListView transaction model (delete/insert/update over indices) with a stable serial per entry
    // used as the CoreListItem identity.
    private var entries: [CoreListEntryItem] = []
    private var currentSize: CGSize = .zero
    private var currentInsets: UIEdgeInsets = .zero
    
    private var nextStableVersion: Int = 1

    // `ListViewDeleteAndInsertOptions.PreferSynchronousResourceLoading` for the pass that is running
    // right now, read by the two host views at the moment they build a node
    // (`CoreListNodeHostView.rebuild`, `CoreListHeaderHostView.update(width:)`).
    //
    // It is a property of the PASS and of nothing else — ListViewImpl reads it off the transaction's
    // options and hands it to `nodeForItem`/`updateItemHeaders` for exactly the nodes that
    // transaction creates (Display/Source/ListView.swift:2135, :3617). It means "the images in the
    // nodes this transaction builds must already be decoded when it returns", which the chat asks for
    // on two paths only: the first view of a chat opened without an animation
    // (`.Initial(fadeIn: false)` — PreparedChatHistoryViewTransition.swift:94) and the send animation
    // (Chat/ChatControllerLoadDisplayNode.swift:929). Everywhere else — every row scrolled into view
    // — a synchronous decode is a main-thread stall for an image the async path would have delivered
    // a frame later.
    //
    // Hence a live read rather than a value seeded into the view at `view()` time, which is what the
    // sibling `isFlashingOnScrolling` does: the question is "which pass is building this node", and
    // only the backend can answer it. Outside a transaction — a scroll rebalance, an overscroll hold
    // — it is false, which is the correct answer for every node those passes create.
    private(set) var prefersSynchronousResourceLoading: Bool = false

    // MARK: - Narrow scroll-view accessors
    var bounces: Bool = true
    var contentHeight: CGFloat { return self.coreList.settledContentHeight }

    // How far the newest edge is currently held beyond its resting position. Deliberately NOT part of
    // `currentInsets`: see `holdOverscrollAction(distance:)` and the protocol declaration for why
    // aliasing the two is the bug this exists to avoid.
    private var overscrollHoldDistance: CGFloat = 0.0

    // The hold reaches CoreList as extra top inset — `pinsLoadedTop` translates a window that starts
    // at index 0 onto the inset edge outright (CoreVirtualListView.swift:2768), so a larger top inset
    // IS the newest edge sitting lower, which under the wrapper's π rotation is the chat held open at
    // the bottom. That is the same outcome `ListViewImpl` gets from `scroller.contentInset`.
    //
    // `compensatesInsetChange: false`: the displacement is the entire point of the call, so the
    // anchor projection that normally cancels an inset change out of the visible content must not
    // run. (It is moot while index 0 is loaded — the pin branch translates outright and never
    // consults it — and index 0 is always loaded when an overscroll action is live. Passing `false`
    // states the intent rather than relying on that.)
    //
    // Unlike the field it replaced, this SUBMITS A PASS, so the hold-and-release actually moves the
    // content; writing the inset field alone was inert until some later transaction happened to
    // carry it.
    var holdsOverscrollActionDuringDrag: Bool { return true }

    // Two levels below `self.view`: this node hosts `coreList`, `coreList` hosts the scroll engine's
    // content host, and the pan is on that. All three views cover the same rect (`layout()` sizes
    // `coreList` to our bounds, `CoreVirtualListView` sizes `contentHost` to its own), so routing a
    // touch or a recognizer here rather than to `self.view` is geometrically neutral and only
    // changes which recognizers can see it — which is the entire point.
    var scrollGestureHostView: UIView { return self.coreList.scrollGestureHostView }

    func holdOverscrollAction(distance: CGFloat, movesContent: Bool) {
        guard distance != self.overscrollHoldDistance else {
            return
        }
        self.overscrollHoldDistance = distance
        // Before the first updateSizeAndInsets there is no geometry to hold and no window to pin;
        // the stored distance still applies to the first real pass through `coreListInsets`.
        guard self.currentSize != .zero else {
            return
        }
        // `absorbsEdgeChangeIntoOverscroll` is the `movesContent` half, and it is NOT the same knob as
        // `compensatesInsetChange`: that one governs the ANCHOR projection, this one governs what
        // happens to the rubber band when the edge moves under it. `pinsLoadedTop` translates the
        // window onto the new inset edge outright whenever index 0 is loaded — which is always, while
        // an overscroll action is live — so the anchor knob cannot hold the content still here and
        // only this one can.
        self.coreList.applyChanges(
            newInsets: self.coreListInsets,
            compensatesInsetChange: false,
            absorbsEdgeChangeIntoOverscroll: !movesContent,
            transition: .immediate
        )
        // MANDATORY, and the reason this bug survived a first fix. This method moves content without
        // going through `chatHistoryTransaction`, so it is the only thing that reports the offset it
        // just produced — and CoreList has no per-frame hook once motion stops ("nothing re-reports
        // when the animation lands", `settledFrame`). Without this the ramp's FINAL step,
        // hold → 0, is invisible: the last value the chat ever heard is whatever the last scroll
        // frame happened to catch mid-ramp (measured: -7.7pt, at hold=6.7), which is still
        // `< -0.1`, so `maybeUpdateOverscrollAction` keeps the overscroll control alive forever over
        // a content offset that is actually zero — a dead band at the bottom of the chat.
        //
        // `ListViewImpl` needs no equivalent because its lever is `scroller.contentInset`: UIKit
        // moves `contentOffset`, `scrollViewDidScroll` fires, and it re-reports every frame of the
        // ramp on its own.
        //
        // The general rule this is an instance of: on this backend, ANY geometry mutation outside a
        // transaction owes a content-offset report, because nothing else will make one.
        //
        // `.settled` matches `chatHistoryTransaction`'s convention — the outcome of the pass just
        // submitted — and for an `.immediate` pass settled and presented coincide anyway. While a
        // spring-back flight is still in the air (the hold is established one callback after the
        // release that launched it) the flight's own sampler keeps reporting `.presented` per frame,
        // so the two self-correct exactly as they do at a transaction point.
        self.updateVisibleContentOffset(transition: .immediate, geometry: .settled)
    }

    // MARK: - Config flags (plain storage; no behavior for the PoC)
    var scrollEnabled: Bool = true
    var preloadPages: Bool = true
    var experimentalSnapScrollToItem: Bool = false
    var stackFromBottom: Bool = false
    var enableExtractedBackgrounds: Bool = false
    var autoScrollWhenReordering: Bool = false
    var defaultToSynchronousTransactionWhileScrolling: Bool = false
    var verticalScrollIndicatorColor: UIColor? = nil
    var accessibilityPageScrolledString: ((String, String) -> String)? = nil

    // MARK: - Snapshot freeze
    //
    // Set by ChatHistoryListNodeImpl.prepareSnapshotState when this node's own view is handed to the
    // next-channel transition as the outgoing "snapshot": from that moment it is a picture, not a
    // list. `ListViewImpl` honours it by returning early from `updateScrollViewDidScroll`
    // (Display/Source/ListView.swift:1004) — the one function that both moves its item nodes and
    // reports to the host — so its content freezes and it stops calling back.
    //
    // It used to sit in the config-stub block, written by that call site and read by nothing, so the
    // outgoing list stayed live: still draggable, still reporting offsets into a controller being
    // torn down.
    //
    // Two parts, and note what is deliberately NOT here: motion is not halted. CoreList's engine
    // moves the content host itself rather than from inside a host callback, so this flag cannot
    // suppress movement the way ListViewImpl's early return does — and it must not. The release that
    // reaches this launches a spring-back one callback earlier, and the chat retargets that spring by
    // applying the overscroll hold (`holdOverscrollAction`), so the flight has to be allowed to
    // finish: it is what carries the content INTO the held-open position the outgoing snapshot is
    // supposed to show. Freezing it in place instead strands the content wherever the finger happened
    // to leave it.
    //
    // What the flag does do:
    // 1. Drops `isUserInteractionEnabled`, so no NEW drag can start on a view that is now a picture.
    // 2. Guards `onVisibleWindowChanged`, the direct analogue of ListViewImpl's early return, so the
    //    host stops reacting to a scroll it no longer owns.
    //
    // Broader than ListViewImpl on (1) — there the scroller keeps scrolling, only the item nodes
    // hold, and taps still land. A snapshot being animated away should accept neither.
    var globalIgnoreScrollingEvents: Bool = false {
        didSet {
            if self.globalIgnoreScrollingEvents != oldValue {
                self.coreList.isUserInteractionEnabled = !self.globalIgnoreScrollingEvents
                if self.globalIgnoreScrollingEvents {
                    self.scrollMotion.reset()
                }
            }
        }
    }

    // MARK: - Geometry / range (real values populated in later tasks)
    var insets: UIEdgeInsets = .zero
    var visibleSize: CGSize = .zero
    var displayedItemRange: ListViewDisplayedItemRange = ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
    // ListViewImpl keeps this mirror alongside displayedItemRange so updateVisibleItemRange can fire
    // displayedItemRangeChanged only on an actual change. Optional (not the empty range) so the very
    // first computation always counts as a change.
    private var internalDisplayedItemRange: ListViewDisplayedItemRange?
    var opaqueTransactionState: Any? = nil

    // MARK: - Interactive-drag origin
    //
    // Parity with `ListViewImpl.didInteractivelyDragFromTopOrigin`: the current-or-most-recent gesture was
    // a real drag — content actually moved — that began pinned to the newest-message edge. Its one
    // consumer is the chat's keyboard-dismissal path, which reads it to decide whether to snap back to the
    // newest message once the keyboard is gone (`ChatControllerNode.swift:2453`). Both halves reset on
    // drag BEGIN, never on drag end, so the value survives to the layout pass that reads it — as in
    // ListViewImpl, where `trackingOffset` is reset only in the pan's `.began`.
    private var beganDragPinnedToNewestEdge = false
    private var didMoveContentDuringDrag = false

    var didInteractivelyDragFromTopOrigin: Bool {
        return self.beganDragPinnedToNewestEdge && self.didMoveContentDuringDrag
    }

    // MARK: - Tracking
    //
    // Parity with `ListViewImpl.isTracking`: a finger is on the list right now. Unlike the two flags
    // above — which deliberately survive drag end so a later layout pass can read them — this one is
    // strictly the finger-down interval, and it is false throughout the momentum phase (ListViewImpl
    // keeps that distinction too: momentum is `isDeceleratingAfterTracking`, and the inset-compensation
    // suppression below checks only `isTracking`).
    //
    // Its consumer is that suppression. The chat's insets change WHILE the list is being dragged, by the
    // same finger: `Window1`'s `WindowPanRecognizer` implements interactive system-keyboard dismissal
    // (`Display/Source/WindowContent.swift:1332`) and its delegate returns true from
    // `shouldRecognizeSimultaneouslyWith` (`WindowContent.swift:254`), so one downward drag both scrolls
    // the history and shrinks `inputHeight` frame by frame. Each frame therefore reaches the list twice —
    // once as a scroll delta, once as a smaller bottom inset — and compensating the inset change on top of
    // the scroll moves content by double the finger's travel. ListViewImpl answers this by zeroing
    // `offsetFix` while tracking (`Display/Source/ListView.swift:3276`).
    //
    // Sampled at drag BEGIN rather than finger-down, which is the same approximation
    // `beganDragPinnedToNewestEdge` makes above and for the same reason: drag-begin is the earliest hook
    // the scroll-engine seam has. The residual is bounded by the pan recognizer's threshold and is not
    // visible, because in that pre-threshold window the content is not yet scrolling — so the inset
    // compensation is the only thing moving it, in the same direction and by the same amount the finger
    // would have. The handover is continuous rather than a step.
    private var isTracking = false

    // Backing state for the header flashing driver in CoreListChatHistoryHeaders.swift.
    // `SwiftSignalKit.Timer` explicitly: `Timer` alone is ambiguous here, since Foundation's is in
    // scope too.
    var headerFlashTimer: SwiftSignalKit.Timer?
    var isFlashingHeaders = false

    // MARK: - Callbacks the controller installs
    var displayedItemRangeChanged: (ListViewDisplayedItemRange, Any?) -> Void = { _, _ in }
    var visibleContentOffsetChanged: (ListViewVisibleContentOffset, ContainedViewLayoutTransition) -> Void = { _, _ in }
    var beganInteractiveDragging: (CGPoint) -> Void = { _ in }
    var endedInteractiveDragging: (CGPoint) -> Void = { _ in }
    var didEndScrolling: ((Bool) -> Void)? = nil
    var didEndScrollingWithOverscroll: (() -> Void)? = nil
    // Straight through to the scroll engine's own release hook — no state of ours in between, so the
    // predicate is evaluated at the release rather than at some earlier moment we cached.
    var shouldStopScrolling: ((CGFloat) -> Bool)? {
        get { self.coreList.shouldStopScrolling }
        set { self.coreList.shouldStopScrolling = newValue }
    }
    var updateFloatingHeaderOffset: ((CGFloat, ContainedViewLayoutTransition) -> Void)? = nil
    var didScrollWithOffset: ((CGFloat, ContainedViewLayoutTransition, ListViewItemNode?, Bool) -> Void)? = nil
    var addContentOffset: ((CGFloat, ListViewItemNode?) -> Void)? = nil
    var tapped: (() -> Void)? = nil
    var reorderItem: (Int, Int, Any?) -> Signal<Bool, NoError> = { _, _, _ in .single(false) }
    var generalScrollDirectionUpdated: (GeneralScrollDirection) -> Void = { _ in }
    var getCustomItemDeleteAnimationDuration: ((ListViewItemNode) -> Double?)? = nil

    // Non-copying, lazy view over the loaded item host views, in ascending item index. Backed by
    // CoreVirtualListView.loadedItemViews, which walks the settled window in place (a COW snapshot of
    // its buffer, so mutating the list mid-iteration is safe). This is the geometry-bearing level:
    // a host view sits in the CoreList hierarchy, whereas its hosted node's frame is host-local.
    // Only settled/loaded rows are visited — never off-screen entries or exit-overlay ghosts.
    private var itemNodeHostViews: some Sequence<CoreListNodeHostView> {
        self.coreList.loadedItemViews.lazy.compactMap { $0 as? CoreListNodeHostView }
    }

    // Non-copying, lazy view over the loaded chat item nodes — the CoreList analogue of
    // ListViewImpl.itemNodes. Maps each loaded host view to its hosted node, skipping any
    // not-yet-built. Lazy: no array is materialized.
    private var itemNodes: some Sequence<ListViewItemNode> {
        self.itemNodeHostViews.lazy.compactMap { $0.itemNode }
    }

    // The inset-reduced viewport band in the hosted CoreVirtualListView's coordinate space, shared by
    // forEachVisibleItemNode and itemNodeVisibleInsideInsets so the two predicates cannot drift.
    //
    // Uses currentSize/currentInsets, the private working pair, rather than the protocol-exposed
    // visibleSize/insets. The two carry the same values — both are written together from the same
    // transaction — so this is a matter of which pair the display path owns, not a difference in
    // meaning. It did once differ, when `setTopContentInset(_:)` wrote `currentInsets.top` alone;
    // that aliasing is gone (see `holdOverscrollAction(distance:)`), and this comment used to cite
    // it as the reason, which is worth knowing if the two ever drift again.
    //
    // The band deliberately does NOT include `overscrollHoldDistance`. Holding the newest edge open
    // must not change which rows count as visible, and ListViewImpl agrees: its own scans read
    // `self.insets`, which `scroller.contentInset` never touches.
    //
    // Their orientation already matches — CoreList lays index 0 at its own top and
    // the wrapper's π maps that to the screen bottom, the same convention ListViewImpl(rotated: true)
    // uses, and both receive the same insets from the same transaction. Before the first
    // updateSizeAndInsets, currentSize is .zero and nothing is inside the band, which is also
    // ListViewImpl's behavior with a zero visibleSize.
    private var visibleBand: (top: CGFloat, bottom: CGFloat) {
        return (self.currentInsets.top, self.currentSize.height - self.currentInsets.bottom)
    }

    // The insets handed to CoreList: VERTICAL ONLY. Rows are laid out at the full viewport width and
    // the horizontal insets travel to the hosted item as ListViewItemLayoutParams.leftInset/rightInset
    // (CoreListEntryItem.leftInset, CoreListNodeHostView.rebuild) — which is exactly what ListViewImpl
    // does: there is no `x: insets.left` anywhere in ListView.swift, its rows are full width, and the
    // inset reaches the item as a layout param (Display/Source/ListView.swift:2384).
    //
    // Two reasons that level matters, not one:
    //
    //   Orientation.  A node carries its OWN π (ChatMessageItemView.init(rotated:) →
    //                 CATransform3DMakeRotation(π, 0, 0, 1), which flips x as well as y). Item π +
    //                 wrapper π = identity, so an inset applied INSIDE the item lands on the screen
    //                 side the chat named. CoreList's viewport insets instead frame the row itself
    //                 (`contentWidth = width - left - right`, CoreVirtualListView.swift:2262), taking
    //                 only the wrapper's π — so `insets.left` came out on the screen RIGHT. Measured:
    //                 the topics sidebar's 92pt shrank the bubbles by 92pt on the screen RIGHT and
    //                 moved nothing away from the left, so the sidebar overlapped the content it was
    //                 supposed to make room for.
    //
    //   Animation.    Framing the row cannot animate the move, and swapping the insets to fix the
    //                 orientation did not change that. A view's subviews do not follow its
    //                 `bounds.size.width`, so the row's content only moves when the hosted node is
    //                 re-laid out — which happened at the destination width immediately, and mirrored
    //                 that content about a centre that had itself jumped by half the inset. Visually:
    //                 items animating correctly but offset by half the inset from the first frame.
    //                 As a layout param it is an ordinary item relayout, which the item animates on
    //                 the pass transition like any other content change.
    //
    // Vertical needs no such treatment because BOTH backends let the list decide a row's vertical
    // position: one π either way, which the chat's pre-mirror at ChatControllerNode.swift:2500 already
    // accounts for.
    private var coreListInsets: UIEdgeInsets {
        return UIEdgeInsets(
            // The overscroll hold is added HERE and nowhere else. Everything that reasons about the
            // list's own geometry — `insets`, `visibleBand`, `visibleContentOffset` — must keep
            // reading `currentInsets`, so that while the edge is held the reported content offset is
            // `-overscrollHoldDistance` rather than zero. That is what keeps the overscroll control
            // on screen and correctly sized for the duration of the hold, and it is what
            // `ListViewImpl` reports at the same moment.
            top: self.currentInsets.top + self.overscrollHoldDistance,
            left: 0.0,
            bottom: self.currentInsets.bottom,
            right: 0.0
        )
    }

    // The settled rect of a loaded row in the hosted CoreVirtualListView's coordinate space, or nil
    // when `node` is not currently loaded.
    //
    // The nil case IS the CoreList analogue of ListViewImpl's `node.index != nil` liveness guard:
    // ListViewItemNode.index is `public internal(set)` to Display, so a hosted node can never carry a
    // ListView index and is always nil. Absence from the loaded window is the equivalent test —
    // genuine departures move to the non-interactive exitOverlay and never appear here.
    //
    // Frames come from `presentedFrame(of:)` rather than a bare `convert`: it walks whatever ancestor
    // path the row currently has (`container` normally, `crossingOverlay` while a structural
    // transition carries it), so it cannot drift from what is rendered, AND it corrects for the
    // additive viewport animations. A bare `convert` composes ancestor MODEL bounds, and CoreList's
    // host layer is parked at a keyframe flight's DESTINATION for the whole fling — so it would report
    // every row hundreds of points from where the user sees it, for the entire momentum phase.
    // (ListViewImpl reads settled endpoints, but there model == presented; here it does not.)
    private func loadedFrame(of node: ListViewItemNode) -> CGRect? {
        for hostView in self.itemNodeHostViews {
            if hostView.itemNode === node {
                return self.listFrame(of: hostView)
            }
        }
        return nil
    }

    // A loaded row's rect in the hosted CoreVirtualListView's coordinate space, as presented.
    private func listFrame(of view: UIView) -> CGRect {
        return self.coreList.presentedFrame(of: view)
    }

    // Which of CoreList's two geometries a content-offset read wants. They differ only while something
    // is animating the viewport, and then they differ by the whole remaining travel.
    //
    // `.presented` — where content is on screen right now. What a question about the CURRENT position
    // means, and what every per-frame scroll read wants.
    //
    // `.settled` — where content will be once the pass in flight finishes. What the transaction-end
    // emission means: it reports the OUTCOME of the pass it just submitted, paired with that pass's
    // transition. This is also what ListViewImpl reports at the same point, because there the two
    // coincide — `replayOperations` writes final item-node frames immediately and animates the layers
    // additively, so its model IS its presented geometry.
    private enum OffsetGeometry {
        case presented
        case settled
    }

    // The rect of the row at a collection index in the requested geometry, or nil when that index is
    // not loaded. `geometry` is deliberately NOT defaulted: which one a call site wants is the whole
    // question, and a default would let a new caller pick one by accident.
    private func loadedFrame(atIndex index: Int, _ geometry: OffsetGeometry) -> CGRect? {
        guard let view = self.coreList.loadedItemView(at: index) else {
            return nil
        }
        switch geometry {
        case .presented:
            return self.listFrame(of: view)
        case .settled:
            return self.coreList.settledFrame(of: view)
        }
    }

    // The collection index of a loaded row, or nil when `node` is not currently loaded.
    //
    // ListViewImpl's ensureItemNodeVisible opens with `if let index = node.index`, which cannot work
    // here: ListViewItemNode.index is `public internal(set)` to Display, so a hosted node never
    // carries one. Resolving through CoreList's loadedItemEntries — the (index, view) sibling of
    // loadedItemViews — is the equivalent, and its nil case is the same liveness guard
    // loadedFrame(of:) relies on: genuine departures move to the exitOverlay and never appear here.
    private func loadedIndex(of node: ListViewItemNode) -> Int? {
        for entry in self.coreList.loadedItemEntries {
            if (entry.view as? CoreListNodeHostView)?.itemNode === node {
                return entry.index
            }
        }
        return nil
    }

    // ListViewImpl's scroll-position arithmetic (Display/Source/ListView.swift:3166-3204),
    // translated from "a delta added to every frame" into "the target row's minY, minus insets.top"
    // — which is what CoreList's resolver returns (its projected screen target for the row's minY is
    // viewportInsets.top + the returned value).
    //
    // Runs inside CoreList's mutation pass, at the moment the anchor row has been measured. It reads
    // geometry only: never mutate the entry array or re-enter a transaction from here.
    //
    // Geometry comes from currentSize/currentInsets, which chatHistoryTransaction has already
    // updated to this pass's values before calling applyChanges — the same values CoreList is
    // resolving against, since they are what was submitted as newSize/newInsets. This diverges from
    // ListViewImpl, which reads the OLD self.insets in this branch (note the commented-out
    // `// updateSizeAndInsets?.insets ?? self.insets` at ListView.swift:3143) and applies the
    // size/inset change separately afterwards.
    // Whether `index` is the LOWEST entry declaring `pinToEdgeWithInset` — `ListViewImpl` runs the
    // same scan before taking its pin-to-edge branch (`Display/Source/ListView.swift:3151-3158`), and
    // it matches CoreList's own `lowestPinnedIndex` rule, so the explicit scroll and the resting pin
    // always name the same row.
    private func isLowestPinToEdgeIndex(_ index: Int) -> Bool {
        guard self.entries.indices.contains(index),
              self.entries[index].listItem.pinToEdgeWithInset else {
            return false
        }
        for i in 0 ..< index where self.entries[i].listItem.pinToEdgeWithInset {
            return false
        }
        return true
    }

    private func pointOffset(for position: ListViewScrollPosition,
                             index: Int,
                             height: CGFloat,
                             view: UIView & CoreListItemView) -> CGFloat {
        let node = (view as? CoreListNodeHostView)?.itemNode
        // ChatUnreadItem and ChatReplyCountItem set (top: 5, bottom: 6) — the unread separator is a
        // primary scroll target, so this is load-bearing rather than a rounding detail.
        let scrollPositioningInsets = node?.scrollPositioningInsets ?? UIEdgeInsets()
        let viewportHeight = self.currentSize.height
        let insetTop = self.currentInsets.top
        let insetBottom = self.currentInsets.bottom
        let contentAreaHeight = viewportHeight - insetTop - insetBottom

        // `ListViewImpl` replaces the requested position WHOLESALE for a pin-to-edge target
        // (`Display/Source/ListView.swift:3146-3170`): the chat asks for `.top(0.0)` from
        // `scrollToPinToTopStableId` (`ChatHistoryListNode.swift:2525`) and relies on the list to know
        // better. Here `.top(0.0)` would return 0 and place the row on `viewportInsets.top` — the
        // SCREEN BOTTOM under the wrapper's π, the opposite end from where it belongs.
        //
        // `scrollPositioningInsets.bottom` is deliberately NOT added, unlike `ListViewImpl` (`:3168`).
        // CoreList's own resting pin works in the list's geometry and cannot see it, so including it
        // would land this scroll a few points off the position every later pass re-pins to, and
        // `isStrictlyScrolledToPinToEdgeItem()` would answer false immediately after the scroll that
        // established the pin. It is zero for every row that can carry the flag anyway — only
        // `ChatUnreadItem`/`ChatReplyCountItem` set a non-zero value, and neither can be pinned.
        //
        // `ListViewImpl` also guards this branch on `pinToEdgeTopInset > 0 || pinExtension > 0`. Not
        // reproduced: when that guard would be false the placement below sits past CoreList's minimum
        // edge and is clamped back to the position the unguarded branch produces anyway, so the guard
        // would only add a second copy of the slack calculation to keep in sync.
        if self.isLowestPinToEdgeIndex(index) {
            let extensionOffset = max(0.0, height - contentAreaHeight * 0.5)
            return (viewportHeight - insetBottom + extensionOffset) - height - insetTop
        }

        switch position {
        case let .top(additionalOffset):
            return additionalOffset + scrollPositioningInsets.top
        case let .bottom(additionalOffset):
            let targetMaxY = (viewportHeight - insetBottom)
                + scrollPositioningInsets.bottom
                + additionalOffset
            return targetMaxY - height - insetTop
        case let .center(overflow):
            if height <= contentAreaHeight + CGFloat.ulpOfOne {
                return floor((contentAreaHeight - height) / 2.0)
            }
            switch overflow {
            case .top:
                return 0.0
            case .bottom:
                return (viewportHeight - insetBottom) - height - insetTop
            case let .custom(getOverflow):
                guard let node else {
                    return 0.0
                }
                let targetMaxY = (viewportHeight - insetBottom)
                    + node.insets.top
                    + getOverflow(node)
                    - floor(contentAreaHeight * 0.5)
                return targetMaxY - height - insetTop
            }
        case .visible:
            // `.visible` is the one position that depends on where the row already is, so it needs
            // the row loaded. It is produced only by ensureItemNodeVisible — which always holds a
            // loaded node — and by the experimentalSnapScrollToItem path, which nothing in chat ever
            // enables. An unloaded target therefore falls back to center-with-top-overflow.
            //
            // `.presented`: the question here is literally "is this row on screen right now", so the
            // rendered position is the input, not where a pass in flight is taking it.
            guard let frame = self.loadedFrame(atIndex: index, .presented) else {
                return height <= contentAreaHeight + CGFloat.ulpOfOne
                    ? floor((contentAreaHeight - height) / 2.0)
                    : 0.0
            }
            if frame.maxY > viewportHeight - insetBottom {
                let targetMaxY = (viewportHeight - insetBottom) + scrollPositioningInsets.bottom
                return targetMaxY - height - insetTop
            }
            if height <= contentAreaHeight + CGFloat.ulpOfOne, frame.minY < insetTop {
                return -scrollPositioningInsets.top
            }
            return frame.minY - insetTop
        }
    }

    override init() {
        self.coreList = CoreVirtualListView(forEmbedding: .zero)
        super.init()
        // Force the ASDisplayNode's view to load eagerly. The composed ChatHistoryListNode wrapper
        // gates its history dequeue on isNodeLoaded, mirroring ListViewImpl's eager view load.
        let _ = self.view
        self.view.addSubview(self.coreList)

        self.coreList.onUserScrollDelta = { [weak self] delta, timestamp in
            guard let self, !self.globalIgnoreScrollingEvents else { return }
            self.scrollMotion.report(delta: self.rotated ? delta : -delta, at: timestamp)
        }

        // Report visible-range and content-offset changes so the history controller paginates and the
        // chat chrome tracks the scroll. Reading the callbacks off `self` at call time picks up
        // whatever the controller has since assigned.
        //
        // onVisibleWindowChanged fires on EVERY user-scroll frame, including momentum — handleUserScroll
        // is the engine.onScroll sink and calls it unconditionally, whether or not the window
        // rebalanced. So this covers all interactive scrolling; programmatic scrolls are covered at
        // transaction end instead (see chatHistoryTransaction).
        self.coreList.onVisibleWindowChanged = { [weak self] in
            guard let self else { return }
            // The other half of `globalIgnoreScrollingEvents`, and the direct analogue of
            // ListViewImpl returning early from `updateScrollViewDidScroll` — placed before the
            // drag-witness write below, exactly as ListViewImpl's guard precedes its `trackingOffset`
            // accumulation (ListView.swift:1004 vs :1050).
            if self.globalIgnoreScrollingEvents {
                return
            }
            // Reaching here means USER-driven content movement, which is what makes it the analogue of
            // ListViewImpl accumulating a non-zero `trackingOffset`: `handleUserScroll` is the
            // `engine.onScroll` sink, programmatic offset writes are isProgrammatic-guarded, and the
            // additive viewport track moves content with no engine offset change at all.
            //
            // It also fires during momentum, where ListViewImpl has stopped accumulating (`isTracking` is
            // false by then). Harmless: momentum only follows a drag that already moved content, so the
            // flag is set either way.
            self.didMoveContentDuringDrag = true
            self.noteHeaderFlashingActivity()
            self.updateVisibleItemRange(force: false)
            // `.presented`: this fires per frame while content is moving under the finger or its
            // momentum, so "where is it now" is both the question and the answer, and any single frame
            // being slightly off is corrected by the next one.
            self.updateVisibleContentOffset(transition: .immediate, geometry: .presented)
            // `ListViewImpl` reaches the same block from `updateScrollViewDidScroll` → `snapToBounds`,
            // with no size/inset update in hand and therefore an immediate transition. What can change
            // here is the LOADED WINDOW — a rebalance loading or dropping rows moves both terms of the
            // "whole collection is on screen" test.
            self.updateTrailingItemSpace(transition: .immediate)
        }
        self.coreList.onLoadedEdgeReached = { [weak self] _ in
            guard let self else { return }
            self.updateVisibleItemRange(force: false)
        }
        // Report interactive drag start to the history controller (parity with ListViewImpl's
        // beganInteractiveDragging). CoreVirtualListView doesn't surface the touch point and every
        // consumer ignores it, so pass .zero.
        self.coreList.willBeginDragging = { [weak self] in
            guard let self else { return }

            // Sample the drag's origin before it can move anything. ListViewImpl samples in
            // `touchesBegan` — finger down — whereas CoreVirtualListView's earliest hook is drag-begin,
            // which fires after the pan recognizer's own threshold, i.e. a few points of movement. The
            // 10pt tolerance (verbatim from ListView.swift:4959) is wide enough to absorb exactly that,
            // which is plausibly why it is 10 and not 0.
            if case let .known(value) = self.visibleContentOffset(), value <= 10.0 {
                self.beganDragPinnedToNewestEdge = true
            } else {
                self.beganDragPinnedToNewestEdge = false
            }
            self.didMoveContentDuringDrag = false
            self.isTracking = true
            self.scrollMotion.holding = !self.globalIgnoreScrollingEvents
            self.noteHeaderFlashingActivity()

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
            
            for itemNode in self.itemNodes {
                cancelContextGestures(view: itemNode.view)
            }
            self.cancelAttachmentContextGestures()

            self.beganInteractiveDragging(.zero)
        }
        // Close the tracking interval. Fires on `.ended` AND `.cancelled`, so a drag torn down by a
        // competing recognizer cannot leave the flag stuck on and permanently suppress inset compensation.
        //
        // This is also ListViewImpl's `scrollViewDidEndDragging` (Display/Source/ListView.swift:903-930),
        // and the three callbacks it fires there are reproduced in its order. The `willDecelerate`
        // distinction it gets from UIKit is read here from `isScrollFlightActive`, which is meaningful
        // because the engine emits this hook AFTER launching deceleration.
        self.coreList.didEndDragging = { [weak self] in
            guard let self else { return }
            self.isTracking = false
            self.scrollMotion.holding = false

            let isDecelerating = self.coreList.isScrollFlightActive
            // `contentOffset.y < -48.0` (ListView.swift:913) against the near edge. Its only consumer is
            // the overlay audio player's pull-to-dismiss, and that list is built `rotated: false`
            // (the default on ChatHistoryListNodeImpl.init, which OverlayAudioPlayerControllerNode does
            // not override), so "past the min edge" is the plain pull-down the gesture means.
            if isDecelerating && self.coreList.overscrollDistance < -48.0 {
                self.didEndScrollingWithOverscroll?()
            }
            // The point is `ListViewImpl.touchesPosition`; both consumers take it as `_`
            // (ChatHistoryListNode.swift:1268, OverlayAudioPlayerControllerNode.swift:363), so `.zero`
            // matches what `beganInteractiveDragging` already passes above rather than inventing a
            // coordinate space for a value nothing reads.
            self.endedInteractiveDragging(.zero)
            if !isDecelerating {
                self.didEndScrolling?(false)
            }
        }
        // The momentum half: `scrollViewDidEndDecelerating` (ListView.swift:932-941), including its
        // `!isTracking` guard, which is what keeps a flight *caught* by a new touch from reporting a
        // stop. See the seam's own comment for why the flag is already true by then.
        self.coreList.didEndScrolling = { [weak self] in
            guard let self, !self.isTracking else { return }
            self.didEndScrolling?(true)
        }
    }

    deinit {
        // The timer holds `self` weakly, so this is not a cycle — but a fired timer on a dead
        // backend is still wasted work on the main run loop.
        self.headerFlashTimer?.invalidate()
    }

    override func layout() {
        super.layout()
        // Transform-safe sizing: set bounds + center rather than frame while a rotation is applied.
        self.coreList.bounds = CGRect(origin: .zero, size: self.bounds.size)
        self.coreList.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)
    }

    // MARK: - Transaction
    // Applies a ListView-style batch to the entry array (mirroring ListView's own ordering:
    // deletes first, then inserts, then updates), maps size/insets, and re-renders the full settled
    // set via CoreVirtualListView.applyChanges. Fine-grained insert/delete animations and
    // stationaryItemRange is intentionally ignored for the PoC; `customAnimationTransition` is
    // honored (see the transition precedence below).
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
    ) {
        if let updateOpaqueState = updateOpaqueState {
            self.opaqueTransactionState = updateOpaqueState
        }

        // Scoped to the transaction, because that is the scope ListViewImpl gives it: nodes this pass
        // builds load synchronously, nodes any later pass builds do not. See the property.
        //
        // The window build that consumes it runs inline inside `applyChanges` below. The one case
        // where it does not is a re-entrant call, which CoreList defers to its scheduler
        // (CoreVirtualListView.swift:964) — the deferred pass then finds the flag already cleared and
        // builds asynchronously. That is the safe direction to be wrong in, and it is the same
        // direction ListViewImpl errs in when a transaction is queued behind another.
        self.prefersSynchronousResourceLoading = options.contains(.PreferSynchronousResourceLoading)
        defer {
            self.prefersSynchronousResourceLoading = false
        }

        // Evaluated HERE, before the new insets are installed below, because the predicate is "is the
        // separator sitting exactly where the previous pass pinned it" and that is a question about
        // the OLD geometry. Same reason `compensatesInsetChange` is read at this call site rather
        // than inside CoreList: the value must be the one that held when the transaction was
        // submitted.
        //
        // Unlike ListViewImpl, which cannot compose a scroll with an inset change and so re-issues
        // the re-pin as a second transaction from its completion, `applyChanges` takes `newInsets`
        // and `scrollTo` together — so this rides the same pass as one movement, with no
        // intermediate frame and a single animation.
        var effectiveScrollToItem = scrollToItem
        if maintainsUnreadItemAlignment,
           effectiveScrollToItem == nil,
           let sizeAndInsets = updateSizeAndInsets,
           sizeAndInsets.insets.bottom != self.currentInsets.bottom {
            let pinnedMaxY = self.currentSize.height - self.currentInsets.bottom + 6.0
            for entry in self.coreList.loadedItemEntries {
                guard let hostView = entry.view as? CoreListNodeHostView,
                      let itemNode = hostView.itemNode,
                      itemNode is ChatUnreadItemNode else {
                    continue
                }
                if abs(self.listFrame(of: hostView).maxY - pinnedMaxY) < 1.0 {
                    effectiveScrollToItem = ListViewScrollToItem(
                        index: entry.index,
                        position: .bottom(0.0),
                        animated: sizeAndInsets.duration != 0.0,
                        curve: sizeAndInsets.curve,
                        directionHint: .Up
                    )
                    break
                }
            }
        }
        let scrollToItem = effectiveScrollToItem

        var sizeChanged = false
        let previousSideInsets = (left: self.currentInsets.left, right: self.currentInsets.right)
        if let sizeAndInsets = updateSizeAndInsets, (sizeAndInsets.size != self.currentSize || sizeAndInsets.insets != self.currentInsets) {
            self.currentSize = sizeAndInsets.size
            self.currentInsets = sizeAndInsets.insets
            self.visibleSize = sizeAndInsets.size
            self.insets = sizeAndInsets.insets
            sizeChanged = true
        }

        let structurallyChanged = !deleteIndices.isEmpty || !insertIndicesAndItems.isEmpty || !updateIndicesAndItems.isEmpty
        // Read before the mutation below rewrites `self.entries`. `deleteIndices` are indices into the
        // OLD array, so `arrivingBlockStableIds` cannot say where they fall without it.
        let previousEntryCount = self.entries.count
        if structurallyChanged {
            var updated = self.entries
            // Deletes: apply in descending index order so earlier removals don't shift later ones.
            for index in deleteIndices.map({ $0.index }).sorted(by: >) {
                if index >= 0 && index < updated.count {
                    updated.remove(at: index)
                }
            }
            // Inserts: apply in ascending index order; each carries its final index in the new array.
            for insert in insertIndicesAndItems.sorted(by: { $0.index < $1.index }) {
                let stableVersion = self.nextStableVersion
                self.nextStableVersion += 1
                let entry = CoreListEntryItem(stableId: insert.stableId, stableVersion: stableVersion, listItem: insert.item, backend: self, leftInset: self.currentInsets.left, rightInset: self.currentInsets.right)
                let clamped = min(max(insert.index, 0), updated.count)
                updated.insert(entry, at: clamped)
            }
            // Updates: same index, keep the stable serial, swap the ListViewItem so content refreshes.
            for update in updateIndicesAndItems {
                if update.index >= 0 && update.index < updated.count {
                    let stableVersion = self.nextStableVersion
                    self.nextStableVersion += 1
                    updated[update.index] = CoreListEntryItem(stableId: update.stableId, stableVersion: stableVersion, listItem: update.item, backend: self, leftInset: self.currentInsets.left, rightInset: self.currentInsets.right)
                }
            }
            // Neighbors are a function of final adjacency, so they are computed once the array has
            // settled rather than per-operation. Same index bases as ListView.neighbors(at:) — the
            // backend feeds items in ListView index order.
            for index in 0 ..< updated.count {
                updated[index].neighbors = ListViewItemNeighbors(
                    previous: index == 0 ? nil : updated[index - 1].listItem.neighborDescriptor,
                    next: index == updated.count - 1 ? nil : updated[index + 1].listItem.neighborDescriptor
                )
            }
            self.entries = updated
        }

        // A horizontal inset change is a content change for every row: the item lays itself out
        // against leftInset/rightInset, so the entries are re-pinned and re-submitted. Identity and
        // stable version are preserved, so each row reconciles as a survivor whose content changed and
        // reaches its host with the pass transition — the same path an edited message takes, and the
        // reason the move animates at all. Cheap and rare: it runs when a sidebar opens or closes.
        let sideInsetsChanged = self.currentInsets.left != previousSideInsets.left
            || self.currentInsets.right != previousSideInsets.right
        if sideInsetsChanged && !self.entries.isEmpty {
            self.entries = self.entries.map {
                $0.withSideInsets(left: self.currentInsets.left, right: self.currentInsets.right)
            }
        }

        // The row's placement can depend on its own measured height (bottom-align, center,
        // make-visible), and on a history jump the target is not loaded — the entries array was
        // replaced wholesale — so the backend cannot measure it. CoreList measures the anchor as the
        // first act of its window build and calls back here at that point. See pointOffset(for:...).
        var scrollTo: CoreListScrollTarget?
        if let scrollToItem, !self.entries.isEmpty {
            // buildWindow traps on an out-of-range anchor; ListViewImpl instead no-ops silently when
            // no node carries the index, so clamp rather than crash on a stale index.
            let index = min(max(scrollToItem.index, 0), self.entries.count - 1)
            let position = scrollToItem.position
            // ListViewImpl's `.Down` pins the old content's bottom to the new content's top, so the
            // new content arrives from higher indices — CoreList's `.forward`. Chat's index space is
            // reversed (0 = newest), which is why ChatHistoryViewForLocation.swift:59 picks `.Down`
            // for an older target. The hint only decides a travel CoreList cannot witness itself.
            let direction: CoreListScrollTarget.Direction
            switch scrollToItem.directionHint {
            case .Down:
                direction = .forward
            case .Up:
                direction = .backward
            }
            scrollTo = CoreListScrollTarget(index: index, direction: direction) { [weak self] height, view in
                guard let self else {
                    return 0.0
                }
                return self.pointOffset(for: position, index: index, height: height, view: view)
            }
        }

        // The applied animation and the reported transition are one value, so they cannot drift.
        // Mirrors ListViewImpl's own precedence: an animated scrollToItem wins, then a
        // size/inset update's curve, then an insertion animation.
        var transition: CoreListTransition = .immediate
        if let scrollToItem, scrollToItem.animated {
            // ListViewImpl's own switch (Display/Source/ListView.swift:3611-3618) rather than one
            // flat spring; `.Default` resolves a nil duration to 0.3 exactly as it does there. A
            // zero duration lands immediate, because CoreList reads 0 as immediate.
            switch scrollToItem.curve {
            case let .Spring(duration):
                transition = .spring(duration: duration)
            case let .Default(duration):
                // UIKit's **scroll-to-top** animation, not `setContentOffset(_:animated:)`.
                //
                // Both are real UIScrollView curves and they are nothing alike. `.uiKitScroll` is
                // `sin²(t·π/2)` over a FIXED 0.3s regardless of distance, which is right for a short
                // `scrollRectToVisible` nudge and reads as a snap over a chat-sized jump — which is
                // exactly why UIKit does not use it for scroll-to-top either. `.uiKitSmoothDeceleration`
                // is the critically damped spring UIKit installs for a status-bar tap, and it is the
                // one a "scroll there" gesture in a long list should feel like.
                //
                // A caller-supplied duration still wins; nil takes CoreList's 1.15s default (the
                // same curve as UIKit's 1.6s settle, replayed ~1.39x faster — see
                // `coreListSmoothDecelerationDefaultDuration`).
                transition = duration.map { .uiKitSmoothDeceleration(duration: $0) }
                    ?? .uiKitSmoothDeceleration()
            case let .Custom(duration, x1, y1, x2, y2):
                transition = .init(animation: .curve(duration: duration,
                                                     curve: .custom(x1, y1, x2, y2)))
            }
        } else if let updateSizeAndInsets, updateSizeAndInsets.duration != 0.0 {
            switch updateSizeAndInsets.curve {
            case let .Spring(duration):
                transition = .spring(duration: duration)
            case let .Default(duration):
                // `.Default` carries an optional duration; ListViewImpl resolves it as
                // max(updateSizeAndInsets.duration, duration ?? 0.3), so mirror that rather than
                // inventing a different default.
                transition = .easeInOut(duration: max(updateSizeAndInsets.duration,
                                                      duration ?? 0.3))
            case let .Custom(duration, x1, y1, x2, y2):
                transition = .init(animation: .curve(duration: duration, curve: .custom(x1, y1, x2, y2)))
            }
        } else if let customAnimationTransition,
                  case let .animated(duration, curve) = customAnimationTransition.legacyAnimator.transition,
                  duration != 0.0 {
            // An ITEM asking for a specific transition, which is a more specific statement than the
            // generic insertion animation below and therefore outranks it.
            //
            // This is the streaming path, and dropping it was visible. A content node re-measuring
            // itself calls `requestFullUpdate(ControlledTransition(duration: 0.15, curve: .easeInOut))`
            // (ChatMessageRichDataBubbleContentNode.swift:1092/:1207/:1224, and the text node's three
            // siblings), which reaches `requestMessageUpdate` and arrives here as
            // `customAnimationTransition` with `options: [.AnimateInsertion, .Synchronous]` and no
            // `scrollToItem`/`updateSizeAndInsets` (ChatHistoryListNode.swift:4920/:4941). Ignoring it
            // ran the ROW on the `.AnimateInsertion` fallback — spring over 0.4s — while the node
            // animated its own internals over 0.15s ease-in-out: a 2.7x duration difference and a
            // different curve, so the node's content settled while its own row was still travelling.
            // On a streaming bubble that re-fires per token, and it reads as the bubble wobbling.
            //
            // NOTE this is the standalone parameter, NOT `ListViewUpdateSizeAndInsets`'s field of the
            // same name — the floating-topics side panel sets THAT one
            // (ChatControllerNode.swift:2619) and reaches the `updateSizeAndInsets` branch above, so
            // it is unaffected. The two were previously conflated, which is how this producer came to
            // be recorded as "the chat sets it in exactly one place".
            switch curve {
            case .easeInOut:
                transition = .easeInOut(duration: duration)
            case .easeIn:
                transition = .init(animation: .curve(duration: duration, curve: .easeIn))
            case .linear:
                // `.linear(duration:)` is a CoreListDemoTests convenience, not shipping API.
                transition = .init(animation: .curve(duration: duration, curve: .linear))
            case .spring, .customSpring:
                // CoreList has one spring; `.customSpring`'s mass/stiffness/damping have no analogue,
                // so it degrades rather than silently rendering as a bezier of the wrong shape.
                transition = .spring(duration: duration)
            case let .custom(x1, y1, x2, y2):
                transition = .init(animation: .curve(duration: duration, curve: .custom(x1, y1, x2, y2)))
            }
        } else if options.contains(.AnimateInsertion) {
            transition = .spring(duration: 0.4)
        }

        // `additionalScrollDistance` displaces content by a caller-chosen delta in the same pass that
        // re-insets it — positive moves content DOWN, composing with the inset compensation rather
        // than replacing it. ListViewImpl folds it into the very same `offsetFix`
        // (Display/Source/ListView.swift:3275) and CoreList folds it into the same anchor projection,
        // so both animate it on the pass curve as one movement.
        //
        // Two deliberate divergences from ListViewImpl, neither reachable from the chat's producer:
        //   • ListViewImpl applies the delta ONLY inside the branch where the size or insets genuinely
        //     changed, and silently drops it otherwise (the addend sits inside
        //     `if let updateSizeAndInsets` at ListView.swift:3257). Here a non-zero delta always moves
        //     content, which is what the parameter means. Every real producer pairs it with an
        //     `updateSizeAndInsets` that does change geometry, so the two agree in practice.
        //   • The halt for a non-zero delta lives inside `applyChanges`, so it needs the pass to run;
        //     ListViewImpl halts before deciding anything (ListView.swift:3238). Same reachability
        //     argument — a delta with nothing else to do would be a layout pass that changes nothing.
        //
        // NOTE the chat never sends a non-zero value: `ChatControllerNode.containerLayoutUpdated`
        // declares `let additionalScrollDistance: CGFloat = 0.0` (ChatControllerNode.swift:2451) and has
        // since the first commit, and `ChatHistoryListNodeImpl.updateLayout` zeroes it again whenever
        // the live sibling `scrollToTop` is set. This exists so the two backends answer a non-zero value
        // the same way if one is ever wired up — it is not load-bearing today.

        // An inset change arriving mid-drag was produced by the drag itself (see `isTracking`), so its
        // compensation would double the finger's travel. Suppressing it leaves the scroll as the single
        // owner of the movement — ListViewImpl's `offsetFix = 0.0` while tracking
        // (Display/Source/ListView.swift:3276). The insets themselves still apply, so the viewport band,
        // the load band, content width and the loaded-top pin all move: at the newest-message edge the pin
        // keeps index 0 on the inset edge, which is how the bottom of the chat still follows the keyboard
        // down under suppression. Note the read happens HERE rather than inside CoreList, so the value is
        // the one that held when this transaction was submitted even if `applyChanges` defers it past a
        // re-entrant pass.
        //
        // Cancelling the compensation with `additionalScrollDistance: -topInsetDelta` would look
        // equivalent and is not: a non-zero distance halts momentum and opts the pass out of
        // `pinsLoadedTop`, so the newest message would stop tracking the inset edge — the one case that
        // must keep working.
        let compensatesInsetChange = !self.isTracking

        // `.RequestItemInsertionAnimations` means the LIST must not animate these arrivals: on
        // ListViewImpl it hands the insertion animation to the node
        // (Display/Source/ListView.swift:2867-2870 → `forceAnimateInsertion`), and the chat's send
        // morph then cancels that node animation. CoreList has no node-animation step — its arrival
        // animation is the entering row's own opacity track, on the host view — so the same
        // statement lands as "do not fade". Without it the bubble is cross-faded twice: once by the
        // morph carrying it out of the input field, once by the list underneath.
        //
        // The chat sets this flag on exactly one path, the fast send
        // (Chat/ChatControllerLoadDisplayNode.swift:938), and drops it under `disableAnimations`
        // (ChatHistoryListNode.swift:2090, :2539) — where the pass is immediate and fades nothing
        // anyway, so the default is the right answer there.
        let animatesInsertions = !options.contains(.RequestItemInsertionAnimations)

        if structurallyChanged || sizeChanged || scrollTo != nil || additionalScrollDistance != 0.0 {
            self.coreList.applyChanges(
                items: (structurallyChanged || sideInsetsChanged) ? self.entries : nil,
                newSize: self.currentSize == .zero ? nil : self.currentSize,
                // Vertical only — see `coreListInsets`.
                newInsets: self.coreListInsets,
                scrollTo: scrollTo,
                additionalScrollDistance: additionalScrollDistance,
                anchorMode: stationaryItemRange == nil ? .automatic : .preserveVisibleContent,
                compensatesInsetChange: compensatesInsetChange,
                animatesInsertions: animatesInsertions,
                transition: transition
            )
        }

        // Messages arriving at the newest edge slide in from beyond it, rather than fading into place
        // where they will sit. This is `ListViewImpl`'s behaviour, though not by its mechanism:
        // `ChatMessageItemView.animateInsertion` (ChatMessageItemView.swift:712) does it by displacing
        // the node's own `transitionOffset`, and BOTH halves of that are inert here — the setter
        // early-outs under `hostOwnsFrame` (ListViewItemNode.swift:275), which `rebuild` sets on every
        // hosted node, and `addTransitionOffsetAnimation` is advanced only by `ListViewImpl`'s display
        // link (ListView.swift:4823), which CoreList has no equivalent of. Calling `animateInsertion`
        // here would compile, run, and animate nothing.
        //
        // So it is a CoreList track instead, and it must be one: an additive position animation added
        // to the row's layer directly would be read back as a CoreList track by
        // `capturePresentedPositionOffsets()` at the next pass, and a second message landing mid-slide
        // would resume against a displacement the model never issued.
        if let arrivingStableIds = self.arrivingBlockStableIds(
            deleteIndices: deleteIndices,
            insertIndicesAndItems: insertIndicesAndItems,
            previousEntryCount: previousEntryCount,
            options: options
        ) {
            // `.beforeBlock` is content order, not screen: index 0 is the NEWEST message and sits at
            // the start of CoreList's content, which the wrapper's π renders at the visual bottom. So
            // travelling forward from before index 0 is the block rising from under the input panel.
            self.coreList.animateInsertedBlock(identities: arrivingStableIds,
                                               origin: .beforeBlock,
                                               transition: transition)
        }

        // Transaction end is where programmatic movement is reported: setOffset / applyShift /
        // setEdges are isProgrammatic-guarded in UIKitScrollEngine so a scrollTo fires no onScroll, and
        // the additive viewport track moves content with no engine offset change at all. Structural and
        // size/inset passes move content the same way. ListViewImpl likewise calls
        // updateVisibleContentOffset at its transaction points rather than relying on the scroll
        // callback.
        //
        // The transition mirrors the animation applied above. ContainedViewLayoutTransitionCurve has no
        // .easeOut, so the standard ease-out bezier approximates CoreList's .easeOut(0.3); this is
        // cosmetic, since consumers use the transition only to co-animate their own chrome.
        //
        // `.settled` is load-bearing, and this is the ONLY emission point that is not per-frame. The
        // pass has been submitted but its animation has not moved anything yet, so the presented value
        // here is the PRE-animation position — and no per-frame hook exists to correct it, since
        // `onVisibleWindowChanged` fires only on user scrolls. Reporting presented therefore leaves the
        // consumer wrong until the user next drags: tapping scroll-to-bottom left the button on screen
        // (the emission described where the jump started), and opening the keyboard at the bottom of a
        // chat made it appear (mid-inset-animation the emission read ~98pt against a settled 0, past the
        // 40pt `minOffsetForNavigation` threshold in ChatControllerLoadDisplayNode.swift:5393).
        //
        // Settled is also what ListViewImpl reports at its equivalent points, and it is self-correcting
        // in the one case where the two disagree for a reason — a transaction landing mid-fling — because
        // the next scroll frame re-reports presented.
        let offsetTransition: ContainedViewLayoutTransition = ComponentTransition(transition).containedViewLayoutTransition
        self.updateVisibleItemRange(force: false)
        self.updateVisibleContentOffset(transition: offsetTransition, geometry: .settled)
        // On the pass transition, so the item's re-centring travels with the content-height or inset
        // change that moved it. `ListViewImpl` derives snapToBounds' transition from the same two
        // producers (`updateSizeAndInsets`/`scrollToItem`); this value additionally covers the
        // `customAnimationTransition` and insertion arms, which is the better answer for a quantity
        // that is a pure function of the content height those arms are animating.
        self.updateTrailingItemSpace(transition: offsetTransition)
        self.pushHeaderFlashingState(animated: false)
        completion(self.displayedItemRange)
    }

    /// The stable ids of a transaction that is a plain arrival at the newest edge, or nil when it is
    /// anything else. Feeds the entering-block slide above.
    ///
    /// Positional rather than by message direction: a bot's reply, a message from another peer and one
    /// you sent from a second device all land the same way, and the backend deals in stableIds and
    /// `ListViewItem`s rather than in message semantics. The one arrival it must NOT claim is the local
    /// fast send, which is what `.RequestItemInsertionAnimations` names — there the send morph is
    /// already carrying the bubble out of the input field, and it is the same flag that suppresses
    /// `animatesInsertions` a few lines above, for the same reason.
    private func arrivingBlockStableIds(
        deleteIndices: [ListViewDeleteItem],
        insertIndicesAndItems: [ChatHistoryListViewInsertItem],
        previousEntryCount: Int,
        options: ListViewDeleteAndInsertOptions
    ) -> [AnyHashable]? {
        guard !insertIndicesAndItems.isEmpty else {
            return nil
        }
        // **An arrival normally DOES delete something.** The history view is a sliding window of
        // bounded size, so a message landing at the newest edge pushes the oldest one out of the view
        // in the same transaction — and `entries[0]` is the newest, so that departure is at the far
        // END of the old array. Requiring no deletes at all rejects nearly every real arrival; what
        // disqualifies one is a departure ANYWHERE ELSE, which is a message being removed rather than
        // the window sliding.
        //
        // Updates are not disqualifying either, and that is the load-bearing half of the same point: a
        // message from the author who sent the one before it changes that bubble's merge state, so the
        // commonest arrival of all carries an update alongside its insert.
        let deletedIndices = deleteIndices.map { $0.index }.sorted()
        guard deletedIndices.count <= previousEntryCount else {
            return nil
        }
        guard deletedIndices == Array((previousEntryCount - deletedIndices.count) ..< previousEntryCount) else {
            return nil
        }
        guard !options.contains(.RequestItemInsertionAnimations) else {
            return nil
        }
        // Everything arriving at once is a population — opening a chat, a hole reload — not messages
        // coming in. Those passes are immediate today, so this is a belt on top of the transition
        // check inside `animateInsertedBlock`, but a full replace should never slide even if one
        // acquires a curve.
        guard insertIndicesAndItems.count < self.entries.count else {
            return nil
        }
        // Contiguous and anchored at the newest edge. An insert further in is history being filled in
        // around what is already there.
        let indices = insertIndicesAndItems.map { $0.index }.sorted()
        guard indices == Array(0 ..< insertIndicesAndItems.count) else {
            return nil
        }
        return Array(insertIndicesAndItems.reversed().map { AnyHashable($0.stableId) })
    }

    // Parity with ListViewImpl.immediateDisplayedItemRange (ListView.swift:4683). loadedRange is the
    // settled window's index span; visibleRange is the sub-span actually intersecting the viewport
    // band. Items are fed in ListView index order and the hosted view is π-counter-rotated, so indices
    // map straight through.
    //
    // Deliberate divergence: ListViewImpl's first-visible scan tests
    // `minY < visibleSize.height + insets.bottom` (ListView.swift:4711) while its last-visible scan
    // tests `minY < visibleSize.height - insets.bottom` (4723). The `+` looks like an upstream typo, so
    // both scans here use the symmetric `- insets.bottom` (i.e. `visibleBand.bottom`). The `- 10.0`
    // fully-visible tolerance is reproduced verbatim.
    private func immediateDisplayedItemRange() -> ListViewDisplayedItemRange {
        guard let range = self.coreList.loadedIndexRange else {
            return ListViewDisplayedItemRange(loadedRange: nil, visibleRange: nil)
        }
        let loadedRange = ListViewItemRange(firstIndex: range.first, lastIndex: range.last)
        let band = self.visibleBand

        var firstVisible: (index: Int, fullyVisible: Bool)?
        var lastVisibleIndex: Int?
        for entry in self.coreList.loadedItemEntries {
            let frame = self.listFrame(of: entry.view)
            if frame.maxY >= band.top && frame.minY < band.bottom {
                if firstVisible == nil {
                    firstVisible = (entry.index, frame.minY >= band.top - 10.0)
                }
                lastVisibleIndex = entry.index
            }
        }

        var visibleRange: ListViewVisibleItemRange?
        if let firstVisible = firstVisible, let lastVisibleIndex = lastVisibleIndex {
            visibleRange = ListViewVisibleItemRange(
                firstIndex: firstVisible.index,
                firstIndexFullyVisible: firstVisible.fullyVisible,
                lastIndex: lastVisibleIndex
            )
        }
        return ListViewDisplayedItemRange(loadedRange: loadedRange, visibleRange: visibleRange)
    }

    // Fires visibleContentOffsetChanged. ListViewImpl's namesake also fires
    // visibleBottomContentOffsetChanged, but ChatHistoryListViewBackend has no such member: the bottom
    // offset has no per-frame consumer in chat at all, and its one caller pulls it through
    // settledContentOffsets().
    //
    // `geometry` is `.settled` at the transaction point and `.presented` on the scroll path — see
    // OffsetGeometry, and the call sites for why each is the one that consumers can act on.
    private func updateVisibleContentOffset(transition: ContainedViewLayoutTransition, geometry: OffsetGeometry) {
        let value = self.visibleContentOffset(geometry)
        self.visibleContentOffsetChanged(value, transition)
    }

    func addAfterTransactionsCompleted(_ f: @escaping () -> Void) { f() }
    // Parity with ListViewImpl.visibleContentOffset (ListView.swift:1380). `.known` is reserved for
    // when the list's TOP edge is loaded — i.e. the settled window starts at collection index 0 — and
    // the value is that row's distance from the top inset edge, negated: 0 means index 0 sits flush
    // against insets.top, positive means scrolled away from it. An empty window is `.none`; a loaded
    // window that does not reach index 0 is `.unknown`.
    //
    // Never fabricate `.known`: chat reads `abs(offset) <= 0.9` as "pinned to the newest message"
    // (ChatHistoryListNode.swift:2425) and short-circuits scrollToEndOfHistory on
    // `value <= ulpOfOne` (3690).
    //
    // ListViewImpl also folds in the minY of removed-but-still-animating nodes above the top item;
    // that has no analogue here, because CoreList departures live in the exitOverlay and never appear
    // in the loaded window.
    //
    // Measured against `currentInsets.top`, which EXCLUDES `overscrollHoldDistance` — so while the
    // overscroll action holds the newest edge open this reports `.known(-distance)`, the same thing
    // ListViewImpl reports when `scroller.contentInset` holds its content down. That is load-bearing
    // rather than incidental: `maybeUpdateOverscrollAction` keeps the control alive only while the
    // offset stays below -0.1 and sizes it from that value, so folding the hold in here would
    // dismiss the control at the instant it is supposed to be held on screen — and, once the hold
    // was released back to zero, would leave a permanent apparent overscroll that rebuilt the
    // control on every emission and never removed it.
    func visibleContentOffset() -> ListViewVisibleContentOffset {
        return self.visibleContentOffset(.presented)
    }

    private func visibleContentOffset(_ geometry: OffsetGeometry) -> ListViewVisibleContentOffset {
        guard let range = self.coreList.loadedIndexRange else {
            return .none
        }
        guard range.first == 0, let frame = self.loadedFrame(atIndex: 0, geometry) else {
            return .unknown
        }
        return .known(-(frame.minY - self.currentInsets.top))
    }

    // Both offsets in the settled geometry — see the protocol declaration for why they are one member.
    // The two are read back-to-back with no pass in between, so they cannot straddle an animation
    // boundary.
    func settledContentOffsets() -> (top: ListViewVisibleContentOffset, bottom: ListViewVisibleContentOffset) {
        return (self.visibleContentOffset(.settled), self.visibleBottomContentOffset(.settled))
    }

    // Parity with ListViewImpl.visibleBottomContentOffset (ListView.swift:1412): `.known` only when the
    // list's BOTTOM edge is loaded (the window ends at the last entry). Note this one is NOT negated —
    // both offsets read as "how much content lies beyond that visible edge", positive = more hidden.
    //
    // Private, unlike its `visibleContentOffset()` sibling: nothing in the chat asks this question
    // per-frame, so it is reached only through `settledContentOffsets()` and the raw member is off the
    // backend contract entirely.
    private func visibleBottomContentOffset(_ geometry: OffsetGeometry) -> ListViewVisibleContentOffset {
        guard let range = self.coreList.loadedIndexRange else {
            return .none
        }
        guard range.last == self.entries.count - 1, let frame = self.loadedFrame(atIndex: range.last, geometry) else {
            return .unknown
        }
        return .known(frame.maxY - (self.currentSize.height - self.currentInsets.bottom))
    }
    func transferVelocity(_ velocity: CGFloat) {}
    func resetScrolledToItem() {}

    // ListViewImpl guards each node on `index != nil` to skip removed-but-still-animating nodes.
    // CoreList needs no analogue: genuine departures are transferred to the non-interactive
    // exitOverlay as ghost blocks and are never returned by loadedItemViews, so every loaded row is
    // live. The only exclusion is a host view whose node has not been built yet, which `itemNodes`
    // already performs.
    func forEachItemNode(_ f: (ASDisplayNode) -> Void) {
        for itemNode in self.itemNodes {
            f(itemNode)
        }
    }

    // Mirrors ListViewImpl.forEachVisibleItemNode: intersect each loaded row against the
    // inset-reduced viewport band. CoreList's loaded window is viewport *plus preload margin*, so
    // "loaded" is not "visible" — over-reporting here would play sound for off-screen video and fire
    // read tracking / unseen-reaction animations for messages the user cannot see.
    //
    // Geometry comes from `listFrame(of:)`, i.e. CoreList's `presentedFrame(of:)`: the frames must be
    // where the rows ARE, not their settled endpoints. Reporting settled geometry mid-fling would fire
    // read tracking and unseen-reaction animations for whatever is visible at the flight's DESTINATION,
    // since the host layer is parked there for the flight's whole duration.
    //
    // See `visibleBand` for why the band reads currentSize/currentInsets.
    func forEachVisibleItemNode(_ f: (ASDisplayNode) -> Void) {
        let band = self.visibleBand
        for hostView in self.itemNodeHostViews {
            guard let itemNode = hostView.itemNode else {
                continue
            }
            let frame = self.listFrame(of: hostView)
            if frame.maxY > band.top && frame.minY < band.bottom {
                f(itemNode)
            }
        }
    }

    // Same set as forEachItemNode, in the same ascending-index order (which ListViewImpl's callers
    // depend on), stopping at the first `f` returning false.
    func enumerateItemNodes(_ f: (ASDisplayNode) -> Bool) {
        for itemNode in self.itemNodes {
            if !f(itemNode) {
                break
            }
        }
    }
    // Backed by CoreList's own live attachment set — see itemHeaderNodes in
    // CoreListChatHistoryHeaders.swift.
    //
    // THREE chat consumers, and the third does not name this file: the live theme/presentation
    // update (ChatHistoryListNode.swift:2649), the chat-loading fade-in (:4418), and
    // `ChatController.updateItemNodesSelectionStates` (ChatController.swift:8382), which reaches
    // this through the wrapper's forwarder (`historyNode.forEachItemHeaderNode`) and is what
    // animates the gutter avatars into and out of selection mode. Grepping for `listView
    // .forEachItemHeaderNode` finds the first two and misses the third — which is how this backend
    // briefly grew a duplicate driver for that same push. See the selection-mode note under
    // `itemHeaderNodes` in CoreListChatHistoryHeaders.swift for what that cost.
    func forEachItemHeaderNode(_ f: (ListViewItemHeaderNode) -> Void) {
        for node in self.itemHeaderNodes {
            f(node)
        }
    }

    // ListViewImpl's own body (Display/Source/ListView.swift:5159-5199) with four substitutions: the
    // index comes from loadedIndex(of:) because a hosted node carries no ListView index; the node's
    // frame comes from loadedFrame(of:), which is list-space and presented rather than host-local;
    // apparentHeight is that rect's height; and the geometry is currentSize/currentInsets.
    //
    // Every branch issues its scroll through chatHistoryTransaction, exactly as ListViewImpl issues
    // its own through self.transaction — one code path, and the "already visible, do nothing" shape
    // is preserved by simply not reaching a branch.
    func ensureItemNodeVisible(_ node: ListViewItemNode, animated: Bool, overflow: CGFloat, allowIntersection: Bool, atTop: Bool, curve: ListViewAnimationCurve) {
        guard let index = self.loadedIndex(of: node), let frame = self.loadedFrame(of: node) else {
            return
        }
        let viewportHeight = self.currentSize.height
        let insetTop = self.currentInsets.top
        let insetBottom = self.currentInsets.bottom

        func scroll(to position: ListViewScrollPosition, directionHint: ListViewScrollToItemDirectionHint) {
            self.chatHistoryTransaction(
                deleteIndices: [],
                insertIndicesAndItems: [],
                updateIndicesAndItems: [],
                options: ListViewDeleteAndInsertOptions(),
                scrollToItem: ListViewScrollToItem(index: index,
                                                   position: position,
                                                   animated: animated,
                                                   curve: curve,
                                                   directionHint: directionHint),
                additionalScrollDistance: 0.0,
                updateSizeAndInsets: nil,
                stationaryItemRange: nil,
                customAnimationTransition: nil,
                updateOpaqueState: nil,
                completion: { _ in }
            )
        }

        if frame.height > viewportHeight - insetTop - insetBottom {
            if atTop {
                if frame.maxY > viewportHeight - insetBottom {
                    scroll(to: .top(-overflow), directionHint: .Down)
                } else if frame.minY < insetTop && overflow > 0.0 {
                    scroll(to: .top(-overflow), directionHint: .Up)
                }
            } else {
                if frame.maxY > viewportHeight - insetBottom {
                    scroll(to: .bottom(-overflow), directionHint: .Down)
                } else if frame.minY < insetTop && overflow > 0.0 {
                    scroll(to: .top(-overflow), directionHint: .Up)
                }
            }
        } else if self.experimentalSnapScrollToItem {
            scroll(to: .visible, directionHint: .Up)
        } else if frame.minY < insetTop + overflow {
            if !allowIntersection || frame.maxY < insetTop {
                scroll(to: allowIntersection ? .center(.top) : .top(overflow), directionHint: .Up)
            }
        } else if frame.maxY > viewportHeight - insetBottom - overflow {
            if !allowIntersection || frame.minY > viewportHeight - insetBottom {
                scroll(to: allowIntersection ? .center(.bottom) : .bottom(-overflow), directionHint: .Down)
            }
        }
    }

    // Parity with ListViewImpl.updateVisibleItemRange (ListView.swift:4673): recompute, and fire
    // displayedItemRangeChanged only when the range actually changed (or when forced). This is the one
    // place displayedItemRange is written. The mirror is committed before the callback fires, so a
    // callback that triggers another update sees the settled value instead of recursing.
    func updateVisibleItemRange(force: Bool) {
        let currentRange = self.immediateDisplayedItemRange()
        if currentRange != self.internalDisplayedItemRange || force {
            self.displayedItemRange = currentRange
            self.internalDisplayedItemRange = currentRange
            self.displayedItemRangeChanged(currentRange, self.opaqueTransactionState)
        }
    }
    // Parity with the trailing-item-space block of ListViewImpl.snapToBounds
    // (Display/Source/ListView.swift:1345-1357).
    //
    // WHAT IT IS. When the whole collection is on screen with room to spare, the list tells its LAST
    // item how much empty viewport lies beyond it, and the item may move its own content into that
    // space. The three chat items that opt in (`wantsTrailingItemSpaceUpdates`) all do the same thing
    // with it: shift their content container by half the space, which centres the block in the gap.
    // `ChatBotInfoItemNode` and `ChatUserInfoItemNode` set the flag in `init`; a message bubble sets it
    // per-layout, for the centred-link `.messageOptions` preview only.
    //
    // WHICH ITEM. `items.count - 1`, i.e. the OLDEST entry (index 0 is the newest — see
    // `arrivingBlockStableIds`), which the wrapper's π renders at the top of the screen with the free
    // space above it. The offset the item applies is `y: -space/2` in its own coordinates, and its own
    // π composes with the wrapper's to identity, so that reads as "up the screen, into the gap".
    //
    // OFFSET-INDEPENDENT BY CONSTRUCTION, which is the property that makes it safe to call from the
    // scroll path: `settledContentHeight` is an intra-window height and `currentBottomEdgePinSlack` an
    // intra-window span, so a rubber-band overscroll on an underfilled list — the one kind of scrolling
    // that regime allows — cannot make the item drift. `ListViewImpl` computes the same quantity from
    // `visibleAreaHeight - completeHeight` for exactly this reason, rather than from where the last
    // node currently sits.
    //
    // THE PIN TERM. `ListViewImpl` measures the leftover against `effectiveInsets.top`, which
    // `calculatePinToEdgeTopInset` has already widened by the slack an unread separator needs to rest
    // on the far edge. CoreList spends that same slack in its underfill alignment (it places the window
    // on `viewportInsets.top + pinSlack`), so the gap really is smaller by that much and subtracting it
    // is geometry, not bookkeeping. In an underfilled chat the slack always exceeds the leftover — the
    // pin has pushed the oldest content off the far edge, taking the info item with it — so a short
    // chat with an unread separator reports zero and the item stays put. That is `ListViewImpl`'s
    // answer too.
    //
    // Insets come from `currentInsets`, which excludes `overscrollHoldDistance`, matching
    // `ListViewImpl` reading `self.insets` rather than `scroller.contentInset`. CoreList's slack is
    // computed against the held insets and so shrinks by the hold, leaving this up to the hold
    // distance too generous while an overscroll action is live. Unreachable in practice and invisible
    // if reached: it needs an underfilled chat that also has a pinned row, where the leftover is
    // already zero with margin.
    //
    // NOT `updateSizeAndInsets`-gated. The two call sites are the transaction end (where the geometry,
    // the entry set and the loaded window can all have changed) and the scroll callback, which is where
    // `ListViewImpl` reaches `snapToBounds` from as well. A CoreList self-update flush is NOT a third
    // site: `CoreListNodeHostView` declares `onContentDidChange` but never CALLS it — only the demo and
    // test rows do — so a chat row that re-measures itself comes back through `chatHistoryTransaction`
    // as `customAnimationTransition` like any other content change, and there is no path that changes a
    // row's height behind this backend's back.
    private func updateTrailingItemSpace(transition: ContainedViewLayoutTransition) {
        guard let lastIndex = self.entries.indices.last else {
            return
        }
        // Mirrors ListViewImpl's `bottomItemNode`: resolved only when the collection's last entry is
        // itself loaded, so an unloaded last item gets no call at all rather than a fabricated zero.
        guard let hostView = self.coreList.loadedItemView(at: lastIndex) as? CoreListNodeHostView,
              let itemNode = hostView.itemNode,
              itemNode.wantsTrailingItemSpaceUpdates else {
            return
        }

        var trailingItemSpace: CGFloat = 0.0
        // `topItemFound && bottomItemFound`: the leftover is only meaningful when the window spans the
        // WHOLE collection, since `settledContentHeight` measures the loaded window and nothing more.
        if let loadedRange = self.coreList.loadedIndexRange,
           loadedRange.first == 0,
           loadedRange.last == lastIndex {
            let visibleAreaHeight = self.currentSize.height
                - self.currentInsets.top
                - self.currentInsets.bottom
                - self.coreList.currentBottomEdgePinSlack
            let completeHeight = self.coreList.settledContentHeight
            if visibleAreaHeight > completeHeight {
                trailingItemSpace = visibleAreaHeight - completeHeight
            }
        }
        // The zero is as load-bearing as the positive value: it is what RESETS an item that was
        // centred by an earlier pass once the content has grown past the viewport.
        itemNode.updateTrailingItemSpace(trailingItemSpace, transition: transition)
    }

    // ListViewImpl scans its item nodes for `index == index`; hosted nodes can never carry a ListView
    // index, so resolve through CoreList, which owns activeWindow and is the authority on the
    // index ↔ view mapping. `index` is in the same space as `self.entries` — which is also the space
    // the one caller uses (ChatHistoryListNode's ad-message anchors, built as
    // `filteredEntries.count - 1 - i`).
    func itemNodeAtIndex(_ index: Int) -> ListViewItemNode? {
        return (self.coreList.loadedItemView(at: index) as? CoreListNodeHostView)?.itemNode
    }

    // Parity with ListViewImpl's `node.frame.minY - insets.top`.
    //
    // The convention is load-bearing: this value is persisted as
    // ChatInterfaceHistoryScrollState.relativeOffset and restored as
    // ListViewScrollToItem(position: .top(offset)), which ListViewImpl resolves to
    // `frame.minY == insets.top + offset` — the exact inverse. CoreList's scrollTo pointOffset uses
    // the identical convention (screen target = viewportInsets.top + pointOffset), so no unit
    // conversion is needed here. Both sides are live: the restore path resolves `.top(offset)`
    // through pointOffset(for:index:height:view:).
    func itemNodeRelativeOffset(_ node: ListViewItemNode) -> CGFloat? {
        guard let frame = self.loadedFrame(of: node) else {
            return nil
        }
        return frame.minY - self.currentInsets.top
    }

    // The loaded row's rect in list space — what `ListViewItemNode.frame` means on ListViewImpl and
    // does NOT mean here, since a hosted node's view sits at (0, 0, width, height) inside its host.
    // Chat-layer geometry must go through this rather than the node's own frame.
    func itemNodeFrame(_ node: ListViewItemNode) -> CGRect? {
        return self.loadedFrame(of: node)
    }

    func itemHeaderNodeFrame(_ node: ListViewItemHeaderNode) -> CGRect? {
        // The attachment-side `loadedFrame(of:)`. `loadedAttachmentViews` is the live set, so absence
        // from it IS the liveness guard — same argument `itemHeaderNodes` makes.
        for view in self.coreList.loadedAttachmentViews {
            if let hostView = view as? CoreListHeaderHostView, hostView.headerNode === node {
                return self.listFrame(of: hostView)
            }
        }
        return nil
    }

    // Same predicate as forEachVisibleItemNode's filter, via the shared band.
    func itemNodeVisibleInsideInsets(_ node: ListViewItemNode) -> Bool {
        guard let frame = self.loadedFrame(of: node) else {
            return false
        }
        let band = self.visibleBand
        return frame.maxY > band.top && frame.minY < band.bottom
    }
    // Was a hard `false` for the PoC, which disabled the whole pin-to-edge mechanic AND routed every
    // send down the `scrollToItem` branch (see "Send animation" in
    // docs/chat/corelist-chat-history-backend.md).
    func isStrictlyScrolledToPinToEdgeItem() -> Bool {
        return self.coreList.isStrictlyPinnedToBottomEdge
    }
    func scrollWithDirection(_ direction: ListViewScrollDirection, distance: CGFloat) -> Bool { return false }
}

// A CoreListItem wrapping a ListViewItem.
// `listItem` is the value content (a fresh instance on update). Reused views reconcile via apply(to:).
private final class CoreListEntryItem: CoreListItem {
    let stableId: UInt64
    let stableVersion: Int
    let listItem: ListViewItem
    // Descriptors published by the adjacent entries. Compared in isEqual(to:) so a row re-applies
    // when a neighbor changed, and passed into layout so merge/date decisions are correct.
    var neighbors: ListViewItemNeighbors

    // The chat's horizontal insets, carried on the item so that changing them is a CONTENT change:
    // `isEqual(to:)` compares them, so a sidebar opening reconciles every row and the pass transition
    // reaches each host. See `coreListInsets` for why they travel to the item instead of framing rows.
    let leftInset: CGFloat
    let rightInset: CGFloat

    // Built once here rather than computed on demand: CoreList consults `attachedItems` repeatedly
    // within a pass — `AttachmentRuns.pendingRuns` runs per row during stacking as well as once per
    // window build. It depends on the item's headers and on the side insets the headers lay out
    // against, so only a pass that changes one of those invalidates it — vertical geometry cannot.
    let attachedItems: [AnyHashable: CoreListAttachedItem]

    // Held for withSideInsets(left:right:), which has to rebuild `attachedItems`.
    private weak var backend: CoreListChatHistoryBackend?

    var identity: AnyHashable { AnyHashable(self.stableId) }

    // CoreList's analogue of the ListView flag, forwarded verbatim. Only `ChatMessageItemImpl`
    // implements it (from `ChatMessageEntryAttributes.pinToTop`), so this is true exactly for the
    // message the chat named in `pinToTopStableId`.
    //
    // It stays current without any invalidation of its own: the flag changes only when the entry's
    // attributes change, which always arrives as an `updateIndicesAndItems` entry — so the pass that
    // changes it is always one that re-submits `items:` to `applyChanges`.
    var pinsToBottomEdge: Bool { return self.listItem.pinToEdgeWithInset }

    init(stableId: UInt64,
         stableVersion: Int,
         listItem: ListViewItem,
         backend: CoreListChatHistoryBackend?,
         leftInset: CGFloat,
         rightInset: CGFloat,
         neighbors: ListViewItemNeighbors = .none) {
        self.stableId = stableId
        self.stableVersion = stableVersion
        self.listItem = listItem
        self.neighbors = neighbors
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.backend = backend

        var attachedItems: [AnyHashable: CoreListAttachedItem] = [:]
        if let headerItem = listItem as? ChatHistoryItemWithHeaders {
            for header in headerItem.headers {
                // A topic header — a date header carrying a separableThreadId — comes through here
                // like any other, keyed by its own id, and declares the stacking that keeps it clear
                // of that day's plain date header. See `CoreListHeaderAttachedItem.stackingYield`.
                attachedItems[AnyHashable(header.id)] = CoreListHeaderAttachedItem(header: header,
                                                                                  backend: backend,
                                                                                  leftInset: leftInset,
                                                                                  rightInset: rightInset)
            }
        }
        self.attachedItems = attachedItems
    }

    /// The same entry re-pinned to new side insets, preserving its identity and stable version so it
    /// reconciles as a survivor whose content changed rather than as a replacement.
    func withSideInsets(left: CGFloat, right: CGFloat) -> CoreListEntryItem {
        return CoreListEntryItem(stableId: self.stableId,
                                 stableVersion: self.stableVersion,
                                 listItem: self.listItem,
                                 backend: self.backend,
                                 leftInset: left,
                                 rightInset: right,
                                 neighbors: self.neighbors)
    }

    func view() -> UIView & CoreListItemView {
        return CoreListNodeHostView(listItem: self.listItem,
                                    neighbors: self.neighbors,
                                    leftInset: self.leftInset,
                                    rightInset: self.rightInset,
                                    rotated: self.backend?.rotated ?? true,
                                    backend: self.backend)
    }

    // Content equality: the engine matches rows by `identity` (= stableId); this additionally compares
    // `stableVersion` so a same-stableId entry whose content was swapped (a new stableVersion) is not
    // equal and reconfigures its reused view.
    func isEqual(to other: CoreListItem) -> Bool {
        guard let other = other as? CoreListEntryItem else {
            return false
        }
        if other.stableId != self.stableId {
            return false
        }
        if other.stableVersion != self.stableVersion {
            return false
        }
        if other.neighbors != self.neighbors {
            return false
        }
        // The row lays its content out against these, so a change is a content change.
        if other.leftInset != self.leftInset || other.rightInset != self.rightInset {
            return false
        }
        return true
    }

    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {
        (view as? CoreListNodeHostView)?.setListItem(self.listItem,
                                                     neighbors: self.neighbors,
                                                     leftInset: self.leftInset,
                                                     rightInset: self.rightInset,
                                                     transition: transition)
    }
}

// Hosts a ListViewItemNode's view inside CoreVirtualListView
private final class CoreListNodeHostView: UIView, CoreListItemView {
    private var listItem: ListViewItem
    private var neighbors: ListViewItemNeighbors
    fileprivate private(set) var itemNode: ListViewItemNode?
    private var lastWidth: CGFloat = -1.0
    private var lastHeight: CGFloat = 0.0
    private var contentDirty: Bool = true
    /// The enclosing pass's transition, held for the layout that follows and consumed by `rebuild`.
    ///
    /// Written by BOTH `setListItem` (reconciliation) and `update(width:transition:)` (every pass), in
    /// that order, so `rebuild` sees the `update` value. They agree by contract — CoreList makes the
    /// transition non-immediate only for a row whose content changed in the pass, which is the same
    /// row `setListItem` was called for. `update` writing it unconditionally is what keeps it from
    /// going stale: a later pass that rebuilds for a width change alone re-reads that pass's own
    /// (immediate) transition rather than replaying the last reconciliation's.
    private var pendingTransition: CoreListTransition = .immediate

    var onContentDidChange: ((_ animated: Bool) -> Void)? = nil

    // The chat's horizontal insets, handed to the hosted node as layout params rather than applied by
    // framing this view — see `coreListInsets`. They arrive through the item (they are part of its
    // content equality), so a sidebar opening reconciles every row and reaches `rebuild` with the
    // pass transition, which is what lets the ITEM animate its own content across the inset.
    private var leftInset: CGFloat
    private var rightInset: CGFloat

    init(listItem: ListViewItem, neighbors: ListViewItemNeighbors, leftInset: CGFloat, rightInset: CGFloat, rotated: Bool, backend: CoreListChatHistoryBackend?) {
        self.listItem = listItem
        self.neighbors = neighbors
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.rotated = rotated
        self.backend = backend
        super.init(frame: .zero)
    }

    // Held only to read `prefersSynchronousResourceLoading` at node-build time — see that property.
    // Weak for the same reason `CoreListEntryItem`'s reference is: the backend owns the list that
    // owns this view.
    private weak var backend: CoreListChatHistoryBackend?

    // Construction-only, like `rotated` on the backend itself: which end of the node's box is the
    // reserved space a non-`spansMemberInsets` attachment must not ride over. Verbatim
    // `self.rotated ? itemNode.insets.top : itemNode.insets.bottom`
    // (Display/Source/ListView.swift:4278) — the chat's rows fold `timestampHeaderHeight` into
    // `layoutInsets.top` and the node carries its own π, so under a rotated chat the header's
    // reservation is the node's TOP inset even though it renders at the visual bottom.
    private let rotated: Bool

    var attachmentBandTrim: CGFloat {
        guard let itemNode = self.itemNode else {
            return 0.0
        }
        return self.rotated ? itemNode.insets.top : itemNode.insets.bottom
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setListItem(_ item: ListViewItem,
                     neighbors: ListViewItemNeighbors,
                     leftInset: CGFloat,
                     rightInset: CGFloat,
                     transition: CoreListTransition) {
        self.listItem = item
        self.neighbors = neighbors
        self.leftInset = leftInset
        self.rightInset = rightInset
        self.pendingTransition = transition
        self.contentDirty = true
    }

    /// The most recent binding from CoreList, held for the same reason `visibleRect` is: the solve can
    /// name this row's attachments before `update(width:)` has built the node they belong on.
    private var attachedItems: [UIView & CoreListAttachedItemView] = []

    // CoreList answers "which attachments hang off this row"; the only translation left is attachment
    // host → header node. `setAttachedHeaderNodes` compares before notifying, which is what makes it
    // safe to receive this every solve — including the frames where nothing moved, and the frame after
    // a recycled view is handed a set for a different row.
    func attachedItemsUpdated(_ attachments: [UIView & CoreListAttachedItemView]) {
        self.attachedItems = attachments
        self.applyAttachedItems()
    }

    private func applyAttachedItems() {
        guard let itemNode = self.itemNode else {
            return
        }
        itemNode.setAttachedHeaderNodes(self.attachedItems.compactMap {
            ($0 as? CoreListHeaderHostView)?.headerNode
        })
    }

    /// The most recent rect from CoreList, held so a node built after the notification still gets it.
    private var visibleRect: CGRect?

    func visibleRectUpdated(_ visibleRect: CGRect?) {
        self.visibleRect = visibleRect
        self.applyVisibility()
    }

    // ListViewImpl's own formula (Display/Source/ListView.swift:4344) with the host's geometry:
    // `subRect` is the visible part in the row's own space, and `fraction` is that part's overlap
    // with the node's content box — the row minus its insets — over that box's height, which is what
    // `apparentContentFrame` gives ListViewImpl. Assign only on change: the property's didSet fans
    // out to every content node.
    private func applyVisibility() {
        guard let itemNode = self.itemNode else {
            return
        }
        var visibility: ListViewItemNodeVisibility = .none
        if let rect = self.visibleRect {
            let insets = itemNode.insets
            let contentTop = insets.top
            let contentBottom = self.lastHeight - insets.bottom
            let contentHeight = contentBottom - contentTop
            var fraction: CGFloat = 0.0
            if contentHeight > 0.0 {
                fraction = max(0.0, min(rect.maxY, contentBottom) - max(rect.minY, contentTop)) / contentHeight
            }
            visibility = .visible(fraction, rect)
        }
        if itemNode.visibility != visibility {
            itemNode.visibility = visibility
        }
    }

    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat {
        self.pendingTransition = transition
        if self.itemNode == nil || self.contentDirty || abs(width - self.lastWidth) > 0.5 {
            self.rebuild(width: width)
        }
        if let itemNode = self.itemNode {
            /*self.layer.borderColor = UIColor.blue.cgColor
            self.layer.borderWidth = 0.5

            itemNode.layer.borderColor = UIColor.red.cgColor
            itemNode.layer.borderWidth = 1.5*/

            // The node's box is applied by `rebuild`, before the item's own apply — see there for why
            // that ordering is load-bearing and why the pass transition animates it. This call is the
            // backstop for the passes that do NOT rebuild (an unchanged survivor, a fresh view), and it
            // no-ops whenever `rebuild` has already installed this frame.
            //
            // It reaches the layer at all only because of `ListViewItemNode.hostOwnsFrame`. Without
            // that, assigning `contentSize`/`insets` resized the node as a side effect, so this frame
            // was already installed by the time anything tried to animate to it and EVERY setter
            // no-oped on its equality guard — `itemNode.frame =`, `CoreListTransition.setFrame`,
            // `ContainedViewLayoutTransition.updateFrame(node:)`, `CALayer.animateFrame`. That is why
            // the box snapped under every variant tried before, and why the earlier experiment matrix
            // (snapped box vs animated box, against three different compensation displacements) was
            // one configuration wearing several labels: the box had never once moved.
            let itemNodeFrame = CGRect(x: 0.0, y: 0.0, width: width, height: self.lastHeight)
            transition.setFrame(view: itemNode.view, frame: itemNodeFrame)
        }
        return self.lastHeight
    }

    private func rebuild(width: CGFloat) {
        // Full row width plus separate side insets, exactly as ListViewImpl builds these params
        // (Display/Source/ListView.swift:2384). The alternative — folding the inset into `width` — was
        // what this did before, and it cannot animate: shrinking the node re-lays its content out at
        // the destination immediately, and the node's own π mirrors that content about a centre that
        // has itself jumped by half the inset.
        let params = ListViewItemLayoutParams(width: width, leftInset: self.leftInset, rightInset: self.rightInset, availableHeight: .greatestFiniteMagnitude, isStandalone: false)
        
        if let itemNode = self.itemNode {
            var layoutAndApply: (ListViewItemNodeLayout, (ListViewItemApply) -> Void)?
            // The pass transition, as the animation the item drives its OWN internals with. Outer
            // geometry is not animated from here — ListAnimationModel owns that. CoreList's item
            // contract already makes this non-immediate exactly when this row's content changed in the
            // pass (a reconciled survivor, or an animated self-update flush) and `.immediate` for fresh
            // views, scroll-in loads, unchanged survivors and off-screen remeasures, so there is no
            // reconciled/not-reconciled test to make here.
            //
            // Routed through the existing CoreListTransition → ComponentTransition →
            // ContainedViewLayoutTransition chain rather than re-deriving a curve, so there stays one
            // mapping to keep correct — and that chain folds CoreList's zero-duration-means-immediate
            // case into `.immediate` (see the ComponentTransition init at the top of this file).
            //
            // That fold matters for exactly one reason, and it is NOT that a zero duration would
            // otherwise animate — it would not, on any path. A zero-duration `ControlledTransition`
            // already collapses: `LegacyAnimator` maps `duration.isZero` to `.immediate`
            // (ContainedViewLayoutTransition.swift:2761). What does NOT collapse is
            // `ListViewItemUpdateAnimation.isAnimated`, which is true for ANY `.System` whatever its
            // duration (ListViewItem.swift:10) — and `ChatMessageBubbleItemNode` branches on it in
            // ~20 places to run its OWN animations on its own hard-coded durations, not the
            // transition's. Reaching `.System` with a zero duration would put the item on those
            // animated paths while the transition itself says immediate. Mapping the immediate case
            // to `.None` is what keeps `isAnimated` false.
            let mappedAnimation: ListViewItemUpdateAnimation
            switch ComponentTransition(self.pendingTransition).containedViewLayoutTransition {
            case .immediate:
                mappedAnimation = .None
            case let .animated(duration, curve):
                // `interactive: false` yields the LegacyAnimator — plain ContainedViewLayoutTransition
                // semantics, which is exactly what the item reads back out through
                // `animation.transition` (ListViewItem.swift:33). ListViewImpl passes `true` only where
                // it retains the transition to SCRUB it (`controlledTransition`, ListView.swift:1805);
                // nothing here scrubs, so a NativeAnimator would be a UIViewPropertyAnimator nobody
                // drives.
                //
                // The duration stays LOGICAL. ListViewImpl multiplies by
                // `UIView.animationDurationFactor()` at that same site because a NativeAnimator needs
                // wall-clock time; the legacy path instead reaches `CALayer.animate`, which applies the
                // Slow Animations factor itself as `speed` (CAAnimationUtils.swift:105-109). Scaling
                // here too would apply it twice, breaking CoreList's "exactly once per path" rule —
                // under which the transition handed to an item is always the logical one.
                mappedAnimation = .System(
                    duration: duration,
                    transition: ControlledTransition(duration: duration, curve: curve, interactive: false)
                )
            }
            self.listItem.updateNode(async: { f in f() }, node: { itemNode }, params: params, neighbors: self.neighbors, animation: mappedAnimation, completion: { nodeLayout, nodeApply in
                layoutAndApply = (nodeLayout, nodeApply)
            })
            if let (nodeLayout, nodeApply) = layoutAndApply {
                let height = nodeLayout.contentSize.height + nodeLayout.insets.top + nodeLayout.insets.bottom
                // Same fields, same order ListViewImpl stamps in updateNodeAtIndex. Load-bearing:
                // `insets` is the content-box term the visibility fraction divides by, and the flip
                // term inside ChatMessageBubbleItemNode.mapVisibility. ChatMessageItemImpl assigns
                // these on its nodeConfiguredForParams path only, so without this they go stale
                // whenever a relayout changes them — a date header appearing, say.
                //
                // contentSize/insets are written BEFORE the apply, matching ListView.swift:3008-3015.
                // The order is load-bearing and compiler-invisible: `apply` runs caller code
                // synchronously (ChatMessageBubbleItemNode's `awaitingAppliedReaction`, which dismisses
                // an open context menu), and that code samples the row's on-screen geometry with a bare
                // `UIView.convert` off the item node. Both setters rewrite the node's `frame` with its
                // origin pinned (ListViewItemNode.swift:209-224), and under the chat's π the node's own
                // height is what maps its content to screen — so with the old height still installed the
                // sample lands a full height-delta too low. Writing them first makes the convert chain
                // report the settled position even though CoreList has not rendered the row's new frame
                // yet: the row's container origin is the sum of the LOWER indices' heights, which this
                // row's own growth cannot change.
                //
                // `apparentHeight` stays after the apply, also matching ListViewImpl, which assigns it
                // only in the post-apply branches (ListView.swift:3021/3053/3083).
                itemNode.contentSize = nodeLayout.contentSize
                itemNode.insets = nodeLayout.insets
                // Under `hostOwnsFrame` those two assignments no longer resize the node — that is the
                // point of the flag — so the box is applied here instead, and it must be BEFORE the
                // apply for the convert-chain reason above.
                //
                // Through the pass transition, which animates `bounds.size.height` and `position.y`
                // from their presentation values: the same two tracks, the same resume rule, and the
                // same curve the engine uses for the ROW. That is what makes this ONE animation rather
                // than a correction chasing another animation — the node's box and its row travel
                // together by construction, and the content follows the box through the node's π.
                //
                // `setFrame` is only reached because the node no longer pre-empted it. Previously
                // `contentSize`/`insets` had already installed this exact frame, so every setter
                // returned at its equality guard and the box snapped no matter which one was used.
                let nodeFrame = CGRect(x: 0.0, y: 0.0, width: width, height: height)
                self.pendingTransition.setFrame(view: itemNode.view, frame: nodeFrame)
                // `CoreListTransition` writes the LAYER, so the node's own `_bounds`/`_position` cache
                // — what its `frame`/`bounds`/`position` getters return, and what `apparentFrame` and
                // the backend's `itemNodeFrame(_:)` are built on — would otherwise go stale. Writing
                // the model after the animated setter re-writes the same values and leaves the
                // animations in place.
                itemNode.frame = nodeFrame
                // The content-offset convention `insets.didSet` maintains when the node owns itself.
                // The item's own layout is expressed against it, so it is not optional.
                //
                // Applied UNANIMATED, deliberately. Routing it through
                // `pendingTransition.setBoundsOriginY` instead — so that a changing inset would travel
                // on the same curve as the height, the way ListViewImpl folds its `insetPart` into the
                // `transitionOffset` seed (ListView.swift:3063) — brought the wobble back on device,
                // and was reverted without the mechanism being established. It is dormant either way:
                // the chat's items no longer carry insets, so this term is constant and a snap is
                // invisible. See docs/chat/corelist-chat-history-backend.md, "Deferred".
                let contentOffsetY = -nodeLayout.insets.top
                if abs(itemNode.bounds.origin.y - contentOffsetY) > CGFloat.ulpOfOne {
                    itemNode.bounds.origin.y = contentOffsetY
                }
                nodeApply(ListViewItemApply())
                itemNode.apparentHeight = height
                self.lastHeight = height
            } else {
                print("[CoreList] async-only item, no synchronous node: \(type(of: self.listItem))")
                self.lastHeight = 0.0
            }
        } else {
            var resolvedNode: ListViewItemNode?
            var applyClosure: (() -> (Signal<Void, NoError>?, (ListViewItemApply) -> Void))?
            // `true` only for the pass that asked for it — the first view of a chat opened without an
            // animation, and the send animation. This is a fresh-node path, so it is reached by every
            // row that scrolls into view, and forcing it there decodes each arriving bubble's images
            // on the main thread mid-fling instead of letting them land a frame later.
            let synchronousLoads = self.backend?.prefersSynchronousResourceLoading ?? false
            self.listItem.nodeConfiguredForParams(async: { f in f() }, params: params, synchronousLoads: synchronousLoads, neighbors: self.neighbors, completion: { node, apply in
                resolvedNode = node
                applyClosure = apply
            })
            if let node = resolvedNode {
                if let applyClosure {
                    let (_, applyFn) = applyClosure()
                    applyFn(ListViewItemApply())
                }
                // contentSize/insets are already assigned on this path by
                // ChatMessageItemImpl.nodeConfiguredForParams; only apparentHeight is missing, and
                // ListViewImpl keeps it in step with the row's rendered height.
                let height = node.contentSize.height + node.insets.top + node.insets.bottom
                node.apparentHeight = height
                // Claimed only AFTER the node has been built. `nodeConfiguredForParams` assigns
                // `contentSize`/`insets` itself, and on this path we WANT the node's own writes: they
                // are what give a fresh view its initial box, with nothing to animate from anyway.
                // From here on the host owns it — see `ListViewItemNode.hostOwnsFrame`.
                node.hostOwnsFrame = true
                self.itemNode = node
                self.addSubview(node.view)
                self.lastHeight = height
            } else {
                print("[CoreList] async-only item, no synchronous node: \(type(of: listItem))")
                self.lastHeight = 0.0
            }
        }
        self.lastWidth = width
        self.contentDirty = false
        (self.itemNode as? ChatMessageItemView)?.scrollTiltProvider = self.backend?.scrollTiltProvider
        // A rect may have arrived before this node existed, and a relayout can change the insets the
        // fraction divides by, so re-derive visibility from the rect we hold.
        self.applyVisibility()
        // Same argument, and it also covers the node being REPLACED: the binding CoreList last named
        // is still correct for this row, but the new node's own array is empty.
        self.applyAttachedItems()
    }
}
