import Foundation
import QuartzCore

/// Keeps a glass button's context menu from opening and closing faster than its liquid morph can follow: opened again
/// right after closing, or closed right after opening, the morph glitches. An open waits until the interval has passed
/// since the last close (`perform`), and a menu action closes the menu no sooner than the interval after it opened
/// (`dismissDelay`). One cooldown per button.
public final class ContextMenuCooldown {
    public static var interval: Double {
        if #available(iOS 27.0, *) {
            return 1.0
        } else if #available(iOS 26.0, *) {
            return 1.2
        } else {
            return 0.0
        }
    }

    private var openedAt: Double = 0.0
    private var closedAt: Double = 0.0
    private var pending: DispatchWorkItem?

    public init() {
    }

    /// How long a menu action should wait before closing the menu.
    public var dismissDelay: Double {
        return max(0.0, ContextMenuCooldown.interval - (CACurrentMediaTime() - self.openedAt))
    }

    public func markOpened() {
        self.openedAt = CACurrentMediaTime()
    }

    public func markClosed() {
        self.closedAt = CACurrentMediaTime()
    }

    /// Runs `action` (opening the menu) now, or once the interval since the last close has passed. Taps while one is
    /// waiting are dropped.
    public func perform(_ action: @escaping () -> Void) {
        let remaining = ContextMenuCooldown.interval - (CACurrentMediaTime() - self.closedAt)
        guard remaining > 0.0 else {
            action()
            return
        }
        guard self.pending == nil else {
            return
        }
        let workItem = DispatchWorkItem { [weak self] in
            self?.pending = nil
            action()
        }
        self.pending = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remaining, execute: workItem)
    }

    public func cancel() {
        self.pending?.cancel()
        self.pending = nil
    }
}
