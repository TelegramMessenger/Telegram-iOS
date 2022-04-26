import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

private final class BotCheckoutPassworInputFieldNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    private let backgroundNode: ASImageNode
    private let textInputNode: TextFieldNode
    private let placeholderNode: ASTextNode
    
    var updateHeight: (() -> Void)?
    var complete: (() -> Void)?
    var textChanged: ((String) -> Void)?
    
    private let backgroundInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 15.0, right: 16.0)
    private let inputInsets = UIEdgeInsets(top: 5.0, left: 12.0, bottom: 5.0, right: 12.0)
    
    var text: String {
        get {
            return self.textInputNode.textField.text ?? ""
        }
        set {
            self.textInputNode.textField.text = newValue
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
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: theme.actionSheet.inputHollowBackgroundColor, strokeColor: theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        
        self.textInputNode = TextFieldNode()
        self.textInputNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(17.0), NSAttributedString.Key.foregroundColor: theme.actionSheet.inputTextColor]
        self.textInputNode.textField.clipsToBounds = true
        self.textInputNode.hitTestSlop = UIEdgeInsets(top: -5.0, left: -5.0, bottom: -5.0, right: -5.0)
        self.textInputNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textInputNode.textField.returnKeyType = .done
        self.textInputNode.textField.isSecureTextEntry = true
        self.textInputNode.textField.tintColor = theme.actionSheet.controlAccentColor
        
        self.placeholderNode = ASTextNode()
        self.placeholderNode.isUserInteractionEnabled = false
        self.placeholderNode.displaysAsynchronously = false
        self.placeholderNode.attributedText = NSAttributedString(string: placeholder, font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        
        super.init()
        
        self.textInputNode.textField.delegate = self
        self.textInputNode.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textInputNode)
        self.addSubnode(self.placeholderNode)
    }
    
    func updateTheme(_ theme: PresentationTheme) {
        self.theme = theme
        
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 12.0, color: self.theme.actionSheet.inputHollowBackgroundColor, strokeColor: self.theme.actionSheet.inputBorderColor, strokeWidth: 1.0)
        self.textInputNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.placeholderNode.attributedText = NSAttributedString(string: self.placeholderNode.attributedText?.string ?? "", font: Font.regular(17.0), textColor: self.theme.actionSheet.inputPlaceholderColor)
        self.textInputNode.textField.tintColor = self.theme.actionSheet.controlAccentColor
        self.textInputNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(17.0), NSAttributedString.Key.foregroundColor: theme.actionSheet.inputTextColor]
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let textFieldHeight = self.calculateTextFieldMetrics(width: width)
        let panelHeight = textFieldHeight + backgroundInsets.top + backgroundInsets.bottom
        
        let backgroundFrame = CGRect(origin: CGPoint(x: backgroundInsets.left, y: backgroundInsets.top), size: CGSize(width: width - backgroundInsets.left - backgroundInsets.right, height: panelHeight - backgroundInsets.top - backgroundInsets.bottom))
        transition.updateFrame(node: self.backgroundNode, frame: backgroundFrame)
        
        let placeholderSize = self.placeholderNode.measure(backgroundFrame.size)
        transition.updateFrame(node: self.placeholderNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY + floor((backgroundFrame.size.height - placeholderSize.height) / 2.0)), size: placeholderSize))
        
        transition.updateFrame(node: self.textInputNode, frame: CGRect(origin: CGPoint(x: backgroundFrame.minX + inputInsets.left, y: backgroundFrame.minY), size: CGSize(width: backgroundFrame.size.width - inputInsets.left - inputInsets.right, height: backgroundFrame.size.height)))
        
        return panelHeight
    }
    
    func activateInput() {
        self.textInputNode.becomeFirstResponder()
    }
    
    func deactivateInput() {
        self.textInputNode.resignFirstResponder()
    }
    
    func shake() {
        self.layer.addShakeAnimation()
    }

    @objc func textDidChange() {
        self.updateTextNodeText(animated: true)
        self.textChanged?(self.textInputNode.textField.text ?? "")
        self.placeholderNode.isHidden = !(self.textInputNode.textField.text ?? "").isEmpty
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if text == "\n" {
            self.complete?()
            return false
        }
        return true
    }
    
    private func calculateTextFieldMetrics(width: CGFloat) -> CGFloat {
        let backgroundInsets = self.backgroundInsets
        let inputInsets = self.inputInsets
        
        let unboundTextFieldHeight = max(33.0, ceil(self.textInputNode.measure(CGSize(width: width - backgroundInsets.left - backgroundInsets.right - inputInsets.left - inputInsets.right, height: CGFloat.greatestFiniteMagnitude)).height))
        
        return min(61.0, max(33.0, unboundTextFieldHeight))
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
        self.textInputNode.textField.text = nil
        self.deactivateInput()
    }
}

private final class BotCheckoutPasswordAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private let period: Int32
    private let requiresBiometrics: Bool
    private let completion: (TemporaryTwoStepPasswordToken) -> Void
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [TextAlertContentActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let cancelActionNode: TextAlertContentActionNode
    private let doneActionNode: TextAlertContentActionNode
    
    let inputFieldNode: BotCheckoutPassworInputFieldNode
    
    private var validLayout: CGSize?
    private var isVerifying = false
    private let disposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, passwordTip: String?, cardTitle: String, period: Int32, requiresBiometrics: Bool, cancel: @escaping () -> Void, completion: @escaping (TemporaryTwoStepPasswordToken) -> Void) {
        self.context = context
        self.period = period
        self.requiresBiometrics = requiresBiometrics
        self.completion = completion
        
        let alertTheme = AlertControllerTheme(presentationTheme: theme, fontSize: .regular)
        
        let titleNode = ASTextNode()
        titleNode.attributedText = NSAttributedString(string: strings.Checkout_PasswordEntry_Title, font: Font.semibold(17.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        titleNode.displaysAsynchronously = false
        titleNode.isUserInteractionEnabled = false
        titleNode.maximumNumberOfLines = 1
        titleNode.truncationMode = .byTruncatingTail
        self.titleNode = titleNode
        
        self.textNode = ASTextNode()
        self.textNode.attributedText = NSAttributedString(string: strings.Checkout_PasswordEntry_Text(cardTitle).string, font: Font.regular(13.0), textColor: theme.actionSheet.primaryTextColor, paragraphAlignment: .center)
        self.textNode.displaysAsynchronously = false
        self.textNode.isUserInteractionEnabled = false
        
        self.inputFieldNode = BotCheckoutPassworInputFieldNode(theme: theme, placeholder: passwordTip ?? "")
                
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        
        self.cancelActionNode = TextAlertContentActionNode(theme: alertTheme, action: TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {
            cancel()
        }))
        
        var doneImpl: (() -> Void)?
        self.doneActionNode = TextAlertContentActionNode(theme: alertTheme, action: TextAlertAction(type: .defaultAction, title: strings.Checkout_PasswordEntry_Pay, action: {
            doneImpl?()
        }))
        
        self.actionNodes = [self.cancelActionNode, self.doneActionNode]
        
        var actionVerticalSeparators: [ASDisplayNode] = []
        if self.actionNodes.count > 1 {
            for _ in 0 ..< self.actionNodes.count - 1 {
                let separatorNode = ASDisplayNode()
                separatorNode.isLayerBacked = true
                separatorNode.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
                actionVerticalSeparators.append(separatorNode)
            }
        }
        self.actionVerticalSeparators = actionVerticalSeparators
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.actionNodesSeparator)
        
        for actionNode in self.actionNodes {
            self.addSubnode(actionNode)
        }
        
        for separatorNode in self.actionVerticalSeparators {
            self.addSubnode(separatorNode)
        }
        
        self.addSubnode(self.inputFieldNode)
        
        self.inputFieldNode.textChanged = { [weak self] _ in
            if let strongSelf = self {
                strongSelf.updateState()
            }
        }
                
        self.updateState()
        
        doneImpl = { [weak self] in
            self?.verify()
        }
    }
    
    override func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) -> CGSize {
        let previousLayout = self.validLayout
        self.validLayout = size
        
        let insets = UIEdgeInsets(top: 18.0, left: 18.0, bottom: 18.0, right: 18.0)
        
        let titleSize = titleNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        let textSize = self.textNode.measure(CGSize(width: size.width - insets.left - insets.right, height: CGFloat.greatestFiniteMagnitude))
        
        let actionsHeight: CGFloat = 44.0
        
        var minActionsWidth: CGFloat = 0.0
        let maxActionWidth: CGFloat = floor(size.width / CGFloat(self.actionNodes.count))
        let actionTitleInsets: CGFloat = 8.0
        for actionNode in self.actionNodes {
            let actionTitleSize = actionNode.titleNode.updateLayout(CGSize(width: maxActionWidth, height: actionsHeight))
            minActionsWidth += actionTitleSize.width + actionTitleInsets
        }
        
        let contentWidth = max(max(titleSize.width, textSize.width), minActionsWidth)
        
        let spacing: CGFloat = 6.0
        let titleFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - titleSize.width) / 2.0), y: insets.top), size: titleSize)
        transition.updateFrame(node: titleNode, frame: titleFrame)
        
        let textFrame = CGRect(origin: CGPoint(x: insets.left + floor((contentWidth - textSize.width) / 2.0), y: titleFrame.maxY + spacing), size: textSize)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        let resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom + 46.0)
        
        let inputFieldWidth = resultSize.width
        let inputFieldHeight = self.inputFieldNode.updateLayout(width: inputFieldWidth, transition: transition)
        transition.updateFrame(node: self.inputFieldNode, frame: CGRect(x: 0.0, y: resultSize.height - 36.0 - actionsHeight - insets.bottom, width: resultSize.width, height: inputFieldHeight))
        
        self.actionNodesSeparator.frame = CGRect(origin: CGPoint(x: 0.0, y: resultSize.height - actionsHeight - UIScreenPixel), size: CGSize(width: resultSize.width, height: UIScreenPixel))
        
        var actionOffset: CGFloat = 0.0
        let actionWidth: CGFloat = floor(resultSize.width / CGFloat(self.actionNodes.count))
        var separatorIndex = -1
        var nodeIndex = 0
        for actionNode in self.actionNodes {
            if separatorIndex >= 0 {
                let separatorNode = self.actionVerticalSeparators[separatorIndex]
                transition.updateFrame(node: separatorNode, frame: CGRect(origin: CGPoint(x: actionOffset - UIScreenPixel, y: resultSize.height - actionsHeight), size: CGSize(width: UIScreenPixel, height: actionsHeight - UIScreenPixel)))
            }
            separatorIndex += 1
            
            let currentActionWidth: CGFloat
            if nodeIndex == self.actionNodes.count - 1 {
                currentActionWidth = resultSize.width - actionOffset
            } else {
                currentActionWidth = actionWidth
            }
            
            let actionNodeFrame = CGRect(origin: CGPoint(x: actionOffset, y: resultSize.height - actionsHeight), size: CGSize(width: currentActionWidth, height: actionsHeight))
            
            actionOffset += currentActionWidth
            transition.updateFrame(node: actionNode, frame: actionNodeFrame)
            
            nodeIndex += 1
        }
        
        if previousLayout == nil {
            self.inputFieldNode.activateInput()
        }
        
        return resultSize
    }
    
    @objc func textFieldChanged(_ textField: UITextField) {
        self.updateState()
    }
    
    private func updateState() {
        var enabled = true
        if self.isVerifying || self.inputFieldNode.text.isEmpty {
            enabled = false
        }
        self.doneActionNode.actionEnabled = enabled
    }
    
    private func verify() {
        let text = self.inputFieldNode.text
        guard !text.isEmpty else {
            return
        }
        
        self.isVerifying = true
        self.disposable.set((self.context.engine.auth.requestTemporaryTwoStepPasswordToken(password: text, period: self.period, requiresBiometrics: self.requiresBiometrics) |> deliverOnMainQueue).start(next: { [weak self] token in
            if let strongSelf = self {
                strongSelf.completion(token)
            }
        }, error: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.inputFieldNode.shake()
                strongSelf.hapticFeedback.error()
                strongSelf.isVerifying = false
                strongSelf.updateState()
            }
        }))
        self.updateState()
    }
}

func botCheckoutPasswordEntryController(context: AccountContext, strings: PresentationStrings, passwordTip: String?, cartTitle: String, period: Int32, requiresBiometrics: Bool, completion: @escaping (TemporaryTwoStepPasswordToken) -> Void) -> AlertController {
    var dismissImpl: (() -> Void)?
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let controller = AlertController(theme: AlertControllerTheme(presentationData: presentationData), contentNode: BotCheckoutPasswordAlertContentNode(context: context, theme: presentationData.theme, strings: strings, passwordTip: passwordTip, cardTitle: cartTitle, period: period, requiresBiometrics: requiresBiometrics, cancel: {
        dismissImpl?()
    }, completion: { token in
        completion(token)
        dismissImpl?()
    }))
    dismissImpl = { [weak controller] in
        controller?.dismissAnimated()
    }
    return controller
}
