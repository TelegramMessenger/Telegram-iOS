import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import AuthorizationUtils
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode

final class AuthorizationSequencePasswordEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let forgotNode: HighlightableButtonNode
    private let resetNode: HighlightableButtonNode
    private let proceedNode: SolidRoundedButtonNode
    
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
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    private var timer: SwiftSignalKit.Timer?
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroPassword"), width: 256, height: 256, playbackMode: .still(.start), mode: .direct(cachePathPrefix: nil))
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: strings.LoginPassword_Title, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.lineSpacing = 0.1
        self.noticeNode.attributedText = NSAttributedString(string: strings.TwoStepAuth_EnterPasswordHelp, font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
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
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        self.proceedNode.isEnabled = false
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.codeField.textField.delegate = self
        self.codeField.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
        
        self.addSubnode(self.codeSeparatorNode)
        self.addSubnode(self.codeField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.forgotNode)
        self.addSubnode(self.resetNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.proceedNode)
        
        self.forgotNode.addTarget(self, action: #selector(self.forgotPressed), forControlEvents: .touchUpInside)
        self.resetNode.addTarget(self, action: #selector(self.resetPressed), forControlEvents: .touchUpInside)
        
        self.proceedNode.pressed = { [weak self] in
            if let strongSelf = self {
                strongSelf.loginWithCode?(strongSelf.currentPassword)
            }
        }
        
        self.timer = SwiftSignalKit.Timer(timeout: 7.5, repeat: true, completion: { [weak self] in
            self?.animationNode.playOnce()
        }, queue: Queue.mainQueue())
        self.timer?.start()
    }
    
    deinit {
        self.timer?.invalidate()
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
        insets.top = layout.statusBarHeight ?? 20.0
        if let inputHeight = layout.inputHeight, !inputHeight.isZero {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        
        let titleInset: CGFloat = layout.size.width > 320.0 ? 18.0 : 0.0
        let additionalBottomInset: CGFloat = layout.size.width > 320.0 ? 110.0 : 20.0
        
        self.titleNode.attributedText = NSAttributedString(string: self.strings.LoginPassword_Title, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        let inset: CGFloat = 24.0
        
        let animationSize = CGSize(width: 100.0, height: 100.0)
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let forgotSize = self.forgotNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let resetSize = self.resetNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        let proceedHeight = self.proceedNode.updateLayout(width: layout.size.width - inset * 2.0, transition: transition)
        let proceedSize = CGSize(width: layout.size.width - inset * 2.0, height: proceedHeight)
        
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: titleInset, maxValue: titleInset), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 80.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 60.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 48.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.forgotNode, size: forgotSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if self.didForgotWithNoRecovery || self.suggestReset {
            self.resetNode.isHidden = false
            items.append(AuthorizationLayoutItem(node: self.resetNode, size: resetSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        } else {
            self.resetNode.isHidden = true
        }
        
        if layout.size.width > 320.0 {
            items.insert(AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)), at: 0)
            self.proceedNode.isHidden = false
            self.animationNode.isHidden = false
            self.animationNode.visibility = true
        } else {
            insets.top = navigationBarHeight
            self.proceedNode.isHidden = true
            self.animationNode.isHidden = true
        }
        
        transition.updateFrame(node: self.proceedNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize))
        
        self.animationNode.updateLayout(size: animationSize)
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - additionalBottomInset)), items: items, transition: transition, failIfDoesNotFit: false)
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
    
    @objc func textDidChange() {
        self.proceedNode.isEnabled = !(self.codeField.textField.text ?? "").isEmpty
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
