import Foundation
import Display
import TelegramCore
import SwiftSignalKit
import AsyncDisplayKit
import Postbox

final class StickerPackPreviewGridItem: GridItem {
    let account: Account
    let stickerItem: StickerPackItem
    
    let section: GridSection? = nil
    
    init(account: Account, stickerItem: StickerPackItem) {
        self.account = account
        self.stickerItem = stickerItem
    }
    
    func node(layout: GridNodeLayout) -> GridItemNode {
        let node = StickerPackPreviewGridItemNode()
        node.setup(account: self.account, stickerItem: self.stickerItem)
        return node
    }
    
    func update(node: GridItemNode) {
        guard let node = node as? StickerPackPreviewGridItemNode else {
            assertionFailure()
            return
        }
        node.setup(account: self.account, stickerItem: self.stickerItem)
    }
}

final class StickerPackPreviewGridItemNode: GridItemNode {
    private var currentState: (Account, StickerPackItem, CGSize)?
    private let imageNode: TransformImageNode
    private let textNode: ASTextNode
    
    private let stickerFetchedDisposable = MetaDisposable()
    
    var interfaceInteraction: ChatControllerInteraction?
    var inputNodeInteraction: ChatMediaInputNodeInteraction?
    var selected: (() -> Void)?
    
    override init() {
        self.imageNode = TransformImageNode()
        //self.imageNode.alphaTransitionOnFirstUpdate = true
        self.imageNode.isLayerBacked = true
        
        self.textNode = ASTextNode()
        self.textNode.isLayerBacked = true
        self.textNode.displaysAsynchronously = true
        
        super.init()
        
        self.addSubnode(self.imageNode)
        self.addSubnode(self.textNode)
    }
    
    deinit {
        stickerFetchedDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.imageNodeTap(_:))))
    }
    
    func setup(account: Account, stickerItem: StickerPackItem) {
        if self.currentState == nil || self.currentState!.0 !== account || self.currentState!.1 != stickerItem {
            var text = ""
            for attribute in stickerItem.file.attributes {
                if case let .Sticker(displayText, _) = attribute {
                    text = displayText
                    break
                }
            }
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.regular(20.0), textColor: .black, paragraphAlignment: .right)
            if let dimensions = stickerItem.file.dimensions {
                self.imageNode.setSignal(account: account, signal: chatMessageSticker(account: account, file: stickerItem.file, small: true))
                self.stickerFetchedDisposable.set(fileInteractiveFetched(account: account, file: stickerItem.file).start())
                
                self.currentState = (account, stickerItem, dimensions)
                self.setNeedsLayout()
            }
        }
        
        //self.updateSelectionState(animated: false)
        //self.updateHiddenMedia()
    }
    
    override func layout() {
        super.layout()
        
        let bounds = self.bounds
        let boundsSide = min(bounds.size.width - 14.0, bounds.size.height - 14.0)
        let boundingSize = CGSize(width: boundsSide, height: boundsSide)
        
        if let (_, _, mediaDimensions) = self.currentState {
            let imageSize = mediaDimensions.aspectFitted(boundingSize)
            self.imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))()
            self.imageNode.frame = CGRect(origin: CGPoint(x: floor((bounds.size.width - imageSize.width) / 2.0), y: (bounds.size.height - imageSize.height) / 2.0), size: imageSize)
            let boundingFrame =  CGRect(origin: CGPoint(x: floor((bounds.size.width - boundingSize.width) / 2.0), y: (bounds.size.height - boundingSize.height) / 2.0), size: boundingSize)
            let textSize = CGSize(width: 32.0, height: 24.0)
            self.textNode.frame = CGRect(origin: CGPoint(x: boundingFrame.maxX - 1.0 - textSize.width, y: boundingFrame.height + 10.0 - textSize.height), size: textSize)
        }
    }
    
    /*func transitionNode(id: MessageId, media: Media) -> ASDisplayNode? {
     if self.messageId == id {
     return self.imageNode
     } else {
     return nil
     }
     }*/
    
    @objc func imageNodeTap(_ recognizer: UITapGestureRecognizer) {
        if let interfaceInteraction = self.interfaceInteraction, let (_, item, _) = self.currentState, case .ended = recognizer.state {
            interfaceInteraction.sendSticker(item.file)
        }
        /*if let controllerInteraction = self.controllerInteraction, let messageId = self.messageId, case .ended = recognizer.state {
         controllerInteraction.openMessage(messageId)
         }*/
    }
    
    func animateIn() {
        self.textNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 60.0), to: CGPoint(), duration: 0.42, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
    }
}

