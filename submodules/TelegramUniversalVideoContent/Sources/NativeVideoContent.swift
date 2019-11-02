import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramAudio
import UniversalMediaPlayer
import AccountContext
import PhotoResources

public enum NativeVideoContentId: Hashable {
    case message(UInt32, MediaId)
    case instantPage(MediaId, MediaId)
    case contextResult(Int64, String)
}

public final class NativeVideoContent: UniversalVideoContent {
    public let id: AnyHashable
    public let nativeId: NativeVideoContentId
    public let fileReference: FileMediaReference
    let imageReference: ImageMediaReference?
    public let dimensions: CGSize
    public let duration: Int32
    public let streamVideo: MediaPlayerStreaming
    public let loopVideo: Bool
    public let enableSound: Bool
    public let baseRate: Double
    let fetchAutomatically: Bool
    let onlyFullSizeThumbnail: Bool
    let continuePlayingWithoutSoundOnLostAudioSession: Bool
    let placeholderColor: UIColor
    let tempFilePath: String?
    
    public init(id: NativeVideoContentId, fileReference: FileMediaReference, imageReference: ImageMediaReference? = nil, streamVideo: MediaPlayerStreaming = .none, loopVideo: Bool = false, enableSound: Bool = true, baseRate: Double = 1.0, fetchAutomatically: Bool = true, onlyFullSizeThumbnail: Bool = false, continuePlayingWithoutSoundOnLostAudioSession: Bool = false, placeholderColor: UIColor = .white, tempFilePath: String? = nil) {
        self.id = id
        self.nativeId = id
        self.fileReference = fileReference
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
        
        self.duration = fileReference.media.duration ?? 0
        self.streamVideo = streamVideo
        self.loopVideo = loopVideo
        self.enableSound = enableSound
        self.baseRate = baseRate
        self.fetchAutomatically = fetchAutomatically
        self.onlyFullSizeThumbnail = onlyFullSizeThumbnail
        self.continuePlayingWithoutSoundOnLostAudioSession = continuePlayingWithoutSoundOnLostAudioSession
        self.placeholderColor = placeholderColor
        self.tempFilePath = tempFilePath
    }
    
    public func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return NativeVideoContentNode(postbox: postbox, audioSessionManager: audioSession, fileReference: self.fileReference, imageReference: self.imageReference, streamVideo: self.streamVideo, loopVideo: self.loopVideo, enableSound: self.enableSound, baseRate: self.baseRate, fetchAutomatically: self.fetchAutomatically, onlyFullSizeThumbnail: self.onlyFullSizeThumbnail, continuePlayingWithoutSoundOnLostAudioSession: self.continuePlayingWithoutSoundOnLostAudioSession, placeholderColor: self.placeholderColor, tempFilePath: self.tempFilePath)
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

private final class NativeVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let postbox: Postbox
    private let fileReference: FileMediaReference
    private let player: MediaPlayer
    private let imageNode: TransformImageNode
    private let playerNode: MediaPlayerNode
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private let placeholderColor: UIColor
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _bufferingStatus = Promise<(IndexSet, Int)?>()
    var bufferingStatus: Signal<(IndexSet, Int)?, NoError> {
        return self._bufferingStatus.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let fetchDisposable = MetaDisposable()
    
    private var dimensions: CGSize?
    private let dimensionsPromise = ValuePromise<CGSize>(CGSize())
    
    private var validLayout: CGSize?
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, fileReference: FileMediaReference, imageReference: ImageMediaReference?, streamVideo: MediaPlayerStreaming, loopVideo: Bool, enableSound: Bool, baseRate: Double, fetchAutomatically: Bool, onlyFullSizeThumbnail: Bool, continuePlayingWithoutSoundOnLostAudioSession: Bool = false, placeholderColor: UIColor, tempFilePath: String?) {
        self.postbox = postbox
        self.fileReference = fileReference
        self.placeholderColor = placeholderColor
        
        self.imageNode = TransformImageNode()
        
        self.player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resourceReference: fileReference.resourceReference(fileReference.media.resource), tempFilePath: tempFilePath, streamable: streamVideo, video: true, preferSoftwareDecoding: false, playAutomatically: false, enableSound: enableSound, baseRate: baseRate, fetchAutomatically: fetchAutomatically, continuePlayingWithoutSoundOnLostAudioSession: continuePlayingWithoutSoundOnLostAudioSession)
        var actionAtEndImpl: (() -> Void)?
        if enableSound && !loopVideo {
            self.player.actionAtEnd = .action({
                actionAtEndImpl?()
            })
        } else {
            self.player.actionAtEnd = .loop({
                actionAtEndImpl?()
            })
        }
        self.playerNode = MediaPlayerNode(backgroundThread: false)
        self.player.attachPlayerNode(self.playerNode)
        
        self.dimensions = fileReference.media.dimensions?.cgSize
        if let dimensions = self.dimensions {
            self.dimensionsPromise.set(dimensions)
        }
        
        super.init()
        
        actionAtEndImpl = { [weak self] in
            self?.performActionAtEnd()
        }
        
        self.imageNode.setSignal(internalMediaGridMessageVideo(postbox: postbox, videoReference: fileReference, imageReference: imageReference, onlyFullSize: onlyFullSizeThumbnail, autoFetchFullSizeThumbnail: fileReference.media.isInstantVideo) |> map { [weak self] getSize, getData in
            Queue.mainQueue().async {
                if let strongSelf = self, strongSelf.dimensions == nil {
                    if let dimensions = getSize() {
                        strongSelf.dimensions = dimensions
                        strongSelf.dimensionsPromise.set(dimensions)
                        if let size = strongSelf.validLayout {
                            strongSelf.updateLayout(size: size, transition: .immediate)
                        }
                    }
                }
            }
            return getData
        })
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self._status.set(combineLatest(self.dimensionsPromise.get(), self.player.status)
        |> map { dimensions, status in
            return MediaPlayerStatus(generationTimestamp: status.generationTimestamp, duration: status.duration, dimensions: dimensions, timestamp: status.timestamp, baseRate: status.baseRate, seekId: status.seekId, status: status.status, soundEnabled: status.soundEnabled)
        })
        
        if let size = fileReference.media.size {
            self._bufferingStatus.set(postbox.mediaBox.resourceRangesStatus(fileReference.media.resource) |> map { ranges in
                return (ranges, size)
            })
        } else {
            self._bufferingStatus.set(.single(nil))
        }
        
        self.imageNode.imageUpdated = { [weak self] _ in
            self?._ready.set(.single(Void()))
        }
    }
    
    deinit {
        self.player.pause()
        self.fetchDisposable.dispose()
    }
    
    private func performActionAtEnd() {
        for listener in self.playbackCompletedListeners.copyItems() {
            listener()
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size
        
        if let dimensions = self.dimensions {
            let imageSize = CGSize(width: floor(dimensions.width / 2.0), height: floor(dimensions.height / 2.0))
            let makeLayout = self.imageNode.asyncLayout()
            let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: self.fileReference.media.isInstantVideo ? .clear : self.placeholderColor))
            applyLayout()
        }
        
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        self.playerNode.frame = CGRect(origin: CGPoint(), size: size).insetBy(dx: -1.0, dy: -1.0)
    }
    
    func play() {
        assert(Queue.mainQueue().isCurrent())
        self.player.play()
    }
    
    func pause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.pause()
    }
    
    func togglePlayPause() {
        assert(Queue.mainQueue().isCurrent())
        self.player.togglePlayPause()
    }
    
    func setSoundEnabled(_ value: Bool) {
        assert(Queue.mainQueue().isCurrent())
        if value {
            self.player.playOnceWithSound(playAndRecord: true)
        } else {
            self.player.continuePlayingWithoutSound()
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.player.seek(timestamp: timestamp)
    }
    
    func playOnceWithSound(playAndRecord: Bool, seek: MediaPlayerSeek, actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        switch actionAtEnd {
            case .loop:
                self.player.actionAtEnd = .loop({})
            case .loopDisablingSound:
                self.player.actionAtEnd = .loopDisablingSound(action)
            case .stop:
                self.player.actionAtEnd = .action(action)
            case .repeatIfNeeded:
                let _ = (self.player.status
                |> deliverOnMainQueue
                |> take(1)).start(next: { [weak self] status in
                    guard let strongSelf = self else {
                        return
                    }
                    if status.timestamp > status.duration * 0.1 {
                        strongSelf.player.actionAtEnd = .loop({ [weak self] in
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.player.actionAtEnd = .loopDisablingSound(action)
                        })
                    } else {
                        strongSelf.player.actionAtEnd = .loopDisablingSound(action)
                    }
                })
        }
        
        self.player.playOnceWithSound(playAndRecord: playAndRecord, seek: seek)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.setForceAudioToSpeaker(forceAudioToSpeaker)
    }
    
    func setBaseRate(_ baseRate: Double) {
        self.player.setBaseRate(baseRate)
    }
    
    func continuePlayingWithoutSound(actionAtEnd: MediaPlayerPlayOnceWithSoundActionAtEnd) {
        assert(Queue.mainQueue().isCurrent())
        let action = { [weak self] in
            Queue.mainQueue().async {
                self?.performActionAtEnd()
            }
        }
        switch actionAtEnd {
            case .loop:
                self.player.actionAtEnd = .loop({})
            case .loopDisablingSound, .repeatIfNeeded:
                self.player.actionAtEnd = .loopDisablingSound(action)
            case .stop:
                self.player.actionAtEnd = .action(action)
        }
        self.player.continuePlayingWithoutSound()
    }
    
    func setContinuePlayingWithoutSoundOnLostAudioSession(_ value: Bool) {
        self.player.setContinuePlayingWithoutSoundOnLostAudioSession(value)
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
                self.fetchDisposable.set(fetchedMediaResource(mediaBox: self.postbox.mediaBox, reference: self.fileReference.resourceReference(self.fileReference.media.resource), statsCategory: statsCategoryForFileWithAttributes(self.fileReference.media.attributes)).start())
            case .cancel:
                self.postbox.mediaBox.cancelInteractiveResourceFetch(self.fileReference.media.resource)
        }
    }
}
