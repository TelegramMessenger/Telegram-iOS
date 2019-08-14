import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import CheckNode

public final class GalleryNavigationCheckNode: ASDisplayNode, NavigationButtonCustomDisplayNode {
    private var checkNode: CheckNode
    
    public init(theme: PresentationTheme) {
        self.checkNode = CheckNode(strokeColor: theme.list.itemCheckColors.strokeColor, fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, style: .navigation)
    
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    public var isHighlightable: Bool {
        return false
    }
    
    public var isChecked: Bool {
        return self.checkNode.isChecked
    }
    
    public func setIsChecked(_ isChecked: Bool, animated: Bool) {
        self.checkNode.setIsChecked(isChecked, animated: animated)
    }
    
    public func addTarget(target: AnyObject?, action: Selector) {
        self.checkNode.addTarget(target: target, action: action)
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 39.0, height: 39.0)
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        let checkSize = CGSize(width: 39.0, height: 39.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: floor((size.width - checkSize.width) / 2.0) + 11.0, y: floor((size.height - checkSize.height) / 2.0) + 3.0), size: checkSize)
    }
}
