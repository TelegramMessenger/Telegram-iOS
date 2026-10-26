import UIKit
import QuartzCore

extension CAAnimation {
    /// Request the highest available refresh rate so this animation runs at the display's maximum
    /// (e.g. 120Hz ProMotion) instead of Core Animation's default cap. Applied to the list's
    /// `position.y` slides / `bounds` resizes and the keyframe deceleration — the motion that visibly
    /// benefits. OPACITY fades are intentionally left at the default rate (they don't benefit from a
    /// higher rate). No-op on ≤60Hz displays (including the iOS Simulator), so it changes nothing in
    /// tests and on non-ProMotion hardware.
    func preferHighRefreshRate() {
        let maxFps = Float(UIScreen.main.maximumFramesPerSecond)
        guard maxFps > 61.0 else { return }
        if let basic = self as? CABasicAnimation, basic.keyPath == "opacity" { return }
        if #available(iOS 15.0, *) {
            preferredFrameRateRange = CAFrameRateRange(minimum: 30.0, maximum: maxFps, preferred: maxFps)
        }
    }
}
