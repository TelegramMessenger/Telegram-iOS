import UIKit
import AsyncDisplayKit

open class ActionSheetItemNode: ASDisplayNode {
    public static let defaultBackgroundColor: UIColor = UIColor(white: 1.0, alpha: 0.8)
    public static let highlightedBackgroundColor: UIColor = UIColor(white: 0.9, alpha: 0.7)
    
    public let backgroundNode: ASDisplayNode
    private let overflowSeparatorNode: ASDisplayNode
    
    public override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = ActionSheetItemNode.defaultBackgroundColor
        
        self.overflowSeparatorNode = ASDisplayNode()
        self.overflowSeparatorNode.backgroundColor = UIColor(white: 0.5, alpha: 0.3)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.overflowSeparatorNode)
    }
    
    open override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: constrainedSize.width, height: 57.0)
    }
    
    open override func layout() {
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: self.calculatedSize)
        self.overflowSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: self.calculatedSize.height), size: CGSize(width: self.calculatedSize.width, height: UIScreenPixel))
    }
}
