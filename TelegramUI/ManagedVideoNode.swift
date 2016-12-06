import Foundation
import AsyncDisplayKit
import SwiftSignalKit
import Postbox
import TelegramCore

class ManagedVideoNode: ASDisplayNode {
    private var videoContext: ManagedVideoContext?
    private let videoContextDisposable = MetaDisposable()
    var transformArguments: TransformImageArguments? {
        didSet {
            self.videoContext?.playerNode.transformArguments = self.transformArguments
        }
    }
    
    deinit {
        self.videoContextDisposable.dispose()
    }
    
    func clearContext() {
        self.videoContextDisposable.set(nil)
    }
    
    func acquireContext(account: Account, mediaManager: MediaManager, id: ManagedMediaId, resource: MediaResource) {
        self.videoContextDisposable.set((mediaManager.videoContext(account: account, id: id, resource: resource) |> deliverOnMainQueue).start(next: { [weak self] videoContext in
            if let strongSelf = self {
                if strongSelf.videoContext !== videoContext {
                    if let videoContext = strongSelf.videoContext {
                        if videoContext.playerNode.supernode == self {
                            videoContext.playerNode.removeFromSupernode()
                        }
                    }
                    
                    strongSelf.videoContext = videoContext
                    if let videoContext = videoContext {
                        strongSelf.addSubnode(videoContext.playerNode)
                        videoContext.playerNode.transformArguments = strongSelf.transformArguments
                        strongSelf.setNeedsLayout()
                        videoContext.mediaPlayer.play()
                    }
                }
            }
        }))
    }
    
    override func layout() {
        super.layout()
        
        if let videoContext = videoContext {
            videoContext.playerNode.frame = self.bounds
        }
    }
}
