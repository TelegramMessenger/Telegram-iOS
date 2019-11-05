import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData

private enum ContextItemNode {
    case action(ContextActionNode)
    case itemSeparator(ASDisplayNode)
    case separator(ASDisplayNode)
}

final class ContextActionsContainerNode: ASDisplayNode {
    private var itemNodes: [ContextItemNode]
    
    init(theme: PresentationTheme, items: [ContextMenuItem], getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void) {
        var itemNodes: [ContextItemNode] = []
        for i in 0 ..< items.count {
            switch items[i] {
            case let .action(action):
                itemNodes.append(.action(ContextActionNode(theme: theme, action: action, getController: getController, actionSelected: actionSelected)))
                if i != items.count - 1, case .action = items[i + 1] {
                    let separatorNode = ASDisplayNode()
                    separatorNode.backgroundColor = theme.contextMenu.itemSeparatorColor
                    itemNodes.append(.itemSeparator(separatorNode))
                }
            case .separator:
                let separatorNode = ASDisplayNode()
                separatorNode.backgroundColor = theme.contextMenu.sectionSeparatorColor
                itemNodes.append(.separator(separatorNode))
            }
        }
        
        self.itemNodes = itemNodes
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 14.0
        
        self.backgroundColor = theme.contextMenu.backgroundColor
        
        self.itemNodes.forEach({ itemNode in
            switch itemNode {
            case let .action(actionNode):
                self.addSubnode(actionNode)
            case let .itemSeparator(separatorNode):
                self.addSubnode(separatorNode)
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
                let previous: ContextActionSibling
                let next: ContextActionSibling
                if i == 0 {
                    previous = .none
                } else if case .separator = self.itemNodes[i - 1] {
                    previous = .separator
                } else {
                    previous = .item
                }
                if i == self.itemNodes.count - 1 {
                    next = .none
                } else if case .separator = self.itemNodes[i + 1] {
                    next = .separator
                } else {
                    next = .item
                }
                let (minSize, complete) = itemNode.updateLayout(constrainedWidth: constrainedWidth, previous: previous, next: next)
                maxWidth = max(maxWidth, minSize.width)
                heightsAndCompletions.append((minSize.height, complete))
                contentHeight += minSize.height
            case .itemSeparator:
                heightsAndCompletions.append(nil)
                contentHeight += UIScreenPixel
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
            case let .itemSeparator(separatorNode):
                transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: maxWidth, height: UIScreenPixel)))
                verticalOffset += UIScreenPixel
            case let .separator(separatorNode):
                transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: verticalOffset), size: CGSize(width: maxWidth, height: separatorHeight)))
                verticalOffset += separatorHeight
            }
        }
        
        return CGSize(width: maxWidth, height: verticalOffset)
    }
    
    func updateTheme(theme: PresentationTheme) {
        for itemNode in self.itemNodes {
            switch itemNode {
            case let .action(action):
                action.updateTheme(theme: theme)
            case let .separator(separator):
                separator.backgroundColor = theme.contextMenu.sectionSeparatorColor
            case let .itemSeparator(itemSeparator):
                itemSeparator.backgroundColor = theme.contextMenu.itemSeparatorColor
            }
        }
        
        self.backgroundColor = theme.contextMenu.backgroundColor
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNode? {
        for itemNode in self.itemNodes {
            switch itemNode {
            case let .action(actionNode):
                if actionNode.frame.contains(point) {
                    return actionNode
                }
            default:
                break
            }
        }
        return nil
    }
}
