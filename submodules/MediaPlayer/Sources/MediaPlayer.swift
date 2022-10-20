import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import TelegramAudio

private let traceEvents = false

private struct MediaPlayerControlTimebase {
    let timebase: CMTimebase
    let isAudio: Bool
}

private enum MediaPlayerPlaybackAction {
    case play
    case pause
}

private final class MediaPlayerLoadedState {
    let frameSource: MediaFrameSource
    let mediaBuffers: MediaPlaybackBuffers
    let controlTimebase: MediaPlayerControlTimebase
    var extraVideoFrames: ([MediaTrackFrame], CMTime)?
    var lostAudioSession: Bool = false
    
    init(frameSource: MediaFrameSource, mediaBuffers: MediaPlaybackBuffers, controlTimebase: MediaPlayerControlTimebase) {
        self.frameSource = frameSource
        self.mediaBuffers = mediaBuffers
        self.controlTimebase = controlTimebase
    }
}

private struct MediaPlayerSeekState {
    let duration: Double
}

private enum MediaPlayerState {
    case empty
    case seeking(frameSource: MediaFrameSource, timestamp: Double, seekState: MediaPlayerSeekState?, disposable: Disposable, action: MediaPlayerPlaybackAction, enableSound: Bool)
    case paused(MediaPlayerLoadedState)
    case playing(MediaPlayerLoadedState)
}

public enum MediaPlayerActionAtEnd {
    case loop((() -> Void)?)
    case action(() -> Void)
    case loopDisablingSound(() -> Void)
    case stop
}

public enum MediaPlayerPlayOnceWithSoundActionAtEnd {
    case loop
    case loopDisablingSound
    case stop
    case repeatIfNeeded
}

public enum MediaPlayerSeek {
    case none
    case start
    case automatic
    case timecode(Double)
}

public enum MediaPlayerStreaming {
    case none
    case conservative
    case earlierStart
    
    public var enabled: Bool {
        if case .none = self {
            return false
        } else {
            return true
        }
    }
    
    public var parameters: (Double, Double, Double) {
        switch self {
            case .none, .conservative:
                return (1.0, 2.0, 3.0)
            case .earlierStart:
                return (1.0, 1.0, 2.0)
        }
    }
}

private final class MediaPlayerAudioRendererContext {
    let renderer: MediaPlayerAudioRenderer
    var requestedFrames = false
    
    init(renderer: MediaPlayerAudioRenderer) {
        self.renderer = renderer
    }
}

private final class MediaPlayerContext {
    private let queue: Queue
    private let audioSessionManager: ManagedAudioSession
    
    private let postbox: Postbox
    private let resourceReference: MediaResourceReference
    private let tempFilePath: String?
    private let streamable: MediaPlayerStreaming
    private let video: Bool
    private let preferSoftwareDecoding: Bool
    private var enableSound: Bool
    private var baseRate: Double
    private let fetchAutomatically: Bool
    private var playAndRecord: Bool
    private var ambient: Bool
    private var keepAudioSessionWhilePaused: Bool
    private var continuePlayingWithoutSoundOnLostAudioSession: Bool
    
    private var seekId: Int = 0
    
    private var state: MediaPlayerState = .empty
    private var audioRenderer: MediaPlayerAudioRendererContext?
    private var forceAudioToSpeaker = false
    fileprivate let videoRenderer: VideoPlayerProxy
    
    private var tickTimer: SwiftSignalKit.Timer?
    private var fadeTimer: SwiftSignalKit.Timer?
    
    private var lastStatusUpdateTimestamp: Double?
    private let playerStatus: Promise<MediaPlayerStatus>
    private let playerStatusValue = Atomic<MediaPlayerStatus?>(value: nil)
    private let audioLevelPipe: ValuePipe<Float>
    
    fileprivate var actionAtEnd: MediaPlayerActionAtEnd = .stop
    
    private var stoppedAtEnd = false
    
    init(queue: Queue, audioSessionManager: ManagedAudioSession, playerStatus: Promise<MediaPlayerStatus>, audioLevelPipe: ValuePipe<Float>, postbox: Postbox, resourceReference: MediaResourceReference, tempFilePath: String?, streamable: MediaPlayerStreaming, video: Bool, preferSoftwareDecoding: Bool, playAutomatically: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool, playAndRecord: Bool, ambient: Bool, keepAudioSessionWhilePaused: Bool, continuePlayingWithoutSoundOnLostAudioSession: Bool) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.audioSessionManager = audioSessionManager
        self.playerStatus = playerStatus
        self.audioLevelPipe = audioLevelPipe
        self.postbox = postbox
        self.resourceReference = resourceReference
        self.tempFilePath = tempFilePath
        self.streamable = streamable
        self.video = video
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
        self.playAndRecord = playAndRecord
        self.ambient = ambient
        self.keepAudioSessionWhilePaused = keepAudioSessionWhilePaused
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        
        self.videoRenderer = VideoPlayerProxy(queue: queue)
        
        self.videoRenderer.visibilityUpdated = { [weak self] value in
            assert(queue.isCurrent())
            
            if let strongSelf = self, !strongSelf.enableSound || strongSelf.continuePlayingWithoutSoundOnLostAudioSession {
                switch strongSelf.state {
                    case .empty:
                        if value && playAutomatically {
                            strongSelf.play()
                        }
                    case .paused:
                        if value {
                            strongSelf.play()
                        }
                    case .playing:
                        if !value {
                            strongSelf.pause(lostAudioSession: false)
                        }
                    case let .seeking(_, _, _, _, action, _):
                        switch action {
                            case .pause:
                                if value {
                                    strongSelf.play()
                                }
                            case .play:
                                if !value {
                                    strongSelf.pause(lostAudioSession: false)
                                }
                        }
                }
            }
        }
        
        self.videoRenderer.takeFrameAndQueue = (queue, { [weak self] in
            assert(queue.isCurrent())
            
            if let strongSelf = self {
                var maybeLoadedState: MediaPlayerLoadedState?
                
                switch strongSelf.state {
                    case .empty:
                        return .noFrames
                    case let .paused(state):
                        maybeLoadedState = state
                    case let .playing(state):
                        maybeLoadedState = state
                    case .seeking:
                        return .noFrames
                }
                
                if let loadedState = maybeLoadedState, let videoBuffer = loadedState.mediaBuffers.videoBuffer {
                    if let (extraVideoFrames, atTime) = loadedState.extraVideoFrames {
                        loadedState.extraVideoFrames = nil
                        return .restoreState(extraVideoFrames, atTime)
                    } else {
                        return videoBuffer.takeFrame()
                    }
                } else {
                    return .noFrames
                }
            } else {
                return .noFrames
            }
        })
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.fadeTimer?.invalidate()
        self.tickTimer?.invalidate()
        
        if case let .seeking(_, _, _, disposable, _, _) = self.state {
            disposable.dispose()
        }
    }
    
    fileprivate func seek(timestamp: Double) {
        assert(self.queue.isCurrent())
        
        let action: MediaPlayerPlaybackAction
        switch self.state {
            case .empty, .paused:
                action = .pause
            case .playing:
                action = .play
            case let .seeking(_, _, _, _, currentAction, _):
                action = currentAction
        }
        self.seek(timestamp: timestamp, action: action)
    }
    
    fileprivate func seek(timestamp: Double, action: MediaPlayerPlaybackAction) {
        assert(self.queue.isCurrent())
        
        var loadedState: MediaPlayerLoadedState?
        var seekState: MediaPlayerSeekState?
        switch self.state {
            case .empty:
                break
            case let .playing(currentLoadedState):
                loadedState = currentLoadedState
            case let .paused(currentLoadedState):
                loadedState = currentLoadedState
            case let .seeking(previousFrameSource, previousTimestamp, seekStateValue, previousDisposable, _, previousEnableSound):
                if previousTimestamp.isEqual(to: timestamp) && self.enableSound == previousEnableSound {
                    self.state = .seeking(frameSource: previousFrameSource, timestamp: previousTimestamp, seekState: seekStateValue, disposable: previousDisposable, action: action, enableSound: self.enableSound)
                    return
                } else {
                    seekState = seekStateValue
                    previousDisposable.dispose()
                }
        }
        
        self.tickTimer?.invalidate()
        var loadedDuration: Double?
        if let loadedState = loadedState {
            self.seekId += 1
            
            if loadedState.controlTimebase.isAudio {
                self.audioRenderer?.renderer.setRate(0.0)
            } else {
                if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: 0.0) {
                    CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate: 0.0)
                }
            }
            var duration: Double = 0.0
            if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer {
                duration = max(duration, CMTimeGetSeconds(videoTrackFrameBuffer.duration))
            }

            if let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer {
                duration = max(duration, CMTimeGetSeconds(audioTrackFrameBuffer.duration))
            }
            loadedDuration = duration
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: duration, dimensions: CGSize(), timestamp: min(max(timestamp, 0.0), duration), baseRate: self.baseRate, seekId: self.seekId, status: .buffering(initial: false, whilePlaying: action == .play, progress: 0.0, display: true), soundEnabled: self.enableSound)
            self.playerStatus.set(.single(status))
            let _ = self.playerStatusValue.swap(status)
        } else {
            let duration = seekState?.duration ?? 0.0
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: duration, dimensions: CGSize(), timestamp: min(max(timestamp, 0.0), duration), baseRate: self.baseRate, seekId: self.seekId, status: .buffering(initial: false, whilePlaying: action == .play, progress: 0.0, display: true), soundEnabled: self.enableSound)
            self.playerStatus.set(.single(status))
            let _ = self.playerStatusValue.swap(status)
        }
        
        let frameSource = FFMpegMediaFrameSource(queue: self.queue, postbox: self.postbox, resourceReference: self.resourceReference, tempFilePath: self.tempFilePath, streamable: self.streamable.enabled, video: self.video, preferSoftwareDecoding: self.preferSoftwareDecoding, fetchAutomatically: self.fetchAutomatically, stallDuration: self.streamable.parameters.0, lowWaterDuration: self.streamable.parameters.1, highWaterDuration: self.streamable.parameters.2)
        let disposable = MetaDisposable()
        let updatedSeekState: MediaPlayerSeekState?
        if let loadedDuration = loadedDuration {
            updatedSeekState = MediaPlayerSeekState(duration: loadedDuration)
        } else {
            updatedSeekState = seekState
        }
        self.state = .seeking(frameSource: frameSource, timestamp: timestamp, seekState: updatedSeekState, disposable: disposable, action: action, enableSound: self.enableSound)
        
        self.lastStatusUpdateTimestamp = nil
        
        let seekResult = frameSource.seek(timestamp: timestamp)
        |> deliverOn(self.queue)
        
        disposable.set(seekResult.start(next: { [weak self] seekResult in
            if let strongSelf = self {
                var result: MediaFrameSourceSeekResult?
                seekResult.with { object in
                    assert(strongSelf.queue.isCurrent())
                    result = object
                }
                if let result = result {
                    strongSelf.seekingCompleted(seekResult: result)
                } else {
                    assertionFailure()
                }
            }
        }, error: { _ in
        }))
    }
    
    fileprivate func seekingCompleted(seekResult: MediaFrameSourceSeekResult) {
        if traceEvents {
            print("seekingCompleted at \(CMTimeGetSeconds(seekResult.timestamp))")
        }
        
        assert(self.queue.isCurrent())
        
        guard case let .seeking(frameSource, _, _, _, action, _) = self.state else {
            assertionFailure()
            return
        }
        
        var buffers = seekResult.buffers
        if !self.enableSound {
            buffers = MediaPlaybackBuffers(audioBuffer: nil, videoBuffer: buffers.videoBuffer)
        }
        
        buffers.audioBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        buffers.videoBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        let controlTimebase: MediaPlayerControlTimebase
        
        if let _ = buffers.audioBuffer {
            let renderer: MediaPlayerAudioRenderer
            if let currentRenderer = self.audioRenderer, !currentRenderer.requestedFrames {
                renderer = currentRenderer.renderer
            } else {
                self.audioRenderer?.renderer.stop()
                self.audioRenderer = nil
                
                let queue = self.queue
                renderer = MediaPlayerAudioRenderer(audioSession: .manager(self.audioSessionManager), playAndRecord: self.playAndRecord, ambient: self.ambient, forceAudioToSpeaker: self.forceAudioToSpeaker, baseRate: self.baseRate, audioLevelPipe: self.audioLevelPipe, updatedRate: { [weak self] in
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.tick()
                        }
                    }
                }, audioPaused: { [weak self] in
                    queue.async {
                        if let strongSelf = self {
                            if strongSelf.enableSound {
                                if strongSelf.continuePlayingWithoutSoundOnLostAudioSession {
                                    strongSelf.continuePlayingWithoutSound()
                                } else {
                                    strongSelf.pause(lostAudioSession: true, faded: false)
                                }
                            } else {
                                strongSelf.seek(timestamp: 0.0, action: .play)
                            }
                        }
                    }
                })
                self.audioRenderer = MediaPlayerAudioRendererContext(renderer: renderer)
                renderer.start()
            }
            
            controlTimebase = MediaPlayerControlTimebase(timebase: renderer.audioTimebase, isAudio: true)
        } else {
            self.audioRenderer?.renderer.stop()
            self.audioRenderer = nil
            
            var timebase: CMTimebase?
            CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
            controlTimebase = MediaPlayerControlTimebase(timebase: timebase!, isAudio: false)
            CMTimebaseSetTime(timebase!, time: seekResult.timestamp)
        }
        
        let loadedState = MediaPlayerLoadedState(frameSource: frameSource, mediaBuffers: buffers, controlTimebase: controlTimebase)
        loadedState.extraVideoFrames = (seekResult.extraDecodedVideoFrames, seekResult.timestamp)
        
        if let audioRenderer = self.audioRenderer?.renderer {
            let queue = self.queue
            audioRenderer.flushBuffers(at: seekResult.timestamp, completion: { [weak self] in
                queue.async { [weak self] in
                    if let strongSelf = self {
                        switch action {
                            case .play:
                                strongSelf.state = .playing(loadedState)
                                strongSelf.audioRenderer?.renderer.start()
                            case .pause:
                                strongSelf.state = .paused(loadedState)
                        }
                        
                        strongSelf.lastStatusUpdateTimestamp = nil
                        strongSelf.tick()
                    }
                }
            })
        } else {
            switch action {
                case .play:
                    self.state = .playing(loadedState)
                case .pause:
                    self.state = .paused(loadedState)
            }
            
            self.lastStatusUpdateTimestamp = nil
            self.tick()
        }
    }
    
    fileprivate func play(faded: Bool = false) {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                self.stoppedAtEnd = false
                self.lastStatusUpdateTimestamp = nil
                if self.enableSound {
                    let queue = self.queue
                    let renderer = MediaPlayerAudioRenderer(audioSession: .manager(self.audioSessionManager), playAndRecord: self.playAndRecord, ambient: self.ambient, forceAudioToSpeaker: self.forceAudioToSpeaker, baseRate: self.baseRate, audioLevelPipe: self.audioLevelPipe, updatedRate: { [weak self] in
                        queue.async {
                            if let strongSelf = self {
                                strongSelf.tick()
                            }
                        }
                    }, audioPaused: { [weak self] in
                        queue.async {
                            if let strongSelf = self {
                                if strongSelf.enableSound {
                                    if strongSelf.continuePlayingWithoutSoundOnLostAudioSession {
                                        strongSelf.continuePlayingWithoutSound()
                                    } else {
                                        strongSelf.pause(lostAudioSession: true, faded: false)
                                    }
                                } else {
                                    strongSelf.seek(timestamp: 0.0, action: .play)
                                }
                            }
                        }
                    })
                    self.audioRenderer = MediaPlayerAudioRendererContext(renderer: renderer)
                    renderer.start()
                }
                self.seek(timestamp: 0.0, action: .play)
            case let .seeking(frameSource, timestamp, seekState, disposable, _, enableSound):
                self.stoppedAtEnd = false
                self.state = .seeking(frameSource: frameSource, timestamp: timestamp, seekState: seekState, disposable: disposable, action: .play, enableSound: enableSound)
                self.lastStatusUpdateTimestamp = nil
            case let .paused(loadedState):
                if faded && false {
                    self.fadeTimer?.invalidate()
                    
                    var volume: Double = 0.0
                    let fadeTimer = SwiftSignalKit.Timer(timeout: 0.025, repeat: true, completion: { [weak self] in
                        if let strongSelf = self {
                            volume += 0.1
                            if volume < 1.0 {
                                strongSelf.audioRenderer?.renderer.setVolume(volume)
                            } else {
                                strongSelf.audioRenderer?.renderer.setVolume(1.0)
                                strongSelf.fadeTimer?.invalidate()
                                strongSelf.fadeTimer = nil
                            }
                        }
                    }, queue: self.queue)
                    self.fadeTimer = fadeTimer
                    fadeTimer.start()
                }
                
                if loadedState.lostAudioSession && !self.stoppedAtEnd {
                    self.stoppedAtEnd = false
                    let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
                    self.seek(timestamp: timestamp, action: .play)
                } else {
                    self.lastStatusUpdateTimestamp = nil
                    if self.stoppedAtEnd {
                        self.stoppedAtEnd = false
                        self.seek(timestamp: 0.0, action: .play)
                    } else {
                        self.state = .playing(loadedState)
                        self.tick()
                    }
                }
            case .playing:
                self.stoppedAtEnd = false
        }
    }
    
    fileprivate func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start) {
        assert(self.queue.isCurrent())
        
        if !self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            self.enableSound = true
            self.playAndRecord = playAndRecord
            
            var loadedState: MediaPlayerLoadedState?
            switch self.state {
                case .empty:
                    break
                case let .playing(currentLoadedState):
                    loadedState = currentLoadedState
                case let .paused(currentLoadedState):
                    loadedState = currentLoadedState
                case let .seeking(_, timestamp, _, disposable, action, _):
                    self.state = .empty
                    disposable.dispose()
                    self.seek(timestamp: timestamp, action: action)
            }
            
            var timestamp: Double
            if case let .timecode(time) = seek {
                timestamp = time
            }
            else if let loadedState = loadedState, case .none = seek {
                timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
                if let duration = self.currentDuration() {
                    if timestamp > duration - 2.0 {
                        timestamp = 0.0
                    }
                }
            } else {
                timestamp = 0.0
            }
            self.seek(timestamp: timestamp, action: .play)
        } else {
            if case let .timecode(time) = seek {
                self.seek(timestamp: Double(time), action: .play)
            } else if case .playing = self.state {
            } else {
                self.play()
            }
        }
        
        self.stoppedAtEnd = false
    }
    
    fileprivate func continuePlayingWithoutSound() {
        if self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            
            var loadedState: MediaPlayerLoadedState?
            switch self.state {
                case .empty:
                    break
                case let .playing(currentLoadedState):
                    loadedState = currentLoadedState
                case let .paused(currentLoadedState):
                    loadedState = currentLoadedState
                case let .seeking(_, timestamp, _, disposable, action, _):
                    if self.enableSound {
                        self.state = .empty
                        disposable.dispose()
                        self.enableSound = false
                        self.seek(timestamp: timestamp, action: action)
                    }
            }
            
            if let loadedState = loadedState {
                self.enableSound = false
                self.playAndRecord = false
                
                var timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
                if let duration = self.currentDuration(), timestamp > duration - 2.0 {
                    timestamp = 0.0
                }
                self.seek(timestamp: timestamp, action: .play)
            }
        }
    }
    
    fileprivate func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        if self.continuePlayingWithoutSoundOnLostAudioSession != value {
            self.continuePlayingWithoutSoundOnLostAudioSession = value
        }
    }
    
    fileprivate func setBaseRate(_ baseRate: Double) {
        self.baseRate = baseRate
        self.lastStatusUpdateTimestamp = nil
        self.tick()
        self.audioRenderer?.renderer.setBaseRate(baseRate)
        
        if case .seeking = self.state, let status = self.playerStatusValue.with({ $0 }) {
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: status.duration, dimensions: status.dimensions, timestamp: status.timestamp, baseRate: self.baseRate, seekId: self.seekId, status: status.status, soundEnabled: status.soundEnabled)
            self.playerStatus.set(.single(status))
            let _ = self.playerStatusValue.swap(status)
        }
    }
    
    fileprivate func setForceAudioToSpeaker(_ value: Bool) {
        if self.forceAudioToSpeaker != value {
            self.forceAudioToSpeaker = value
            
            self.audioRenderer?.renderer.setForceAudioToSpeaker(value)
        }
    }
    
    fileprivate func setKeepAudioSessionWhilePaused(_ value: Bool) {
        if self.keepAudioSessionWhilePaused != value {
            self.keepAudioSessionWhilePaused = value
            
            var isPlaying = false
            switch self.state {
                case .playing:
                    isPlaying = true
                case let .seeking(_, _, _, _, action, _):
                    switch action {
                        case .play:
                            isPlaying = true
                        default:
                            break
                    }
                default:
                    break
            }
            if value && !isPlaying {
                self.audioRenderer?.renderer.stop()
            } else {
                self.audioRenderer?.renderer.start()
            }
        }
    }
    
    fileprivate func pause(lostAudioSession: Bool, faded: Bool = false) {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                break
            case let .seeking(frameSource, timestamp, seekState, disposable, _, enableSound):
                self.state = .seeking(frameSource: frameSource, timestamp: timestamp, seekState: seekState, disposable: disposable, action: .pause, enableSound: enableSound)
                self.lastStatusUpdateTimestamp = nil
            case let .paused(loadedState):
                if lostAudioSession {
                    loadedState.lostAudioSession = true
                }
            case let .playing(loadedState):
                if lostAudioSession {
                    loadedState.lostAudioSession = true
                }
                self.state = .paused(loadedState)
                self.lastStatusUpdateTimestamp = nil
                
                if faded && false {
                    self.fadeTimer?.invalidate()
                    
                    var volume: Double = 1.0
                    let fadeTimer = SwiftSignalKit.Timer(timeout: 0.025, repeat: true, completion: { [weak self] in
                        if let strongSelf = self {
                            volume -= 0.1
                            if volume > 0 {
                                strongSelf.audioRenderer?.renderer.setVolume(volume)
                            } else {
                                strongSelf.fadeTimer?.invalidate()
                                strongSelf.fadeTimer = nil
                                strongSelf.tick()
                            }
                        }
                    }, queue: self.queue)
                    self.fadeTimer = fadeTimer
                    fadeTimer.start()
                }
                
                self.tick()
        }
    }
    
    fileprivate func togglePlayPause(faded: Bool) {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                self.play(faded: false)
            case let .seeking(_, _, _, _, action, _):
                switch action {
                    case .play:
                        self.pause(lostAudioSession: false, faded: faded)
                    case .pause:
                        self.play(faded: faded)
                }
            case .paused:
                if !self.enableSound {
                    self.playOnceWithSound(playAndRecord: false, seek: .none)
                } else {
                    self.play(faded: faded)
                }
            case .playing:
                self.pause(lostAudioSession: false, faded: faded)
        }
    }
    
    private func currentDuration() -> Double? {
        var maybeLoadedState: MediaPlayerLoadedState?
        switch self.state {
            case let .paused(state):
                maybeLoadedState = state
            case let .playing(state):
                maybeLoadedState = state
            default:
                break
        }
        
        guard let loadedState = maybeLoadedState else {
            return nil
        }
        
        var duration: Double = 0.0
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer {
            duration = max(duration, CMTimeGetSeconds(videoTrackFrameBuffer.duration))
        }

        if let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer {
            duration = max(duration, CMTimeGetSeconds(audioTrackFrameBuffer.duration))
        }
        return duration
    }
    
    private func tick() {
        self.tickTimer?.invalidate()
        
        var maybeLoadedState: MediaPlayerLoadedState?
        
        switch self.state {
            case .empty:
                return
            case let .paused(state):
                maybeLoadedState = state
            case let .playing(state):
                maybeLoadedState = state
            case .seeking:
                return
        }
        
        guard let loadedState = maybeLoadedState else {
            return
        }
        
        let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
        if traceEvents {
            print("tick at \(timestamp)")
        }
        
        var duration: Double = 0.0
        var videoStatus: MediaTrackFrameBufferStatus?
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer {
            videoStatus = videoTrackFrameBuffer.status(at: timestamp)
            duration = max(duration, CMTimeGetSeconds(videoTrackFrameBuffer.duration))
        }
        
        var audioStatus: MediaTrackFrameBufferStatus?
        if let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer {
            audioStatus = audioTrackFrameBuffer.status(at: timestamp)
            duration = max(duration, CMTimeGetSeconds(audioTrackFrameBuffer.duration))
        }
        
        var performActionAtEndNow = false
        
        var worstStatus: MediaTrackFrameBufferStatus?
        for status in [videoStatus, audioStatus] {
            if let status = status {
                if let worst = worstStatus {
                    switch status {
                        case .buffering:
                            worstStatus = status
                        case let .full(currentFullUntil):
                            switch worst {
                                case .buffering:
                                    worstStatus = worst
                                case let .full(worstFullUntil):
                                    if currentFullUntil < worstFullUntil {
                                        worstStatus = status
                                    } else {
                                        worstStatus = worst
                                    }
                                case .finished:
                                    worstStatus = status
                            }
                        case let .finished(currentFinishedAt):
                            switch worst {
                                case .buffering, .full:
                                    worstStatus = worst
                                case let .finished(worstFinishedAt):
                                    if currentFinishedAt < worstFinishedAt {
                                        worstStatus = worst
                                    } else {
                                        worstStatus = status
                                    }
                            }
                    }
                } else {
                    worstStatus = status
                }
            }
        }
        
        var rate: Double
        var bufferingProgress: Float?
        
        if let worstStatus = worstStatus, case let .full(fullUntil) = worstStatus, fullUntil.isFinite {
            var playing = false
            if case .playing = self.state {
                playing = true
            } else if self.fadeTimer != nil {
                playing = true
            }
            if playing {
                rate = self.baseRate
                
                let nextTickDelay = max(0.0, fullUntil - timestamp) / self.baseRate
                let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                    self?.tick()
                }, queue: self.queue)
                self.tickTimer = tickTimer
                tickTimer.start()
            } else {
                rate = 0.0
            }
        } else if let worstStatus = worstStatus, case let .finished(finishedAt) = worstStatus, finishedAt.isFinite {
            let nextTickDelay = max(0.0, finishedAt - timestamp) / self.baseRate
            if nextTickDelay.isLessThanOrEqualTo(0.0) {
                rate = 0.0
                performActionAtEndNow = true
            } else {
                var playing = false
                if case .playing = self.state {
                    playing = true
                } else if self.fadeTimer != nil {
                    playing = true
                }
                if playing {
                    rate = self.baseRate
                    
                    let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                        self?.tick()
                    }, queue: self.queue)
                    self.tickTimer = tickTimer
                    tickTimer.start()
                } else {
                    rate = 0.0
                }
            }
        } else if case let .buffering(progress) = worstStatus {
            bufferingProgress = Float(progress)
            rate = 0.0
            //print("bufferingProgress = \(progress)")
            
            let tickTimer = SwiftSignalKit.Timer(timeout: 0.3, repeat: false, completion: { [weak self] in
                self?.tick()
            }, queue: self.queue)
            self.tickTimer = tickTimer
            tickTimer.start()
        } else {
            bufferingProgress = 0.0
            rate = 0.0
        }
        
        var reportRate = rate
        
        if loadedState.controlTimebase.isAudio {
            if !rate.isZero {
                self.audioRenderer?.renderer.start()
            }
            self.audioRenderer?.renderer.setRate(rate)
            if !rate.isZero, let audioRenderer = self.audioRenderer {
                let timebaseRate = CMTimebaseGetRate(audioRenderer.renderer.audioTimebase)
                if !timebaseRate.isEqual(to: rate) {
                    reportRate = timebaseRate
                }
            }
        } else {
            if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: rate) {
                CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate: rate)
            }
        }
        
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer, videoTrackFrameBuffer.hasFrames {
            self.videoRenderer.state = (loadedState.controlTimebase.timebase, true, videoTrackFrameBuffer.rotationAngle, videoTrackFrameBuffer.aspect)
        }
        
        if let audioRenderer = self.audioRenderer, let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer, audioTrackFrameBuffer.hasFrames {
            let queue = self.queue
            audioRenderer.requestedFrames = true
            audioRenderer.renderer.beginRequestingFrames(queue: queue.queue, takeFrame: { [weak audioTrackFrameBuffer] in
                assert(queue.isCurrent())
                if let audioTrackFrameBuffer = audioTrackFrameBuffer {
                    return audioTrackFrameBuffer.takeFrame()
                } else {
                    return .noFrames
                }
            })
        }
        
        var statusTimestamp = CACurrentMediaTime()
        let playbackStatus: MediaPlayerPlaybackStatus
        var isPlaying = false
        var isPaused = false
        if case .playing = self.state {
            isPlaying = true
        } else if case .paused = self.state {
            isPaused = true
        }
        if let bufferingProgress = bufferingProgress {
            playbackStatus = .buffering(initial: false, whilePlaying: isPlaying, progress: Float(bufferingProgress), display: true)
        } else if !rate.isZero {
            if isPaused && self.fadeTimer != nil {
                playbackStatus = .paused
            } else if reportRate.isZero {
                //playbackStatus = .buffering(initial: false, whilePlaying: true)
                playbackStatus = .playing
                statusTimestamp = 0.0
            } else {
                playbackStatus = .playing
            }
        } else {
            if performActionAtEndNow && !self.stoppedAtEnd, case .loop = self.actionAtEnd, isPlaying {
                playbackStatus = .playing
            } else {
                playbackStatus = .paused
            }
        }
        
        if self.lastStatusUpdateTimestamp == nil || self.lastStatusUpdateTimestamp! < statusTimestamp + 500 {
            lastStatusUpdateTimestamp = statusTimestamp
            var reportTimestamp = timestamp
            if case .seeking(_, timestamp, _, _, _, _) = self.state {
                reportTimestamp = timestamp
            }
            let status = MediaPlayerStatus(generationTimestamp: statusTimestamp, duration: duration, dimensions: CGSize(), timestamp: min(max(reportTimestamp, 0.0), duration), baseRate: self.baseRate, seekId: self.seekId, status: playbackStatus, soundEnabled: self.enableSound)
            self.playerStatus.set(.single(status))
            let _ = self.playerStatusValue.swap(status)
        }

        if performActionAtEndNow {
            if !self.stoppedAtEnd {
                switch self.actionAtEnd {
                    case let .loop(f):
                        self.stoppedAtEnd = false
                        self.seek(timestamp: 0.0, action: .play)
                        f?()
                    case .stop:
                        self.stoppedAtEnd = true
                        self.pause(lostAudioSession: false)
                    case let .action(f):
                        self.stoppedAtEnd = true
                        self.pause(lostAudioSession: false)
                        f()
                    case let .loopDisablingSound(f):
                        self.stoppedAtEnd = false
                        self.enableSound = false
                        self.seek(timestamp: 0.0, action: .play)
                        f()
                }
            }
        }
    }
}

public enum MediaPlayerPlaybackStatus: Equatable {
    case playing
    case paused
    case buffering(initial: Bool, whilePlaying: Bool, progress: Float, display: Bool)
    
    public static func ==(lhs: MediaPlayerPlaybackStatus, rhs: MediaPlayerPlaybackStatus) -> Bool {
        switch lhs {
            case .playing:
                if case .playing = rhs {
                    return true
                } else {
                    return false
                }
            case .paused:
                if case .paused = rhs {
                    return true
                } else {
                    return false
                }
            case let .buffering(initial, whilePlaying, progress, display):
                if case .buffering(initial, whilePlaying, progress, display) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

public struct MediaPlayerStatus: Equatable {
    public let generationTimestamp: Double
    public let duration: Double
    public let dimensions: CGSize
    public let timestamp: Double
    public let baseRate: Double
    public let seekId: Int
    public let status: MediaPlayerPlaybackStatus
    public let soundEnabled: Bool
    
    public init(generationTimestamp: Double, duration: Double, dimensions: CGSize, timestamp: Double, baseRate: Double, seekId: Int, status: MediaPlayerPlaybackStatus, soundEnabled: Bool) {
        self.generationTimestamp = generationTimestamp
        self.duration = duration
        self.dimensions = dimensions
        self.timestamp = timestamp
        self.baseRate = baseRate
        self.seekId = seekId
        self.status = status
        self.soundEnabled = soundEnabled
    }
}

public final class MediaPlayer {
    private let queue = Queue()
    private var contextRef: Unmanaged<MediaPlayerContext>?
    
    private let statusValue = Promise<MediaPlayerStatus>()
    
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    private let audioLevelPipe = ValuePipe<Float>()
    public var audioLevelEvents: Signal<Float, NoError> {
        return self.audioLevelPipe.signal()
    }
    
    public var actionAtEnd: MediaPlayerActionAtEnd = .stop {
        didSet {
            let value = self.actionAtEnd
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    context.actionAtEnd = value
                }
            }
        }
    }
    
    public init(audioSessionManager: ManagedAudioSession, postbox: Postbox, resourceReference: MediaResourceReference, tempFilePath: String? = nil, streamable: MediaPlayerStreaming, video: Bool, preferSoftwareDecoding: Bool, playAutomatically: Bool = false, enableSound: Bool, baseRate: Double = 1.0, fetchAutomatically: Bool, playAndRecord: Bool = false, ambient: Bool = false, keepAudioSessionWhilePaused: Bool = false, continuePlayingWithoutSoundOnLostAudioSession: Bool = false) {
        let audioLevelPipe = self.audioLevelPipe
        self.queue.async {
            let context = MediaPlayerContext(queue: self.queue, audioSessionManager: audioSessionManager, playerStatus: self.statusValue, audioLevelPipe: audioLevelPipe, postbox: postbox, resourceReference: resourceReference, tempFilePath: tempFilePath, streamable: streamable, video: video, preferSoftwareDecoding: preferSoftwareDecoding, playAutomatically: playAutomatically, enableSound: enableSound, baseRate: baseRate, fetchAutomatically: fetchAutomatically, playAndRecord: playAndRecord, ambient: ambient, keepAudioSessionWhilePaused: keepAudioSessionWhilePaused, continuePlayingWithoutSoundOnLostAudioSession: continuePlayingWithoutSoundOnLostAudioSession)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    public func play() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.play()
            }
        }
    }
    
    public func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
            }
        }
    }
    
    public func continuePlayingWithoutSound() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.continuePlayingWithoutSound()
            }
        }
    }
    
    public func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setContinuePlayingWithoutSoundOnLostAudioSession(value)
            }
        }
    }
    
    public func setForceAudioToSpeaker(_ value: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setForceAudioToSpeaker(value)
            }
        }
    }
    
    public func setKeepAudioSessionWhilePaused(_ value: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setKeepAudioSessionWhilePaused(value)
            }
        }
    }
    
    public func pause() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.pause(lostAudioSession: false)
            }
        }
    }
    
    public func togglePlayPause(faded: Bool = false) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePlayPause(faded: faded)
            }
        }
    }
    
    public func seek(timestamp: Double, play: Bool? = nil) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                if let play = play {
                    context.seek(timestamp: timestamp, action: play ? .play : .pause)
                } else {
                    context.seek(timestamp: timestamp)
                }
            }
        }
    }
    
    public func setBaseRate(_ baseRate: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setBaseRate(baseRate)
            }
        }
    }
    
    public func attachPlayerNode(_ node: MediaPlayerNode) {
        let nodeRef: Unmanaged<MediaPlayerNode> = Unmanaged.passRetained(node)
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.videoRenderer.attachNodeAndRelease(nodeRef)
            } else {
                Queue.mainQueue().async {
                    nodeRef.release()
                }
            }
        }
    }
}
