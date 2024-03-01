import Foundation
import UIKit
import SwiftSignalKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BalancedTextComponent
import EmojiStatusComponent

private final class PromptInputFieldNode: ASDisplayNode, ASEditableTextNodeDelegate {
    private var theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: EditableTextNode
    private let placeholderNode: ASTextNode
    private let characterLimitView = ComponentView<Empty>()
    
    private let characterLimit: Int
    
    var updateHeight: (() -> Void)?
    var complete: (() -> Void)?
    var textChanged: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 15.0, right: 16.0)
    private let inputInsets: UIEdgeInsets
    
    private let validCharacterSets: [CharacterSet]
    
    var text: String {
        get {
            return self.textInputNode.attributedText?.string ?? ""
        }
        set {
            self.textInputNode.attributedText = NSAttributedString(string: newValue, font: Font.regular(13.0), textColor: self.theme.actionSheet.inputTextColor)
            self.placeholderNode.isHidden = !newValue.isEmpty
        }
    }
    
    var placeholder: String = "" {
        didSet {
            self.placeholderNode.attributedText = NSAttributedString(string: self.placeholder, font: Font.regular(13.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        }
    }
    
    init(theme: PresentationTheme, placeholder: String, characterLimit: Int) {
        self.theme = theme
        self.characterLimit = characterLimit
        
        self.inputInsets = UIEdgeInsets(top: 9.0, left: 6.0, bottom: 9.0, right: 16.0)
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        
        self.textInputNode = EditableTextNode()
        self.textInputNode.typingAttributes = [NSAttributedString.Key.font.rawValue: Font.regular(13.0), NSAttributedString.Key.foregroundColor.rawValue: theme.actionSheet.inputTextColor]
        self.textInputNode.clipsToBounds = true
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textContainerInset = UIEdgeInsets(top: self.inputInsets.top, left: self.inputInsets.left, bottom: self.inputInsets.bottom, right: self.inputInsets.right)
        self.textInputNode.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.keyboardType = .default
        self.textInputNode.autocapitalizationType = .none
        self.textInputNode.returnKeyType = .done
        self.textInputNode.autocorrectionType = .no
        self.textInputNode.tintColor = theme.actionSheet.controlAccentColor
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(13.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        
        self.validCharacterSets = [
            CharacterSet.alphanumerics,
            CharacterSet(charactersIn: "0123456789_"),
        ]
        
        super.init()
        
        self.textInputNode.delegate = self
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 16.0, color: self.theme.actionSheet.inputHollowBackgroundColor, strokeColor: self.theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        self.textInputNode.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.placeholderNode.attributedText = NSAttributedString(string: self.placeholderNode.attributedText?.string ?? "", font: Font.regular(13.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        self.textInputNode.tintColor = self.theme.actionSheet.controlAccentColor
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: width)
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left + 5.0, y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right, height: backgroundFrame.size.height)))
        
        let characterLimitString: String
        let characterLimitColor: UIColor
        if self.text.count <= self.characterLimit {
            let remaining = self.characterLimit - self.text.count
            if remaining < 5 {
                characterLimitString = "\(remaining)"
            } else {
                characterLimitString = " "
            }
            characterLimitColor = self.theme.list.itemPlaceholderTextColor
        } else {
            characterLimitString = "\(self.characterLimit - self.text.count)"
            characterLimitColor = self.theme.list.itemDestructiveColor
        }
        
        let characterLimitSize = self.characterLimitView.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: characterLimitString, font: Font.regular(13.0), textColor: characterLimitColor))
            )),
            environment: {},
            containerSize: CGSize(width: 100.0, height: 100.0)
        )
        if let characterLimitComponentView = self.characterLimitView.view {
            if characterLimitComponentView.superview == nil {
                self.view.addSubview(characterLimitComponentView)
            }
            characterLimitComponentView.frame = CGRect(origin: CGPoint(x: width - 23.0 - characterLimitSize.width, y: 18.0), size: characterLimitSize)
        }
        
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
        self.textChanged?(editableTextNode.textView.text)
        self.placeholderNode.isHidden = !(editableTextNode.textView.text ?? "").isEmpty
    }
    
    func editableTextNode(_ editableTextNode: ASEditableTextNode, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text == "\n" {
            self.complete?()
            return false
        }
        if text.unicodeScalars.contains(where: { c in
            return !self.validCharacterSets.contains(where: { set in
                return set.contains(c)
            })
        }) {
            return false
        }
        return true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let unboundTextFieldHeight = max(34.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right, height: CGFloat.greatestFiniteMagnitude)).height))
        
        return min(61.0, max(34.0, unboundTextFieldHeight))
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

public final class QuickReplyNameAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private var theme: AlertControllerTheme
    private let strings: PresentationStrings
    private let text: String
    private let subtext: String
    private let titleFont: PromptControllerTitleFont

    private let textView = ComponentView<Empty>()
    private let subtextView = ComponentView<Empty>()
    
    fileprivate let inputFieldNode: PromptInputFieldNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let disposable = MetaDisposable()
    
    private var validLayout: CGSize?
    private var errorText: String?
    
    private let hapticFeedback = HapticFeedback()
    
    var complete: (() -> Void)?
    
    override public var dismissOnOutsideTap: Bool {
        return self.isUserInteractionEnabled
    }
    
    init(context: AccountContext, theme: AlertControllerTheme, ptheme: PresentationTheme, strings: PresentationStrings, actions: [TextAlertAction], text: String, subtext: String, titleFont: PromptControllerTitleFont, value: String?, characterLimit: Int) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.text = text
        self.subtext = subtext
        self.titleFont = titleFont
        
        self.inputFieldNode = PromptInputFieldNode(theme: ptheme, placeholder: strings.QuickReply_ShortcutPlaceholder, characterLimit: characterLimit)
        self.inputFieldNode.text = value ?? ""
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        
        self.actionNodes = actions.map { action -> TextAlertContentActionNode in
            return TextAlertContentActionNode(theme: theme, action: action)
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
        
        self.addSubnode(self.inputFieldNode)

        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        self.actionNodes.last?.actionEnabled = true
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.inputFieldNode.updateHeight = { [weak self] in
            if let strongSelf = self {
                if let _ = strongSelf.validLayout {
                    strongSelf.requestLayout?(.immediate)
                }
            }
        }
        
        self.inputFieldNode.textChanged = { [weak self] text in
            if let strongSelf = self, let lastNode = strongSelf.actionNodes.last {
                lastNode.actionEnabled = text.count <= characterLimit
                strongSelf.requestLayout?(.immediate)
            }
        }
        
        self.updateTheme(theme)
        
        self.inputFieldNode.complete = { [weak self] in
            guard let self else {
                return
            }
            if let lastNode = self.actionNodes.last, lastNode.actionEnabled {
                self.complete?()
            }
        }
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    var value: String {
        return self.inputFieldNode.text
    }
    
    public func setErrorText(errorText: String?) {
        if self.errorText != errorText {
            self.errorText = errorText
            self.requestLayout?(.immediate)
        }
        
        if errorText != nil {
            HapticFeedback().error()
            self.inputFieldNode.layer.addShakeAnimation()
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
        var size = size
        size.width = min(size.width, 270.0)
        let measureSize = CGSize(width: size.width - 16.0 * 2.0, height: CGFloat.greatestFiniteMagnitude)
        
        let hadValidLayout = self.validLayout != nil
        
        self.validLayout = size
        
        var origin: CGPoint = CGPoint(x: 0.0, y: 16.0)
        let spacing: CGFloat = 5.0
        let subtextSpacing: CGFloat = -1.0
        
        let textSize = self.textView.update(
            transition: .immediate,
            component: AnyComponent(MultilineTextComponent(
                text: .plain(NSAttributedString(string: self.text, font: Font.semibold(17.0), textColor: self.theme.primaryColor)),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: measureSize.width, height: 1000.0)
        )
        let textFrame = CGRect(origin: CGPoint(x: floor((size.width - textSize.width) * 0.5), y: origin.y), size: textSize)
        if let textComponentView = self.textView.view {
            if textComponentView.superview == nil {
                textComponentView.layer.anchorPoint = CGPoint()
                self.view.addSubview(textComponentView)
            }
            textComponentView.bounds = CGRect(origin: CGPoint(), size: textFrame.size)
            transition.updatePosition(layer: textComponentView.layer, position: textFrame.origin)
        }
        origin.y += textSize.height + 6.0 + subtextSpacing
        
        let subtextSize = self.subtextView.update(
            transition: .immediate,
            component: AnyComponent(BalancedTextComponent(
                text: .plain(NSAttributedString(string: self.errorText ?? self.subtext, font: Font.regular(13.0), textColor: self.errorText != nil ? self.theme.destructiveColor : self.theme.primaryColor)),
                horizontalAlignment: .center,
                maximumNumberOfLines: 0
            )),
            environment: {},
            containerSize: CGSize(width: measureSize.width, height: 1000.0)
        )
        let subtextFrame = CGRect(origin: CGPoint(x: floor((size.width - subtextSize.width) * 0.5), y: origin.y), size: subtextSize)
        if let subtextComponentView = self.subtextView.view {
            if subtextComponentView.superview == nil {
                subtextComponentView.layer.anchorPoint = CGPoint()
                self.view.addSubview(subtextComponentView)
            }
            subtextComponentView.bounds = CGRect(origin: CGPoint(), size: subtextFrame.size)
            transition.updatePosition(layer: subtextComponentView.layer, position: subtextFrame.origin)
        }
        origin.y += subtextSize.height + 6.0 + spacing
        
        let actionButtonHeight: CGFloat = 44.0
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        
        var effectiveActionLayout = TextAlertContentActionLayout.horizontal
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
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 9.0, right: 18.0)
        
        var contentWidth = max(textSize.width, minActionsWidth)
        contentWidth = max(subtextSize.width, minActionsWidth)
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
        let inputFieldFrame = CGRect(x: 0.0, y: origin.y, width: resultWidth, height: inputFieldHeight)
        transition.updateFrame(node: self.inputFieldNode, frame: inputFieldFrame)
        transition.updateAlpha(node: self.inputFieldNode, alpha: inputHeight > 0.0 ? 1.0 : 0.0)
        
        let resultSize = CGSize(width: resultWidth, height: textSize.height + subtextSpacing + subtextSize.height + spacing + inputHeight + actionsHeight + insets.top + insets.bottom)
        
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
    
    func animateError() {
        self.inputFieldNode.layer.addShakeAnimation()
        self.hapticFeedback.error()
    }
}

public enum PromptControllerTitleFont {
    case regular
    case bold
}

public func quickReplyNameAlertController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, text: String, subtext: String, titleFont: PromptControllerTitleFont = .regular, value: String?, characterLimit: Int = 1000, apply: @escaping (String?) -> Void) -> AlertController {
    let presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
    
    var dismissImpl: ((Bool) -> Void)?
    var applyImpl: (() -> Void)?
    
    let actions: [TextAlertAction] = [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
        dismissImpl?(true)
        apply(nil)
    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Done, action: {
        applyImpl?()
    })]
    
    let contentNode = QuickReplyNameAlertContentNode(context: context, theme: AlertControllerTheme(presentationData: presentationData), ptheme: presentationData.theme, strings: presentationData.strings, actions: actions, text: text, subtext: subtext, titleFont: titleFont, value: value, characterLimit: characterLimit)
    contentNode.complete = {
        applyImpl?()
    }
    applyImpl = { [weak contentNode] in
        guard let contentNode = contentNode else {
            return
        }
        apply(contentNode.value)
    }
    
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: contentNode)
    let presentationDataDisposable = (updatedPresentationData?.signal ?? context.sharedContext.presentationData).start(next: { [weak controller, weak contentNode] presentationData in
        controller?.theme = AlertControllerTheme(presentationData: presentationData)
        contentNode?.inputFieldNode.updateTheme(presentationData.theme)
    })
    controller.dismissed = { _ in
        presentationDataDisposable.dispose()
    }
    dismissImpl = { [weak controller] animated in
        contentNode.inputFieldNode.deactivateInput()
        if animated {
            controller?.dismissAnimated()
        } else {
            controller?.dismiss()
        }
    }
    return controller
}
