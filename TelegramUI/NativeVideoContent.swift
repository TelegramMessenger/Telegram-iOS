import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

final class NativeVideoContent: UniversalVideoContent {
    let id: AnyHashable
    let file: TelegramMediaFile
    let dimensions: CGSize
    let duration: Int32
    
    init(file: TelegramMediaFile) {
        self.id = anyHashableFromMediaResourceId(file.resource.id)
        self.file = file
        self.dimensions = file.dimensions ?? CGSize(width: 128.0, height: 128.0)
        self.duration = file.duration ?? 0
    }
    
    func makeContentNode(account: Account) -> UniversalVideoContentNode & ASDisplayNode {
        return NativeVideoContentNode(account: account, audioSessionManager: account.telegramApplicationContext.mediaManager.audioSession, postbox: account.postbox, file: self.file)
    }
}

private final class NativeVideoContentNode: ASDisplayNode, UniversalVideoContentNode {
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
    
    init(account: Account, audioSessionManager: ManagedAudioSession, postbox: Postbox, file: TelegramMediaFile) {
        self.file = file
        
        self.imageNode = TransformImageNode()
        
        self.player = MediaPlayer(audioSessionManager: audioSessionManager, postbox: postbox, resource: file.resource, streamable: false, video: true, preferSoftwareDecoding: false, playAutomatically: false, enableSound: true)
        var actionAtEndImpl: (() -> Void)?
        self.player.actionAtEnd = .stop
        self.playerNode = MediaPlayerNode(backgroundThread: false)
        self.player.attachPlayerNode(self.playerNode)
        
        super.init()
        
        actionAtEndImpl = { [weak self] in
            if let strongSelf = self {
                for listener in strongSelf.playbackCompletedListeners.copyItems() {
                    listener()
                }
            }
        }
        
        self.imageNode.setSignal(account: account, signal: mediaGridMessageVideo(account: account, video: file))
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.playerNode)
        self._status.set(self.player.status)
    }
    
    deinit {
        self.player.pause()
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
            self.player.playOnceWithSound()
        } else {
            self.player.continuePlayingWithoutSound()
        }
    }
    
    func seek(_ timestamp: Double) {
        assert(Queue.mainQueue().isCurrent())
        self.player.seek(timestamp: timestamp)
    }
    
    func addPlaybackCompleted(_ f: @escaping () -> Void) -> Int {
        return self.playbackCompletedListeners.add(f)
    }
    
    func removePlaybackCompleted(_ index: Int) {
        self.playbackCompletedListeners.remove(index)
    }
}
