import Foundation
import UIKit
import AsyncDisplayKit

open class ASButtonNode: ASControlNode {
    public let titleNode: ImmediateTextNode
    
    override public init() {
        self.titleNode = ImmediateTextNode()
        
        super.init()
        
        self.addSubnode(self.titleNode)
    }
    
    open func setAttributedTitle(_ attributedTitle: NSAttributedString, for states: [Any]) {
        self.titleNode.attributedText = attributedTitle
        self.setNeedsLayout()
    }
    
    override open func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: size.width, height: size.height))
        self.titleNode.frame = CGRect(origin: CGPoint(x: floor((size.width - titleSize.width) / 2.0), y: floor((size.height - titleSize.height) / 2.0)), size: titleSize)
    }
}
