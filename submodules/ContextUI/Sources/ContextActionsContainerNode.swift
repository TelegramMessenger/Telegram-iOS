import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData

private enum ContextItemNode {
    case action(ContextActionNode)
    case separator(ASDisplayNode)
}

final class ContextActionsContainerNode: ASDisplayNode {
    private var itemNodes: [ContextItemNode]
    
    init(theme: PresentationTheme, items: [ContextMenuItem], getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        self.itemNodes = items.map { item in
            switch item {
            case let .action(action):
                return .action(ContextActionNode(theme: theme, action: action, getController: getController, actionSelected: actionSelected))
            case .separator:
                let separatorNode = ASDisplayNode()
                if theme.chatList.searchBarKeyboardColor == .dark {
                    separatorNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor.withAlphaComponent(0.8)
                } else {
                    separatorNode.backgroundColor = UIColor(white: 0.8, alpha: 0.6)
                }
                return .separator(separatorNode)
            }
        }
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 14.0
        
        self.itemNodes.forEach({ itemNode in
            switch itemNode {
            case let .action(actionNode):
                self.addSubnode(actionNode)
            case let .separator(separatorNode):
                self.addSubnode(separatorNode)
            }
        })
    }
    
    func updateLayout(constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        let minActionsWidth = min(constrainedWidth, max(250.0, floor(constrainedWidth / 3.0)))
        let separatorHeight: CGFloat = 8.0
        
        var maxWidth: CGFloat = 0.0
        var contentHeight: CGFloat = 0.0
        var heightsAndCompletions: [(CGFloat, (CGSize, ContainedViewLayoutTransition) -> Void)?] = []
        for i in 0 ..< self.itemNodes.count {
            switch self.itemNodes[i] {
            case let .action(itemNode):
                let next: ContextActionNext
                if i == self.itemNodes.count - 1 {
                    next = .none
                } else if case .separator = self.itemNodes[i + 1] {
                    next = .separator
                } else {
                    next = .item
                }
                let (minSize, complete) = itemNode.updateLayout(constrainedWidth: constrainedWidth, next: next)
                maxWidth = max(maxWidth, minSize.width)
                heightsAndCompletions.append((minSize.height, complete))
                contentHeight += minSize.height
            case .separator:
                heightsAndCompletions.append(nil)
                contentHeight += separatorHeight
            }
        }
        
        maxWidth = max(maxWidth, minActionsWidth)
        
        var verticalOffset: CGFloat = 0.0
        for i in 0 ..< heightsAndCompletions.count {
            switch self.itemNodes[i] {
            case let .action(itemNode):
                if let (itemHeight, itemCompletion) = heightsAndCompletions[i] {
                    let itemSize = CGSize(width: maxWidth, height: itemHeight)
                    transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: itemSize))
                    itemCompletion(itemSize, transition)
                    verticalOffset += itemHeight
                }
            case let .separator(separatorNode):
                transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: maxWidth, height: separatorHeight)))
                verticalOffset += separatorHeight
            }
        }
        
        return CGSize(width: maxWidth, height: verticalOffset)
    }
}
