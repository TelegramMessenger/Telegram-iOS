import Foundation
import CoreGraphics

/// What a refresh fetch brought. A failed refresh is `.nothing`: the feeds keep their items on a failure, so it looks
/// like an empty one, and both land the drop without an unfold (spec §1.5-1.6).
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
    /// The list's first row's top at rest, unpulled: the header's bottom (the search row's top).
    public var restingListTop: CGFloat
    /// The first row's live top, or nil when it is not on screen.
    public var firstPostTop: CGFloat?

    public init(gap: CGFloat, isDragging: Bool, atEdge: Bool, canPull: Bool, islandFrame: CGRect, restingListTop: CGFloat, firstPostTop: CGFloat?) {
        self.gap = gap
        self.isDragging = isDragging
        self.atEdge = atEdge
        self.canPull = canPull
        self.islandFrame = islandFrame
        self.restingListTop = restingListTop
        self.firstPostTop = firstPostTop
    }
}

public enum NewsRefreshEvent: Equatable {
    /// The threshold: a medium haptic at 0.9, start the fetch, hold the list.
    case begin
    /// The drop landed. `unfolds`: the posts unfold (a soft haptic at 0.45).
    case impact(unfolds: Bool)
    /// The refresh's result may be shown: its new posts go in under the landed drop, which shrinks and fades as their
    /// block comes in, or (`unfolded: false`) whatever it changed appears plainly, after a landing without posts or a
    /// retract.
    case insertRows(unfolded: Bool)
}

/// The pull-to-refresh drop as a function of time (spec §1). `step` advances it and returns what happened;
/// `hold` and `dropPose` read it.
public struct NewsRefreshModel {
    public enum Phase: Equatable {
        case idle
        case loading(since: Double)
        /// `angle`: the sticker's rock when loading ended, eased to 0 during the exit (ours).
        case finishing(since: Double, fallFromTop: CGFloat, angle: CGFloat)
        /// The drop shrinks back into the island. The posts are revealed plainly when they arrive (spec §1.7).
        case retracting(since: Double, fromTop: CGFloat, fromDiameter: CGFloat)
    }

    public struct Unfold: Equatable {
        public var since: Double
        /// The drop's frame at impact.
        public var from: CGRect
        public var count: Int
        public var inserted: Double?
    }

    public private(set) var phase: Phase = .idle
    public private(set) var unfold: Unfold?
    public private(set) var outcome: NewsRefreshOutcome?
    /// When the hold's release began.
    private var releasedAt: Double?
    /// The release that insertion waits on. It follows the finger while the finger is down (R:143).
    private var insertReleasedAt: Double?
    private var revealedAfterRetract = false
    /// Set at the threshold, cleared once the finger lifts or the list is back at rest: a refresh needs a new pull, so a
    /// finger still held past the threshold after a landing does not start another (as `UIRefreshControl`).
    private var awaitsRelease = false
    /// The first row's top when last seen: the fall's target while the row is briefly off screen.
    internal private(set) var lastFirstPostTop: CGFloat?

    public init() {
    }

    public mutating func step(now: Double, input: NewsRefreshInput) -> [NewsRefreshEvent] {
        let M = NewsRefreshMetrics.self
        var events: [NewsRefreshEvent] = []
        if let firstPostTop = input.firstPostTop {
            self.lastFirstPostTop = firstPostTop
        }
        if self.awaitsRelease, !input.isDragging || input.gap <= 0.5 {
            self.awaitsRelease = false
        }
        switch self.phase {
        case .idle:
            if self.unfold == nil, !self.awaitsRelease, input.canPull, input.isDragging, input.gap >= M.threshold {
                self.awaitsRelease = true
                self.phase = .loading(since: now)
                self.outcome = nil
                self.releasedAt = nil
                self.insertReleasedAt = nil
                events.append(.begin)
            }
        case let .loading(since):
            if self.outcome != nil, now - since >= M.minLoading {
                let pose = self.dropPose(now: now, input: input)
                // Nothing new: the drop goes back into the island rather than falling onto posts it has nothing to
                // add to (Added, usually). Likewise when the first post is off screen.
                if input.firstPostTop == nil || self.outcome == .nothing {
                    self.beginRetract(now: now, pose: pose)
                } else {
                    self.phase = .finishing(since: now, fallFromTop: pose.top, angle: pose.iconAngle)
                }
            }
        case let .finishing(since, _, _):
            let t = now - since
            if t >= M.handoff, self.releasedAt == nil {
                // Released at the handoff, even when the step comes late.
                self.releasedAt = since + M.handoff
                self.insertReleasedAt = since + M.handoff
            }
            if t >= M.fallStart + M.fallTime {
                let pose = self.dropPose(now: now, input: input)
                let from = CGRect(x: input.islandFrame.midX - M.dropSize * 0.5, y: input.islandFrame.maxY + pose.top, width: M.dropSize, height: M.dropSize)
                self.phase = .idle
                if case let .posts(count) = self.outcome, count > 0 {
                    self.unfold = Unfold(since: now, from: from, count: count, inserted: nil)
                    events.append(.impact(unfolds: true))
                } else {
                    events.append(.impact(unfolds: false))
                    events.append(.insertRows(unfolded: false))
                }
            }
        case let .retracting(since, _, _):
            if self.outcome != nil, !self.revealedAfterRetract {
                self.revealedAfterRetract = true
                events.append(.insertRows(unfolded: false))
            }
            if self.revealedAfterRetract, now - since >= M.retractDuration {
                self.phase = .idle
            }
        }
        if var unfold = self.unfold {
            if let inserted = unfold.inserted {
                if now - inserted > M.unfoldLinger {
                    self.unfold = nil
                }
            } else {
                if input.isDragging {
                    self.insertReleasedAt = now
                }
                let settled = self.insertReleasedAt.map { now - $0 >= M.settleAfterRelease } ?? true
                let waitFrom = max(unfold.since, self.insertReleasedAt ?? unfold.since)
                if (input.atEdge && !input.isDragging && settled) || now - waitFrom > M.insertFallback {
                    unfold.inserted = now
                    self.unfold = unfold
                    events.append(.insertRows(unfolded: true))
                }
            }
        }
        return events
    }

    /// The fetch ended. Only the first report of a refresh counts.
    public mutating func fetchEnded(_ outcome: NewsRefreshOutcome) {
        guard self.outcome == nil else {
            return
        }
        switch self.phase {
        case .loading, .retracting:
            self.outcome = outcome
        case .idle, .finishing:
            break
        }
    }

    /// The tab changed or search opened while the refresh runs: the drop retracts, and the refresh carries on.
    public mutating func detach(now: Double, input: NewsRefreshInput) {
        switch self.phase {
        case .loading, .finishing:
            self.beginRetract(now: now, pose: self.dropPose(now: now, input: input))
        case .idle, .retracting:
            break
        }
    }

    private mutating func beginRetract(now: Double, pose: NewsRefreshDropPose) {
        self.phase = .retracting(since: now, fromTop: pose.top, fromDiameter: pose.diameter)
        self.revealedAfterRetract = false
        if self.releasedAt == nil {
            self.releasedAt = now
        }
    }

    /// The list's hold: `holdInset` from the threshold until the release, then a smoothstep back over 0.3 s.
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

    /// Whether anything moves: the drop is out, a refresh runs, the landed drop rests or goes out, or the hold is
    /// releasing.
    public func isLive(now: Double, gap: CGFloat) -> Bool {
        if gap > 0.5 || self.unfold != nil || self.hold(now: now) > 0.0 {
            return true
        }
        switch self.phase {
        case .idle:
            return false
        case .loading, .finishing:
            return true
        case let .retracting(since, _, _):
            return now - since < NewsRefreshMetrics.retractDuration
        }
    }
}
