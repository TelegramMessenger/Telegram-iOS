import Foundation

/// Whether a layer that leaves the window gives its MetalEngine surfaces back, and when. A layer kept long after it
/// was last shown should not hold them: each is a dedicated surface, about 5.5 MB for the recording blob at 3x. A move
/// between windows passes through no window for a moment, so the decision waits for the end of the run loop turn,
/// and a layer that is back in a window by then keeps them.
struct LiquidGlassSurfaceReleasePolicy {
    var releasesWhenHidden: Bool
    private(set) var isInWindow: Bool = false

    init(releasesWhenHidden: Bool) {
        self.releasesWhenHidden = releasesWhenHidden
    }

    /// Records a window change. Returns true when the layer should check `releasesNow` at the end of this run loop
    /// turn.
    mutating func update(isInWindow: Bool) -> Bool {
        self.isInWindow = isInWindow
        return !isInWindow && self.releasesWhenHidden
    }

    /// Whether to release the surfaces now, at the end of a turn that `update(isInWindow:)` asked to check.
    var releasesNow: Bool {
        return self.releasesWhenHidden && !self.isInWindow
    }
}
