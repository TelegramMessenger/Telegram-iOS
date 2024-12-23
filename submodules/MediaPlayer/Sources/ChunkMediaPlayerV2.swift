import Foundation
import AVFoundation
import TelegramCore
import TelegramAudio
import SwiftSignalKit
import Postbox
import VideoToolbox

public let internal_isHardwareAv1Supported: Bool = {
    let value = VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1)
    return value
}()

public final class ChunkMediaPlayerV2: ChunkMediaPlayer {
    private final class LoadedPart {
        final class Media {
            let queue: Queue
            let tempFile: TempBoxFile
            let mediaType: AVMediaType
            let codecName: String?
            
            private(set) var reader: MediaDataReader?
            
            var didBeginReading: Bool = false
            var isFinished: Bool = false
            
            init(queue: Queue, tempFile: TempBoxFile, mediaType: AVMediaType, codecName: String?) {
                assert(queue.isCurrent())
                
                self.queue = queue
                self.tempFile = tempFile
                self.mediaType = mediaType
                self.codecName = codecName
            }
            
            deinit {
                assert(self.queue.isCurrent())
            }
            
            func load() {
                let reader: MediaDataReader
                if self.mediaType == .video && (self.codecName == "av1" || self.codecName == "av01") && internal_isHardwareAv1Supported {
                    reader = AVAssetVideoDataReader(filePath: self.tempFile.path, isVideo: self.mediaType == .video)
                } else {
                    reader = FFMpegMediaDataReader(filePath: self.tempFile.path, isVideo: self.mediaType == .video, codecName: self.codecName)
                }
                if self.mediaType == .video {
                    if reader.hasVideo {
                        self.reader = reader
                    }
                } else {
                    if reader.hasAudio {
                        self.reader = reader
                    }
                }
            }
        }
        
        final class MediaData {
            let part: ChunkMediaPlayerPart
            let video: Media?
            let audio: Media?
            
            init(part: ChunkMediaPlayerPart, video: Media?, audio: Media?) {
                self.part = part
                self.video = video
                self.audio = audio
            }
        }
        
        let part: ChunkMediaPlayerPart
        
        init(part: ChunkMediaPlayerPart) {
            self.part = part
        }
    }
    
    private final class LoadedPartsMediaData {
        var ids: [ChunkMediaPlayerPart.Id] = []
        var parts: [ChunkMediaPlayerPart.Id: LoadedPart.MediaData] = [:]
        var notifiedHasSound: Bool = false
        var seekFromMinTimestamp: Double?
    }
    
    private static let sharedDataQueue = Queue(name: "ChunkMediaPlayerV2-DataQueue")
    private let dataQueue: Queue
    
    private let audioSessionManager: ManagedAudioSession
    private let onSeeked: (() -> Void)?
    
    private let renderSynchronizer: AVSampleBufferRenderSynchronizer
    private var videoRenderer: AVSampleBufferDisplayLayer
    private var audioRenderer: AVSampleBufferAudioRenderer?
    
    private var partsState = ChunkMediaPlayerPartsState(duration: nil, parts: [])
    private var loadedParts: [LoadedPart] = []
    private var loadedPartsMediaData: QueueLocalObject<LoadedPartsMediaData>
    private var hasSound: Bool = false
    
    private var statusValue: MediaPlayerStatus? {
        didSet {
            if let statusValue = self.statusValue, statusValue != oldValue {
                self.statusPromise.set(statusValue)
            }
        }
    }
    private let statusPromise = ValuePromise<MediaPlayerStatus>()
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusPromise.get()
    }

    public var audioLevelEvents: Signal<Float, NoError> {
        return .never()
    }

    public var actionAtEnd: ChunkMediaPlayerActionAtEnd = .stop
    
    private var isPlaying: Bool = false
    private var baseRate: Double = 1.0
    private var isSoundEnabled: Bool
    private var isMuted: Bool
    
    private var seekId: Int = 0
    private var pendingSeekTimestamp: Double?
    private var pendingContinuePlaybackAfterSeekToTimestamp: Double?
    private var shouldNotifySeeked: Bool = false
    private var stoppedAtEnd: Bool = false
    
    private var renderSynchronizerRate: Double = 0.0
    private var videoIsRequestingMediaData: Bool = false
    private var audioIsRequestingMediaData: Bool = false
    
    private var partsStateDisposable: Disposable?
    private var updateTimer: Foundation.Timer?
    
    private var audioSessionDisposable: Disposable?
    private var hasAudioSession: Bool = false

    public init(
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
        self.dataQueue = ChunkMediaPlayerV2.sharedDataQueue
        
        self.audioSessionManager = audioSessionManager
        self.onSeeked = onSeeked
        
        self.loadedPartsMediaData = QueueLocalObject(queue: self.dataQueue, generate: {
            return LoadedPartsMediaData()
        })
        
        self.isSoundEnabled = enableSound
        self.isMuted = soundMuted
        self.baseRate = baseRate
        
        self.renderSynchronizer = AVSampleBufferRenderSynchronizer()
        self.renderSynchronizer.setRate(0.0, time: CMTime(seconds: 0.0, preferredTimescale: 44000))
        
        if playerNode.videoLayer == nil {
            assertionFailure()
        }
        self.videoRenderer = playerNode.videoLayer ?? AVSampleBufferDisplayLayer()
        
        self.updateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateInternalState()
        })
        
        self.partsStateDisposable = (partsState
        |> deliverOnMainQueue).startStrict(next: { [weak self] partsState in
            guard let self else {
                return
            }
            self.partsState = partsState
            self.updateInternalState()
        })
        
        if #available(iOS 17.0, *) {
            self.renderSynchronizer.addRenderer(self.videoRenderer.sampleBufferRenderer)
        } else {
            self.renderSynchronizer.addRenderer(self.videoRenderer)
        }
    }
    
    deinit {
        self.partsStateDisposable?.dispose()
        self.updateTimer?.invalidate()
        self.audioSessionDisposable?.dispose()
        
        if #available(iOS 17.0, *) {
            self.videoRenderer.sampleBufferRenderer.stopRequestingMediaData()
        } else {
            self.videoRenderer.stopRequestingMediaData()
        }
        
        // Conservatively release AVSampleBufferDisplayLayer reference on main thread to prevent deadlock
        let videoRenderer = self.videoRenderer
        Queue.mainQueue().after(1.0, {
            let _ = videoRenderer.masksToBounds
        })
        
        if let audioRenderer = self.audioRenderer {
            audioRenderer.stopRequestingMediaData()
        }
    }
    
    private func updateInternalState() {
        if self.isSoundEnabled && self.hasSound {
            if self.audioSessionDisposable == nil {
                self.audioSessionDisposable = self.audioSessionManager.push(params: ManagedAudioSessionClientParams(
                    audioSessionType: .play(mixWithOthers: false),
                    activateImmediately: false,
                    manualActivate: { [weak self] control in
                        control.setupAndActivate(synchronous: false, { state in
                            Queue.mainQueue().async {
                                guard let self else {
                                    return
                                }
                                self.hasAudioSession = true
                                self.updateInternalState()
                            }
                        })
                    },
                    deactivate: { [weak self] _ in
                        return Signal { subscriber in
                            guard let self else {
                                subscriber.putCompletion()
                                return EmptyDisposable
                            }
                            
                            self.hasAudioSession = false
                            self.updateInternalState()
                            subscriber.putCompletion()
                            
                            return EmptyDisposable
                        }
                        |> runOn(.mainQueue())
                    },
                    headsetConnectionStatusChanged: { _ in },
                    availableOutputsChanged: { _, _ in }
                ))
            }
        } else {
            if let audioSessionDisposable = self.audioSessionDisposable {
                self.audioSessionDisposable = nil
                audioSessionDisposable.dispose()
            }
            
            self.hasAudioSession = false
        }
        
        if self.isSoundEnabled && self.hasSound && self.hasAudioSession {
            if self.audioRenderer == nil {
                let audioRenderer = AVSampleBufferAudioRenderer()
                audioRenderer.isMuted = self.isMuted
                self.audioRenderer = audioRenderer
                self.renderSynchronizer.addRenderer(audioRenderer)
            }
        } else {
            if let audioRenderer = self.audioRenderer {
                self.audioRenderer = nil
                audioRenderer.stopRequestingMediaData()
                self.audioIsRequestingMediaData = false
                self.renderSynchronizer.removeRenderer(audioRenderer, at: .invalid)
            }
        }
        
        let timestamp: CMTime
        if let pendingSeekTimestamp = self.pendingSeekTimestamp {
            timestamp = CMTimeMakeWithSeconds(pendingSeekTimestamp, preferredTimescale: 44000)
        } else {
            timestamp = self.renderSynchronizer.currentTime()
        }
        let timestampSeconds = timestamp.seconds
        
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
            if timestampSeconds >= partStartTime - 0.5 && timestampSeconds < partEndTime + 0.5 {
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
        
        if validParts.isEmpty, let pendingContinuePlaybackAfterSeekToTimestamp = self.pendingContinuePlaybackAfterSeekToTimestamp {
            for part in self.partsState.parts {
                if pendingContinuePlaybackAfterSeekToTimestamp >= part.startTime - 0.2 && pendingContinuePlaybackAfterSeekToTimestamp < part.endTime {
                    self.renderSynchronizer.setRate(Float(self.renderSynchronizerRate), time: CMTimeMakeWithSeconds(part.startTime, preferredTimescale: 44000))
                    break
                }
            }
        }
        
        self.loadedParts.removeAll(where: { partState in
            if !validParts.contains(where: { $0.id == partState.part.id }) {
                return true
            }
            return false
        })
        
        for part in validParts {
            if !self.loadedParts.contains(where: { $0.part.id == part.id }) {
                self.loadedParts.append(LoadedPart(part: part))
                self.loadedParts.sort(by: { $0.part.startTime < $1.part.startTime })
            }
        }
        
        if self.pendingSeekTimestamp != nil {
            return
        }
        
        let loadedParts = self.loadedParts
        let dataQueue = self.dataQueue
        let isSoundEnabled = self.isSoundEnabled
        self.loadedPartsMediaData.with { [weak self] loadedPartsMediaData in
            loadedPartsMediaData.ids = loadedParts.map(\.part.id)
            
            for part in loadedParts {
                if let loadedPart = loadedPartsMediaData.parts[part.part.id] {
                    if let audio = loadedPart.audio, audio.didBeginReading, !isSoundEnabled {
                        let cleanAudio = LoadedPart.Media(queue: dataQueue, tempFile: part.part.file, mediaType: .audio, codecName: part.part.codecName)
                        cleanAudio.load()
                        
                        loadedPartsMediaData.parts[part.part.id] = LoadedPart.MediaData(
                            part: part.part,
                            video: loadedPart.video,
                            audio: cleanAudio.reader != nil ? cleanAudio : nil
                        )
                    }
                } else {
                    let video = LoadedPart.Media(queue: dataQueue, tempFile: part.part.file, mediaType: .video, codecName: part.part.codecName)
                    video.load()
                    
                    let audio = LoadedPart.Media(queue: dataQueue, tempFile: part.part.file, mediaType: .audio, codecName: part.part.codecName)
                    audio.load()
                    
                    loadedPartsMediaData.parts[part.part.id] = LoadedPart.MediaData(
                        part: part.part,
                        video: video,
                        audio: audio.reader != nil ? audio : nil
                    )
                }
            }
            
            var removedKeys: [ChunkMediaPlayerPart.Id] = []
            for (id, _) in loadedPartsMediaData.parts {
                if !loadedPartsMediaData.ids.contains(id) {
                    removedKeys.append(id)
                }
            }
            for id in removedKeys {
                loadedPartsMediaData.parts.removeValue(forKey: id)
            }
            
            if !loadedPartsMediaData.notifiedHasSound, let part = loadedPartsMediaData.parts.values.first {
                loadedPartsMediaData.notifiedHasSound = true
                let hasSound = part.audio?.reader != nil
                Queue.mainQueue().async {
                    guard let self else {
                        return
                    }
                    if self.hasSound != hasSound {
                        self.hasSound = hasSound
                        self.updateInternalState()
                    }
                }
            }
        }
        
        var playableDuration: Double = 0.0
        var previousValidPartEndTime: Double?
        for part in self.partsState.parts {
            if let previousValidPartEndTime {
                if part.startTime > previousValidPartEndTime + 0.5 {
                    break
                }
            } else if !validParts.contains(where: { $0.id == part.id }) {
                continue
            }
            
            let partDuration: Double
            if part.startTime - 0.5 <= timestampSeconds && part.endTime + 0.5 > timestampSeconds {
                partDuration = part.endTime - timestampSeconds
            } else if part.startTime - 0.5 > timestampSeconds {
                partDuration = part.endTime - part.startTime
            } else {
                partDuration = 0.0
            }
            playableDuration += partDuration
            previousValidPartEndTime = part.endTime
        }
        
        var effectiveRate: Double = 0.0
        let isBuffering: Bool
        if let previousValidPartEndTime, previousValidPartEndTime >= duration - 0.5 {
            isBuffering = false
        } else {
            isBuffering = playableDuration < 1.0
        }
        if self.isPlaying {
            if !isBuffering {
                effectiveRate = self.baseRate
            }
        }
        if !isBuffering {
            self.pendingContinuePlaybackAfterSeekToTimestamp = nil
        }
        
        //print("timestampSeconds: \(timestampSeconds) rate: \(effectiveRate)")
        
        if self.renderSynchronizerRate != effectiveRate {
            self.renderSynchronizerRate = effectiveRate
            self.renderSynchronizer.setRate(Float(effectiveRate), time: timestamp)
        }
        
        if effectiveRate != 0.0 {
            self.triggerRequestMediaData()
        }
        
        let playbackStatus: MediaPlayerPlaybackStatus
        if isBuffering {
            playbackStatus = .buffering(initial: false, whilePlaying: self.isPlaying, progress: 0.0, display: true)
        } else if self.isPlaying {
            playbackStatus = .playing
        } else {
            playbackStatus = .paused
        }
        self.statusValue = MediaPlayerStatus(
            generationTimestamp: CACurrentMediaTime(),
            duration: duration,
            dimensions: CGSize(),
            timestamp: timestampSeconds,
            baseRate: self.baseRate,
            seekId: self.seekId,
            status: playbackStatus,
            soundEnabled: self.isSoundEnabled
        )
        
        if self.shouldNotifySeeked {
            self.shouldNotifySeeked = false
            self.onSeeked?()
        }

        if duration > 0.0 && timestampSeconds >= duration - 0.1 {
            if !self.stoppedAtEnd {
                switch self.actionAtEnd {
                case let .loop(f):
                    self.stoppedAtEnd = false
                    self.seek(timestamp: 0.0, play: true, notify: true)
                    f?()
                case .stop:
                    self.stoppedAtEnd = true
                    self.pause()
                case let .action(f):
                    self.stoppedAtEnd = true
                    self.pause()
                    f()
                case let .loopDisablingSound(f):
                    self.stoppedAtEnd = false
                    self.isSoundEnabled = false
                    self.seek(timestamp: 0.0, play: true, notify: true)
                    f()
                }
            }
        }
    }
    
    public func play() {
        self.isPlaying = true
        self.updateInternalState()
    }

    public func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek) {
        self.isPlaying = true
        self.isSoundEnabled = true

        switch seek {
        case .automatic, .none:
            self.updateInternalState()
        case .start:
            self.seek(timestamp: 0.0, play: nil)
        case let .timecode(timestamp):
            self.seek(timestamp: timestamp, play: nil)
        }
    }

    public func setSoundMuted(soundMuted: Bool) {
        if self.isMuted != soundMuted {
            self.isMuted = soundMuted
            if let audioRenderer = self.audioRenderer {
                audioRenderer.isMuted = self.isMuted
            }
        }
    }

    public func continueWithOverridingAmbientMode(isAmbient: Bool) {
    }

    public func continuePlayingWithoutSound(seek: MediaPlayerSeek) {
        self.isSoundEnabled = false
        self.isPlaying = true
        self.updateInternalState()
        
        switch seek {
        case .automatic, .none:
            break
        case .start:
            self.seek(timestamp: 0.0, play: nil)
        case let .timecode(timestamp):
            self.seek(timestamp: timestamp, play: nil)
        }
    }

    public func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
    }

    public func setForceAudioToSpeaker(_ value: Bool) {
    }

    public func setKeepAudioSessionWhilePaused(_ value: Bool) {
    }

    public func pause() {
        self.isPlaying = false
        self.updateInternalState()
    }

    public func togglePlayPause(faded: Bool) {
        if self.isPlaying {
            self.isPlaying = false
        } else {
            self.isPlaying = true
        }
        self.updateInternalState()
    }
    
    public func seek(timestamp: Double, play: Bool?) {
        self.seek(timestamp: timestamp, play: play, notify: true)
    }
        
    private func seek(timestamp: Double, play: Bool?, notify: Bool) {
        self.seekId += 1
        let seekId = self.seekId
        self.pendingSeekTimestamp = timestamp
        self.pendingContinuePlaybackAfterSeekToTimestamp = timestamp
        if let play {
            self.isPlaying = play
        }
        if notify {
            self.shouldNotifySeeked = true
        }
        
        //print("Seek to \(timestamp)")
        self.renderSynchronizerRate = 0.0
        self.renderSynchronizer.setRate(0.0, time: CMTimeMakeWithSeconds(timestamp, preferredTimescale: 44000))
        
        self.updateInternalState()
        
        self.videoIsRequestingMediaData = false
        if #available(iOS 17.0, *) {
            self.videoRenderer.sampleBufferRenderer.stopRequestingMediaData()
        } else {
            self.videoRenderer.stopRequestingMediaData()
        }
        if let audioRenderer = self.audioRenderer {
            self.audioIsRequestingMediaData = false
            audioRenderer.stopRequestingMediaData()
        }
        
        self.loadedPartsMediaData.with { [weak self] loadedPartsMediaData in
            loadedPartsMediaData.parts.removeAll()
            loadedPartsMediaData.seekFromMinTimestamp = timestamp
            
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                
                if self.seekId == seekId {
                    if #available(iOS 17.0, *) {
                        self.videoRenderer.sampleBufferRenderer.flush()
                    } else {
                        self.videoRenderer.flush()
                    }
                    if let audioRenderer = self.audioRenderer {
                        audioRenderer.flush()
                    }
                    
                    self.pendingSeekTimestamp = nil
                    self.updateInternalState()
                }
            }
        }
    }

    public func setBaseRate(_ baseRate: Double) {
        self.baseRate = baseRate
        self.updateInternalState()
    }
    
    private func triggerRequestMediaData() {
        let loadedPartsMediaData = self.loadedPartsMediaData
        
        if !self.videoIsRequestingMediaData && "".isEmpty {
            self.videoIsRequestingMediaData = true
            
            let videoTarget: AVQueuedSampleBufferRendering
            if #available(iOS 17.0, *) {
                videoTarget = self.videoRenderer.sampleBufferRenderer
            } else {
                videoTarget = self.videoRenderer
            }
        
            videoTarget.requestMediaDataWhenReady(on: self.dataQueue.queue, using: { [weak self] in
                if let loadedPartsMediaData = loadedPartsMediaData.unsafeGet() {
                    let bufferIsReadyForMoreData = ChunkMediaPlayerV2.fillRendererBuffer(bufferTarget: videoTarget, loadedPartsMediaData: loadedPartsMediaData, isVideo: true)
                    if bufferIsReadyForMoreData {
                        videoTarget.stopRequestingMediaData()
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            self.videoIsRequestingMediaData = false
                            self.updateInternalState()
                        }
                    }
                }
            })
        }
        
        if !self.audioIsRequestingMediaData, let audioRenderer = self.audioRenderer {
            self.audioIsRequestingMediaData = true
            let loadedPartsMediaData = self.loadedPartsMediaData
            let audioTarget = audioRenderer
            audioTarget.requestMediaDataWhenReady(on: self.dataQueue.queue, using: { [weak self] in
                if let loadedPartsMediaData = loadedPartsMediaData.unsafeGet() {
                    let bufferIsReadyForMoreData = ChunkMediaPlayerV2.fillRendererBuffer(bufferTarget: audioTarget, loadedPartsMediaData: loadedPartsMediaData, isVideo: false)
                    if bufferIsReadyForMoreData {
                        audioTarget.stopRequestingMediaData()
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            self.audioIsRequestingMediaData = false
                            self.updateInternalState()
                        }
                    }
                }
            })
        }
    }
    
    private static func fillRendererBuffer(bufferTarget: AVQueuedSampleBufferRendering, loadedPartsMediaData: LoadedPartsMediaData, isVideo: Bool) -> Bool {
        var bufferIsReadyForMoreData = true
        outer: while true {
            if !bufferTarget.isReadyForMoreMediaData {
                bufferIsReadyForMoreData = false
                break
            }
            var hasData = false
            for partId in loadedPartsMediaData.ids {
                guard let loadedPart = loadedPartsMediaData.parts[partId] else {
                    continue
                }
                guard let media = isVideo ? loadedPart.video : loadedPart.audio else {
                    continue
                }
                if media.isFinished {
                    continue
                }
                guard let reader = media.reader else {
                    continue
                }
                media.didBeginReading = true
                if var sampleBuffer = reader.readSampleBuffer() {
                    if let seekFromMinTimestamp = loadedPartsMediaData.seekFromMinTimestamp, CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds < seekFromMinTimestamp {
                        if isVideo {
                            var updatedSampleBuffer: CMSampleBuffer?
                            CMSampleBufferCreateCopy(allocator: nil, sampleBuffer: sampleBuffer, sampleBufferOut: &updatedSampleBuffer)
                            if let updatedSampleBuffer {
                                if let attachments = CMSampleBufferGetSampleAttachmentsArray(updatedSampleBuffer, createIfNecessary: true) {
                                    let attachments = attachments as NSArray
                                    let dict = attachments[0] as! NSMutableDictionary
                                    
                                    dict.setValue(kCFBooleanTrue as AnyObject, forKey: kCMSampleAttachmentKey_DoNotDisplay as NSString as String)
                                    
                                    sampleBuffer = updatedSampleBuffer
                                }
                            }
                        } else {
                            continue outer
                        }
                    }
                    /*if isVideo {
                        print("Enqueue \(isVideo ? "video" : "audio") at \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds) \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value)/\(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).timescale) next \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value + CMSampleBufferGetDuration(sampleBuffer).value)")
                    }*/
                    bufferTarget.enqueue(sampleBuffer)
                    hasData = true
                    continue outer
                } else {
                    media.isFinished = true
                }
            }
            if !hasData {
                break
            }
        }
        
        return bufferIsReadyForMoreData
    }
}

private func createSampleBuffer(fromSampleBuffer sampleBuffer: CMSampleBuffer, withTimeOffset timeOffset: CMTime, duration: CMTime?) -> CMSampleBuffer? {
    var itemCount: CMItemCount = 0
    var status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: 0, arrayToFill: nil, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    var timingInfo = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(duration: CMTimeMake(value: 0, timescale: 0), presentationTimeStamp: CMTimeMake(value: 0, timescale: 0), decodeTimeStamp: CMTimeMake(value: 0, timescale: 0)), count: itemCount)
    status = CMSampleBufferGetSampleTimingInfoArray(sampleBuffer, entryCount: itemCount, arrayToFill: &timingInfo, entriesNeededOut: &itemCount)
    if status != 0 {
        return nil
    }
    
    if let dur = duration {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
            timingInfo[i].duration = dur
        }
    } else {
        for i in 0 ..< itemCount {
            timingInfo[i].decodeTimeStamp = CMTimeAdd(timingInfo[i].decodeTimeStamp, timeOffset)
            timingInfo[i].presentationTimeStamp = CMTimeAdd(timingInfo[i].presentationTimeStamp, timeOffset)
        }
    }
    
    var sampleBufferOffset: CMSampleBuffer?
    CMSampleBufferCreateCopyWithNewTiming(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleTimingEntryCount: itemCount, sampleTimingArray: &timingInfo, sampleBufferOut: &sampleBufferOffset)
    
    if let output = sampleBufferOffset {
        return output
    } else {
        return nil
    }
}
