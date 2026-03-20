import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext
import UniversalMediaPlayer

final class MusicListenTracker {
    private let engine: TelegramEngine

    // Current listening session
    private var currentFileReference: FileMediaReference?
    private var currentItemStableId: AnyHashable?
    private var trackDuration: Double = 0

    // Position-based duration accumulation
    private var accumulatedDuration: Double = 0
    private var lastPosition: Double = 0
    private var lastGenerationTimestamp: Double = 0
    private var lastBaseRate: Double = 1.0
    private var lastSeekId: Int = 0
    private var isPlaying: Bool = false

    // Pause tracking
    private var pauseTimer: SwiftSignalKit.Timer?

    // Disposables
    private let reportDisposable = MetaDisposable()

    private static let pauseTimeoutSeconds: Double = 60.0

    init(engine: TelegramEngine) {
        self.engine = engine
    }

    deinit {
        self.pauseTimer?.invalidate()
        self.reportDisposable.dispose()
    }

    // MARK: - Public Interface

    /// Called by MediaManagerImpl with each music player state update.
    func update(with stateAndType: (Account, SharedMediaPlayerItemPlaybackStateOrLoading, MediaManagerPlayerType)?) {
        assert(Queue.mainQueue().isCurrent())
        guard let (_, stateOrLoading, type) = stateAndType, type == .music else {
            // Player closed or switched to non-music — report and clear
            self.reportAndReset()
            return
        }

        guard case let .state(state) = stateOrLoading else {
            return // loading state, ignore
        }

        let itemStableId = state.item.stableId

        // Detect track switch
        if let currentId = self.currentItemStableId, currentId != itemStableId {
            self.reportAndReset()
        }

        // Start new session if needed
        if self.currentItemStableId == nil {
            self.startSession(item: state.item, status: state.status)
        }

        // Update current item reference
        self.currentItemStableId = itemStableId

        // Process playback status
        self.processStatus(state.status)
    }

    /// Called when musicMediaPlayer is set to nil (player closed).
    func playerClosed() {
        assert(Queue.mainQueue().isCurrent())
        self.reportAndReset()
    }

    // MARK: - Session Management

    private func startSession(item: SharedMediaPlaylistItem, status: MediaPlayerStatus) {
        // Extract FileMediaReference from the playlist item
        guard let playbackData = item.playbackData,
              case let .telegramFile(fileReference, _, _) = playbackData.source else {
            return
        }

        self.currentFileReference = fileReference
        self.trackDuration = status.duration
        self.accumulatedDuration = 0
        self.lastPosition = status.timestamp
        self.lastGenerationTimestamp = status.generationTimestamp
        self.lastBaseRate = status.baseRate
        self.lastSeekId = status.seekId
        self.isPlaying = false
        self.pauseTimer?.invalidate()
        self.pauseTimer = nil
    }

    private func processStatus(_ status: MediaPlayerStatus) {
        let wasPlaying = self.isPlaying
        let nowPlaying: Bool

        switch status.status {
        case .playing:
            nowPlaying = true
        case let .buffering(_, whilePlaying, _, _):
            nowPlaying = whilePlaying
        case .paused:
            nowPlaying = false
        }

        // Accumulate duration if we were playing (and no seek occurred)
        let seekOccurred = status.seekId != self.lastSeekId
        if wasPlaying && !seekOccurred {
            let positionDelta = status.timestamp - self.lastPosition
            let wallDelta = status.generationTimestamp - self.lastGenerationTimestamp
            let maxExpected = wallDelta * max(self.lastBaseRate, 0.5) * 1.5

            if positionDelta > 0 && (wallDelta <= 0 || positionDelta <= maxExpected) {
                self.accumulatedDuration += positionDelta
            }
        }

        self.lastPosition = status.timestamp
        self.lastGenerationTimestamp = status.generationTimestamp
        self.lastBaseRate = status.baseRate
        self.lastSeekId = status.seekId
        self.trackDuration = status.duration

        // Handle play/pause transitions
        if nowPlaying && !wasPlaying {
            // Resumed playing
            self.pauseTimer?.invalidate()
            self.pauseTimer = nil
        } else if !nowPlaying && wasPlaying {
            // Just paused — start pause timer
            self.startPauseTimer()
        }

        self.isPlaying = nowPlaying
    }

    // MARK: - Pause Timer

    private func startPauseTimer() {
        self.pauseTimer?.invalidate()
        let timer = SwiftSignalKit.Timer(timeout: MusicListenTracker.pauseTimeoutSeconds, repeat: false, completion: { [weak self] in
            self?.pauseTimerFired()
        }, queue: Queue.mainQueue())
        self.pauseTimer = timer
        timer.start()
    }

    private func pauseTimerFired() {
        // Paused > 60s — report current session
        self.reportAndReset()
    }

    // MARK: - Reporting

    private func reportAndReset() {
        self.pauseTimer?.invalidate()
        self.pauseTimer = nil

        guard let fileReference = self.currentFileReference else {
            self.resetSession()
            return
        }

        let duration = self.accumulatedDuration
        let trackDuration = self.trackDuration

        if duration >= 3.0 && trackDuration > 0 {
            let reportedDuration = Int(duration)
            self.reportDisposable.set(
                self.engine.messages.reportMusicListened(file: fileReference, duration: reportedDuration).startStrict()
            )
        }

        self.resetSession()
    }

    private func resetSession() {
        self.currentFileReference = nil
        self.currentItemStableId = nil
        self.trackDuration = 0
        self.accumulatedDuration = 0
        self.lastPosition = 0
        self.lastGenerationTimestamp = 0
        self.lastBaseRate = 1.0
        self.lastSeekId = 0
        self.isPlaying = false
    }
}
