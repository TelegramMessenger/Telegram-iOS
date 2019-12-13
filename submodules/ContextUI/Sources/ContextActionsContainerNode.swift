import Foundation
import AsyncDisplayKit
import Display
import TelegramPresentationData
import TextSelectionNode
import AppBundle

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

private final class InnerActionsContainerNode: ASDisplayNode {
    private let presentationData: PresentationData
    private var effectView: UIVisualEffectView?
    private var itemNodes: [ContextItemNode]
    private let feedbackTap: () -> Void
    
    private(set) var gesture: UIGestureRecognizer?
    private var currentHighlightedActionNode: ContextActionNode?
    
    init(presentationData: PresentationData, items: [ContextMenuItem], getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void, feedbackTap: @escaping () -> Void) {
        self.presentationData = presentationData
        self.feedbackTap = feedbackTap
        
        var itemNodes: [ContextItemNode] = []
        for i in 0 ..< items.count {
            switch items[i] {
            case let .action(action):
                itemNodes.append(.action(ContextActionNode(presentationData: presentationData, action: action, getController: getController, actionSelected: actionSelected)))
                if i != items.count - 1, case .action = items[i + 1] {
                    let separatorNode = ASDisplayNode()
                    separatorNode.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
                    itemNodes.append(.itemSeparator(separatorNode))
                }
            case .separator:
                let separatorNode = ASDisplayNode()
                separatorNode.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
                itemNodes.append(.separator(separatorNode))
            }
        }
        
        self.itemNodes = itemNodes
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 14.0
        
        self.backgroundColor = presentationData.theme.contextMenu.backgroundColor
        
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
                if #available(iOS 13.0, *) {
                    if self.presentationData.theme.overallDarkAppearance {
                        effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
                    } else {
                        effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
                    }
                } else if #available(iOS 10.0, *) {
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
    
    func updateTheme(presentationData: PresentationData) {
        for itemNode in self.itemNodes {
            switch itemNode {
            case let .action(action):
                action.updateTheme(presentationData: presentationData)
            case let .separator(separator):
                separator.backgroundColor = presentationData.theme.contextMenu.sectionSeparatorColor
            case let .itemSeparator(itemSeparator):
                itemSeparator.backgroundColor = presentationData.theme.contextMenu.itemSeparatorColor
            }
        }
        
        self.backgroundColor = presentationData.theme.contextMenu.backgroundColor
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

private final class InnerTextSelectionTipContainerNode: ASDisplayNode {
    private let presentationData: PresentationData
    private var effectView: UIVisualEffectView?
    private let textNode: TextNode
    private var textSelectionNode: TextSelectionNode?
    private let iconNode: ASImageNode
    
    private let text: String
    private let targetSelectionIndex: Int
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
        self.textNode = TextNode()
        
        var rawText = self.presentationData.strings.ChatContextMenu_TextSelectionTip
        if let range = rawText.range(of: "|") {
            rawText.removeSubrange(range)
            self.text = rawText
            self.targetSelectionIndex = NSRange(range, in: rawText).lowerBound
        } else {
            self.text = rawText
            self.targetSelectionIndex = 1
        }
        
        self.iconNode = ASImageNode()
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Tip"), color: presentationData.theme.contextMenu.primaryColor)
        
        super.init()
        
        self.clipsToBounds = true
        self.cornerRadius = 14.0
        
        self.backgroundColor = presentationData.theme.contextMenu.backgroundColor
        
        let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: presentationData.theme.contextMenu.primaryColor.withAlphaComponent(0.15), knob: presentationData.theme.contextMenu.primaryColor, knobDiameter: 8.0), strings: presentationData.strings, textNode: self.textNode, updateIsActive: { _ in
        }, present: { _, _ in
        }, rootNode: self, performAction: { _, _ in
        })
        self.textSelectionNode = textSelectionNode
        
        self.addSubnode(self.textNode)
        self.addSubnode(self.iconNode)
        
        self.textSelectionNode.flatMap(self.addSubnode)
        
        self.addSubnode(textSelectionNode.highlightAreaNode)
    }
    
    func updateLayout(widthClass: ContainerViewLayoutSizeClass, width: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        switch widthClass {
        case .compact:
            if let effectView = self.effectView {
                self.effectView = nil
                effectView.removeFromSuperview()
            }
        case .regular:
            if self.effectView == nil {
                let effectView: UIVisualEffectView
                if #available(iOS 13.0, *) {
                    if self.presentationData.theme.overallDarkAppearance {
                        effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
                    } else {
                        effectView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialLight))
                    }
                } else if #available(iOS 10.0, *) {
                    effectView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
                } else {
                    effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
                }
                self.effectView = effectView
                self.view.insertSubview(effectView, at: 0)
            }
        }
        
        let verticalInset: CGFloat = 10.0
        let horizontalInset: CGFloat = 16.0
        let standardIconWidth: CGFloat = 32.0
        let iconSideInset: CGFloat = 12.0
        
        let textFont = Font.regular(floor(presentationData.fontSize.baseDisplaySize * 14.0 / 17.0))
        
        let iconSize = self.iconNode.image?.size ?? CGSize(width: 16.0, height: 16.0)
        
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: self.text, font: textFont, textColor: self.presentationData.theme.contextMenu.primaryColor), backgroundColor: nil, minimumNumberOfLines: 0, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - horizontalInset * 2.0 - iconSize.width - 8.0, height: .greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets(), lineColor: nil, textShadowColor: nil, textStroke: nil))
        let _ = textApply()
        
        let textFrame = CGRect(origin: CGPoint(x: horizontalInset, y: verticalInset), size: textLayout.size)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let size = CGSize(width: width, height: textLayout.size.height + verticalInset * 2.0)
        
        let iconFrame = CGRect(origin: CGPoint(x: size.width - standardIconWidth - iconSideInset + floor((standardIconWidth - iconSize.width) / 2.0), y: floor((size.height - iconSize.height) / 2.0)), size: iconSize)
        transition.updateFrame(node: self.iconNode, frame: iconFrame)
        
        if let textSelectionNode = self.textSelectionNode {
            transition.updateFrame(node: textSelectionNode, frame: textFrame)
            textSelectionNode.highlightAreaNode.frame = textFrame
        }
        
        if let effectView = self.effectView {
            transition.updateFrame(view: effectView, frame: CGRect(origin: CGPoint(), size: size))
        }
        
        return size
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.backgroundColor = presentationData.theme.contextMenu.backgroundColor
    }
    
    func animateIn() {
        if let textSelectionNode = self.textSelectionNode {
            textSelectionNode.pretendInitiateSelection()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.5, execute: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.textSelectionNode?.pretendExtendSelection(to: strongSelf.targetSelectionIndex)
            })
        }
    }
}

final class ContextActionsContainerNode: ASDisplayNode {
    private let actionsNode: InnerActionsContainerNode
    private let textSelectionTipNode: InnerTextSelectionTipContainerNode?
    
    init(presentationData: PresentationData, items: [ContextMenuItem], getController: @escaping () -> ContextController?, actionSelected: @escaping (ContextMenuActionResult) -> Void, feedbackTap: @escaping () -> Void, displayTextSelectionTip: Bool) {
        self.actionsNode = InnerActionsContainerNode(presentationData: presentationData, items: items, getController: getController, actionSelected: actionSelected, feedbackTap: feedbackTap)
        if displayTextSelectionTip {
            let textSelectionTipNode = InnerTextSelectionTipContainerNode(presentationData: presentationData)
            textSelectionTipNode.isUserInteractionEnabled = false
            self.textSelectionTipNode = textSelectionTipNode
        } else {
            self.textSelectionTipNode = nil
        }
        
        super.init()
        
        self.addSubnode(self.actionsNode)
        self.textSelectionTipNode.flatMap(self.addSubnode)
    }
    
    func updateLayout(widthClass: ContainerViewLayoutSizeClass, constrainedWidth: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
        let actionsSize = self.actionsNode.updateLayout(widthClass: widthClass, constrainedWidth: constrainedWidth, transition: transition)
        
        var contentSize = actionsSize
        transition.updateFrame(node: self.actionsNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: actionsSize))
        
        if let textSelectionTipNode = self.textSelectionTipNode {
            contentSize.height += 8.0
            let textSelectionTipSize = textSelectionTipNode.updateLayout(widthClass: widthClass, width: actionsSize.width, transition: transition)
            transition.updateFrame(node: textSelectionTipNode, frame: CGRect(origin: CGPoint(x: 0.0, y: contentSize.height), size: textSelectionTipSize))
            contentSize.height += textSelectionTipSize.height
        }
        
        return contentSize
    }
    
    func actionNode(at point: CGPoint) -> ContextActionNode? {
        return self.actionsNode.actionNode(at: self.view.convert(point, to: self.actionsNode.view))
    }
    
    func updateTheme(presentationData: PresentationData) {
        self.actionsNode.updateTheme(presentationData: presentationData)
        self.textSelectionTipNode?.updateTheme(presentationData: presentationData)
    }
    
    func animateIn() {
        self.textSelectionTipNode?.animateIn()
    }
}
