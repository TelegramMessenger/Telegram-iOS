import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import PhotoResources

final class InstantPageArticleNode: ASDisplayNode, InstantPageNode {
    let item: InstantPageArticleItem
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    
    private let contentTile: InstantPageTile
    private let contentTileNode: InstantPageTileNode
    private var imageNode: TransformImageNode?
    
    let url: String
    let webpageId: MediaId
    let cover: TelegramMediaImage?
    
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private var fetchedDisposable = MetaDisposable()
    
    init(context: AccountContext, item: InstantPageArticleItem, webPage: TelegramMediaWebpage, strings: PresentationStrings, theme: InstantPageTheme, contentItems: [InstantPageItem], contentSize: CGSize, cover: TelegramMediaImage?, url: String, webpageId: MediaId, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.item = item
        self.url = url
        self.webpageId = webpageId
        self.cover = cover
        self.openUrl = openUrl
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.contentTile = InstantPageTile(frame: CGRect(x: 0.0, y: 0.0, width: contentSize.width, height: contentSize.height))
        self.contentTile.items.append(contentsOf: contentItems)
        self.contentTileNode = InstantPageTileNode(tile: self.contentTile, backgroundColor: .clear)
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.contentTileNode)
        
        if let image = cover {
            let imageNode = TransformImageNode()
            imageNode.isUserInteractionEnabled = false
            
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            imageNode.setSignal(chatMessagePhoto(postbox: context.account.postbox, photoReference: imageReference))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(context: context, photoReference: imageReference, displayAtSize: nil, storeToDownloadsPeerType: nil).start())
            
            self.imageNode = imageNode
            self.addSubnode(imageNode)
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.highlightedBackgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.highlightedBackgroundNode.alpha = 1.0
                } else {
                    strongSelf.highlightedBackgroundNode.alpha = 0.0
                    strongSelf.highlightedBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                }
            }
        }
        
        self.update(strings: strings, theme: theme)
    }
    
    deinit {
        self.fetchedDisposable.dispose()
    }
    
    @objc func buttonPressed() {
        self.openUrl(InstantPageUrlItem(url: self.url, webpageId: self.webpageId))
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let inset: CGFloat = 17.0
        let imageSize = CGSize(width: 44.0, height: 44.0)
        
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.contentTileNode.frame = self.bounds
        
        if let imageNode = self.imageNode, let image = self.cover, let largest = largestImageRepresentation(image.representations) {
            let size = largest.dimensions.cgSize.aspectFilled(imageSize)
            let boundingSize = imageSize
            
            let makeLayout = imageNode.asyncLayout()
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 5.0), imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
            apply()
        }
        
        if let imageNode = self.imageNode {
            if item.hasRTL {
                imageNode.frame = CGRect(origin: CGPoint(x: inset, y: 11.0), size: imageSize)
            } else {
                imageNode.frame = CGRect(origin: CGPoint(x: size.width - inset - imageSize.width, y: 11.0), size: imageSize)
            }
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
    }
}
