import Foundation
import CoreGraphics
import LottieSettings
import RLottieBinding
import TLottieBinding

/// Telegram's accept/reject policy for a Lottie animation.
///
/// These limits are the app's, not a renderer's. They live here rather than in
/// either backend because if the two enforced them differently, flipping the
/// killswitch would change *which stickers render at all*, not merely how they
/// are rasterized. The values are the ones RLottieInstance's initializer
/// enforced before this refactor.
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

/// `cacheKey` is rlottie's internal parsed-model cache key. tlottie has no such
/// cache and ignores it.
///
/// `colorReplacements` is `[AnyHashable: Any]?` — the type the backends' ObjC
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
    colorReplacements: [AnyHashable: Any]?,
    cacheKey: String,
    settings: LottieRenderingSettings
) -> LottieInstance? {
    let instance: LottieInstance?
    switch settings.backend {
    case .rlottie:
        instance = RLottieInstance(
            data: data,
            fitzModifier: fitzModifier.rlottieValue,
            colorReplacements: colorReplacements,
            cacheKey: cacheKey
        )
    case .tlottie:
        instance = TLottieAnimation(
            data: data,
            fitzModifier: fitzModifier.tlottieValue,
            colorReplacements: colorReplacements
        )
    }
    guard let instance, LottieInstanceLimits.permits(instance) else {
        return nil
    }
    return instance
}
