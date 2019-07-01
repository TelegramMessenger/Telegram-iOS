import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

enum StickerPreviewPeekItem: Equatable {
    case pack(StickerPackItem)
    case found(FoundStickerItem)
    
    var file: TelegramMediaFile {
        switch self {
            case let .pack(item):
                return item.file
            case let .found(item):
                return item.file
        }
    }
}

final class StickerPreviewPeekContent: PeekControllerContent {
    let account: Account
    let item: StickerPreviewPeekItem
    let menu: [PeekControllerMenuItem]
    
    init(account: Account, item: StickerPreviewPeekItem, menu: [PeekControllerMenuItem]) {
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
    
    func topAccessoryNode() -> ASDisplayNode? {
        return nil
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
    private let item: StickerPreviewPeekItem
    
    private var textNode: ASTextNode
    private var imageNode: TransformImageNode
    private var animationNode: AnimatedStickerNode?
    
    private var containerLayout: (ContainerViewLayout, CGFloat)?
    
    init(account: Account, item: StickerPreviewPeekItem) {
        self.account = account
        self.item = item
        
        self.textNode = ASTextNode()
        self.imageNode = TransformImageNode()
        
        for case let .Sticker(text, _, _) in item.file.attributes {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(32.0), textColor: .black)
            break
        }
        
        if item.file.isAnimatedSticker {
            let animationNode = AnimatedStickerNode()
            self.animationNode = animationNode
            
            self.animationNode?.setup(account: account, resource: item.file.resource, width: 400, height: 400, mode: .direct)
            self.animationNode?.visibility = true
            self.animationNode?.addSubnode(self.textNode)
        } else {
            self.imageNode.addSubnode(self.textNode)
            self.animationNode = nil
        }
        
        self.imageNode.setSignal(chatMessageSticker(account: account, file: item.file, small: false, fetched: true))
        
        super.init()
        
        self.isUserInteractionEnabled = false
        
        if let animationNode = self.animationNode {
            self.addSubnode(animationNode)
        } else {
            self.addSubnode(self.imageNode)
        }
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let boundingSize = CGSize(width: 180.0, height: 180.0).fitted(size)
        
        if let dimensitons = self.item.file.dimensions {
            let textSpacing: CGFloat = 10.0
            let textSize = self.textNode.measure(CGSize(width: 100.0, height: 100.0))
            
            let imageSize = dimensitons.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets()))()
            let imageFrame = CGRect(origin: CGPoint(x: floor((size.width - imageSize.width) / 2.0), y: textSize.height + textSpacing), size: imageSize)
            self.imageNode.frame = imageFrame
            if let animationNode = self.animationNode {
                animationNode.frame = imageFrame
                animationNode.updateLayout(size: imageSize)
            }
            
            self.textNode.frame = CGRect(origin: CGPoint(x: floor((imageFrame.size.width - textSize.width) / 2.0), y: -textSize.height - textSpacing), size: textSize)
            
            return CGSize(width: size.width, height: imageFrame.height + textSize.height + textSpacing)
        } else {
            return CGSize(width: size.width, height: 10.0)
        }
    }
}
