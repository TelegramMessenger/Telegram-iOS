import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import CoreMedia
import TelegramCore
import TelegramAudio

private struct ChunkMediaPlayerControlTimebase {
    let timebase: CMTimebase
    let isAudio: Bool
}

private enum ChunkMediaPlayerPlaybackAction {
    case play
    case pause
}

private final class ChunkMediaPlayerPartLoadedState {
    let part: ChunkMediaPlayerPart
    let frameSource: MediaFrameSource
    var mediaBuffersDisposable: Disposable?
    var mediaBuffers: MediaPlaybackBuffers?
    var extraVideoFrames: ([MediaTrackFrame], CMTime)?
    
    init(part: ChunkMediaPlayerPart, frameSource: MediaFrameSource, mediaBuffers: MediaPlaybackBuffers?) {
        self.part = part
        self.frameSource = frameSource
        self.mediaBuffers = mediaBuffers
    }
    
    deinit {
        self.mediaBuffersDisposable?.dispose()
    }
}

private final class ChunkMediaPlayerLoadedState {
    var partStates: [ChunkMediaPlayerPartLoadedState] = []
    var controlTimebase: ChunkMediaPlayerControlTimebase?
    var lostAudioSession: Bool = false
}

private struct ChunkMediaPlayerSeekState {
    let duration: Double
}

private enum ChunkMediaPlayerState {
    case paused
    case playing
}

public enum ChunkMediaPlayerActionAtEnd {
    case loop((() -> Void)?)
    case action(() -> Void)
    case loopDisablingSound(() -> Void)
    case stop
}

public enum ChunkMediaPlayerPlayOnceWithSoundActionAtEnd {
    case loop
    case loopDisablingSound
    case stop
    case repeatIfNeeded
}

public enum ChunkMediaPlayerStreaming {
    case none
    case conservative
    case earlierStart
    case story
    
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
            case .story:
                return (0.25, 0.5, 1.0)
        }
    }
    
    public var isSeekable: Bool {
        switch self {
        case .none, .conservative, .earlierStart:
            return true
        case .story:
            return false
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

public final class ChunkMediaPlayerPart {
    public struct Id: Hashable {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
    
    public let startTime: Double
    public let endTime: Double
    public let file: TempBoxFile
    public let clippedStartTime: Double?
    public let codecName: String?
    
    public var id: Id {
        return Id(rawValue: self.file.path)
    }
    
    public init(startTime: Double, clippedStartTime: Double? = nil, endTime: Double, file: TempBoxFile, codecName: String?) {
        self.startTime = startTime
        self.clippedStartTime = clippedStartTime
        self.endTime = endTime
        self.file = file
        self.codecName = codecName
    }
}

public final class ChunkMediaPlayerPartsState {
    public let duration: Double?
    public let parts: [ChunkMediaPlayerPart]
    
    public init(duration: Double?, parts: [ChunkMediaPlayerPart]) {
        self.duration = duration
        self.parts = parts
    }
}

private final class ChunkMediaPlayerContext {
    private let queue: Queue
    private let postbox: Postbox
    private let audioSessionManager: ManagedAudioSession
    
    private var partsState = ChunkMediaPlayerPartsState(duration: nil, parts: [])
    
    private let video: Bool
    private var enableSound: Bool
    private var baseRate: Double
    private var playAndRecord: Bool
    private var soundMuted: Bool
    private var ambient: Bool
    private var mixWithOthers: Bool
    private var keepAudioSessionWhilePaused: Bool
    private var continuePlayingWithoutSoundOnLostAudioSession: Bool
    private let isAudioVideoMessage: Bool
    private let onSeeked: () -> Void
    
    private var seekId: Int = 0
    private var initialSeekTimestamp: Double?
    private var notifySeeked: Bool = false
    
    private let loadedState: ChunkMediaPlayerLoadedState
    private var isSeeking: Bool = false
    private var state: ChunkMediaPlayerState = .paused
    private var audioRenderer: MediaPlayerAudioRendererContext?
    private var forceAudioToSpeaker = false
    fileprivate let videoRenderer: VideoPlayerProxy
    
    private var tickTimer: SwiftSignalKit.Timer?
    
    private var lastStatusUpdateTimestamp: Double?
    private let playerStatus: Promise<MediaPlayerStatus>
    private let playerStatusValue = Atomic<MediaPlayerStatus?>(value: nil)
    private let audioLevelPipe: ValuePipe<Float>
    
    fileprivate var actionAtEnd: ChunkMediaPlayerActionAtEnd = .stop
    
    private var stoppedAtEnd = false
    
    private var partsDisposable: Disposable?
    
    init(
        queue: Queue,
        postbox: Postbox,
        audioSessionManager: ManagedAudioSession,
        playerStatus: Promise<MediaPlayerStatus>,
        audioLevelPipe: ValuePipe<Float>,
        partsState: Signal<ChunkMediaPlayerPartsState, NoError>,
        video: Bool,
        playAutomatically: Bool,
        enableSound: Bool,
        baseRate: Double,
        playAndRecord: Bool,
        soundMuted: Bool,
        ambient: Bool,
        mixWithOthers: Bool,
        keepAudioSessionWhilePaused: Bool,
        continuePlayingWithoutSoundOnLostAudioSession: Bool,
        isAudioVideoMessage: Bool,
        onSeeked: @escaping () -> Void
    ) {
        assert(queue.isCurrent())
        
        self.queue = queue
        self.postbox = postbox
        self.audioSessionManager = audioSessionManager
        self.playerStatus = playerStatus
        self.audioLevelPipe = audioLevelPipe
        self.video = video
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.playAndRecord = playAndRecord
        self.soundMuted = soundMuted
        self.ambient = ambient
        self.mixWithOthers = mixWithOthers
        self.keepAudioSessionWhilePaused = keepAudioSessionWhilePaused
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        self.isAudioVideoMessage = isAudioVideoMessage
        self.onSeeked = onSeeked
        
        self.videoRenderer = VideoPlayerProxy(queue: queue)
        
        self.loadedState = ChunkMediaPlayerLoadedState()
        
        let queue = self.queue
        self.videoRenderer.visibilityUpdated = { [weak self] value in
            assert(queue.isCurrent())
            
            if let strongSelf = self, !strongSelf.enableSound || strongSelf.continuePlayingWithoutSoundOnLostAudioSession {
                switch strongSelf.state {
                case .paused:
                    if value {
                        strongSelf.play()
                    }
                case .playing:
                    if !value {
                        strongSelf.pause(lostAudioSession: false)
                    }
                }
            }
        }
        
        self.videoRenderer.takeFrameAndQueue = (queue, { [weak self] in
            assert(queue.isCurrent())
            
            guard let self else {
                return .noFrames
            }
            
            var ignoreEmptyExtraFrames = false
            for i in 0 ..< self.loadedState.partStates.count {
                let partState = self.loadedState.partStates[i]
                
                if let (extraVideoFrames, atTime) = partState.extraVideoFrames {
                    partState.extraVideoFrames = nil
                    
                    if extraVideoFrames.isEmpty {
                        if !ignoreEmptyExtraFrames {
                            return .restoreState(frames: extraVideoFrames, atTimestamp: atTime, soft: i != 0)
                        }
                    } else {
                        return .restoreState(frames: extraVideoFrames, atTimestamp: atTime, soft: i != 0)
                    }
                }
                
                if let videoBuffer = partState.mediaBuffers?.videoBuffer {
                    let frame = videoBuffer.takeFrame()
                    switch frame {
                    case .finished:
                        ignoreEmptyExtraFrames = true
                        continue
                    default:
                        if ignoreEmptyExtraFrames, case let .frame(mediaTrackFrame) = frame {
                            return .restoreState(frames: [mediaTrackFrame], atTimestamp: mediaTrackFrame.position, soft: i != 0)
                        }
                        
                        return frame
                    }
                }
            }
            
            return .noFrames
        })
        
        let tickTimer = SwiftSignalKit.Timer(timeout: 1.0 / 25.0, repeat: true, completion: { [weak self] in
            self?.tick()
        }, queue: self.queue)
        self.tickTimer = tickTimer
        tickTimer.start()
        
        self.partsDisposable = (partsState |> deliverOn(self.queue)).startStrict(next: { [weak self] partsState in
            guard let self else {
                return
            }
            self.partsState = partsState
            self.tick()
        })
        
        self.tick()
    }
    
    deinit {
        assert(self.queue.isCurrent())
        
        self.tickTimer?.invalidate()
        self.partsDisposable?.dispose()
    }
    
    fileprivate func seek(timestamp: Double, notify: Bool) {
        assert(self.queue.isCurrent())
        
        let action: ChunkMediaPlayerPlaybackAction
        switch self.state {
        case .paused:
            action = .pause
        case .playing:
            action = .play
        }
        self.seek(timestamp: timestamp, action: action, notify: notify)
    }
    
    fileprivate func seek(timestamp: Double, action: ChunkMediaPlayerPlaybackAction, notify: Bool) {
        assert(self.queue.isCurrent())
        
        self.isSeeking = true
        self.loadedState.partStates.removeAll()
        
        self.seekId += 1
        self.initialSeekTimestamp = timestamp
        self.notifySeeked = true
        
        switch action {
        case .play:
            self.state = .playing
        case .pause:
            self.state = .paused
        }
        
        self.videoRenderer.flush()
        
        if let audioRenderer = self.audioRenderer {
            let queue = self.queue
            audioRenderer.renderer.flushBuffers(at: CMTime(seconds: timestamp, preferredTimescale: 44100), completion: { [weak self] in
                queue.async {
                    guard let self else {
                        return
                    }
                    self.isSeeking = false
                    self.tick()
                }
            })
        } else {
            if let controlTimebase = self.loadedState.controlTimebase, !controlTimebase.isAudio {
                CMTimebaseSetTime(controlTimebase.timebase, time: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 44000))
            }
            
            self.isSeeking = false
            self.tick()
        }
    }
    
    fileprivate func play() {
        assert(self.queue.isCurrent())
        
        if case .paused = self.state {
            self.state = .playing
            self.stoppedAtEnd = false
            self.lastStatusUpdateTimestamp = nil
            
            if self.enableSound {
                self.audioRenderer?.renderer.start()
            }
            
            let timestamp: Double
            if let controlTimebase = self.loadedState.controlTimebase {
                timestamp = CMTimeGetSeconds(CMTimebaseGetTime(controlTimebase.timebase))
            } else {
                timestamp = self.initialSeekTimestamp ?? 0.0
            }
            
            self.seek(timestamp: timestamp, action: .play, notify: false)
        }
    }
    
    fileprivate func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start) {
        assert(self.queue.isCurrent())
        
        /*#if DEBUG
        var seek = seek
        if case .timecode = seek {
            seek = .timecode(830.83000000000004)
        }
        #endif*/
        
        if !self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            self.enableSound = true
            self.playAndRecord = playAndRecord
            
            var timestamp: Double
            if case let .timecode(time) = seek {
                timestamp = time
            } else if case .none = seek, let controlTimebase = self.loadedState.controlTimebase {
                timestamp = CMTimeGetSeconds(CMTimebaseGetTime(controlTimebase.timebase))
                if let duration = self.currentDuration(), duration != 0.0 {
                    if timestamp > duration - 2.0 {
                        timestamp = 0.0
                    }
                }
            } else {
                timestamp = 0.0
            }
            let _ = timestamp
            self.seek(timestamp: timestamp, action: .play, notify: true)
        } else {
            if case let .timecode(time) = seek {
                self.seek(timestamp: Double(time), action: .play, notify: true)
            } else if case .playing = self.state {
            } else {
                self.play()
            }
        }
        
        self.stoppedAtEnd = false
    }
    
    fileprivate func setSoundMuted(soundMuted: Bool) {
        self.soundMuted = soundMuted
        self.audioRenderer?.renderer.setSoundMuted(soundMuted: soundMuted)
    }
    
    fileprivate func continueWithOverridingAmbientMode(isAmbient: Bool) {
        if self.ambient != isAmbient {
            self.ambient = isAmbient
            self.audioRenderer?.renderer.reconfigureAudio(ambient: self.ambient)
        }
    }
    
    fileprivate func continuePlayingWithoutSound(seek: MediaPlayerSeek) {
        if self.enableSound {
            self.lastStatusUpdateTimestamp = nil
            
            if let controlTimebase = self.loadedState.controlTimebase {
                self.enableSound = false
                self.playAndRecord = false
                
                var timestamp: Double
                if case let .timecode(time) = seek {
                    timestamp = time
                } else if case .none = seek {
                    timestamp = CMTimeGetSeconds(CMTimebaseGetTime(controlTimebase.timebase))
                    if let duration = self.currentDuration(), duration != 0.0 {
                        if timestamp > duration - 2.0 {
                            timestamp = 0.0
                        }
                    }
                } else {
                    timestamp = 0.0
                }
                
                self.seek(timestamp: timestamp, action: .play, notify: true)
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
        
        if lostAudioSession {
            self.loadedState.lostAudioSession = true
        }
        switch self.state {
        case .paused:
            break
        case .playing:
            self.state = .paused
            self.lastStatusUpdateTimestamp = nil
            
            self.tick()
        }
    }
    
    fileprivate func togglePlayPause(faded: Bool) {
        assert(self.queue.isCurrent())
        
        switch self.state {
        case .paused:
            if !self.enableSound {
                self.playOnceWithSound(playAndRecord: false, seek: .none)
            } else {
                self.play()
            }
        case .playing:
            self.pause(lostAudioSession: false, faded: faded)
        }
    }
    
    private func currentDuration() -> Double? {
        return self.partsState.duration
    }
    
    private func tick() {
        if self.isSeeking {
            return
        }
        
        var timestamp: Double
        if let controlTimebase = self.loadedState.controlTimebase {
            timestamp = CMTimeGetSeconds(CMTimebaseGetTime(controlTimebase.timebase))
        } else {
            timestamp = self.initialSeekTimestamp ?? 0.0
        }
        timestamp = max(0.0, timestamp)
        
        var disableAudio = false
        if !self.enableSound {
            disableAudio = true
        }
        var hasAudio = false
        if let firstPart = self.loadedState.partStates.first, let mediaBuffers = firstPart.mediaBuffers, mediaBuffers.videoBuffer != nil {
            if mediaBuffers.audioBuffer != nil {
                hasAudio = true
            } else {
                disableAudio = true
            }
        }
        
        if disableAudio {
            var resetTimebase = false
            if self.audioRenderer != nil {
                self.audioRenderer?.renderer.stop()
                self.audioRenderer = nil
                resetTimebase = true
            }
            if self.loadedState.controlTimebase == nil {
                resetTimebase = true
            }
             
            if resetTimebase {
                var timebase: CMTimebase?
                CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
                let controlTimebase = ChunkMediaPlayerControlTimebase(timebase: timebase!, isAudio: false)
                CMTimebaseSetTime(timebase!, time: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 44000))
                
                self.loadedState.controlTimebase = controlTimebase
            }
        } else if hasAudio {
            if self.audioRenderer == nil {
                let queue = self.queue
                let audioRendererContext = MediaPlayerAudioRenderer(
                    audioSession: .manager(self.audioSessionManager),
                    forAudioVideoMessage: self.isAudioVideoMessage,
                    playAndRecord: self.playAndRecord,
                    soundMuted: self.soundMuted,
                    ambient: self.ambient,
                    mixWithOthers: self.mixWithOthers,
                    forceAudioToSpeaker: self.forceAudioToSpeaker,
                    baseRate: self.baseRate,
                    audioLevelPipe: self.audioLevelPipe,
                    updatedRate: { [weak self] in
                        queue.async {
                            guard let self else {
                                return
                            }
                            self.tick()
                        }
                    },
                    audioPaused: { [weak self] in
                        queue.async {
                            guard let self else {
                                return
                            }
                            if self.enableSound {
                                if self.continuePlayingWithoutSoundOnLostAudioSession {
                                    self.continuePlayingWithoutSound(seek: .start)
                                } else {
                                    self.pause(lostAudioSession: true, faded: false)
                                }
                            } else {
                                self.seek(timestamp: 0.0, action: .play, notify: true)
                            }
                        }
                    }
                )
                self.audioRenderer = MediaPlayerAudioRendererContext(renderer: audioRendererContext)
                
                self.loadedState.controlTimebase = ChunkMediaPlayerControlTimebase(timebase: audioRendererContext.audioTimebase, isAudio: true)
                audioRendererContext.flushBuffers(at: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 44000), completion: {})
                audioRendererContext.start()
            }
        }
        
        //print("Timestamp: \(timestamp)")
        
        var duration: Double = 0.0
        if let partsStateDuration = self.partsState.duration {
            duration = partsStateDuration
        }
        
        var validParts: [ChunkMediaPlayerPart] = []
        
        var minStartTime: Double = 0.0
        for i in 0 ..< self.partsState.parts.count {
            let part = self.partsState.parts[i]
            
            let partStartTime = max(minStartTime, part.startTime)
            let partEndTime = max(partStartTime, part.endTime)
            if partStartTime >= partEndTime {
                continue
            }
            
            var partMatches = false
            if timestamp >= partStartTime - 0.5 && timestamp < partEndTime + 0.5 {
                partMatches = true
            }
            
            if partMatches {
                validParts.append(ChunkMediaPlayerPart(
                    startTime: part.startTime,
                    clippedStartTime: partStartTime == part.startTime ? nil : partStartTime,
                    endTime: part.endTime,
                    file: part.file,
                    codecName: part.codecName
                ))
                minStartTime = max(minStartTime, partEndTime)
            }
        }
        
        if let lastValidPart = validParts.last {
            for i in 0 ..< self.partsState.parts.count {
                let part = self.partsState.parts[i]
                
                let partStartTime = max(minStartTime, part.startTime)
                let partEndTime = max(partStartTime, part.endTime)
                if partStartTime >= partEndTime {
                    continue
                }
                
                if lastValidPart !== part && partStartTime > (lastValidPart.clippedStartTime ?? lastValidPart.startTime) && partStartTime <= lastValidPart.endTime + 0.5 {
                    validParts.append(ChunkMediaPlayerPart(
                        startTime: part.startTime,
                        clippedStartTime: partStartTime == part.startTime ? nil : partStartTime,
                        endTime: part.endTime,
                        file: part.file,
                        codecName: part.codecName
                    ))
                    minStartTime = max(minStartTime, partEndTime)
                    break
                }
            }
        }
        
        if validParts.isEmpty, let initialSeekTimestamp = self.initialSeekTimestamp {
            for part in self.partsState.parts {
                if initialSeekTimestamp >= part.startTime - 0.2 && initialSeekTimestamp < part.endTime {
                    self.initialSeekTimestamp = nil
                    
                    self.videoRenderer.flush()
                    
                    if let audioRenderer = self.audioRenderer {
                        self.isSeeking = true
                        let queue = self.queue
                        audioRenderer.renderer.flushBuffers(at: CMTime(seconds: part.startTime + 0.1, preferredTimescale: 44100), completion: { [weak self] in
                            queue.async {
                                guard let self else {
                                    return
                                }
                                self.isSeeking = false
                                self.tick()
                            }
                        })
                    }
                    
                    return
                }
            }
        } else {
            self.initialSeekTimestamp = nil
        }
        
        //print("validParts: \(validParts.map { "\($0.startTime) ... \($0.endTime)" })")
        
        self.loadedState.partStates.removeAll(where: { partState in
            if !validParts.contains(where: { $0.id == partState.part.id }) {
                return true
            }
            return false
        })
        
        for part in validParts {
            if !self.loadedState.partStates.contains(where: { $0.part.id == part.id }) {
                let frameSource = FFMpegMediaFrameSource(
                    queue: self.queue,
                    postbox: self.postbox,
                    userLocation: .other,
                    userContentType: .other,
                    resourceReference: .standalone(resource: LocalFileReferenceMediaResource(localFilePath: "", randomId: 0)),
                    tempFilePath: part.file.path,
                    limitedFileRange: nil,
                    streamable: false,
                    isSeekable: true,
                    video: self.video,
                    preferSoftwareDecoding: false,
                    fetchAutomatically: false,
                    stallDuration: 1.0,
                    lowWaterDuration: 2.0,
                    highWaterDuration: 3.0,
                    storeAfterDownload: nil
                )
                
                let partState = ChunkMediaPlayerPartLoadedState(
                    part: part,
                    frameSource: frameSource,
                    mediaBuffers: nil
                )
                self.loadedState.partStates.append(partState)
                self.loadedState.partStates.sort(by: { $0.part.startTime < $1.part.startTime })
            }
        }
        
        for i in 0 ..< self.loadedState.partStates.count {
            let partState = self.loadedState.partStates[i]
            if partState.mediaBuffersDisposable == nil {
                let partSeekOffset: Double
                if let clippedStartTime = partState.part.clippedStartTime {
                    partSeekOffset = clippedStartTime - partState.part.startTime
                } else {
                    partSeekOffset = 0.0
                }
                partState.mediaBuffersDisposable = (partState.frameSource.seek(timestamp: i == 0 ? timestamp : partSeekOffset)
                |> deliverOn(self.queue)).startStrict(next: { [weak self, weak partState] result in
                    guard let self, let partState else {
                        return
                    }
                    guard let result = result.unsafeGet() else {
                        return
                    }
                    
                    partState.mediaBuffers = result.buffers
                    partState.extraVideoFrames = (result.extraDecodedVideoFrames, result.timestamp)
                    
                    if partState === self.loadedState.partStates.first {
                        self.audioRenderer?.renderer.flushBuffers(at: result.timestamp, completion: {})
                    }
                    
                    let queue = self.queue
                    result.buffers.audioBuffer?.statusUpdated = { [weak self] in
                        queue.async {
                            guard let self else {
                                return
                            }
                            self.tick()
                        }
                    }
                    result.buffers.videoBuffer?.statusUpdated = { [weak self] in
                        queue.async {
                            guard let self else {
                                return
                            }
                            self.tick()
                        }
                    }
                    
                    self.tick()
                })
            }
        }
        
        var videoStatus: MediaTrackFrameBufferStatus?
        var audioStatus: MediaTrackFrameBufferStatus?
        
        for i in 0 ..< self.loadedState.partStates.count {
            let partState = self.loadedState.partStates[i]
            
            var partVideoStatus: MediaTrackFrameBufferStatus?
            var partAudioStatus: MediaTrackFrameBufferStatus?
            if let videoTrackFrameBuffer = partState.mediaBuffers?.videoBuffer {
                partVideoStatus = videoTrackFrameBuffer.status(at: i == 0 ? timestamp : videoTrackFrameBuffer.startTime.seconds)
            }
            if let audioTrackFrameBuffer = partState.mediaBuffers?.audioBuffer {
                partAudioStatus = audioTrackFrameBuffer.status(at: i == 0 ? timestamp : audioTrackFrameBuffer.startTime.seconds)
            }
            if i == 0 {
                videoStatus = partVideoStatus
                audioStatus = partAudioStatus
            }
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
            }
            if playing {
                rate = self.baseRate
            } else {
                rate = 0.0
            }
        } else if let worstStatus = worstStatus, case let .finished(finishedAt) = worstStatus, finishedAt.isFinite {
            var playing = false
            if case .playing = self.state {
                playing = true
            }
            if playing {
                rate = self.baseRate
            } else {
                rate = 0.0
            }
            
            //print("finished timestamp: \(timestamp), finishedAt: \(finishedAt), duration: \(duration)")
            if duration > 0.0 && timestamp >= finishedAt && finishedAt >= duration - 0.2 {
                performActionAtEndNow = true
            }
        } else if case .buffering = worstStatus {
            bufferingProgress = 0.0
            rate = 0.0
        } else {
            rate = 0.0
            bufferingProgress = 0.0
        }
        
        if rate != 0.0 && self.initialSeekTimestamp != nil {
            self.initialSeekTimestamp = nil
        }
        
        if duration > 0.0 && timestamp >= duration {
            performActionAtEndNow = true
        }
        
        var reportRate = rate
        
        if let controlTimebase = self.loadedState.controlTimebase {
            if controlTimebase.isAudio {
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
                if !CMTimebaseGetRate(controlTimebase.timebase).isEqual(to: rate) {
                    CMTimebaseSetRate(controlTimebase.timebase, rate: rate)
                }
            }
        }
        
        if let controlTimebase = self.loadedState.controlTimebase, let videoTrackFrameBuffer = self.loadedState.partStates.first?.mediaBuffers?.videoBuffer, videoTrackFrameBuffer.hasFrames {
            self.videoRenderer.state = (controlTimebase.timebase, true, videoTrackFrameBuffer.rotationAngle, videoTrackFrameBuffer.aspect)
        }
        
        if let audioRenderer = self.audioRenderer {
            let queue = self.queue
            audioRenderer.requestedFrames = true
            audioRenderer.renderer.beginRequestingFrames(queue: queue.queue, takeFrame: { [weak self] in
                assert(queue.isCurrent())
                guard let self else {
                    return .noFrames
                }
                
                for partState in self.loadedState.partStates {
                    if let audioTrackFrameBuffer = partState.mediaBuffers?.audioBuffer {
                        //print("Poll audio: part \(partState.part.startTime) frames: \(audioTrackFrameBuffer.frames.map(\.pts.seconds))")
                        let frame = audioTrackFrameBuffer.takeFrame()
                        switch frame {
                        case .finished:
                            continue
                        default:
                            /*if case let .frame(frame) = frame {
                                print("audio: \(frame.position.seconds) \(frame.position.value) part \(partState.part.startTime) next: (\(frame.position.value + frame.duration.value))")
                            }*/
                            return frame
                        }
                    }
                }
                
                return .noFrames
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
            if reportRate.isZero {
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
        let _ = isPaused
        
        if self.lastStatusUpdateTimestamp == nil || self.lastStatusUpdateTimestamp! < statusTimestamp + 1.0 / 25.0 {
            self.lastStatusUpdateTimestamp = statusTimestamp
            let reportTimestamp = timestamp
            let statusTimestamp: Double
            if duration == 0.0 {
                statusTimestamp = max(reportTimestamp, 0.0)
            } else {
                statusTimestamp = min(max(reportTimestamp, 0.0), duration)
            }
            let status = MediaPlayerStatus(generationTimestamp: CACurrentMediaTime(), duration: duration, dimensions: CGSize(), timestamp: statusTimestamp, baseRate: self.baseRate, seekId: self.seekId, status: playbackStatus, soundEnabled: self.enableSound)
            self.playerStatus.set(.single(status))
            let _ = self.playerStatusValue.swap(status)
        }
        
        if self.notifySeeked {
            self.notifySeeked = false
            self.onSeeked()
        }

        if performActionAtEndNow {
            if !self.stoppedAtEnd {
                switch self.actionAtEnd {
                case let .loop(f):
                    self.stoppedAtEnd = false
                    self.seek(timestamp: 0.0, action: .play, notify: true)
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
                    self.seek(timestamp: 0.0, action: .play, notify: true)
                    f()
                }
            }
        }
    }
}

public protocol ChunkMediaPlayer: AnyObject {
    var status: Signal<MediaPlayerStatus, NoError> { get }
    var audioLevelEvents: Signal<Float, NoError> { get }
    var actionAtEnd: ChunkMediaPlayerActionAtEnd { get set }
    
    func play()
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek)
    func setSoundMuted(soundMuted: Bool)
    func continueWithOverridingAmbientMode(isAmbient: Bool)
    func continuePlayingWithoutSound(seek: MediaPlayerSeek)
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool)
    func setForceAudioToSpeaker(_ value: Bool)
    func setKeepAudioSessionWhilePaused(_ value: Bool)
    func pause()
    func togglePlayPause(faded: Bool)
    func seek(timestamp: Double, play: Bool?)
    func setBaseRate(_ baseRate: Double)
}

public final class ChunkMediaPlayerImpl: ChunkMediaPlayer {
    private let queue = Queue()
    private var contextRef: Unmanaged<ChunkMediaPlayerContext>?
    
    private let statusValue = Promise<MediaPlayerStatus>()
    
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusValue.get()
    }
    
    private let audioLevelPipe = ValuePipe<Float>()
    public var audioLevelEvents: Signal<Float, NoError> {
        return self.audioLevelPipe.signal()
    }
    
    public var actionAtEnd: ChunkMediaPlayerActionAtEnd = .stop {
        didSet {
            let value = self.actionAtEnd
            self.queue.async {
                if let context = self.contextRef?.takeUnretainedValue() {
                    context.actionAtEnd = value
                }
            }
        }
    }
    
    public init(
        postbox: Postbox,
        audioSessionManager: ManagedAudioSession,
        partsState: Signal<ChunkMediaPlayerPartsState, NoError>,
        video: Bool,
        playAutomatically: Bool = false,
        enableSound: Bool,
        baseRate: Double = 1.0,
        playAndRecord: Bool = false,
        soundMuted: Bool = false,
        ambient: Bool = false,
        mixWithOthers: Bool = false,
        keepAudioSessionWhilePaused: Bool = false,
        continuePlayingWithoutSoundOnLostAudioSession: Bool = false,
        isAudioVideoMessage: Bool = false,
        onSeeked: (() -> Void)? = nil,
        playerNode: MediaPlayerNode
    ) {
        let audioLevelPipe = self.audioLevelPipe
        self.queue.async {
            let context = ChunkMediaPlayerContext(
                queue: self.queue,
                postbox: postbox,
                audioSessionManager: audioSessionManager,
                playerStatus: self.statusValue,
                audioLevelPipe: audioLevelPipe,
                partsState: partsState,
                video: video,
                playAutomatically: playAutomatically,
                enableSound: enableSound,
                baseRate: baseRate,
                playAndRecord: playAndRecord,
                soundMuted: soundMuted,
                ambient: ambient,
                mixWithOthers: mixWithOthers,
                keepAudioSessionWhilePaused: keepAudioSessionWhilePaused,
                continuePlayingWithoutSoundOnLostAudioSession: continuePlayingWithoutSoundOnLostAudioSession,
                isAudioVideoMessage: isAudioVideoMessage,
                onSeeked: {
                    onSeeked?()
                }
            )
            self.contextRef = Unmanaged.passRetained(context)
        }
        
        self.attachPlayerNode(playerNode)
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
    
    public func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
            }
        }
    }
    
    public func setSoundMuted(soundMuted: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.setSoundMuted(soundMuted: soundMuted)
            }
        }
    }
    
    public func continueWithOverridingAmbientMode(isAmbient: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.continueWithOverridingAmbientMode(isAmbient: isAmbient)
            }
        }
    }
    
    public func continuePlayingWithoutSound(seek: MediaPlayerSeek) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.continuePlayingWithoutSound(seek: seek)
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
    
    public func togglePlayPause(faded: Bool) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                context.togglePlayPause(faded: faded)
            }
        }
    }
    
    public func seek(timestamp: Double, play: Bool?) {
        self.queue.async {
            if let context = self.contextRef?.takeUnretainedValue() {
                if let play {
                    context.seek(timestamp: timestamp, action: play ? .play : .pause, notify: false)
                } else {
                    context.seek(timestamp: timestamp, notify: false)
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
