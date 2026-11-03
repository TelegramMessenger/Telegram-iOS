import UIKit
@testable import CoreListDemo

func buildListFrame(listView: CoreVirtualListView,
                    animationController: ListAnimationController,
                    clock: SyntheticClock,
                    boundsOriginY: CGFloat) -> Frame {
    let window = listView.activeWindow
    let now = animationController.now()
    let renderedViewport = boundsOriginY + animationController.viewportOffset(at: now)
    var snapshots: [Int: ItemSnapshot] = [:]

    for item in window.items {
        let identity = listView.items[item.index].identity
        let offset = animationController.positionOffset(identity: identity, at: now) ?? 0
        let opacity = animationController.opacity(owner: .live(identity), at: now) ?? 1
        let visualHeight = animationController.height(identity: identity, at: now)
            ?? item.frame.height
        let y = listView.container.frame.origin.y
            + item.frame.minY - window.minY
            - renderedViewport
            + offset
        snapshots[item.index] = ItemSnapshot(
            modelFrame: item.frame,
            resolvedScreenY: y,
            structuralScreenY: y,
            height: item.frame.height,
            visualHeight: visualHeight,
            alpha: opacity
        )
    }

    return Frame(time: clock.now,
                 containerOriginY: listView.container.frame.origin.y,
                 boundsOriginY: boundsOriginY,
                 containerTranslationY: 0,
                 snapshotOriginY: nil,
                 snapItems: [],
                 items: snapshots)
}

final class VirtualListDriver {
    let clock: SyntheticClock
    let scrollView: TestableScrollView
    let engine: UIKitScrollEngine
    let animationController: ListAnimationController
    let scheduler: TestScheduler
    let listView: CoreVirtualListView

    init(viewport: CGSize,
         items: [CoreListItem],
         preloadMargin: CGFloat = 160,
         clock: SyntheticClock = SyntheticClock(),
         animationController: ListAnimationController? = nil,
         emitsCA: Bool = false) {
        let scrollView = TestableScrollView(clock: clock)
        let engine = UIKitScrollEngine(scrollView: scrollView)
        let controller = animationController ?? ListAnimationController(
            compiler: CoreAnimationCompiler(emitsAnimations: emitsCA),
            mediaTime: { clock.now },
            durationFactor: { 1 }
        )
        let scheduler = TestScheduler()
        let listView = CoreVirtualListView(frame: CGRect(origin: .zero, size: viewport),
                                           engine: engine,
                                           animationController: controller,
                                           scheduler: scheduler)
        controller.seedViewport(layer: engine.contentHost.layer)
        listView.preloadMargin = preloadMargin
        listView.items = items
        listView.applyChanges(newSize: viewport, transition: .easeInOut(duration: 0))
        listView.layoutIfNeeded()

        self.clock = clock
        self.scrollView = scrollView
        self.engine = engine
        self.animationController = controller
        self.scheduler = scheduler
        self.listView = listView
    }

    func tick(dt: TimeInterval) {
        clock.advance(by: dt)
        scrollView.tick(dt: dt)
        animationController.reapSettledTracks()
    }

    func apply(_ items: [CoreListItem], duration: TimeInterval) {
        listView.applyChanges(items: items, transition: .easeInOut(duration: duration))
    }

    func item(identity: AnyHashable) -> CoreVirtualListView.Window.Item? {
        listView.activeWindow.items.first {
            listView.items[$0.index].identity == identity
        }
    }

    func view(identity: AnyHashable) -> (UIView & CoreListItemView)? {
        item(identity: identity)?.view
    }

    func screenY(identity: AnyHashable) -> CGFloat? {
        guard let item = item(identity: identity) else { return nil }
        let now = animationController.now()
        let offset = animationController.positionOffset(identity: identity,
                                                        at: now) ?? 0
        let renderedViewport = engine.offset + animationController.viewportOffset(at: now)
        return listView.container.frame.origin.y
            + item.frame.minY - listView.activeWindow.minY
            - renderedViewport
            + offset
    }

    var exitOverlay: UIView { listView.exitOverlay }

    var viewportCarryViews: [UIView] {
        listView.viewportCarryViews
    }

    /// Screen Y of a parked viewport carry, resolving its coordinate space. A carry promoted out of
    /// a carousel pass lives outside the scrolling content host, so only the viewport correction
    /// applies to it — subtracting the engine offset as well puts it millions of points away, in the
    /// private virtual canvas.
    func viewportCarryScreenY(view: UIView) -> CGFloat {
        let correction = animationController.viewportOffset(at: animationController.now())
        let isScreenAnchored = listView.screenAnchoredViewportCarryViews.contains { $0 === view }
        return view.layer.position.y - (isScreenAnchored ? correction : engine.offset + correction)
    }

    var crossingCarryIdentities: [AnyHashable] {
        listView.crossingCarrySnapshots.map(\.identity)
    }

    var crossingCarryViews: [UIView] {
        crossingCarryIdentities.compactMap { crossingCarryView(identity: $0) }
    }

    func crossingCarryView(identity: AnyHashable) -> UIView? {
        listView.crossingCarryView(identity: identity)
    }

    func crossingCarryScreenY(identity: AnyHashable) -> CGFloat? {
        guard let snapshot = listView.crossingCarrySnapshots.first(where: {
            $0.identity == identity
        }) else { return nil }
        let offset = animationController.positionOffset(
            identity: identity,
            at: animationController.now()
        ) ?? 0
        return snapshot.settledContentY + offset
            - (engine.offset + animationController.viewportOffset(at: animationController.now()))
    }

    var exitSubviews: [UIView] {
        listView.ghostMemberViews
    }

    func isExitMember(_ view: UIView) -> Bool {
        listView.ghostMemberViews.contains { $0 === view }
    }

    func ghostBlockScreenY(_ id: GhostBlockID) -> CGFloat? {
        guard let block = listView.ghostBlockSnapshots.first(where: { $0.id == id }),
              let render = listView.ghostRender(for: id) else { return nil }
        let offset = animationController.ghostBlockOffset(
            owner: render.owner, at: animationController.now()
        ) ?? 0
        let correction = animationController.viewportOffset(at: animationController.now())
        // A viewport-anchored block's root is already a screen quantity: it lives outside the
        // scrolling content host, so only the viewport correction applies to it.
        let renderedViewport = block.anchoring == .viewport
            ? correction
            : engine.offset + correction
        return block.settledRootY + offset - renderedViewport
    }

    func exitScreenY(view: UIView) -> CGFloat? {
        guard let id = listView.ghostBlockID(containing: view),
              let rootY = ghostBlockScreenY(id),
              let render = listView.ghostRender(for: id),
              view.superview === render.wrapper else { return nil }
        return rootY + view.frame.minY
    }

    func settledContentY(identity: AnyHashable) -> CGFloat? {
        guard let item = item(identity: identity) else { return nil }
        return listView.containerOriginY
            + item.frame.minY - listView.activeWindow.minY
    }

    func exitAnimation(view: UIView,
                       property: ListAnimatedProperty) -> CAAnimation? {
        view.layer.animation(
            forKey: animationController.compiler.animationKey(for: property)
        )
    }

    func scroll(to offset: CGFloat) {
        scrollView.bounds.origin.y = offset
        engine.scrollViewDidScroll(scrollView)
    }

    func run(duration: TimeInterval, step: TimeInterval = 1.0 / 60) -> Trace {
        var trace = Trace()
        trace.append(sample())
        var remaining = duration
        let epsilon = step * 0.5
        while remaining > epsilon {
            let dt = min(step, remaining)
            tick(dt: dt)
            trace.append(sample())
            remaining -= dt
        }
        return trace
    }

    func runUntilSettled(max: TimeInterval = 5.0,
                         step: TimeInterval = 1.0 / 60) -> Trace {
        var trace = Trace()
        trace.append(sample())
        var elapsed: TimeInterval = 0
        while elapsed < max {
            if !scrollView.isActive
                && !animationController.hasActiveAnimations(at: animationController.now()) {
                break
            }
            tick(dt: step)
            trace.append(sample())
            elapsed += step
        }
        return trace
    }

    func sample() -> Frame {
        buildListFrame(listView: listView,
                       animationController: animationController,
                       clock: clock,
                       boundsOriginY: engine.offset)
    }
}
