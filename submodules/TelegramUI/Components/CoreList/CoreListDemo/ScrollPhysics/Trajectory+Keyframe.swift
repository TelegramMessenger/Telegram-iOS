import QuartzCore
import CoreGraphics

extension Trajectory {
    /// Build the additive `position.y` keyframe animation for this path. Values are
    /// `finalOffset - offset(tᵢ)` so they add onto the *settled* model position and resolve to 0 at
    /// the end — the same convention as CoreAnimationListAnimator's slides. `.linear` so the render
    /// INTERPOLATES the path to each actual display frame: the vertices are baked at 120/s, so on a
    /// display running below 120Hz (ProMotion throttles to 80/60 for power/thermal regardless of our
    /// rate request) `.discrete` playback would beat — land 1 or 2 vertices per frame unevenly. Linear
    /// interpolation is rate-agnostic (smooth at any refresh), and `offset(at:)` interpolates the same
    /// way so the sampler matches the render. Caller passes the layer-local `beginTime`.
    /// Precondition: `duration > 0` (the degenerate path is handled before launch).
    func positionKeyframeAnimation(beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: "position.y")
        anim.isAdditive = true
        anim.calculationMode = .linear   // interpolate to the actual frame time — rate-agnostic (see note)
        anim.values = samples.map { NSNumber(value: Double(finalOffset - $0.offset)) }
        anim.keyTimes = samples.map { NSNumber(value: $0.t / duration) }
        anim.duration = duration
        anim.beginTime = beginTime
        return anim
    }

    /// Additive `bounds.origin.y` keyframe animation for the list engine. `bounds.origin.y` rises WITH
    /// scroll, so values are `offset(tᵢ) − finalOffset` (NOT negated like the position.y variant),
    /// ending at 0 so they resolve onto the model `bounds.origin.y = finalOffset`. `.linear` so the
    /// render interpolates the path to each actual frame — rate-agnostic, so it stays smooth when
    /// ProMotion runs below 120Hz (where `.discrete` playback of the 120/s vertices would beat). The
    /// sampler `offset(at:)` interpolates the same way, keeping sampler == render. Precondition:
    /// `duration > 0`.
    func boundsOriginKeyframeAnimation(beginTime: CFTimeInterval) -> CAKeyframeAnimation {
        let anim = CAKeyframeAnimation(keyPath: "bounds.origin.y")
        anim.isAdditive = true
        anim.calculationMode = .linear   // interpolate to the actual frame time — rate-agnostic (see note)
        anim.values = samples.map { NSNumber(value: Double($0.offset - finalOffset)) }
        anim.keyTimes = samples.map { NSNumber(value: $0.t / duration) }
        anim.duration = duration
        anim.beginTime = beginTime
        return anim
    }
}
