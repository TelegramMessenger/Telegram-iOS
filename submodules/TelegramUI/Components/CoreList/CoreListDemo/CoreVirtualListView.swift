import UIKit

public protocol CoreListItemView: AnyObject {
    /// Lays the row out at `width` and returns its measured height.
    ///
    /// `transition` describes the enclosing pass, and is non-immediate ONLY when this row's content
    /// changed in that pass — a reconciled survivor, or an animated self-update flush. A fresh view,
    /// a row loaded by scrolling, an unchanged survivor, and an off-screen remeasure all receive
    /// `.immediate`: there is nothing to animate from, or the change is purely outer geometry, which
    /// `ListAnimationModel` owns. The returned height must be the settled height either way.
    ///
    /// This may be called twice in one pass (dirty remeasure, then window construction). The
    /// transition's setters early-out on an equal target, so the second call is a no-op.
    func update(width: CGFloat, transition: CoreListTransition) -> CGFloat
    var onContentDidChange: ((_ animated: Bool) -> Void)? { get set }

    /// The part of this row currently inside the viewport, in the row's OWN coordinate space (its
    /// origin is `(0, 0)`); `nil` when the row is not visible.
    ///
    /// Fired wherever the list maintains its window — after every render, and on every user-scroll
    /// frame including momentum and edge bounce — using the same projection `rebalanceActiveWindow`
    /// uses: settled window frames at the live engine offset. During a programmatic animated viewport
    /// move that describes the row's DESTINATION, which is deliberate: it is the same window the pass
    /// has already loaded, and there is no clock here to re-sample an in-flight animation.
    ///
    /// Insets are NOT subtracted: inset space is visible, interactive list space.
    ///
    /// A row leaving the live window — unloaded by rebalancing, or transferred to the exit overlay as
    /// a departure — receives `nil`.
    func visibleRectUpdated(_ visibleRect: CGRect?)

    /// How far the far edge of a `spansMemberInsets == false` attachment band pulls in from this row's
    /// frame — the part of the row that is reserved space rather than content. Default `0`, the
    /// correct neutral for a row that reserves nothing; it is read ONLY for such an attachment's
    /// outermost member, so a row with no attachments never pays for it.
    var attachmentBandTrim: CGFloat { get }

    /// The attachments currently bound to this row: those whose run counts this row as a member AND
    /// which overlap it more than any other member of that run. A row is the OWNER of an attachment in
    /// the sense a row needs — "the avatar hanging off me right now" — which is a different question
    /// from "the run I belong to", because one run has many members and one attachment.
    ///
    /// This exists because the binding is only answerable HERE. It is a function of the attachment's
    /// SOLVED position, which moves independently of the rows as the run scrolls and its floating
    /// attachment parks against the display edge, so it changes without any item or run changing. The
    /// row cannot compute it (it does not know the solve) and neither can the host (it would have to
    /// re-derive attachment frames, member ranges and row frames from outside, in view space rather
    /// than the window space they are solved in).
    ///
    /// Delivered on every solve, unconditionally and including no-change frames — the same cadence as
    /// `stickDistanceUpdated`, and for the same reason: this is per-frame geometry, not an event.
    /// Receivers that do real work on it must compare and no-op, which they must do anyway, since a
    /// recycled view can be handed the same set for a different row. Default: no-op.
    ///
    /// The analogue of `ListViewItemNode.attachedHeaderNodes` and its `attachedHeaderNodesUpdated`
    /// notification (`Display/Source/ListView.swift:4203-4242`), which resolves the same
    /// max-intersection-within-the-run question — including its "and only if it actually intersects"
    /// guard, so a run scrolled far enough that its attachment has parked clear of every member binds
    /// to nothing.
    func attachedItemsUpdated(_ attachments: [UIView & CoreListAttachedItemView])
}

public extension CoreListItemView {
    var attachmentBandTrim: CGFloat { 0.0 }
    func attachedItemsUpdated(_ attachments: [UIView & CoreListAttachedItemView]) {}
    func visibleRectUpdated(_ visibleRect: CGRect?) {}
}

public protocol CoreListItem: AnyObject {
    /// Stable identity: drives diff matching (survive / insert / delete / move) and the uniqueness
    /// invariant, and is the animation/owner key. Two items are "the same row" iff their `identity` is
    /// equal.
    var identity: AnyHashable { get }
    func view() -> UIView & CoreListItemView
    /// Value/content equality for an already-identity-matched survivor. The engine matches rows by
    /// `identity`; this only decides whether a matched survivor's content changed — it reconfigures
    /// (`apply(to:)` + remeasure) iff `!isEqual`. Deliberately has NO default: equality-by-identity is
    /// almost never correct in production, so every item must state its content equality explicitly.
    func isEqual(to other: CoreListItem) -> Bool
    /// Reconfigures a reused survivor's content. `transition` is the enclosing pass's transition; a
    /// view that animates its own internals should use it, or hold it for its next layout.
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition)

    /// This row pins to the viewport's BOTTOM edge: the list declares whatever extra TOP-inset slack
    /// is needed to bring it there, so it can reach the edge even when the content above it is
    /// shorter than the viewport. The analogue of `ListViewItem.pinToEdgeWithInset`
    /// (`Display/Source/ListViewItem.swift:83`).
    ///
    /// When several loaded rows declare it, the LOWEST index wins — `ListViewImpl`'s
    /// `lowestPinnedIndex` (`Display/Source/ListView.swift:1107`).
    var pinsToBottomEdge: Bool { get }

    /// Attachments this row publishes, keyed by attachment key. A key identifies a RUN: adjacent
    /// items publishing the same key, and agreeing under `combines(with:)`, share one attachment
    /// view. The same key may recur in disjoint runs of the loaded window, which is why runs carry a
    /// serial rather than being identified by key alone.
    var attachedItems: [AnyHashable: CoreListAttachedItem] { get }
}

public extension CoreListItem {
    func apply(to view: UIView & CoreListItemView, transition: CoreListTransition) {}

    /// Unlike `isEqual`, `false` is honest rather than a conservative guess: a row that says nothing
    /// about pinning is not pinned, and there is no behavior to degrade silently.
    var pinsToBottomEdge: Bool { false }

    /// Unlike `isEqual`, an empty default is honest here — most rows publish no attachments — and it
    /// keeps every existing conformance compiling.
    var attachedItems: [AnyHashable: CoreListAttachedItem] { [:] }
}

public enum CoreListAnchorMode: Equatable {
    case automatic
    case preserveVisibleContent
}

/// Where a programmatic scroll should place one row.
///
/// `resolve` returns the row's settled Y as an offset from the top inset edge — the convention the
/// old `pointOffset` tuple used, i.e. the projected screen target is `viewportInsets.top + returned
/// value`. It is called exactly once per pass, immediately after the anchor row has been measured,
/// with that row's measured height and its view. That is the only point at which a height-dependent
/// placement (bottom-align, center, "make visible") can be computed for a target that is not in the
/// loaded window — which is what a host's far jump always is.
///
/// The closure MUST be pure with respect to this list: it may read geometry, but it must not mutate
/// the collection or re-enter `applyChanges`. It runs inside the mutation pass.
public struct CoreListScrollTarget {
    /// Travel direction for a viewport transition that has no anchor witness — i.e. when no old
    /// identity survives into the new collection, so index comparison has nothing to compare. `nil`
    /// keeps the historical hardcoded `.forward`.
    public enum Direction {
        case forward
        case backward
    }

    public let index: Int
    public let resolve: (_ measuredHeight: CGFloat, _ view: UIView & CoreListItemView) -> CGFloat
    public let direction: Direction?

    public init(index: Int, pointOffset: CGFloat) {
        self.index = index
        self.resolve = { _, _ in pointOffset }
        self.direction = nil
    }

    public init(index: Int,
                direction: Direction? = nil,
                resolve: @escaping (CGFloat, UIView & CoreListItemView) -> CGFloat) {
        self.index = index
        self.resolve = resolve
        self.direction = direction
    }
}

extension CoreListScrollTarget: CustomStringConvertible {
    public var description: String {
        "CoreListScrollTarget(index: \(index), direction: \(String(describing: direction)))"
    }
}

public enum CoreListLoadedEdge: Hashable {
    case top
    case bottom
}

/// Which side of its settled span a rigid block of rows travels in from — see
/// `CoreVirtualListView.animateInsertedBlock(identities:origin:transition:)`.
///
/// Stated in CONTENT ORDER, not on screen: `.beforeBlock` is the low-index side. A host whose view is
/// rotated (the chat history is) renders that at the visual bottom, and picking the case by what the
/// user sees is how the sign gets inverted.
public enum CoreListBlockOrigin: Hashable {
    /// The block starts one block-height toward index 0 and travels forward into place.
    case beforeBlock
    /// The block starts one block-height away from index 0 and travels back into place.
    case afterBlock
}

public final class CoreVirtualListView: UIView {
    struct Window {
        struct Item {
            let index: Int
            let view: UIView & CoreListItemView
            var frame: CGRect
            /// Space reserved ABOVE this row by `.reservesSpace` `.top` attachments whose run starts
            /// here. A gap between rows, NOT part of this row's frame — which is why every existing
            /// reader of `frame` keeps its meaning.
            var reservedTop: CGFloat = 0
            /// The mirror below this row, for `.bottom` attachments whose run ends here.
            var reservedBottom: CGFloat = 0
        }

        /// A resolved attachment run in the settled window.
        ///
        /// Holds only OFFSET-INDEPENDENT state. The solved position is deliberately absent: item
        /// frames are offset-independent, and a floating attachment's solved Y is not, so storing it
        /// would destroy the property that makes this window a settled value. The solve happens at
        /// render and scroll time, exactly as a row's screen position does.
        struct Attachment {
            let key: AnyHashable
            let serial: UInt64
            let view: UIView & CoreListAttachedItemView
            var memberRange: Range<Int>
            var measuredHeight: CGFloat
            let placement: CoreListAttachmentPlacement
            let edge: CoreListAttachmentEdge
            let isFloating: Bool
            let startsCollectionRun: Bool
            let endsCollectionRun: Bool
            /// Copied from the run representative, as `placement`/`edge`/`isFloating` are: the solve
            /// needs both declarations without reaching back for a descriptor.
            let stackingGroup: AnyHashable?
            let stackingYield: (group: AnyHashable, gap: CGFloat)?
            /// Frame-space band, finalised after row stacking.
            var bandTop: CGFloat
            var bandBottom: CGFloat
        }

        var items: [Item] = []
        /// Sorted by `(memberRange.lowerBound, key description)` — see `AttachmentRuns.pendingRuns`.
        var attachments: [Attachment] = []

        var startIndex: Int { items.first?.index ?? 0 }
        var endIndex: Int { items.last?.index ?? -1 }
        var isEmpty: Bool { items.isEmpty }
        // Extended to cover the reserved bands, so underfill alignment and `pinsLoadedTop` place the
        // BAND on the inset edge rather than the row.
        var minY: CGFloat { (items.first?.frame.minY ?? 0) - (items.first?.reservedTop ?? 0) }
        var maxY: CGFloat { (items.last?.frame.maxY ?? 0) + (items.last?.reservedBottom ?? 0) }
        var height: CGFloat { maxY - minY }

        func contains(index: Int) -> Bool {
            guard let first = items.first, let last = items.last else { return false }
            return index >= first.index && index <= last.index
        }

        func localFrame(for index: Int) -> CGRect? {
            items.first(where: { $0.index == index })?.frame
        }

        // The loaded view at a collection index. Filters rather than subscripts: `items` is the
        // settled window, whose array positions are offset from collection indices whenever the
        // window has scrolled away from index 0.
        func view(for index: Int) -> (UIView & CoreListItemView)? {
            items.first(where: { $0.index == index })?.view
        }
    }

    struct ItemDiff {
        var survivorMap: [Int: Int]
        var deletes: [Int]
        var inserts: [Int]
        var moves: [(old: Int, new: Int)] = []

        func survivingNewIndex(forOldIndex oldIndex: Int) -> Int? {
            survivorMap[oldIndex]
                ?? moves.first(where: { $0.old == oldIndex })?.new
        }
    }

    private struct ResolvedAnchor {
        /// `.resolved` is produced by `resolveAnchor`'s `scrollTo` branch and by nothing else, so the
        /// two cases are exactly the old `hasScrollTo` split in the offset composition below.
        enum Offset {
            case fixed(CGFloat)
            case resolved((CGFloat, UIView & CoreListItemView) -> CGFloat)
        }

        let index: Int
        let offset: Offset
        let preservesVisibleContent: Bool
        /// Set only by `resolveAnchor`'s pin branch. Read by `pinsLoadedTop`, which must not ALSO
        /// place the window: in the short-content regime both mechanisms land the row on the bottom
        /// edge and agree exactly, and "two mechanisms that happen to agree" is what this design
        /// exists to remove.
        ///
        /// Stored rather than re-derived as `index == lowestPinnedItemIndex`: an explicit `scrollTo`
        /// to the pinned row is a DIFFERENT case that keeps its own behaviour.
        let isPin: Bool

        // Every non-scrollTo branch of resolveAnchor computes a plain point offset, so they keep
        // their existing call shape.
        init(index: Int, pointOffset: CGFloat, preservesVisibleContent: Bool) {
            self.index = index
            self.offset = .fixed(pointOffset)
            self.preservesVisibleContent = preservesVisibleContent
            self.isPin = false
        }

        init(index: Int, offset: Offset, preservesVisibleContent: Bool, isPin: Bool = false) {
            self.index = index
            self.offset = offset
            self.preservesVisibleContent = preservesVisibleContent
            self.isPin = isPin
        }
    }

    static func computeDiff(old: [CoreListItem], new: [CoreListItem]) -> ItemDiff {
        var oldMatched = Array(repeating: false, count: old.count)
        var survivorMap: [Int: Int] = [:]
        var inserts: [Int] = []

        for newIndex in new.indices {
            var matched = false
            for oldIndex in old.indices where !oldMatched[oldIndex] {
                if old[oldIndex].identity == new[newIndex].identity {
                    oldMatched[oldIndex] = true
                    survivorMap[oldIndex] = newIndex
                    matched = true
                    break
                }
            }
            if !matched { inserts.append(newIndex) }
        }

        let oldSurvivors = survivorMap.keys.sorted()
        let newIndexSequence = oldSurvivors.map { survivorMap[$0]! }
        let keptPositions = Set(longestIncreasingSubsequenceIndices(newIndexSequence))
        var reorderedOldIndices: Set<Int> = []
        for position in oldSurvivors.indices where !keptPositions.contains(position) {
            reorderedOldIndices.insert(oldSurvivors[position])
        }

        var moves: [(old: Int, new: Int)] = []
        for oldIndex in reorderedOldIndices {
            let newIndex = survivorMap[oldIndex]!
            inserts.append(newIndex)
            moves.append((old: oldIndex, new: newIndex))
            survivorMap[oldIndex] = nil
        }
        moves.sort { $0.new < $1.new }

        var deletes: [Int] = []
        for oldIndex in old.indices where !oldMatched[oldIndex] || reorderedOldIndices.contains(oldIndex) {
            deletes.append(oldIndex)
        }
        inserts.sort()
        return ItemDiff(survivorMap: survivorMap,
                        deletes: deletes,
                        inserts: inserts,
                        moves: moves)
    }

    static func firstDuplicatePair(in items: [CoreListItem]) -> (first: Int, second: Int)? {
        for first in items.indices {
            for second in items.indices where second > first {
                if items[first].identity == items[second].identity {
                    return (first, second)
                }
            }
        }
        return nil
    }

    static func longestIncreasingSubsequenceIndices(_ values: [Int]) -> [Int] {
        guard !values.isEmpty else { return [] }
        var tails: [Int] = []
        var predecessors = Array(repeating: -1, count: values.count)

        for index in values.indices {
            var lower = 0
            var upper = tails.count
            while lower < upper {
                let middle = (lower + upper) / 2
                if values[tails[middle]] < values[index] {
                    lower = middle + 1
                } else {
                    upper = middle
                }
            }
            if lower > 0 { predecessors[index] = tails[lower - 1] }
            if lower == tails.count {
                tails.append(index)
            } else {
                tails[lower] = index
            }
        }

        var result: [Int] = []
        var index = tails.last ?? -1
        while index >= 0 {
            result.append(index)
            index = predecessors[index]
        }
        return result.reversed()
    }

    private struct SettledLiveItem {
        let index: Int
        let identity: AnyHashable
        let view: UIView & CoreListItemView
        let contentX: CGFloat
        let contentY: CGFloat
        let positionOffsetX: CGFloat
        let positionOffset: CGFloat
        let opacity: CGFloat
        let size: CGSize
        let visualWidth: CGFloat
        let visualHeight: CGFloat
    }

    private struct GhostMember {
        let owner: ListAnimationOwner
        let view: UIView
        var settledX: CGFloat
        var settledWidth: CGFloat
    }

    private struct GhostBlockRender {
        let owner: ListAnimationOwner
        let wrapper: UIView
        var members: [ObjectIdentifier: GhostMember]
        let departedRange: Range<Int>
    }

    private struct GhostWitnessCandidate {
        let witness: GhostBoundaryWitness
        let edgeY: CGFloat
        let carrierOrder: Int
    }

    private struct ViewportCarry {
        var generation: UInt64
        let owner: ListAnimationOwner
        let identity: AnyHashable
        let view: UIView
        var settledX: CGFloat
        var settledWidth: CGFloat
        /// The same fact a ghost block records as `GhostBlockAnchoring`: a carry promoted out of a
        /// carousel pass lives in `carouselExitOverlay`, in viewport coordinates.
        var isScreenAnchored: Bool = false
    }

    struct CrossingCarrySnapshot: Equatable {
        let identity: AnyHashable
        let settledContentY: CGFloat
        let releaseGeneration: UInt64?
    }

    private struct CrossingCarry {
        let identity: AnyHashable
        let view: UIView & CoreListItemView
        var settledX: CGFloat
        var settledWidth: CGFloat
        var settledContentY: CGFloat
        var releaseGeneration: UInt64?
    }

    private struct SurvivorEndpointIndices {
        let oldIndex: Int
        let newIndex: Int
        let isMoveParticipant: Bool
    }

    private var _items: [CoreListItem] = [] {
        didSet { lowestPinnedItemIndex = _items.firstIndex(where: { $0.pinsToBottomEdge }) }
    }
    /// The collection's lowest `pinsToBottomEdge` index — `ListViewImpl`'s `lowestPinnedIndex`.
    ///
    /// Cached rather than scanned per build: `buildWindow` needs it to decide how far down to load
    /// before the slack is answerable, and that would be an O(collection) scan on the hot path. Kept
    /// on `_items`'s `didSet` so it cannot go stale behind any of the three assignment sites.
    private var lowestPinnedItemIndex: Int?

    /// Whether the list is currently HOLDING its lowest `pinsToBottomEdge` row against the bottom
    /// edge. `ListViewImpl.experimentalSnapScrollToPinnedItem` (`Display/Source/ListView.swift:215`).
    ///
    /// A plain flag, deliberately — not a remembered index, identity or settled offset. The pinned
    /// row's index shifts every time a message arrives, and `lowestPinnedItemIndex` is already
    /// re-derived per pass, so there is nothing here to go stale.
    ///
    /// Engaged by an explicit `scrollTo` at the pinned index; released on finger-down, on the pinned
    /// row leaving the collection, and on a full replace. Release is PERMANENT for that pin —
    /// scrolling back to the edge does not re-engage it, matching `ListViewImpl`.
    ///
    /// This answers WHERE the pinned row goes. `bottomEdgePinSlack` answers whether the list has
    /// scroll ROOM to rest there, and is deliberately independent of this flag.
    private var holdsPinnedRow = false

    var items: [CoreListItem] {
        get { _items }
        set {
            _items = newValue
            rebuildFromScratch()
        }
    }

    public var preloadMargin: CGFloat = 160
    public var loadedEdgeMargin: CGFloat = 0 {
        didSet {
            guard loadedEdgeMargin != oldValue else { return }
            refreshReachedLoadedEdges()
        }
    }
    let engine: ScrollEngine
    let container = UIView()
    /// Attachment views. A SIBLING of `container` inside `contentHost`, with its frame kept identical
    /// to `container`'s, which buys: the additive viewport track and container rebases inherited
    /// exactly as rows inherit them; and `render()`'s subview bookkeeping left untouched (it only
    /// calls `addSubview` when a view's superview is wrong, so ordering by call sequence would not
    /// have been reliable). It is the TOPMOST sibling — above the crossing and exit overlays too, not
    /// merely above `container` — see the ordering comment in `init`.
    let attachmentContainer = AttachmentContainerView()
    let crossingOverlay = UIView()
    let exitOverlay = UIView()
    /// Where a CAROUSEL's outgoing content is parked — outside `engine.contentHost`, so no engine
    /// offset write reaches it.
    ///
    /// A carousel travels between two disjoint windows, so its departed strip has no position in the
    /// destination's content space; the adjacent placement it is given is a fiction that holds only
    /// while the shared viewport track is the sole thing moving. Parked in `exitOverlay` it also
    /// moved with the user's finger, so reversing direction mid-travel dragged the old window back
    /// over the new one's rows — and the strip's fictional placement is exactly where the
    /// destination's own older rows live.
    ///
    /// Its travel is the viewport travel, carried by registering its layer as a viewport MIRROR —
    /// the same track, not a second one. Children are placed in content coordinates minus the frozen
    /// destination engine offset, which is forced by equating the two renderings:
    /// `contentY - (offset + correction)` in the content host, `mirrorY - correction` here.
    ///
    /// `ListViewImpl` has always done this: `temporaryPreviousNodes` are added to the list view
    /// itself at their final frames and travel on one additive `sublayerTransform`
    /// (`Display/Source/ListView.swift:3625-3634`, `:3803`), so scrolling never repositions them.
    let carouselExitOverlay = UIView()
    let animationController: ListAnimationController
    let scheduler: Scheduler
    private(set) var logicalSize: CGSize = .zero
    private(set) var viewportInsets: UIEdgeInsets = .zero
    var viewportGeometry: ListViewportGeometry {
        ListViewportGeometry(size: logicalSize, insets: viewportInsets)
    }
    // Internal rather than private: `CoreVirtualListView+Attachments.swift` is a different FILE, and
    // Swift's `private` is file-scoped.
    var contentWidth: CGFloat { viewportGeometry.contentWidth }
    private(set) var activeWindow = Window()
    private(set) var containerOriginY: CGFloat = 0
    private var viewportCarries: [ViewportCarry] = []
    var viewportCarryViews: [UIView] { viewportCarries.map(\.view) }
    /// The carries promoted out of a carousel pass, which live in `carouselExitOverlay` and are
    /// therefore in viewport coordinates. The ghost-block counterpart is `GhostBlockAnchoring`.
    var screenAnchoredViewportCarryViews: [UIView] {
        viewportCarries.filter(\.isScreenAnchored).map(\.view)
    }
    private var crossingCarries: [AnyHashable: CrossingCarry] = [:]
    var crossingCarrySnapshots: [CrossingCarrySnapshot] {
        crossingCarries.values.map {
            CrossingCarrySnapshot(identity: $0.identity,
                                  settledContentY: $0.settledContentY,
                                  releaseGeneration: $0.releaseGeneration)
        }.sorted { String(reflecting: $0.identity) < String(reflecting: $1.identity) }
    }

    func crossingCarryView(identity: AnyHashable) -> UIView? {
        crossingCarries[identity]?.view
    }
    private let ghostLedger = GhostBlockLedger()
    private var ghostRenders: [GhostBlockID: GhostBlockRender] = [:]
    var ghostBlockSnapshots: [GhostBlockSnapshot] { ghostLedger.snapshots }
    var ghostMemberViews: [UIView] {
        ghostRenders.values.flatMap { render in render.members.values.map(\.view) }
    }
    /// The per-block wrappers parented directly to `exitOverlay`. Members live inside these, so an
    /// overlay-ownership check has to account for both.
    var ghostBlockWrapperViews: [UIView] {
        ghostRenders.values.map(\.wrapper)
    }
    struct DetachedHorizontalSnapshot {
        let owner: ListAnimationOwner
        let view: UIView
        let settledX: CGFloat
        let settledWidth: CGFloat
    }
    var ghostMemberHorizontalSnapshots: [DetachedHorizontalSnapshot] {
        ghostRenders.values.flatMap { render in
            render.members.values.map {
                DetachedHorizontalSnapshot(owner: $0.owner,
                                           view: $0.view,
                                           settledX: $0.settledX,
                                           settledWidth: $0.settledWidth)
            }
        }
    }
    private var previousOffset: CGFloat = 0
    public private(set) var reachedLoadedEdges: Set<CoreListLoadedEdge> = []
    public var onLoadedEdgeReached: ((CoreListLoadedEdge) -> Void)?

    // Embedding seam (used by the TelegramUI ChatHistoryListViewBackend adapter).
    // User-driven offset delta (drag/momentum/bounce), before window rebasing. Programmatic
    // shifts are excluded. Timestamp is monotonic wall time; observers must not mutate the list.
    public var onUserScrollDelta: ((_ delta: CGFloat, _ timestamp: CFTimeInterval) -> Void)?
    // Fired after each user-scroll rebalance so a host can recompute its visible index range.
    public var onVisibleWindowChanged: (() -> Void)?
    // Fired when the user starts an interactive drag (the scroll engine's pan reaches `.began`); not
    // fired for programmatic scrolls or momentum/bounce. Analogous to ListViewImpl's
    // `beganInteractiveDragging`.
    public var willBeginDragging: (() -> Void)?
    // Fired when that interactive drag ends (the pan reaches `.ended`/`.cancelled`), whether or not
    // momentum follows — so this and `willBeginDragging` bracket the finger-down interval, not the
    // momentum phase after it. Analogous to ListViewImpl's `endedInteractiveDragging`, and the signal a
    // host needs to maintain its own `ListViewImpl.isTracking` equivalent.
    public var didEndDragging: (() -> Void)?
    // Consulted once at each interactive release, with the release velocity, BEFORE the engine decides
    // whether momentum follows. Returning true releases the list as if the finger had come to rest — no
    // fling — while an overscrolled release still springs back. The seam exists for a host whose release
    // is claimed by something outside the list; see `ScrollEngine.shouldStopScrollingOnRelease`, and
    // `ListViewImpl.shouldStopScrolling` for the identically-shaped hook on the other backend.
    public var shouldStopScrolling: ((CGFloat) -> Bool)? {
        get { self.engine.shouldStopScrollingOnRelease }
        set { self.engine.shouldStopScrollingOnRelease = newValue }
    }
    // Fired when a momentum flight stops carrying the content: both the authoritative settle
    // (`finalizeFlight`) and the interruption (`catchFlight`, when a new touch grabs the list
    // mid-flight) reach it, because both are the engine reporting `onFlightChanged(nil)`.
    //
    // That is deliberately the same conflation `scrollViewDidEndDecelerating` has — UIKit fires it on
    // an interrupted deceleration too, and ListViewImpl separates the cases with its own
    // `!scrollView.isTracking` guard (Display/Source/ListView.swift:940). A host wanting "settled, and
    // the user is not already dragging again" applies the same guard; it can, because
    // `onWillBeginDragging` is emitted BEFORE the catch (PhysicsScrollEngine.swift:163-167), so its
    // tracking flag is already true by the time this arrives.
    //
    // A drag released with no momentum produces NO flight and therefore never reaches here. That case
    // is the host's to read off `didEndDragging` + `isScrollFlightActive`, mirroring how ListViewImpl
    // splits the same two cases across `willDecelerate`.
    public var didEndScrolling: (() -> Void)?
    // True while the render server is carrying a momentum flight. Read at `didEndDragging` to learn
    // whether momentum followed the release: the engine emits that callback AFTER launching
    // deceleration, precisely so an observer sees the post-release truth
    // (PhysicsScrollEngine.swift:194-197).
    public var isScrollFlightActive: Bool { activeScrollFlight != nil }
    // Signed distance the engine offset sits beyond its declared edges — negative past `min`, positive
    // past `max`, zero within. The analogue of reading `scrollView.contentOffset.y` against its content
    // bounds, and correct to sample at `didEndDragging`: `launchFlight` parks the LAYER at the settled
    // offset but leaves `core.offset` at the release position, so this still describes where the finger
    // let go rather than where the spring is headed.
    public var overscrollDistance: CGFloat {
        let offset = engine.offset
        if let minimum = declaredEdges.min, offset < minimum { return offset - minimum }
        if let maximum = declaredEdges.max, offset > maximum { return offset - maximum }
        return 0.0
    }
    // Mirrors the last `engine.setEdges` — the engine takes them but does not hand them back.
    private(set) var declaredEdges: (min: CGFloat?, max: CGFloat?) = (nil, nil)
    // The contiguous loaded item-index span of the settled window, or nil when empty.
    public var loadedIndexRange: (first: Int, last: Int)? {
        activeWindow.isEmpty ? nil : (activeWindow.startIndex, activeWindow.endIndex)
    }

    /// Non-copying, in-ascending-index-order iteration over the currently loaded item views (the
    /// settled window). Walks the window in place — no array is built and no element is copied. This is
    /// CoreList's analogue of `ListViewImpl.forEachItemNode`, but iterator-based rather than
    /// closure-based, so a host can `for view in listView.loadedItemViews { … }`. The iterator holds a
    /// stable snapshot of the window (a COW retain of its buffer), so mutating the list mid-iteration is
    /// safe. Only settled/loaded rows are visited — not off-screen entries or exit-overlay ghosts.
    public struct LoadedItemViews: Sequence, IteratorProtocol {
        private let items: [Window.Item]
        private var index = 0
        fileprivate init(_ items: [Window.Item]) { self.items = items }
        public mutating func next() -> (UIView & CoreListItemView)? {
            guard index < items.count else { return nil }
            defer { index += 1 }
            return items[index].view
        }
    }
    public var loadedItemViews: LoadedItemViews { LoadedItemViews(activeWindow.items) }

    /// The loaded item view at `index` in the current item collection, or nil when that index is not
    /// in the settled window. The index-keyed sibling of `loadedItemViews`: this view is the authority
    /// on the index ↔ view mapping (it owns `activeWindow`), so a host must never re-derive it by
    /// walking `loadedItemViews` to a position inferred from `loadedIndexRange`. Only settled/loaded
    /// rows resolve — never off-screen entries or exit-overlay ghosts. A pure read of settled state:
    /// it starts no transaction and mutates nothing.
    public func loadedItemView(at index: Int) -> (UIView & CoreListItemView)? {
        activeWindow.view(for: index)
    }

    /// Non-copying, in-ascending-index-order iteration over the loaded item views **paired with their
    /// collection indices**. Same in-place COW-snapshot walk as `loadedItemViews` — no array built, no
    /// element copied, safe to mutate the list mid-iteration — but each element also carries the
    /// window's own `index`. Use this instead of counting iterations over `loadedItemViews`: array
    /// position equals collection index only while the window still starts at 0. Visits only
    /// settled/loaded rows, never off-screen entries or exit-overlay ghosts.
    public struct LoadedItemEntries: Sequence, IteratorProtocol {
        public typealias Element = (index: Int, view: UIView & CoreListItemView)
        private let items: [Window.Item]
        private var position = 0
        fileprivate init(_ items: [Window.Item]) { self.items = items }
        public mutating func next() -> Element? {
            guard position < items.count else { return nil }
            defer { position += 1 }
            let item = items[position]
            return (index: item.index, view: item.view)
        }
    }
    public var loadedItemEntries: LoadedItemEntries { LoadedItemEntries(activeWindow.items) }

    /// Non-copying, in-order iteration over the LIVE attachment views — the floating headers,
    /// footers and gutter views of the settled window's runs. Same in-place COW-snapshot walk as
    /// `loadedItemViews`, so mutating the list mid-iteration is safe.
    ///
    /// This IS the live set: a run that has departed is carried by the fade-out path and is absent
    /// from `activeWindow.attachments`, so a host needs no liveness guard of its own — the same
    /// argument `loadedItemViews` makes about exit-overlay ghosts.
    ///
    /// Views only. A run's key, serial and member range are engine identity, and a host that needs to
    /// correlate an attachment with its rows should get a purpose-built accessor rather than these.
    public struct LoadedAttachmentViews: Sequence, IteratorProtocol {
        private let attachments: [Window.Attachment]
        private var position = 0
        fileprivate init(_ attachments: [Window.Attachment]) { self.attachments = attachments }
        public mutating func next() -> (UIView & CoreListAttachedItemView)? {
            guard position < attachments.count else { return nil }
            defer { position += 1 }
            return attachments[position].view
        }
    }
    public var loadedAttachmentViews: LoadedAttachmentViews {
        LoadedAttachmentViews(activeWindow.attachments)
    }

    // The current settled scroll offset reported by the scroll engine.
    public var currentScrollOffset: CGFloat { engine.offset }

    /// The view the scroll pan gesture recognizer is attached to — NOT `self`. Both engines park the
    /// pan on their content host (`PhysicsScrollEngine`'s own `host`, `UIKitScrollEngine`'s
    /// `UIScrollView`), which is a subview of this list, so `self` is an ANCESTOR of the pan's view
    /// and is the wrong answer to every question about the pan.
    ///
    /// Two kinds of caller need it, and each breaks SILENTLY with the wrong view:
    ///
    /// - a host that force-routes a touch by returning a view from `hitTest` — UIKit collects
    ///   recognizers from the hit view UPWARD, so handing back an ancestor of the pan excludes the
    ///   pan from the touch entirely and scrolling simply stops happening;
    /// - a host attaching its own recognizer that must arbitrate against the scroll pan —
    ///   `gestureRecognizerShouldBegin` enumerates `pan.view.gestureRecognizers`, i.e. the pan's OWN
    ///   view, so a recognizer on an ancestor is invisible to that scan even though UIKit still
    ///   delivers touches to it.
    ///
    /// Both are exactly how `ListViewImpl` is wired (`Display/Source/ListView.swift:526` adds the
    /// scroll pan to `self.view`, and everything that must arbitrate with it goes on that same view);
    /// the difference is only that there the pan's view and the list's view coincide.
    public var scrollGestureHostView: UIView { engine.contentHost }

    /// Whether a `pinsToBottomEdge` row is currently HELD against the bottom edge, as opposed to
    /// merely happening to be near it. `ListViewImpl.isStrictlyScrolledToPinToEdgeItem()`
    /// (`Display/Source/ListView.swift:2708`), tolerance included.
    ///
    /// One member rather than a slack getter for the host to compare against: a pair of raw members
    /// is a pair a backend can half-implement or half-sample.
    ///
    /// Reads the PRESENTED frame — the question is where the row is on screen right now, so a pass
    /// whose animation has not landed yet must answer false.
    ///
    /// Gated on the LATCH, not on geometry. With a latch there is no such thing as a row sitting at
    /// the edge "by coincidence": the flag distinguishes held from coincident directly, which is what
    /// the old `slack != 0 || ext > 0` guard was a proxy for. That guard could not survive the clamp
    /// anyway — it reads false in the tall-content regime, where the pin is most firmly held.
    ///
    /// Load-bearing beyond the scroll-to-bottom button: `ChatControllerLoadDisplayNode.swift:900-904`
    /// uses this to decide whether SENDING A MESSAGE drops the pin.
    public var isStrictlyPinnedToBottomEdge: Bool {
        guard holdsPinnedRow,
              let pinnedIndex = lowestPinnedItemIndex,
              let pinned = activeWindow.items.first(where: { $0.index == pinnedIndex })
        else { return false }
        let visibleArea = logicalSize.height - viewportInsets.top - viewportInsets.bottom
        let ext = max(0, pinned.frame.height - visibleArea * 0.5)
        let expectedMaxY = logicalSize.height - viewportInsets.bottom + ext
        return abs(presentedFrame(of: pinned.view).maxY - expectedMaxY) < 0.5
    }

    /// A view's rect in this list's coordinate space, as PRESENTED — where it is on screen right now, not
    /// where its settled model geometry says it will end up.
    ///
    /// Hosts MUST use this instead of `convert(_:from:)`. `UIView.convert` composes ancestor MODEL
    /// `bounds.origin`, and `contentHost`'s model origin is the additive base of whatever animates the
    /// viewport: a `.keyframe` deceleration parks it at the flight's destination for the flight's whole
    /// duration, and a programmatic `scrollTo` leaves the settled endpoint there while the additive
    /// `viewportOffset` track carries the motion. Converting through `contentHost` therefore yields
    /// destination-space geometry — which silently made a host's visible-range, content-offset and
    /// read-tracking reporting describe the end of a fling rather than the middle of it.
    ///
    /// Only this view can apply the correction, because only it holds both the model base and the engine's
    /// scroll position. Ancestor-path-agnostic like `convert` itself: a row carried by `crossingOverlay`
    /// during a structural transition converts correctly too.
    ///
    /// "Presented" here means **as of the last sampling tick**, not instantaneous: it is built on
    /// `engine.offset`, which is per-frame stable by contract, so this is stable within a frame and at most
    /// one frame behind the screen. That is the right semantic for a host — hosts read geometry from the
    /// per-frame scroll callbacks, where the two coincide exactly — and it keeps the clock out of the seam.
    /// Two reads in the same frame therefore agree, which is what makes this safe to call in a loop over the
    /// loaded window.
    public func presentedFrame(of view: UIView) -> CGRect {
        convert(view.bounds, from: view)
            .offsetBy(dx: 0, dy: -modelToPresentedViewportDelta)
    }

    /// A view's rect in this list's coordinate space, as SETTLED — where its model geometry says it will be
    /// once the animations in flight finish. The counterpart of `presentedFrame(of:)`, and exactly that
    /// value without the presented correction.
    ///
    /// This is NOT the default: a host asking "where is this row" wants `presentedFrame(of:)`, and reaching
    /// for `convert(_:from:)` to get destination geometry is the specific mistake that method exists to
    /// prevent. Use this only where the host is reporting the OUTCOME of a pass it just submitted, alongside
    /// that pass's transition, so a consumer animating on that transition arrives where the content will.
    /// At such a point the presented value is the pre-animation position, and nothing re-reports when the
    /// animation lands — CoreList has no per-frame hook outside user scrolling.
    ///
    /// Ancestor-path-agnostic in the same way `presentedFrame(of:)` is: a row carried by `crossingOverlay`
    /// during a structural transition converts correctly too.
    public func settledFrame(of view: UIView) -> CGRect {
        convert(view.bounds, from: view)
    }

    /// How far the model viewport leads the presented one: `(engine.offset − contentHost model origin)` plus
    /// the additive viewport correction. Zero whenever nothing is animating the viewport.
    private var modelToPresentedViewportDelta: CGFloat {
        (engine.offset - engine.contentHost.bounds.origin.y)
            + animationController.viewportOffset(at: animationController.now())
    }
    // The height of the currently loaded (settled) window.
    public var settledContentHeight: CGFloat { activeWindow.height }

    /// The top-inset slack currently reserved for the lowest `pinsToBottomEdge` row — the public read
    /// of `bottomEdgePinSlack(for:)`, which is `ListViewImpl.calculatePinToEdgeTopInset`
    /// (`Display/Source/ListView.swift:1106`). Zero unless index 0 is loaded and a pinned row is in
    /// the window.
    ///
    /// A host needs it wherever it asks "how much viewport is left over once the whole collection is
    /// on screen": the underfill alignment places the window on `viewportInsets.top + this`, so the
    /// free space beyond the last row is short by exactly this much. `ListViewImpl` folds the same
    /// term into `effectiveInsets.top` before it measures that leftover (`ListView.swift:1238-1241`).
    ///
    /// Offset-independent, like `settledContentHeight` and for the same reason: it is built from
    /// intra-window spans (`pinned.frame.maxY - window.minY`), never from a placement, so a
    /// rubber-band overscroll cannot move it.
    public var currentBottomEdgePinSlack: CGFloat { bottomEdgePinSlack(for: activeWindow) }

    private var dirtyIndices: Set<Int> = []
    private var dirtyAnimated = false
    /// Identities whose content was reconciled in the pass currently being applied. Window
    /// construction measures exactly these with the pass transition; everything else measures
    /// `.immediate`. Cleared at the end of each pass.
    /// Monotonic serial for attachment runs. The only attachment state outside `activeWindow`.
    var nextAttachmentSerial: UInt64 = 0
    /// The representative descriptor last applied to each live serial, so the next pass can decide
    /// whether to reconfigure. Keyed by serial because that is what identifies a run's view.
    var appliedAttachmentDescriptors: [UInt64: CoreListAttachedItem] = [:]
    /// Attachment analogue of `reconciledIdentities`; cleared with it at the end of each pass.
    var reconciledAttachmentSerials: Set<UInt64> = []
    /// Set by an attachment's `onContentDidChange`. A flag rather than a set: a pass re-measures
    /// every loaded attachment anyway.
    var attachmentsAreDirty = false
    /// The item array the CURRENT `activeWindow` was built against. `resolveAttachments` maps a prior
    /// run's collection indices back to identities through this, because `_items` has already been
    /// replaced by the time a pass resolves attachments.
    var priorItems: [CoreListItem] = []
    /// Runs that no new run claimed in the most recent `resolveAttachments`, with the views they
    /// owned. Recorded rather than acted on, because only the enclosing pass knows whether a run left
    /// the loaded WINDOW (silent) or the COLLECTION (a genuine departure that fades). Every producer
    /// must be drained by its caller; both call sites do.
    var pendingAttachmentDepartures: [AttachmentDeparture] = []
    /// Views fading out in the exit overlay after a genuine attachment departure. Held so
    /// `assertOverlayInvariants` can recognise a THIRD legitimate kind of exit-overlay child, and so
    /// a leak still trips the assertion rather than being waved through.
    let fadingAttachmentViews = NSHashTable<UIView>.weakObjects()
    /// The baked flight the render server is currently playing, or `nil` under main-thread-driven
    /// motion. While non-nil, attachments park at its destination and ride a composed keyframe.
    var activeScrollFlight: ScrollFlight?

    // Internal: read by `fadingInAttachmentSerials` in CoreVirtualListView+Attachments.swift.
    var reconciledIdentities: Set<AnyHashable> = []
    /// True when this pass changes `contentWidth`, which makes every loaded row and attachment
    /// re-measure at a new width rather than merely move. Paired with `reconciledIdentities` and
    /// cleared with it.
    var contentWidthChangedInPass = false
    /// Views CREATED during the pass currently being applied, by object identity. A fresh view has no
    /// prior layout to animate its internals from, so it measures `.immediate` even when the pass is
    /// animated — the exclusion the item contract has always promised. Recorded in `viewForItem`, the
    /// single funnel through which a row's view is obtained, and cleared with `reconciledIdentities`.
    var freshViewsThisPass: Set<ObjectIdentifier> = []
    /// The transition of the pass currently being applied, paired with `reconciledIdentities`.
    /// Window construction is reached from the mutation pass AND from scroll-driven rebalancing;
    /// the latter leaves the set empty, so its rows correctly measure `.immediate` without any
    /// caller having to say so.
    // Internal for the same reason as `contentWidth` above.
    var currentPassTransition: CoreListTransition = .immediate
    private var dirtyFlushScheduled = false
    private var isApplyingChanges = false
    var defaultDirtyDuration: TimeInterval = 0.3

    init(frame: CGRect = .zero,
         engine: ScrollEngine = UIKitScrollEngine(),
         animationController: ListAnimationController = ListAnimationController(),
         scheduler: Scheduler = MainQueueScheduler()) {
        self.engine = engine
        self.animationController = animationController
        self.scheduler = scheduler
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        self.engine = UIKitScrollEngine()
        self.animationController = ListAnimationController()
        self.scheduler = MainQueueScheduler()
        super.init(coder: coder)
        setup()
    }

    // Public entry point for cross-module consumers (e.g. the TelegramUI adapter).
    // Uses a distinct argument label so it does not collide with the all-defaulted
    // internal designated initializer, and keeps the ScrollEngine/Scheduler types
    // module-internal.
    public convenience init(forEmbedding frame: CGRect) {
        let engine = PhysicsScrollEngine()
        engine.decelerationMode = .keyframe
        self.init(frame: frame, engine: engine, animationController: ListAnimationController(), scheduler: MainQueueScheduler())
    }

    private func setup() {
        // No background: the list is transparent by default and never paints its own backdrop. Hosts
        // composite it over whatever they own (a chat wallpaper, a themed controller view), so an
        // opaque background here would hide that. Callers that want one set it themselves.
        engine.onScroll = { [weak self] offset in
            self?.handleUserScroll(offset)
        }
        engine.onWillBeginDragging = { [weak self] in
            // Mirrors `ListViewImpl.scrollViewWillBeginDragging` (`Display/Source/ListView.swift:879`).
            // The TOUCH releases the pin, not the movement: a programmatic offset write keeps it, which
            // is what every self-update flush and inset change is.
            self?.holdsPinnedRow = false
            self?.willBeginDragging?()
        }
        engine.onDidEndDragging = { [weak self] in
            self?.didEndDragging?()
        }
        engine.onFlightChanged = { [weak self] flight in
            guard let self else { return }
            let wasFlying = self.activeScrollFlight != nil
            self.activeScrollFlight = flight
            self.renderAttachments()
            // After renderAttachments, so a host reading geometry from this callback sees the solve for
            // the state it is being told about rather than the one it replaced.
            if wasFlying && flight == nil {
                self.didEndScrolling?()
            }
        }
        container.backgroundColor = .clear
        container.clipsToBounds = false
        crossingOverlay.backgroundColor = .clear
        crossingOverlay.clipsToBounds = false
        crossingOverlay.isUserInteractionEnabled = false
        exitOverlay.backgroundColor = .clear
        exitOverlay.clipsToBounds = false
        exitOverlay.isUserInteractionEnabled = false
        carouselExitOverlay.backgroundColor = .clear
        carouselExitOverlay.clipsToBounds = false
        carouselExitOverlay.isUserInteractionEnabled = false
        attachmentContainer.backgroundColor = .clear
        attachmentContainer.clipsToBounds = false
        // BELOW the content host, matching ListViewImpl's `insertSubnode(_:belowSubnode:)` for its
        // temporary previous nodes. Nothing paints over the strip during a correct travel — the
        // incoming rows are off-screen at t=0 and `container` has no background — so this changes
        // nothing about the intended appearance. It is here so that if the geometry is ever wrong
        // again, live rows win instead of losing.
        addSubview(carouselExitOverlay)
        addSubview(engine.contentHost)
        engine.contentHost.addSubview(container)
        engine.contentHost.addSubview(crossingOverlay)
        engine.contentHost.addSubview(exitOverlay)
        // Attachments LAST — above every overlay, not just above `container`. A crossing carry and a
        // ghost block are row content that happens to be leaving, and a floating header is above row
        // content; that is what makes it a floating header. Ordered below `exitOverlay` instead, a
        // departing row draws over a parked header for the whole exit fade, and because the row is
        // opaque the header reads as fading in from nothing once the ghost clears. Reported from the
        // demo as "Load +5, settle, Load -5 — the top header crossfades 0->1 in place".
        engine.contentHost.addSubview(attachmentContainer)
        animationController.setReferenceLayer(container.layer)
        animationController.seedViewport(layer: engine.contentHost.layer)
        animationController.addViewportMirrorLayer(carouselExitOverlay.layer)
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        engine.contentHost.frame = bounds
        layoutExitOverlay()
    }

    /// `additionalScrollDistance` displaces the resolved anchor by that many points, on top of
    /// whatever compensation an inset change already applies — positive moves content DOWN, the same
    /// sign convention as a growing top inset. It is the analogue of `ListViewImpl.transaction`'s
    /// parameter of the same name, which folds into the identical `offsetFix`
    /// (`Display/Source/ListView.swift:3275`) so that one pass can both re-inset and scroll by a
    /// caller-chosen delta. Being an anchor displacement rather than a post-hoc offset write, it
    /// composes with the pass's window build and edge clipping instead of fighting them.
    ///
    /// `compensatesInsetChange` selects whether a top-inset change moves content. The default `true`
    /// projects the resolved anchor by `newTopInset - oldTopInset`, preserving its settled distance from
    /// the inset edge. Passing `false` drops only that addend, so content keeps its screen position while
    /// the inset edge moves under it — the geometry ListViewImpl produces when it zeroes `offsetFix`
    /// (`Display/Source/ListView.swift:3276`). Everything else is unaffected: the new insets still take
    /// effect for content x/width, the viewport band, the load band, and the loaded-top pin, exactly as
    /// ListViewImpl still assigns `self.insets` and still runs `snapToBounds`. Whether an inset change was
    /// caused by the user's own in-progress gesture — the only reason to pass `false` — is caller policy;
    /// this view stays policy-free.
    public func applyChanges(items newItems: [CoreListItem]? = nil,
                      newSize: CGSize? = nil,
                      newInsets: UIEdgeInsets? = nil,
                      scrollTo: CoreListScrollTarget? = nil,
                      additionalScrollDistance: CGFloat = 0.0,
                      anchorMode: CoreListAnchorMode = .automatic,
                      compensatesInsetChange: Bool = true,
                      absorbsEdgeChangeIntoOverscroll: Bool = false,
                      animatesInsertions: Bool = true,
                      transition: CoreListTransition) {
        let animationDuration = transition.duration
        if isApplyingChanges {
            scheduler.schedule { [weak self] in
                self?.applyChanges(items: newItems,
                                   newSize: newSize,
                                   newInsets: newInsets,
                                   scrollTo: scrollTo,
                                   additionalScrollDistance: additionalScrollDistance,
                                   anchorMode: anchorMode,
                                   compensatesInsetChange: compensatesInsetChange,
                                   absorbsEdgeChangeIntoOverscroll: absorbsEdgeChangeIntoOverscroll,
                                   animatesInsertions: animatesInsertions,
                                   transition: transition)
            }
            return
        }
        isApplyingChanges = true
        // BEFORE anything this pass writes. Every bound layer's model position is still the base its
        // render tree was committed against, which is the only moment `presented - model` means the
        // additive contribution — `render()` overwrites it ~570 lines below. Re-entrant calls are
        // deferred to the scheduler above rather than nested, so one pass owns this snapshot.
        animationController.capturePresentedPositionOffsets()
        defer {
            animationController.clearPresentedPositionOffsets()
            isApplyingChanges = false
            reconciledIdentities.removeAll()
        reconciledAttachmentSerials.removeAll()
            reconciledAttachmentSerials.removeAll()
                freshViewsThisPass.removeAll()
            contentWidthChangedInPass = false
            currentPassTransition = .immediate
            refreshReachedLoadedEdges()
            assertOverlayInvariants()
        }

        let hasItems = newItems != nil
        let hasNewSize = newSize != nil
        let hasNewInsets = newInsets != nil
        let hasScrollTo = scrollTo != nil
        let hasDirty = !dirtyIndices.isEmpty
        let hasDirtyAttachments = attachmentsAreDirty
        let hasAdditionalScrollDistance = additionalScrollDistance != 0.0
        guard hasItems || hasNewSize || hasNewInsets || hasScrollTo || hasDirty
                || hasDirtyAttachments || hasAdditionalScrollDistance else { return }

        if let newItems, let duplicate = Self.firstDuplicatePair(in: newItems) {
            preconditionFailure(
                "applyChanges: items must be mutually unique by identity. Duplicate at indices \(duplicate.first) and \(duplicate.second)."
            )
        }

        if activeWindow.isEmpty, let newSize { logicalSize = newSize }
        if activeWindow.isEmpty, let newInsets { viewportInsets = newInsets }

        if activeWindow.isEmpty, newItems == nil {
            if _items.isEmpty {
                engine.contentHost.frame = bounds
                layoutExitOverlay()
            } else {
                rebuildFromScratch()
            }
            return
        }
        if activeWindow.isEmpty, let newItems, newItems.isEmpty {
            _items = newItems
            if ghostMemberViews.isEmpty, ghostLedger.snapshots.isEmpty {
                rebuildFromScratch()
            }
            return
        }

        // A `scrollTo` pass halts any live momentum (the §4(b) halt idiom). Do it HERE, before the first
        // `engine.offset` read below: the halt catches a keyframe flight at its true instantaneous
        // position, so halting mid-pass would leave every geometry decision — and the viewport animation's
        // `from` — anchored on a position the content has already left. `resolveAnchor`'s `scrollTo` branch
        // is its first branch, so this fires for exactly the passes that used to halt there. See
        // docs/superpowers/specs/2026-07-26-clock-free-mutation-pass-design.md.
        if hasScrollTo { engine.haltMotionInPlace() }

        // A non-zero `additionalScrollDistance` is a programmatic displacement too, so it halts for the
        // same reason — and `ListViewImpl` halts on it identically (`ListView.swift:3238`). The
        // `.automatic` guard is that halt's else-if chain: ListViewImpl reaches it only when the pass
        // did not position content itself, i.e. no `scrollToItem` (halted just above) and no stationary
        // item range, whose analogue here is `.preserveVisibleContent`.
        if !hasScrollTo, hasAdditionalScrollDistance, anchorMode == .automatic {
            engine.haltMotionInPlace()
        }

        // Re-anchor on the presented viewport once, before the first `engine.offset` read below. Everything
        // downstream — the anchor witness (:1481), buildWindow's projected load band, the overscroll gate
        // (:588, :819-828), refreshReachedLoadedEdges and the final coordinate re-base — then resolves
        // against the current viewport instead of the last sampling tick's. No-op after a halt above.
        engine.syncToPresentedPosition()

        let oldItems = _items
        let oldViewportInsets = viewportInsets
        // Captured BEFORE `if let newSize { logicalSize = newSize }` below, so the old attachment
        // snapshot solves against the geometry it actually had.
        let oldLogicalSize = logicalSize
        let effectiveItems = newItems ?? oldItems
        let logicalSizeChanged = newSize.map { $0 != logicalSize } ?? false
        let insetsChanged = newInsets.map { $0 != viewportInsets } ?? false
        // A caller-chosen `additionalScrollDistance` displaces screen-space content exactly as a
        // size/inset change does, so it must take the same three decisions below: settled-membership
        // crossing, ghost geometry, and — the load-bearing one — the ONE shared additive viewport track
        // that owns a pass's screen displacement. Without this the pass reads as a pure coordinate
        // rebase and each loaded row animates its own position instead: the same rigid motion for the
        // rows that happen to be loaded, but ghost blocks, viewport carries and rows entering the window
        // stay behind, because they follow the viewport track and nothing else.
        let displacesViewport = logicalSizeChanged || insetsChanged || hasAdditionalScrollDistance
        let diff: ItemDiff
        if hasItems {
            diff = Self.computeDiff(old: oldItems, new: effectiveItems)
        } else {
            diff = ItemDiff(
                survivorMap: Dictionary(uniqueKeysWithValues: oldItems.indices.map { ($0, $0) }),
                deletes: [],
                inserts: []
            )
        }
        let hasContentChanges = hasItems && diff.survivorMap.contains { oldIndex, newIndex in
            !oldItems[oldIndex].isEqual(to: effectiveItems[newIndex])
        }

        var survivorMapNewToOld: [Int: Int] = [:]
        for (oldIndex, newIndex) in diff.survivorMap {
            survivorMapNewToOld[newIndex] = oldIndex
        }

        let oldWindow = activeWindow
        let oldContainerOriginY = containerOriginY
        let oldBoundsOriginY = engine.offset
        let transactionTime = animationController.now()
        let currentViewportCorrection = animationController.viewportOffset(at: transactionTime)
        let oldEdges = loadedEdgeRange(for: oldWindow,
                                       originY: oldContainerOriginY,
                                       itemCount: oldItems.count)
        var oldMaximum = oldEdges.max
        if let minimum = oldEdges.min,
           let maximum = oldMaximum,
           maximum < minimum {
            oldMaximum = minimum
        }
        // Captured here, while `viewportInsets`, `logicalSize` and `_items` are all still the pass's
        // OLD state — the geometry assignment is below.
        let oldPinSlack = bottomEdgePinSlack(for: oldWindow)
        var oldSettledOffset = oldBoundsOriginY
        if let minimum = oldEdges.min {
            oldSettledOffset = max(oldSettledOffset, minimum)
        }
        if let maximum = oldMaximum {
            oldSettledOffset = min(oldSettledOffset, maximum)
        }
        let presentationOverscroll = oldBoundsOriginY - oldSettledOffset
        let oldState = settledState(oldWindow,
                                    sourceItems: oldItems,
                                    containerOriginY: oldContainerOriginY,
                                    at: transactionTime)
        let oldAttachmentState = settledAttachmentState(oldWindow,
                                                        containerOriginY: oldContainerOriginY,
                                                        insets: oldViewportInsets,
                                                        logicalHeight: oldLogicalSize.height,
                                                        // `oldBoundsOriginY`, NOT `oldSettledOffset`:
                                                        // this snapshot says where the attachment WAS,
                                                        // and `renderAttachments` placed it at the
                                                        // PRESENTED offset — rubber-band residual and
                                                        // all. Handing it the edge-clamped offset makes
                                                        // the pass believe a parked attachment sat one
                                                        // overscroll away from where it was drawn, so
                                                        // the transition starts there: the attachment
                                                        // jumps by the residual and eases back. Rows
                                                        // are immune because their frames are
                                                        // container-local and offset-independent; the
                                                        // attachment solve consumes the offset.
                                                        offset: oldBoundsOriginY,
                                                        // The viewport displacement already applied
                                                        // to the OLD rendered content.
                                                        viewportCorrection: currentViewportCorrection,
                                                        at: transactionTime)
        var oldRenderedState = oldState
        for (identity, state) in crossingCarryState(sourceItems: oldItems,
                                                    at: transactionTime) {
            precondition(oldRenderedState[identity] == nil)
            oldRenderedState[identity] = state
        }
        let renderedOldViewport = oldSettledOffset + currentViewportCorrection
        let currentAnchorIdentity = oldWindow.items.first { item in
            guard oldItems.indices.contains(item.index),
                  let state = oldState[oldItems[item.index].identity]
            else { return false }
            return state.contentY + state.size.height > renderedOldViewport
        }.map { oldItems[$0.index].identity }
            ?? oldWindow.items.last.map { oldItems[$0.index].identity }

        // Captured across the geometry assignment below, because a pass that changes `contentWidth`
        // re-measures every loaded row at the new width — see `measureTransition(forItemAt:view:)`.
        // The 0.5 epsilon is the one `CoreListNodeHostView.update(width:transition:)` uses to decide
        // whether to relayout at all; the two must agree, or a row either animates without
        // relayouting or relayouts without animating.
        let widthBeforePass = contentWidth
        if let newSize { logicalSize = newSize }
        if let newInsets { viewportInsets = newInsets }
        // The OLD window measured against the NEW viewport geometry — precisely what `ListViewImpl`
        // computes at `Display/Source/ListView.swift:3291`, where `calculatePinToEdgeTopInset()` runs
        // after `self.insets`/`self.visibleSize` are assigned but before anything is re-laid out. The
        // pass's own `buildWindow` applies the real new slack; this pair only says how far the
        // EFFECTIVE inset edge moved, which is what the anchor must be projected by.
        let updatedPinSlack = bottomEdgePinSlack(for: oldWindow)
        contentWidthChangedInPass = abs(contentWidth - widthBeforePass) > 0.5
        if !oldItems.isEmpty, effectiveItems.isEmpty {
            engine.haltMotionInPlace()
        }

        let consumedDirty = dirtyIndices
        dirtyIndices.removeAll()
        dirtyAnimated = false
        // Consumed HERE rather than in `flushDirtyItems`, so the flag stays set until a pass has
        // actually run: a flush that early-outs for any other reason cannot silently drop a pending
        // attachment re-measure.
        attachmentsAreDirty = false

        let wasOverscrolledPrePass = abs(presentationOverscroll) > 0.5

        var moveReuseNewToOld: [Int: Int] = [:]
        for move in diff.moves where oldWindow.contains(index: move.old) {
            moveReuseNewToOld[move.new] = move.old
        }

        reconciledIdentities.removeAll()
        freshViewsThisPass.removeAll()
        currentPassTransition = transition
        if hasItems {
            func reconcileContent(newIndex: Int, oldIndex: Int) {
                guard oldItems.indices.contains(oldIndex),
                      effectiveItems.indices.contains(newIndex),
                      !oldItems[oldIndex].isEqual(to: effectiveItems[newIndex]),
                      let view = oldRenderedState[oldItems[oldIndex].identity]?.view
                else { return }
                effectiveItems[newIndex].apply(to: view, transition: transition)
                reconciledIdentities.insert(effectiveItems[newIndex].identity)
            }
            for (newIndex, oldIndex) in survivorMapNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
            for (newIndex, oldIndex) in moveReuseNewToOld {
                reconcileContent(newIndex: newIndex, oldIndex: oldIndex)
            }
        }

        // Dirty rows changed their own content, so they are reconciled too.
        for index in consumedDirty {
            if let item = oldWindow.items.first(where: { $0.index == index }) {
                if effectiveItems.indices.contains(index) {
                    reconciledIdentities.insert(effectiveItems[index].identity)
                }
                _ = item.view.update(width: contentWidth, transition: transition)
            }
        }

        if hasItems { _items = effectiveItems }

        let isNoOverlapSwap = hasItems && !hasScrollTo
            && diff.survivorMap.isEmpty && !effectiveItems.isEmpty

        // The pin latch, resolved against THIS pass's collection (`_items` is assigned above, so
        // `lowestPinnedItemIndex` is current).
        if lowestPinnedItemIndex == nil || isNoOverlapSwap {
            // The row left the collection, or this is a full replace — a chat switch or hole reload,
            // whose incoming collection must not inherit a hold from the outgoing one.
            holdsPinnedRow = false
        } else if let scrollTo, scrollTo.index == lowestPinnedItemIndex {
            // `ListView.swift:2737`. The chat produces exactly one of these per streamed answer, from
            // `scrollToPinToTopStableId` (`ChatHistoryListNode.swift:2244-2246`), which fires only when
            // the pinned stableId CHANGES.
            holdsPinnedRow = true
        }
        let resolvedAnchor: ResolvedAnchor?
        if effectiveItems.isEmpty {
            resolvedAnchor = nil
        } else {
            guard let anchor = resolveAnchor(
                scrollTo: scrollTo,
                anchorMode: anchorMode,
                isNoOverlapSwap: isNoOverlapSwap,
                diff: diff,
                oldWindow: oldWindow,
                oldContainerOriginY: oldContainerOriginY,
                oldSettledOffset: oldSettledOffset,
                oldTopInset: oldViewportInsets.top,
                oldItemCount: oldItems.count
            )
            else {
                rebuildFromScratch()
                return
            }
            resolvedAnchor = anchor
        }

        let newWindow: Window
        if let resolvedAnchor {
            // Zero when the caller declined inset compensation, which is the whole of what
            // `compensatesInsetChange: false` does: content holds its screen position while the inset edge
            // moves under it. The new insets are already installed above and still drive content x/width,
            // the viewport band, the load band and the loaded-top pin below — the same split ListViewImpl
            // makes when it zeroes `offsetFix` but still assigns `self.insets` and still snaps to bounds.
            // Against the EFFECTIVE top edge (`viewportInsets.top + slack`), not the raw inset: while
            // a bottom-edge pin is active the slack absorbs an inset change — exactly, until it runs
            // out — so the effective edge moves less than the inset did, and content must follow the
            // effective edge. `ListViewImpl` does the same at `Display/Source/ListView.swift:3291`.
            //
            // Needs no gate, unlike `ListViewImpl`'s, whose `+=` sits inside `if let
            // updateSizeAndInsets`. The two samples read the SAME `oldWindow` and the SAME `_items`
            // (`_items` is assigned further down), so they differ only if `logicalSize` or
            // `viewportInsets` changed between them — the addend is provably zero on any other pass.
            let pinSlackDelta = updatedPinSlack - oldPinSlack
            let topInsetDelta = compensatesInsetChange
                ? (viewportInsets.top - oldViewportInsets.top) + pinSlackDelta
                : 0.0
            // `additionalScrollDistance` rides the same addend as the inset compensation, which is
            // exactly where ListViewImpl puts it (`offsetFix += additionalScrollDistance`), and it
            // composes with an explicit `scrollTo` for the same reason it does there: the scroll
            // positions content first, then the displacement moves it.
            //
            // The two branches below are the two halves of what used to be one `projectedPointOffset`
            // expression; only the `scrollTo` half is deferred, because only it needs the anchor's
            // measured height. `.resolved` is produced by resolveAnchor's `scrollTo` branch and by
            // nothing else, so the branch split here is exactly the old `hasScrollTo` split — note
            // in particular that it does NOT add `topInsetDelta`.
            let resolveY: (CGFloat, UIView & CoreListItemView) -> CGFloat
            switch resolvedAnchor.offset {
            case let .fixed(pointOffset):
                let value = pointOffset + topInsetDelta + additionalScrollDistance
                resolveY = { _, _ in value }
            case let .resolved(resolve):
                let base = viewportInsets.top + additionalScrollDistance
                resolveY = { height, view in base + resolve(height, view) }
            }
            // The loaded-top pin would swallow the displacement whole, so a caller asking for one opts
            // out of it and lets the window build clip instead. That reproduces ListViewImpl, where the
            // equivalent pin is `snapToBounds` — which only closes a GAP above the top item. A positive
            // displacement at the top edge opens such a gap and is clipped away by both; a negative one
            // scrolls down into content, which ListViewImpl honours and the pin would discard.
            let pinsLoadedTop = !resolvedAnchor.preservesVisibleContent
                && !resolvedAnchor.isPin
                && !hasScrollTo
                && !hasAdditionalScrollDistance
                && oldWindow.startIndex == 0
                && oldEdges.min.map { abs(oldSettledOffset - $0) <= 1e-6 } == true
            // Only a `.fixed` anchor was placed against the OLD effective top edge, so only it needs
            // re-projecting onto the new one. A `.resolved` anchor — an explicit `scrollTo`, or the pin
            // latch itself — computes its placement from the geometry this pass is building, and the
            // `pinsLoadedTop` branch translates the window onto `topEdge` outright.
            //
            // And only an anchor ABOVE the pinned row. The absorption invariant is that the pinned row
            // and everything below it hold still while the content above spends the slack: an anchor
            // above the pin has to move by that spend to deliver it, and an anchor at or below the pin
            // delivers it by holding — its old screen position is ALREADY the right answer, because
            // nothing above it can displace it. Projecting there moves it by the whole slack delta.
            //
            // Not hypothetical, and it is the pass that ENDS a stream: the typing draft carrying
            // `TypingDraftMessageAttribute` is replaced by the real cloud message
            // (`ChatHistoryListNode.swift:2240`), so index 0 departs, `topItemWasDeleted` sends
            // `resolveAnchor` to the first survivor — the pinned row — and the final message's height
            // differing from the last draft's moved the pin by exactly that difference. One jerk, at
            // the end of streaming, only when the two measure differently.
            let pinSlackBaseline: CGFloat? = {
                guard let pinnedIndex = lowestPinnedItemIndex,
                      resolvedAnchor.index < pinnedIndex
                else { return nil }
                guard case .fixed = resolvedAnchor.offset else { return nil }
                return updatedPinSlack
            }()
            newWindow = buildWindow(anchoredAt: resolvedAnchor.index,
                                    resolveY: resolveY,
                                    pinsLoadedTop: pinsLoadedTop,
                                    pinSlackBaseline: pinSlackBaseline,
                                    sourceWindow: oldWindow,
                                    survivorMapNewToOld: survivorMapNewToOld,
                                    moveReuseNewToOld: moveReuseNewToOld)
        } else {
            newWindow = Window()
        }

        let newIdentities = Set(effectiveItems.map(\.identity))
        let oldLoadedIdentities = oldWindow.items.map { oldItems[$0.index].identity }
        let newLoadedIdentities = newWindow.items.map { effectiveItems[$0.index].identity }
        let promotedCrossingIdentities = Set(crossingCarries.keys)
            .intersection(newLoadedIdentities)
        for identity in promotedCrossingIdentities {
            crossingCarries.removeValue(forKey: identity)
        }
        let sharedLoadedIdentities = Set(oldLoadedIdentities).intersection(newLoadedIdentities)
        let isOverlappingScroll = hasScrollTo && !sharedLoadedIdentities.isEmpty
        let isCarouselScroll = hasScrollTo && sharedLoadedIdentities.isEmpty
            && !oldWindow.isEmpty && !newWindow.isEmpty
        // A carousel travelling to a destination that is entirely new content: the incoming strip IS
        // the context, not an insertion into one, so neither end should fade — it is one rigid
        // movement between two strips, already owned by the shared viewport track.
        //
        // The test is the DESTINATION WINDOW, not the whole collection. Both narrower and wider than
        // it sounds:
        //   • narrower than `isCarouselScroll` (which only says the two LOADED windows are disjoint):
        //     a far jump within a surviving collection is a carousel too, and a genuinely new row
        //     landing among survivors in its destination is real new content that must still fade.
        //   • wider than whole-collection disjointness, which is what this used to test and which is
        //     wrong for real hosts. A chat's non-message rows carry CONSTANT identities — an unread
        //     separator is `4 << 40`, chat-info `6 << 40` — so one of them survives a wholesale
        //     history replace and made the collection-level test permanently false. What matters is
        //     whether anything in the place we are travelling TO was already there.
        let destinationIsEntirelyNew = !newLoadedIdentities.isEmpty
            && Set(newLoadedIdentities).isDisjoint(with: Set(oldItems.map(\.identity)))
        let isFullReplaceCarousel = isCarouselScroll && destinationIsEntirelyNew
        let potentialCarryIdentities: Set<AnyHashable> = {
            guard (isOverlappingScroll || isCarouselScroll), animationDuration > 0 else {
                return []
            }
            return Set(oldLoadedIdentities)
                .subtracting(newLoadedIdentities)
                .intersection(newIdentities)
        }()
        let hasStructuralMutation = !diff.deletes.isEmpty
            || !diff.inserts.isEmpty || !diff.moves.isEmpty
        let hasSettledMembershipTransition = hasStructuralMutation
            || displacesViewport
        let outgoingCrossingIdentities: Set<AnyHashable> = {
            guard hasSettledMembershipTransition else { return [] }
            return Set(oldRenderedState.keys)
                .subtracting(newLoadedIdentities)
                .intersection(newIdentities)
                .subtracting(potentialCarryIdentities)
        }()
        var survivorEndpointIndices: [AnyHashable: SurvivorEndpointIndices] = [:]
        for (oldIndex, newIndex) in diff.survivorMap {
            let identity = oldItems[oldIndex].identity
            survivorEndpointIndices[identity] = SurvivorEndpointIndices(
                oldIndex: oldIndex,
                newIndex: newIndex,
                isMoveParticipant: false
            )
        }
        for move in diff.moves where oldItems.indices.contains(move.old) {
            let identity = oldItems[move.old].identity
            survivorEndpointIndices[identity] = SurvivorEndpointIndices(
                oldIndex: move.old,
                newIndex: move.new,
                isMoveParticipant: true
            )
        }
        let hasStructuralPositionChange = hasScrollTo
            || !diff.deletes.isEmpty || !diff.inserts.isEmpty || !diff.moves.isEmpty
        if hasStructuralPositionChange {
            // Snapshot and settle while these owners are still unbound. Rendering can
            // synchronously reattach an owner that enters the new window, after which
            // it is too late to discard a correction based on stale predecessor geometry.
            for identity in animationController.activeUnboundPositionIdentities(at: transactionTime)
                where settledPredecessorsChanged(identity: identity,
                                                  oldItems: oldItems,
                                                  newItems: effectiveItems) {
                animationController.settleUnboundPosition(identity: identity,
                                                          at: transactionTime)
            }
        }

        let exitingIdentities = Set(oldRenderedState.keys).subtracting(newIdentities)
        // Classified here, before ghost blocks are formed, because a whole-run departure has to be
        // handed to `makeGhostBlock` at construction — a block's local extent is fixed at
        // `GhostBlockLedger.insert` and cannot be widened afterwards. `newIdentities` and
        // `oldAttachmentState` are both already in scope at this point.
        let attachmentDepartures = classifyAttachmentDepartures(newItems: effectiveItems)
        pendingAttachmentDepartures.removeAll()
        for departure in attachmentDepartures.silent {
            dropAttachmentSilently(departure)
        }
        var departingRuns: [[SettledLiveItem]] = []
        let departingStates = oldRenderedState.values
            .filter { !newIdentities.contains($0.identity) }
            .sorted { $0.index < $1.index }
        for state in departingStates {
            crossingCarries.removeValue(forKey: state.identity)
            if let last = departingRuns.indices.last,
               departingRuns[last].last?.index == state.index - 1 {
                departingRuns[last].append(state)
            } else {
                departingRuns.append([state])
            }
        }
        // A genuine departure joins a block when its whole old member range lies inside that block's
        // departed range; otherwise it fades in place.
        var attachmentsByRunIndex: [Int: [(departure: AttachmentDeparture,
                                           state: SettledAttachment)]] = [:]
        var fadingInPlace: [AttachmentDeparture] = []
        for departure in attachmentDepartures.genuine {
            guard let state = oldAttachmentState[departure.run.serial] else {
                fadingInPlace.append(departure)
                continue
            }
            let memberOldIndices = oldItems.indices.filter {
                departure.run.memberIdentities.contains(oldItems[$0].identity)
            }
            let runIndex = departingRuns.firstIndex { run in
                guard let first = run.first, let last = run.last else { return false }
                let range = first.index..<(last.index + 1)
                return !memberOldIndices.isEmpty
                    && memberOldIndices.allSatisfy { range.contains($0) }
            }
            if let runIndex {
                attachmentsByRunIndex[runIndex, default: []].append((departure, state))
            } else {
                fadingInPlace.append(departure)
            }
        }

        let newGhostBlockIDs = departingRuns.enumerated().map { index, run in
            makeGhostBlock(from: run,
                           attachments: attachmentsByRunIndex[index] ?? [],
                           transition: transition,
                           transactionTime: transactionTime,
                           fadesOut: !isFullReplaceCarousel)
        }

        // Whatever did not join a block fades where it stood — the merge-loser case. A carousel fades
        // nothing at either end, outgoing included, which is the same predicate `makeGhostBlock`
        // receives as `fadesOut:` for the departing rows.
        fadeDepartingAttachments(fadingInPlace,
                                 oldState: oldAttachmentState,
                                 transition: transition,
                                 transactionTime: transactionTime,
                                 fadesOut: !isFullReplaceCarousel)

        var newGhostBlockByDepartedIdentity: [AnyHashable: GhostBlockID] = [:]
        for (run, blockID) in zip(departingRuns, newGhostBlockIDs) {
            for item in run {
                newGhostBlockByDepartedIdentity[item.identity] = blockID
            }
        }
        for identity in outgoingCrossingIdentities {
            guard crossingCarries[identity] == nil,
                  let old = oldRenderedState[identity] else { continue }
            old.view.onContentDidChange = nil
            old.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            old.view.frame = CGRect(origin: CGPoint(x: old.contentX, y: old.contentY),
                                    size: old.size)
            crossingOverlay.addSubview(old.view)
            crossingCarries[identity] = CrossingCarry(
                identity: identity,
                view: old.view,
                settledX: old.contentX,
                settledWidth: old.size.width,
                settledContentY: old.contentY,
                releaseGeneration: nil
            )
        }
        let newViews = Set(newWindow.items.map { ObjectIdentifier($0.view) })
        for oldItem in oldWindow.items where !newViews.contains(ObjectIdentifier(oldItem.view)) {
            let identity = oldItems[oldItem.index].identity
            if !exitingIdentities.contains(identity),
               !potentialCarryIdentities.contains(identity),
               !outgoingCrossingIdentities.contains(identity) {
                animationController.unbind(identity: identity,
                                           layer: oldItem.view.layer,
                                           at: transactionTime)
            }
        }
        for item in oldItems
            where !newIdentities.contains(item.identity)
                && !exitingIdentities.contains(item.identity) {
            animationController.removeLive(identity: item.identity)
        }

        activeWindow = newWindow
        priorItems = effectiveItems
        render()

        let resolvedAnchorIdentity = resolvedAnchor.flatMap { anchor in
            effectiveItems.indices.contains(anchor.index)
                ? effectiveItems[anchor.index].identity
                : nil
        }
        let anchorCoordinateShift: CGFloat = {
            guard let resolvedAnchor,
                  let identity = resolvedAnchorIdentity,
                  let oldAnchorY = oldState[identity]?.contentY,
                  let newAnchorY = settledContentY(in: newWindow,
                                                   index: resolvedAnchor.index,
                                                   containerOriginY: containerOriginY)
            else { return 0 }
            return newAnchorY - oldAnchorY
        }()
#if DEBUG
        if (logicalSizeChanged || insetsChanged),
           !hasItems, !hasScrollTo,
           !oldWindow.isEmpty, !newWindow.isEmpty {
            assert(resolvedAnchorIdentity.flatMap { oldState[$0] } != nil,
                   "nonempty geometry-only passes must retain their resolved anchor")
        }
#endif

        var newSettledOffset = containerOriginY - newWindow.minY
        let geometryMustSettleToLoadedEdges = logicalSizeChanged || insetsChanged
        if !hasScrollTo, diff.moves.isEmpty || geometryMustSettleToLoadedEdges,
           (!wasOverscrolledPrePass || geometryMustSettleToLoadedEdges) {
            let edges = loadedEdgeRange(for: newWindow, originY: containerOriginY)
            var maximum = edges.max
            if let minimum = edges.min, let rawMaximum = maximum, rawMaximum < minimum {
                maximum = minimum
            }
            if let minimum = edges.min { newSettledOffset = max(newSettledOffset, minimum) }
            if let maximum { newSettledOffset = min(newSettledOffset, maximum) }
        }
        // `presentationOverscroll` preserves the rubber-band MAGNITUDE across a geometry pass: the
        // content ends up the same distance past the edge it was before. That is right whenever the
        // edge stays where it is and the geometry around it changed (a rotation, a keyboard) — the
        // band is a presentation-only displacement and losing it would snap.
        //
        // It is exactly wrong when the EDGE ITSELF MOVES under content that is standing still.
        // Preserving the magnitude then teleports the content by the edge's travel. Measured on the
        // chat's overscroll-action hold, which moves the newest edge 106pt while a finger-held
        // overscroll of 156pt sits there: `newBounds = -185 + (-156.37) = -341.37`, i.e. still 156pt
        // past an edge that just moved — a 106pt jump at let-go.
        //
        // `absorbsEdgeChangeIntoOverscroll` says the caller wants the other reading: hold the
        // PRESENTED POSITION and let the band re-measure itself against the new edge (156 → 50 here).
        // Nothing moves, and a spring already in flight simply retargets, which is what "bounce back
        // from where I am, to the new inset" means.
        //
        // Both are needed by the same caller at different moments and neither is a default: the hold
        // ENGAGING wants absorb (the finger is holding the content still), while the hold RELEASING
        // over its ramp wants the magnitude preserved, because that is what carries the content back
        // down as the edge closes. Off by default, so every existing caller keeps today's behaviour.
        //
        // The container-origin term keeps it exact across a rebase, where holding the engine offset
        // literally still would move content by the rebase.
        let newBoundsOriginY: CGFloat
        if hasScrollTo {
            newBoundsOriginY = newSettledOffset
        } else if absorbsEdgeChangeIntoOverscroll {
            newBoundsOriginY = oldBoundsOriginY + (containerOriginY - oldContainerOriginY)
        } else {
            newBoundsOriginY = newSettledOffset + presentationOverscroll
        }
        setBoundsOriginY(newBoundsOriginY)
        if absorbsEdgeChangeIntoOverscroll {
            // Holding the engine offset is only half of holding the CONTENT. A drag in progress maps
            // finger travel to content through the rubber band, and this pass just moved an edge, so
            // the same finger position now bands differently — the content would jump on the very
            // next drag frame, one frame after the offset we so carefully preserved. Re-anchoring the
            // drag against the new edges is what makes "absorb" mean the same thing under a finger as
            // it does under a flight. No-op when nothing is dragging.
            engine.reanchorDragToCurrentPosition()
        }
        // Re-solve against the offset this pass just settled on. `render()` ran earlier, before the
        // final offset existed — harmless for rows, whose frames are offset-INDEPENDENT, but the
        // attachment solve consumes the offset, so a header parked against the pre-pass value lands
        // a whole inset-change away from where it belongs.
        renderAttachments()
        // Visibility also depends on the final offset. Publishing it from render() would combine
        // the new window with the old offset and leave destination rows paused after a scrollTo.
        notifyVisibleRects()

        for item in newWindow.items {
            let identity = effectiveItems[item.index].identity
            if oldRenderedState[identity]?.view !== item.view {
                attachLive(identity: identity, layer: item.view.layer)
            }
        }

        let newState = settledState(newWindow,
                                    sourceItems: effectiveItems,
                                    containerOriginY: containerOriginY,
                                    at: transactionTime)
        let liveEdges = Dictionary(uniqueKeysWithValues: newState.map { identity, state in
            (identity, GhostLiveEdges(minY: state.contentY,
                                      maxY: state.contentY + state.size.height))
        })
        let transactionOffset = engine.offset
        let oldLiveEdgeCoordinateShift = transactionOffset - oldBoundsOriginY
        let oldLiveEdges = Dictionary(uniqueKeysWithValues: oldState.map { identity, state in
            (identity, GhostLiveEdges(
                minY: state.contentY + oldLiveEdgeCoordinateShift,
                maxY: state.contentY + state.size.height + oldLiveEdgeCoordinateShift
            ))
        })
        let oldIDs = Set(oldRenderedState.keys)
        let newIDs = Set(newState.keys)
        let movedIDs = Set(diff.moves.compactMap { move in
            effectiveItems.indices.contains(move.new)
                ? effectiveItems[move.new].identity
                : nil
        })
        let hasGhostOrderChange = !diff.deletes.isEmpty
            || !diff.inserts.isEmpty
            || !diff.moves.isEmpty
        let hasMeasuredGhostGeometryChange = (hasDirty || hasContentChanges)
            && oldIDs.intersection(newIDs).contains { identity in
                guard let old = oldRenderedState[identity], let new = newState[identity] else {
                    return false
                }
                let epsilon: CGFloat = 1e-6
                return abs(old.contentY + oldLiveEdgeCoordinateShift - new.contentY) > epsilon
                    || abs(old.size.width - new.size.width) > epsilon
                    || abs(old.size.height - new.size.height) > epsilon
            }
        let hasGhostGeometryPass = hasGhostOrderChange
            || displacesViewport
            || hasMeasuredGhostGeometryChange
        let movedOldIndices = Set(diff.moves.map { $0.old })
        let movedNewIndices = Set(diff.moves.map { $0.new })
        let insertedIdentities: Set<AnyHashable> = Set(diff.inserts.compactMap { index -> AnyHashable? in
            guard effectiveItems.indices.contains(index),
                  !movedNewIndices.contains(index) else { return nil }
            return effectiveItems[index].identity
        })
        let anchorIdentity = resolvedAnchorIdentity
        let anchorY = anchorIdentity.flatMap { newState[$0]?.contentY }
        var moveAmbiguousNewBlockIDs: Set<GhostBlockID> = []
        // A carousel's departed strip has no live neighbourhood left to attach to: the destination is
        // a different region of the collection (the two loaded windows are disjoint, which is what
        // makes it a carousel), and the shared additive viewport track is ALREADY the exclusive owner
        // of the travel — for the outgoing strip exactly as much as for the incoming one. A boundary
        // witness here hands the outgoing strip a second vertical owner that walks it onto the
        // incoming one, which renders as the two windows interpenetrating for the whole jump.
        //
        // This is the outgoing counterpart of the rule the incoming side already states: "for a
        // non-overlapping carousel, the additive viewport track is the exclusive vertical-motion
        // owner for destination-only survivors".
        //
        // It only ever bit when the destination window contained collection INDEX 0. A full replace
        // leaves `initialGhostWitness` no surviving predecessor, so it falls to `ordinal == 0` and
        // proposes `newItems[0]` — which resolves to a target only when that row is loaded. Any other
        // far jump leaves index 0 outside the destination window, the witness stays `.unresolved`,
        // and the travel is rigid; a chat jumping to the newest message loads it every time.
        //
        // Blocks are born `.unresolved` in `makeGhostBlock`, so declining to attach one IS the fix:
        // `GhostBlockLedger.resolve` returns the block's own `settledRootY`, and the resulting
        // equal-endpoint `transitionGhostBlock` is an exact no-op.
        for id in newGhostBlockIDs where !isCarouselScroll {
            guard let render = ghostRenders[id],
                  let block = ghostLedger.snapshot(for: id) else { continue }
            let initialWitness = initialGhostWitness(
                block: block,
                departedRange: render.departedRange,
                diff: diff,
                movedOldIndices: movedOldIndices,
                movedNewIndices: movedNewIndices,
                insertedIdentities: insertedIdentities,
                oldItems: oldItems,
                newItems: effectiveItems,
                newState: newState,
                anchorY: anchorY,
                vacatedTopY: oldItems.indices.contains(render.departedRange.lowerBound)
                    ? oldState[oldItems[render.departedRange.lowerBound].identity]
                        .map { $0.contentY + oldLiveEdgeCoordinateShift }
                    : nil
            )
            _ = ghostLedger.setBoundaryLink(
                attachmentEdge: initialWitness.attachmentEdge,
                witness: initialWitness.witness,
                for: id
            )
            if let identity = ghostWitnessIdentity(initialWitness.witness),
               insertedIdentities.contains(identity) {
                ghostLedger.sealBoundary(for: id)
            }
            if initialWitness.isMoveAmbiguous {
                moveAmbiguousNewBlockIDs.insert(id)
            }
        }
        if hasGhostGeometryPass {
            let allNewBlockIDs = Set(newGhostBlockIDs)
            migrateInvalidGhostWitnesses(
                blockIDs: moveAmbiguousNewBlockIDs,
                insertedIdentities: insertedIdentities,
                newBlockByDepartedIdentity: newGhostBlockByDepartedIdentity,
                movedIDs: movedIDs,
                liveState: newState,
                liveEdges: liveEdges,
                oldLiveEdges: oldLiveEdges,
                anchorIdentity: anchorIdentity
            )
            migrateInvalidGhostWitnesses(
                blockIDs: Set(ghostLedger.snapshots.map(\.id))
                    .subtracting(allNewBlockIDs),
                insertedIdentities: insertedIdentities,
                newBlockByDepartedIdentity: newGhostBlockByDepartedIdentity,
                movedIDs: movedIDs,
                liveState: newState,
                liveEdges: liveEdges,
                oldLiveEdges: oldLiveEdges,
                anchorIdentity: anchorIdentity
            )
        }
        assertGhostInvariants()

        var overlapCoordinateShift: CGFloat?
        var transitionViewportFrom: CGFloat?
        var viewportTrack: ListAnimationTrack?
        if let scrollTo, isOverlappingScroll || isCarouselScroll {
            let newOrder = effectiveItems.map(\.identity)
            let directionAnchorIdentity: AnyHashable? = {
                if let currentAnchorIdentity,
                   newIdentities.contains(currentAnchorIdentity) {
                    return currentAnchorIdentity
                }
                guard let currentAnchorIdentity,
                      let oldAnchorIndex = oldItems.firstIndex(where: {
                          $0.identity == currentAnchorIdentity
                      })
                else { return nil }
                let survivingOldIndices = oldItems.indices.filter {
                    newIdentities.contains(oldItems[$0].identity)
                }
                guard let nearestOldIndex = survivingOldIndices.min(by: { lhs, rhs in
                    let lhsDistance = abs(lhs - oldAnchorIndex)
                    let rhsDistance = abs(rhs - oldAnchorIndex)
                    return lhsDistance == rhsDistance
                        ? lhs < rhs
                        : lhsDistance < rhsDistance
                }) else { return nil }
                return oldItems[nearestOldIndex].identity
            }()
            let direction = ViewportTransitionGeometry.direction(
                currentAnchor: directionAnchorIdentity,
                targetIndex: scrollTo.index,
                newOrder: newOrder,
                fallback: {
                    switch scrollTo.direction {
                    case .backward: return .backward
                    case .forward, nil: return .forward
                    }
                }()
            )
            if isOverlappingScroll,
               let reference = ViewportTransitionGeometry.overlapReference(
                currentAnchor: currentAnchorIdentity,
                direction: direction,
                oldLoaded: oldLoadedIdentities,
                newLoaded: newLoadedIdentities,
                newOrder: newOrder
            ), let oldReference = oldState[reference],
               let newReference = newState[reference] {
                let coordinateShift = ViewportTransitionGeometry.coordinateShift(
                    oldReferenceY: oldReference.contentY,
                    newReferenceY: newReference.contentY
                )
                let viewportFrom = ViewportTransitionGeometry.overlapViewportFrom(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    coordinateShift: coordinateShift,
                    newEngineOffset: transactionOffset
                )
                let mutation = transitionViewportPreservingDetachedBoundary(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    oldSettledOffset: oldBoundsOriginY + coordinateShift,
                    newSettledOffset: transactionOffset,
                    transition: transition,
                    transactionTime: transactionTime) { [weak self] generation in
                    self?.finishViewportGeneration(generation)
                }
                overlapCoordinateShift = coordinateShift
                transitionViewportFrom = viewportFrom
                viewportTrack = mutation.startedTrack

                if case .immediate = mutation {
                    resetViewportCarries()
                }
            } else if isCarouselScroll {
                let oldRenderedOffset = oldBoundsOriginY + currentViewportCorrection
                let oldLoadedTop = oldContainerOriginY - oldRenderedOffset
                let newLoadedTop = containerOriginY - transactionOffset
                // The outgoing strip is everything on its way out, not just the loaded window: a
                // carousel still in flight has its own outgoing strip parked in the viewport. Placed
                // against the loaded window alone, a jump back the way the earlier one came lands the
                // incoming window exactly on that strip and carries both, coincident, for the whole
                // travel.
                let outgoingStrip = carouselOutgoingStrip(
                    loadedTop: oldLoadedTop,
                    loadedHeight: oldWindow.height,
                    viewportCorrection: currentViewportCorrection,
                    excluding: Set(newGhostBlockIDs),
                    at: transactionTime
                )
                let viewportFrom = ViewportTransitionGeometry.carouselViewportFrom(
                    direction: direction,
                    oldVisibleTop: outgoingStrip.lowerBound,
                    newVisibleTop: newLoadedTop,
                    oldStripHeight: outgoingStrip.upperBound - outgoingStrip.lowerBound,
                    newWindowHeight: newWindow.height
                )
                let syntheticOldSettledOffset = transactionOffset
                    + viewportFrom - currentViewportCorrection
                let mutation = transitionViewportPreservingDetachedBoundary(
                    oldEngineOffset: oldBoundsOriginY,
                    currentViewportCorrection: currentViewportCorrection,
                    oldSettledOffset: syntheticOldSettledOffset,
                    newSettledOffset: transactionOffset,
                    transition: transition,
                    transactionTime: transactionTime) { [weak self] generation in
                    self?.finishViewportGeneration(generation)
                }
                transitionViewportFrom = viewportFrom
                viewportTrack = mutation.startedTrack

                if case .immediate = mutation {
                    resetViewportCarries()
                }
                // An earlier carousel's strip is now carried by THIS track, so it has to live exactly
                // as long as this track. Its own deadline could fall while the travel is still
                // bringing it across the screen, and the band the placement above reserved for it
                // would then cross the viewport empty. Viewport carries get the same by the
                // generation re-stamp below; a ghost block's lifetime is its members' exit tracks.
                retimeCarouselExitStrips(excluding: Set(newGhostBlockIDs),
                                         transition: transition,
                                         transactionTime: transactionTime)

#if DEBUG
                if let track = mutation.startedTrack {
                    assert(abs(track.from - viewportFrom) <= 1e-6)
                    let mappedOldTop = ViewportTransitionGeometry.mappedContentY(
                        oldScreenY: outgoingStrip.lowerBound,
                        newEngineOffset: transactionOffset,
                        viewportFrom: viewportFrom
                    )
                    let initialOutgoingTop = mappedOldTop
                        - (transactionOffset + viewportFrom)
                    let initialIncomingTop = newLoadedTop - viewportFrom
                    assert(abs(initialOutgoingTop - outgoingStrip.lowerBound) <= 1e-6)
                    switch direction {
                    case .forward:
                        assert(abs(initialIncomingTop - outgoingStrip.upperBound) <= 1e-6)
                    case .backward:
                        assert(abs(initialIncomingTop + newWindow.height
                                   - initialOutgoingTop) <= 1e-6)
                    }
                }
#endif
            }
        }

        if viewportTrack == nil, displacesViewport {
            let syntheticOldOffset = oldBoundsOriginY + anchorCoordinateShift
            let mutation = transitionViewportPreservingDetachedBoundary(
                oldEngineOffset: oldBoundsOriginY,
                currentViewportCorrection: currentViewportCorrection,
                oldSettledOffset: syntheticOldOffset,
                newSettledOffset: transactionOffset,
                transition: transition,
                transactionTime: transactionTime) { [weak self] generation in
                self?.finishViewportGeneration(generation)
            }
            transitionViewportFrom = mutation.startedTrack?.from
            viewportTrack = mutation.startedTrack
            // Row geometry remains in content coordinates; the shared viewport track owns
            // the screen-space displacement for this pass.
            overlapCoordinateShift = anchorCoordinateShift
            if case .immediate = mutation {
                resetViewportCarries()
            }
        }

        // Attachments transition HERE, after the shared viewport track has been installed — the same
        // phase the row transitions run in, and for the same reason. Earlier in the pass
        // `viewportOffset(at:)` still reads 0, so an attachment's own track would carry the whole
        // programmatic-scroll displacement that the viewport track ALSO carries. The two cancel at
        // t = 0 and every floating attachment sits at its destination while the content is still
        // travelling — "tapping Top makes the floating items jump immediately".
        let newAttachmentState = settledAttachmentState(activeWindow,
                                                        containerOriginY: containerOriginY,
                                                        insets: viewportInsets,
                                                        logicalHeight: logicalSize.height,
                                                        offset: engine.offset,
                                                        viewportCorrection: animationController
                                                            .viewportOffset(at: transactionTime),
                                                        at: transactionTime)
        let insertedAttachmentIdentities = Set(diff.inserts.compactMap { newIndex -> AnyHashable? in
            effectiveItems.indices.contains(newIndex) ? effectiveItems[newIndex].identity : nil
        })
        // A full-replace carousel is a rigid travel between two strips: both ends ride the shared
        // viewport track at full opacity. Under it EVERY incoming run is all-new, so the fade-in rule
        // fires on all of them and headers would fade while the rows beside them do not. This is the
        // same suppression the row path applies, on the same predicate — see the row `insert` block
        // guarded by `!isFullReplaceCarousel`.
        let fadingIn = isFullReplaceCarousel
            ? []
            : fadingInAttachmentSerials(
                window: activeWindow,
                existingSerials: Set(oldAttachmentState.keys),
                insertedIdentities: insertedAttachmentIdentities,
                reconciledIdentities: reconciledIdentities)
        transitionAttachments(old: oldAttachmentState,
                              new: newAttachmentState,
                              transition: transition,
                              transactionTime: transactionTime,
                              fadesInSerials: fadingIn)

        let carriesBeforePass = viewportCarries.count
        if let track = viewportTrack, let viewportFrom = transitionViewportFrom {
            for index in viewportCarries.indices {
                viewportCarries[index].generation = track.generation
            }
            for identity in oldLoadedIdentities where potentialCarryIdentities.contains(identity) {
                guard let old = oldState[identity] else { continue }
                let oldScreenY = old.contentY + old.positionOffset
                    - (oldBoundsOriginY + currentViewportCorrection)
                let mappedY = ViewportTransitionGeometry.mappedContentY(
                    oldScreenY: oldScreenY,
                    newEngineOffset: transactionOffset,
                    viewportFrom: viewportFrom
                )
                old.view.onContentDidChange = nil
                old.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
                old.view.layer.position.x = old.contentX + old.positionOffsetX
                old.view.layer.bounds.size.width = old.visualWidth
                exitOverlay.addSubview(old.view)
                let owner = animationController.makeTransient(
                    identity: identity,
                    layer: old.view.layer,
                    contentY: mappedY,
                    transactionTime: transactionTime
                )
                viewportCarries.append(ViewportCarry(
                    generation: track.generation,
                    owner: owner,
                    identity: identity,
                    view: old.view,
                    settledX: old.contentX + old.positionOffsetX,
                    settledWidth: old.visualWidth
                ))
            }
        } else {
            for identity in oldLoadedIdentities where potentialCarryIdentities.contains(identity) {
                guard let old = oldState[identity] else { continue }
                animationController.unbind(identity: identity,
                                           layer: old.view.layer,
                                           at: transactionTime)
            }
        }

        if logicalSizeChanged || insetsChanged {
            transitionDetachedHorizontalGeometry(transition: transition,
                                                 transactionTime: transactionTime)
        }

        if hasGhostGeometryPass {
            transitionGhostBlocks(liveEdges: liveEdges,
                                  transition: transition,
                                  transactionTime: transactionTime)
        }

        if isCarouselScroll, viewportTrack != nil {
            promoteCarouselExitContent(
                ghostBlockIDs: newGhostBlockIDs,
                carryRange: carriesBeforePass..<viewportCarries.count,
                transactionOffset: transactionOffset
            )
        }

        let sharedDisplacementSamples: [CrossingDisplacementSample] = oldIDs
            .intersection(newIDs)
            .compactMap { identity in
                guard !movedIDs.contains(identity),
                      let indices = survivorEndpointIndices[identity],
                      let old = oldRenderedState[identity],
                      let new = newState[identity]
                else { return nil }
                let coordinates = transitionCoordinates(
                    old: old,
                    new: new,
                    oldBoundsOriginY: oldBoundsOriginY,
                    transactionOffset: transactionOffset,
                    overlapCoordinateShift: overlapCoordinateShift
                )
                return CrossingDisplacementSample(
                    identity: identity,
                    oldIndex: indices.oldIndex,
                    newIndex: indices.newIndex,
                    oldY: coordinates.oldY,
                    newY: coordinates.newY
                )
            }
        let newCoordinateBase = overlapCoordinateShift == nil ? 0 : transactionOffset
        let newCoordinateY: (SettledLiveItem) -> CGFloat = { state in
            overlapCoordinateShift == nil
                ? state.contentY - transactionOffset
                : state.contentY
        }
        let newOccupiedMinY = newState.values.map(newCoordinateY).min()
        let newOccupiedMaxY = newState.values.map {
            newCoordinateY($0) + $0.size.height
        }.max()
        let newCrossingBand = CrossingRetentionBand(
            minY: newCoordinateBase - preloadMargin,
            maxY: newCoordinateBase + logicalSize.height + preloadMargin,
            anchorY: anchorIdentity.flatMap { newState[$0] }.map(newCoordinateY),
            anchorIndex: resolvedAnchor?.index,
            occupiedMinY: newOccupiedMinY,
            occupiedMaxY: newOccupiedMaxY
        )
        let oldCoordinateBase = overlapCoordinateShift.map {
            oldBoundsOriginY + $0
        } ?? 0
        let oldCoordinateY: (SettledLiveItem) -> CGFloat = { state in
            if let shift = overlapCoordinateShift {
                return state.contentY + shift
            }
            return state.contentY - oldBoundsOriginY
        }
        let oldOccupiedMinY = oldState.values.map(oldCoordinateY).min()
        let oldOccupiedMaxY = oldState.values.map {
            oldCoordinateY($0) + $0.size.height
        }.max()
        let oldAnchorY = currentAnchorIdentity.flatMap { oldRenderedState[$0] }
            .map(oldCoordinateY)
        let oldCrossingBand = CrossingRetentionBand(
            minY: oldCoordinateBase - preloadMargin,
            maxY: oldCoordinateBase + logicalSize.height + preloadMargin,
            anchorY: oldAnchorY,
            anchorIndex: currentAnchorIdentity.flatMap { oldRenderedState[$0]?.index },
            occupiedMinY: oldOccupiedMinY,
            occupiedMaxY: oldOccupiedMaxY
        )
        let outgoingEndpoints = outgoingCrossingIdentities.compactMap {
            identity -> CrossingKnownEndpoint? in
            guard let old = oldRenderedState[identity],
                  let indices = survivorEndpointIndices[identity]
            else { return nil }
            let knownOldY = overlapCoordinateShift.map { old.contentY + $0 }
                ?? (old.contentY - oldBoundsOriginY)
            return CrossingKnownEndpoint(
                identity: identity,
                side: .old,
                oldIndex: indices.oldIndex,
                newIndex: indices.newIndex,
                y: knownOldY,
                height: old.size.height,
                isMoveParticipant: indices.isMoveParticipant
            )
        }.sorted { $0.oldIndex < $1.oldIndex }
        for plan in CrossingSurvivorPlanner.infer(
            endpoints: outgoingEndpoints,
            samples: sharedDisplacementSamples,
            band: newCrossingBand
        ) {
            guard let old = oldRenderedState[plan.identity] else { continue }
            let newSettledContentY = overlapCoordinateShift == nil
                ? plan.newY + transactionOffset
                : plan.newY
            installOutgoingCrossingCarry(
                from: old,
                plan: plan,
                newSettledContentY: newSettledContentY,
                transition: transition,
                transactionTime: transactionTime,
                fallbackReleaseGeneration: viewportTrack?.generation
            )
        }
        let oldCollectionIdentities = Set(oldItems.map(\.identity))
        let incomingCrossingIdentities: Set<AnyHashable> = {
            guard hasSettledMembershipTransition, !isCarouselScroll else { return [] }
            return newIDs.subtracting(oldIDs).intersection(oldCollectionIdentities)
        }()
        let incomingEndpoints = incomingCrossingIdentities.compactMap {
            identity -> CrossingKnownEndpoint? in
            guard let new = newState[identity],
                  let indices = survivorEndpointIndices[identity]
            else { return nil }
            let knownNewY = overlapCoordinateShift == nil
                ? new.contentY - transactionOffset
                : new.contentY
            return CrossingKnownEndpoint(
                identity: identity,
                side: .new,
                oldIndex: indices.oldIndex,
                newIndex: indices.newIndex,
                y: knownNewY,
                height: new.size.height,
                isMoveParticipant: indices.isMoveParticipant
            )
        }.sorted { $0.newIndex < $1.newIndex }
        for plan in CrossingSurvivorPlanner.infer(
            endpoints: incomingEndpoints,
            samples: sharedDisplacementSamples,
            band: oldCrossingBand
        ) {
            guard let new = newState[plan.identity] else { continue }
            transitionIncomingCrossingSurvivor(
                new,
                plan: plan,
                transition: transition,
                transactionTime: transactionTime
            )
        }

        for identity in oldIDs.intersection(newIDs) {
            guard let old = oldRenderedState[identity], let new = newState[identity] else { continue }
            let coordinates = transitionCoordinates(
                old: old,
                new: new,
                oldBoundsOriginY: oldBoundsOriginY,
                transactionOffset: transactionOffset,
                overlapCoordinateShift: overlapCoordinateShift
            )
            animationController.transitionPosition(
                identity: identity,
                layer: new.view.layer,
                oldSettledY: coordinates.oldY,
                newSettledY: coordinates.newY,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionPositionX(
                identity: identity,
                layer: new.view.layer,
                oldSettledX: old.contentX,
                newSettledX: new.contentX,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                identity: identity,
                layer: new.view.layer,
                oldSettledWidth: old.size.width,
                newSettledWidth: new.size.width,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionHeight(
                identity: identity,
                layer: new.view.layer,
                oldSettledHeight: old.size.height,
                newSettledHeight: new.size.height,
                transition: transition,
                transactionTime: transactionTime
            )
        }

        // A full-replace carousel is a rigid travel between two strips: both ends ride the shared
        // viewport track at full opacity, which is what ListViewImpl does with its
        // temporaryPreviousNodes. Fading here would be an artifact of the host expressing a jump as
        // delete-all + insert-all, not a wanted animation. Scoped tightly — an overlapping scrollTo,
        // or a carousel within a surviving collection, carrying a genuinely new row must still fade
        // that row in; see `isFullReplaceCarousel`.
        //
        // `animatesInsertions` is the host's version of the same statement: the row's arrival is
        // real, but something outside the list is already staging it, so a fade here would be a
        // second, uncoordinated animation of one arrival. The chat's send morph is the caller — it
        // carries the bubble out of the input field itself.
        //
        // Nothing else is needed for the incoming side — render() already stamps `layer.opacity = 1`
        // on every window item, and it runs earlier in this pass.
        if !isFullReplaceCarousel && animatesInsertions {
            let insertedIDs = Set(diff.inserts.compactMap { newIndex in
                effectiveItems.indices.contains(newIndex)
                    ? effectiveItems[newIndex].identity
                    : nil
            }).subtracting(movedIDs)
            for identity in newIDs.subtracting(oldIDs).intersection(insertedIDs) {
                guard let new = newState[identity] else { continue }
                animationController.insert(identity: identity,
                                           layer: new.view.layer,
                                           transition: transition,
                                           transactionTime: transactionTime)
            }
        }
    }

    /// Slides a run of rows in from just beyond one edge of where they settled, as one rigid block:
    /// every named row gets the SAME offset, so their spacing is preserved for the whole travel and
    /// they arrive together.
    ///
    /// The host names the EDGE and this view measures the DISTANCE. The distance is the block's own
    /// total settled height, which is what puts the block exactly out of the way of its final
    /// position at the start of the travel; the host cannot compute it, because the heights come from
    /// the very pass this call follows. Which edge is host policy — a rotated host reads them the
    /// other way round — and `origin` is in CoreList's content order, not screen space.
    ///
    /// **Why this is a list-owned track and not something a host can install itself.** Position tracks
    /// here are additive offsets decaying to zero, and `capturePresentedPositionOffsets()` reads
    /// `presented − model` on every bound live layer at the start of the NEXT pass to recover exactly
    /// that quantity. A raw `CAAnimation` a host added would be indistinguishable from a track this
    /// model owns, so a second pass landing mid-slide would resume against a displacement the model
    /// never issued. Going through `transitionPosition` also means an overlapping slide composes with
    /// the one in flight (`transitionPositionOffset` folds in `currentOffset`) rather than fighting it.
    ///
    /// Rows not currently loaded are skipped: an unloaded row has no layer, and it is off-screen, so
    /// there is nothing to see travel.
    ///
    /// Safe to call immediately after `applyChanges`. If that pass was deferred for re-entrancy this
    /// call defers onto the same scheduler behind it, so it always reads the window the pass built —
    /// reading it synchronously would find the PREVIOUS window and displace the wrong rows.
    public func animateInsertedBlock(identities: [AnyHashable],
                                     origin: CoreListBlockOrigin,
                                     transition: CoreListTransition) {
        guard !identities.isEmpty, !transition.isImmediate else {
            return
        }
        if isApplyingChanges {
            scheduler.schedule { [weak self] in
                self?.animateInsertedBlock(identities: identities,
                                           origin: origin,
                                           transition: transition)
            }
            return
        }

        let wanted = Set(identities)
        let members = activeWindow.items.filter { item in
            guard _items.indices.contains(item.index) else {
                return false
            }
            return wanted.contains(_items[item.index].identity)
        }
        guard !members.isEmpty else {
            return
        }

        // Reserved space is between rows rather than part of one, so a block entering from beyond its
        // own edge has to clear it too — otherwise a run carrying a date header starts that much
        // short and the header is already half-arrived when the rows begin to move.
        let blockHeight = members.reduce(CGFloat(0.0)) { total, item in
            total + item.frame.height + item.reservedTop + item.reservedBottom
        }
        guard blockHeight > 0.0 else {
            return
        }
        let displacement: CGFloat
        switch origin {
        case .beforeBlock:
            displacement = -blockHeight
        case .afterBlock:
            displacement = blockHeight
        }

        // One clock for the whole block, for the same reason a pass captures one: sampling per row
        // would stagger the starts of an animation whose entire point is that the rows move rigidly.
        let transactionTime = animationController.now()
        for item in members {
            let identity = _items[item.index].identity
            // `render()` has already written the settled frame, so the layer's model position IS the
            // settled endpoint. Passing it back as `newSettledY` is a no-op write; the pair only has
            // to differ by `displacement` for the track to carry it.
            let settledY = item.view.layer.position.y
            animationController.transitionPosition(identity: identity,
                                                   layer: item.view.layer,
                                                   oldSettledY: settledY + displacement,
                                                   newSettledY: settledY,
                                                   transition: transition,
                                                   transactionTime: transactionTime)
        }
    }

    private func settledPredecessorsChanged(identity: AnyHashable,
                                            oldItems: [CoreListItem],
                                            newItems: [CoreListItem]) -> Bool {
        guard let oldIndex = oldItems.firstIndex(where: { $0.identity == identity }),
              let newIndex = newItems.firstIndex(where: { $0.identity == identity })
        else { return false }
        let oldPredecessors = Set(oldItems[..<oldIndex].map(\.identity))
        let newPredecessors = Set(newItems[..<newIndex].map(\.identity))
        return oldPredecessors != newPredecessors
    }

    func setBoundsOriginY(_ y: CGFloat) {
        applyEngineShift(y - engine.offset)
        previousOffset = engine.offset
    }

    private func rebuildFromScratch() {
        defer {
            notifyVisibleRects()
            refreshReachedLoadedEdges()
        }
        engine.haltMotionInPlace()
        resetViewportCarries()
        animationController.reset()
        ghostLedger.reset()
        ghostRenders.removeAll()
        crossingCarries.removeAll()
        activeWindow = Window()
        container.subviews.forEach { $0.removeFromSuperview() }
        crossingOverlay.subviews.forEach { $0.removeFromSuperview() }
        exitOverlay.subviews.forEach { $0.removeFromSuperview() }
        carouselExitOverlay.subviews.forEach { $0.removeFromSuperview() }
        engine.contentHost.frame = bounds
        layoutExitOverlay()
        engine.setEdges(min: 0, max: 0)
        declaredEdges = (0, 0)
        containerOriginY = 0
        animationController.seedViewport(layer: engine.contentHost.layer)
        animationController.addViewportMirrorLayer(carouselExitOverlay.layer)
        assertGhostInvariants()

        guard contentWidth > 0,
              logicalSize.height > 0,
              !_items.isEmpty else { return }

        activeWindow = buildWindow(anchoredAt: 0,
                                   resolveY: { _, _ in 0 },
                                   pinsLoadedTop: true,
                                   sourceWindow: nil)
        priorItems = _items
        render()
        var initialOffset = containerOriginY - activeWindow.minY
        let edges = loadedEdgeRange(for: activeWindow, originY: containerOriginY)
        if let minimum = edges.min { initialOffset = max(initialOffset, minimum) }
        if let maximum = edges.max { initialOffset = min(initialOffset, maximum) }
        // `edges.min` is non-nil exactly when `startIndex == 0`, so this is the old condition — but it
        // reads the CLAMPED minimum, which carries the pin's slack. Reading
        // `viewportGeometry.minimumOffset` here instead would discard it on the cold-start path (a chat
        // opened with a stream already in flight).
        if let minimum = edges.min { initialOffset = minimum }
        setBoundsOriginY(initialOffset)
        // As in `applyChanges`: the solve consumes the offset, so it must run after the final write.
        renderAttachments()
        for item in activeWindow.items {
            animationController.seedLive(identity: _items[item.index].identity,
                                         layer: item.view.layer)
        }
    }

    private func resolveAnchor(scrollTo: CoreListScrollTarget?,
                               anchorMode: CoreListAnchorMode,
                               isNoOverlapSwap: Bool,
                               diff: ItemDiff,
                               oldWindow: Window,
                               oldContainerOriginY: CGFloat,
                               oldSettledOffset: CGFloat,
                               oldTopInset: CGFloat,
                               oldItemCount: Int) -> ResolvedAnchor? {
        if let scrollTo {
            // Momentum was already halted at pass entry (see applyChanges) — deliberately, so this pass's
            // geometry is built against the caught position rather than a stale sample.
            return ResolvedAnchor(index: scrollTo.index,
                                  offset: .resolved(scrollTo.resolve),
                                  preservesVisibleContent: false)
        }
        if holdsPinnedRow, let pinnedIndex = lowestPinnedItemIndex {
            // Above `preserveVisibleContent`: loading older history above a held pin must not move it.
            // Below `scrollTo`: an explicit jump still wins, and re-arms the latch when it targets the
            // pin.
            //
            // Reads ONLY the pinned row's own height — no span, no window membership, no loading
            // precondition, because anchoring on a row loads it. That is the whole reason this is an
            // anchor: the slack needed every row from the window start through the pin, which is what
            // made it fragile about load order.
            //
            // `logicalSize`/`viewportInsets` are read when the closure RUNS, inside `buildWindow`,
            // which is after this pass has assigned its `newSize`/`newInsets` — so a pass that
            // re-insets and re-pins in one transaction resolves against the new geometry.
            return ResolvedAnchor(
                index: pinnedIndex,
                offset: .resolved { [weak self] height, _ in
                    guard let self else { return 0 }
                    let visibleArea = self.logicalSize.height
                        - self.viewportInsets.top - self.viewportInsets.bottom
                    // `pinToEdgeBottomExtension` (`ListView.swift:1137`): a row taller than half the
                    // viewport hangs off the edge, so it never takes more than half the screen.
                    let ext = max(0, height - visibleArea * 0.5)
                    // `Offset` means "settled Y as an offset from the top inset edge", and `resolveY`
                    // adds `viewportInsets.top`, so the screen target is
                    // `logicalSize.height - viewportInsets.bottom + ext - height`: the row's maxY on
                    // the bottom inset edge.
                    return visibleArea + ext - height
                },
                preservesVisibleContent: false,
                isPin: true
            )
        }
        if anchorMode == .preserveVisibleContent,
           let preserved = resolvePreservedAnchor(
               diff: diff,
               oldWindow: oldWindow,
               oldContainerOriginY: oldContainerOriginY,
               oldSettledOffset: oldSettledOffset,
               oldTopInset: oldTopInset
           ) {
            return preserved
        }
        if isNoOverlapSwap {
            engine.haltMotionInPlace()
            return ResolvedAnchor(index: 0,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }
        let oldEdges = loadedEdgeRange(for: oldWindow,
                                       originY: oldContainerOriginY,
                                       itemCount: oldItemCount)
        if oldWindow.startIndex == 0,
           let minimum = oldEdges.min,
           abs(oldSettledOffset - minimum) <= 1e-6 {
            return ResolvedAnchor(index: 0,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }

        let scrollY = oldSettledOffset
        let absoluteBase = oldContainerOriginY - oldWindow.minY
        let topItem = oldWindow.items.first { absoluteBase + $0.frame.maxY > scrollY }
        let topItemWasDeleted = topItem.map { diff.survivorMap[$0.index] == nil } ?? false
        let firstVisibleSurvivor = oldWindow.items.first {
            diff.survivorMap[$0.index] != nil && absoluteBase + $0.frame.maxY > scrollY
        }
        let lastSurvivorAbove = oldWindow.items.last {
            diff.survivorMap[$0.index] != nil && absoluteBase + $0.frame.maxY <= scrollY
        }

        func pinnedOffset(_ item: Window.Item) -> CGFloat {
            oldContainerOriginY + item.frame.minY - oldWindow.minY - oldSettledOffset
        }

        if topItemWasDeleted,
           let item = lastSurvivorAbove,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let item = firstVisibleSurvivor,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let item = lastSurvivorAbove,
           let newIndex = diff.survivorMap[item.index] {
            return ResolvedAnchor(index: newIndex,
                                  pointOffset: pinnedOffset(item),
                                  preservesVisibleContent: false)
        }
        if let nearest = diff.survivorMap.min(by: { $0.value < $1.value }) {
            return ResolvedAnchor(index: nearest.value,
                                  pointOffset: 0,
                                  preservesVisibleContent: false)
        }
        return nil
    }

    private func resolvePreservedAnchor(diff: ItemDiff,
                                        oldWindow: Window,
                                        oldContainerOriginY: CGFloat,
                                        oldSettledOffset: CGFloat,
                                        oldTopInset: CGFloat) -> ResolvedAnchor? {
        let absoluteBase = oldContainerOriginY - oldWindow.minY
        let insetEdgeY = oldSettledOffset + oldTopInset
        guard let witnessPosition = oldWindow.items.firstIndex(where: {
            absoluteBase + $0.frame.maxY > insetEdgeY
        }) else {
            return nil
        }

        func resolved(_ positions: [Int]) -> ResolvedAnchor? {
            for position in positions {
                let item = oldWindow.items[position]
                guard let newIndex = diff.survivingNewIndex(
                    forOldIndex: item.index
                ) else { continue }
                let pointOffset = absoluteBase + item.frame.minY - oldSettledOffset
                return ResolvedAnchor(index: newIndex,
                                      pointOffset: pointOffset,
                                      preservesVisibleContent: true)
            }
            return nil
        }

        if let below = resolved(Array(witnessPosition..<oldWindow.items.endIndex)) {
            return below
        }
        return resolved(Array(
            oldWindow.items.indices[..<witnessPosition].reversed()
        ))
    }

    fileprivate func markDirty(_ view: UIView, animated: Bool) {
        guard let item = activeWindow.items.first(where: { $0.view === view }) else { return }
        dirtyIndices.insert(item.index)
        dirtyAnimated = dirtyAnimated || animated
        if !dirtyFlushScheduled {
            dirtyFlushScheduled = true
            scheduler.schedule { [weak self] in self?.flushDirtyItems() }
        }
    }

    /// The attachment analogue of `markDirty`. No index to record: a pass re-measures every loaded
    /// attachment, so the flag only has to trigger one.
    func markAttachmentsDirty(animated: Bool) {
        attachmentsAreDirty = true
        dirtyAnimated = dirtyAnimated || animated
        if !dirtyFlushScheduled {
            dirtyFlushScheduled = true
            scheduler.schedule { [weak self] in self?.flushDirtyItems() }
        }
    }

    private func flushDirtyItems() {
        dirtyFlushScheduled = false
        // `attachmentsAreDirty` is NOT cleared here — `applyChanges` consumes it, the same way it
        // consumes `dirtyIndices`. Clearing it first would make the pass's own guard read false and
        // the flush would do nothing.
        guard !dirtyIndices.isEmpty || attachmentsAreDirty else { return }
        let animated = dirtyAnimated
        applyChanges(transition: animated ? .easeInOut(duration: defaultDirtyDuration) : .immediate)
    }

    private func handleUserScroll(_ currentY: CGFloat) {
        let timestamp = CACurrentMediaTime()
        var delta = currentY - previousOffset
        if abs(delta) > logicalSize.height {
            delta = logicalSize.height * (delta > 0 ? 1 : -1)
            engine.setOffset(previousOffset + delta)
        }
        previousOffset = engine.offset
        onUserScrollDelta?(delta, timestamp)
        rebalanceActiveWindow()
        refreshReachedLoadedEdges()
        // The floating clamp is viewport-dependent, and `rebalanceActiveWindow` runs `render()` only
        // when the window actually changed — so a scroll that leaves the window untouched would
        // otherwise never re-solve. The solve is a pure function of the settled window and the
        // offset, so running it again after a rebalance that DID render is an exact no-op.
        renderAttachments()
        // After any rebase and before the host callback, so the host sees final row visibility
        // whether or not the loaded window changed.
        notifyVisibleRects()
        onVisibleWindowChanged?()
    }

    private func rebalanceActiveWindow() {
        guard !activeWindow.isEmpty else { return }

        let scrollY = engine.offset
        let band = projectedLoadBand
        let width = contentWidth
        let preRebalanceIdentities = Set(activeWindow.items.map { _items[$0.index].identity })
        let absoluteBase = containerOriginY - activeWindow.minY
        var window = activeWindow
        var changed = false

        while window.items.count > 1,
              let first = window.items.first,
              projectedFrame(first.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).maxY < band.lowerBound {
            animationController.unbind(identity: _items[first.index].identity,
                                       layer: first.view.layer)
            window.items.removeFirst()
            changed = true
        }

        while window.items.count > 1,
              let last = window.items.last,
              projectedFrame(last.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).minY > band.upperBound {
            animationController.unbind(identity: _items[last.index].identity,
                                       layer: last.view.layer)
            window.items.removeLast()
            changed = true
        }

        while let first = window.items.first,
              projectedFrame(first.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).minY > band.lowerBound,
              window.startIndex > 0 {
            prependItem(to: &window, width: width, sourceWindow: nil)
            changed = true
        }

        while let last = window.items.last,
              projectedFrame(last.frame,
                             contentBaseY: absoluteBase,
                             viewportOffset: scrollY).maxY < band.upperBound,
              window.endIndex < _items.count - 1 {
            appendItem(to: &window, width: width, sourceWindow: nil)
            changed = true
        }

        guard changed else { return }
        let promotedCrossingIdentities = Set(window.items.map {
            _items[$0.index].identity
        }).intersection(crossingCarries.keys)
        for identity in promotedCrossingIdentities {
            crossingCarries.removeValue(forKey: identity)
        }
        // Rebalancing mutates `window.items` directly and never calls `buildWindow`, so without this
        // the attachment set goes stale the moment scrolling loads a row belonging to a run the
        // window had not seen. `priorItems` is still `_items` here (the collection did not change),
        // so the witness rule resolves against the very window being replaced.
        resolveAttachments(in: &window, sourceWindow: activeWindow)
        drainAttachmentDeparturesSilently()
        activeWindow = window
        priorItems = _items
        let newOriginY = computeContainerOriginY(for: window)
        let newAbsoluteBase = newOriginY - window.minY
        if abs(newAbsoluteBase - absoluteBase) > 0.5 {
            applyEngineShift(newAbsoluteBase - absoluteBase)
            previousOffset = engine.offset
        }
        render()

        for item in window.items {
            let identity = _items[item.index].identity
            if !preRebalanceIdentities.contains(identity) {
                attachLive(identity: identity, layer: item.view.layer)
            }
        }
    }

    /// Views last notified with a NON-nil rect, held weakly so a departed row is not retained. Lets
    /// one uniform rule deliver the `nil` for every way a row can leave the live window — a rebalance
    /// unload, a ghost-block member, the transient exit-overlay carry — instead of threading a call
    /// through each departure site.
    private let visibleRectNotifiedViews = NSHashTable<UIView>.weakObjects()

    /// Reports each loaded row the part of itself inside the viewport. Uses the same projection
    /// `rebalanceActiveWindow` uses, against the FULL viewport rect — insets stay visible space.
    private func notifyVisibleRects() {
        let viewportRect = CGRect(origin: .zero, size: logicalSize)
        let contentBaseY = containerOriginY - activeWindow.minY
        let scrollY = engine.offset

        var visibleNow: [UIView] = []
        var visibleIDs = Set<ObjectIdentifier>()
        visibleNow.reserveCapacity(activeWindow.items.count)

        for item in activeWindow.items {
            let viewportFrame = projectedFrame(item.frame,
                                               contentBaseY: contentBaseY,
                                               viewportOffset: scrollY)
            let intersection = viewportFrame.intersection(viewportRect)
            // Null OR empty is "not visible": `intersection` is empty for rects that merely touch at
            // an edge, which `CGRect.intersects` — ListViewImpl's gate — also calls false.
            if intersection.isNull || intersection.isEmpty {
                item.view.visibleRectUpdated(nil)
            } else {
                item.view.visibleRectUpdated(intersection.offsetBy(dx: -viewportFrame.minX,
                                                                   dy: -viewportFrame.minY))
                visibleNow.append(item.view)
                visibleIDs.insert(ObjectIdentifier(item.view))
            }
        }

        for view in visibleRectNotifiedViews.allObjects
        where !visibleIDs.contains(ObjectIdentifier(view)) {
            (view as? CoreListItemView)?.visibleRectUpdated(nil)
        }

        visibleRectNotifiedViews.removeAllObjects()
        for view in visibleNow {
            visibleRectNotifiedViews.add(view)
        }
    }

    private var projectedLoadBand: ClosedRange<CGFloat> {
        -preloadMargin ... logicalSize.height + preloadMargin
    }

    private func projectedFrame(_ frame: CGRect,
                                contentBaseY: CGFloat,
                                viewportOffset: CGFloat) -> CGRect {
        frame.offsetBy(dx: 0, dy: contentBaseY - viewportOffset)
    }

    private func translate(_ window: inout Window, by deltaY: CGFloat) {
        guard abs(deltaY) > 1e-9 else { return }
        for index in window.items.indices {
            window.items[index].frame.origin.y += deltaY
        }
    }

    /// The transition a row is measured with. Non-immediate when the row has to RE-LAY-OUT and has a
    /// prior layout to animate from — either because its content was reconciled in this pass, or
    /// because the pass changed `contentWidth` and it is being measured at a new width.
    ///
    /// The width case is not a special case of the content one: a horizontal inset or a viewport-width
    /// change reconciles nothing, yet `buildWindow` re-measures every loaded row at the new
    /// `contentWidth`, and the row reflows internally — a bubble rewraps its text, its subviews move.
    /// `ListAnimationModel` owns the row's OUTER frame and animates that, but it knows nothing about
    /// where a label sits inside a bubble; only the row can animate that, and only if it is handed a
    /// transition. Measuring `.immediate` there snapped every row's internals while its frame
    /// animated. (This is why the old "the change is purely outer geometry" reasoning held for a
    /// VERTICAL inset change — which leaves `contentWidth` alone, so nothing re-measures — and not for
    /// a horizontal one.)
    ///
    /// Still `.immediate` for: a view created in this pass (nothing to animate from), a row whose
    /// identity is out of range, and — when the width is unchanged — scroll-in loads, unchanged
    /// survivors and off-screen remeasures, none of which relayout.
    private func measureTransition(forItemAt index: Int,
                                   view: UIView & CoreListItemView) -> CoreListTransition {
        guard _items.indices.contains(index) else { return .immediate }
        guard !freshViewsThisPass.contains(ObjectIdentifier(view)) else { return .immediate }
        if contentWidthChangedInPass {
            return currentPassTransition
        }
        guard reconciledIdentities.contains(_items[index].identity) else { return .immediate }
        return currentPassTransition
    }

    /// - Parameter pinSlackBaseline: the pin slack the ANCHOR's placement was computed against, when
    ///   that placement came from old geometry. Non-nil makes the window ride the effective top edge
    ///   rather than sit at an absolute offset — see the translate below.
    private func buildWindow(anchoredAt index: Int,
                             resolveY: (CGFloat, UIView & CoreListItemView) -> CGFloat,
                             pinsLoadedTop: Bool = false,
                             pinSlackBaseline: CGFloat? = nil,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) -> Window {
        let width = contentWidth
        let itemX = viewportInsets.left
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width,
                                 transition: measureTransition(forItemAt: index, view: view))
        // The anchor's placement may depend on its own height (bottom-align, center, make-visible),
        // so it is resolved here rather than by the caller: this is the first moment the height
        // exists.
        let anchorY = resolveY(height, view)
        let anchorReserve = reservedHeights(atIndex: index, width: width)
        var window = Window(items: [
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: itemX, y: anchorY, width: width, height: height),
                        reservedTop: anchorReserve.top,
                        reservedBottom: anchorReserve.bottom)
        ])

        let band = projectedLoadBand
        // Assigned after the first prepend below, which is the earliest point at which rows 0…k are
        // members and the slack is therefore answerable. Every later `topEdge` read in this build —
        // the loaded-top pin, both underfill alignments, the whole-collection underfill test — uses
        // the same value.
        var topEdge = viewportInsets.top
        let bottomEdge = logicalSize.height - viewportInsets.bottom

        func alignTopIfUnderfilled() -> Bool {
            guard window.startIndex == 0, window.minY > topEdge else { return false }
            translate(&window, by: topEdge - window.minY)
            return true
        }

        func alignBottomIfUnderfilled() -> Bool {
            guard window.endIndex == _items.count - 1,
                  window.maxY < bottomEdge else { return false }
            translate(&window, by: bottomEdge - window.maxY)
            return true
        }

        func prependUntilCoveredOrAtTop() {
            while window.minY > band.lowerBound, window.startIndex > 0 {
                prependItem(to: &window,
                            width: width,
                            sourceWindow: sourceWindow,
                            survivorMapNewToOld: survivorMapNewToOld,
                            moveReuseNewToOld: moveReuseNewToOld)
            }
        }

        func appendUntilCoveredOrAtBottom() {
            while window.maxY < band.upperBound,
                  window.endIndex < _items.count - 1 {
                appendItem(to: &window,
                           width: width,
                           sourceWindow: sourceWindow,
                           survivorMapNewToOld: survivorMapNewToOld,
                           moveReuseNewToOld: moveReuseNewToOld)
            }
        }

        // The pinned row sits at a HIGHER index than the anchor on exactly the passes that matter —
        // the cold start and any pass resting at the edge both anchor on the newest row, with the pin
        // just below it — so `prependUntilCoveredOrAtTop` has NOT loaded it and the slack would read
        // 0. Load down to it first. These rows are inside the viewport whenever the slack is non-zero,
        // so `appendUntilCoveredOrAtBottom` below would have loaded them regardless; this only moves
        // that work before the measurement that depends on it.
        //
        // While the pin latch is ENGAGED this is a no-op: the pinned row is the anchor, so it is
        // member zero of the window before this runs. It still matters once the latch is released and
        // the content above the pin is short — the case that keeps the pin reachable by scrolling
        // back to it.
        //
        // The `window.height` bound is load-bearing and exact under the clamped slack: once the rows
        // above the pin alone exceed the viewport, the slack is zero regardless of the pinned row's
        // height, so there is nothing to learn by loading down to it. (Reply 620 / viewport 400 /
        // pinned 60: the loop stops after the reply, and 0 IS the right answer, since 620 + 60 > 400.)
        //
        // This bound was once reported as the cause of a dropped pin and patched; the patch made the
        // device behaviour worse and was reverted (`2f31d2bc5a`). It only looked wrong because the
        // unclamped slack needed an exact negative value here. Do not patch it again.
        func appendUntilPinnedRowLoaded() {
            guard window.startIndex == 0, let pinnedIndex = lowestPinnedItemIndex else { return }
            let visibleArea = logicalSize.height - viewportInsets.top - viewportInsets.bottom
            while window.endIndex < pinnedIndex,
                  window.endIndex < _items.count - 1,
                  window.height < visibleArea {
                appendItem(to: &window,
                           width: width,
                           sourceWindow: sourceWindow,
                           survivorMapNewToOld: survivorMapNewToOld,
                           moveReuseNewToOld: moveReuseNewToOld)
            }
        }

        prependUntilCoveredOrAtTop()
        appendUntilPinnedRowLoaded()
        // Ordering is safe in one direction only, and this is that direction: the slack pushes the
        // window DOWN, so the append below needs no more rows than it would have without it.
        let pinSlack = bottomEdgePinSlack(for: window)
        topEdge = viewportInsets.top + pinSlack
        if pinsLoadedTop, window.startIndex == 0 {
            translate(&window, by: topEdge - window.minY)
        } else {
            if let pinSlackBaseline {
                // The anchor's placement was derived from the OLD effective top edge, and the SLACK
                // half of that edge moves with the content above the pin — a streaming reply spends
                // the slack as it grows. Riding the edge is what ABSORBS that growth: the pinned row
                // and every row below it hold still, exactly as they do resting at the edge, while the
                // reply extends into the room the slack gives up.
                //
                // Held absolutely instead, nothing takes up the retreat and the whole growth goes into
                // pushing the rows below the anchor — the chat drifting under a streaming reply. The
                // settle clamp then cancels only the part that crosses the edge, which is the same
                // absorption arriving late, partially, and in one jerk: drift, tug, drift, tug.
                //
                // Only the CONTENT half is applied here. `topInsetDelta` carries the geometry half, and
                // cannot see this one — both of its samples read `oldWindow` and the old items, so they
                // differ only when `logicalSize` or `viewportInsets` changed. This half is also
                // deliberately NOT gated on `compensatesInsetChange`: a caller whose own drag owns the
                // movement still wants growth absorbed rather than pushed under its finger.
                translate(&window, by: pinSlack - pinSlackBaseline)
            }
            _ = alignTopIfUnderfilled()
        }
        appendUntilCoveredOrAtBottom()

        if window.endIndex == _items.count - 1,
           window.maxY < bottomEdge {
            let wholeCollectionIsUnderfilled = window.startIndex == 0
                && window.height + viewportInsets.top + viewportInsets.bottom
                    <= logicalSize.height
            if wholeCollectionIsUnderfilled {
                translate(&window, by: topEdge - window.minY)
            } else if alignBottomIfUnderfilled() {
                prependUntilCoveredOrAtTop()
                if window.startIndex == 0,
                   window.height + viewportInsets.top + viewportInsets.bottom
                        <= logicalSize.height {
                    translate(&window, by: topEdge - window.minY)
                } else {
                    _ = alignTopIfUnderfilled()
                }
            }
        }

        resolveAttachments(in: &window, sourceWindow: sourceWindow)
        return window
    }

    private func prependItem(to window: inout Window,
                             width: CGFloat,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) {
        let index = window.startIndex - 1
        guard index >= 0, let first = window.items.first else { return }
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width,
                                 transition: measureTransition(forItemAt: index, view: view))
        let reserve = reservedHeights(atIndex: index, width: width)
        window.items.insert(
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: viewportInsets.left,
                                      y: first.frame.minY - first.reservedTop
                                          - reserve.bottom - height,
                                      width: width,
                                      height: height),
                        reservedTop: reserve.top,
                        reservedBottom: reserve.bottom),
            at: 0
        )
    }

    private func appendItem(to window: inout Window,
                            width: CGFloat,
                            sourceWindow: Window?,
                            survivorMapNewToOld: [Int: Int]? = nil,
                            moveReuseNewToOld: [Int: Int]? = nil) {
        let index = window.endIndex + 1
        guard _items.indices.contains(index) else { return }
        let view = viewForItem(at: index,
                               sourceWindow: sourceWindow,
                               survivorMapNewToOld: survivorMapNewToOld,
                               moveReuseNewToOld: moveReuseNewToOld)
        let height = view.update(width: width,
                                 transition: measureTransition(forItemAt: index, view: view))
        let reserve = reservedHeights(atIndex: index, width: width)
        let previous = window.items.last
        window.items.append(
            Window.Item(index: index,
                        view: view,
                        frame: CGRect(x: viewportInsets.left,
                                      y: (previous?.frame.maxY ?? 0)
                                          + (previous?.reservedBottom ?? 0)
                                          + reserve.top,
                                      width: width,
                                      height: height),
                        reservedTop: reserve.top,
                        reservedBottom: reserve.bottom)
        )
    }

    private func viewForItem(at index: Int,
                             sourceWindow: Window?,
                             survivorMapNewToOld: [Int: Int]? = nil,
                             moveReuseNewToOld: [Int: Int]? = nil) -> UIView & CoreListItemView {
        if let oldIndex = survivorMapNewToOld?[index],
           let existing = sourceWindow?.items.first(where: { $0.index == oldIndex })?.view {
            return existing
        }
        if let oldIndex = moveReuseNewToOld?[index],
           let existing = sourceWindow?.items.first(where: { $0.index == oldIndex })?.view {
            return existing
        }
        let identity = _items[index].identity
        if let carry = crossingCarries[identity] {
            return carry.view
        }
        let fresh = _items[index].view()
        freshViewsThisPass.insert(ObjectIdentifier(fresh))
        return fresh
    }

    /// Extra TOP-inset slack this window needs so its lowest `pinsToBottomEdge` row can rest against
    /// the bottom edge — `ListViewImpl.calculatePinToEdgeTopInset` (`Display/Source/ListView.swift:1106`),
    /// re-derived against the window's own geometry.
    ///
    /// Reads only INTRA-window offsets (`pinned.frame.maxY - window.minY`), never a placement, so it
    /// is well defined at any point after the members have been measured — including inside the very
    /// alignment step that consumes it. That is the same property `ListViewImpl` relies on by summing
    /// `apparentBounds.height` rather than reading positions.
    ///
    /// `window.minY`/`maxY` already cover the reserved attachment bands, so a date header above the
    /// pinned row is accounted for without a separate term.
    private func bottomEdgePinSlack(for window: Window) -> CGFloat {
        // `sawIndexZero`: the slack is scroll room at an edge, and it means nothing until that edge
        // is loaded.
        guard window.startIndex == 0,
              let pinnedIndex = lowestPinnedItemIndex,
              let pinned = window.items.first(where: { $0.index == pinnedIndex })
        else { return 0 }
        let visibleArea = logicalSize.height - viewportInsets.top - viewportInsets.bottom
        // `pinToEdgeBottomExtension` (`ListView.swift:1137`): a row taller than half the viewport is
        // allowed to hang off the edge, so it never takes more than half.
        let ext = max(0, pinned.frame.height - visibleArea * 0.5)
        let span = pinned.frame.maxY - window.minY
        // **Clamped at zero**, as `ListViewImpl` clamps the same expression (`ListView.swift:1134`).
        //
        // This answers ONE question: does the list have scroll ROOM to rest with the pinned row on
        // the bottom edge. It is not what holds the row there — `holdsPinnedRow` is. Once `span`
        // outgrows the viewport the natural scroll range already contains the pinned position, so
        // zero is the correct answer and the latch alone carries the hold.
        //
        // The two are matched by construction, which is why the clamp cannot strand the anchor: the
        // pin's target sits exactly `visibleArea - span + ext` points past the natural minimum, the
        // same expression this returns. Positive, and the edge extends by precisely that much;
        // negative, and the target is INSIDE the natural range — ordinary scrolled-down territory.
        //
        // It was briefly unclamped, to make the edge carry the hold without a latch. A negative slack
        // is placement leaking into a scroll-range quantity: it fed `loadedEdgeRange`'s minimum and
        // extended the range into empty space, so on device the chat could not be scrolled down to a
        // tall streaming reply at all — it overscroll-bounced instead.
        //
        // Deliberately INDEPENDENT of the latch. Release happens at finger-down, so a slack that
        // vanished with it would move content under the user's finger before the drag had travelled a
        // point. `ListViewImpl` computes its inset unconditionally for the same reason.
        return max(0.0, (logicalSize.height - viewportInsets.bottom + ext)
                      - (viewportInsets.top + span))
    }

    private func loadedEdgeRange(for window: Window,
                                 originY: CGFloat,
                                 itemCount: Int? = nil) -> (min: CGFloat?, max: CGFloat?) {
        guard !window.isEmpty else { return (0, 0) }
        let count = itemCount ?? _items.count
        // The pin's slack rides the MINIMUM edge, which is what makes it stick: `render()` and
        // `refreshReachedLoadedEdges()` both come through here and `rebalanceActiveWindow()` re-renders,
        // so user scrolling, momentum and self-update flushes all see it with no extra plumbing.
        let minimum: CGFloat? = window.startIndex == 0
            ? viewportGeometry.minimumOffset - bottomEdgePinSlack(for: window)
            : nil
        let maximum: CGFloat? = window.endIndex == count - 1
            ? viewportGeometry.maximumOffset(
                contentBottom: originY - window.minY + window.maxY
            )
            : nil
        return (minimum, maximum)
    }

    private func refreshReachedLoadedEdges() {
        guard !activeWindow.isEmpty, !_items.isEmpty else {
            reachedLoadedEdges.removeAll()
            return
        }

        let limits = loadedEdgeRange(for: activeWindow, originY: containerOriginY)
        var settledOffset = engine.offset
        if let minimum = limits.min {
            settledOffset = max(settledOffset, minimum)
        }
        if let maximum = limits.max {
            settledOffset = min(settledOffset, maximum)
        }

        let epsilon: CGFloat = 1e-6
        let topBoundaryY = containerOriginY - settledOffset
        let bottomBoundaryY = containerOriginY
            - activeWindow.minY
            + activeWindow.maxY
            - settledOffset
        let topLine = loadedEdgeMargin
        let bottomLine = logicalSize.height - loadedEdgeMargin

        var reached: Set<CoreListLoadedEdge> = []
        if activeWindow.startIndex == 0,
           topBoundaryY >= topLine - epsilon {
            reached.insert(.top)
        }
        if activeWindow.endIndex == _items.count - 1,
           bottomBoundaryY <= bottomLine + epsilon {
            reached.insert(.bottom)
        }

        let arrivals = reached.subtracting(reachedLoadedEdges)
        reachedLoadedEdges = reached
        for edge in [CoreListLoadedEdge.top, .bottom] where arrivals.contains(edge) {
            onLoadedEdgeReached?(edge)
        }
    }

    private func computeContainerOriginY(for window: Window) -> CGFloat {
        guard !window.isEmpty else { return 0 }
        return engine.containerOrigin(windowHeight: window.height,
                                      topLoaded: window.startIndex == 0,
                                      bottomLoaded: window.endIndex == _items.count - 1)
    }

    private func render() {
        let window = activeWindow
        let newOriginY = computeContainerOriginY(for: window)

        container.frame = CGRect(x: 0,
                                 y: newOriginY,
                                 width: logicalSize.width,
                                 height: max(1, window.height))
        for subview in container.subviews
            where !window.items.contains(where: { $0.view === subview }) {
            subview.removeFromSuperview()
        }
        for item in window.items {
            item.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            item.view.frame = item.frame.offsetBy(dx: 0, dy: -window.minY)
            item.view.layer.opacity = 1
            item.view.onContentDidChange = { [weak self, weak view = item.view] animated in
                guard let self, let view else { return }
                self.markDirty(view, animated: animated)
            }
            if item.view.superview !== container { container.addSubview(item.view) }
        }

        let edges = loadedEdgeRange(for: window, originY: newOriginY)
        let offsetBeforeEdges = engine.offset
        engine.setEdges(min: edges.min, max: edges.max)
        declaredEdges = (edges.min, edges.max)
        shiftExitOverlayChildren(by: engine.offset - offsetBeforeEdges)
        containerOriginY = newOriginY
        // The caller publishes visibility after it also settles the engine offset.
        renderAttachments()
    }

    private func settledState(_ window: Window,
                              sourceItems: [CoreListItem],
                              containerOriginY: CGFloat,
                              at time: TimeInterval) -> [AnyHashable: SettledLiveItem] {
        Dictionary(uniqueKeysWithValues: window.items.map { item in
            let identity = sourceItems[item.index].identity
            let localY = item.frame.minY - window.minY
            let positionOffset = animationController.positionOffset(
                identity: identity,
                at: time
            ) ?? 0
            let positionOffsetX = animationController.positionOffsetX(
                identity: identity,
                at: time
            ) ?? 0
            return (
                identity,
                SettledLiveItem(
                    index: item.index,
                    identity: identity,
                    view: item.view,
                    contentX: item.frame.minX,
                    contentY: containerOriginY + localY,
                    positionOffsetX: positionOffsetX,
                    positionOffset: positionOffset,
                    opacity: animationController.opacity(
                        owner: .live(identity),
                        at: time
                    ) ?? 1,
                    size: item.frame.size,
                    visualWidth: animationController.width(
                        identity: identity,
                        at: time
                    ) ?? item.frame.width,
                    visualHeight: animationController.height(
                        identity: identity,
                        at: time
                    ) ?? item.frame.height
                )
            )
        })
    }

    private func settledContentY(in window: Window,
                                 index: Int,
                                 containerOriginY: CGFloat) -> CGFloat? {
        guard let frame = window.localFrame(for: index) else { return nil }
        return containerOriginY + frame.minY - window.minY
    }

    private func crossingCarryState(
        sourceItems: [CoreListItem],
        at time: TimeInterval
    ) -> [AnyHashable: SettledLiveItem] {
        Dictionary(uniqueKeysWithValues: crossingCarries.values.compactMap { carry in
            guard let index = sourceItems.firstIndex(where: {
                $0.identity == carry.identity
            }) else { return nil }
            let size = carry.view.bounds.size
            return (
                carry.identity,
                SettledLiveItem(
                    index: index,
                    identity: carry.identity,
                    view: carry.view,
                    contentX: carry.view.layer.position.x,
                    contentY: carry.settledContentY,
                    positionOffsetX: animationController.positionOffsetX(
                        identity: carry.identity,
                        at: time
                    ) ?? 0,
                    positionOffset: animationController.positionOffset(
                        identity: carry.identity,
                        at: time
                    ) ?? 0,
                    opacity: animationController.opacity(
                        owner: .live(carry.identity),
                        at: time
                    ) ?? 1,
                    size: size,
                    visualWidth: animationController.width(
                        identity: carry.identity,
                        at: time
                    ) ?? size.width,
                    visualHeight: animationController.height(
                        identity: carry.identity,
                        at: time
                    ) ?? size.height
                )
            )
        })
    }

    private func transitionCoordinates(
        old: SettledLiveItem,
        new: SettledLiveItem,
        oldBoundsOriginY: CGFloat,
        transactionOffset: CGFloat,
        overlapCoordinateShift: CGFloat?
    ) -> (oldY: CGFloat, newY: CGFloat) {
        if let overlapCoordinateShift {
            return (old.contentY + overlapCoordinateShift, new.contentY)
        }
        return (old.contentY - oldBoundsOriginY,
                new.contentY - transactionOffset)
    }

    private func installOutgoingCrossingCarry(
        from old: SettledLiveItem,
        plan: CrossingEndpointPlan,
        newSettledContentY: CGFloat,
        transition: CoreListTransition,
        transactionTime: TimeInterval,
        fallbackReleaseGeneration: UInt64?
    ) {
        guard var carry = crossingCarries[old.identity], carry.view === old.view else {
            return
        }
        if carry.releaseGeneration != nil,
           abs(carry.settledContentY - newSettledContentY) <= 1e-6 {
            return
        }
        old.view.layer.position.y = newSettledContentY
        carry.settledContentY = newSettledContentY
        crossingCarries[old.identity] = carry

        let mutation = animationController.transitionPosition(
            identity: old.identity,
            layer: old.view.layer,
            oldSettledY: plan.oldY,
            newSettledY: plan.newY,
            transition: transition,
            transactionTime: transactionTime
        ) { [weak self, weak view = old.view] generation in
            guard let view else { return }
            self?.finishCrossingCarry(identity: old.identity,
                                      generation: generation,
                                      view: view)
        }
        switch mutation {
        case let .started(track):
            guard var current = crossingCarries[old.identity],
                  current.view === old.view else { return }
            current.releaseGeneration = track.generation
            crossingCarries[old.identity] = current
        case .immediate:
            removeCrossingCarry(identity: old.identity, removeLiveOwner: true)
        case .unchanged:
            if let fallbackReleaseGeneration,
               var current = crossingCarries[old.identity],
               current.view === old.view {
                current.releaseGeneration = fallbackReleaseGeneration
                crossingCarries[old.identity] = current
            } else if crossingCarries[old.identity]?.releaseGeneration == nil {
                removeCrossingCarry(identity: old.identity, removeLiveOwner: true)
            }
        }
    }

    private func transitionIncomingCrossingSurvivor(
        _ new: SettledLiveItem,
        plan: CrossingEndpointPlan,
        transition: CoreListTransition,
        transactionTime: TimeInterval
    ) {
        animationController.transitionPosition(
            identity: new.identity,
            layer: new.view.layer,
            oldSettledY: plan.oldY,
            newSettledY: plan.newY,
            transition: transition,
            transactionTime: transactionTime
        )
    }

    private func transitionDetachedHorizontalGeometry(
        transition: CoreListTransition,
        transactionTime: TimeInterval
    ) {
        let targetX = viewportInsets.left
        let targetWidth = contentWidth

        for blockID in Array(ghostRenders.keys) {
            guard var render = ghostRenders[blockID] else { continue }
            render.wrapper.layer.bounds.size.width = logicalSize.width
            for key in Array(render.members.keys) {
                guard var member = render.members[key] else { continue }
                animationController.transitionPositionX(
                    owner: member.owner,
                    layer: member.view.layer,
                    oldSettledX: member.settledX,
                    newSettledX: targetX,
                    transition: transition,
                    transactionTime: transactionTime
                )
                animationController.transitionWidth(
                    owner: member.owner,
                    layer: member.view.layer,
                    oldSettledWidth: member.settledWidth,
                    newSettledWidth: targetWidth,
                    transition: transition,
                    transactionTime: transactionTime
                )
                member.settledX = targetX
                member.settledWidth = targetWidth
                render.members[key] = member
            }
            ghostRenders[blockID] = render
        }

        for identity in Array(crossingCarries.keys) {
            guard var carry = crossingCarries[identity] else { continue }
            animationController.transitionPositionX(
                identity: identity,
                layer: carry.view.layer,
                oldSettledX: carry.settledX,
                newSettledX: targetX,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                identity: identity,
                layer: carry.view.layer,
                oldSettledWidth: carry.settledWidth,
                newSettledWidth: targetWidth,
                transition: transition,
                transactionTime: transactionTime
            )
            carry.settledX = targetX
            carry.settledWidth = targetWidth
            crossingCarries[identity] = carry
        }

        for index in viewportCarries.indices {
            var carry = viewportCarries[index]
            animationController.transitionPositionX(
                owner: carry.owner,
                layer: carry.view.layer,
                oldSettledX: carry.settledX,
                newSettledX: targetX,
                transition: transition,
                transactionTime: transactionTime
            )
            animationController.transitionWidth(
                owner: carry.owner,
                layer: carry.view.layer,
                oldSettledWidth: carry.settledWidth,
                newSettledWidth: targetWidth,
                transition: transition,
                transactionTime: transactionTime
            )
            carry.settledX = targetX
            carry.settledWidth = targetWidth
            viewportCarries[index] = carry
        }
    }

    private func finishCrossingCarry(identity: AnyHashable,
                                     generation: UInt64,
                                     view: UIView) {
        guard let carry = crossingCarries[identity],
              carry.releaseGeneration == generation,
              carry.view === view,
              !activeWindow.items.contains(where: {
                  _items.indices.contains($0.index)
                      && _items[$0.index].identity == identity
              })
        else { return }
        crossingCarries.removeValue(forKey: identity)
        animationController.unbind(identity: identity, layer: view.layer)
        view.removeFromSuperview()
    }

    private func removeCrossingCarry(identity: AnyHashable,
                                     removeLiveOwner: Bool) {
        guard let carry = crossingCarries.removeValue(forKey: identity) else { return }
        if removeLiveOwner {
            animationController.unbind(identity: identity, layer: carry.view.layer)
        }
        carry.view.removeFromSuperview()
    }

    private func makeGhostBlock(from items: [SettledLiveItem],
                                attachments: [(departure: AttachmentDeparture,
                                               state: SettledAttachment)] = [],
                                transition: CoreListTransition,
                                transactionTime: TimeInterval,
                                fadesOut: Bool) -> GhostBlockID {
        precondition(!items.isEmpty)
        let rootY = items[0].contentY + items[0].positionOffset
        let localYs = items.map { $0.contentY + $0.positionOffset - rootY }
        // Attachment locals are computed on the same terms and participate in the block's extent: a
        // `.top` header sits ABOVE its first row, so it can push localMinY negative.
        let attachmentLocalYs = attachments.map {
            $0.state.contentY + $0.state.positionOffset - rootY
        }
        let localMinY = (localYs + attachmentLocalYs).min() ?? 0
        let localMaxY = (zip(items, localYs).map { item, localY in
            localY + item.visualHeight
        } + zip(attachments, attachmentLocalYs).map { attachment, localY in
            localY + attachment.state.size.height
        }).max() ?? 0
        let id = ghostLedger.insert(rootY: rootY,
                                    localMinY: localMinY,
                                    localMaxY: localMaxY,
                                    witness: .unresolved,
                                    visibleMemberCount: items.count + attachments.count)
        let owner = ListAnimationOwner.ghostBlock(id.rawValue)
        let wrapper = UIView()
        wrapper.backgroundColor = .clear
        wrapper.clipsToBounds = false
        wrapper.isUserInteractionEnabled = false

        wrapper.layer.anchorPoint = CGPoint(x: 0, y: 0)
        wrapper.layer.bounds = CGRect(x: 0,
                                      y: 0,
                                      width: logicalSize.width,
                                      height: max(1, localMaxY - localMinY))
        wrapper.layer.position = CGPoint(x: 0, y: rootY)
        exitOverlay.addSubview(wrapper)
        for (item, localY) in zip(items, localYs) {
            item.view.onContentDidChange = nil
            item.view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            wrapper.addSubview(item.view)
            item.view.frame = CGRect(x: item.contentX + item.positionOffsetX,
                                     y: localY,
                                     width: item.visualWidth,
                                     height: item.visualHeight)
            item.view.layer.opacity = Float(item.opacity)
        }

        animationController.seedGhostBlock(owner: owner,
                                           layer: wrapper.layer,
                                           settledRootY: rootY)
        // Placeholders for EVERY member — rows and attachments alike — before any `makeExit` runs.
        // An immediate transition completes its exit synchronously, so `finishGhostMember` can fire
        // inside the loops below; without a placeholder already present it would decrement the
        // ledger's member count for an entry that was then inserted afterwards, and
        // `assertGhostInvariants` would see `members.count > visibleMemberCount`.
        var placeholderMembers = Dictionary(uniqueKeysWithValues: items.map { item in
            let member = GhostMember(owner: .live(item.identity),
                                     view: item.view,
                                     settledX: item.contentX + item.positionOffsetX,
                                     settledWidth: item.visualWidth)
            return (ObjectIdentifier(item.view), member)
        })
        for attachment in attachments {
            let view = attachment.departure.view
            placeholderMembers[ObjectIdentifier(view)] = GhostMember(
                owner: .attachment(attachment.departure.run.serial),
                view: view,
                settledX: attachment.state.contentX,
                settledWidth: attachment.state.size.width
            )
        }
        ghostRenders[id] = GhostBlockRender(
            owner: owner,
            wrapper: wrapper,
            members: placeholderMembers,
            departedRange: items[0].index..<(items[items.count - 1].index + 1)
        )

        for (item, localY) in zip(items, localYs) {
            let memberOwner = makeExit(from: item,
                                       localY: localY,
                                       blockID: id,
                                       transition: transition,
                                       transactionTime: transactionTime,
                                       fadesOut: fadesOut)
            let key = ObjectIdentifier(item.view)
            if var render = ghostRenders[id], render.members[key] != nil {
                render.members[key] = GhostMember(
                    owner: memberOwner,
                    view: item.view,
                    settledX: item.contentX + item.positionOffsetX,
                    settledWidth: item.visualWidth
                )
                ghostRenders[id] = render
            }
        }
        for (attachment, localY) in zip(attachments, attachmentLocalYs) {
            let view = attachment.departure.view
            view.onContentDidChange = nil
            view.layer.anchorPoint = CGPoint(x: 0, y: 0)
            wrapper.addSubview(view)
            view.frame = CGRect(x: attachment.state.contentX,
                                y: localY,
                                width: attachment.state.size.width,
                                height: attachment.state.size.height)
            let memberOwner = animationController.makeExit(
                owner: .attachment(attachment.departure.run.serial),
                layer: view.layer,
                contentY: localY,
                transition: transition,
                transactionTime: transactionTime,
                fadesOut: fadesOut
            ) { [weak self, weak view] in
                guard let view else { return }
                self?.finishGhostMember(blockID: id, view: view)
            }
            // Replace the placeholder only if it is still there: an immediate exit may already have
            // finished this member and removed it, exactly as the row loop above guards.
            let key = ObjectIdentifier(view)
            if var render = ghostRenders[id], render.members[key] != nil {
                render.members[key] = GhostMember(
                    owner: memberOwner,
                    view: view,
                    settledX: attachment.state.contentX,
                    settledWidth: attachment.state.size.width
                )
                ghostRenders[id] = render
            }
        }
        assertGhostInvariants()
        return id
    }

    @discardableResult
    private func makeExit(from item: SettledLiveItem,
                          localY: CGFloat,
                          blockID: GhostBlockID,
                          transition: CoreListTransition,
                          transactionTime: TimeInterval,
                          fadesOut: Bool) -> ListAnimationOwner {
        item.view.frame = CGRect(x: item.contentX + item.positionOffsetX,
                                 y: localY,
                                 width: item.visualWidth,
                                 height: item.visualHeight)
        item.view.layer.opacity = Float(item.opacity)

        return animationController.makeExit(
            identity: item.identity,
            layer: item.view.layer,
            contentY: localY,
            transition: transition,
            transactionTime: transactionTime,
            fadesOut: fadesOut
        ) { [weak self, weak view = item.view] in
            guard let view else { return }
            self?.finishGhostMember(blockID: blockID, view: view)
        }
    }

    private func finishGhostMember(blockID: GhostBlockID, view: UIView) {
        let key = ObjectIdentifier(view)
        guard var render = ghostRenders[blockID],
              let member = render.members.removeValue(forKey: key),
              member.view === view else { return }
        view.removeFromSuperview()
        ghostRenders[blockID] = render
        ghostLedger.removeVisibleMember(from: blockID)
        collectGhostBlocks()
        assertGhostInvariants()
    }

    private func collectGhostBlocks() {
        for id in ghostLedger.collectOrphanedEmptyBlocks() {
            guard let render = ghostRenders.removeValue(forKey: id) else { continue }
            render.wrapper.removeFromSuperview()
            animationController.removeGhostBlock(owner: render.owner,
                                                 layer: render.wrapper.layer)
        }
    }

    private func migrateInvalidGhostWitnesses(
        blockIDs: Set<GhostBlockID>,
        insertedIdentities: Set<AnyHashable>,
        newBlockByDepartedIdentity: [AnyHashable: GhostBlockID],
        movedIDs: Set<AnyHashable>,
        liveState: [AnyHashable: SettledLiveItem],
        liveEdges: [AnyHashable: GhostLiveEdges],
        oldLiveEdges: [AnyHashable: GhostLiveEdges],
        anchorIdentity: AnyHashable?
    ) {
        let epsilon: CGFloat = 1e-6
        let anchorY = anchorIdentity.flatMap { liveState[$0]?.contentY }

        let snapshots = ghostLedger.snapshots
            .filter { blockIDs.contains($0.id) }
            .sorted { $0.id < $1.id }
        for snapshot in snapshots {
            if snapshot.isBoundaryOpen,
               let occupant = insertedIdentities.compactMap({ identity -> SettledLiveItem? in
                   guard let state = liveState[identity],
                         abs(state.contentY - snapshot.settledRootY) <= epsilon else { return nil }
                   return state
               }).min(by: { $0.index < $1.index }) {
                _ = ghostLedger.setBoundaryLink(
                    attachmentEdge: .minY,
                    witness: .liveMinY(occupant.identity),
                    for: snapshot.id
                )
                ghostLedger.sealBoundary(for: snapshot.id)
                continue
            }
            guard ghostWitnessNeedsMigration(snapshot.witness,
                                             movedIDs: movedIDs,
                                             liveState: liveState) else { continue }
            let boundaryY = invalidGhostBoundaryY(snapshot,
                                                  oldLiveEdges: oldLiveEdges)

            if let exact = exactDepartingWitnessHandoff(
                from: snapshot.witness,
                sourceID: snapshot.id,
                boundaryY: boundaryY,
                newBlockByDepartedIdentity: newBlockByDepartedIdentity,
                liveEdges: liveEdges,
                epsilon: epsilon
            ) {
                _ = ghostLedger.setWitness(exact, for: snapshot.id)
                continue
            }

            guard let anchorY else {
                _ = ghostLedger.setWitness(.unresolved, for: snapshot.id)
                continue
            }

            let searchesAbove = anchorY < boundaryY - epsilon
            var candidates: [GhostWitnessCandidate] = []
            for (identity, state) in liveState where !movedIDs.contains(identity) {
                let edgeY = searchesAbove
                    ? state.contentY + state.size.height
                    : state.contentY
                guard searchesAbove
                    ? edgeY <= boundaryY + epsilon
                    : edgeY >= boundaryY - epsilon else { continue }
                candidates.append(GhostWitnessCandidate(
                    witness: searchesAbove ? .liveMaxY(identity) : .liveMinY(identity),
                    edgeY: edgeY,
                    carrierOrder: state.index
                ))
            }

            let provisionalTargets = ghostLedger.resolvedTargets(liveEdges: liveEdges)
            for carrier in ghostLedger.snapshots where carrier.id != snapshot.id {
                guard let rootY = provisionalTargets[carrier.id],
                      let render = ghostRenders[carrier.id] else { continue }
                let witness: GhostBoundaryWitness = searchesAbove
                    ? .ghostMaxY(carrier.id)
                    : .ghostMinY(carrier.id)
                guard ghostLedger.canSetWitness(witness, for: snapshot.id) else { continue }
                let edgeY = rootY + (searchesAbove ? carrier.localMaxY : carrier.localMinY)
                guard searchesAbove
                    ? edgeY <= boundaryY + epsilon
                    : edgeY >= boundaryY - epsilon else { continue }
                candidates.append(GhostWitnessCandidate(
                    witness: witness,
                    edgeY: edgeY,
                    carrierOrder: render.departedRange.lowerBound
                ))
            }

            let selected = candidates.min { lhs, rhs in
                let lhsDistance = abs(lhs.edgeY - boundaryY)
                let rhsDistance = abs(rhs.edgeY - boundaryY)
                if abs(lhsDistance - rhsDistance) > epsilon {
                    return lhsDistance < rhsDistance
                }
                if lhs.carrierOrder != rhs.carrierOrder {
                    return lhs.carrierOrder < rhs.carrierOrder
                }
                let lhsDescription = ghostWitnessStableDescription(lhs.witness)
                let rhsDescription = ghostWitnessStableDescription(rhs.witness)
                if lhsDescription != rhsDescription {
                    return lhsDescription < rhsDescription
                }
                return ghostWitnessBlockID(lhs.witness) < ghostWitnessBlockID(rhs.witness)
            }
            if let selected {
                _ = ghostLedger.setBoundaryLink(
                    attachmentEdge: searchesAbove ? .minY : .maxY,
                    witness: selected.witness,
                    for: snapshot.id
                )
            } else {
                _ = ghostLedger.setWitness(.unresolved, for: snapshot.id)
            }
        }
    }

    private func invalidGhostBoundaryY(
        _ snapshot: GhostBlockSnapshot,
        oldLiveEdges: [AnyHashable: GhostLiveEdges]
    ) -> CGFloat {
        switch snapshot.witness {
        case let .liveMinY(identity):
            return oldLiveEdges[identity]?.minY ?? snapshot.settledRootY
        case let .liveMaxY(identity):
            return oldLiveEdges[identity]?.maxY ?? snapshot.settledRootY
        case .ghostMinY, .ghostMaxY, .unresolved:
            return snapshot.settledRootY
        }
    }

    private func ghostWitnessNeedsMigration(
        _ witness: GhostBoundaryWitness,
        movedIDs: Set<AnyHashable>,
        liveState: [AnyHashable: SettledLiveItem]
    ) -> Bool {
        switch witness {
        case let .liveMinY(identity), let .liveMaxY(identity):
            return movedIDs.contains(identity) || liveState[identity] == nil
        case .unresolved:
            return true
        case .ghostMinY, .ghostMaxY:
            return false
        }
    }

    private func ghostWitnessIdentity(_ witness: GhostBoundaryWitness) -> AnyHashable? {
        switch witness {
        case let .liveMinY(identity), let .liveMaxY(identity): return identity
        case .ghostMinY, .ghostMaxY, .unresolved: return nil
        }
    }

    private func exactDepartingWitnessHandoff(
        from witness: GhostBoundaryWitness,
        sourceID: GhostBlockID,
        boundaryY: CGFloat,
        newBlockByDepartedIdentity: [AnyHashable: GhostBlockID],
        liveEdges: [AnyHashable: GhostLiveEdges],
        epsilon: CGFloat
    ) -> GhostBoundaryWitness? {
        let identity: AnyHashable
        let useMinimum: Bool
        switch witness {
        case let .liveMinY(value):
            identity = value
            useMinimum = true
        case let .liveMaxY(value):
            identity = value
            useMinimum = false
        case .ghostMinY, .ghostMaxY, .unresolved:
            return nil
        }
        guard let targetID = newBlockByDepartedIdentity[identity],
              let target = ghostLedger.snapshot(for: targetID) else { return nil }
        let candidate: GhostBoundaryWitness = useMinimum
            ? .ghostMinY(targetID)
            : .ghostMaxY(targetID)
        guard ghostLedger.canSetWitness(candidate, for: sourceID),
              let rootY = ghostLedger.resolvedTargets(liveEdges: liveEdges)[targetID]
        else { return nil }
        let edgeY = rootY + (useMinimum ? target.localMinY : target.localMaxY)
        return abs(edgeY - boundaryY) <= epsilon ? candidate : nil
    }

    private func ghostWitnessStableDescription(_ witness: GhostBoundaryWitness) -> String {
        switch witness {
        case let .liveMinY(identity): return "liveMinY:\(String(reflecting: identity))"
        case let .liveMaxY(identity): return "liveMaxY:\(String(reflecting: identity))"
        case .ghostMinY: return "ghostMinY"
        case .ghostMaxY: return "ghostMaxY"
        case .unresolved: return "unresolved"
        }
    }

    private func ghostWitnessBlockID(_ witness: GhostBoundaryWitness) -> UInt64 {
        switch witness {
        case let .ghostMinY(id), let .ghostMaxY(id): return id.rawValue
        case .liveMinY, .liveMaxY, .unresolved: return 0
        }
    }

    private func transitionGhostBlocks(
        liveEdges: [AnyHashable: GhostLiveEdges],
        transition: CoreListTransition,
        transactionTime: TimeInterval
    ) {
        let targets = ghostLedger.resolvedTargets(liveEdges: liveEdges)
        for snapshot in ghostLedger.snapshots.sorted(by: { $0.id < $1.id }) {
            guard let target = targets[snapshot.id],
                  let render = ghostRenders[snapshot.id] else { continue }
            animationController.transitionGhostBlock(
                owner: render.owner,
                layer: render.wrapper.layer,
                oldSettledY: snapshot.settledRootY,
                newSettledY: target,
                transition: transition,
                transactionTime: transactionTime
            )
            ghostLedger.setSettledRootY(target, for: snapshot.id)
        }
    }

    private func initialGhostWitness(
        block: GhostBlockSnapshot,
        departedRange: Range<Int>,
        diff: ItemDiff,
        movedOldIndices: Set<Int>,
        movedNewIndices: Set<Int>,
        insertedIdentities: Set<AnyHashable>,
        oldItems: [CoreListItem],
        newItems: [CoreListItem],
        newState: [AnyHashable: SettledLiveItem],
        anchorY: CGFloat?,
        /// The departed run's OLD SETTLED top, translated into this pass's post-rebase coordinate
        /// space. NOT `block.settledRootY`, which is the sampled in-flight root — see the edge
        /// decision below. `nil` when the run's leading row has no old settled geometry.
        vacatedTopY: CGFloat?
    ) -> (attachmentEdge: GhostBlockEdge,
          witness: GhostBoundaryWitness,
          isMoveAmbiguous: Bool) {
        let ghostMaxY = block.settledRootY + block.localMaxY
        let anchorFacingEdge: GhostBlockEdge = anchorY.map {
            $0 >= ghostMaxY - 1e-6
        } == true ? .maxY : .minY
        let predecessor = oldItems.indices[..<departedRange.lowerBound].reversed().first {
            diff.survivorMap[$0] != nil && !movedOldIndices.contains($0)
        }
        let ordinal = predecessor.flatMap { diff.survivorMap[$0] }.map { $0 + 1 } ?? 0
        if newItems.indices.contains(ordinal) {
            if movedNewIndices.contains(ordinal) {
                return (anchorFacingEdge, .unresolved, true)
            }
            let identity = newItems[ordinal].identity
            let witness: GhostBoundaryWitness = newState[identity] == nil
                ? .unresolved
                : .liveMinY(identity)
            // Which edge welds the block to this witness is GEOMETRY, not anchor direction.
            //
            // `.minY` says "the block's top and its successor's top are the same point". That is true
            // in the ordinary mid-collection deletion, where the successor slides UP into the space the
            // block just vacated, and it is what holds the block still while the live rows collapse
            // past it. It is also true of a REPLACEMENT, where an inserted row lands on the block root.
            //
            // It is NOT true when the successor goes somewhere else. Deleting the head of the
            // collection re-pins the survivors to the loaded top edge instead of sliding them into the
            // gap, so the two tops are unrelated and equating them drops the block by its own height —
            // it slides down the screen while it fades.
            //
            // So ask whether the successor actually arrived at the top the run vacated. Both sides are
            // SETTLED values in one post-rebase space: `vacatedTopY` is the run's old settled top, not
            // the block's sampled root, which for a row that departs mid-animation is nowhere near it.
            // `anchorFacingEdge` remains the answer for the `.unresolved` returns below, where it is a
            // migration hint rather than resolved geometry.
            let successorCollapsedIntoGap: Bool = {
                guard let vacatedTopY, let successorTop = newState[identity]?.contentY else {
                    return false
                }
                return abs(successorTop - vacatedTopY) < 1e-6
            }()
            let attachmentEdge: GhostBlockEdge =
                insertedIdentities.contains(identity) || successorCollapsedIntoGap
                ? .minY
                : .maxY
            return (attachmentEdge, witness, false)
        }
        if ordinal == newItems.count,
           let identity = newItems.last?.identity,
           newState[identity] != nil {
            return (.minY, .liveMaxY(identity), false)
        }
        return (anchorFacingEdge, .unresolved, false)
    }

    func ghostRender(for id: GhostBlockID)
        -> (owner: ListAnimationOwner, wrapper: UIView)? {
        guard let render = ghostRenders[id] else { return nil }
        return (render.owner, render.wrapper)
    }

    func ghostBlockID(containing view: UIView) -> GhostBlockID? {
        let key = ObjectIdentifier(view)
        return ghostRenders.first { _, render in
            render.members[key]?.view === view
        }?.key
    }

    private func finishViewportGeneration(_ generation: UInt64) {
        let finished = viewportCarries.filter { $0.generation == generation }
        viewportCarries.removeAll { $0.generation == generation }
        for carry in finished {
            animationController.removeTransient(owner: carry.owner,
                                                layer: carry.view.layer)
            carry.view.removeFromSuperview()
        }
        let finishedCrossings = crossingCarries.values.filter {
            $0.releaseGeneration == generation
        }
        for carry in finishedCrossings {
            finishCrossingCarry(identity: carry.identity,
                                generation: generation,
                                view: carry.view)
        }
        assertOverlayInvariants()
    }

    private func resetViewportCarries() {
        let carries = viewportCarries
        viewportCarries.removeAll()
        for carry in carries {
            animationController.removeTransient(owner: carry.owner,
                                                layer: carry.view.layer)
            carry.view.removeFromSuperview()
        }
    }

    private func prepareViewportCarriesForReplacement(
        oldRenderedViewport: CGFloat,
        newRenderedViewport: CGFloat,
        appliedEngineShift: CGFloat,
        oldSettledOffset: CGFloat,
        newSettledOffset: CGFloat,
        transition: CoreListTransition
    ) {
        let epsilon: CGFloat = 1e-6
        guard !transition.isImmediate,
              abs(newSettledOffset - oldSettledOffset) > epsilon
        else { return }

        // Normal rendering/rebasing has already shifted overlay children by the
        // engine's actual delta. Apply the remainder of the exact boundary mapping
        // before replacing the additive viewport animation.
        let boundaryShift = newRenderedViewport - oldRenderedViewport
        shiftExitOverlayChildren(by: boundaryShift - appliedEngineShift)
    }

    private func transitionViewportPreservingDetachedBoundary(
        oldEngineOffset: CGFloat,
        currentViewportCorrection: CGFloat,
        oldSettledOffset: CGFloat,
        newSettledOffset: CGFloat,
        transition: CoreListTransition,
        transactionTime: TimeInterval,
        completion: @escaping (UInt64) -> Void
    ) -> ListAnimationMutation {
        let replacementFrom = oldSettledOffset
            + currentViewportCorrection - newSettledOffset
        prepareViewportCarriesForReplacement(
            oldRenderedViewport: oldEngineOffset + currentViewportCorrection,
            newRenderedViewport: newSettledOffset + replacementFrom,
            appliedEngineShift: newSettledOffset - oldEngineOffset,
            oldSettledOffset: oldSettledOffset,
            newSettledOffset: newSettledOffset,
            transition: transition
        )
        let previousGeneration = animationController.model.track(
            for: .viewport,
            property: .viewportOffset
        )?.generation
        // A replacement STEPS the shared correction: `replacementFrom` is the current correction plus
        // (oldSettled - newSettled), because the settled base moved and the correction has to absorb
        // that for content to stay continuous. Content-space children are carried through it by the
        // engine's own write to `contentHost.bounds.origin`; mirror children are not, and their
        // rendering subtracts only the correction — so the step lands on them undiluted.
        //
        // Sampling the correction either side of the mutation states the requirement directly
        // ("keep the mirror's rendering continuous") rather than re-deriving the algebra, and it
        // covers the immediate case, where the correction drops to zero rather than stepping.
        //
        // Without this, two carousels in a row stacked the first strip exactly on top of the second:
        // both were placed against their own pass's `transactionOffset`, and nothing rebased the
        // first when the correction stepped underneath it.
        let correctionBeforeReplacement = animationController.viewportOffset(at: transactionTime)
        let mutation = animationController.transitionViewport(
            layer: engine.contentHost.layer,
            oldSettledOffset: oldSettledOffset,
            newSettledOffset: newSettledOffset,
            transition: transition,
            transactionTime: transactionTime,
            completion: completion
        )
        shiftCarouselExitChildren(
            by: animationController.viewportOffset(at: transactionTime)
                - correctionBeforeReplacement
        )
        migrateCrossingViewportReleases(
            from: previousGeneration,
            through: mutation
        )
        return mutation
    }

    private func migrateCrossingViewportReleases(
        from previousGeneration: UInt64?,
        through mutation: ListAnimationMutation
    ) {
        guard let previousGeneration else { return }
        let identities = crossingCarries.compactMap { identity, carry in
            carry.releaseGeneration == previousGeneration ? identity : nil
        }

        switch mutation {
        case let .started(track):
            for identity in identities {
                crossingCarries[identity]?.releaseGeneration = track.generation
            }
        case .immediate:
            for identity in identities {
                removeCrossingCarry(identity: identity, removeLiveOwner: true)
            }
        case .unchanged:
            break
        }
    }

    private func layoutExitOverlay() {
        crossingOverlay.frame = CGRect(origin: .zero,
                                       size: engine.contentHost.bounds.size)
        exitOverlay.frame = CGRect(origin: .zero,
                                   size: engine.contentHost.bounds.size)
        // `.frame` is safe next to the mirrored additive animation: `CALayer.frame` is derived from
        // `position` and `bounds.size` only, so `bounds.origin.y` — which is what the mirror writes —
        // is untouched. Same reason it is safe on `contentHost`.
        carouselExitOverlay.frame = CGRect(origin: .zero,
                                           size: engine.contentHost.bounds.size)
    }

    private func applyEngineShift(_ delta: CGFloat) {
        guard delta != 0 else { return }
        let offsetBeforeShift = engine.offset
        engine.applyShift(delta)
        shiftExitOverlayChildren(by: engine.offset - offsetBeforeShift)
    }

    /// Moves this pass's carousel exit content out of content space and into `carouselExitOverlay`.
    ///
    /// The subtraction is forced, not chosen. In the content host a child at content `y` renders at
    /// `y - (transactionOffset + correction)`; in the mirror overlay at `y - correction`. Equating
    /// them at every value of the correction gives `mirrorY = y - transactionOffset`, so t=0 is
    /// pixel-identical to the old rendering and t=1 leaves the strip off-screen, where it stays.
    ///
    /// It runs as ONE hand-off after every parking site rather than at each site, because
    /// `makeGhostBlock` runs with OLD content coordinates — `transactionOffset` is not even captured
    /// until later in the pass — and the wrappers only reach the destination base afterwards, via the
    /// pass's rebase shift and then `prepareViewportCarriesForReplacement`.
    ///
    /// Membership is passed in, never re-derived. In particular it must NOT be derived from carry
    /// generation: the viewport block re-stamps EVERY live carry to the new track generation,
    /// including ones an earlier content-space pass parked, and promoting one of those would freeze
    /// content-space content on screen — this bug inverted.
    ///
    /// Departing ATTACHMENTS need no entry here. A genuine departure joins a departing run when its
    /// old member indices all lie inside that run's range, `AttachmentRuns.PriorRun.memberIdentities`
    /// holds only the run's LOADED members, and a full replace departs the entire loaded window as
    /// one contiguous run — so every departing attachment already travels inside a ghost wrapper this
    /// method moves. The fade-in-place branch (the merge-loser case) is unreachable in a carousel,
    /// and `AttachmentAnimationTests` pins that rather than leaving it to be rediscovered.
    private func promoteCarouselExitContent(ghostBlockIDs: [GhostBlockID],
                                            carryRange: Range<Int>,
                                            transactionOffset: CGFloat) {
        var views: [UIView] = []
        for id in ghostBlockIDs {
            guard let render = ghostRenders[id],
                  let block = ghostLedger.snapshot(for: id) else { continue }
            // Root and wrapper position move together, exactly as in `shiftExitOverlayChildren`: the
            // animation model holds only an additive offset for a ghost block, so a matched shift of
            // the settled root and the layer is invisible to it.
            ghostLedger.setSettledRootY(block.settledRootY - transactionOffset, for: id)
            ghostLedger.setAnchoring(.viewport, for: id)
            views.append(render.wrapper)
        }
        for index in carryRange where viewportCarries.indices.contains(index) {
            views.append(viewportCarries[index].view)
            viewportCarries[index].isScreenAnchored = true
        }
        for view in views {
            view.layer.position.y -= transactionOffset
            carouselExitOverlay.addSubview(view)
        }
        assertGhostInvariants()
        assertOverlayInvariants()
    }

    /// The screen band a carousel travels away from: the old loaded window plus every strip an earlier
    /// carousel parked in `carouselExitOverlay`, whose screen Y is its mirror Y minus the correction.
    /// `excluding` names this pass's own blocks, which are still in content space until promotion.
    private func carouselOutgoingStrip(loadedTop: CGFloat,
                                       loadedHeight: CGFloat,
                                       viewportCorrection: CGFloat,
                                       excluding: Set<GhostBlockID>,
                                       at time: TimeInterval) -> ClosedRange<CGFloat> {
        var minY = loadedTop
        var maxY = loadedTop + loadedHeight
        for block in ghostLedger.snapshots
            where block.anchoring == .viewport
                && block.visibleMemberCount > 0
                && !excluding.contains(block.id) {
            let offset = ghostRenders[block.id].flatMap {
                animationController.ghostBlockOffset(owner: $0.owner, at: time)
            } ?? 0
            let rootY = block.settledRootY + offset - viewportCorrection
            minY = min(minY, rootY + block.localMinY)
            maxY = max(maxY, rootY + block.localMaxY)
        }
        for carry in viewportCarries where carry.isScreenAnchored {
            let top = carry.view.layer.position.y - viewportCorrection
            minY = min(minY, top)
            maxY = max(maxY, top + carry.view.bounds.height)
        }
        return minY...maxY
    }

    /// Hands every earlier carousel strip's teardown to this pass's transition. See the call site.
    private func retimeCarouselExitStrips(excluding: Set<GhostBlockID>,
                                          transition: CoreListTransition,
                                          transactionTime: TimeInterval) {
        for block in ghostLedger.snapshots
            where block.anchoring == .viewport && !excluding.contains(block.id) {
            guard let render = ghostRenders[block.id] else { continue }
            for member in render.members.values {
                let blockID = block.id
                animationController.retimeExit(
                    owner: member.owner,
                    layer: member.view.layer,
                    transition: transition,
                    transactionTime: transactionTime
                ) { [weak self, weak view = member.view] in
                    guard let view else { return }
                    self?.finishGhostMember(blockID: blockID, view: view)
                }
            }
        }
    }

    /// Rebases the mirror overlay's children when the shared viewport correction steps under them.
    /// The counterpart of `shiftExitOverlayChildren`, for the other coordinate space: root and layer
    /// move together, which the animation model does not see because a ghost block holds only an
    /// additive offset.
    private func shiftCarouselExitChildren(by delta: CGFloat) {
        guard delta != 0 else { return }
        for view in carouselExitOverlay.subviews {
            view.layer.position.y += delta
        }
        ghostLedger.shiftRoots(by: delta, anchoring: .viewport)
        assertGhostInvariants()
    }

    /// Content-space rebase only. Promoted carousel content is no longer in `exitOverlay`, and
    /// `ghostLedger.shiftRoots(by:)` skips viewport-anchored blocks, so the two halves of a promoted
    /// block stay in step by construction.
    private func shiftExitOverlayChildren(by delta: CGFloat) {
        guard delta != 0 else { return }
        for view in crossingOverlay.subviews {
            view.layer.position.y += delta
        }
        for view in exitOverlay.subviews {
            view.layer.position.y += delta
        }
        for identity in Array(crossingCarries.keys) {
            guard var carry = crossingCarries[identity] else { continue }
            carry.settledContentY += delta
            crossingCarries[identity] = carry
        }
        ghostLedger.shiftRoots(by: delta)
        assertGhostInvariants()
    }

    /// Every view parked in an overlay must be owned by something that will eventually remove it:
    /// a `viewportCarry` (reaped by `finishViewportGeneration`), a `crossingCarry`, or a ghost
    /// block's wrapper. A view that outlives its owner is stranded forever — the overlays sit above
    /// `container` and have `isUserInteractionEnabled = false`, so it renders on top of live rows
    /// and silently swallows nothing, which is exactly how the "stale rows overlay live rows"
    /// symptom presents.
    ///
    /// A generation's completion is dropped without being invoked whenever a new track replaces an
    /// in-flight one (`discardPendingCompletions` filters rather than fires), so the migration in
    /// `migrateCrossingViewportReleases` / the carry re-stamp is the only thing keeping these
    /// reachable. This asserts that contract instead of trusting it.
    private func assertOverlayInvariants() {
#if DEBUG
        let carriedViews = Set(viewportCarries.map { ObjectIdentifier($0.view) })
        let crossingViews = Set(crossingCarries.values.map { ObjectIdentifier($0.view) })
        let ghostWrappers = Set(ghostRenders.values.map { ObjectIdentifier($0.wrapper) })
        let fadingAttachments = Set(fadingAttachmentViews.allObjects.map { ObjectIdentifier($0) })

        for view in exitOverlay.subviews + carouselExitOverlay.subviews {
            let key = ObjectIdentifier(view)
            if carriedViews.contains(key)
                || ghostWrappers.contains(key)
                || fadingAttachments.contains(key) { continue }
            assertionFailure("exitOverlay holds a view owned by no viewport carry, ghost block or "
                + "fading attachment — it will never be removed and will render above live rows")
        }
        for view in crossingOverlay.subviews {
            if crossingViews.contains(ObjectIdentifier(view)) { continue }
            assertionFailure("crossingOverlay holds a view owned by no crossing carry — "
                + "it will never be removed and will render above live rows")
        }

        // The reverse direction: a carry whose view has drifted out of its overlay is equally broken.
        for carry in viewportCarries {
            let expected = carry.isScreenAnchored ? carouselExitOverlay : exitOverlay
            assert(carry.view.superview === expected,
                   "viewport carry view is not in its exit overlay")
        }
#endif
    }

    private func assertGhostInvariants() {
#if DEBUG
        ghostLedger.assertInvariants()
        assert(Set(ghostMemberViews.map(ObjectIdentifier.init)).count
            == ghostMemberViews.count)
        let snapshots = ghostLedger.snapshots
        assert(Set(snapshots.map(\.id)) == Set(ghostRenders.keys))
        for snapshot in snapshots {
            guard let render = ghostRenders[snapshot.id] else {
                assertionFailure("ghost ledger node is missing its render record")
                continue
            }
            assert(render.members.count == snapshot.visibleMemberCount)
            assert(render.owner == .ghostBlock(snapshot.id.rawValue))
            switch snapshot.anchoring {
            case .content:
                assert(render.wrapper.superview === exitOverlay)
            case .viewport:
                assert(render.wrapper.superview === carouselExitOverlay)
            }
            assert(animationController.model.contains(render.owner))
        }
#endif
    }

    private func attachLive(identity: AnyHashable, layer: CALayer) {
        let now = animationController.now()
        if animationController.positionOffset(identity: identity, at: now) != nil
            || animationController.opacity(owner: .live(identity), at: now) != nil {
            animationController.rebind(identity: identity, layer: layer)
        } else {
            animationController.seedLive(identity: identity, layer: layer)
        }
    }
}

private extension ListAnimationMutation {
    var startedTrack: ListAnimationTrack? {
        guard case let .started(track) = self else { return nil }
        return track
    }
}
