import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

final class InstantPageImageNode: ASDisplayNode, InstantPageNode {
    private let account: Account
    let media: InstantPageMedia
    private let interactive: Bool
    private let roundCorners: Bool
    private let fit: Bool
    private let openMedia: (InstantPageMedia) -> Void
    
    private let imageNode: TransformImageNode
    
    private var currentSize: CGSize?
    
    private var fetchedDisposable = MetaDisposable()
    
    init(account: Account, media: InstantPageMedia, interactive: Bool, roundCorners: Bool, fit: Bool, openMedia: @escaping (InstantPageMedia) -> Void) {
        self.account = account
        self.media = media
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
        self.openMedia = openMedia
        
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.imageNode.alphaTransitionOnFirstUpdate = true
        self.addSubnode(self.imageNode)
        
        if let image = media.media as? TelegramMediaImage {
            self.imageNode.setSignal(account: account, signal: chatMessagePhoto(account: account, photo: image))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photo: image).start())
        } else if let file = media.media as? TelegramMediaFile {
            self.imageNode.setSignal(account: account, signal: chatMessageVideo(account: account, video: file))
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
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if self.currentSize != size {
            self.currentSize = size
            
            self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
            
            if let image = self.media.media as? TelegramMediaImage, let largest = largestImageRepresentation(image.representations) {
                let imageSize = largest.dimensions.aspectFilled(size)
                let boundingSize = size
                var radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                apply()
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> ASDisplayNode? {
        if media == self.media {
            return self.imageNode
        } else {
            return nil
        }
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        self.imageNode.isHidden = self.media == media
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.openMedia(self.media)
        }
    }
}
