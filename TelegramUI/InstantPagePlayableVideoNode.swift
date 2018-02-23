import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class InstantPagePlayableVideoNode: ASDisplayNode, InstantPageNode {
    private let account: Account
    let media: InstantPageMedia
    private let interactive: Bool
    private let openMedia: (InstantPageMedia) -> Void
    
    private let imageNode: TransformImageNode
    private let videoNode: ManagedVideoNode
    
    private var currentSize: CGSize?
    
    private var fetchedDisposable = MetaDisposable()
    
    private var localIsVisible = false
    
    init(account: Account, media: InstantPageMedia, interactive: Bool, openMedia: @escaping  (InstantPageMedia) -> Void) {
        self.account = account
        self.media = media
        self.interactive = interactive
        self.openMedia = openMedia
        
        self.imageNode = TransformImageNode()
        self.videoNode = ManagedVideoNode(preferSoftwareDecoding: false, backgroundThread: false)
        
        super.init()
        
        self.imageNode.contentAnimations = [.firstUpdate]
        self.addSubnode(self.imageNode)
        self.addSubnode(self.videoNode)
        
        if let file = media.media as? TelegramMediaFile {
            self.imageNode.setSignal(chatMessageVideo(postbox: account.postbox, video: file))
            self.fetchedDisposable.set(freeMediaFileInteractiveFetched(account: account, file: file).start())
        }
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if self.interactive {
            self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        if self.localIsVisible != isVisible {
            self.localIsVisible = isVisible
        
            if isVisible {
                if let file = media.media as? TelegramMediaFile {
                    self.videoNode.acquireContext(account: self.account, mediaManager: account.telegramApplicationContext.mediaManager, id: InstantPageManagedMediaId(media: self.media), resource: file.resource, priority: 0)
                }
            } else {
                self.videoNode.discardContext()
            }
        }
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size {
            self.currentSize = size
            
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            self.videoNode.frame = CGRect(origin: CGPoint(), size: size)
            
            if let file = self.media.media as? TelegramMediaFile, let dimensions = file.dimensions {
                let imageSize = dimensions.aspectFilled(size)
                let boundingSize = size
                
                let makeLayout = self.imageNode.asyncLayout()
                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets())
                let apply = makeLayout(arguments)
                apply()
                
                self.videoNode.transformArguments = arguments
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        if media == self.media {
            let videoNode = self.videoNode
            return (self.videoNode, { [weak videoNode] in
                return videoNode?.view.snapshotContentTree(unhide: true)
            })
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.imageNode.isHidden = self.media == media
        self.videoNode.isHidden = self.media == media
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.openMedia(self.media)
        }
    }
}
