import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class StickerPreviewPeekContent: PeekControllerContent {
    let account: Account
    let item: StickerPackItem
    let menu: [PeekControllerMenuItem]
    
    init(account: Account, item: StickerPackItem, menu: [PeekControllerMenuItem]) {
        self.account = account
        self.item = item
        self.menu = menu
    }
    
    func presentation() -> PeekControllerContentPresentation {
        return .freeform
    }
    
    func menuActivation() -> PeerkControllerMenuActivation {
        return .press
    }
    
    func menuItems() -> [PeekControllerMenuItem] {
        return self.menu
    }
    
    func node() -> PeekControllerContentNode & ASDisplayNode {
        return StickerPreviewPeekContentNode(account: self.account, item: self.item)
    }
    
    func isEqual(to: PeekControllerContent) -> Bool {
        if let to = to as? StickerPreviewPeekContent {
            return self.item == to.item
        } else {
            return false
        }
    }
}

private final class StickerPreviewPeekContentNode: ASDisplayNode, PeekControllerContentNode {
    private let account: Account
    private let item: StickerPackItem
    
    private var textNode: ASTextNode
    private var imageNode: TransformImageNode
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    init(account: Account, item: StickerPackItem) {
        self.account = account
        self.item = item
        
        self.textNode = ASTextNode()
        self.imageNode = TransformImageNode()
        self.imageNode.addSubnode(self.textNode)
        
        for case let .Sticker(text, _, _) in item.file.attributes {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(32.0), textColor: .black)
            break
        }
        self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: false))
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        self.addSubnode(self.imageNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let boundingSize = CGSize(width: 180.0, height: 180.0).fitted(size)
        
        if let dimensitons = self.item.file.dimensions {
            let textSpacing: CGFloat = 10.0
            let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
            
            let imageSize = dimensitons.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: textSize.height + textSpacing), size: imageSize)
            self.imageNode.frame = imageFrame
            
            self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0), y: -textSize.height - textSpacing), size: textSize)
            
            return CGSize(width: size.width, height: imageFrame.height + textSize.height + textSpacing)
        } else {
            return CGSize(width: size.width, height: 10.0)
        }
    }
}
