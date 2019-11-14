import Foundation
import UIKit
import AsyncDisplayKit

final class PeekControllerMenuNode: ASDisplayNode {
    private let itemNodes: [PeekControllerMenuItemNode]
    
    init(theme: PeekControllerTheme, items: [PeekControllerMenuItem], activatedAction: @escaping () -> Void) {
        self.itemNodes = items.map { PeekControllerMenuItemNode(theme: theme, item: $0, activatedAction: activatedAction) }
        
        super.init()
        
        self.backgroundColor = theme.menuBackgroundColor
        self.cornerRadius = 16.0
        self.clipsToBounds = true
        
        for itemNode in self.itemNodes {
            self.addSubnode(itemNode)
        }
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        var verticalOffset: CGFloat = 0.0
        for itemNode in self.itemNodes {
            let itemHeight = itemNode.updateLayout(width: width, transition: transition)
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: width, height: itemHeight)))
            verticalOffset += itemHeight
        }
        return verticalOffset - UIScreenPixel
    }
}
