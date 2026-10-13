import UIKit

/// `ScrollEngine` backed by `UIScrollView`. Behavior-preserving adapter: it keeps UIKit's
/// pan/momentum/rubber-band/bounce while exposing the physics-semantic seam. The 10M
/// virtual-content trick and the re-entrancy guard live HERE — `UIScrollView` needs a finite
/// `contentSize`; a future physics engine implements `ScrollEngine` without either.
final class UIKitScrollEngine: NSObject, ScrollEngine, UIScrollViewDelegate {
    // Diagnostic only (FlightTrace-gated): the real scroll view's release velocity and opening frames.
    private var uikitOpeningLink: CADisplayLink?
    private var uikitOpeningSamples = 0
    private var uikitLaunchOffset: CGFloat = 0
    private var uikitLaunchWall: CFTimeInterval = 0
    /// The 10,000,000pt virtual canvas is recentred mid-scroll, which moves the offset without moving
    /// the content — subtract it or an opening sample reads as a five-million-point "frame".
    private var uikitShiftAccum: CGFloat = 0
    let scrollView: UIScrollView
    var onScroll: ((CGFloat) -> Void)?

    /// Never fires: UIScrollView advances `bounds.origin` on the main thread every frame, so a
    /// per-frame consumer is already in lockstep with the content.
    var onFlightChanged: ((ScrollFlight?) -> Void)?
    var onWillBeginDragging: (() -> Void)?
    var onDidEndDragging: (() -> Void)?
    var shouldStopScrollingOnRelease: ((CGFloat) -> Bool)?

    /// Raised around programmatic writes so the re-entrant `scrollViewDidScroll` is suppressed.
    /// This is the old `CoreVirtualListView.isUpdating`, now encapsulated.
    private var isProgrammatic = false

    init(scrollView: UIScrollView = UIScrollView()) {
        self.scrollView = scrollView
        super.init()
        scrollView.delegate = self
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = false
        scrollView.bounces = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.clipsToBounds = false
        scrollView.layer.borderColor = UIColor.blue.cgColor
        scrollView.layer.borderWidth = 1.0
    }

    /// `UIScrollView` clamps `bounds.origin.y` to [0, contentSize − viewport], so it needs a finite
    /// content extent far from 0 for an open edge to be effectively unreachable. Private to the adapter.
    private let canvasExtent: CGFloat = 10_000_000

    var offset: CGFloat { scrollView.bounds.origin.y }
    var contentHost: UIView { scrollView }

    func containerOrigin(windowHeight h: CGFloat, topLoaded: Bool, bottomLoaded: Bool) -> CGFloat {
        if topLoaded { return 0 }                       // glued to the top bounce point
        if bottomLoaded { return canvasExtent - h }     // bottom glued; room above toward 0
        return canvasExtent / 2 - h / 2                 // centred; room both ways
    }

    func setOffset(_ y: CGFloat) {
        isProgrammatic = true
        scrollView.bounds.origin.y = y
        isProgrammatic = false
    }

    // UIKit owns the drag and its own rubber band; a `contentSize` change re-bands inside
    // `UIScrollView` with no anchor of ours to move.
    func reanchorDragToCurrentPosition() {}

    func haltMotionInPlace() {
        // A `UIScrollView`'s `bounds.origin` IS its presented position, so writing it back is an exact
        // halt-in-place here — this is the historical `setOffset(offset)` idiom, now stated once instead of
        // at four call sites, and behaviour-preserving for this backend. (If UIKit momentum ever needs a
        // harder stop than a programmatic offset write, the canonical form is
        // `setContentOffset(contentOffset, animated: false)` — deliberately not changed here, since this
        // backend's behaviour is not what the change is about.)
        setOffset(offset)
    }

    func syncToPresentedPosition() {
        // A `UIScrollView`'s `bounds.origin` is always the presented value; there is nothing to re-anchor.
    }

    func applyShift(_ dy: CGFloat) {
        isProgrammatic = true
        uikitShiftAccum += dy       // diagnostic only: canvas rebases move the offset, not the content
        scrollView.bounds.origin.y += dy
        isProgrammatic = false
    }

    func setEdges(min: CGFloat?, max: CGFloat?) {
        let height: CGFloat
        if let lo = min, let hi = max {
            // UIScrollView bounces at [0, contentSize.height − viewport]; contentSize.height =
            // maxOffset + viewport. The floor reproduces `max(logicalSize.height, window.height)`
            // and handles content shorter than the viewport (hi − lo negative).
            let viewport = scrollView.bounds.height
            height = Swift.max(viewport, (hi - lo) + viewport)
        } else {
            height = canvasExtent
        }
        // A contentSize SHRINK clamps `bounds.origin.y` into the new [0, contentSize − viewport]
        // range, which fires `scrollViewDidScroll`. `setEdges` is a programmatic declaration (called
        // from `render()`), never a user scroll — so guard it like `setOffset`/`applyShift`. Without
        // this, shrinking the canvas (e.g. a delete that turns a deep bottom-loaded window into a
        // tight both-edges-loaded one) clamps the offset by a huge amount and RE-ENTERS
        // `onScroll → handleUserScroll → rebalanceActiveWindow` mid-render, with a stale
        // `containerOriginY`, collapsing the loaded window to a single row.
        isProgrammatic = true
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: height)
        isProgrammatic = false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard !isProgrammatic else { return }
        onScroll?(scrollView.bounds.origin.y)
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        onWillBeginDragging?()
    }

    /// UIKit hands us ITS OWN release velocity here, in points per millisecond — the same unit and the
    /// same quantity `ReleaseDecision` computes — plus the landing it projects from it. That makes this
    /// the one place the replica can be compared against the real thing live, rather than inferred: if
    /// our velocity is systematically lower for a comparable flick, a slower initial speed follows
    /// directly, and no amount of trajectory instrumentation would show it because our path would be
    /// self-consistently correct for the velocity we captured.
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Ahead of the diagnostics below: UIKit's own way to release without momentum is to project
        // the landing onto the current offset, which is what `ListViewImpl` does with the same hook
        // (`Display/Source/ListView.swift:897`). UIKit still bounces back from an overscrolled
        // release afterwards, matching the physics engine's `.stop` outcome.
        if shouldStopScrollingOnRelease?(velocity.y) == true {
            targetContentOffset.pointee = scrollView.contentOffset
        }
        
        guard FlightTrace.isEnabled else { return }
        FlightTrace.shared.begin("UISCROLLVIEW flight")
        let from = scrollView.contentOffset.y
        FlightTrace.shared.log(String(
            format: "launch v=%.6f offset=%.1f target=%.1f travel=%.1f  (UIKit's own numbers)",
            velocity.y, from, targetContentOffset.pointee.y, targetContentOffset.pointee.y - from))
        uikitLaunchOffset = from
        uikitShiftAccum = 0
        uikitOpeningSamples = 0
        uikitLaunchWall = CACurrentMediaTime()
        uikitOpeningLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(uikitOpeningTick))
        link.add(to: .main, forMode: .common)
        uikitOpeningLink = link
    }

    /// Opening frames of a REAL UIScrollView deceleration, in the same shape as the physics engine's
    /// so the two can be compared line for line.
    @objc private func uikitOpeningTick() {
        guard uikitOpeningSamples < 6 else {
            uikitOpeningLink?.invalidate(); uikitOpeningLink = nil
            FlightTrace.shared.flush()
            return
        }
        uikitOpeningSamples += 1
        FlightTrace.shared.log(String(format: "OPENING uikit(contentOffset) #%d t=%.2fms moved=%.1f",
                                      uikitOpeningSamples,
                                      (CACurrentMediaTime() - uikitLaunchWall) * 1000,
                                      scrollView.contentOffset.y - uikitShiftAccum - uikitLaunchOffset))
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        onDidEndDragging?()
    }
}
