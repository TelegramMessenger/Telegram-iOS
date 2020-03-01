import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AuthorizationUI

final class AuthorizationSequencePasswordEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let forgotNode: HighlightableButtonNode
    private let resetNode: HighlightableButtonNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentPassword: String {
        return self.codeField.textField.text ?? ""
    }
    
    var loginWithCode: ((String) -> Void)?
    var forgot: (() -> Void)?
    var reset: (() -> Void)?
    
    var didForgotWithNoRecovery = false
    var suggestReset = false
    
    private var clearOnce: Bool = false
    
    var inProgress: Bool = false {
        didSet {
            self.codeField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.LoginPassword_Title, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: strings.TwoStepAuth_EnterPasswordHelp, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.forgotNode = HighlightableButtonNode()
        self.forgotNode.displaysAsynchronously = false
        self.forgotNode.setAttributedTitle(NSAttributedString(string: self.strings.TwoStepAuth_EnterPasswordForgot, font: Font.regular(16.0), textColor: self.theme.list.itemAccentColor, paragraphAlignment: .center), for: [])
        
        self.resetNode = HighlightableButtonNode()
        self.resetNode.displaysAsynchronously = false
        self.resetNode.setAttributedTitle(NSAttributedString(string: self.strings.LoginPassword_ResetAccount, font: Font.regular(16.0), textColor: self.theme.list.itemDestructiveColor, paragraphAlignment: .center), for: [])
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(20.0)
        self.codeField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.codeField.textField.textAlignment = .natural
        self.codeField.textField.isSecureTextEntry = true
        self.codeField.textField.returnKeyType = .done
        self.codeField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.codeField.textField.tintColor = self.theme.list.itemAccentColor
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.codeField.textField.delegate = self
        
        self.addSubnode(self.codeSeparatorNode)
        self.addSubnode(self.codeField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.forgotNode)
        self.addSubnode(self.resetNode)
        self.addSubnode(self.noticeNode)
        
        self.forgotNode.addTarget(self, action: #selector(self.forgotPressed), forControlEvents: .touchUpInside)
        self.resetNode.addTarget(self, action: #selector(self.resetPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(hint: String, didForgotWithNoRecovery: Bool, suggestReset: Bool) {
        self.didForgotWithNoRecovery = didForgotWithNoRecovery
        self.suggestReset = suggestReset
        self.codeField.textField.attributedPlaceholder = NSAttributedString(string: hint, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
        if let (layout, navigationHeight) = self.layoutArguments {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [])
        insets.top = navigationBarHeight
        
        if let inputHeight = layout.inputHeight {
            insets.bottom += max(inputHeight, layout.standardInputHeight)
        }
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.LoginPassword_Title, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.LoginPassword_Title, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let forgotSize = self.forgotNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let resetSize = self.resetNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 88.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.forgotNode, size: forgotSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if self.didForgotWithNoRecovery || self.suggestReset {
            self.resetNode.isHidden = false
            items.append(AuthorizationLayoutItem(node: self.resetNode, size: resetSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        } else {
            self.resetNode.isHidden = true
        }
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    func activateInput() {
        self.codeField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeField.layer.addShakeAnimation()
    }
    
    func passwordIsInvalid() {
        self.clearOnce = true
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.clearOnce {
            self.clearOnce = false
            if range.length > string.count {
                textField.text = ""
                return false
            }
        }
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.loginWithCode?(self.currentPassword)
        return false
    }
    
    @objc func forgotPressed() {
        self.forgot?()
    }
    
    @objc func resetPressed() {
        self.reset?()
    }
}
