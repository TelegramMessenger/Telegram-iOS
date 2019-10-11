import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData

private final class ContextActionsSelectionGestureRecognizer: UIPanGestureRecognizer {
    var updateLocation: ((CGPoint, Bool) -> Void)?
    var completed: ((Bool) -> Void)?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        
        self.updateLocation?(touches.first!.location(in: self.view), false)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        
        self.updateLocation?(touches.first!.location(in: self.view), true)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        
        self.completed?(true)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        
        self.completed?(false)
    }
}

private enum ContextItemNode {
    case action(ContextActionNode)
    case itemSeparator(ASDisplayNode)
    case separator(ASDisplayNode)
}

final class ContextActionsContainerNode: ASDisplayNode {
    private var effectView: UIVisualEffectView?
    private var itemNodes: [ContextItemNode]
    private let feedbackTap: () -> Void
    
    private(set) var gesture: UIGestureRecognizer?
    private var currentHighlightedActionNode: ContextActionNode?
    
    init(theme: PresentationTheme, items: [ContextMenuItem], getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void, feedbackTap: @escaping () -> Void) {
        self.feedbackTap = feedbackTap
        
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
                actionNode.isUserInteractionEnabled = false
                self.addSubnode(actionNode)
            case let .itemSeparator(separatorNode):
                self.addSubnode(separatorNode)
            case let .separator(separatorNode):
                self.addSubnode(separatorNode)
            }
        })
        
        let gesture = ContextActionsSelectionGestureRecognizer(target: nil, action: nil)
        self.gesture = gesture
        gesture.updateLocation = { [weak self] point, moved in
            guard let strongSelf = self else {
                return
            }
            let actionNode = strongSelf.actionNode(at: point)
            if actionNode !== strongSelf.currentHighlightedActionNode {
                if actionNode != nil, moved {
                    strongSelf.feedbackTap()
                }
                strongSelf.currentHighlightedActionNode?.setIsHighlighted(false)
            }
            strongSelf.currentHighlightedActionNode = actionNode
            actionNode?.setIsHighlighted(true)
        }
        gesture.completed = { [weak self] performAction in
            guard let strongSelf = self else {
                return
            }
            if let currentHighlightedActionNode = strongSelf.currentHighlightedActionNode {
                strongSelf.currentHighlightedActionNode = nil
                currentHighlightedActionNode.setIsHighlighted(false)
                if performAction {
                    currentHighlightedActionNode.performAction()
                }
            }
        }
        self.view.addGestureRecognizer(gesture)
    }
    
    func updateLayout(widthClass: ContainerViewLayoutSizeClass, constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        var minActionsWidth: CGFloat = 250.0
        switch widthClass {
        case .compact:
            minActionsWidth = max(minActionsWidth, floor(constrainedWidth / 3.0))
            if let effectView = self.effectView {
                self.effectView = nil
                effectView.removeFromSuperview()
            }
        case .regular:
            if self.effectView == nil {
                let effectView: UIVisualEffectView
                if #available(iOS 10.0, *) {
                    effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                } else {
                    effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
                }
                self.effectView = effectView
                self.view.insertSubview(effectView, at: 0)
            }
        }
        minActionsWidth = min(minActionsWidth, constrainedWidth)
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
        
        let size = CGSize(width: maxWidth, height: verticalOffset)
        if let effectView = self.effectView {
            transition.updateFrame(view: effectView, frame: CGRect(origin: CGPoint(), size: size))
        }
        return size
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
