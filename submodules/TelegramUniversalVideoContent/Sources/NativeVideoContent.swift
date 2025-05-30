import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramAudio
import UniversalMediaPlayer
import AccountContext
import PhotoResources
import UIKitRuntimeUtils
import RangeSet
import VideoToolbox

private extension CGRect {
    var center: CGPoint {
        return CGPoint(x: self.midX, y: self.midY)
    }
}

public enum NativeVideoContentId: Hashable {
    case message(UInt32, MediaId)
    case instantPage(MediaId, MediaId)
    case contextResult(Int64, String)
    case profileVideo(Int64, String?)
}

public final class NativeVideoContent: UniversalVideoContent {
    public let id: AnyHashable
    public let nativeId: NativeVideoContentId
    public let userLocation: MediaResourceUserLocation
    public let fileReference: FileMediaReference
    public let previewSourceFileReference: FileMediaReference?
    public let limitedFileRange: Range<Int64>?
    let imageReference: ImageMediaReference?
    public let dimensions: CGSize
    public let duration: Double
    public let streamVideo: MediaPlayerStreaming
    public let loopVideo: Bool
    public let enableSound: Bool
    public let soundMuted: Bool
    public let beginWithAmbientSound: Bool
    public let mixWithOthers: Bool
    public let baseRate: Double
    let fetchAutomatically: Bool
    let onlyFullSizeThumbnail: Bool
    let useLargeThumbnail: Bool
    let autoFetchFullSizeThumbnail: Bool
    public let startTimestamp: Double?
    let endTimestamp: Double?
    let continuePlayingWithoutSoundOnLostAudioSession: Bool
    let placeholderColor: UIColor
    let tempFilePath: String?
    let isAudioVideoMessage: Bool
    let captureProtected: Bool
    let hintDimensions: CGSize?
    let storeAfterDownload: (() -> Void)?
    let displayImage: Bool
    let hasSentFramesToDisplay: (() -> Void)?
    
    public static func isVideoCodecSupported(videoCodec: String, isHardwareAv1Supported: Bool, isSoftwareAv1Supported: Bool) -> Bool {
        if videoCodec == "h264" || videoCodec == "h265" || videoCodec == "avc" || videoCodec == "hevc" {
            return true
        }
        
        if videoCodec == "av1" || videoCodec == "av01" {
            return isHardwareAv1Supported || isSoftwareAv1Supported
        }
        
        return false
    }
    
    public static func isHLSVideo(file: TelegramMediaFile) -> Bool {
        for alternativeRepresentation in file.alternativeRepresentations {
            if alternativeRepresentation.mimeType == "application/x-mpegurl" {
                return true
            }
        }
        return false
    }
    
    public init(id: NativeVideoContentId, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, previewSourceFileReference: FileMediaReference? = nil, limitedFileRange: Range<Int64>? = nil, imageReference: ImageMediaReference? = nil, streamVideo: MediaPlayerStreaming = .none, loopVideo: Bool = false, enableSound: Bool = true, soundMuted: Bool = false, beginWithAmbientSound: Bool = false, mixWithOthers: Bool = false, baseRate: Double = 1.0, fetchAutomatically: Bool = true, onlyFullSizeThumbnail: Bool = false, useLargeThumbnail: Bool = false, autoFetchFullSizeThumbnail: Bool = false, startTimestamp: Double? = nil, endTimestamp: Double? = nil, continuePlayingWithoutSoundOnLostAudioSession: Bool = false, placeholderColor: UIColor = .white, tempFilePath: String? = nil, isAudioVideoMessage: Bool = false, captureProtected: Bool = false, hintDimensions: CGSize? = nil, storeAfterDownload: (() -> Void)?, displayImage: Bool = true, hasSentFramesToDisplay: (() -> Void)? = nil) {
        self.id = id
        self.nativeId = id
        self.userLocation = userLocation
        self.fileReference = fileReference
        self.previewSourceFileReference = previewSourceFileReference
        self.limitedFileRange = limitedFileRange
        self.imageReference = imageReference
        if var dimensions = fileReference.media.dimensions {
            if let thumbnail = fileReference.media.previewRepresentations.first {
                let dimensionsVertical = dimensions.width < dimensions.height
                let thumbnailVertical = thumbnail.dimensions.width < thumbnail.dimensions.height
                if dimensionsVertical != thumbnailVertical {
                    dimensions = PixelDimensions(width: dimensions.height, height: dimensions.width)
                }
            }
            self.dimensions = dimensions.cgSize
        } else {
            self.dimensions = CGSize(width: 128.0, height: 128.0)
        }
        
        self.duration = fileReference.media.duration ?? 0.0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.soundMuted = soundMuted
        self.beginWithAmbientSound = beginWithAmbientSound
        self.mixWithOthers = mixWithOthers
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
        self.onlyFullSizeThumbnail = onlyFullSizeThumbnail
        self.useLargeThumbnail = useLargeThumbnail
        self.autoFetchFullSizeThumbnail = autoFetchFullSizeThumbnail
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        self.placeholderColor = placeholderColor
        self.tempFilePath = tempFilePath
        self.captureProtected = captureProtected
        self.isAudioVideoMessage = isAudioVideoMessage
        self.hintDimensions = hintDimensions
        self.storeAfterDownload = storeAfterDownload
        self.displayImage = displayImage
        self.hasSentFramesToDisplay = hasSentFramesToDisplay
    }
    
    public func makeContentNode(context: AccountContext, postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return NativeVideoContentNode(context: context, postbox: postbox, audioSessionManager: audioSession, userLocation: self.userLocation, fileReference: self.fileReference, previewSourceFileReference: self.previewSourceFileReference, limitedFileRange: self.limitedFileRange, imageReference: self.imageReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, soundMuted: self.soundMuted, beginWithAmbientSound: self.beginWithAmbientSound, mixWithOthers: self.mixWithOthers, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically, onlyFullSizeThumbnail: self.onlyFullSizeThumbnail, useLargeThumbnail: self.useLargeThumbnail, autoFetchFullSizeThumbnail: self.autoFetchFullSizeThumbnail, startTimestamp: self.startTimestamp, endTimestamp: self.endTimestamp, continuePlayingWithoutSoundOnLostAudioSession: self.continuePlayingWithoutSoundOnLostAudioSession, placeholderColor: self.placeholderColor, tempFilePath: self.tempFilePath, isAudioVideoMessage: self.isAudioVideoMessage, captureProtected: self.captureProtected, hintDimensions: self.hintDimensions, storeAfterDownload: self.storeAfterDownload, displayImage: self.displayImage, hasSentFramesToDisplay: self.hasSentFramesToDisplay)
    }
    
    public func isEqual(to other: UniversalVideoContent) -> Bool {
        if let other = other as? NativeVideoContent {
            if case let .message(stableId, _) = self.nativeId {
                if case .message(stableId, _) = other.nativeId {
                    if self.fileReference.media.isInstantVideo {
                        return true
                    }
                }
            }
        }
        return false
    }
}

private enum PlayerImpl {
    case legacy(MediaPlayer)
    case chunked(ChunkMediaPlayerV2)
    
    var actionAtEnd: MediaPlayerActionAtEnd {
        get {
            switch self {
            case let .legacy(player):
                return player.actionAtEnd
            case let .chunked(player):
                return player.actionAtEnd
            }
        } set(value) {
            switch self {
            case let .legacy(player):
                player.actionAtEnd = value
            case let .chunked(player):
                player.actionAtEnd = value
            }
        }
    }
    
    var status: Signal<MediaPlayerStatus, NoError> {
        switch self {
        case let .legacy(player):
            return player.status
        case let .chunked(player):
            return player.status
        }
    }
    
    func play() {
        switch self {
        case let .legacy(player):
            player.play()
        case let .chunked(player):
            player.play()
        }
    }
    
    func pause() {
        switch self {
        case let .legacy(player):
            player.pause()
        case let .chunked(player):
            player.pause()
        }
    }
    
    func togglePlayPause(faded: Bool = false) {
        switch self {
        case let .legacy(player):
            player.togglePlayPause(faded: faded)
        case let .chunked(player):
            player.togglePlayPause(faded: faded)
        }
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek = .start) {
        switch self {
        case let .legacy(player):
            player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
        case let .chunked(player):
            player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
        }
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
        switch self {
        case let .legacy(player):
            player.continueWithOverridingAmbientMode(isAmbient: isAmbient)
        case let .chunked(player):
            player.continueWithOverridingAmbientMode(isAmbient: isAmbient)
        }
    }
    
    func continuePlayingWithoutSound(seek: MediaPlayerSeek = .start) {
        switch self {
        case let .legacy(player):
            player.continuePlayingWithoutSound(seek: seek)
        case let .chunked(player):
            player.continuePlayingWithoutSound(seek: seek)
        }
    }
    
    func seek(timestamp: Double, play: Bool? = nil) {
        switch self {
        case let .legacy(player):
            player.seek(timestamp: timestamp, play: play)
        case let .chunked(player):
            player.seek(timestamp: timestamp, play: play)
        }
    }
    
    func setForceAudioToSpeaker(_ value: Bool) {
        switch self {
        case let .legacy(player):
            player.setForceAudioToSpeaker(value)
        case let .chunked(player):
            player.setForceAudioToSpeaker(value)
        }
    }
    
    func setSoundMuted(soundMuted: Bool) {
        switch self {
        case let .legacy(player):
            player.setSoundMuted(soundMuted: soundMuted)
        case let .chunked(player):
            player.setSoundMuted(soundMuted: soundMuted)
        }
    }
    
    func setBaseRate(_ baseRate: Double) {
        switch self {
        case let .legacy(player):
            player.setBaseRate(baseRate)
        case let .chunked(player):
            player.setBaseRate(baseRate)
        }
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        switch self {
        case let .legacy(player):
            player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
        case let .chunked(player):
            player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
        }
    }
}

public extension ChunkMediaPlayerV2.MediaDataReaderParams {
    init(context: AccountContext) {
        var useV2Reader = true
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_video_v2_reader2"] as? Double {
            useV2Reader = value != 0.0
        }
        
        self.init(useV2Reader: useV2Reader)
    }
}

private final class NativeVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let postbox: Postbox
    private let userLocation: MediaResourceUserLocation
    private let fileReference: FileMediaReference
    private let previewSourceFileReference: FileMediaReference?
    private let limitedFileRange: Range<Int64>?
    private let streamVideo: MediaPlayerStreaming
    private let enableSound: Bool
    private let soundMuted: Bool
    private let beginWithAmbientSound: Bool
    private let mixWithOthers: Bool
    private let loopVideo: Bool
    private let baseRate: Double
    private let audioSessionManager: ManagedAudioSession
    private let isAudioVideoMessage: Bool
    private let captureProtected: Bool
    private let continuePlayingWithoutSoundOnLostAudioSession: Bool
    private let displayImage: Bool
    
    private var player: PlayerImpl?
    private var thumbnailPlayer: MediaPlayer?
    private let imageNode: TransformImageNode
    private let playerNode: MediaPlayerNode
    private var thumbnailNode: MediaPlayerNode?
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private let placeholderColor: UIColor
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    private let _thumbnailStatus = Promise<MediaPlayerStatus?>(nil)
    var status: Signal<MediaPlayerStatus, NoError> {
        return combineLatest(self._thumbnailStatus.get(), self._status.get())
        |> map { thumbnailStatus, status in
            switch status.status {
            case .buffering:
                if let thumbnailStatus = thumbnailStatus {
                    return thumbnailStatus
                } else {
                    return status
                }
            default:
                return status
            }
        }
    }
    
    private let _bufferingStatus = Promise<(RangeSet<Int64>, Int64)?>()
    var bufferingStatus: Signal<(RangeSet<Int64>, Int64)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    var isNativePictureInPictureActive: Signal<Bool, NoError> {
        return .single(false)
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private var initializePlayerDisposable: Disposable?
    private let fetchDisposable = MetaDisposable()
    private let fetchStatusDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: (size: CGSize, actualSize: CGSize)?
    
    private var shouldPlay: Bool = false
    private var pendingSetSoundEnabled: Bool?
    private var pendingSeek: Double?
    private var pendingPlayOnceWithSound: (playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd)?
    private var pendingForceAudioToSpeaker: Bool?
    private var pendingSetSoundMuted: Bool?
    private var pendingContinueWithOverridingAmbientMode: Bool?
    private var pendingSetBaseRate: Double?
    private var pendingContinuePlayingWithoutSound: MediaPlayerPlayOnceWithSoundActionAtEnd?
    private var pendingSetContinuePlayingWithoutSoundOnLostAudioSession: Bool?
    
    private let hasSentFramesToDisplay: (() -> Void)?
    
    init(context: AccountContext, postbox: Postbox, audioSessionManager: ManagedAudioSession, userLocation: MediaResourceUserLocation, fileReference: FileMediaReference, previewSourceFileReference: FileMediaReference?, limitedFileRange: Range<Int64>?, imageReference: ImageMediaReference?, streamVideo: MediaPlayerStreaming, loopVideo: Bool, enableSound: Bool, soundMuted: Bool, beginWithAmbientSound: Bool, mixWithOthers: Bool, baseRate: Double, fetchAutomatically: Bool, onlyFullSizeThumbnail: Bool, useLargeThumbnail: Bool, autoFetchFullSizeThumbnail: Bool, startTimestamp: Double?, endTimestamp: Double?, continuePlayingWithoutSoundOnLostAudioSession: Bool = false, placeholderColor: UIColor, tempFilePath: String?, isAudioVideoMessage: Bool, captureProtected: Bool, hintDimensions: CGSize?, storeAfterDownload: (() -> Void)? = nil, displayImage: Bool, hasSentFramesToDisplay: (() -> Void)?) {
        self.postbox = postbox
        self.userLocation = userLocation
        self.fileReference = fileReference
        self.previewSourceFileReference = previewSourceFileReference
        self.limitedFileRange = limitedFileRange
        self.streamVideo = streamVideo
        self.placeholderColor = placeholderColor
        self.enableSound = enableSound
        self.soundMuted = soundMuted
        self.beginWithAmbientSound = beginWithAmbientSound
        self.mixWithOthers = mixWithOthers
        self.loopVideo = loopVideo
        self.baseRate = baseRate
        self.audioSessionManager = audioSessionManager
        self.isAudioVideoMessage = isAudioVideoMessage
        self.captureProtected = captureProtected
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        self.displayImage = displayImage
        self.hasSentFramesToDisplay = hasSentFramesToDisplay
        
        self.imageNode = TransformImageNode()
        
        var userContentType = MediaResourceUserContentType(file: fileReference.media)
        switch fileReference {
        case .story:
            userContentType = .story
        default:
            break
        }
        
        let selectedFile = fileReference.media
        
        self.playerNode = MediaPlayerNode(backgroundThread: false, captureProtected: captureProtected)
        
        self.dimensions = fileReference.media.dimensions?.cgSize
        if let dimensions = self.dimensions {
            self.dimensionsPromise.set(dimensions)
        }
        
        super.init()
        
        var didProcessFramesToDisplay = false
        self.playerNode.isHidden = true
        self.playerNode.hasSentFramesToDisplay = { [weak self] in
            guard let self, !didProcessFramesToDisplay else {
                return
            }
            didProcessFramesToDisplay = true
            self.playerNode.isHidden = false
            self.hasSentFramesToDisplay?()
        }
        
        if let dimensions = hintDimensions {
            self.dimensions = dimensions
            self.dimensionsPromise.set(dimensions)
        }
        
        if displayImage {
            if captureProtected {
                setLayerDisableScreenshots(self.imageNode.layer, captureProtected)
            }
            
            self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, userLocation: userLocation, videoReference: fileReference, previewSourceFileReference: previewSourceFileReference, imageReference: imageReference, onlyFullSize: onlyFullSizeThumbnail, useLargeThumbnail: useLargeThumbnail, autoFetchFullSizeThumbnail: autoFetchFullSizeThumbnail || fileReference.media.isInstantVideo) |> map { [weak self] getSize, getData in
                Queue.mainQueue().async {
                    if let strongSelf = self, strongSelf.dimensions == nil {
                        if let dimensions = getSize() {
                            strongSelf.dimensions = dimensions
                            strongSelf.dimensionsPromise.set(dimensions)
                            if let validLayout = strongSelf.validLayout {
                                strongSelf.updateLayout(size: validLayout.size, actualSize: validLayout.actualSize, transition: .immediate)
                            }
                        }
                    }
                }
                return getData
            })
            
            self.addSubnode(self.imageNode)
        }
        
        self.addSubnode(self.playerNode)
        
        self.fetchStatusDisposable.set((postbox.mediaBox.resourceStatus(selectedFile.resource)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            guard let strongSelf = self else {
                return
            }
            switch status {
            case .Local:
                break
            default:
                if strongSelf.thumbnailPlayer == nil {
                    strongSelf.createThumbnailPlayer()
                }
            }
        }))
        
        if let size = selectedFile.size {
            self._bufferingStatus.set(postbox.mediaBox.resourceRangesStatus(selectedFile.resource) |> map { ranges in
                return (ranges, size)
            })
        } else {
            self._bufferingStatus.set(.single(nil))
        }
        
        if self.displayImage {
            self.imageNode.imageUpdated = { [weak self] _ in
                self?._ready.set(.single(Void()))
            }
        } else {
            self._ready.set(.single(Void()))
        }
        
        if let startTimestamp = startTimestamp {
            self.seek(startTimestamp)
        }
        
        var useLegacyImplementation = !context.sharedContext.immediateExperimentalUISettings.playerV2
        if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_video_legacyplayer"] as? Double {
            useLegacyImplementation = value != 0.0
        }
        
        if useLegacyImplementation {
            let mediaPlayer = MediaPlayer(
                audioSessionManager: audioSessionManager,
                postbox: postbox,
                userLocation: userLocation,
                userContentType: userContentType,
                resourceReference: fileReference.resourceReference(selectedFile.resource),
                tempFilePath: tempFilePath,
                limitedFileRange: limitedFileRange,
                streamable: streamVideo,
                video: true,
                preferSoftwareDecoding: false,
                playAutomatically: false,
                enableSound: enableSound,
                baseRate: baseRate,
                fetchAutomatically: fetchAutomatically,
                soundMuted: soundMuted,
                ambient: beginWithAmbientSound,
                mixWithOthers: mixWithOthers,
                continuePlayingWithoutSoundOnLostAudioSession: continuePlayingWithoutSoundOnLostAudioSession,
                storeAfterDownload: storeAfterDownload,
                isAudioVideoMessage: isAudioVideoMessage
            )
            mediaPlayer.attachPlayerNode(self.playerNode)
            self.initializePlayer(player: .legacy(mediaPlayer))
        } else {
            let mediaPlayer = ChunkMediaPlayerV2(
                params: ChunkMediaPlayerV2.MediaDataReaderParams(context: context),
                audioSessionManager: audioSessionManager,
                source: .directFetch(ChunkMediaPlayerV2.SourceDescription.ResourceDescription(
                    postbox: postbox,
                    size: selectedFile.size ?? 0,
                    reference: fileReference.resourceReference(selectedFile.resource),
                    userLocation: userLocation,
                    userContentType: userContentType,
                    statsCategory: statsCategoryForFileWithAttributes(fileReference.media.attributes),
                    fetchAutomatically: fetchAutomatically
                )),
                video: true,
                playAutomatically: false,
                enableSound: enableSound,
                baseRate: baseRate,
                soundMuted: soundMuted,
                ambient: beginWithAmbientSound,
                mixWithOthers: mixWithOthers,
                continuePlayingWithoutSoundOnLostAudioSession: continuePlayingWithoutSoundOnLostAudioSession,
                isAudioVideoMessage: isAudioVideoMessage,
                playerNode: self.playerNode
            )
            self.initializePlayer(player: .chunked(mediaPlayer))
        }
    }
    
    deinit {
        self.initializePlayerDisposable?.dispose()
        self.player?.pause()
        self.thumbnailPlayer?.pause()
        self.fetchDisposable.dispose()
        self.fetchStatusDisposable.dispose()
    }
    
    private func initializePlayer(player: PlayerImpl) {
        var player = player
        self.player = player
        
        var actionAtEndImpl: (() -> Void)?
        if self.enableSound && !self.loopVideo {
            player.actionAtEnd = .action({
                actionAtEndImpl?()
            })
        } else {
            player.actionAtEnd = .loop({
                actionAtEndImpl?()
            })
        }
        actionAtEndImpl = { [weak self] in
            self?.performActionAtEnd()
        }
        
        self._status.set(combineLatest(self.dimensionsPromise.get(), player.status)
        |> map { dimensions, status in
            return MediaPlayerStatus(generationTimestamp: status.generationTimestamp, duration: status.duration, dimensions: dimensions, timestamp: status.timestamp, baseRate: status.baseRate, seekId: status.seekId, status: status.status, soundEnabled: status.soundEnabled)
        })
        
        if self.shouldPlay {
            player.play()
        } else {
            player.pause()
        }
        
        if let pendingSeek = self.pendingSeek {
            self.pendingSeek = nil
            self.seek(pendingSeek)
        }
        if let pendingSetSoundEnabled = self.pendingSetSoundEnabled {
            self.pendingSetSoundEnabled = nil
            self.setSoundEnabled(pendingSetSoundEnabled)
        }
        if let pendingPlayOnceWithSound = self.pendingPlayOnceWithSound {
            self.pendingPlayOnceWithSound = nil
            self.playOnceWithSound(playAndRecord: pendingPlayOnceWithSound.playAndRecord, seek: pendingPlayOnceWithSound.seek, actionAtEnd: pendingPlayOnceWithSound.actionAtEnd)
        }
        if let pendingForceAudioToSpeaker = self.pendingForceAudioToSpeaker {
            self.pendingForceAudioToSpeaker = nil
            self.setForceAudioToSpeaker(pendingForceAudioToSpeaker)
        }
        if let pendingSetSoundMuted = self.pendingSetSoundMuted {
            self.pendingSetSoundMuted = nil
            self.setSoundMuted(soundMuted: pendingSetSoundMuted)
        }
        if let pendingContinueWithOverridingAmbientMode = self.pendingContinueWithOverridingAmbientMode {
            self.pendingContinueWithOverridingAmbientMode = nil
            self.continueWithOverridingAmbientMode(isAmbient: pendingContinueWithOverridingAmbientMode)
        }
        if let pendingSetBaseRate = self.pendingSetBaseRate {
            self.pendingSetBaseRate = nil
            self.setBaseRate(pendingSetBaseRate)
        }
        if let pendingContinuePlayingWithoutSound = self.pendingContinuePlayingWithoutSound {
            self.pendingContinuePlayingWithoutSound = nil
            self.continuePlayingWithoutSound(actionAtEnd: pendingContinuePlayingWithoutSound)
        }
        if let pendingSetContinuePlayingWithoutSoundOnLostAudioSession = self.pendingSetContinuePlayingWithoutSoundOnLostAudioSession {
            self.pendingSetContinuePlayingWithoutSoundOnLostAudioSession = nil
            self.setContinuePlayingWithoutSoundOnLostAudioSession(pendingSetContinuePlayingWithoutSoundOnLostAudioSession)
        }
    }
    
    private func createThumbnailPlayer() {
        guard let videoThumbnail = self.fileReference.media.videoThumbnails.first else {
            return
        }
        
        let thumbnailPlayer = MediaPlayer(audioSessionManager: self.audioSessionManager, postbox: postbox, userLocation: self.userLocation, userContentType: MediaResourceUserContentType(file: self.fileReference.media), resourceReference: self.fileReference.resourceReference(videoThumbnail.resource), tempFilePath: nil, streamable: .none, video: true, preferSoftwareDecoding: false, playAutomatically: false, enableSound: false, baseRate: self.baseRate, fetchAutomatically: false, continuePlayingWithoutSoundOnLostAudioSession: false)
        self.thumbnailPlayer = thumbnailPlayer
        
        var actionAtEndImpl: (() -> Void)?
        if self.enableSound && !self.loopVideo {
            thumbnailPlayer.actionAtEnd = .action({
                actionAtEndImpl?()
            })
        } else {
            thumbnailPlayer.actionAtEnd = .loop({
                actionAtEndImpl?()
            })
        }
        
        actionAtEndImpl = { [weak self] in
            self?.performActionAtEnd()
        }
        
        let thumbnailNode = MediaPlayerNode(backgroundThread: false)
        self.thumbnailNode = thumbnailNode
        thumbnailPlayer.attachPlayerNode(thumbnailNode)
        
        self._thumbnailStatus.set(thumbnailPlayer.status
        |> map { status in
            return MediaPlayerStatus(generationTimestamp: status.generationTimestamp, duration: status.duration, dimensions: CGSize(), timestamp: status.timestamp, baseRate: status.baseRate, seekId: status.seekId, status: status.status, soundEnabled: status.soundEnabled)
        })
        
        self.addSubnode(thumbnailNode)
        
        thumbnailNode.frame = self.playerNode.frame
        
        if self.shouldPlay {
            thumbnailPlayer.play()
        }
        
        var processedSentFramesToDisplay = false
        thumbnailNode.hasSentFramesToDisplay = { [weak self] in
            guard !processedSentFramesToDisplay, let strongSelf = self else {
                return
            }
            processedSentFramesToDisplay = true
            
            strongSelf.hasSentFramesToDisplay?()
            
            Queue.mainQueue().after(0.1, {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.thumbnailNode?.isHidden = true
                strongSelf.thumbnailPlayer?.pause()
            })
        }
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, actualSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, actualSize)
        
        if let dimensions = self.dimensions {
            let imageSize = CGSize(width: floor(dimensions.width / 2.0), height: floor(dimensions.height / 2.0))
            let makeLayout = self.imageNode.asyncLayoutWithAnimation()
            let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: self.fileReference.media.isInstantVideo ? .clear : self.placeholderColor))
            let mappedAnimation: ListViewItemUpdateAnimation
            if case let .animated(duration, curve) = transition {
                mappedAnimation = .System(duration: duration, transition: ControlledTransition(duration: duration, curve: curve, interactive: false))
            } else {
                mappedAnimation = .None
            }
            applyLayout(mappedAnimation)
        }
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: size))
        let fromFrame = self.playerNode.frame
        let toFrame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0)
        if case let .animated(duration, curve) = transition, fromFrame != toFrame, !fromFrame.width.isZero, !fromFrame.height.isZero, !toFrame.width.isZero, !toFrame.height.isZero {
            let _ = duration
            let _ = curve
            self.playerNode.position = toFrame.center
            self.playerNode.bounds = CGRect(origin: CGPoint(), size: toFrame.size)
            self.playerNode.updateLayout()
            transition.animatePosition(node: self.playerNode, from: CGPoint(x: fromFrame.center.x, y: fromFrame.center.y))
            
            let transform = CATransform3DScale(CATransform3DIdentity, fromFrame.width / toFrame.width, fromFrame.height / toFrame.height, 1.0)
            self.playerNode.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: curve.timingFunction, duration: duration)
        } else {
            transition.updatePosition(node: self.playerNode, position: toFrame.center)
            transition.updateBounds(node: self.playerNode, bounds: CGRect(origin: CGPoint(), size: toFrame.size))
            self.playerNode.updateLayout()
        }
        if let thumbnailNode = self.thumbnailNode {
            transition.updateFrame(node: thumbnailNode, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0))
        }
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        self.player?.play()
        self.shouldPlay = true
        self.thumbnailPlayer?.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player?.pause()
        self.shouldPlay = false
        self.thumbnailPlayer?.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.player?.togglePlayPause()
        self.shouldPlay = !self.shouldPlay
        self.thumbnailPlayer?.togglePlayPause()
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if let player = self.player {
            if value {
                player.playOnceWithSound(playAndRecord: false, seek: .none)
            } else {
                player.continuePlayingWithoutSound(seek: .none)
            }
        } else {
            self.pendingSetSoundEnabled = value
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        if let player = self.player {
            player.seek(timestamp: timestamp)
        } else {
            self.pendingSeek = timestamp
        }
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        
        guard var player = self.player else {
            self.pendingPlayOnceWithSound = (playAndRecord, seek, actionAtEnd)
            return
        }
        
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        switch actionAtEnd {
            case .loop:
                player.actionAtEnd = .loop({})
            case .loopDisablingSound:
                player.actionAtEnd = .loopDisablingSound(action)
            case .stop:
                player.actionAtEnd = .action(action)
            case .repeatIfNeeded:
                let _ = (player.status
                |> deliverOnMainQueue
                |> take(1)).start(next: { [weak self] status in
                    guard let strongSelf = self, var player = strongSelf.player else {
                        return
                    }
                    if status.timestamp > status.duration * 0.1 {
                        player.actionAtEnd = .loop({ [weak self] in
                            guard let strongSelf = self, var player = strongSelf.player else {
                                return
                            }
                            player.actionAtEnd = .loopDisablingSound(action)
                        })
                    } else {
                        player.actionAtEnd = .loopDisablingSound(action)
                    }
                })
        }
        
        player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if let player = self.player {
            player.setForceAudioToSpeaker(forceAudioToSpeaker)
        } else {
            self.pendingForceAudioToSpeaker = forceAudioToSpeaker
        }
    }
    
    func setSoundMuted(soundMuted: Bool) {
        if let player = self.player {
            player.setSoundMuted(soundMuted: soundMuted)
        } else {
            self.pendingSetSoundMuted = soundMuted
        }
    }
    
    func continueWithOverridingAmbientMode(isAmbient: Bool) {
        if let player = self.player {
            player.continueWithOverridingAmbientMode(isAmbient: isAmbient)
        } else {
            self.pendingContinueWithOverridingAmbientMode = isAmbient
        }
    }
    
    func setBaseRate(_ baseRate: Double) {
        if let player = self.player {
            player.setBaseRate(baseRate)
        } else {
            self.pendingSetBaseRate = baseRate
        }
    }
    
    func setVideoQuality(_ quality: UniversalVideoContentVideoQuality) {
    }
    
    func videoQualityState() -> (current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])? {
        return nil
    }
    
    func videoQualityStateSignal() -> Signal<(current: Int, preferred: UniversalVideoContentVideoQuality, available: [Int])?, NoError> {
        return .single(nil)
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        
        guard var player = self.player else {
            self.pendingContinuePlayingWithoutSound = actionAtEnd
            return
        }
        
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        switch actionAtEnd {
        case .loop:
            player.actionAtEnd = .loop({})
        case .loopDisablingSound, .repeatIfNeeded:
            player.actionAtEnd = .loopDisablingSound(action)
        case .stop:
            player.actionAtEnd = .action(action)
        }
        player.continuePlayingWithoutSound()
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        if let player = self.player {
            player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
        } else {
            self.pendingSetContinuePlayingWithoutSoundOnLostAudioSession = value
        }
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
    
    func fetchControl(_ control: UniversalVideoNodeFetchControl) {
        switch control {
            case .fetch:
            self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.postbox.mediaBox, userLocation: self.userLocation, userContentType: .video, reference: self.fileReference.resourceReference(self.fileReference.media.resource), statsCategory: statsCategoryForFileWithAttributes(self.fileReference.media.attributes)).start())
            case .cancel:
                self.postbox.mediaBox.cancelInteractiveResourceFetch(self.fileReference.media.resource)
        }
    }
    
    func notifyPlaybackControlsHidden(_ hidden: Bool) {
    }

    func setCanPlaybackWithoutHierarchy(_ canPlaybackWithoutHierarchy: Bool) {
        self.playerNode.setCanPlaybackWithoutHierarchy(canPlaybackWithoutHierarchy)
    }
    
    func enterNativePictureInPicture() -> Bool {
        return false
    }
    
    func exitNativePictureInPicture() {
    }
    
    func setNativePictureInPictureIsActive(_ value: Bool) {
        self.imageNode.isHidden = value
    }
}
