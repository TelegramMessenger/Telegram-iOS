import QuartzCore

/// Readers for the metadata `CoreAnimationCompiler` stamps on every model-path emission. Test support
/// only — production reads these keys in exactly two places (the controller's resolved-origin lookup
/// and `InsetRectOverlayAnimator.generation(for:on:)`).
extension CAAnimation {
    var coreListGeneration: UInt64? {
        (value(forKey: "CoreListAnimation.generation") as? NSNumber)?.uint64Value
    }

    /// The model track's own clock, declared by the emitter. Readable with no commit, which is what a
    /// windowless fixture needs now that `beginTime` is commit-resolved.
    var coreListDeclaredStartTime: TimeInterval? {
        (value(forKey: "CoreListAnimation.startTime") as? NSNumber)?.doubleValue
    }

    /// The origin policy the emitter chose: `true` for a `.explicit` stamp (rebind), `false` for the
    /// `.atCommit` convention.
    var coreListPreservesPhase: Bool {
        ((value(forKey: "CoreListAnimation.preservesPhase") as? NSNumber)?.boolValue) ?? false
    }
}
