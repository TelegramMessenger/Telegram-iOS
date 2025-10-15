import Foundation
import UIKit
import AsyncDisplayKit
import Display
import CheckNode

public final class ItemListSelectableControlNode: ASDisplayNode {
    public enum Style {
        case regular
        case compact
        case small
    }
    
    private let checkNode: CheckNode
    
    public init(strokeColor: UIColor, fillColor: UIColor, foregroundColor: UIColor) {
        self.checkNode = CheckNode(theme: CheckNodeTheme(backgroundColor: fillColor, strokeColor: foregroundColor, borderColor: strokeColor, overlayBorder: false, hasInset: true, hasShadow: false))
        self.checkNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.addSubnode(self.checkNode)
    }
    
    public static func asyncLayout(_ node: ItemListSelectableControlNode?) -> (_ strokeColor: UIColor, _ fillColor: UIColor, _ foregroundColor: UIColor, _ selected: Bool, _ style: Style) -> (CGFloat, (CGSize, Bool) -> ItemListSelectableControlNode) {
        return { strokeColor, fillColor, foregroundColor, selected, style in
            let resultNode: ItemListSelectableControlNode
            if let node = node {
                resultNode = node
            } else {
                resultNode = ItemListSelectableControlNode(strokeColor: strokeColor, fillColor: fillColor, foregroundColor: foregroundColor)
            }
            
            let offsetSize: CGFloat
            switch style {
            case .regular:
                offsetSize = 45.0
            case .compact:
                offsetSize = 38.0
            case .small:
                offsetSize = 44.0
            }
            
            return (offsetSize, { size, animated in
                let checkSize: CGSize
                let checkOffset: CGFloat
                switch style {
                case .regular, .compact:
                    checkSize = CGSize(width: 26.0, height: 26.0)
                    checkOffset = style == .compact ? 11.0 : 13.0
                case .small:
                    checkSize = CGSize(width: 22.0, height: 22.0)
                    checkOffset = 16.0
                }
                resultNode.checkNode.frame = CGRect(origin: CGPoint(x: checkOffset, y: floorToScreenPixels((size.height - checkSize.height) / 2.0)), size: checkSize)
                resultNode.checkNode.setSelected(selected, animated: animated)
                return resultNode
            })
        }
    }
}
