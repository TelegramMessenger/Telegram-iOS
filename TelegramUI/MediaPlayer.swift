import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import Postbox

private let traceEvents = false

private struct MediaPlayerControlTimebase {
    let timebase: CMTimebase
    let isAudio: Bool
}

private enum MediaPlayerPlaybackAction {
    case play
    case pause
}

private struct MediaPlayerLoadedState {
    fileprivate let frameSource: MediaFrameSource
    fileprivate let mediaBuffers: MediaPlaybackBuffers
    fileprivate let controlTimebase: MediaPlayerControlTimebase
}

private enum MediaPlayerState {
    case empty
    case seeking(frameSource: MediaFrameSource, timestamp: Double, disposable: Disposable, action: MediaPlayerPlaybackAction)
    case paused(MediaPlayerLoadedState)
    case playing(MediaPlayerLoadedState)
}

enum MediaPlayerActionAtEnd {
    case loop
    case action(() -> Void)
    case stop
}

private final class MediaPlayerContext {
    private let queue: Queue
    private let audioSessionManager: ManagedAudioSession
    private let postbox: Postbox
    private let resource: MediaResource
    private let streamable: Bool
    private let video: Bool
    private let preferSoftwareDecoding: Bool
    private var enableSound: Bool
    
    private var state: MediaPlayerState = .empty
    private var audioRenderer: MediaPlayerAudioRenderer?
    fileprivate let videoRenderer: VideoPlayerProxy
    
    private var tickTimer: SwiftSignalKit.Timer?
    
    private var lastStatusUpdateTimestamp: Double?
    private let playerStatus: ValuePromise<MediaPlayerStatus>
    
    fileprivate var actionAtEnd: MediaPlayerActionAtEnd = .stop
    
    init(queue: Queue, audioSessionManager: ManagedAudioSession, playerStatus: ValuePromise<MediaPlayerStatus>, postbox: Postbox, resource: MediaResource, streamable: Bool, video: Bool, preferSoftwareDecoding: Bool, enableSound: Bool) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.audioSessionManager = audioSessionManager
        self.playerStatus = playerStatus
        self.postbox = postbox
        self.resource = resource
        self.streamable = streamable
        self.video = video
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.enableSound = enableSound
        
        self.videoRenderer = VideoPlayerProxy(queue: queue)
        
        self.videoRenderer.visibilityUpdated = { [weak self] value in
            assert(queue.isCurrent())
            
            if let strongSelf = self {
                switch strongSelf.state {
                    case .empty:
                        if value {
                            strongSelf.play()
                        }
                    case .paused:
                        if value {
                            strongSelf.play()
                        }
                    case .playing:
                        if !value {
                            strongSelf.pause()
                        }
                    case let .seeking(_, _, _, action):
                        switch action {
                            case .pause:
                                if value {
                                    strongSelf.play()
                                }
                            case .play:
                                if !value {
                                    strongSelf.pause()
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
                    return videoBuffer.takeFrame()
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
        
        self.tickTimer?.invalidate()
        
        if case let .seeking(_, _, disposable, _) = self.state {
            disposable.dispose()
        }
    }
    
    fileprivate func seek(timestamp: Double) {
        let action: MediaPlayerPlaybackAction
        switch self.state {
            case .empty, .paused:
                action = .pause
            case .playing:
                action = .play
            case let .seeking(_, _, _, currentAction):
                action = currentAction
        }
        self.seek(timestamp: timestamp, action: action)
    }
    
    fileprivate func seek(timestamp: Double, action: MediaPlayerPlaybackAction) {
        assert(self.queue.isCurrent())
        
        var loadedState: MediaPlayerLoadedState?
        switch self.state {
            case .empty:
                break
            case let .playing(currentLoadedState):
                loadedState = currentLoadedState
            case let .paused(currentLoadedState):
                loadedState = currentLoadedState
            case let .seeking(previousFrameSource, previousTimestamp, previousDisposable, _):
                if previousTimestamp.isEqual(to: timestamp) {
                    self.state = .seeking(frameSource: previousFrameSource, timestamp: previousTimestamp, disposable: previousDisposable, action: action)
                    return
                } else {
                    previousDisposable.dispose()
                }
        }
        
        self.tickTimer?.invalidate()
        if let loadedState = loadedState {
            if loadedState.controlTimebase.isAudio {
                self.audioRenderer?.setRate(0.0)
            } else {
                if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: 0.0) {
                    CMTimebaseSetRate(loadedState.controlTimebase.timebase, 0.0)
                }
            }
            let timestamp = CMTimeGetSeconds(CMTimebaseGetTime(loadedState.controlTimebase.timebase))
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
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: duration, timestamp: min(max(timestamp, 0.0), duration), status: .buffering(whilePlaying: action == .play))
            self.playerStatus.set(status)
        } else {
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: 0.0, timestamp: 0.0, status: .buffering(whilePlaying: action == .play))
            self.playerStatus.set(status)
        }
        
        let frameSource = FFMpegMediaFrameSource(queue: self.queue, postbox: self.postbox, resource: self.resource, streamable: self.streamable, video: self.video, preferSoftwareDecoding: self.preferSoftwareDecoding)
        let disposable = MetaDisposable()
        self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: action)
        
        let seekResult = frameSource.seek(timestamp: timestamp) |> deliverOn(self.queue)
        
        disposable.set(seekResult.start(next: { [weak self] seekResult in
            if let strongSelf = self {
                strongSelf.seekingCompleted(seekResult: seekResult)
            }
        }, error: { _ in
        }))
    }
    
    fileprivate func seekingCompleted(seekResult: MediaFrameSourceSeekResult) {
        if traceEvents {
            print("seekingCompleted at \(CMTimeGetSeconds(seekResult.timestamp))")
        }
        
        assert(self.queue.isCurrent())
        
        guard case let .seeking(frameSource, _, _, action) = self.state else {
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
            if let currentRenderer = self.audioRenderer {
                renderer = currentRenderer
            } else {
                let queue = self.queue
                renderer = MediaPlayerAudioRenderer(audioSessionManager: self.audioSessionManager, audioPaused: { [weak self] in
                    queue.async {
                        if let strongSelf = self {
                            strongSelf.pause()
                        }
                    }
                })
                self.audioRenderer = renderer
                renderer.start()
            }
            
            controlTimebase = MediaPlayerControlTimebase(timebase: renderer.audioTimebase, isAudio: true)
        } else {
            self.audioRenderer?.stop()
            self.audioRenderer = nil
            
            var timebase: CMTimebase?
            CMTimebaseCreateWithMasterClock(nil, CMClockGetHostTimeClock(), &timebase)
            controlTimebase = MediaPlayerControlTimebase(timebase: timebase!, isAudio: false)
            CMTimebaseSetTime(timebase!, seekResult.timestamp)
        }
        
        let loadedState = MediaPlayerLoadedState(frameSource: frameSource, mediaBuffers: buffers, controlTimebase: controlTimebase)
        
        if let audioRenderer = self.audioRenderer {
            let queue = self.queue
            audioRenderer.flushBuffers(at: seekResult.timestamp, completion: { [weak self] in
                queue.async { [weak self] in
                    if let strongSelf = self {
                        switch action {
                            case .play:
                                strongSelf.state = .playing(loadedState)
                                strongSelf.audioRenderer?.start()
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
    
    fileprivate func play() {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                self.lastStatusUpdateTimestamp = nil
                self.seek(timestamp: 0.0, action: .play)
            case let .seeking(frameSource, timestamp, disposable, _):
                self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: .play)
                self.lastStatusUpdateTimestamp = nil
            case let .paused(loadedState):
                self.state = .playing(loadedState)
                self.lastStatusUpdateTimestamp = nil
                self.tick()
            case .playing:
                break
        }
    }
    
    fileprivate func pause() {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                break
            case let .seeking(frameSource, timestamp, disposable, _):
                self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: .pause)
                self.lastStatusUpdateTimestamp = nil
            case .paused:
                break
            case let .playing(loadedState):
                self.state = .paused(loadedState)
                self.lastStatusUpdateTimestamp = nil
                self.tick()
        }
    }
    
    fileprivate func togglePlayPause() {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                break
            case let .seeking(_, _, _, action):
                switch action {
                    case .play:
                        self.pause()
                    case .pause:
                        self.play()
                }
            case .paused:
                self.play()
            case .playing:
                self.pause()
        }
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
        
        let rate: Double
        var buffering = false
        
        if let worstStatus = worstStatus, case let .full(fullUntil) = worstStatus, fullUntil.isFinite {
            if case .playing = self.state {
                rate = 1.0
                
                let nextTickDelay = max(0.0, fullUntil - timestamp)
                let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                    self?.tick()
                }, queue: self.queue)
                self.tickTimer = tickTimer
                tickTimer.start()
            } else {
                rate = 0.0
            }
        } else if let worstStatus = worstStatus, case let .finished(finishedAt) = worstStatus, finishedAt.isFinite {
            let nextTickDelay = max(0.0, finishedAt - timestamp)
            if nextTickDelay.isLessThanOrEqualTo(0.0) {
                rate = 0.0
                performActionAtEndNow = true
            } else {
                if case .playing = self.state {
                    rate = 1.0
                    
                    let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                        self?.tick()
                    }, queue: self.queue)
                    self.tickTimer = tickTimer
                    tickTimer.start()
                } else {
                    rate = 0.0
                }
            }
        } else {
            buffering = true
            rate = 0.0
        }
        
        if loadedState.controlTimebase.isAudio {
            self.audioRenderer?.setRate(rate)
        } else {
            if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: rate) {
                CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate)
            }
        }
        
        if let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer, videoTrackFrameBuffer.hasFrames {
            self.videoRenderer.state = (loadedState.controlTimebase.timebase, true, videoTrackFrameBuffer.rotationAngle)
            /*let queue = self.queue.queue
            playerNode.beginRequestingFrames(queue: queue, takeFrame: { [weak videoTrackFrameBuffer] in
                if let videoTrackFrameBuffer = videoTrackFrameBuffer {
                    return videoTrackFrameBuffer.takeFrame()
                } else {
                    return .noFrames
                }
            })*/
        }
        
        if let audioRenderer = self.audioRenderer, let audioTrackFrameBuffer = loadedState.mediaBuffers.audioBuffer, audioTrackFrameBuffer.hasFrames {
            let queue = self.queue.queue
            audioRenderer.beginRequestingFrames(queue: queue, takeFrame: { [weak audioTrackFrameBuffer] in
                if let audioTrackFrameBuffer = audioTrackFrameBuffer {
                    return audioTrackFrameBuffer.takeFrame()
                } else {
                    return .noFrames
                }
            })
        }
        
        let playbackStatus: MediaPlayerPlaybackStatus
        if buffering {
            var whilePlaying = false
            if case .playing = self.state {
                whilePlaying = true
            }
            playbackStatus = .buffering(whilePlaying: whilePlaying)
        } else if rate.isEqual(to: 1.0) {
            playbackStatus = .playing
        } else {
            playbackStatus = .paused
        }
        let statusTimestamp = CACurrentMediaTime()
        if self.lastStatusUpdateTimestamp == nil || self.lastStatusUpdateTimestamp! < statusTimestamp + 500 {
            lastStatusUpdateTimestamp = statusTimestamp
            let status = MediaPlayerStatus(generationTimestamp: statusTimestamp, duration: duration, timestamp: min(max(timestamp, 0.0), duration), status: playbackStatus)
            self.playerStatus.set(status)
        }
        
        if performActionAtEndNow {
            switch self.actionAtEnd {
                case .loop:
                    self.seek(timestamp: 0.0, action: .play)
                case .stop:
                    self.pause()
                case let .action(f):
                    self.pause()
                    f()
            }
        }
    }
}

enum MediaPlayerPlaybackStatus: Equatable {
    case playing
    case paused
    case buffering(whilePlaying: Bool)
    
    static func ==(lhs: MediaPlayerPlaybackStatus, rhs: MediaPlayerPlaybackStatus) -> Bool {
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
            case let .buffering(whilePlaying):
                if case .buffering(whilePlaying) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
}

struct MediaPlayerStatus: Equatable {
    let generationTimestamp: Double
    let duration: Double
    let timestamp: Double
    let status: MediaPlayerPlaybackStatus
    
    static func ==(lhs: MediaPlayerStatus, rhs: MediaPlayerStatus) -> Bool {
        if !lhs.generationTimestamp.isEqual(to: rhs.generationTimestamp) {
            return false
        }
        if !lhs.duration.isEqual(to: rhs.duration) {
            return false
        }
        if !lhs.timestamp.isEqual(to: rhs.timestamp) {
            return false
        }
        if lhs.status != rhs.status {
            return false
        }
        return true
    }
}

final class MediaPlayer {
    private let queue = Queue()
    private var contextRef: Unmanaged<MediaPlayerContext>?
    
    private let statusValue = ValuePromise<MediaPlayerStatus>(MediaPlayerStatus(generationTimestamp: 0.0, duration: 0.0, timestamp: 0.0, status: .paused), ignoreRepeated: true)
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    var actionAtEnd: MediaPlayerActionAtEnd = .stop {
        didSet {
            let value = self.actionAtEnd
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    context.actionAtEnd = value
                }
            }
        }
    }
    
    init(audioSessionManager: ManagedAudioSession, postbox: Postbox, resource: MediaResource, streamable: Bool, video: Bool, preferSoftwareDecoding: Bool, enableSound: Bool) {
        self.queue.async {
            let context = MediaPlayerContext(queue: self.queue, audioSessionManager: audioSessionManager, playerStatus: self.statusValue, postbox: postbox, resource: resource, streamable: streamable, video: video, preferSoftwareDecoding: preferSoftwareDecoding, enableSound: enableSound)
            self.contextRef = Unmanaged.passRetained(context)
        }
    }
    
    deinit {
        let contextRef = self.contextRef
        self.queue.async {
            contextRef?.release()
        }
    }
    
    func play() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.play()
            }
        }
    }
    
    func pause() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.pause()
            }
        }
    }
    
    func togglePlayPause() {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePlayPause()
            }
        }
    }
    
    func seek(timestamp: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.seek(timestamp: timestamp)
            }
        }
    }
    
    func attachPlayerNode(_ node: MediaPlayerNode) {
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
