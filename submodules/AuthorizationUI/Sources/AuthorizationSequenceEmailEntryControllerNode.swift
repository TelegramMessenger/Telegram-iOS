import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AuthorizationUtils
import AuthenticationServices
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode

final class AuthorizationDividerNode: ASDisplayNode {
    private let titleNode: ImmediateTextNode
    private let leftLineNode: ASDisplayNode
    private let rightLineNode: ASDisplayNode
    
    init(theme: PresentationTheme, strings: PresentationStrings) {
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 1
        self.titleNode.attributedText = NSAttributedString(string: strings.Login_Or, font: Font.regular(17.0), textColor: theme.list.itemSecondaryTextColor)

        self.leftLineNode = ASDisplayNode()
        self.leftLineNode.backgroundColor = theme.list.itemSecondaryTextColor
        
        self.rightLineNode = ASDisplayNode()
        self.rightLineNode.backgroundColor = theme.list.itemSecondaryTextColor
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.leftLineNode)
        self.addSubnode(self.rightLineNode)
    }
    
    func updateLayout(width: CGFloat) -> CGSize {
        let lineSize = CGSize(width: 33.0, height: UIScreenPixel)
        let spacing: CGFloat = 7.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - (lineSize.width + spacing) * 2.0, height: .greatestFiniteMagnitude))
       
        let height: CGFloat = 40.0
        let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((width - lineSize.width) / 2.0), y: floor((height - titleSize.height) / 2.0)), size: titleSize)
        self.titleNode.frame = titleFrame
        self.leftLineNode.frame = CGRect(origin: CGPoint(x: titleFrame.minX - spacing - lineSize.width, y: floorToScreenPixels(height / 2.0)), size: lineSize)
        self.rightLineNode.frame = CGRect(origin: CGPoint(x: titleFrame.maxX + spacing, y: floorToScreenPixels(height / 2.0)), size: lineSize)
        return CGSize(width: width, height: height)
    }
}

final class AuthorizationSequenceEmailEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    private let mode: AuthorizationSequenceEmailEntryController.Mode
    
    private let animationNode: AnimatedStickerNode
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    
    private let dividerNode: AuthorizationDividerNode
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
            
            if self.inProgress != oldValue {
                if self.inProgress {
                    self.proceedNode.transitionToProgress()
                } else {
                    self.proceedNode.transitionFromProgress()
                }
            }
        }
    }
    
    init(strings: PresentationStrings, theme: PresentationTheme, mode: AuthorizationSequenceEmailEntryController.Mode) {
        self.strings = strings
        self.theme = theme
        self.mode = mode
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: "IntroMail"), width: 256, height: 256, playbackMode: .once, mode: .direct(cachePathPrefix: nil))
        
        self.titleNode = ASTextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.lineSpacing = 0.1
        self.noticeNode.attributedText = NSAttributedString(string: self.strings.Login_AddEmailText, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        if #available(iOS 13.0, *) {
            self.signInWithAppleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: theme.overallDarkAppearance ? .white : .black)
            (self.signInWithAppleButton as? ASAuthorizationAppleIDButton)?.cornerRadius = 11
        }
        
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_Continue, theme: SolidRoundedButtonTheme(theme: self.theme), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(20.0)
        self.codeField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.codeField.textField.textAlignment = .natural
        self.codeField.textField.autocorrectionType = .no
        self.codeField.textField.autocapitalizationType = .none
        self.codeField.textField.keyboardType = .emailAddress
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.codeField.textField.textContentType = UITextContentType(rawValue: "")
        }
        self.codeField.textField.returnKeyType = .done
        self.codeField.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeField.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        self.codeField.textField.tintColor = self.theme.list.itemAccentColor
        self.codeField.textField.placeholder = self.strings.Login_AddEmailPlaceholder
                
        self.dividerNode = AuthorizationDividerNode(theme: self.theme, strings: self.strings)
        
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
        self.addSubnode(self.dividerNode)
        
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
//            if self.proceedNode.isHidden {
                transition.updateAlpha(node: self.dividerNode, alpha: 1.0)
//            }
            if let signInWithAppleButton = self.signInWithAppleButton {
                transition.updateAlpha(layer: signInWithAppleButton.layer, alpha: 1.0)
            }
        } else {
            transition.updateAlpha(node: self.proceedNode, alpha: 1.0)
//            if self.proceedNode.isHidden {
                transition.updateAlpha(node: self.dividerNode, alpha: 0.0)
//            }
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
        insets.top = layout.statusBarHeight ?? 20.0
        if let inputHeight = layout.inputHeight {
            insets.bottom = max(inputHeight, insets.bottom)
        }
        
        let titleInset: CGFloat = layout.size.width > 320.0 ? 18.0 : 0.0
        
        self.titleNode.attributedText = NSAttributedString(string: self.mode == .setup ? self.strings.Login_AddEmailTitle : self.strings.Login_EnterNewEmailTitle, font: Font.bold(28.0), textColor: self.theme.list.itemPrimaryTextColor)

        let animationSize = CGSize(width: 100.0, height: 100.0)
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 80.0, height: CGFloat.greatestFiniteMagnitude))
        let proceedHeight = self.proceedNode.updateLayout(width: layout.size.width - 48.0, transition: transition)
        let proceedSize = CGSize(width: layout.size.width - 48.0, height: proceedHeight)
        
        var items: [AuthorizationLayoutItem] = []
        
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: titleInset, maxValue: titleInset), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 48.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        if layout.size.width > 320.0 {
            items.insert(AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)), at: 0)
            self.animationNode.updateLayout(size: animationSize)
            self.proceedNode.isHidden = false
            self.animationNode.isHidden = false
            self.animationNode.visibility = true
        } else {
            insets.top = navigationBarHeight
            self.proceedNode.isHidden = true
            self.animationNode.isHidden = true
        }
        
        let inset: CGFloat = 24.0
        let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize)
        transition.updateFrame(node: self.proceedNode, frame: buttonFrame)
        
        let dividerSize = self.dividerNode.updateLayout(width: layout.size.width)
        transition.updateFrame(node: self.dividerNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - dividerSize.width) / 2.0), y: buttonFrame.minY - dividerSize.height), size: dividerSize))
        
        if let _ = self.signInWithAppleButton, self.appleSignInAllowed {
            self.dividerNode.isHidden = false
        } else {
            self.dividerNode.isHidden = true
        }
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 120.0)), items: items, transition: transition, failIfDoesNotFit: false)
        
        if let signInWithAppleButton = self.signInWithAppleButton, self.appleSignInAllowed {
            signInWithAppleButton.isHidden = false
            transition.updateFrame(view: signInWithAppleButton, frame: self.proceedNode.frame)
        } else {
            self.signInWithAppleButton?.isHidden = true
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
