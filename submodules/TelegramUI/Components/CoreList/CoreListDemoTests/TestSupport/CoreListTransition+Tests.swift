import Foundation
@testable import CoreListDemo

extension CoreListTransition {
    /// Test-only convenience for the contrast curve.
    ///
    /// Production is `.easeInOut` throughout, so a test that wants to prove a pass's curve actually
    /// reaches its track needs a second, distinguishable curve — otherwise the assertion passes on a
    /// track that simply took `ListAnimationTrack.init`'s `.easeInOut` default. `.linear` is a
    /// ComponentTransition case like any other; it just isn't one CoreList chooses on its own.
    ///
    /// Deliberately test-only: the module's public surface stays at `.immediate`/`.easeInOut`/
    /// `.spring`, matching ComponentTransition's own static set.
    static func linear(duration: TimeInterval) -> CoreListTransition {
        CoreListTransition(animation: .curve(duration: duration, curve: .linear))
    }
}
