import Foundation
import SwiftSignalKit
import Postbox

public final class MessageReadMetricsTracker {
    public struct VisibleMessageEntry {
        public let messageId: EngineMessage.Id
        public let visibleTopPx: CGFloat
        public let visibleBottomPx: CGFloat
        public let postHeightPx: CGFloat
        public let viewportHeightPx: CGFloat

        public init(messageId: EngineMessage.Id, visibleTopPx: CGFloat, visibleBottomPx: CGFloat, postHeightPx: CGFloat, viewportHeightPx: CGFloat) {
            self.messageId = messageId
            self.visibleTopPx = visibleTopPx
            self.visibleBottomPx = visibleBottomPx
            self.postHeightPx = postHeightPx
            self.viewportHeightPx = viewportHeightPx
        }
    }

    private enum PhaseState {
        case graceStart
        case tracking
        case graceEnd
        case paused
    }

    private static let kGracePeriod: Double = 0.3
    private static let kMinViewTimeMs: Int = 300
    private static let kUserActivityTimeout: Double = 15.0
    private static let kMaxPhaseDuration: Double = 300.0
    private static let kHeartbeatInterval: Double = 0.1

    private struct TrackingPhase {
        let viewId: Int64
        let messageId: EngineMessage.Id
        var state: PhaseState

        var totalViewTimeMs: Int = 0
        var activeViewTimeMs: Int = 0
        var seenTopPx: CGFloat = CGFloat.greatestFiniteMagnitude
        var seenBottomPx: CGFloat = 0.0
        var postHeightPx: CGFloat = 0.0
        var viewportHeightPx: CGFloat = 0.0

        var lastTickTime: CFAbsoluteTime?
        let phaseStartTime: CFAbsoluteTime
        var graceTimer: SwiftSignalKit.Timer?
        var graceDeadline: CFAbsoluteTime?

        var stateBeforePause: PhaseState?
        var graceRemainingAtPause: Double?

        init(messageId: EngineMessage.Id) {
            self.viewId = Int64.random(in: Int64.min ... Int64.max)
            self.messageId = messageId
            self.state = .graceStart
            let now = CFAbsoluteTimeGetCurrent()
            self.phaseStartTime = now
            self.lastTickTime = now
        }

        mutating func updateSeenRange(visibleTopPx: CGFloat, visibleBottomPx: CGFloat, postHeightPx: CGFloat, viewportHeightPx: CGFloat) {
            self.seenTopPx = min(self.seenTopPx, visibleTopPx)
            self.seenBottomPx = max(self.seenBottomPx, visibleBottomPx)
            self.postHeightPx = postHeightPx
            self.viewportHeightPx = viewportHeightPx
        }

        mutating func flushTime(now: CFAbsoluteTime, lastActivityTime: CFAbsoluteTime) {
            if let lastTick = self.lastTickTime {
                let deltaMs = Int((now - lastTick) * 1000.0)
                self.totalViewTimeMs += deltaMs
                if (now - lastActivityTime) < kUserActivityTimeout {
                    self.activeViewTimeMs += deltaMs
                }
            }
            self.lastTickTime = now
        }

        mutating func stopTicking(now: CFAbsoluteTime, lastActivityTime: CFAbsoluteTime) {
            if let lastTick = self.lastTickTime {
                let deltaMs = Int((now - lastTick) * 1000.0)
                self.totalViewTimeMs += deltaMs
                if (now - lastActivityTime) < kUserActivityTimeout {
                    self.activeViewTimeMs += deltaMs
                }
            }
            self.lastTickTime = nil
        }

        func buildMetric() -> TelegramMessageReadMetric? {
            guard self.totalViewTimeMs >= kMinViewTimeMs else {
                return nil
            }
            guard self.postHeightPx > 0.0 && self.viewportHeightPx > 0.0 else {
                return nil
            }
            let heightToViewportRatio = Double(self.postHeightPx / self.viewportHeightPx)
            var seenRangeRatio: Double = 0.0
            if self.seenBottomPx > self.seenTopPx {
                seenRangeRatio = min(1.0, max(0.0, Double((self.seenBottomPx - self.seenTopPx) / self.postHeightPx)))
            }
            return TelegramMessageReadMetric(
                id: self.viewId,
                messageId: self.messageId,
                timeInViewMs: self.totalViewTimeMs,
                activeTimeInViewMs: self.activeViewTimeMs,
                heightToViewportRatio: heightToViewportRatio,
                seenRangeRatio: seenRangeRatio
            )
        }
    }
    
    private let pipe = ValuePipe<TelegramMessageReadMetric>()
    public var completedMetrics: Signal<TelegramMessageReadMetric, NoError> {
        return self.pipe.signal()
    }

    private var phases: [EngineMessage.Id: TrackingPhase] = [:]
    private var isActive: Bool = true
    private var lastActivityTime: CFAbsoluteTime = CFAbsoluteTimeGetCurrent()
    private var heartbeatTimer: SwiftSignalKit.Timer?

    public init() {
    }

    deinit {
        self.heartbeatTimer?.invalidate()
        let now = CFAbsoluteTimeGetCurrent()
        for (_, phase) in self.phases {
            phase.graceTimer?.invalidate()
            var phase = phase
            if phase.state == .tracking || phase.state == .graceStart {
                phase.stopTicking(now: now, lastActivityTime: self.lastActivityTime)
            }
            if let metric = phase.buildMetric() {
                self.pipe.putNext(metric)
            }
        }
        self.phases.removeAll()
    }

    public func updateVisibleMessages(_ entries: [VisibleMessageEntry]) {
        assert(Queue.mainQueue().isCurrent())
        guard self.isActive else { return }

        let visibleIds = Set(entries.map { $0.messageId })

        var toDiscard: [EngineMessage.Id] = []
        var toBeginGraceEnd: [EngineMessage.Id] = []
        var toResumeGraceEnd: [EngineMessage.Id] = []
        for (messageId, phase) in self.phases {
            if !visibleIds.contains(messageId) {
                switch phase.state {
                case .graceStart:
                    toDiscard.append(messageId)
                case .tracking:
                    toBeginGraceEnd.append(messageId)
                case .graceEnd:
                    break
                case .paused:
                    switch phase.stateBeforePause {
                    case .graceStart, .none:
                        toDiscard.append(messageId)
                    case .tracking, .graceEnd:
                        toResumeGraceEnd.append(messageId)
                    case .paused:
                        break
                    }
                }
            }
        }
        for messageId in toDiscard {
            self.phases[messageId]?.graceTimer?.invalidate()
            self.phases.removeValue(forKey: messageId)
        }
        for messageId in toBeginGraceEnd {
            self.beginGraceEnd(messageId: messageId)
        }
        for messageId in toResumeGraceEnd {
            self.resumeGraceEnd(messageId: messageId)
        }

        for entry in entries {
            if var phase = self.phases[entry.messageId] {
                switch phase.state {
                case .graceStart, .tracking:
                    phase.updateSeenRange(
                        visibleTopPx: entry.visibleTopPx,
                        visibleBottomPx: entry.visibleBottomPx,
                        postHeightPx: entry.postHeightPx,
                        viewportHeightPx: entry.viewportHeightPx
                    )
                    self.phases[entry.messageId] = phase
                case .graceEnd:
                    phase.graceTimer?.invalidate()
                    phase.graceTimer = nil
                    phase.graceDeadline = nil
                    phase.state = .tracking
                    phase.lastTickTime = CFAbsoluteTimeGetCurrent()
                    phase.updateSeenRange(
                        visibleTopPx: entry.visibleTopPx,
                        visibleBottomPx: entry.visibleBottomPx,
                        postHeightPx: entry.postHeightPx,
                        viewportHeightPx: entry.viewportHeightPx
                    )
                    self.phases[entry.messageId] = phase
                    self.startHeartbeatIfNeeded()
                case .paused:
                    self.resumePausedPhase(messageId: entry.messageId, entry: entry)
                }
            } else {
                self.beginGraceStart(messageId: entry.messageId, entry: entry)
            }
        }
    }

    public func reportUserActivity() {
        assert(Queue.mainQueue().isCurrent())
        self.lastActivityTime = CFAbsoluteTimeGetCurrent()
    }

    public func setIsActive(_ isActive: Bool) {
        assert(Queue.mainQueue().isCurrent())
        guard self.isActive != isActive else { return }
        self.isActive = isActive

        if !isActive {
            let now = CFAbsoluteTimeGetCurrent()
            for (messageId, phase) in self.phases {
                var phase = phase
                switch phase.state {
                case .tracking:
                    phase.stopTicking(now: now, lastActivityTime: self.lastActivityTime)
                    phase.stateBeforePause = .tracking
                    phase.state = .paused
                    self.phases[messageId] = phase
                case .graceStart:
                    phase.stopTicking(now: now, lastActivityTime: self.lastActivityTime)
                    if let deadline = phase.graceDeadline {
                        phase.graceRemainingAtPause = max(0, deadline - now)
                    }
                    phase.graceTimer?.invalidate()
                    phase.graceTimer = nil
                    phase.graceDeadline = nil
                    phase.stateBeforePause = .graceStart
                    phase.state = .paused
                    self.phases[messageId] = phase
                case .graceEnd:
                    if let deadline = phase.graceDeadline {
                        phase.graceRemainingAtPause = max(0, deadline - now)
                    }
                    phase.graceTimer?.invalidate()
                    phase.graceTimer = nil
                    phase.graceDeadline = nil
                    phase.stateBeforePause = .graceEnd
                    phase.state = .paused
                    self.phases[messageId] = phase
                case .paused:
                    break
                }
            }
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
        }
    }

    private func startHeartbeatIfNeeded() {
        guard self.heartbeatTimer == nil else { return }
        let hasTrackingPhases = self.phases.values.contains(where: { $0.state == .tracking })
        guard hasTrackingPhases else { return }
        let timer = SwiftSignalKit.Timer(timeout: MessageReadMetricsTracker.kHeartbeatInterval, repeat: true, completion: { [weak self] in
            self?.heartbeatTick()
        }, queue: Queue.mainQueue())
        self.heartbeatTimer = timer
        timer.start()
    }

    private func stopHeartbeatIfIdle() {
        let hasTrackingPhases = self.phases.values.contains(where: { $0.state == .tracking })
        if !hasTrackingPhases {
            self.heartbeatTimer?.invalidate()
            self.heartbeatTimer = nil
        }
    }

    private func heartbeatTick() {
        let now = CFAbsoluteTimeGetCurrent()

        var toFinalize: [EngineMessage.Id] = []
        for (messageId, phase) in self.phases {
            guard phase.state == .tracking else { continue }

            var phase = phase
            phase.flushTime(now: now, lastActivityTime: self.lastActivityTime)

            if (now - phase.phaseStartTime) >= MessageReadMetricsTracker.kMaxPhaseDuration {
                toFinalize.append(messageId)
            }
            self.phases[messageId] = phase
        }

        for messageId in toFinalize {
            self.finalizePhase(messageId: messageId)
        }
    }

    private func beginGraceStart(messageId: EngineMessage.Id, entry: VisibleMessageEntry) {
        var phase = TrackingPhase(messageId: messageId)
        phase.updateSeenRange(
            visibleTopPx: entry.visibleTopPx,
            visibleBottomPx: entry.visibleBottomPx,
            postHeightPx: entry.postHeightPx,
            viewportHeightPx: entry.viewportHeightPx
        )
        let now = CFAbsoluteTimeGetCurrent()
        phase.graceDeadline = now + MessageReadMetricsTracker.kGracePeriod
        let timer = SwiftSignalKit.Timer(timeout: MessageReadMetricsTracker.kGracePeriod, repeat: false, completion: { [weak self] in
            self?.graceStartCompleted(messageId: messageId)
        }, queue: Queue.mainQueue())
        phase.graceTimer = timer
        self.phases[messageId] = phase
        timer.start()
    }

    private func graceStartCompleted(messageId: EngineMessage.Id) {
        guard var phase = self.phases[messageId], phase.state == .graceStart else { return }
        let now = CFAbsoluteTimeGetCurrent()
        phase.flushTime(now: now, lastActivityTime: self.lastActivityTime)
        phase.graceTimer = nil
        phase.graceDeadline = nil
        phase.state = .tracking
        self.phases[messageId] = phase
        self.startHeartbeatIfNeeded()
    }

    private func beginGraceEnd(messageId: EngineMessage.Id) {
        guard var phase = self.phases[messageId], phase.state == .tracking else { return }
        let now = CFAbsoluteTimeGetCurrent()
        phase.stopTicking(now: now, lastActivityTime: self.lastActivityTime)
        phase.state = .graceEnd
        phase.graceDeadline = now + MessageReadMetricsTracker.kGracePeriod
        let timer = SwiftSignalKit.Timer(timeout: MessageReadMetricsTracker.kGracePeriod, repeat: false, completion: { [weak self] in
            self?.graceEndCompleted(messageId: messageId)
        }, queue: Queue.mainQueue())
        phase.graceTimer = timer
        self.phases[messageId] = phase
        timer.start()
        self.stopHeartbeatIfIdle()
    }

    private func resumeGraceEnd(messageId: EngineMessage.Id) {
        guard var phase = self.phases[messageId], phase.state == .paused else { return }
        let now = CFAbsoluteTimeGetCurrent()
        let remaining: Double
        if phase.stateBeforePause == .graceEnd {
            remaining = phase.graceRemainingAtPause ?? MessageReadMetricsTracker.kGracePeriod
        } else {
            remaining = MessageReadMetricsTracker.kGracePeriod
        }
        phase.stateBeforePause = nil
        phase.graceRemainingAtPause = nil
        phase.state = .graceEnd
        phase.graceDeadline = now + remaining
        let timer = SwiftSignalKit.Timer(timeout: remaining, repeat: false, completion: { [weak self] in
            self?.graceEndCompleted(messageId: messageId)
        }, queue: Queue.mainQueue())
        phase.graceTimer = timer
        self.phases[messageId] = phase
        timer.start()
    }

    private func graceEndCompleted(messageId: EngineMessage.Id) {
        if let phase = self.phases[messageId], phase.state == .graceEnd {
            self.finalizePhase(messageId: messageId)
        }
    }

    private func resumePausedPhase(messageId: EngineMessage.Id, entry: VisibleMessageEntry) {
        guard var phase = self.phases[messageId], phase.state == .paused else { return }
        let now = CFAbsoluteTimeGetCurrent()

        if (now - phase.phaseStartTime) >= MessageReadMetricsTracker.kMaxPhaseDuration {
            self.finalizePhase(messageId: messageId)
            return
        }

        let resumeTo = phase.stateBeforePause ?? .tracking
        phase.stateBeforePause = nil

        switch resumeTo {
        case .tracking:
            phase.state = .tracking
            phase.lastTickTime = now
            phase.graceRemainingAtPause = nil
            phase.updateSeenRange(
                visibleTopPx: entry.visibleTopPx,
                visibleBottomPx: entry.visibleBottomPx,
                postHeightPx: entry.postHeightPx,
                viewportHeightPx: entry.viewportHeightPx
            )
            self.phases[messageId] = phase
            self.startHeartbeatIfNeeded()
        case .graceStart:
            let remaining = phase.graceRemainingAtPause ?? MessageReadMetricsTracker.kGracePeriod
            phase.graceRemainingAtPause = nil
            phase.state = .graceStart
            phase.lastTickTime = now
            phase.graceDeadline = now + remaining
            let timer = SwiftSignalKit.Timer(timeout: remaining, repeat: false, completion: { [weak self] in
                self?.graceStartCompleted(messageId: messageId)
            }, queue: Queue.mainQueue())
            phase.graceTimer = timer
            phase.updateSeenRange(
                visibleTopPx: entry.visibleTopPx,
                visibleBottomPx: entry.visibleBottomPx,
                postHeightPx: entry.postHeightPx,
                viewportHeightPx: entry.viewportHeightPx
            )
            self.phases[messageId] = phase
            timer.start()
        case .graceEnd:
            phase.graceRemainingAtPause = nil
            phase.state = .tracking
            phase.lastTickTime = now
            phase.updateSeenRange(
                visibleTopPx: entry.visibleTopPx,
                visibleBottomPx: entry.visibleBottomPx,
                postHeightPx: entry.postHeightPx,
                viewportHeightPx: entry.viewportHeightPx
            )
            self.phases[messageId] = phase
            self.startHeartbeatIfNeeded()
        case .paused:
            break
        }
    }

    private func finalizePhase(messageId: EngineMessage.Id) {
        guard let phase = self.phases.removeValue(forKey: messageId) else { return }
        phase.graceTimer?.invalidate()
        if let metric = phase.buildMetric() {
            self.pipe.putNext(metric)
        }
        self.stopHeartbeatIfIdle()
    }
}
