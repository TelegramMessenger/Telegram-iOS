import Foundation
import UIKit

/// While a bar is lifted by a navigation transition, the scroll-driven layout its screen's list asks for is held, and
/// the last offset is applied when the bar is put back, so the header neither collapses nor expands mid-transition.
public struct NavigationBarLiftedScrollGate {
    public var isClosed = false
    private var heldOffset: CGFloat?
    private var hasPendingLayout = false

    public init() {
    }

    /// Whether `offset` applies now; a closed gate keeps it.
    public mutating func offer(_ offset: CGFloat) -> Bool {
        if self.isClosed {
            self.heldOffset = offset
            return false
        }
        return true
    }

    /// The bar was asked for a layout (no scroll with it); while closed, put-back applies it.
    public mutating func noteLayout() {
        if self.isClosed {
            self.hasPendingLayout = true
        }
    }

    /// Opens the gate; the offset to apply now: the last one it kept, else `currentOffset` when a layout was asked for
    /// while it was closed, else nil.
    public mutating func open(currentOffset: CGFloat?) -> CGFloat? {
        self.isClosed = false
        let offset = self.heldOffset ?? (self.hasPendingLayout ? currentOffset : nil)
        self.heldOffset = nil
        self.hasPendingLayout = false
        return offset
    }
}
