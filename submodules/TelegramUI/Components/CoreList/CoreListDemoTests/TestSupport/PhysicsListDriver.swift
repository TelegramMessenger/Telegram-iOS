import UIKit
@testable import CoreListDemo

final class PhysicsListDriver {
    let clock: SyntheticClock
    let engine: TestScrollEngine
    let animationController: ListAnimationController
    let scheduler: TestScheduler
    let listView: CoreVirtualListView

    init(viewport: CGSize,
         items: [CoreListItem],
         preloadMargin: CGFloat = 160,
         decelerationMode: TestScrollEngine.DecelerationMode = .stepped,
         clock: SyntheticClock = SyntheticClock(),
         animationController: ListAnimationController? = nil,
         emitsCA: Bool = false) {
        let engine = TestScrollEngine(clock: clock, viewport: viewport)
        engine.decelerationMode = decelerationMode
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
        self.engine = engine
        self.animationController = controller
        self.scheduler = scheduler
        self.listView = listView
    }

    func tick(dt: TimeInterval) {
        clock.advance(by: dt)
        engine.tick(dt: dt)
        animationController.reapSettledTracks()
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
            if !engine.isDecelerating
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
