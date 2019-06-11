import UIKit
import AsyncDisplayKit

open class ActionSheetItemNode: ASDisplayNode {
    private let theme: ActionSheetControllerTheme
    
    public let backgroundNode: ASDisplayNode
    private let overflowSeparatorNode: ASDisplayNode
    
    public init(theme: ActionSheetControllerTheme) {
        self.theme = theme
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = self.theme.itemBackgroundColor
        
        self.overflowSeparatorNode = ASDisplayNode()
        self.overflowSeparatorNode.backgroundColor = self.theme.itemHighlightedBackgroundColor
        
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
