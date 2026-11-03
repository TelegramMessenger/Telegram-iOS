import UIKit
@testable import CoreListDemo

final class PhysicsListFixture {
    let driver: PhysicsListDriver

    init(viewport: CGSize = CGSize(width: 390, height: 800),
         items: [CoreListItem],
         preloadMargin: CGFloat = 160,
         decelerationMode: TestScrollEngine.DecelerationMode = .stepped,
         clock: SyntheticClock = SyntheticClock(),
         emitsCA: Bool = false) {
        let compiler = CoreAnimationCompiler(emitsAnimations: emitsCA)
        let controller = ListAnimationController(
            compiler: compiler,
            mediaTime: { clock.now },
            durationFactor: { 1 }
        )
        driver = PhysicsListDriver(viewport: viewport,
                                   items: items,
                                   preloadMargin: preloadMargin,
                                   decelerationMode: decelerationMode,
                                   clock: clock,
                                   animationController: controller)
    }

    convenience init(itemCount: Int,
                     itemHeight: CGFloat = 50,
                     viewport: CGSize = CGSize(width: 390, height: 800),
                     preloadMargin: CGFloat = 160,
                     decelerationMode: TestScrollEngine.DecelerationMode = .stepped) {
        let items: [CoreListItem] = (0..<itemCount).map { _ in
            IdentifiableFixedHeightItem(id: UUID(), height: itemHeight)
        }
        self.init(viewport: viewport,
                  items: items,
                  preloadMargin: preloadMargin,
                  decelerationMode: decelerationMode)
    }

    var listView: CoreVirtualListView { driver.listView }
    var engine: TestScrollEngine { driver.engine }
    var animationController: ListAnimationController { driver.animationController }
    var clock: SyntheticClock { driver.clock }
    var scheduler: TestScheduler { driver.scheduler }
    var activeWindow: CoreVirtualListView.Window { listView.activeWindow }
    var loadedIndices: [Int] { activeWindow.items.map(\.index) }
    var offset: CGFloat { engine.offset }
    var containerOriginY: CGFloat { listView.containerOriginY }
    var viewportTrack: ListAnimationTrack? {
        animationController.model.track(for: .viewport, property: .viewportOffset)
    }
    var viewportCorrection: CGFloat {
        animationController.viewportOffset(at: animationController.now())
    }
    var viewportCarryViews: [UIView] { listView.viewportCarryViews }
    var hasActiveAnimations: Bool {
        animationController.hasActiveAnimations(at: animationController.now())
    }

    func flushScheduler() { scheduler.flush() }
    func simulateFlick(offsetVelocity velocity: CGFloat) {
        engine.simulateFlick(offsetVelocity: velocity)
    }
    func beginDrag() { engine.beginDrag() }
    func drag(translation: CGFloat, velocity: CGFloat) {
        engine.drag(translation: translation, velocity: velocity)
    }
    @discardableResult
    func endDrag() -> Bool { engine.endDrag() }
    func tick(dt: TimeInterval) { driver.tick(dt: dt) }
    func run(duration: TimeInterval, step: TimeInterval = 1.0 / 60) -> Trace {
        driver.run(duration: duration, step: step)
    }
    func runUntilSettled(max: TimeInterval = 5.0,
                         step: TimeInterval = 1.0 / 60) -> Trace {
        driver.runUntilSettled(max: max, step: step)
    }
    func sample() -> Frame { driver.sample() }
}
