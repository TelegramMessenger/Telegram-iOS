import Foundation

final class SyntheticClock {
    // Plain settable time lets focused model/controller tests place the clock at exact phases.
    // Existing harness consumers remain compatible because they advance it through `advance(by:)`.
    var now: TimeInterval = 0

    func advance(by dt: TimeInterval) {
        now += dt
    }
}
