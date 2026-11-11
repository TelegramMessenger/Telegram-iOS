import Foundation
import CoreGraphics
import TLottieBinding

/// Telegram's accept/reject policy for a Lottie animation.
///
/// These limits are the app's, not the renderer's, so they live here rather than
/// in the binding. The values are the ones the app has always enforced.
private enum LottieInstanceLimits {
    static let maximumDimension: CGFloat = 1536.0
    static let maximumFrameRate: Int32 = 360
    static let maximumDuration: Double = 9.0

    static func permits(_ instance: LottieInstance) -> Bool {
        if instance.dimensions.width > self.maximumDimension
            || instance.dimensions.height > self.maximumDimension {
            return false
        }
        if instance.frameRate > self.maximumFrameRate {
            return false
        }
        if instance.duration > self.maximumDuration {
            return false
        }
        return true
    }
}

/// `colorReplacements` is `[AnyHashable: Any]?` — the type the binding's ObjC
/// `NSDictionary *` parameter imports as — rather than `NSDictionary?`, so that
/// the live call sites keep compiling unchanged. Swift bridges a `Dictionary` to
/// `NSDictionary` implicitly only at an ObjC boundary, not at a Swift one, so an
/// `NSDictionary?` parameter would force `as NSDictionary?` at every site that
/// passes a Swift dictionary (`ManagedAnimationItem.replaceColors` is
/// `[UInt32: UInt32]?`). Collection upcasting to `[AnyHashable: Any]` is
/// implicit, so this spelling needs no cast anywhere.
public func makeLottieInstance(
    data: Data,
    fitzModifier: LottieFitzModifier,
    colorReplacements: [AnyHashable: Any]?
) -> LottieInstance? {
    guard let instance = TLottieAnimation(
        data: data,
        fitzModifier: fitzModifier.tlottieValue,
        colorReplacements: colorReplacements
    ), LottieInstanceLimits.permits(instance) else {
        return nil
    }
    return instance
}
