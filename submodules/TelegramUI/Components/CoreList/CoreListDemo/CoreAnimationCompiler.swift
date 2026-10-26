import QuartzCore

/// Where an emitted animation's phase axis is anchored.
///
/// `.atCommit` leaves `beginTime` unset, so Core Animation resolves it at the commit that follows —
/// the same clock every other animation in the app starts on (`CAAnimationUtils` and
/// `CALayer.animate` never stamp one either), which is what lets a host animation committed in the
/// same runloop turn compose with a CoreList track. This is the convention.
///
/// `.explicit` stamps an origin that is in the past by construction. Exactly one caller needs it:
/// `ListAnimationController.rebind`, re-emitting an in-flight track onto another layer. `fillMode =
/// .both` cannot supply that phase — before-begin holds `from`, so an implicit origin would replay
/// the whole curve. The value it stamps is the origin Core Animation RESOLVED for the animation
/// being replaced, not `track.startTime`; see `ListAnimationController.phaseOrigin(for:…)`.
enum CoreListAnimationOrigin: Equatable {
    case atCommit
    case explicit(TimeInterval)
}

final class CoreAnimationCompiler {
    var emitsAnimations: Bool

    init(emitsAnimations: Bool = true) {
        self.emitsAnimations = emitsAnimations
    }

    func animation(for track: ListAnimationTrack,
                   property: ListAnimatedProperty,
                   origin: CoreListAnimationOrigin = .atCommit) -> CAAnimation {
        let animation = makeCoreListAnimation(from: track.from,
                                              to: track.to,
                                              keyPath: keyPath(for: property),
                                              curve: track.curve,
                                              springKind: track.springKind,
                                              logicalDuration: track.duration / max(track.durationFactor, .leastNonzeroMagnitude),
                                              durationFactor: track.durationFactor,
                                              additive: isAdditive(property))
        // Model-path properties the shared factory deliberately does not set. `beginTime` is left
        // UNSET by default so the commit resolves it — see `CoreListAnimationOrigin`.
        let preservesPhase: Bool
        switch origin {
        case .atCommit:
            preservesPhase = false      // leave `beginTime` unset: the commit resolves it
        case let .explicit(time):
            animation.beginTime = time
            preservesPhase = true
        }
        animation.fillMode = .both
        animation.isRemovedOnCompletion = false
        animation.setValue(track.generation, forKey: "CoreListAnimation.generation")
        // The model's phase axis, declared on the animation itself. `beginTime` no longer carries it
        // (the commit does) and a windowless layer never resolves one, so this is what lets the
        // stress oracle keep an EXACT model↔CA clock check with no commit and no test-only path.
        animation.setValue(track.startTime, forKey: "CoreListAnimation.startTime")
        animation.setValue(preservesPhase, forKey: "CoreListAnimation.preservesPhase")
        if property == .viewportOffset || property == .positionX || property == .positionY {
            animation.preferHighRefreshRate()
        }
        return animation
    }

    private func keyPath(for property: ListAnimatedProperty) -> String {
        switch property {
        case .viewportOffset: return "bounds.origin.y"
        case .positionX: return "position.x"
        case .positionY: return "position.y"
        case .width: return "bounds.size.width"
        case .height: return "bounds.size.height"
        case .opacity: return "opacity"
        }
    }

    /// Internal rather than private so the parity test can assert this still delegates — the model
    /// converts presented values using the same classification, and the two must not drift apart.
    func isAdditive(_ property: ListAnimatedProperty) -> Bool {
        return property.isAdditiveTrack
    }

    func install(_ track: ListAnimationTrack,
                 property: ListAnimatedProperty,
                 on layer: CALayer,
                 origin: CoreListAnimationOrigin = .atCommit,
                 completion: (() -> Void)? = nil) {
        guard emitsAnimations else { return }
        let animation = animation(for: track, property: property, origin: origin)
        if let completion {
            animation.setCoreListCompletion { _ in completion() }
        }
        layer.add(animation, forKey: animationKey(for: property))
    }

    func remove(property: ListAnimatedProperty, from layer: CALayer) {
        layer.removeAnimation(forKey: animationKey(for: property))
    }

    func animationKey(for property: ListAnimatedProperty) -> String {
        switch property {
        case .viewportOffset: return "CoreListAnimation.viewportOffset"
        case .positionX: return "CoreListAnimation.positionX"
        case .positionY: return "CoreListAnimation.positionY"
        case .width: return "CoreListAnimation.width"
        case .height: return "CoreListAnimation.height"
        case .opacity: return "CoreListAnimation.opacity"
        }
    }
}
