import Foundation
import AsyncDisplayKit
import Display

final class ChatMessageInteractiveMediaLabelNode: ASDisplayNode {
    private let backgroundNode: ASImageNode
    private let textNode: TextNode
    
    override init() {
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
    }
    
    
}
