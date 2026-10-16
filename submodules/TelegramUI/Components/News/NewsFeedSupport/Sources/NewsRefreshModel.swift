import Foundation
import CoreGraphics

/// What a refresh fetch brought. A failed refresh is `.nothing`: the feeds keep their items on a failure, so it looks
/// like an empty one.
public enum NewsRefreshOutcome: Equatable {
    case posts(Int)
    case nothing
}

/// What the screen reports on each tick, in its own coordinates (spec §1.1).
public struct NewsRefreshInput: Equatable {
    /// How far the list is pulled past its resting top. It includes the hold.
    public var gap: CGFloat
    public var isDragging: Bool
    /// The list rests at its current top edge, held or not, within 1.5 pt.
    public var atEdge: Bool
    /// A pull may start (spec §1.2).
    public var canPull: Bool
    public var islandFrame: CGRect
    /// The search field's top with the list at rest, unpulled. The field moves down with the pull.
    public var restingSearchFieldTop: CGFloat
    /// The first row's live top, or nil when it is not on screen.
    public var firstPostTop: CGFloat?

    public init(gap: CGFloat, isDragging: Bool, atEdge: Bool, canPull: Bool, islandFrame: CGRect, restingSearchFieldTop: CGFloat, firstPostTop: CGFloat?) {
        self.gap = gap
        self.isDragging = isDragging
        self.atEdge = atEdge
        self.canPull = canPull
        self.islandFrame = islandFrame
        self.restingSearchFieldTop = restingSearchFieldTop
        self.firstPostTop = firstPostTop
    }
}

public enum NewsRefreshEvent: Equatable {
    /// The threshold: a medium haptic at 0.9, start the fetch, hold the list.
    case begin
    /// The refresh's result may be shown. `slides`: the new posts go in at the top of a list at rest, the old ones
    /// sliding down; otherwise whatever it changed appears without moving what is on screen.
    case insertRows(slides: Bool)
}

/// The pull-to-refresh drop as a function of time (spec §1). `step` advances it and returns what happened;
/// `hold` and `dropPose` read it.
public struct NewsRefreshModel {
    public enum Phase: Equatable {
        case idle
        case loading(since: Double)
        /// The drop shrinks back into the island. Every refresh ends this way (user decision, 2026-10-15: the drop no
        /// longer falls onto the new posts).
        case retracting(since: Double, fromTop: CGFloat, fromDiameter: CGFloat)
    }

    /// How the refresh's result is shown once it is known.
    private enum Reveal: Equatable {
        /// At once, without moving what is on screen: nothing new, the first post off screen, or the refresh detached.
        case plain
        /// New posts at the top: they slide in once the list rests at its edge.
        case slide(since: Double)
    }

    public private(set) var phase: Phase = .idle
    public private(set) var outcome: NewsRefreshOutcome?
    private var reveal: Reveal?
    /// When the hold's release began.
    private var releasedAt: Double?
    /// The release a slide waits on. It follows the finger while the finger is down (R:143).
    private var insertReleasedAt: Double?
    /// Set at the threshold, cleared once the finger lifts or the list is back at rest: a refresh needs a new pull, so a
    /// finger still held past the threshold after a finish does not start another (as `UIRefreshControl`).
    private var awaitsRelease = false

    public init() {
    }

    /// The refresh's result is known and not yet shown.
    public var isRevealPending: Bool {
        return self.reveal != nil
    }

    public mutating func step(now: Double, input: NewsRefreshInput) -> [NewsRefreshEvent] {
        let M = NewsRefreshMetrics.self
        var events: [NewsRefreshEvent] = []
        if self.awaitsRelease, !input.isDragging || input.gap <= 0.5 {
            self.awaitsRelease = false
        }
        switch self.phase {
        case .idle:
            if self.reveal == nil, !self.awaitsRelease, input.canPull, input.isDragging, input.gap >= M.threshold {
                self.awaitsRelease = true
                self.phase = .loading(since: now)
                self.outcome = nil
                self.releasedAt = nil
                self.insertReleasedAt = nil
                events.append(.begin)
            }
        case let .loading(since):
            if let outcome = self.outcome, now - since >= M.minLoading {
                self.beginRetract(now: now, pose: self.dropPose(now: now, input: input))
                if case let .posts(count) = outcome, count > 0, input.firstPostTop != nil {
                    self.reveal = .slide(since: now)
                } else {
                    self.reveal = .plain
                }
            }
        case .retracting:
            break
        }
        switch self.reveal {
        case .none:
            break
        case .plain:
            self.reveal = nil
            events.append(.insertRows(slides: false))
        case let .slide(since):
            if input.isDragging {
                self.insertReleasedAt = now
            }
            let settled = self.insertReleasedAt.map { now - $0 >= M.settleAfterRelease } ?? true
            let waitFrom = max(since, self.insertReleasedAt ?? since)
            if (input.atEdge && !input.isDragging && settled) || now - waitFrom > M.insertFallback {
                self.reveal = nil
                events.append(.insertRows(slides: input.atEdge))
            }
        }
        // A detached refresh retracts before its result is known, and stays retracting until it is.
        if case let .retracting(since, _, _) = self.phase, self.outcome != nil, now - since >= M.retractDuration {
            self.phase = .idle
        }
        return events
    }

    /// The fetch ended. Only the first report of a refresh counts.
    public mutating func fetchEnded(_ outcome: NewsRefreshOutcome) {
        guard self.outcome == nil else {
            return
        }
        switch self.phase {
        case .loading:
            self.outcome = outcome
        case .retracting:
            // Detached while loading: the result shows plainly.
            self.outcome = outcome
            self.reveal = .plain
        case .idle:
            break
        }
    }

    /// The tab changed or search opened while the refresh runs: the drop retracts, the refresh carries on, and its
    /// result shows without moving anything.
    public mutating func detach(now: Double, input: NewsRefreshInput) {
        if case .loading = self.phase {
            self.beginRetract(now: now, pose: self.dropPose(now: now, input: input))
        }
        if case .slide = self.reveal {
            self.reveal = .plain
        }
    }

    private mutating func beginRetract(now: Double, pose: NewsRefreshDropPose) {
        self.phase = .retracting(since: now, fromTop: pose.top, fromDiameter: pose.diameter)
        if self.releasedAt == nil {
            self.releasedAt = now
        }
        if self.insertReleasedAt == nil {
            self.insertReleasedAt = now
        }
    }

    /// The list's hold: `holdInset` from the threshold until the drop retracts, then a smoothstep back over 0.3 s.
    public func hold(now: Double) -> CGFloat {
        let M = NewsRefreshMetrics.self
        if case .loading = self.phase {
            return M.holdInset
        }
        guard let releasedAt = self.releasedAt else {
            if case .idle = self.phase {
                return 0.0
            }
            return M.holdInset
        }
        return M.holdInset * (1.0 - NewsRefreshCurves.smooth(NewsRefreshCurves.ramp(now - releasedAt, 0.0, M.releaseDuration)))
    }

    /// Whether anything moves: the drop is out, a refresh runs or retracts, its result waits, or the hold is releasing.
    public func isLive(now: Double, gap: CGFloat) -> Bool {
        if gap > 0.5 || self.reveal != nil || self.hold(now: now) > 0.0 {
            return true
        }
        switch self.phase {
        case .idle:
            return false
        case .loading:
            return true
        case let .retracting(since, _, _):
            return now - since < NewsRefreshMetrics.retractDuration
        }
    }
}
