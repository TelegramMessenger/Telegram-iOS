import Foundation
import UIKit
import Display

/// A media clock and a deadline scheduler a test moves by hand, installed on every `NavigationAnimationClock` made
/// while it is attached (no render server runs in the test process, so nothing resolves an origin by itself).
final class ManualAnimationTime {
    var now: Double = 1000.0
    var factor: Double = 1.0
    private var pending: [(time: Double, order: Int, action: () -> Void)] = []
    private var order = 0

    func attach() {
        NavigationAnimationClock.configureForTesting = { [weak self] clock in
            guard let self else {
                return
            }
            clock.now = { [weak self] in self?.now ?? 0.0 }
            clock.durationFactor = { [weak self] in self?.factor ?? 1.0 }
            clock.schedule = { [weak self] delay, action in
                self?.schedule(delay, action)
            }
        }
    }

    func detach() {
        NavigationAnimationClock.configureForTesting = nil
    }

    func schedule(_ delay: Double, _ action: @escaping () -> Void) {
        self.order += 1
        self.pending.append((self.now + max(0.0, delay), self.order, action))
    }

    /// Moves the clock on by `seconds` of media time, running each deadline that falls due, in time order.
    func advance(by seconds: Double) {
        let end = self.now + seconds
        while let next = self.pending.filter({ $0.time <= end }).min(by: { ($0.time, $0.order) < ($1.time, $1.order) }) {
            self.pending.removeAll(where: { $0.order == next.order })
            self.now = max(self.now, next.time)
            next.action()
        }
        self.now = end
    }

    /// Stands in for Core Animation resolving the clock animation's origin at a commit `delay` seconds after the bake.
    func resolveOrigin(of clock: NavigationAnimationClock, at time: Double) {
        guard let animation = clock.layer.animation(forKey: NavigationAnimationClock.animationKey)?.copy() as? CAAnimation else {
            return
        }
        animation.beginTime = clock.layer.convertTime(time, from: nil)
        clock.layer.add(animation, forKey: NavigationAnimationClock.animationKey)
    }
}
