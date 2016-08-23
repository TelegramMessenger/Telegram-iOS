import Foundation
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore

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

private final class MediaPlayerContext {
    private let queue: Queue
    private let account: Account
    private let resource: MediaResource
    
    private var state: MediaPlayerState = .empty
    private var audioRenderer: MediaPlayerAudioRenderer?
    
    private var tickTimer: SwiftSignalKit.Timer?
    
    fileprivate var status = Promise<MediaPlayerStatus>()
    
    fileprivate var playerNode: MediaPlayerNode? {
        didSet {
            if let playerNode = self.playerNode {
                var controlTimebase: CMTimebase?
                
                switch self.state {
                    case let .paused(loadedState):
                        controlTimebase = loadedState.controlTimebase.timebase
                    case let .playing(loadedState):
                        controlTimebase = loadedState.controlTimebase.timebase
                    case .empty, .seeking:
                        break
                }
                if let controlTimebase = controlTimebase {
                    DispatchQueue.main.async {
                        playerNode.controlTimebase = controlTimebase
                    }
                }
            }
        }
    }
    
    init(queue: Queue, account: Account, resource: MediaResource) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.account = account
        self.resource = resource
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
                self.audioRenderer?.rate = 0.0
            } else {
                if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: 0.0) {
                    CMTimebaseSetRate(loadedState.controlTimebase.timebase, 0.0)
                }
            }
        }
        
        let frameSource = FFMpegMediaFrameSource(queue: self.queue, account: account, resource: resource)
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
        print("seekingCompleted at \(CMTimeGetSeconds(seekResult.timestamp))")
        
        assert(self.queue.isCurrent())
        
        guard case let .seeking(frameSource, _, _, action) = self.state else {
            assertionFailure()
            return
        }
        
        seekResult.buffers.audioBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        seekResult.buffers.videoBuffer?.statusUpdated = { [weak self] in
            self?.tick()
        }
        let controlTimebase: MediaPlayerControlTimebase
        
        if let _ = seekResult.buffers.audioBuffer {
            let renderer: MediaPlayerAudioRenderer
            if let currentRenderer = self.audioRenderer {
                renderer = currentRenderer
            } else {
                renderer = MediaPlayerAudioRenderer()
                self.audioRenderer = renderer
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
        
        let loadedState = MediaPlayerLoadedState(frameSource: frameSource, mediaBuffers: seekResult.buffers, controlTimebase: controlTimebase)
        
        if let audioRenderer = self.audioRenderer {
            let queue = self.queue
            audioRenderer.flushBuffers(at: seekResult.timestamp, completion: { [weak self] in
                queue.async { [weak self] in
                    if let strongSelf = self {
                        if let playerNode = strongSelf.playerNode {
                            let queue = strongSelf.queue
                            
                            DispatchQueue.main.async {
                                playerNode.reset()
                                playerNode.controlTimebase = controlTimebase.timebase
                                
                                queue.async { [weak self] in
                                    if let strongSelf = self {
                                        switch action {
                                            case .play:
                                                strongSelf.state = .playing(loadedState)
                                                strongSelf.audioRenderer?.start()
                                            case .pause:
                                                strongSelf.state = .paused(loadedState)
                                        }
                                        
                                        strongSelf.tick()
                                    }
                                }
                            }
                        } else {
                            switch action {
                                case .play:
                                    strongSelf.state = .playing(loadedState)
                                    strongSelf.audioRenderer?.start()
                                case .pause:
                                    strongSelf.state = .paused(loadedState)
                            }
                            
                            strongSelf.tick()
                        }
                    }
                }
            })
        } else {
            if let playerNode = self.playerNode {
                let queue = self.queue
                
                DispatchQueue.main.async {
                    playerNode.reset()
                    playerNode.controlTimebase = controlTimebase.timebase
                    
                    queue.async { [weak self] in
                        if let strongSelf = self {
                            switch action {
                                case .play:
                                    strongSelf.state = .playing(loadedState)
                                case .pause:
                                    strongSelf.state = .paused(loadedState)
                            }
                            
                            strongSelf.tick()
                        }
                    }
                }
            }
        }
    }
    
    fileprivate func play() {
        assert(self.queue.isCurrent())
        
        switch self.state {
            case .empty:
                self.seek(timestamp: 0.0, action: .play)
            case let .seeking(frameSource, timestamp, disposable, _):
                self.state = .seeking(frameSource: frameSource, timestamp: timestamp, disposable: disposable, action: .play)
            case let .paused(loadedState):
                self.state = .playing(loadedState)
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
            case .paused:
                break
            case let .playing(loadedState):
                self.state = .paused(loadedState)
                self.tick()
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
        print("tick at \(timestamp)")
        
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
            let nextTickDelay = max(0.0, fullUntil - timestamp)
            let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                self?.tick()
            }, queue: self.queue)
            self.tickTimer = tickTimer
            tickTimer.start()
            
            if case .playing = self.state {
                rate = 1.0
            } else {
                rate = 0.0
            }
        } else if let worstStatus = worstStatus, case let .finished(finishedAt) = worstStatus, finishedAt.isFinite {
            let nextTickDelay = max(0.0, finishedAt - timestamp)
            if nextTickDelay.isLessThanOrEqualTo(0.0) {
                rate = 0.0
            } else {
                let tickTimer = SwiftSignalKit.Timer(timeout: nextTickDelay, repeat: false, completion: { [weak self] in
                    self?.tick()
                }, queue: self.queue)
                self.tickTimer = tickTimer
                tickTimer.start()
                
                if case .playing = self.state {
                    rate = 1.0
                } else {
                    rate = 0.0
                }
            }
        } else {
            buffering = true
            rate = 0.0
        }
        
        if loadedState.controlTimebase.isAudio {
            self.audioRenderer?.rate = rate
        } else {
            if !CMTimebaseGetRate(loadedState.controlTimebase.timebase).isEqual(to: rate) {
                CMTimebaseSetRate(loadedState.controlTimebase.timebase, rate)
            }
        }
        
        if let playerNode = self.playerNode, let videoTrackFrameBuffer = loadedState.mediaBuffers.videoBuffer, videoTrackFrameBuffer.hasFrames {
            let queue = self.queue.queue
            playerNode.beginRequestingFrames(queue: queue, takeFrame: { [weak videoTrackFrameBuffer] in
                if let videoTrackFrameBuffer = videoTrackFrameBuffer {
                    return videoTrackFrameBuffer.takeFrame()
                } else {
                    return .noFrames
                }
            })
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
            playbackStatus = .buffering
        } else if rate.isEqual(to: 1.0) {
            playbackStatus = .playing
        } else {
            playbackStatus = .paused
        }
        let status = MediaPlayerStatus(duration: duration, timestamp: timestamp, status: playbackStatus)
        self.status.set(.single(status))
    }
}

enum MediaPlayerPlaybackStatus {
    case playing
    case paused
    case buffering
}

struct MediaPlayerStatus {
    let duration: Double
    let timestamp: Double
    let status: MediaPlayerPlaybackStatus
}

final class MediaPlayer {
    private let queue = Queue()
    private var contextRef: Unmanaged<MediaPlayerContext>?
    
    var status: Signal<MediaPlayerStatus, NoError> {
        return Signal { [weak self] subscriber in
            let disposable = MetaDisposable()
            
            if let strongSelf = self {
                strongSelf.queue.async {
                    if let context = strongSelf.contextRef?.takeUnretainedValue() {
                        disposable.set(context.status.get().start(next: { next in
                            subscriber.putNext(next)
                        }, error: { error in
                            subscriber.putError(error)
                        }, completed: {
                            subscriber.putCompletion()
                        }))
                    }
                }
            }
            
            return disposable
        }
    }
    
    init(account: Account, resource: MediaResource) {
        self.queue.async {
            let context = MediaPlayerContext(queue: self.queue, account: account, resource: resource)
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
    
    func seek(timestamp: Double) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.seek(timestamp: timestamp)
            }
        }
    }
    
    func attachPlayerNode(_ node: MediaPlayerNode) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                node.queue = self.queue
                context.playerNode = node
            }
        }
    }
}
