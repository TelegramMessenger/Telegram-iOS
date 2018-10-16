import Foundation
import AsyncDisplayKit
import Display

final class ProgressNavigationButtonNode: ASDisplayNode {
    private var indicatorNode: ActivityIndicator
    
    convenience init(theme: PresentationTheme) {
        self.init(color: theme.rootController.navigationBar.accentTextColor)
    }
    
    init(color: UIColor) {
        self.indicatorNode = ActivityIndicator(type: .custom(color, 22.0, 1.0))
        
        super.init()
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 26.0, height: 22.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
}
