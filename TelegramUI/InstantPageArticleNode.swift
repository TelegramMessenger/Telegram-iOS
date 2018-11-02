import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

private func isRtl(string: String) -> Bool {
    if string.count == 0 {
        return false
    }
    
    let code = CFStringTokenizerCopyBestStringLanguage(string as CFString, CFRangeMake(0, string.count)) as String
    return Locale.characterDirection(forLanguage: code) == .rightToLeft
}

final class InstantPageArticleNode: ASDisplayNode, InstantPageNode {
    private let titleNode: ASTextNode
    private let descriptionNode: ASTextNode
    private var imageNode: TransformImageNode?
    
    private let highlightedBackgroundNode: ASDisplayNode
    private let buttonNode: HighlightableButtonNode
    
    let title: String
    let pageDescription: String
    let url: String
    let webpageId: MediaId
    let cover: TelegramMediaImage?
    let rtl: Bool
    
    private let openUrl: (InstantPageUrlItem) -> Void
    
    private var fetchedDisposable = MetaDisposable()
    
    init(account: Account, webPage: TelegramMediaWebpage, strings: PresentationStrings, theme: InstantPageTheme, title: String, description: String, cover: TelegramMediaImage?, url: String, webpageId: MediaId, openUrl: @escaping (InstantPageUrlItem) -> Void) {
        self.title = title
        self.pageDescription = description
        self.url = url
        self.webpageId = webpageId
        self.cover = cover
        self.rtl = isRtl(string: title) || isRtl(string: description)
        self.openUrl = openUrl
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.isLayerBacked = true
        self.highlightedBackgroundNode.alpha = 0.0
        
        self.buttonNode = HighlightableButtonNode()
        
        self.titleNode = ASTextNode()
        self.titleNode.isLayerBacked = true
        self.titleNode.maximumNumberOfLines = 1
        
        self.descriptionNode = ASTextNode()
        self.descriptionNode.isLayerBacked = true
        self.descriptionNode.maximumNumberOfLines = 2
        
        super.init()
        
        self.addSubnode(self.highlightedBackgroundNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.descriptionNode)
        
        if let image = cover {
            let imageNode = TransformImageNode()
            imageNode.isUserInteractionEnabled = false
            
            let imageReference = ImageMediaReference.webPage(webPage: WebpageReference(webPage), media: image)
            imageNode.setSignal(chatMessagePhoto(postbox: account.postbox, photoReference: imageReference))
            self.fetchedDisposable.set(chatMessagePhotoInteractiveFetched(account: account, photoReference: imageReference, storeToDownloadsPeerType: nil).start())
            
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
        let imageSize = CGSize(width: 65.0, height: 65.0)
        
        self.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -UIScreenPixel), size: CGSize(width: size.width, height: size.height + UIScreenPixel))
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        
        var sideInset: CGFloat = 0.0
        if let imageNode = self.imageNode, let image = self.cover, let largest = largestImageRepresentation(image.representations) {
            sideInset = imageSize.width + inset
            let size = largest.dimensions.aspectFilled(imageSize)
            let boundingSize = imageSize
            
            let makeLayout = imageNode.asyncLayout()
            let apply = makeLayout(TransformImageArguments(corners: ImageCorners(radius: 5.0), imageSize: size, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
            apply()
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: size.width - inset * 2.0 - sideInset, height: size.height))
        let descriptionSize = self.descriptionNode.measure(CGSize(width: size.width - inset * 2.0 - sideInset, height: size.height))
        
        if self.rtl {
            if let imageNode = self.imageNode {
                imageNode.frame = CGRect(origin: CGPoint(x: inset, y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
            }
            self.titleNode.frame = CGRect(origin: CGPoint(x: size.width - titleSize.width - inset, y: 16.0), size: titleSize)
            self.descriptionNode.frame = CGRect(origin: CGPoint(x: size.width - descriptionSize.width - inset, y: self.titleNode.frame.maxY + 6.0), size: descriptionSize)
        } else {
            if let imageNode = self.imageNode {
                imageNode.frame = CGRect(origin: CGPoint(x: size.width - inset - imageSize.width, y: floor((size.height - imageSize.height) / 2.0)), size: imageSize)
            }
            self.titleNode.frame = CGRect(origin: CGPoint(x: inset, y: 16.0), size: titleSize)
            self.descriptionNode.frame = CGRect(origin: CGPoint(x: inset, y: self.titleNode.frame.maxY + 6.0), size: descriptionSize)
        }
    }
    
    func updateIsVisible(_ isVisible: Bool) {
        
    }
    
    func transitionNode(media: InstantPageMedia) -> (ASDisplayNode, () -> UIView?)? {
        return nil
    }
    
    func updateHiddenMedia(media: InstantPageMedia?) {
        
    }
    
    func update(strings: PresentationStrings, theme: InstantPageTheme) {
        self.titleNode.attributedText = NSAttributedString(string: self.title, font: UIFont(name: "Georgia", size: 17.0), textColor: theme.panelPrimaryColor)
        self.descriptionNode.attributedText = NSAttributedString(string: self.pageDescription, font: theme.serif ? UIFont(name: "Georgia", size: 15.0) : Font.regular(15.0), textColor: theme.panelSecondaryColor)
        self.highlightedBackgroundNode.backgroundColor = theme.panelHighlightedBackgroundColor
    }
}
