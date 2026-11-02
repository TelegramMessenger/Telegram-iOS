import Foundation

// When a playback's start steps happened, on the controller's clock.
public struct HLSStartTimeline: Equatable {
    // Every level's playlist was in, or known not to be on disk.
    public var started: Double?
    public var firstLoadIssued: Double?
    public var firstLoadCompleted: Double?
    public var firstAppendRequested: Double?
    public var firstAppendCompleted: Double?

    public init() {
    }
}

// What one playback was like, for the log: stalls, waits after seeks, and the time played at each level.
//
// Buffering while play is requested, after the first frame, is a stall, unless a seek came after the last moment of
// playing: then it is a seek wait. Buffering while paused is neither. An interval ends when playback plays or pauses.
public final class HLSPlaybackStats {
    public struct Summary: Equatable {
        public var stallCount: Int = 0
        public var stallTime: Double = 0.0
        public var seekWaitCount: Int = 0
        public var seekWaitTime: Double = 0.0
        public var playedTime: Double = 0.0
        public var secondsPerLevel: [Int: Double] = [:]
        public var levelSwitches: Int = 0
    }

    private enum Interval {
        case stall(start: Double)
        case seekWait(start: Double)
    }

    private var closed = Summary()
    private var hasFirstFrame = false
    private var isSeekPending = false
    private var interval: Interval?
    private var lastEventTime: Double?
    private var lastPlayhead: (level: Int?, isPlaying: Bool, now: Double)?

    public init() {
    }

    public func noteFirstFrame(now: Double) {
        self.hasFirstFrame = true
        self.lastEventTime = now
    }

    public func noteSeek(now: Double) {
        self.isSeekPending = true
        // A seek during a stall ends the stall; the buffering after it is the seek's.
        if case .stall = self.interval {
            self.closeInterval(now: now)
            self.openInterval(.seekWait(start: now))
        }
        self.lastEventTime = now
    }

    public func noteStatus(isBuffering: Bool, isPlayRequested: Bool, now: Double) {
        if isBuffering && isPlayRequested {
            if self.hasFirstFrame && self.interval == nil {
                self.openInterval(self.isSeekPending ? .seekWait(start: now) : .stall(start: now))
            }
        } else {
            self.closeInterval(now: now)
            if !isBuffering && isPlayRequested {
                self.isSeekPending = false
            }
        }
        self.lastEventTime = now
    }

    // The level under the playhead (nil when nothing is buffered there) and whether the clock moves.
    public func notePlayhead(level: Int?, isPlaying: Bool, now: Double) {
        if let lastPlayhead = self.lastPlayhead {
            if lastPlayhead.isPlaying && now > lastPlayhead.now {
                self.closed.playedTime += now - lastPlayhead.now
                if let level = lastPlayhead.level {
                    self.closed.secondsPerLevel[level, default: 0.0] += now - lastPlayhead.now
                }
            }
            if let previous = lastPlayhead.level, let level, previous != level {
                self.closed.levelSwitches += 1
            }
        }
        self.lastPlayhead = (level ?? self.lastPlayhead?.level, isPlaying, now)
        self.lastEventTime = now
    }

    // Includes an interval still open, up to the last event.
    public var summary: Summary {
        var result = self.closed
        if let interval = self.interval, let lastEventTime = self.lastEventTime {
            switch interval {
            case let .stall(start):
                result.stallTime += max(0.0, lastEventTime - start)
            case let .seekWait(start):
                result.seekWaitTime += max(0.0, lastEventTime - start)
            }
        }
        return result
    }

    private func openInterval(_ interval: Interval) {
        self.interval = interval
        switch interval {
        case .stall:
            self.closed.stallCount += 1
        case .seekWait:
            self.closed.seekWaitCount += 1
        }
    }

    private func closeInterval(now: Double) {
        guard let interval = self.interval else {
            return
        }
        self.interval = nil
        switch interval {
        case let .stall(start):
            self.closed.stallTime += max(0.0, now - start)
        case let .seekWait(start):
            self.closed.seekWaitTime += max(0.0, now - start)
        }
    }
}
