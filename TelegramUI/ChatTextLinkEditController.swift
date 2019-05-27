import Foundation
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private final class ChatTextLinkEditInputFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    private let theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: EditableTextNode
    private let placeholderNode: ASTextNode
    
    var updateHeight: (() -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 16.0, left: 16.0, bottom: 1.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 10.0, left: 8.0, bottom: 10.0, right: 16.0)
    private let accessoryButtonsWidth: CGFloat = 10.0
    
    var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputTextColor)
            self.placeholderNode.isHidden = !newValue.isEmpty
        }
    }
    
    var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        }
    }
    
    init(theme: PresentationTheme, placeholder: String) {
        self.theme = theme
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.actionSheet.inputBackgroundColor)
        
        self.textInputNode = EditableTextNode()
        self.textInputNode.typingAttributes = [NSAttributedStringKey.font.rawValue: Font.regular(17.0), NSAttributedStringKey.foregroundColor.rawValue: theme.actionSheet.inputTextColor]
        self.textInputNode.clipsToBounds = true
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textContainerInset = UIEdgeInsets(top: self.inputInsets.top, left: 0.0, bottom: self.inputInsets.bottom, right: 0.0)
        self.textInputNode.keyboardAppearance = theme.chatList.searchBarKeyboardColor.keyboardAppearance
        self.textInputNode.keyboardType = .URL
        self.textInputNode.autocapitalizationType = .none
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        
        super.init()
        
        self.textInputNode.delegate = self
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: width)
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + floor((backgroundFrame.size.width - placeholderSize.width) / 2.0), y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right - accessoryButtonsWidth, height: backgroundFrame.size.height)))
        
        return panelHeight
    }
    
    func activateInput() {
        self.textInputNode.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    @objc func editableTextNodeDidUpdateText(_ editableTextNode: ASEditableTextNode) {
        self.updateTextNodeText(animated: true)
    }
    
    func editableTextNodeDidBeginEditing(_ editableTextNode: ASEditableTextNode) {
        self.placeholderNode.isHidden = true
    }
    
    func editableTextNodeDidFinishEditing(_ editableTextNode: ASEditableTextNode) {
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        let accessoryButtonsWidth = self.accessoryButtonsWidth
        
        let unboundTextFieldHeight = max(33.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right - accessoryButtonsWidth, height: CGFloat.greatestFiniteMagnitude)).height))
        
        return min(61.0, max(41.0, unboundTextFieldHeight))
    }
    
    private func updateTextNodeText(animated: Bool) {
        let backgroundInsets = self.backgroundInsets
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: self.bounds.size.width)
        
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        if !self.bounds.size.height.isEqual(to: panelHeight) {
            self.updateHeight?()
        }
    }
    
    @objc func clearPressed() {
        self.textInputNode.attributedText = nil
        self.deactivateInput()
    }
}


private final class ChatTextLinkEditContentActionNode: HighlightableButtonNode {
    private let backgroundNode: ASDisplayNode
    
    let action: TextAlertAction
    
    init(theme: AlertControllerTheme, action: TextAlertAction) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.alpha = 0.0
        
        self.action = action
        
        super.init()
        
        self.titleNode.maximumNumberOfLines = 2
        
        self.highligthedChanged = { [weak self] value in
            if let strongSelf = self {
                if value {
                    if strongSelf.backgroundNode.supernode == nil {
                        strongSelf.insertSubnode(strongSelf.backgroundNode, at: 0)
                    }
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 1.0
                } else if !strongSelf.backgroundNode.alpha.isZero {
                    strongSelf.backgroundNode.alpha = 0.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    func updateTheme(_ theme: AlertControllerTheme) {
        self.backgroundNode.backgroundColor = theme.highlightedItemColor
        
        var font = Font.regular(17.0)
        var color = theme.accentColor
        switch self.action.type {
            case .defaultAction, .genericAction:
                break
            case .destructiveAction:
                color = theme.destructiveColor
        }
        switch self.action.type {
            case .defaultAction:
                font = Font.semibold(17.0)
            case .destructiveAction, .genericAction:
                break
        }
        self.setAttributedTitle(NSAttributedString(string: self.action.title, font: font, textColor: color, paragraphAlignment: .center), for: [])
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
    }
    
    @objc func pressed() {
        self.action.action()
    }
    
    override func layout() {
        super.layout()
        
        self.backgroundNode.frame = self.bounds
    }
}

private final class ChatTextLinkEditAlertContentNode: AlertContentNode {
    private let strings: PresentationStrings
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    private let inputFieldNode: ChatTextLinkEditInputFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [ChatTextLinkEditContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    
    override var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], link: String?) {
        self.strings = strings
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 2
        self.textNode = ASTextNode()
        self.textNode.maximumNumberOfLines = 2
        
        self.inputFieldNode = ChatTextLinkEditInputFieldNode(theme: ptheme, placeholder: "")
        self.inputFieldNode.text = link ?? ""
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> ChatTextLinkEditContentActionNode in
            return ChatTextLinkEditContentActionNode(theme: theme, action: action)
        }
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if actions.count > 1 {
            for _ in 0 ..< actions.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.titleNode)
        
        self.addSubnode(self.inputFieldNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.inputFieldNode.updateHeight = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.validLayout {
                    strongSelf.requestLayout?(.animated(duration: 0.15, curve: .spring))
                }
            }
        }
        
        self.updateTheme(theme)
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    var link: String {
        return self.inputFieldNode.text
    }
    
    override func updateTheme(_ theme: AlertControllerTheme) {
        self.titleNode.attributedText = NSAttributedString(string: "Add Link", font: Font.bold(17.0), textColor: theme.primaryColor, paragraphAlignment: .center)

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
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        var size = size
        size.width = min(size.width , 270.0)
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 20.0)
        
        let titleSize = self.titleNode.measure(size)
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: origin.y), size: titleSize))
        origin.y += titleSize.height + 6.0
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.measure(CGSize(width: maxActionWidth, height: actionButtonHeight))
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
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        var contentWidth = max(titleSize.width, minActionsWidth)
        contentWidth = max(contentWidth, 234.0)
        
        var actionsHeight: CGFloat = 0.0
        switch effectiveActionLayout {
            case .horizontal:
                actionsHeight = actionButtonHeight
            case .vertical:
                actionsHeight = actionButtonHeight * CGFloat(self.actionNodes.count)
        }
        
        let resultWidth = contentWidth + insets.left + insets.right
        
        let inputFieldWidth = resultWidth
        let inputFieldHeight = self.inputFieldNode.updateLayout(width: inputFieldWidth, transition: transition)
        let inputHeight = inputFieldHeight
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(x: 0.0, y: origin.y, width: resultWidth, height: inputFieldHeight))
        transition.updateAlpha(node: self.inputFieldNode, alpha: inputHeight > 0.0 ? 1.0 : 0.0)
        
        let resultSize = CGSize(width: resultWidth, height: titleSize.height + actionsHeight + inputHeight + insets.top + insets.bottom)
        
        transition.updateFrame(node: self.actionNodesSeparator, frame: CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel)))
        
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
        
        if !hadValidLayout {
            self.inputFieldNode.activateInput()
        }
        
        return resultSize
    }
}

func chatTextLinkEditController(sharedContext: SharedAccountContext, account: Account, link: String?, apply: @escaping (String) -> Void) -> AlertController {
    let presentationData = sharedContext.currentPresentationData.with { $0 }
    let theme = presentationData.theme
    let strings = presentationData.strings
    
    var dismissImpl: ((Bool) -> Void)?
    var contentNode: ChatTextLinkEditAlertContentNode?
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Done, action: {
        dismissImpl?(true)
        apply(contentNode?.link ?? "")
    })]
    
    contentNode = ChatTextLinkEditAlertContentNode(theme: AlertControllerTheme(presentationTheme: theme), ptheme: theme, strings: strings, actions: actions, link: link)
    
    let controller = AlertController(theme: AlertControllerTheme(presentationTheme: theme), contentNode: contentNode!)
    dismissImpl = { [weak controller] animated in
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
