import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CheckNode

public final class ItemListSelectableControlNode: ASDisplayNode {
    private let checkNode: CheckNode
    
    public init(strokeColor: UIColor, fillColor: UIColor, foregroundColor: UIColor) {
        self.checkNode = CheckNode(theme: CheckNodeTheme(backgroundColor: fillColor, strokeColor: foregroundColor, borderColor: strokeColor, overlayBorder: false, hasInset: true, hasShadow: false))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    public static func asyncLayout(_ node: ItemListSelectableControlNode?) -> (_ strokeColor: UIColor, _ fillColor: UIColor, _ foregroundColor: UIColor, _ selected: Bool, _ compact: Bool) -> (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode) {
        return { strokeColor, fillColor, foregroundColor, selected, compact in
            let resultNode: ItemListSelectableControlNode
            if let node = node {
                resultNode = node
            } else {
                resultNode = ItemListSelectableControlNode(strokeColor: strokeColor, fillColor: fillColor, foregroundColor: foregroundColor)
            }
            
            return (compact ? 38.0 : 45.0, { size, animated in
                let checkSize = CGSize(width: 26.0, height: 26.0)
                resultNode.checkNode.frame = CGRect(origin: CGPoint(x: compact ? 11.0 : 13.0, y: floorToScreenPixels((size.height - checkSize.height) / 2.0)), size: checkSize)
                resultNode.checkNode.setSelected(selected, animated: animated)
                return resultNode
            })
        }
    }
}
