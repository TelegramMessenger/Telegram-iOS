import Foundation

/// A reaction picked in a message's context menu flies from the reaction bar into the message's reaction button and
/// plays there in place of the button's own icon, until a fallback ends the hand-off and removes it. The icon hides
/// only while that copy is drawing: from the landing, once its expanded animation has rendered its first frame. A copy
/// that has rendered nothing yet leaves the icon visible rather than an empty button (issue #97); one that starts after
/// the landing takes over then, and is cut short by the fallback like any other. StandaloneReactionAnimation, the
/// double-tap path, follows the same rule through ReactionNode's `expandedAnimationDidBegin`.
public final class ReactionFlyInIconHandoff {
    private var hasLanded: Bool = false
    private var expandedAnimationDidBegin: Bool = false
    private var isFinished: Bool = false

    public var hidesTargetIcon: Bool {
        return self.hasLanded && self.expandedAnimationDidBegin && !self.isFinished
    }

    public init() {
    }

    public func land() {
        self.hasLanded = true
    }

    public func expandedAnimationBegan() {
        self.expandedAnimationDidBegin = true
    }

    public func finish() {
        self.isFinished = true
    }
}
