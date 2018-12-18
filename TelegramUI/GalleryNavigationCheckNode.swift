import Foundation
import AsyncDisplayKit
import Display

final class GalleryNavigationCheckNode: ASDisplayNode {
    private var checkNode: CheckNode
    
    init(theme: PresentationTheme) {
        self.checkNode = CheckNode(strokeColor: theme.list.itemCheckColors.strokeColor, fillColor: theme.list.itemCheckColors.fillColor, foregroundColor: theme.list.itemCheckColors.foregroundColor, style: .navigation)
    
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 39.0, height: 39.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        let checkSize = CGSize(width: 39.0, height: 39.0)
        self.checkNode.frame = CGRect(origin: CGPoint(x: floor((size.width - checkSize.width) / 2.0) + 11.0, y: floor((size.height - checkSize.height) / 2.0) + 3.0), size: checkSize)
    }
}
