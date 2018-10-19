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
    
    init(account: Account, webPage: TelegramMediaWebpage, media: InstantPageMedia, interactive: Bool, roundCorners: Bool, fit: Bool, openMedia: @escaping (InstantPageMedia) -> Void) {
        self.account = account
        self.media = media
        self.interactive = interactive
        self.roundCorners = roundCorners
        self.fit = fit
        self.openMedia = openMedia
        
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.imageNode)
        
        if let image = media.media as? TelegramMediaImage {
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            self.imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photoReference: imageReference))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photoReference: imageReference, storeToDownloads: false).start())
        } else if let file = media.media as? TelegramMediaFile {
            let fileReference = FileMediaReference.webPage(webPage: WebpageReference(webPage), media: file)
            self.imageNode.setSignal(chatMessageVideo(postbox: account.postbox, videoReference: fileReference))
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
                let radius: CGFloat = self.roundCorners ? floor(min(imageSize.width, imageSize.height) / 2.0) : 0.0
                
                let makeLayout = self.imageNode.asyncLayout()
                let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
                apply()
            }
        }
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        if media == self.media {
            let imageNode = self.imageNode
            return (self.imageNode, { [weak imageNode] in
                return imageNode?.view.snapshotContentTree(unhide: true)
            })
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
