import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ManagedVideoNode: ASDisplayNode {
    private let thumbnailNode: TransformImageNode
    
    private var videoPlayer: MediaPlayer?
    private var playerNode: MediaPlayerNode?
    private let videoContextDisposable = MetaDisposable()
    var transformArguments: TransformImageArguments? {
        didSet {
            self.playerNode?.transformArguments = self.transformArguments
        }
    }
    
    private let _player = Promise<MediaPlayer?>(nil)
    var player: Signal<MediaPlayer?, NoError> {
        return self._player.get()
    }
    
    let preferSoftwareDecoding: Bool
    let backgroundThread: Bool
    
    init(preferSoftwareDecoding: Bool = false, backgroundThread: Bool = true) {
        self.preferSoftwareDecoding = preferSoftwareDecoding
        self.backgroundThread = backgroundThread
        
        self.thumbnailNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.thumbnailNode)
    }
    
    deinit {
        self.videoContextDisposable.dispose()
    }
    
    func clearContext() {
        self.videoContextDisposable.set(nil)
    }
    
    func acquireContext(account: Account, mediaManager: MediaManager, id: ManagedMediaId, resource: MediaResource, priority: Int32) {
        let (player, disposable) = mediaManager.videoContext(postbox: account.postbox, id: id, resource: resource, preferSoftwareDecoding: false, backgroundThread: false, priority: priority, initiatePlayback: true, activate: { [weak self] playerNode in
            if let strongSelf = self {
                if strongSelf.playerNode !== playerNode {
                    if strongSelf.playerNode?.supernode === self {
                        strongSelf.playerNode?.removeFromSupernode()
                    }
                    strongSelf.playerNode = playerNode
                    strongSelf.addSubnode(playerNode)
                    playerNode.transformArguments = strongSelf.transformArguments
                    strongSelf.setNeedsLayout()
                }
            }
        }, deactivate: { [weak self] in
            if let strongSelf = self {
                if let playerNode = strongSelf.playerNode {
                    strongSelf.playerNode = nil
                    if playerNode.supernode === strongSelf {
                        playerNode.removeFromSupernode()
                    }
                }
                return .complete()
            } else {
                return .complete()
            }
        })
        
        self._player.set(.single(player))
        self.videoContextDisposable.set(disposable)
    }
    
    func discardContext() {
        self._player.set(.single(nil))
        if let playerNode = self.playerNode {
            self.playerNode = nil
            if playerNode.supernode === self {
                playerNode.removeFromSupernode()
            }
        }
        self.videoContextDisposable.set(nil)
    }
    
    override func layout() {
        super.layout()
        
        self.playerNode?.frame = self.bounds
    }
}
