import UIKit
@testable import CoreListDemo

final class VirtualListFixture {
    let driver: VirtualListDriver
    private var rememberedViews: [AnyHashable: UIView] = [:]

    init(viewport: CGSize = CGSize(width: 390, height: 800),
         items: [CoreListItem],
         preloadMargin: CGFloat = 160,
         clock: SyntheticClock = SyntheticClock(),
         mediaTime: (() -> CFTimeInterval)? = nil,
         emitsCA: Bool = false) {
        let compiler = CoreAnimationCompiler(emitsAnimations: emitsCA)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: mediaTime ?? { clock.now },
            durationFactor: { 1 }
        )
        driver = VirtualListDriver(viewport: viewport,
                                   items: items,
                                   preloadMargin: preloadMargin,
                                   clock: clock,
                                   animationController: controller)
    }

    convenience init(itemCount: Int,
                     itemHeight: CGFloat = 50,
                     viewport: CGSize = CGSize(width: 390, height: 800),
                     preloadMargin: CGFloat = 160,
                     clock: SyntheticClock = SyntheticClock(),
                     emitsCA: Bool = false) {
        let items: [CoreListItem] = (0..<itemCount).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: itemHeight)
        }
        self.init(viewport: viewport,
                  items: items,
                  preloadMargin: preloadMargin,
                  clock: clock,
                  emitsCA: emitsCA)
    }

    var listView: CoreVirtualListView { driver.listView }
    var scrollView: TestableScrollView { driver.scrollView }
    var animationController: ListAnimationController { driver.animationController }
    var clock: SyntheticClock { driver.clock }
    var scheduler: TestScheduler { driver.scheduler }
    var activeWindow: CoreVirtualListView.Window { listView.activeWindow }
    var loadedIndices: [Int] { activeWindow.items.map(\.index) }
    var contentSize: CGSize { scrollView.contentSize }
    var declaredEdges: (min: CGFloat?, max: CGFloat?) { listView.declaredEdges }
    var containerOriginY: CGFloat { listView.containerOriginY }
    var boundsOriginY: CGFloat { scrollView.bounds.origin.y }
    var viewportTrack: ListAnimationTrack? {
        animationController.model.track(for: .viewport, property: .viewportOffset)
    }
    var viewportCorrection: CGFloat {
        animationController.viewportOffset(at: animationController.now())
    }
    var viewportCarryViews: [UIView] { driver.viewportCarryViews }
    var crossingCarryIdentities: [AnyHashable] { driver.crossingCarryIdentities }
    var crossingCarryViews: [UIView] { driver.crossingCarryViews }
    var ghostBlocks: [GhostBlockSnapshot] { listView.ghostBlockSnapshots }
    var ghostMemberViews: [UIView] { driver.exitSubviews }
    var hasActiveAnimations: Bool {
        animationController.hasActiveAnimations(at: animationController.now())
    }

    func flushScheduler() { scheduler.flush() }
    func fireScroll() { driver.engine.scrollViewDidScroll(scrollView) }

    func apply(_ items: [CoreListItem], duration: TimeInterval) {
        driver.apply(items, duration: duration)
    }

    func frame(identity: AnyHashable) -> CGRect? {
        driver.item(identity: identity)?.frame
    }

    func view(identity: AnyHashable) -> (UIView & CoreListItemView)? {
        driver.view(identity: identity)
    }

    func crossingCarryView(identity: AnyHashable) -> UIView? {
        driver.crossingCarryView(identity: identity)
    }

    func screenY(identity: AnyHashable) -> CGFloat? {
        driver.screenY(identity: identity)
    }

    func renderedY(identity: AnyHashable) -> CGFloat? {
        if let item = driver.item(identity: identity) {
            rememberedViews[identity] = item.view
            return driver.screenY(identity: identity)
        }
        if let crossingY = driver.crossingCarryScreenY(identity: identity) {
            return crossingY
        }
        guard let remembered = rememberedViews[identity],
              let carry = viewportCarryViews.first(where: { $0 === remembered })
        else { return nil }
        return driver.viewportCarryScreenY(view: carry)
    }

    func simulateDrag(by deltaY: CGFloat) {
        scrollView.simulateDrag(by: deltaY)
    }

    func simulateRelease() {
        scrollView.simulateRelease()
    }

    /// Fires the engine's finger-down callback without moving the offset.
    ///
    /// `scroll(to:)` and `simulateDrag(by:)` are both offset writes that reach the list through
    /// `scrollViewDidScroll` only — neither is a *touch*. The bottom-edge pin latch releases on the
    /// touch, not on the movement, so a test for release has to say so explicitly.
    func beginUserDrag() {
        driver.engine.scrollViewWillBeginDragging(scrollView)
    }

    func settledScreenY(identity: AnyHashable) -> CGFloat? {
        guard let item = driver.item(identity: identity) else { return nil }
        let renderedViewport = driver.engine.offset + viewportCorrection
        return listView.container.frame.origin.y
            + item.frame.minY - activeWindow.minY
            - renderedViewport
    }

    func settledContentY(identity: AnyHashable) -> CGFloat? {
        driver.settledContentY(identity: identity)
    }

    func positionTrack(identity: AnyHashable) -> ListAnimationTrack? {
        animationController.model.track(for: .live(identity), property: .positionY)
    }

    func opacityTrack(identity: AnyHashable) -> ListAnimationTrack? {
        animationController.model.track(for: .live(identity), property: .opacity)
    }

    func heightTrack(identity: AnyHashable) -> ListAnimationTrack? {
        animationController.model.track(for: .live(identity), property: .height)
    }

    func ghostBlockTrack(_ id: GhostBlockID) -> ListAnimationTrack? {
        animationController.model.track(for: .ghostBlock(id.rawValue), property: .positionY)
    }

    func visualHeight(identity: AnyHashable) -> CGFloat? {
        animationController.height(identity: identity, at: animationController.now())
    }

    func opacity(identity: AnyHashable) -> CGFloat? {
        animationController.opacity(owner: .live(identity), at: animationController.now())
    }

    func scroll(to offset: CGFloat) {
        driver.scroll(to: offset)
    }

    func screenY(forIndex index: Int) -> CGFloat? {
        guard let item = activeWindow.items.first(where: { $0.index == index }) else { return nil }
        let identity = listView.items[index].identity
        let now = animationController.now()
        let offset = animationController.positionOffset(identity: identity,
                                                        at: now) ?? 0
        let renderedViewport = driver.engine.offset
            + animationController.viewportOffset(at: now)
        return listView.container.frame.origin.y
            + item.frame.minY - activeWindow.minY
            - renderedViewport
            + offset
    }

    func screenFrame(forIndex index: Int) -> CGRect? {
        guard let y = screenY(forIndex: index),
              let item = activeWindow.items.first(where: { $0.index == index }) else { return nil }
        return CGRect(x: 0,
                      y: y,
                      width: listView.logicalSize.width,
                      height: item.frame.height)
    }

    func isVisible(index: Int) -> Bool {
        guard let frame = screenFrame(forIndex: index) else { return false }
        return frame.maxY > 0 && frame.minY < listView.logicalSize.height
    }

    func tick(dt: TimeInterval) { driver.tick(dt: dt) }
    func advance(by dt: TimeInterval) { driver.tick(dt: dt) }
    func run(duration: TimeInterval, step: TimeInterval = 1.0 / 60) -> Trace {
        driver.run(duration: duration, step: step)
    }
    func runUntilSettled(max: TimeInterval = 5.0,
                         step: TimeInterval = 1.0 / 60) -> Trace {
        driver.runUntilSettled(max: max, step: step)
    }
    func sample() -> Frame { driver.sample() }

    func resize(width: CGFloat? = nil, height: CGFloat? = nil) {
        let size = CGSize(width: width ?? listView.logicalSize.width,
                          height: height ?? listView.logicalSize.height)
        listView.frame = CGRect(origin: listView.frame.origin, size: size)
        listView.applyChanges(newSize: size, transition: .easeInOut(duration: 0))
    }
}
