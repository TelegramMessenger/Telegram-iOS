import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

enum NativeVideoContentId: Hashable {
    case message(MessageId, MediaId)
    case instantPage(MediaId, MediaId)
    
    static func ==(lhs: NativeVideoContentId, rhs: NativeVideoContentId) -> Bool {
        switch lhs {
            case let .message(messageId, mediaId):
                if case .message(messageId, mediaId) = rhs {
                    return true
                } else {
                    return false
                }
            case let .instantPage(pageId, mediaId):
                if case .instantPage(pageId, mediaId) = rhs {
                    return true
                } else {
                    return false
                }
        }
    }
    
    var hashValue: Int {
        switch self {
            case let .message(messageId, mediaId):
                return messageId.hashValue &* 31 &+ mediaId.hashValue
            case let .instantPage(pageId, mediaId):
                return pageId.hashValue &* 31 &+ mediaId.hashValue
        }
    }
}

final class NativeVideoContent: UniversalVideoContent {
    let id: AnyHashable
    let file: TelegramMediaFile
    let dimensions: CGSize
    let duration: Int32
    let streamVideo: Bool
    let enableSound: Bool
    
    init(id: NativeVideoContentId, file: TelegramMediaFile, streamVideo: Bool = false, enableSound: Bool = true) {
        self.id = id
        self.file = file
        self.dimensions = file.dimensions ?? CGSize(width: 128.0, height: 128.0)
        self.duration = file.duration ?? 0
        self.streamVideo = streamVideo
        self.enableSound = enableSound
    }
    
    func makeContentNode(postbox: Postbox, audioSession: ManagedAudioSession) -> UniversalVideoContentNode & ASDisplayNode {
        return NativeVideoContentNode(postbox: postbox, audioSessionManager: audioSession, file: self.file, streamVideo: self.streamVideo, enableSound: self.enableSound)
    }
}

private final class NativeVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
    private let postbox: Postbox
    private let file: TelegramMediaFile
    private let player: MediaPlayer
    private let imageNode: TransformImageNode
    private let playerNode: MediaPlayerNode
    private let playbackCompletedListeners = Bag<() -> Void>()
    
    private var initializedStatus = false
    private let _status = Promise<MediaPlayerStatus>()
    var status: Signal<MediaPlayerStatus, NoError> {
        return self._status.get()
    }
    
    private let _ready = Promise<Void>()
    var ready: Signal<Void, NoError> {
        return self._ready.get()
    }
    
    private let fetchDisposable = MetaDisposable()
    
    init(postbox: Postbox, audioSessionManager: ManagedAudioSession, file: TelegramMediaFile, streamVideo: Bool, enableSound: Bool) {
        self.postbox = postbox
        self.file = file
        
        self.imageNode = TransformImageNode()
        
        self.player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resource: file.resource, streamable: streamVideo, video: true, preferSoftwareDecoding: false, playAutomatically: false, enableSound: enableSound)
        var actionAtEndImpl: (() -> Void)?
        if enableSound {
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
        
        super.init()
        
        actionAtEndImpl = { [weak self] in
            self?.performActionAtEnd()
        }
        
        self.imageNode.setSignal(mediaGridMessageVideo(postbox: postbox, video: file))
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self._status.set(self.player.status)
        
        self.imageNode.imageUpdated = { [weak self] in
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
        if let dimensions = self.file.dimensions {
            let imageSize = CGSize(width: floor(dimensions.width / 2.0), height: floor(dimensions.height / 2.0))
            let makeLayout = self.imageNode.asyncLayout()
            let applyLayout = makeLayout(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))
            applyLayout()
        }
        
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        self.playerNode.frame = CGRect(origin: CGPoint(), size: size)
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
    
    func playOnceWithSound(playAndRecord: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.actionAtEnd = .loopDisablingSound({ [weak self] in
            self?.performActionAtEnd()
        })
        self.player.playOnceWithSound(playAndRecord: playAndRecord)
    }
    
    func setForceAudioToSpeaker(_ forceAudioToSpeaker: Bool) {
        assert(Queue.mainQueue().isCurrent())
        self.player.setForceAudioToSpeaker(forceAudioToSpeaker)
    }
    
    func continuePlayingWithoutSound() {
        assert(Queue.mainQueue().isCurrent())
        self.player.continuePlayingWithoutSound()
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
                self.fetchDisposable.set(self.postbox.mediaBox.fetchedResource(self.file.resource, tag: TelegramMediaResourceFetchTag(statsCategory: MediaResourceStatsCategory.video)).start())
            case .cancel:
                self.postbox.mediaBox.cancelInteractiveResourceFetch(self.file.resource)
        }
    }
}
