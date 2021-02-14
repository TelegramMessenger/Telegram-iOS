import UIKit
import AsyncDisplayKit

open class ActionSheetItemNode: ASDisplayNode {
    private let theme: ActionSheetControllerTheme
    
    public let backgroundNode: ASDisplayNode
    private let overflowSeparatorNode: ASDisplayNode
    
    public var hasSeparator = true
    
    public var requestLayout: (() -> Void)?
    
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
    
    open func updateLayout(constrainedSize: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let size = CGSize(width: constrainedSize.width, height: 57.0)
        self.updateInternalLayout(size)
        return size
    }
    
    public func updateInternalLayout(_ calculatedSize: CGSize) {
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: calculatedSize)
        self.overflowSeparatorNode.frame = CGRect(origin: CGPoint(x: 0.0, y: calculatedSize.height), size: CGSize(width: calculatedSize.width, height: UIScreenPixel))
        self.overflowSeparatorNode.isHidden = !self.hasSeparator
    }
}
