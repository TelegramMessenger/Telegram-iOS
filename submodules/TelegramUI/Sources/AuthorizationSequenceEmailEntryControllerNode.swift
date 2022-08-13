import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AuthorizationUI
import AuthenticationServices
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode

final class AuthorizationSequenceEmailEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private var signInWithAppleButton: UIControl?
    private let proceedNode: SolidRoundedButtonNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentEmail: String {
        return self.codeField.textField.text ?? ""
    }
    
    var proceedWithEmail: ((String) -> Void)?
    var signInWithApple: (() -> Void)?
    
    private var appleSignInAllowed = false
        
    var inProgress: Bool = false {
        didSet {
            self.codeField.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroMail"), width: 256, height: 256, playbackMode: .loop, mode: .direct(cachePathPrefix: nil))
        self.animationNode.visibility = true
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        self.titleNode.attributedText = NSAttributedString(string: "Add Email", font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: "Please enter your valid email address to protect your account.", font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        if #available(iOS 13.0, *) {
            self.signInWithAppleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: theme.overallDarkAppearance ? .white : .black)
            (self.signInWithAppleButton as? ASAuthorizationAppleIDButton)?.cornerRadius = 11
        }
        
        self.proceedNode = SolidRoundedButtonNode(title: "Continue", theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)

        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(20.0)
        self.codeField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.codeField.textField.textAlignment = .natural
        self.codeField.textField.keyboardType = .emailAddress
        self.codeField.textField.autocorrectionType = .no
        self.codeField.textField.autocapitalizationType = .none
        self.codeField.textField.returnKeyType = .done
        self.codeField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.codeField.textField.tintColor = self.theme.list.itemAccentColor
        self.codeField.textField.placeholder = "Enter Your Email"
                
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.codeField.textField.delegate = self
        
        self.addSubnode(self.codeSeparatorNode)
        self.addSubnode(self.codeField)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.proceedNode)
        self.addSubnode(self.noticeNode)
        self.addSubnode(self.animationNode)
        
        self.codeField.textField.addTarget(self, action: #selector(self.textDidChange), for: .editingChanged)
        self.proceedNode.pressed = { [weak self] in
            self?.proceedPressed()
        }
        self.signInWithAppleButton?.addTarget(self, action: #selector(self.signInWithApplePressed), for: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let signInWithAppleButton = self.signInWithAppleButton {
            self.view.addSubview(signInWithAppleButton)
        }
    }
    
    @objc private func textDidChange() {
        self.updateButtonsVisibility(transition: .animated(duration: 0.2, curve: .easeInOut))
    }
    
    private func updateButtonsVisibility(transition: ContainedViewLayoutTransition) {
        if self.currentEmail.isEmpty && self.appleSignInAllowed {
            transition.updateAlpha(node: self.proceedNode, alpha: 0.0)
            if let signInWithAppleButton = self.signInWithAppleButton {
                transition.updateAlpha(layer: signInWithAppleButton.layer, alpha: 1.0)
            }
        } else {
            transition.updateAlpha(node: self.proceedNode, alpha: 1.0)
            if let signInWithAppleButton = self.signInWithAppleButton {
                transition.updateAlpha(layer: signInWithAppleButton.layer, alpha: 0.0)
            }
        }
    }
    
    func updateData(appleSignInAllowed: Bool) {
        self.appleSignInAllowed = appleSignInAllowed
        if let (layout, navigationHeight) = self.layoutArguments {
            self.updateButtonsVisibility(transition: .immediate)
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
        
        self.titleNode.attributedText = NSAttributedString(string: "Add Email", font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)

        let animationSize = CGSize(width: 88.0, height: 88.0)
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 80.0, height: CGFloat.greatestFiniteMagnitude))
        let proceedHeight = self.proceedNode.updateLayout(width: layout.size.width - 48.0, transition: transition)
        let proceedSize = CGSize(width: layout.size.width - 48.0, height: proceedHeight)
        
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        self.animationNode.updateLayout(size: animationSize)
        
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 20.0, maxValue: 20.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 60.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 48.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.proceedNode, size: proceedSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
        
        if let signInWithAppleButton = self.signInWithAppleButton {
            if self.appleSignInAllowed {
                signInWithAppleButton.isHidden = false
                transition.updateFrame(view: signInWithAppleButton, frame: self.proceedNode.frame)
            } else {
                signInWithAppleButton.isHidden = true
            }
        }
    }
    
    func activateInput() {
        self.codeField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeField.layer.addShakeAnimation()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.proceedWithEmail?(self.currentEmail)
        return false
    }
    
    @objc func proceedPressed() {
        self.proceedWithEmail?(self.currentEmail)
    }
    
    @objc func signInWithApplePressed() {
        self.signInWithApple?()
    }
}
