import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

private struct BotCheckoutPasswordAlertAction {
    public let title: String
    public let action: () -> Void
    
    public init(title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }
}

private final class BotCheckoutPasswordAlertActionNode: HighlightableButtonNode {
    private let backgroundNode: ASDisplayNode
    
    let action: BotCheckoutPasswordAlertAction
    
    init(theme: PresentationTheme, action: BotCheckoutPasswordAlertAction) {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.backgroundColor = theme.actionSheet.opaqueItemHighlightedBackgroundColor
        self.backgroundNode.alpha = 0.0
        
        self.action = action
        
        super.init()
        
        self.setTitle(action.title, with: Font.regular(17.0), with: theme.actionSheet.controlAccentColor, for: [])
        self.setTitle(action.title, with: Font.regular(17.0), with: theme.actionSheet.disabledActionTextColor, for: [.disabled])
        
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

private final class BotCheckoutPasswordAlertContentNode: AlertContentNode {
    private let context: AccountContext
    private let period: Int32
    private let requiresBiometrics: Bool
    private let completion: (TemporaryTwoStepPasswordToken) -> Void
    
    private let titleNode: ASTextNode
    private let textNode: ASTextNode
    
    private let actionNodesSeparator: ASDisplayNode
    private let actionNodes: [BotCheckoutPasswordAlertActionNode]
    private let actionVerticalSeparators: [ASDisplayNode]
    
    private let cancelActionNode: BotCheckoutPasswordAlertActionNode
    private let doneActionNode: BotCheckoutPasswordAlertActionNode
    
    private let textFieldNodeBackground: ASImageNode
    private let textFieldNode: TextFieldNode
    
    private var validLayout: CGSize?
    private var isVerifying = false
    private let disposable = MetaDisposable()
    
    private let hapticFeedback = HapticFeedback()
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, passwordTip: String?, cardTitle: String, period: Int32, requiresBiometrics: Bool, cancel: @escaping () -> Void, completion: @escaping (TemporaryTwoStepPasswordToken) -> Void) {
        self.context = context
        self.period = period
        self.requiresBiometrics = requiresBiometrics
        self.completion = completion
        
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
        
        self.actionNodesSeparator = ASDisplayNode()
        self.actionNodesSeparator.isLayerBacked = true
        self.actionNodesSeparator.backgroundColor = theme.actionSheet.opaqueItemSeparatorColor
        
        self.cancelActionNode = BotCheckoutPasswordAlertActionNode(theme: theme, action: BotCheckoutPasswordAlertAction(title: strings.Common_Cancel, action: {
            cancel()
        }))
        
        var doneImpl: (() -> Void)?
        self.doneActionNode = BotCheckoutPasswordAlertActionNode(theme: theme, action: BotCheckoutPasswordAlertAction(title: strings.Checkout_PasswordEntry_Pay, action: {
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
        
        self.textFieldNodeBackground = ASImageNode()
        self.textFieldNodeBackground.displaysAsynchronously = false
        self.textFieldNodeBackground.displayWithoutProcessing = true
        self.textFieldNodeBackground.image = generateImage(CGSize(width: 4.0, height: 4.0), rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            context.setStrokeColor(theme.actionSheet.primaryTextColor.cgColor)
            context.setLineWidth(UIScreenPixel)
            context.stroke(CGRect(origin: CGPoint(), size: size))
        })?.stretchableImage(withLeftCapWidth: 2, topCapHeight: 2)
        
        self.textFieldNode = TextFieldNode()
        self.textFieldNode.textField.textColor = theme.actionSheet.primaryTextColor
        self.textFieldNode.textField.font = Font.regular(12.0)
        self.textFieldNode.textField.typingAttributes = [NSAttributedString.Key.font: Font.regular(12.0)]
        self.textFieldNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.textFieldNode.textField.isSecureTextEntry = true
        self.textFieldNode.textField.tintColor = theme.list.itemAccentColor
        self.textFieldNode.textField.placeholder = passwordTip

        
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
        
        self.addSubnode(self.textFieldNodeBackground)
        self.addSubnode(self.textFieldNode)
        
        self.textFieldNode.textField.addTarget(self, action: #selector(self.textFieldChanged(_:)), for: .editingChanged)
        
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
        
        let inputHeight: CGFloat = 38.0
        
        let resultSize = CGSize(width: contentWidth + insets.left + insets.right, height: titleSize.height + spacing + textSize.height + actionsHeight + insets.top + insets.bottom + inputHeight)
        
        let textFieldBackgroundFrame = CGRect(origin: CGPoint(x: insets.left, y: resultSize.height - inputHeight + 12.0 - actionsHeight - insets.bottom), size: CGSize(width: resultSize.width - insets.left - insets.right, height: 25.0))
        self.textFieldNodeBackground.frame = textFieldBackgroundFrame
        self.textFieldNode.frame = textFieldBackgroundFrame.offsetBy(dx: 0.0, dy: 0.0).insetBy(dx: 4.0, dy: 0.0)
        
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
            self.textFieldNode.textField.becomeFirstResponder()
        }
        
        return resultSize
    }
    
    @objc func textFieldChanged(_ textField: UITextField) {
        self.updateState()
    }
    
    private func updateState() {
        var enabled = true
        
        if self.isVerifying {
            enabled = false
        }
        
        if let text = self.textFieldNode.textField.text {
            if text.isEmpty {
                enabled = false
            }
        } else {
            enabled = false
        }
        
        self.doneActionNode.isEnabled = enabled
    }
    
    private func verify() {
        guard let text = self.textFieldNode.textField.text, !text.isEmpty else {
            return
        }
        
        self.isVerifying = true
        self.disposable.set((self.context.engine.auth.requestTemporaryTwoStepPasswordToken(password: text, period: self.period, requiresBiometrics: self.requiresBiometrics) |> deliverOnMainQueue).start(next: { [weak self] token in
            if let strongSelf = self {
                strongSelf.completion(token)
            }
        }, error: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.textFieldNodeBackground.layer.addShakeAnimation()
                strongSelf.textFieldNode.layer.addShakeAnimation()
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
