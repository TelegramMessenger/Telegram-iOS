import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ActivityIndicator

public final class ProgressNavigationButtonNode: ASDisplayNode {
    private var indicatorNode: ActivityIndicator
    
    public init(color: UIColor) {
        self.indicatorNode = ActivityIndicator(type: .custom(color, 22.0, 1.0, false))
        
        super.init()
        
        self.addSubnode(self.indicatorNode)
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 26.0, height: 22.0)
    }
    
    override public func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
}
