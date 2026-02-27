import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import CheckNode

public final class GalleryNavigationCheckNode: ASDisplayNode, NavigationButtonCustomDisplayNode {
    private var checkNode: InteractiveCheckNode
    private weak var target: AnyObject?
    private var action: Selector?
    
    public init(theme: PresentationTheme) {
        self.checkNode = InteractiveCheckNode(theme: CheckNodeTheme(theme: theme, style: .overlay))
    
        super.init()
        
        self.addSubnode(self.checkNode)
        
        self.checkNode.valueChanged = { [weak self] value in
            if let strongSelf = self, let target = strongSelf.target, let action = strongSelf.action {
                let _ = target.perform(action)
            }
        }
    }
    
    public var isHighlightable: Bool {
        return false
    }
    
    public var isChecked: Bool {
        return self.checkNode.selected
    }
    
    public func setIsChecked(_ isChecked: Bool, animated: Bool) {
        self.checkNode.setSelected(isChecked, animated: animated)
    }
    
    public func addTarget(target: AnyObject?, action: Selector) {
        self.target = target
        self.action = action
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 39.0, height: 39.0)
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        let checkSize = CGSize(width: 36.0, height: 36.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - checkSize.width) / 2.0) + 11.0, y: floorToScreenPixels((size.height - checkSize.height) / 2.0) + 3.0), size: checkSize)
    }
}
