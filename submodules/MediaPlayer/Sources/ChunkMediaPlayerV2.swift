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
            let offset: Double
            let ignoreEditList: Bool
            
            private(set) var reader: MediaDataReader?
            
            var didBeginReading: Bool = false
            var isFinished: Bool = false
            
            init(queue: Queue, content: Content, mediaType: AVMediaType, codecName: String?, offset: Double, ignoreEditList: Bool = false) {
                assert(queue.isCurrent())
                
                self.queue = queue
                self.content = content
                self.mediaType = mediaType
                self.codecName = codecName
                self.offset = offset
                self.ignoreEditList = ignoreEditList
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
                            reader = FFMpegMediaDataReaderV2(content: .tempFile(tempFile), isVideo: self.mediaType == .video, codecName: self.codecName, ignoreEditList: self.ignoreEditList)
                        } else {
                            reader = FFMpegMediaDataReaderV1(filePath: tempFile.file.path, isVideo: self.mediaType == .video, codecName: self.codecName, ignoreEditList: self.ignoreEditList)
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

    private struct AudioBufferTimingState {
        var sampleRate: CMTimeScale
        var anchorPts: CMTime
        var nextSampleOffset: Int64
    }
    
    private final class LoadedPartsMediaData {
        var ids: [ChunkMediaPlayerPart.Id] = []
        var parts: [ChunkMediaPlayerPart.Id: LoadedPart.MediaData] = [:]
        var directMediaData: LoadedPart.MediaData?
        var directReaderId: Double?
        var notifiedHasSound: Bool = false
        var seekFromMinTimestamp: Double?
        var audioBufferTimingState: AudioBufferTimingState?
    }
    
    private static let sharedDataQueue = Queue(name: "ChunkMediaPlayerV2-DataQueue")
    private let dataQueue: Queue
    
    private let mediaDataReaderParams: MediaDataReaderParams
    private let audioSessionManager: ManagedAudioSession
    private let onSeeked: (() -> Void)?
    private weak var playerNode: MediaPlayerNode?
    
    private let renderSynchronizer: AVSampleBufferRenderSynchronizer
    private var videoRenderer: AVSampleBufferDisplayLayer
    private var audioRenderer: AVSampleBufferAudioRenderer?
    
    private var didNotifySentVideoFrames: Bool = false
    
    private var partsState = ChunkMediaPlayerPartsState(duration: nil, content: .parts([]))
    private var loadedParts: [LoadedPart] = []
    private var loadedPartsMediaData: QueueLocalObject<LoadedPartsMediaData>
    private var hasSound: Bool = false
    
    private var lastEmittedStatus: MediaPlayerStatus?
    private var lastStatusEmitTimestamp: Double = 0.0
    private let statusPromise = ValuePromise<MediaPlayerStatus>()
    public var status: Signal<MediaPlayerStatus, NoError> {
        return self.statusPromise.get()
    }

    public var audioLevelEvents: Signal<Float, NoError> {
        return .never()
    }

    public var actionAtEnd: MediaPlayerActionAtEnd = .stop

    // A position this close to the duration counts as the end. HLS needs the slack: its chunks do not
    // always line up with the declared duration.
    private static let endTolerance: Double = 0.1
    
    private var didSeekOnce: Bool = false
    private var isPlaying: Bool = false
    private var baseRate: Double = 1.0
    private var isSoundEnabled: Bool
    private var isMuted: Bool
    private var isAmbientMode: Bool
    private var continuePlayingWithoutSoundOnLostAudioSession: Bool

    private var seekId: Int = 0
    private var seekTimestamp: Double = 0.0
    private var pendingSeekTimestamp: Double?
    private var pendingContinuePlaybackAfterSeekToTimestamp: Double?
    private var shouldNotifySeeked: Bool = false
    private var stoppedAtEnd: Bool = false
    private var bufferingStartTime: Double?
    
    private var renderSynchronizerRate: Double = 0.0
    private var renderSynchronizerRateReapplyNotBefore: Double = 0.0
    private var videoIsRequestingMediaData: Bool = false
    private var audioIsRequestingMediaData: Bool = false
    private var videoRearmNotBefore: Double = 0.0
    private var audioRearmNotBefore: Double = 0.0
    private var videoStarvationBackoff: Double = 0.0
    private var audioStarvationBackoff: Double = 0.0

    private let source: ChunkMediaPlayerSourceImpl
    private var didSetSourceSeek: Bool = false
    private var partsStateDisposable: Disposable?
    private var updateTimer: Foundation.Timer?
    private var updateTimerIsFast: Bool = false
    
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
        self.playerNode = playerNode
        
        self.loadedPartsMediaData = QueueLocalObject(queue: self.dataQueue, generate: {
            return LoadedPartsMediaData()
        })
        
        self.isSoundEnabled = enableSound
        self.isMuted = soundMuted
        self.isAmbientMode = ambient
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
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
        
        self.updateTimerState()

        self.partsStateDisposable = (self.source.partsState
        |> deliverOnMainQueue).startStrict(next: { [weak self] partsState in
            guard let self else {
                return
            }
            self.partsState = partsState
            self.resetMediaDataStarvation()
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
    
    private func updateTimerState() {
        let isFast = self.isPlaying || self.pendingSeekTimestamp != nil || !self.didSeekOnce
        if isFast == self.updateTimerIsFast, self.updateTimer != nil {
            return
        }
        self.updateTimerIsFast = isFast
        self.updateTimer?.invalidate()
        self.updateTimer = Foundation.Timer.scheduledTimer(withTimeInterval: isFast ? 1.0 / 60.0 : 1.0 / 5.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            self.updateInternalState()
        })
    }

    private func updateInternalState() {
        defer {
            self.updateTimerState()
        }

        if self.isSoundEnabled && self.hasSound {
            if self.audioSessionDisposable == nil {
                self.audioSessionDisposable = self.audioSessionManager.push(params: ManagedAudioSessionClientParams(
                    audioSessionType: self.isAmbientMode ? .ambient : .play(mixWithOthers: false),
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
                            // Losing the session is the only signal this player gets that the system has
                            // stopped it (it has no equivalent of the legacy player's audioPaused hook).
                            // Leaving isPlaying set here is what strands it in "playing" against a rate the
                            // system has zeroed, with a clock that no longer advances.
                            // isPlaying is part of the condition because the session is held whenever
                            // sound is enabled, paused or not, and continuePlayingWithoutSound sets
                            // isPlaying — without this a lost session would start a paused video.
                            if self.isSoundEnabled, self.isPlaying {
                                if self.continuePlayingWithoutSoundOnLostAudioSession {
                                    self.continuePlayingWithoutSound(seek: .none)
                                } else {
                                    self.pause()
                                }
                            } else {
                                self.updateInternalState()
                            }
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
                self.loadedPartsMediaData.with { loadedPartsMediaData in
                    loadedPartsMediaData.audioBufferTimingState = nil
                }
                self.resetMediaDataStarvation()
            }
        } else {
            if let audioRenderer = self.audioRenderer {
                self.audioRenderer = nil
                audioRenderer.stopRequestingMediaData()
                self.audioIsRequestingMediaData = false
                self.renderSynchronizer.removeRenderer(audioRenderer, at: .invalid)
                self.loadedPartsMediaData.with { loadedPartsMediaData in
                    loadedPartsMediaData.audioBufferTimingState = nil
                }
                self.resetMediaDataStarvation()
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
        let rawTimestampSeconds = timestamp.seconds
        let timestampSeconds = rawTimestampSeconds.isFinite ? rawTimestampSeconds : 0.0

        self.source.updatePlaybackState(
            seekTimestamp: self.seekTimestamp,
            position: timestampSeconds,
            isPlaying: self.isPlaying
        )
        
        var duration: Double = 0.0
        if let partsStateDuration = self.partsState.duration {
            duration = partsStateDuration
        }
        if !duration.isFinite {
            duration = 0.0
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
                        codecName: part.codecName,
                        offsetTime: part.offsetTime
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
                            codecName: part.codecName,
                            offsetTime: part.offsetTime
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
                    let ignoreAudioEditList = part.part.content.ignoreAudioEditList
                    if let loadedPart = loadedPartsMediaData.parts[part.part.id] {
                        if let audio = loadedPart.audio, audio.didBeginReading, !isSoundEnabled {
                            let cleanAudio = LoadedPart.Media(
                                queue: dataQueue,
                                content: .tempFile(part.part.content),
                                mediaType: .audio,
                                codecName: part.part.codecName,
                                offset: part.part.offsetTime,
                                ignoreEditList: ignoreAudioEditList
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
                            codecName: part.part.codecName,
                            offset: part.part.offsetTime
                        )
                        video.load(params: mediaDataReaderParams)
                        
                        let audio = LoadedPart.Media(
                            queue: dataQueue,
                            content: .tempFile(part.part.content),
                            mediaType: .audio,
                            codecName: part.part.codecName,
                            offset: part.part.offsetTime,
                            ignoreEditList: ignoreAudioEditList
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
                            self.resetMediaDataStarvation()
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
                                codecName: media.codecName,
                                offset: 0.0
                            )
                        }
                        video?.load(params: mediaDataReaderParams)
                        
                        let audio = readerImpl.audio.flatMap { media in
                            return LoadedPart.Media(
                                queue: dataQueue,
                                content: .directStream(media),
                                mediaType: .audio,
                                codecName: media.codecName,
                                offset: 0.0
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
                                self.resetMediaDataStarvation()
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
        
        // A video no longer than the end tolerance is at its end from position 0, so it is not played:
        // its clock never moves. Its media is still requested while playback is asked for, so it shows
        // its first frame, and its end action runs once, below.
        let isTooShortToPlay = duration > 0.0 && duration <= ChunkMediaPlayerV2.endTolerance

        var effectiveRate: Double = 0.0
        if self.isPlaying {
            if !isBuffering && !isTooShortToPlay {
                effectiveRate = self.baseRate
            }
        }
        if !isBuffering {
            self.pendingContinuePlaybackAfterSeekToTimestamp = nil
        }
        
        //print("timestampSeconds: \(timestampSeconds) rate: \(effectiveRate)")
        
        let now = CACurrentMediaTime()
        if self.renderSynchronizerRate != effectiveRate {
            self.renderSynchronizerRate = effectiveRate
            self.renderSynchronizerRateReapplyNotBefore = 0.0
            self.renderSynchronizer.setRate(Float(effectiveRate), time: .invalid)
        } else if effectiveRate == 0.0, self.renderSynchronizer.rate != 0.0, now >= self.renderSynchronizerRateReapplyNotBefore {
            // The system can change the rate with no action by us, and the cached rate above cannot see
            // that, so reconcile against the real one — but only ever downwards. Re-imposing a non-zero
            // rate would fight the zeroing the system does on an audio interruption and run a silent
            // stream through the interruption, losing the listener's position.
            self.renderSynchronizerRateReapplyNotBefore = now + 1.0
            self.renderSynchronizer.setRate(0.0, time: .invalid)
        }

        if effectiveRate != 0.0 || (isTooShortToPlay && self.isPlaying) {
            self.triggerRequestMediaData(now: now)
        }
        
        if isBuffering {
            if self.bufferingStartTime == nil {
                self.bufferingStartTime = CFAbsoluteTimeGetCurrent()
            }
        } else {
            self.bufferingStartTime = nil
        }
        
        let playbackStatus: MediaPlayerPlaybackStatus
        if isBuffering {
            var displayBuffering = false
            if let bufferingStartTime = self.bufferingStartTime, (CFAbsoluteTimeGetCurrent() - bufferingStartTime) >= 0.3 {
                displayBuffering = true
            }
            playbackStatus = .buffering(initial: false, whilePlaying: self.isPlaying, progress: 0.0, display: displayBuffering)
        } else if self.isPlaying {
            playbackStatus = .playing
        } else {
            playbackStatus = .paused
        }
        let isPlayingLike = self.isPlaying
        let status = MediaPlayerStatus(
            generationTimestamp: isPlayingLike ? CACurrentMediaTime() : 0.0,
            duration: duration,
            dimensions: CGSize(),
            timestamp: timestampSeconds,
            baseRate: self.baseRate,
            seekId: self.seekId,
            status: playbackStatus,
            soundEnabled: self.isSoundEnabled
        )
        self.emitStatus(status, isPlayingLike: isPlayingLike, now: now)
        
        if self.shouldNotifySeeked {
            self.shouldNotifySeeked = false
            self.onSeeked?()
        }

        if duration > 0.0 && timestampSeconds >= duration - ChunkMediaPlayerV2.endTolerance {
            if !self.stoppedAtEnd {
                switch self.actionAtEnd {
                case let .loop(f):
                    // Looping a video that is too short to play would seek to where its clock already is,
                    // and that no-op seek re-enters this check synchronously, without bound.
                    if isTooShortToPlay {
                        self.stoppedAtEnd = true
                        self.pause()
                    } else {
                        self.stoppedAtEnd = false
                        self.seek(timestamp: 0.0, play: true, notify: true)
                    }
                    f?()
                case .stop:
                    self.stoppedAtEnd = true
                    self.pause()
                case let .action(f):
                    self.stoppedAtEnd = true
                    self.pause()
                    f()
                case let .loopDisablingSound(f):
                    if isTooShortToPlay {
                        self.stoppedAtEnd = true
                        self.pause()
                    } else {
                        self.stoppedAtEnd = false
                        self.isSoundEnabled = false
                        self.seek(timestamp: 0.0, play: true, notify: true)
                    }
                    f()
                }
            }
        }
    }
    
    public func play() {
        self.isPlaying = true
        self.resetMediaDataStarvation()
        self.updateInternalState()
    }

    public func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek) {
        self.isPlaying = true
        self.isSoundEnabled = true
        self.resetMediaDataStarvation()

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
        if self.isAmbientMode != isAmbient {
            self.isAmbientMode = isAmbient
            
            self.hasAudioSession = false
            self.updateInternalState()
            self.audioSessionDisposable?.dispose()
            self.audioSessionDisposable = nil
            
            let currentTimestamp: CMTime
            if let pendingSeekTimestamp = self.pendingSeekTimestamp {
                currentTimestamp = CMTimeMakeWithSeconds(pendingSeekTimestamp, preferredTimescale: 44000)
            } else {
                currentTimestamp = self.renderSynchronizer.currentTime()
            }
            self.seek(timestamp: currentTimestamp.seconds, play: nil)
        }
    }

    public func continuePlayingWithoutSound(seek: MediaPlayerSeek) {
        self.isSoundEnabled = false
        self.isPlaying = true
        self.resetMediaDataStarvation()
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
        self.continuePlayingWithoutSoundOnLostAudioSession = value
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
        self.resetMediaDataStarvation()
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
            self.resetMediaDataStarvation()
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
        self.resetMediaDataStarvation()

        self.didSetSourceSeek = true
        self.source.seek(id: self.seekId, position: timestamp)
        
        self.loadedPartsMediaData.with { [weak self] loadedPartsMediaData in
            loadedPartsMediaData.parts.removeAll()
            loadedPartsMediaData.seekFromMinTimestamp = timestamp
            loadedPartsMediaData.directMediaData = nil
            loadedPartsMediaData.directReaderId = nil
            loadedPartsMediaData.audioBufferTimingState = nil
            
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
                    self.stoppedAtEnd = false
                    self.updateInternalState()
                }
            }
        }
    }

    public func setBaseRate(_ baseRate: Double) {
        self.baseRate = baseRate
        self.resetMediaDataStarvation()
        self.updateInternalState()
    }

    private func noteVideoStarvation(didEnqueue: Bool) {
        self.videoStarvationBackoff = didEnqueue ? 0.0 : (self.videoStarvationBackoff <= 0.0 ? 1.0 / 60.0 : min(self.videoStarvationBackoff * 2.0, 1.0))
        self.videoRearmNotBefore = CACurrentMediaTime() + self.videoStarvationBackoff
    }

    private func noteAudioStarvation(didEnqueue: Bool) {
        self.audioStarvationBackoff = didEnqueue ? 0.0 : (self.audioStarvationBackoff <= 0.0 ? 1.0 / 60.0 : min(self.audioStarvationBackoff * 2.0, 1.0))
        self.audioRearmNotBefore = CACurrentMediaTime() + self.audioStarvationBackoff
    }

    private func resetMediaDataStarvation() {
        self.videoStarvationBackoff = 0.0
        self.audioStarvationBackoff = 0.0
        self.videoRearmNotBefore = 0.0
        self.audioRearmNotBefore = 0.0
    }

    private static func differsBeyondTiming(_ lhs: MediaPlayerStatus, _ rhs: MediaPlayerStatus) -> Bool {
        // Exhaustive over MediaPlayerStatus except generationTimestamp and timestamp. A field added to
        // MediaPlayerStatus and not added here is silently throttled to the heartbeat rate.
        return lhs.duration != rhs.duration || lhs.dimensions != rhs.dimensions || lhs.baseRate != rhs.baseRate || lhs.seekId != rhs.seekId || lhs.status != rhs.status || lhs.soundEnabled != rhs.soundEnabled
    }

    private func emitStatus(_ status: MediaPlayerStatus, isPlayingLike: Bool, now: Double) {
        let shouldEmit: Bool
        if let lastEmittedStatus = self.lastEmittedStatus {
            if ChunkMediaPlayerV2.differsBeyondTiming(status, lastEmittedStatus) {
                shouldEmit = true
            } else if isPlayingLike {
                shouldEmit = now - self.lastStatusEmitTimestamp >= 1.0 / 10.0
            } else {
                shouldEmit = status.timestamp != lastEmittedStatus.timestamp
            }
        } else {
            shouldEmit = true
        }
        if !shouldEmit {
            return
        }

        self.lastEmittedStatus = status
        self.lastStatusEmitTimestamp = now
        self.statusPromise.set(status)
    }

    private func triggerRequestMediaData(now: Double) {
        let loadedPartsMediaData = self.loadedPartsMediaData

        if !self.videoIsRequestingMediaData, now >= self.videoRearmNotBefore {
            self.videoIsRequestingMediaData = true
            
            let videoTarget: AVQueuedSampleBufferRendering
            if #available(iOS 17.0, *) {
                videoTarget = self.videoRenderer.sampleBufferRenderer
            } else {
                videoTarget = self.videoRenderer
            }
        
            let didNotifySentVideoFrames = self.didNotifySentVideoFrames
            videoTarget.stopRequestingMediaData()
            videoTarget.requestMediaDataWhenReady(on: self.dataQueue.queue, using: { [weak self] in
                if let loadedPartsMediaData = loadedPartsMediaData.unsafeGet() {
                    let bufferFillResult = ChunkMediaPlayerV2.fillRendererBuffer(bufferTarget: videoTarget, loadedPartsMediaData: loadedPartsMediaData, isVideo: true)
                    if bufferFillResult.bufferIsReadyForMoreData {
                        // The renderer still wants data we do not have. Record the starvation instead of
                        // re-arming from here: re-arming would immediately invoke this block again.
                        videoTarget.stopRequestingMediaData()
                        let didEnqueue = bufferFillResult.didEnqueue
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            self.videoIsRequestingMediaData = false
                            self.noteVideoStarvation(didEnqueue: didEnqueue)
                        }
                    }
                    if !didNotifySentVideoFrames {
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            if self.didNotifySentVideoFrames {
                                return
                            }
                            self.didNotifySentVideoFrames = true
                            if #available(iOS 17.4, *) {
                            } else {
                                self.playerNode?.hasSentFramesToDisplay?()
                            }
                        }
                    }
                }
            })
        }
        
        if !self.audioIsRequestingMediaData, now >= self.audioRearmNotBefore, let audioRenderer = self.audioRenderer {
            self.audioIsRequestingMediaData = true
            let loadedPartsMediaData = self.loadedPartsMediaData
            let audioTarget = audioRenderer
            audioTarget.stopRequestingMediaData()
            audioTarget.requestMediaDataWhenReady(on: self.dataQueue.queue, using: { [weak self] in
                if let loadedPartsMediaData = loadedPartsMediaData.unsafeGet() {
                    let bufferFillResult = ChunkMediaPlayerV2.fillRendererBuffer(bufferTarget: audioTarget, loadedPartsMediaData: loadedPartsMediaData, isVideo: false)
                    if bufferFillResult.bufferIsReadyForMoreData {
                        audioTarget.stopRequestingMediaData()
                        let didEnqueue = bufferFillResult.didEnqueue
                        Queue.mainQueue().async {
                            guard let self else {
                                return
                            }
                            self.audioIsRequestingMediaData = false
                            self.noteAudioStarvation(didEnqueue: didEnqueue)
                        }
                    }
                }
            })
        }
    }
    
    private static func fillRendererBuffer(bufferTarget: AVQueuedSampleBufferRendering, loadedPartsMediaData: LoadedPartsMediaData, isVideo: Bool) -> (bufferIsReadyForMoreData: Bool, didEnqueue: Bool) {
        var bufferIsReadyForMoreData = true
        var didEnqueue = false
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
                    if media.offset != 0.0 {
                        if let updatedSampleBuffer = createSampleBuffer(fromSampleBuffer: sampleBuffer, withTimeOffset: CMTimeMakeWithSeconds(Float64(media.offset), preferredTimescale: CMSampleBufferGetPresentationTimeStamp(sampleBuffer).timescale), duration: nil) {
                            sampleBuffer = updatedSampleBuffer
                        }
                    }
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
                    if !isVideo {
                        sampleBuffer = ChunkMediaPlayerV2.normalizeAudioSampleBuffer(
                            sampleBuffer,
                            state: &loadedPartsMediaData.audioBufferTimingState
                        )
                    }
                    /*if !isVideo {
                        print("Enqueue audio \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) next: \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value + 1024)")
                    }*/
                    bufferTarget.enqueue(sampleBuffer)
                    didEnqueue = true
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
                    /*if isVideo {
                        print("Enqueue video \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value)")
                    }*/
                    /*if !isVideo {
                        print("Enqueue audio \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value) next: \(CMSampleBufferGetPresentationTimeStamp(sampleBuffer).value + 1024)")
                    }*/
                    bufferTarget.enqueue(sampleBuffer)
                    didEnqueue = true
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
        
        return (bufferIsReadyForMoreData: bufferIsReadyForMoreData, didEnqueue: didEnqueue)
    }

    private static func normalizeAudioSampleBuffer(_ sampleBuffer: CMSampleBuffer, state: inout AudioBufferTimingState?) -> CMSampleBuffer {
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
        guard pts.seconds.isFinite, sampleCount > 0, let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer), let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription) else {
            state = nil
            return sampleBuffer
        }

        let sampleRateValue = streamDescription.pointee.mSampleRate
        let roundedSampleRate = sampleRateValue.rounded()
        guard sampleRateValue.isFinite, roundedSampleRate > 0.0, roundedSampleRate <= Double(Int32.max), abs(sampleRateValue - roundedSampleRate) < 0.001 else {
            state = nil
            return sampleBuffer
        }
        let sampleRate = CMTimeScale(roundedSampleRate)
        let sampleCountValue = Int64(sampleCount)

        guard var currentState = state, currentState.sampleRate == sampleRate else {
            state = AudioBufferTimingState(sampleRate: sampleRate, anchorPts: pts, nextSampleOffset: sampleCountValue)
            return sampleBuffer
        }

        let expectedPts = CMTimeAdd(currentState.anchorPts, CMTime(value: currentState.nextSampleOffset, timescale: currentState.sampleRate))
        let inputDelta = CMTimeSubtract(pts, expectedPts).seconds
        guard inputDelta.isFinite, abs(inputDelta) <= 2.0 / 1000.0 else {
            state = AudioBufferTimingState(sampleRate: sampleRate, anchorPts: pts, nextSampleOffset: sampleCountValue)
            return sampleBuffer
        }

        let normalizedSampleBuffer: CMSampleBuffer
        if CMTimeCompare(pts, expectedPts) == 0 {
            normalizedSampleBuffer = sampleBuffer
        } else {
            let timeOffset = CMTimeSubtract(expectedPts, pts)
            guard let updatedSampleBuffer = createSampleBuffer(fromSampleBuffer: sampleBuffer, withTimeOffset: timeOffset, duration: nil) else {
                state = AudioBufferTimingState(sampleRate: sampleRate, anchorPts: pts, nextSampleOffset: sampleCountValue)
                return sampleBuffer
            }
            normalizedSampleBuffer = updatedSampleBuffer
        }

        let (nextSampleOffset, overflow) = currentState.nextSampleOffset.addingReportingOverflow(sampleCountValue)
        if overflow {
            state = AudioBufferTimingState(sampleRate: sampleRate, anchorPts: pts, nextSampleOffset: sampleCountValue)
        } else {
            currentState.nextSampleOffset = nextSampleOffset
            state = currentState
        }
        return normalizedSampleBuffer
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
