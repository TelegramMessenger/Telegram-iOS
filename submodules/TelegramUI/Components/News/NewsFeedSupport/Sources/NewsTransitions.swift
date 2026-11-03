import Foundation
import CoreGraphics

/// Rows cascading in when a list's first content replaces its skeleton (Feed2 FeedRow.swift:58, 104-112;
/// FeedScreen.swift:837-855): from alpha 0 and 12 pt lower, on `NewsSpring.appear`, 45 ms apart.
public enum NewsCascade {
    /// Rows built this long after the content arrived still cascade.
    public static let window: Double = 0.6
    public static let offset: CGFloat = 12.0
    public static let step: Double = 0.045
    public static let maxSteps: Int = 8
    /// The mockup's search and widget rows precede its first post in the list.
    public static let leadingRows: Int = 2

    /// The delay of the row at `position` (0 = the first row loaded when the content arrived).
    public static func delay(position: Int) -> Double {
        return Double(min(position + leadingRows, maxSteps)) * step
    }
}

/// A tab tap swaps the pages under a shutter in the list background colour (Feed2 FeedStore.swift:799-815).
public enum NewsShutter {
    public static let fadeInDuration: Double = 0.14
    public static let swapDelay: Double = 0.14
    public static let fadeOutDelay: Double = 0.17
    public static let fadeOutDuration: Double = 0.3
}

/// Cancels the delayed steps of a superseded transition: each `begin()` makes every earlier token stale.
public final class NewsGeneration {
    private var current = 0

    public init() {
    }

    public func begin() -> Int {
        self.current += 1
        return self.current
    }

    public func isCurrent(_ token: Int) -> Bool {
        return token == self.current
    }
}

/// A Reload Feed in progress. It waits for the feed to report a load, then ends when that load ends, whether it
/// succeeded or failed.
public struct NewsReloadTracker: Equatable {
    private enum Phase: Equatable {
        case idle
        case requested
        case loading
    }

    /// A reload gives the rows back after this long even if its load never ends: offline, the request is queued
    /// rather than failed, and the skeleton would otherwise stay until the connection returns.
    public static let timeout: Double = 5.0

    private var phase: Phase = .idle
    private var generation = 0

    public init() {
    }

    public var isActive: Bool {
        return self.phase != .idle
    }

    /// `isLoading`: the feed is already loading (that load becomes the reload's). Returns the token `expire`
    /// takes after `timeout`.
    @discardableResult
    public mutating func begin(isLoading: Bool) -> Int {
        self.generation += 1
        self.phase = isLoading ? .loading : .requested
        return self.generation
    }

    /// Ends the reload begun with `token` if it is still running. Returns true when it ended it.
    public mutating func expire(token: Int) -> Bool {
        guard token == self.generation, self.phase != .idle else {
            return false
        }
        self.phase = .idle
        return true
    }

    /// Feeds the feed's loading flag from a new state. Returns true when this state ends the reload.
    public mutating func observe(isLoading: Bool) -> Bool {
        switch self.phase {
        case .idle:
            return false
        case .requested:
            if isLoading {
                self.phase = .loading
            }
            return false
        case .loading:
            if !isLoading {
                self.phase = .idle
                return true
            }
            return false
        }
    }
}
