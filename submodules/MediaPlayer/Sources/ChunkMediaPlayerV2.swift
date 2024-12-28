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

protocol ChunkMediaPlayerSourceImpl: AnyObject {
    var partsState: Signal<ChunkMediaPlayerPartsState, NoError> { get }
    
    func seek(id: Int, position: Double)
    func updatePlaybackState(seekTimestamp: Double, position: Double, isPlaying: Bool)
}

private final class ChunkMediaPlayerExternalSourceImpl: ChunkMediaPlayerSourceImpl {
    let partsState: Signal<ChunkMediaPlayerPartsState, NoError>
    
    init(partsState: Signal<ChunkMediaPlayerPartsState, NoError>) {
        self.partsState = partsState
    }
    
    func seek(id: Int, position: Double) {
    }
    
    func updatePlaybackState(seekTimestamp: Double, position: Double, isPlaying: Bool) {
    }
}

public final class ChunkMediaPlayerV2: ChunkMediaPlayer {
    public enum SourceDescription {
        public final class ResourceDescription {
            public let postbox: Postbox
            public let size: Int64
            public let reference: MediaResourceReference
            public let userLocation: MediaResourceUserLocation
            public let userContentType: MediaResourceUserContentType
            public let statsCategory: MediaResourceStatsCategory
            public let fetchAutomatically: Bool
            
            public init(postbox: Postbox, size: Int64, reference: MediaResourceReference, userLocation: MediaResourceUserLocation, userContentType: MediaResourceUserContentType, statsCategory: MediaResourceStatsCategory, fetchAutomatically: Bool) {
                self.postbox = postbox
                self.size = size
                self.reference = reference
                self.userLocation = userLocation
                self.userContentType = userContentType
                self.statsCategory = statsCategory
                self.fetchAutomatically = fetchAutomatically
            }
        }
        
        case externalParts(Signal<ChunkMediaPlayerPartsState, NoError>)
        case directFetch(ResourceDescription)
    }
    
    public struct MediaDataReaderParams {
        public var useV2Reader: Bool
        
        public init(useV2Reader: Bool) {
            self.useV2Reader = useV2Reader
        }
    }
    
    private final class LoadedPart {
        enum Content {
            case tempFile(ChunkMediaPlayerPart.TempFile)
            case directStream(ChunkMediaPlayerPartsState.DirectReader.Stream)
        }
        
        final class Media {
            let queue: Queue
            let content: Content
            let mediaType: AVMediaType
            let codecName: String?
            
            private(set) var reader: MediaDataReader?
            
            var didBeginReading: Bool = false
            var isFinished: Bool = false
            
            init(queue: Queue, content: Content, mediaType: AVMediaType, codecName: String?) {
                assert(queue.isCurrent())
                
                self.queue = queue
                self.content = content
                self.mediaType = mediaType
                self.codecName = codecName
            }
            
            deinit {
                assert(self.queue.isCurrent())
            }
            
            func load(params: MediaDataReaderParams) {
                let reader: MediaDataReader
                switch self.content {
                case let .tempFile(tempFile):
                    if self.mediaType == .video, (self.codecName == "av1" || self.codecName == "av01"), internal_isHardwareAv1Supported {
                        reader = AVAssetVideoDataReader(filePath: tempFile.file.path, isVideo: self.mediaType == .video)
                    } else {
                        if params.useV2Reader {
                            reader = FFMpegMediaDataReaderV2(content: .tempFile(tempFile), isVideo: self.mediaType == .video, codecName: self.codecName)
                        } else {
                            reader = FFMpegMediaDataReaderV1(filePath: tempFile.file.path, isVideo: self.mediaType == .video, codecName: self.codecName)
                        }
                    }
                case let .directStream(directStream):
                    reader = FFMpegMediaDataReaderV2(content: .directStream(directStream), isVideo: self.mediaType == .video, codecName: self.codecName)
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
            
            func update(content: Content) {
                if let reader = self.reader {
                    if let reader = reader as? FFMpegMediaDataReaderV2, case let .directStream(directStream) = content {
                        reader.update(content: .directStream(directStream))
                    } else {
                        assertionFailure()
                    }
                }
            }
        }
        
        final class MediaData {
            let video: Media?
            let audio: Media?
            
            init(video: Media?, audio: Media?) {
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
        var directMediaData: LoadedPart.MediaData?
        var directReaderId: Double?
        var notifiedHasSound: Bool = false
        var seekFromMinTimestamp: Double?
    }
    
    private static let sharedDataQueue = Queue(name: "ChunkMediaPlayerV2-DataQueue")
    private let dataQueue: Queue
    
    private let mediaDataReaderParams: MediaDataReaderParams
    private let audioSessionManager: ManagedAudioSession
    private let onSeeked: (() -> Void)?
    
    private let renderSynchronizer: AVSampleBufferRenderSynchronizer
    private var videoRenderer: AVSampleBufferDisplayLayer
    private var audioRenderer: AVSampleBufferAudioRenderer?
    
    private var partsState = ChunkMediaPlayerPartsState(duration: nil, content: .parts([]))
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

    public var actionAtEnd: MediaPlayerActionAtEnd = .stop
    
    private var didSeekOnce: Bool = false
    private var isPlaying: Bool = false
    private var baseRate: Double = 1.0
    private var isSoundEnabled: Bool
    private var isMuted: Bool
    
    private var seekId: Int = 0
    private var seekTimestamp: Double = 0.0
    private var pendingSeekTimestamp: Double?
    private var pendingContinuePlaybackAfterSeekToTimestamp: Double?
    private var shouldNotifySeeked: Bool = false
    private var stoppedAtEnd: Bool = false
    
    private var renderSynchronizerRate: Double = 0.0
    private var videoIsRequestingMediaData: Bool = false
    private var audioIsRequestingMediaData: Bool = false
    
    private let source: ChunkMediaPlayerSourceImpl
    private var didSetSourceSeek: Bool = false
    private var partsStateDisposable: Disposable?
    private var updateTimer: Foundation.Timer?
    
    private var audioSessionDisposable: Disposable?
    private var hasAudioSession: Bool = false

    public init(
        params: MediaDataReaderParams,
        audioSessionManager: ManagedAudioSession,
        source: SourceDescription,
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
        
        self.mediaDataReaderParams = params
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
        
        switch source {
        case let .externalParts(partsState):
            self.source = ChunkMediaPlayerExternalSourceImpl(partsState: partsState)
        case let .directFetch(resource):
            self.source = ChunkMediaPlayerDirectFetchSourceImpl(resource: resource)
        }
        
        self.updateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateInternalState()
        })
        
        self.partsStateDisposable = (self.source.partsState
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
        
        if !self.didSeekOnce {
            self.didSeekOnce = true
            self.seek(timestamp: 0.0, play: nil)
            return
        }
        
        let timestamp: CMTime
        if let pendingSeekTimestamp = self.pendingSeekTimestamp {
            timestamp = CMTimeMakeWithSeconds(pendingSeekTimestamp, preferredTimescale: 44000)
        } else {
            timestamp = self.renderSynchronizer.currentTime()
        }
        let timestampSeconds = timestamp.seconds
        
        self.source.updatePlaybackState(
            seekTimestamp: self.seekTimestamp,
            position: timestampSeconds,
            isPlaying: self.isPlaying
        )
        
        var duration: Double = 0.0
        if let partsStateDuration = self.partsState.duration {
            duration = partsStateDuration
        }
        
        let isBuffering: Bool
        
        let mediaDataReaderParams = self.mediaDataReaderParams
        
        switch self.partsState.content {
        case let .parts(partsStateParts):
            var validParts: [ChunkMediaPlayerPart] = []
            var minStartTime: Double = 0.0
            for i in 0 ..< partsStateParts.count {
                let part = partsStateParts[i]
                
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
                        content: part.content,
                        codecName: part.codecName
                    ))
                    minStartTime = max(minStartTime, partEndTime)
                }
            }
            
            if let lastValidPart = validParts.last {
                for i in 0 ..< partsStateParts.count {
                    let part = partsStateParts[i]
                    
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
                            content: part.content,
                            codecName: part.codecName
                        ))
                        minStartTime = max(minStartTime, partEndTime)
                        break
                    }
                }
            }
            
            if validParts.isEmpty, let pendingContinuePlaybackAfterSeekToTimestamp = self.pendingContinuePlaybackAfterSeekToTimestamp {
                for part in partsStateParts {
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
            
            var playableDuration: Double = 0.0
            var previousValidPartEndTime: Double?
            
            for part in partsStateParts {
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
                            let cleanAudio = LoadedPart.Media(
                                queue: dataQueue,
                                content: .tempFile(part.part.content),
                                mediaType: .audio,
                                codecName: part.part.codecName
                            )
                            cleanAudio.load(params: mediaDataReaderParams)
                            
                            loadedPartsMediaData.parts[part.part.id] = LoadedPart.MediaData(
                                video: loadedPart.video,
                                audio: cleanAudio.reader != nil ? cleanAudio : nil
                            )
                        }
                    } else {
                        let video = LoadedPart.Media(
                            queue: dataQueue,
                            content: .tempFile(part.part.content),
                            mediaType: .video,
                            codecName: part.part.codecName
                        )
                        video.load(params: mediaDataReaderParams)
                        
                        let audio = LoadedPart.Media(
                            queue: dataQueue,
                            content: .tempFile(part.part.content),
                            mediaType: .audio,
                            codecName: part.part.codecName
                        )
                        audio.load(params: mediaDataReaderParams)
                        
                        loadedPartsMediaData.parts[part.part.id] = LoadedPart.MediaData(
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
            
            if let previousValidPartEndTime, previousValidPartEndTime >= duration - 0.5 {
                isBuffering = false
            } else {
                isBuffering = playableDuration < 1.0
            }
        case let .directReader(directReader):
            var readerImpl: ChunkMediaPlayerPartsState.DirectReader.Impl?
            var playableDuration: Double = 0.0
            let directReaderSeekPosition = directReader.seekPosition
            if directReader.id == self.seekId {
                readerImpl = directReader.impl
                playableDuration = max(0.0, directReader.availableUntilPosition - timestampSeconds)
                if directReader.bufferedUntilEnd {
                    isBuffering = false
                } else {
                    isBuffering = playableDuration < 1.0
                }
            } else {
                playableDuration = 0.0
                isBuffering = true
            }
            
            let dataQueue = self.dataQueue
            self.loadedPartsMediaData.with { [weak self] loadedPartsMediaData in
                if !loadedPartsMediaData.ids.isEmpty {
                    loadedPartsMediaData.ids = []
                }
                if !loadedPartsMediaData.parts.isEmpty {
                    loadedPartsMediaData.parts.removeAll()
                }
                
                if let readerImpl {
                    if let currentDirectMediaData = loadedPartsMediaData.directMediaData, let currentDirectReaderId = loadedPartsMediaData.directReaderId, currentDirectReaderId == directReaderSeekPosition {
                        if let video = currentDirectMediaData.video, let videoStream = readerImpl.video {
                            video.update(content: .directStream(videoStream))
                        }
                        if let audio = currentDirectMediaData.audio, let audioStream = readerImpl.audio {
                            audio.update(content: .directStream(audioStream))
                        }
                    } else {
                        let video = readerImpl.video.flatMap { media in
                            return LoadedPart.Media(
                                queue: dataQueue,
                                content: .directStream(media),
                                mediaType: .video,
                                codecName: media.codecName
                            )
                        }
                        video?.load(params: mediaDataReaderParams)
                        
                        let audio = readerImpl.audio.flatMap { media in
                            return LoadedPart.Media(
                                queue: dataQueue,
                                content: .directStream(media),
                                mediaType: .audio,
                                codecName: media.codecName
                            )
                        }
                        audio?.load(params: mediaDataReaderParams)
                        
                        loadedPartsMediaData.directMediaData = LoadedPart.MediaData(
                            video: video,
                            audio: audio
                        )
                    }
                    loadedPartsMediaData.directReaderId = directReaderSeekPosition
                    
                    if !loadedPartsMediaData.notifiedHasSound {
                        loadedPartsMediaData.notifiedHasSound = true
                        let hasSound = readerImpl.audio != nil
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
                } else {
                    loadedPartsMediaData.directMediaData = nil
                    loadedPartsMediaData.directReaderId = nil
                }
            }
            
            if self.pendingSeekTimestamp != nil {
                return
            }
        }
        
        var effectiveRate: Double = 0.0
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
        let currentTimestamp: CMTime
        if let pendingSeekTimestamp = self.pendingSeekTimestamp {
            currentTimestamp = CMTimeMakeWithSeconds(pendingSeekTimestamp, preferredTimescale: 44000)
        } else {
            currentTimestamp = self.renderSynchronizer.currentTime()
        }
        let currentTimestampSeconds = currentTimestamp.seconds
        if currentTimestampSeconds == timestamp {
            if let play {
                self.isPlaying = play
            }
            if notify {
                self.shouldNotifySeeked = true
            }
            if !self.didSetSourceSeek {
                self.didSetSourceSeek = true
                self.source.seek(id: self.seekId, position: timestamp)
            }
            self.updateInternalState()
            return
        }
        
        self.seekId += 1
        self.seekTimestamp = timestamp
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
        
        self.didSetSourceSeek = true
        self.source.seek(id: self.seekId, position: timestamp)
        
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
        
        if !self.videoIsRequestingMediaData {
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
                switch reader.readSampleBuffer() {
                case let .frame(sampleBuffer):
                    var sampleBuffer = sampleBuffer
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
                    /*if !isVideo {
                        print("Enqueue audio \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) next: \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value + 1024)")
                    }*/
                    bufferTarget.enqueue(sampleBuffer)
                    hasData = true
                    continue outer
                case .waitingForMoreData, .endOfStream, .error:
                    media.isFinished = true
                }
            }
            outerDirect: while true {
                guard let directMediaData = loadedPartsMediaData.directMediaData else {
                    break outer
                }
                guard let media = isVideo ? directMediaData.video : directMediaData.audio else {
                    break outer
                }
                if media.isFinished {
                    break outer
                }
                guard let reader = media.reader else {
                    break outer
                }
                media.didBeginReading = true
                switch reader.readSampleBuffer() {
                case let .frame(sampleBuffer):
                    var sampleBuffer = sampleBuffer
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
                    /*if !isVideo {
                        print("Enqueue audio \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) next: \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value + 1024)")
                    }*/
                    bufferTarget.enqueue(sampleBuffer)
                    hasData = true
                    continue outer
                case .waitingForMoreData:
                    break outer
                case .endOfStream, .error:
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
