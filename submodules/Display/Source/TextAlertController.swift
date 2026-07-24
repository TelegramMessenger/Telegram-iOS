import Foundation
import UIKit
import AsyncDisplayKit
import Markdown

private let alertWidth: CGFloat = 270.0

public enum TextAlertActionType {
    case genericAction
    case defaultAction
    case destructiveAction
    case defaultDestructiveAction
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
    public var action: TextAlertAction {
        didSet {
            self.updateTitle()
        }
    }
    
    private let backgroundNode: ASDisplayNode
    
    public var highlightedUpdated: (Bool) -> Void = { _ in }
        
    public init(theme: AlertControllerTheme, action: TextAlertAction) {
        self.theme = theme
        self.action = action
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        super.init()
        
        self.titleNode.maximumNumberOfLines = 0
        
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
        let fontSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: theme.baseFontSize)
        var font = Font.regular(fontSize)
        var color: UIColor
        switch self.action.type {
            case .defaultAction, .genericAction:
                color = self.actionEnabled ? self.theme.accentColor : self.theme.disabledColor
            case .destructiveAction, .defaultDestructiveAction:
                color = self.actionEnabled ? self.theme.destructiveColor : self.theme.disabledColor
        }
        switch self.action.type {
            case .defaultAction, .defaultDestructiveAction:
                font = Font.semibold(fontSize)
            case .destructiveAction, .genericAction:
                break
        }
        
        let attributedString = NSMutableAttributedString(string: self.action.title, font: font, textColor: color, paragraphAlignment: .center)
        if let range = attributedString.string.range(of: "$") {
            attributedString.addAttribute(.attachment, value: UIImage(bundleImageName: "Item List/PremiumIcon")!, range: NSRange(range, in: attributedString.string))
            attributedString.addAttribute(.foregroundColor, value: color, range: NSRange(range, in: attributedString.string))
            attributedString.addAttribute(.baselineOffset, value: 2.0, range: NSRange(range, in: attributedString.string))
        }
        
        self.setAttributedTitle(attributedString, for: [])
        self.accessibilityLabel = self.action.title
        var accessibilityTraits: UIAccessibilityTraits = [.button]
        if !self.actionEnabled {
            accessibilityTraits.insert(.notEnabled)
        }
        self.accessibilityTraits = accessibilityTraits
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
    private let dynamicTypeTitle: String?
    private let dynamicTypeText: String?
    private let dynamicTypeParseMarkdown: Bool
    
    private var validLayout: CGSize?
    
    private let _dismissOnOutsideTap: Bool
    override public var dismissOnOutsideTap: Bool {
        return self._dismissOnOutsideTap
    }
    
    override public var accessibilityInitialFocusNode: ASDisplayNode? {
        return self.titleNode ?? self.textNode
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
    
    public init(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout, dismissOnOutsideTap: Bool, linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil, dynamicTypeTitle: String? = nil, dynamicTypeText: String? = nil, dynamicTypeParseMarkdown: Bool = false) {
        self.theme = theme
        self.actionLayout = actionLayout
        self._dismissOnOutsideTap = dismissOnOutsideTap
        self.dynamicTypeTitle = dynamicTypeTitle
        self.dynamicTypeText = dynamicTypeText
        self.dynamicTypeParseMarkdown = dynamicTypeParseMarkdown
        if let title = title {
            let titleNode = ImmediateTextNode()
            titleNode.attributedText = title
            titleNode.displaysAsynchronously = false
            titleNode.isUserInteractionEnabled = false
            titleNode.maximumNumberOfLines = 0
            titleNode.truncationType = .end
            titleNode.isAccessibilityElement = true
            titleNode.accessibilityLabel = title.string
            titleNode.accessibilityTraits = [.header]
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
        self.textNode.tapAttributeAction = linkAction
        self.textNode.highlightAttributeAction = { attributes in
            if let _ = attributes[NSAttributedString.Key(rawValue: "URL")] {
                return NSAttributedString.Key(rawValue: "URL")
            } else {
                return nil
            }
        }
        self.textNode.linkHighlightColor = theme.accentColor.withMultipliedAlpha(0.1)
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
    
    override public func contentSizeCategoryUpdated() {
        for actionNode in self.actionNodes {
            actionNode.updateTheme(self.theme)
        }
        if let dynamicTypeText = self.dynamicTypeText {
            let attributedStrings = standardTextAlertAttributedStrings(theme: self.theme, title: self.dynamicTypeTitle, text: dynamicTypeText, parseMarkdown: self.dynamicTypeParseMarkdown)
            self.titleNode?.attributedText = attributedStrings.title
            self.textNode.attributedText = attributedStrings.text
        }
        self.requestLayout?(.immediate)
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
        
        let minimumActionButtonHeight: CGFloat = 44.0
        let maxActionWidth: CGFloat = self.actionNodes.isEmpty ? size.width : floor(size.width / CGFloat(self.actionNodes.count))
        
        var effectiveActionLayout = self.actionLayout
        if self.traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            effectiveActionLayout = .vertical
        }
        var actionHeights: [CGFloat] = []
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: max(1.0, maxActionWidth - 16.0), height: CGFloat.greatestFiniteMagnitude))
            let actionHeight = max(minimumActionButtonHeight, actionTitleSize.height + 20.0)
            actionHeights.append(actionHeight)
            if case .horizontal = effectiveActionLayout, actionHeight > minimumActionButtonHeight {
                effectiveActionLayout = .vertical
            }
        }
        
        let resultSize: CGSize
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionHeights.max() ?? minimumActionButtonHeight
            case .vertical:
                actionsHeight = actionHeights.reduce(0.0, +)
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
        
        self.actionNodesSeparator.isHidden = self.actionNodes.isEmpty
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = self.actionNodes.isEmpty ? resultSize.width : floor(resultSize.width / CGFloat(self.actionNodes.count))
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
                    actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionsHeight))
                    actionOffset += currentActionWidth
                case .vertical:
                    let actionHeight = actionHeights[nodeIndex]
                    actionNodeFrame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight + actionOffset), size: CGSize(width: currentActionWidth, height: actionHeight))
                    actionOffset += actionHeight
            }
            
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        return resultSize
    }
}

private func standardTextAlertAttributedStrings(theme: AlertControllerTheme, title: String?, text: String, parseMarkdown: Bool) -> (title: NSAttributedString?, text: NSAttributedString) {
    let titleFontSize = UIFontMetrics(forTextStyle: .headline).scaledValue(for: theme.baseFontSize)
    let bodyBaseFontSize = title == nil ? theme.baseFontSize : floor(theme.baseFontSize * 13.0 / 17.0)
    let bodyFontSize = UIFontMetrics(forTextStyle: .body).scaledValue(for: bodyBaseFontSize)

    let attributedTitle = title.flatMap {
        NSAttributedString(string: $0, font: Font.semibold(titleFontSize), textColor: theme.primaryColor, paragraphAlignment: .center)
    }
    let attributedText: NSAttributedString
    if parseMarkdown {
        let font = title == nil ? Font.semibold(bodyFontSize) : Font.regular(bodyFontSize)
        let boldFont = title == nil ? Font.bold(bodyFontSize) : Font.semibold(bodyFontSize)
        let body = MarkdownAttributeSet(font: font, textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: theme.primaryColor)
        let link = MarkdownAttributeSet(font: font, textColor: theme.accentColor)
        attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { url in
            return ("URL", url)
        }), textAlignment: .center)
    } else {
        let font = title == nil ? Font.semibold(bodyFontSize) : Font.regular(bodyFontSize)
        attributedText = NSAttributedString(string: text, font: font, textColor: theme.primaryColor, paragraphAlignment: .center)
    }
    return (attributedTitle, attributedText)
}

public func textAlertController(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, dismissOnOutsideTap: Bool = true, linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil) -> AlertController {
    return AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title, text: text, actions: actions, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap, linkAction: linkAction))
}

public func standardTextAlertController(theme: AlertControllerTheme, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true, linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil) -> AlertController {
    var dismissImpl: (() -> Void)?
    let attributedStrings = standardTextAlertAttributedStrings(theme: theme, title: title, text: text, parseMarkdown: parseMarkdown)
    let controller = AlertController(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: attributedStrings.title, text: attributedStrings.text, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap, linkAction: linkAction, dynamicTypeTitle: title, dynamicTypeText: text, dynamicTypeParseMarkdown: parseMarkdown), allowInputInset: allowInputInset)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
