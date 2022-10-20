import Foundation
import UIKit
import AsyncDisplayKit
import Markdown

private let alertWidth: CGFloat = 270.0

public enum TextAlertActionType {
    case genericAction
    case defaultAction
    case destructiveAction
}

public struct TextAlertAction {
    public let type: TextAlertActionType
    public let title: String
    public let action: () -> Void
    
    public init(type: TextAlertActionType, title: String, action: @escaping () -> Void) {
        self.type = type
        self.title = title
        self.action = action
    }
}

public final class TextAlertContentActionNode: HighlightableButtonNode {
    private var theme: AlertControllerTheme
    let action: TextAlertAction
    
    private let backgroundNode: ASDisplayNode
    
    var highlightedUpdated: (Bool) -> Void = { _ in }
        
    public init(theme: AlertControllerTheme, action: TextAlertAction) {
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
    
    func performAction() {
        if self.actionEnabled {
            self.action.action()
        }
    }
    
    func setHighlighted(_ highlighted: Bool, animated: Bool) {
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
            case .destructiveAction:
                color = self.actionEnabled ? self.theme.destructiveColor : self.theme.disabledColor
        }
        switch self.action.type {
            case .defaultAction:
                font = Font.semibold(theme.baseFontSize)
            case .destructiveAction, .genericAction:
                break
        }
        self.setAttributedTitle(NSAttributedString(string: self.action.title, font: font, textColor: color, paragraphAlignment: .center), for: [])
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override public func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

public enum TextAlertContentActionLayout {
    case horizontal
    case vertical
}

public final class TextAlertContentNode: AlertContentNode {
    private var theme: AlertControllerTheme
    private let actionLayout: TextAlertContentActionLayout
    
    private let titleNode: ImmediateTextNode?
    private let textNode: ImmediateTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private var validLayout: CGSize?
    
    private let _dismissOnOutsideTap: Bool
    override public var dismissOnOutsideTap: Bool {
        return self._dismissOnOutsideTap
    }
    
    private var highlightedItemIndex: Int? = nil
    
    public var textAttributeAction: (NSAttributedString.Key, (Any) -> Void)? {
        didSet {
            if let (attribute, textAttributeAction) = self.textAttributeAction {
                self.textNode.highlightAttributeAction = { attributes in
                    if let _ = attributes[attribute] {
                        return attribute
                    } else {
                        return nil
                    }
                }
                self.textNode.tapAttributeAction = { attributes, _ in
                    if let value = attributes[attribute] {
                        textAttributeAction(value)
                    }
                }
                self.textNode.linkHighlightColor = self.theme.accentColor.withAlphaComponent(0.5)
            } else {
                self.textNode.highlightAttributeAction = nil
                self.textNode.tapAttributeAction = nil
            }
        }
    }
    
    public init(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout, dismissOnOutsideTap: Bool) {
        self.theme = theme
        self.actionLayout = actionLayout
        self._dismissOnOutsideTap = dismissOnOutsideTap
        if let title = title {
            let titleNode = ImmediateTextNode()
            titleNode.attributedText = title
            titleNode.displaysAsynchronously = false
            titleNode.isUserInteractionEnabled = false
            titleNode.maximumNumberOfLines = 2
            titleNode.truncationType = .end
            titleNode.isAccessibilityElement = true
            self.titleNode = titleNode
        } else {
            self.titleNode = nil
        }
        
        self.textNode = ImmediateTextNode()
        self.textNode.maximumNumberOfLines = 0
        self.textNode.attributedText = text
        self.textNode.displaysAsynchronously = false
        self.textNode.isLayerBacked = false
        self.textNode.isAccessibilityElement = true
        self.textNode.accessibilityLabel = text.string
        self.textNode.insets = UIEdgeInsets(top: 1.0, left: 1.0, bottom: 1.0, right: 1.0)
        if text.length != 0 {
            if let paragraphStyle = text.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
                self.textNode.textAlignment = paragraphStyle.alignment
            }
        }
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = theme.separatorColor
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
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
        
        if let titleNode = self.titleNode {
            self.addSubnode(titleNode)
        }
        self.addSubnode(self.textNode)

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
        
        if let titleNode = self.titleNode, let attributedText = titleNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            titleNode.attributedText = updatedText
        }
        if let attributedText = self.textNode.attributedText {
            let updatedText = NSMutableAttributedString(attributedString: attributedText)
            updatedText.addAttribute(NSAttributedString.Key.foregroundColor, value: theme.primaryColor, range: NSRange(location: 0, length: updatedText.length))
            self.textNode.attributedText = updatedText
        }

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
        
        var titleSize: CGSize?
        if let titleNode = self.titleNode {
            titleSize = titleNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        }
        let textSize = self.textNode.updateLayout(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
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
        if let titleNode = self.titleNode, let titleSize = titleSize {
            let spacing: CGFloat = 6.0
            let titleFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - titleSize.width) / 2.0), y: insets.top), size: titleSize)
            transition.updateFrame(node: titleNode, frame: titleFrame)
            
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: titleFrame.maxY + spacing), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame.offsetBy(dx: -1.0, dy: -1.0))
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom)
        } else {
            let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: insets.top), size: textSize)
            transition.updateFrame(node: self.textNode, frame: textFrame)
            
            resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: textSize.height + actionsHeight + insets.top + insets.bottom)
        }
        
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

public func textAlertController(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, dismissOnOutsideTap: Bool = true) -> AlertController {
    return AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap))
}

public func standardTextAlertController(theme: AlertControllerTheme, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true) -> AlertController {
    var dismissImpl: (() -> Void)?
    let attributedText: NSAttributedString
    if parseMarkdown {
        let font = title == nil ? Font.semibold(theme.baseFontSize * 13.0 / 17.0) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        let boldFont = title == nil ? Font.bold(theme.baseFontSize * 13.0 / 17.0) : Font.semibold(floor(theme.baseFontSize * 13.0 / 17.0))
        let body = MarkdownAttributeSet(font: font, textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: theme.primaryColor)
        attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil }), textAlignment: .center)
    } else {
        attributedText = NSAttributedString(string: text, font: title == nil ? Font.semibold(theme.baseFontSize) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0)), textColor: theme.primaryColor, paragraphAlignment: .center)
    }
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title != nil ? NSAttributedString(string: title!, font: Font.semibold(theme.baseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center) : nil, text: attributedText, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap), allowInputInset: allowInputInset)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
