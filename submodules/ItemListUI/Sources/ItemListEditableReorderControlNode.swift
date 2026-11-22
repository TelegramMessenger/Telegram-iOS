import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

public final class ItemListEditableReorderControlNode: ASDisplayNode {
    public var tapped: (() -> Void)?
    private let iconNode: ASImageNode
    
    override public init() {
        self.iconNode = ASImageNode()
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.iconNode)
    }
    
    public static func asyncLayout(_ node: ItemListEditableReorderControlNode?) -> (_ theme: PresentationTheme) -> (CGFloat, (CGFloat, Bool, ContainedViewLayoutTransition) -> ItemListEditableReorderControlNode) {
        return { theme in
            let image = PresentationResourcesItemList.itemListReorderIndicatorIcon(theme)
            
            let resultNode: ItemListEditableReorderControlNode
            if let node = node {
                resultNode = node
            } else {
                resultNode = ItemListEditableReorderControlNode()
            }
            resultNode.iconNode.image = image
            
            return (40.0, { height, offsetForLabel, transition in
                if let image = image {
                    transition.updateFrame(node: resultNode.iconNode, frame: CGRect(origin: CGPoint(x: 0.0, y: floor((height - image.size.height) / 2.0) - (offsetForLabel ? 6.0 : 0.0)), size: image.size))
                }
                return resultNode
            })
        }
    }
}

