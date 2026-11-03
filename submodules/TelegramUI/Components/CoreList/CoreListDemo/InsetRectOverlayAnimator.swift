import UIKit
import QuartzCore

/// Animates the demo's inset guide with the same granular Core Animation tracks as the list.
final class InsetRectOverlayAnimator {
    private let compiler: CoreAnimationCompiler
    private let mediaTime: () -> CFTimeInterval
    private let durationFactor: () -> Double
    private var nextGeneration: UInt64 = 0

    init(compiler: CoreAnimationCompiler = CoreAnimationCompiler(),
         mediaTime: @escaping () -> CFTimeInterval = { CACurrentMediaTime() },
         durationFactor: @escaping () -> Double = { UIView.animationDurationFactor }) {
        self.compiler = compiler
        self.mediaTime = mediaTime
        self.durationFactor = durationFactor
    }

    func transition(view: UIView,
                    to finalFrame: CGRect,
                    transition: CoreListTransition) {
        let layer = view.layer
        let currentFrame = layer.presentation()?.frame ?? layer.frame
        self.transition(layer: layer,
                   from: currentFrame,
                   to: finalFrame,
                   transition: transition.scaled(by: durationFactor()),
                   at: layer.convertTime(mediaTime(), from: nil))
    }

    func transition(layer: CALayer,
                    from currentFrame: CGRect,
                    to finalFrame: CGRect,
                    transition: CoreListTransition,
                    at startTime: CFTimeInterval) {
        // Settled write only; the granular tracks below are what animate. Same reasoning as
        // ListAnimationController's write helpers — `commit` rather than an `.immediate` setter, so
        // the standard animation keys are left alone.
        layer.frame = finalFrame

        install(from: currentFrame.midX - finalFrame.midX,
                to: 0,
                property: .positionX,
                transition: transition,
                at: startTime,
                on: layer)
        install(from: currentFrame.midY - finalFrame.midY,
                to: 0,
                property: .positionY,
                transition: transition,
                at: startTime,
                on: layer)
        install(from: currentFrame.width,
                to: finalFrame.width,
                property: .width,
                transition: transition,
                at: startTime,
                on: layer)
        install(from: currentFrame.height,
                to: finalFrame.height,
                property: .height,
                transition: transition,
                at: startTime,
                on: layer)
    }

    private func install(from: CGFloat,
                         to: CGFloat,
                         property: ListAnimatedProperty,
                         transition: CoreListTransition,
                         at startTime: CFTimeInterval,
                         on layer: CALayer) {
        guard case let .curve(duration, curve) = transition.animation,
              duration > 0,
              abs(from - to) > 1e-6
        else {
            compiler.remove(property: property, from: layer)
            return
        }

        nextGeneration &+= 1
        let track = ListAnimationTrack(generation: nextGeneration,
                                       from: from,
                                       to: to,
                                       startTime: startTime,
                                       duration: duration,
                                       curve: curve)
        // `.atCommit`, stated rather than defaulted, because this animator is the module's one
        // producer whose `from` is sampled from the RENDER SERVER (`layer.presentation()`) rather
        // than from the model. Under an explicit stamp at `startTime` the new curve rendered exactly
        // the sampled value at its own origin, so a retarget was continuous by construction; under an
        // implicit origin the curve starts at `startTime + δ` while `from` still holds the value from
        // `startTime`, costing a `velocity × δ` step on every retarget of an in-flight guide. That is
        // accepted: the guide must share the list's clock, and every other presentation-sampled
        // emitter in the module (the `CoreListTransition` setters, via `CALayer.animate` with no
        // delay) already pays exactly this. Do NOT "fix" a visible step here by re-stamping — that
        // would put the guide δ ahead of the list it annotates.
        compiler.install(track, property: property, on: layer, origin: .atCommit) { [weak self, weak layer] in
            guard let self, let layer else { return }
            self.complete(property: property,
                          generation: track.generation,
                          on: layer)
        }
    }

    func generation(for property: ListAnimatedProperty, on layer: CALayer) -> UInt64? {
        let key = compiler.animationKey(for: property)
        return (layer.animation(forKey: key)?.value(forKey: "CoreListAnimation.generation")
                as? NSNumber)?.uint64Value
    }

    func complete(property: ListAnimatedProperty,
                  generation: UInt64,
                  on layer: CALayer) {
        guard self.generation(for: property, on: layer) == generation else { return }
        compiler.remove(property: property, from: layer)
    }
}
