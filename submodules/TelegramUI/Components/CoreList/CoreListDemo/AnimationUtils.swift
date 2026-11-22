import Foundation
import UIKit

#if targetEnvironment(simulator)
@_silgen_name("UIAnimationDragCoefficient") func UIAnimationDragCoefficient() -> Float
#endif

extension UIView {
    #if DEBUG
    /// DEBUG-only override for the drag coefficient (the Simulator "Slow Animations" factor). Since EVERY
    /// codebase CAAnimation multiplies its duration by `animationDurationFactor` (and the fade/deadline math
    /// divides by it), setting this to e.g. 10 faithfully reproduces Slow Animations DETERMINISTICALLY —
    /// without the Simulator UI toggle — so the slow-anims-only alpha-snap/pile class can be captured
    /// autonomously (task #5; set via the demo's `-P5DragCoeff`). nil ⇒ read the real coefficient.
    static var debugAnimationDurationFactorOverride: Double?
    #endif
    static var animationDurationFactor: Double {
    #if DEBUG
        if let o = debugAnimationDurationFactorOverride { return o }
    #endif
    #if targetEnvironment(simulator)
        return Double(UIAnimationDragCoefficient())
    #else
        return 1.0
    #endif
    }
}
