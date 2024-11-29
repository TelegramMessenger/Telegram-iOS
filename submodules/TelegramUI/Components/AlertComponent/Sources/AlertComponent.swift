import Foundation
import UIKit
import Display
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AsyncDisplayKit

private let alertWidth: CGFloat = 270.0

public enum ComponentAlertActionType {
    case genericAction
    case defaultAction
    case destructiveAction
    case defaultDestructiveAction
}

public struct ComponentAlertAction {
    public let type: ComponentAlertActionType
    public let title: String
    public let action: () -> Void
    
    public init(type: ComponentAlertActionType, title: String, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.action = action
    }
}

public final class ComponentAlertContentActionNode: HighlightableButtonNode {
    private var theme: AlertControllerTheme
    public var action: ComponentAlertAction {
        didSet {
            self.updateTitle()
        }
    }
    
    private let backgroundNode: ASDisplayNode
    
    public var highlightedUpdated: (Bool) -> Void = { _ in }
        
    public init(theme: AlertControllerTheme, action: ComponentAlertAction) {
        self.theme = theme
        self.action = action
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        super.init()
        
        self.titleNode.maximumNumberOfLines = 2
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                strongSelf.setHighlighted(value, animated: true)
            }
        }
        
        self.updateTheme(theme)
    }
    
    public override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        
        self.pointerInteraction = PointerInteraction(node: self, style: .hover, willEnter: { [weak self] in
            if let strongSelf = self {
                strongSelf.setHighlighted(true, animated: false)
            }
        }, willExit: { [weak self] in
            if let strongSelf = self {
                strongSelf.setHighlighted(false, animated: false)
            }
        })
    }
    
    public func performAction() {
        if self.actionEnabled {
            self.action.action()
        }
    }
    
    public func setHighlighted(_ highlighted: Bool, animated: Bool) {
        self.highlightedUpdated(highlighted)
        if highlighted {
            if self.backgroundNode.supernode == nil {
                self.insertSubnode(self.backgroundNode, at: 0)
            }
            self.backgroundNode.alpha = 1.0
        } else {
            if animated {
                UIView.animate(withDuration: 0.3, animations: {
                    self.backgroundNode.alpha = 0.0
                })
            } else {
                self.backgroundNode.alpha = 0.0
            }
        }
    }
    public var actionEnabled: Bool = true {
        didSet {
            self.isUserInteractionEnabled = self.actionEnabled
            self.updateTitle()
        }
    }
    
    public func updateTheme(_ theme: AlertControllerTheme) {
        self.theme = theme
        self.backgroundNode.backgroundColor = theme.highlightedItemColor
        self.updateTitle()
    }
    
    private func updateTitle() {
        var font = Font.regular(theme.baseFontSize)
        var color: UIColor
        switch self.action.type {
            case .defaultAction, .genericAction:
                color = self.actionEnabled ? self.theme.accentColor : self.theme.disabledColor
            case .destructiveAction, .defaultDestructiveAction:
                color = self.actionEnabled ? self.theme.destructiveColor : self.theme.disabledColor
        }
        switch self.action.type {
            case .defaultAction, .defaultDestructiveAction:
                font = Font.semibold(theme.baseFontSize)
            case .destructiveAction, .genericAction:
                break
        }
        self.setAttributedTitle(NSAttributedString(string: self.action.title, font: font, textColor: color, paragraphAlignment: .center), for: [])
        self.accessibilityLabel = self.action.title
        self.accessibilityTraits = [.button]
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override public func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

public enum ComponentAlertContentActionLayout {
    case horizontal
    case vertical
}

public final class ComponentAlertContentNode: AlertContentNode {
    private var theme: AlertControllerTheme
    private let actionLayout: ComponentAlertContentActionLayout
    
    private let content: AnyComponent<Empty>
    private let contentView = ComponentView<Empty>()
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [ComponentAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    private let _dismissOnOutsideTap: Bool
    override public var dismissOnOutsideTap: Bool {
        return self._dismissOnOutsideTap
    }
    
    private var highlightedItemIndex: Int? = nil
    
    public init(theme: AlertControllerTheme, content: AnyComponent<Empty>, actions: [ComponentAlertAction], actionLayout: ComponentAlertContentActionLayout, dismissOnOutsideTap: Bool) {
        self.theme = theme
        self.actionLayout = actionLayout
        self._dismissOnOutsideTap = dismissOnOutsideTap
        self.content = content
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isUserInteractionEnabled = false
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        
        self.actionNodes = actions.map { action -> ComponentAlertContentActionNode in
            return ComponentAlertContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                separatorNode.backgroundColor = theme.separatorColor
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()

        self.addSubnode(self.actionNodesSeparator)
        
        var i = 0
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
            
            let index = i
            actionNode.highlightedUpdated = { [weak self] highlighted in
                if highlighted {
                    self?.highlightedItemIndex = index
                }
            }
            i += 1
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
    }
    
    func setHighlightedItemIndex(_ index: Int?, update: Bool = false) {
        self.highlightedItemIndex = index
        
        if update {
            var i = 0
            for actionNode in self.actionNodes {
                if i == index {
                    actionNode.setHighlighted(true, animated: false)
                } else {
                    actionNode.setHighlighted(false, animated: false)
                }
                i += 1
            }
        }
    }
    
    override public func decreaseHighlightedIndex() {
        let currentHighlightedIndex = self.highlightedItemIndex ?? 0
        
        self.setHighlightedItemIndex(max(0, currentHighlightedIndex - 1), update: true)
    }
    
    override public func increaseHighlightedIndex() {
        let currentHighlightedIndex = self.highlightedItemIndex ?? -1
        
        self.setHighlightedItemIndex(min(self.actionNodes.count - 1, currentHighlightedIndex + 1), update: true)
    }
    
    override public func performHighlightedAction() {
        guard let highlightedItemIndex = self.highlightedItemIndex else {
            return
        }
        
        var i = 0
        for itemNode in self.actionNodes {
            if i == highlightedItemIndex {
                itemNode.performAction()
                return
            }
            i += 1
        }
    }
    
    override public func updateTheme(_ theme: AlertControllerTheme) {
        self.theme = theme

        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        for actionNode in self.actionNodes {
            actionNode.updateTheme(theme)
        }
        for separatorNode in self.actionVerticalSeparators {
            separatorNode.backgroundColor = theme.separatorColor
        }
        
        if let size = self.validLayout {
            _ = self.updateLayout(size: size, transition: .immediate)
        }
    }
    
    override public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        self.validLayout = size
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var size = size
        size.width = min(size.width, alertWidth)
        
        let contentSize = self.contentView.update(
            transition: ComponentTransition(transition),
            component: self.content,
            environment: {},
            containerSize: CGSize(width: size.width - insets.left - insets.right, height: 10000.0)
        )
        
        let actionButtonHeight: CGFloat = 44.0
        
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = self.actionLayout
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionButtonHeight))
            if case .horizontal = effectiveActionLayout, actionTitleSize.height > actionButtonHeight * 0.6667 {
                effectiveActionLayout = .vertical
            }
            switch effectiveActionLayout {
            case .horizontal:
                minActionsWidth += actionTitleSize.width + actionTitleInsets
            case .vertical:
                minActionsWidth = max(minActionsWidth, actionTitleSize.width + actionTitleInsets)
            }
        }
        
        let resultSize: CGSize
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
        case .horizontal:
            actionsHeight = actionButtonHeight
        case .vertical:
            actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let contentWidth = alertWidth - insets.left - insets.right
        
        let contentFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - contentSize.width) / 2.0), y: insets.top), size: contentSize)
        if let contentComponentView = self.contentView.view {
            if contentComponentView.superview == nil {
                self.view.insertSubview(contentComponentView, belowSubview: self.actionNodesSeparator.view)
                transition.updateFrame(view: contentComponentView, frame: contentFrame)
            }
        }
        
        resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: contentSize.height + actionsHeight + insets.top + insets.bottom)
        
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                switch effectiveActionLayout {
                    case .horizontal:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
                    case .vertical:
                        transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
                }
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            switch effectiveActionLayout {
                case .horizontal:
                    if nodeIndex == self.actionNodes.count - 1 {
                        currentActionWidth = resultSize.width - actionOffset
                    } else {
                        currentActionWidth = actionWidth
                    }
                case .vertical:
                    currentActionWidth = resultSize.width
            }
            
            let actionNodeFrame: CGRect
            switch effectiveActionLayout {
                case .horizontal:
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionButtonHeight))
                    actionOffset += actionButtonHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

public func componentAlertController(theme: AlertControllerTheme, content: AnyComponent<Empty>, actions: [ComponentAlertAction], actionLayout: ComponentAlertContentActionLayout = .horizontal, dismissOnOutsideTap: Bool = true) -> AlertController {
    var dismissImpl: (() -> Void)?
    let controller = AlertController(theme: theme, contentNode: ComponentAlertContentNode(theme: theme, content: content, actions: actions.map { action in
        return ComponentAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap))
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
