import Foundation
import UIKit
import AsyncDisplayKit
import Markdown
import Display
import TelegramPresentationData
import ComponentFlow
import ToastComponent
import Markdown
import LottieComponent
import MultilineTextComponent
import ComponentDisplayAdapters

private let alertWidth: CGFloat = 270.0

private final class SuggestedPostApproveAlertContentNode: AlertContentNode {
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
    
    public init(theme: AlertControllerTheme, title: NSAttributedString?, text: NSAttributedString, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout, dismissOnOutsideTap: Bool, linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil) {
        self.theme = theme
        self.actionLayout = actionLayout
        self._dismissOnOutsideTap = dismissOnOutsideTap
        if let title = title {
            let titleNode = ImmediateTextNode()
            titleNode.attributedText = title
            titleNode.displaysAsynchronously = false
            titleNode.isUserInteractionEnabled = false
            titleNode.maximumNumberOfLines = 4
            titleNode.truncationType = .end
            titleNode.isAccessibilityElement = true
            titleNode.accessibilityLabel = title.string
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

private final class SuggestedPostAlertImpl: AlertController {
    private let toastText: String?
    private var toast: ComponentView<Empty>?
    
    init(theme: AlertControllerTheme, contentNode: AlertContentNode, allowInputInset: Bool, toastText: String?) {
        self.toastText = toastText
        
        super.init(theme: theme, contentNode: contentNode, allowInputInset: allowInputInset)
        
        self.willDismiss = { [weak self] in
            guard let self else {
                return
            }
            if let toastView = self.toast?.view {
                toastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if let toastText = self.toastText {
            let toast: ComponentView<Empty>
            if let current = self.toast {
                toast = current
            } else {
                toast = ComponentView()
                self.toast = toast
            }
            let body = MarkdownAttributeSet(font: Font.regular(14.0), textColor: .white)
            let bold = MarkdownAttributeSet(font: Font.semibold(14.0), textColor: .white)
            let playOnce = ActionSlot<Void>()
            let toastSize = toast.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(ToastContentComponent(
                    icon: AnyComponent(LottieComponent(
                        content: LottieComponent.AppBundleContent(name: "anim_infotip"),
                        startingPosition: .begin,
                        size: CGSize(width: 32.0, height: 32.0),
                        playOnce: playOnce
                    )),
                    content: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: 0, component: AnyComponent(MultilineTextComponent(
                            text: .markdown(text: toastText, attributes: MarkdownAttributes(body: body, bold: bold, link: body, linkAttribute: { _ in nil })),
                            maximumNumberOfLines: 0
                        )))
                    ], alignment: .left, spacing: 6.0)),
                    insets: UIEdgeInsets(top: 10.0, left: 12.0, bottom: 10.0, right: 10.0),
                    iconSpacing: 12.0
                )),
                environment: {},
                containerSize: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right - 12.0 * 2.0, height: 1000.0)
            )
            let toastFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left + 12.0, y: layout.insets(options: .statusBar).top + 4.0), size: toastSize)
            if let toastView = toast.view {
                if toastView.superview == nil {
                    self.view.addSubview(toastView)
                    playOnce.invoke(())
                }
                transition.updatePosition(layer: toastView.layer, position: toastFrame.center)
                transition.updateBounds(layer: toastView.layer, bounds: CGRect(origin: CGPoint(), size: toastFrame.size))
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let toastView = self.toast?.view {
            toastView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        }
    }
    
    override func dismissAnimated() {
        super.dismissAnimated()
        
        if let toastView = self.toast?.view {
            toastView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        }
    }
}

public func SuggestedPostApproveAlert(presentationData: PresentationData, title: String?, text: String, actions: [TextAlertAction], actionLayout: TextAlertContentActionLayout = .horizontal, allowInputInset: Bool = true, parseMarkdown: Bool = false, dismissOnOutsideTap: Bool = true, linkAction: (([NSAttributedString.Key: Any], Int) -> Void)? = nil, toastText: String?) -> AlertController {
    let theme = AlertControllerTheme(presentationData: presentationData)

    var dismissImpl: (() -> Void)?
    let attributedText: NSAttributedString
    if parseMarkdown {
        let font = title == nil ? Font.semibold(theme.baseFontSize) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0))
        let boldFont = title == nil ? Font.bold(theme.baseFontSize) : Font.semibold(floor(theme.baseFontSize * 13.0 / 17.0))
        let body = MarkdownAttributeSet(font: font, textColor: theme.primaryColor)
        let bold = MarkdownAttributeSet(font: boldFont, textColor: theme.primaryColor)
        let link = MarkdownAttributeSet(font: font, textColor: theme.accentColor)
        attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(body: body, bold: bold, link: link, linkAttribute: { url in
            return ("URL", url)
        }), textAlignment: .center)
    } else {
        attributedText = NSAttributedString(string: text, font: title == nil ? Font.semibold(theme.baseFontSize) : Font.regular(floor(theme.baseFontSize * 13.0 / 17.0)), textColor: theme.primaryColor, paragraphAlignment: .center)
    }
    let controller = SuggestedPostAlertImpl(theme: theme, contentNode: TextAlertContentNode(theme: theme, title: title != nil ? NSAttributedString(string: title!, font: Font.semibold(theme.baseFontSize), textColor: theme.primaryColor, paragraphAlignment: .center) : nil, text: attributedText, actions: actions.map { action in
        return TextAlertAction(type: action.type, title: action.title, action: {
            dismissImpl?()
            action.action()
        })
    }, actionLayout: actionLayout, dismissOnOutsideTap: dismissOnOutsideTap, linkAction: linkAction), allowInputInset: allowInputInset, toastText: toastText)
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
