import Foundation
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import UIKit
import WebPBinding
import AnimatedAvatarSetNode
import ContextUI

public final class ReactionListContextMenuContent: ContextControllerItemsContent {
    final class ItemsNode: ASDisplayNode, ContextControllerItemsNode {
        private let contentNode: ASDisplayNode
        
        override init() {
            self.contentNode = ASDisplayNode()
            
            super.init()
            
            self.addSubnode(self.contentNode)
            //self.contentNode.backgroundColor = .blue
        }
        
        func update(constrainedWidth: CGFloat, maxHeight: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> (cleanSize: CGSize, visibleSize: CGSize) {
            let size = CGSize(width: min(260.0, constrainedWidth), height: maxHeight)
            
            let contentSize = CGSize(width: size.width, height: size.height + bottomInset + 14.0)
            //contentSize.height = 120.0
            
            self.contentNode.frame = CGRect(origin: CGPoint(), size: contentSize)
            
            return (size, contentSize)
        }
    }
    
    public init() {
    }
    
    public func node() -> ContextControllerItemsNode {
        return ItemsNode()
    }
}
