import Foundation
import UIKit
import AsyncDisplayKit

final class ListViewOverscrollBackgroundNode: ASDisplayNode {
    private let backgroundNode: ASDisplayNode
    
    var color: UIColor {
        didSet {
            self.backgroundNode.backgroundColor = color
        }
    }
    
    init(color: UIColor) {
        self.color = color
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = color
        self.backgroundNode.isLayerBacked = true
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: size))
    }
}
