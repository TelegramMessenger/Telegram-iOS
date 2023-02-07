import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TextFormat
import AuthenticationServices
import CodeInputView
import PhoneNumberFormat
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SolidRoundedButtonNode
import InvisibleInkDustNode
import AuthorizationUtils
import TelegramStringFormatting

final class AuthorizationSequenceCodeEntryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let animationNode: AnimatedStickerNode
    private let titleNode: ImmediateTextNode
    private let titleActivateAreaNode: AccessibilityAreaNode
    private let titleIconNode: ASImageNode
    private let currentOptionNode: ImmediateTextNode
    private let currentOptionActivateAreaNode: AccessibilityAreaNode
    private var dustNode: InvisibleInkDustNode?
    
    private let currentOptionInfoNode: ASTextNode
    private let currentOptionInfoActivateAreaNode: AccessibilityAreaNode
    private let nextOptionTitleNode: ImmediateTextNode
    private let nextOptionButtonNode: HighlightableButtonNode
    
    private let dividerNode: AuthorizationDividerNode
    private var signInWithAppleButton: UIControl?
    private let proceedNode: SolidRoundedButtonNode
    
    private let codeInputView: CodeInputView
    private let errorTextNode: ImmediateTextNode
    
    private var codeType: SentAuthorizationCodeType?
    
    private let countdownDisposable = MetaDisposable()
    private var currentTimeoutTime: Int32?
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    private var appleSignInAllowed = false
    
    var phoneNumber: String = "" {
        didSet {
            if self.phoneNumber != oldValue {
                if let (layout, navigationHeight) = self.layoutArguments {
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                }
            }
        }
    }
    
    var email: String?
    
    var currentCode: String {
        return self.codeInputView.text
    }
    
    var loginWithCode: ((String) -> Void)?
    var signInWithApple: (() -> Void)?
    var openFragment: ((String) -> Void)?
    var present: (ViewController, Any?) -> Void = { _, _ in }
    
    var requestNextOption: (() -> Void)?
    var requestAnotherOption: (() -> Void)?
    var updateNextEnabled: ((Bool) -> Void)?
    
    var inProgress: Bool = false {
        didSet {
            self.codeInputView.alpha = self.inProgress ? 0.6 : 1.0
        }
    }
    
    private let appearanceTimestamp = CACurrentMediaTime()
        
    init(strings: PresentationStrings, theme: PresentationTheme) {
        self.strings = strings
        self.theme = theme
        
        self.animationNode = DefaultAnimatedStickerNodeImpl()
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.titleActivateAreaNode = AccessibilityAreaNode()
        self.titleActivateAreaNode.accessibilityTraits = .staticText
        
        self.titleIconNode = ASImageNode()
        self.titleIconNode.isLayerBacked = true
        self.titleIconNode.displayWithoutProcessing = true
        self.titleIconNode.displaysAsynchronously = false
        
        self.currentOptionNode = ImmediateTextNode()
        self.currentOptionNode.isUserInteractionEnabled = false
        self.currentOptionNode.displaysAsynchronously = false
        self.currentOptionNode.lineSpacing = 0.1
        self.currentOptionNode.maximumNumberOfLines = 0
        
        self.currentOptionActivateAreaNode = AccessibilityAreaNode()
        self.currentOptionActivateAreaNode.accessibilityTraits = .staticText
        
        self.currentOptionInfoNode = ASTextNode()
        self.currentOptionInfoNode.isUserInteractionEnabled = false
        self.currentOptionInfoNode.displaysAsynchronously = false
        
        self.currentOptionInfoActivateAreaNode = AccessibilityAreaNode()
        self.currentOptionInfoActivateAreaNode.accessibilityTraits = .staticText
        
        self.nextOptionTitleNode = ImmediateTextNode()
        
        self.nextOptionButtonNode = HighlightableButtonNode()
        self.nextOptionButtonNode.displaysAsynchronously = false
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: .sms(length: 5), nextType: .call, timeout: 60, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        self.nextOptionTitleNode.attributedText = nextOptionText
        self.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
        self.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
        if nextOptionActive {
            self.nextOptionButtonNode.accessibilityTraits = [.button]
        } else {
            self.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
        }
        self.nextOptionButtonNode.addSubnode(self.nextOptionTitleNode)
        
        self.codeInputView = CodeInputView()
        self.codeInputView.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.codeInputView.textField.returnKeyType = .done
        self.codeInputView.textField.disableAutomaticKeyboardHandling = [.forward, .backward]
        if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
            self.codeInputView.textField.textContentType = .oneTimeCode
        }
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.codeInputView.textField.keyboardType = .asciiCapableNumberPad
        } else {
            self.codeInputView.textField.keyboardType = .numberPad
        }
        
        self.errorTextNode = ImmediateTextNode()
        self.errorTextNode.alpha = 0.0
        self.errorTextNode.displaysAsynchronously = false
        self.errorTextNode.textAlignment = .center
        
        self.dividerNode = AuthorizationDividerNode(theme: self.theme, strings: self.strings)
        
        if #available(iOS 13.0, *) {
            self.signInWithAppleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .signIn, authorizationButtonStyle: theme.overallDarkAppearance ? .white : .black)
            self.signInWithAppleButton?.isHidden = true
            (self.signInWithAppleButton as? ASAuthorizationAppleIDButton)?.cornerRadius = 11
        }
        self.proceedNode = SolidRoundedButtonNode(title: self.strings.Login_OpenFragment, theme: SolidRoundedButtonTheme(backgroundColor: UIColor(rgb: 0x37475a), foregroundColor: .white), height: 50.0, cornerRadius: 11.0, gloss: false)
        self.proceedNode.progressType = .embedded
        self.proceedNode.isHidden = true
        self.proceedNode.iconSpacing = 4.0
        self.proceedNode.animationSize = CGSize(width: 36.0, height: 36.0)
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.backgroundColor = self.theme.list.plainBackgroundColor
        
        self.addSubnode(self.codeInputView)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.titleActivateAreaNode)
        self.addSubnode(self.titleIconNode)
        self.addSubnode(self.currentOptionNode)
        self.addSubnode(self.currentOptionActivateAreaNode)
        self.addSubnode(self.currentOptionInfoNode)
        self.addSubnode(self.nextOptionButtonNode)
        self.addSubnode(self.animationNode)
        self.addSubnode(self.dividerNode)
        self.addSubnode(self.errorTextNode)
        self.addSubnode(self.proceedNode)
        
        self.codeInputView.updated = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.textChanged(text: strongSelf.codeInputView.text)
        }
        
        self.codeInputView.longPressed = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            if let code = UIPasteboard.general.string, let codeLength = strongSelf.requiredCodeLength, code.count == Int(codeLength) {
                let code = normalizeArabicNumeralString(code, type: .western)
                guard code.rangeOfCharacter(from: CharacterSet(charactersIn: "0123456789").inverted) == nil else {
                    return
                }
                
                let controller = ContextMenuController(actions: [ContextMenuAction(content: .text(title: strongSelf.strings.Common_Paste, accessibilityLabel: strongSelf.strings.Common_Paste), action: { [weak self] in
                    self?.updateCode(code)
                })])
                
                strongSelf.present(
                    controller,
                    ContextMenuControllerPresentationArguments(sourceNodeAndRect: { [weak self] in
                        if let strongSelf = self {
                            return (strongSelf, strongSelf.codeInputView.frame.offsetBy(dx: 0.0, dy: -8.0), strongSelf, strongSelf.bounds)
                        } else {
                            return nil
                        }
                    })
                )
            }
        }
        
        self.nextOptionButtonNode.addTarget(self, action: #selector(self.nextOptionNodePressed), forControlEvents: .touchUpInside)
        self.proceedNode.pressed = { [weak self] in
            self?.proceedPressed()
        }
        self.signInWithAppleButton?.addTarget(self, action: #selector(self.signInWithApplePressed), for: .touchUpInside)
    }
    
    deinit {
        self.countdownDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        if let signInWithAppleButton = self.signInWithAppleButton {
            self.view.addSubview(signInWithAppleButton)
        }
    }
        
    func updateCode(_ code: String) {
        self.codeInputView.text = code
        self.textChanged(text: code)

        if let codeLength = self.requiredCodeLength, code.count == Int(codeLength) {
            self.loginWithCode?(code)
        }
    }
    
    var requiredCodeLength: Int32? {
        if let codeType = self.codeType {
            switch codeType {
            case let .call(length):
                return length
            case let .otherSession(length):
                return length
            case let .missedCall(_, length):
                return length
            case let .sms(length):
                return length
            case let .fragment(_, length):
                return length
            default:
                return nil
            }
        } else {
            return nil
        }
    }
    
    func resetCode() {
        self.codeInputView.text = ""
    }
    
    func updateData(number: String, email: String?, codeType: SentAuthorizationCodeType, nextType: AuthorizationCodeNextType?, timeout: Int32?, appleSignInAllowed: Bool) {
        self.codeType = codeType
        self.phoneNumber = number
        self.email = email
        
        var appleSignInAllowed = appleSignInAllowed
        if #available(iOS 13.0, *) {
        } else {
            appleSignInAllowed = false
        }
        self.appleSignInAllowed = appleSignInAllowed
        
        self.currentOptionNode.attributedText = authorizationCurrentOptionText(codeType, phoneNumber: self.phoneNumber, email: self.email, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        self.currentOptionActivateAreaNode.accessibilityLabel = self.currentOptionNode.attributedText?.string ?? ""
        if case .missedCall = codeType {
            self.currentOptionInfoNode.attributedText = NSAttributedString(string: self.strings.Login_CodePhonePatternInfoText, font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
            self.currentOptionInfoActivateAreaNode.accessibilityLabel = self.currentOptionInfoNode.attributedText?.string ?? ""
            if self.currentOptionInfoActivateAreaNode.supernode == nil {
                self.addSubnode(self.currentOptionInfoActivateAreaNode)
            }
        } else {
            self.currentOptionInfoNode.attributedText = NSAttributedString(string: "", font: Font.regular(17.0), textColor: self.theme.list.itemPrimaryTextColor)
            if self.currentOptionInfoActivateAreaNode.supernode != nil {
                self.currentOptionInfoActivateAreaNode.removeFromSupernode()
            }
        }
        if let timeout = timeout {
            #if DEBUG
            let timeout = min(timeout, 5)
            #endif
            self.currentTimeoutTime = timeout
            let disposable = ((Signal<Int, NoError>.single(1) |> delay(1.0, queue: Queue.mainQueue())) |> restart).start(next: { [weak self] _ in
                if let strongSelf = self {
                    if let currentTimeoutTime = strongSelf.currentTimeoutTime, currentTimeoutTime > 0 {
                        strongSelf.currentTimeoutTime = currentTimeoutTime - 1
                        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, timeout: strongSelf.currentTimeoutTime, strings: strongSelf.strings, primaryColor: strongSelf.theme.list.itemPrimaryTextColor, accentColor: strongSelf.theme.list.itemAccentColor)
                        strongSelf.nextOptionTitleNode.attributedText = nextOptionText
                        strongSelf.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
                        strongSelf.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
                        if nextOptionActive {
                            strongSelf.nextOptionButtonNode.accessibilityTraits = [.button]
                        } else {
                            strongSelf.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
                        }
                        if let layoutArguments = strongSelf.layoutArguments {
                            strongSelf.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
                        }
                        /*if currentTimeoutTime == 1 {
                            strongSelf.requestNextOption?()
                        }*/
                    }
                }
            })
            self.countdownDisposable.set(disposable)
        } else {
            self.currentTimeoutTime = nil
            self.countdownDisposable.set(nil)
        }
        let (nextOptionText, nextOptionActive) = authorizationNextOptionText(currentType: codeType, nextType: nextType, timeout: self.currentTimeoutTime, strings: self.strings, primaryColor: self.theme.list.itemPrimaryTextColor, accentColor: self.theme.list.itemAccentColor)
        self.nextOptionTitleNode.attributedText = nextOptionText
        self.nextOptionButtonNode.isUserInteractionEnabled = nextOptionActive
        self.nextOptionButtonNode.accessibilityLabel = nextOptionText.string
        if nextOptionActive {
            self.nextOptionButtonNode.accessibilityTraits = [.button]
        } else {
            self.nextOptionButtonNode.accessibilityTraits = [.button, .notEnabled]
        }
        if let layoutArguments = self.layoutArguments {
            self.containerLayoutUpdated(layoutArguments.0, navigationBarHeight: layoutArguments.1, transition: .immediate)
        }
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        let previousInputHeight = self.layoutArguments?.0.inputHeight ?? 0.0
        let newInputHeight = layout.inputHeight ?? 0.0
        
        self.layoutArguments = (layout, navigationBarHeight)
        
        var layout = layout
        if CACurrentMediaTime() - self.appearanceTimestamp < 2.0, newInputHeight < previousInputHeight {
            layout = layout.withUpdatedInputHeight(previousInputHeight)
        }
        
        let maximumWidth: CGFloat = min(430.0, layout.size.width)
        let inset: CGFloat = 24.0
        
        var insets = layout.insets(options: [])
        insets.top = layout.statusBarHeight ?? 20.0
                
        var animationName = "IntroMessage"
        var animationPlaybackMode: AnimatedStickerPlaybackMode = .once
        if let codeType = self.codeType {
            switch codeType {
            case .missedCall:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterMissingDigits, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
            case .email:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeEmailTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
                animationName = "IntroLetter"
            case .sms:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeSMSTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
            case .fragment:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeFragmentTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
                animationName = "IntroFragment"
                animationPlaybackMode = .count(3)
                self.proceedNode.animation = "anim_fragment"
            default:
                self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeTelegramTitle, font: Font.semibold(28.0), textColor: self.theme.list.itemPrimaryTextColor)
            }
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.Login_EnterCodeTelegramTitle, font: Font.semibold(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        self.titleActivateAreaNode.accessibilityLabel = self.titleNode.attributedText?.string ?? ""
        
        if let inputHeight = layout.inputHeight {
            if let codeType = self.codeType, case .email = codeType {
                insets.bottom = max(inputHeight, insets.bottom)
            } else if let codeType = self.codeType, case .fragment = codeType {
                insets.bottom = max(inputHeight, insets.bottom)
            } else {
                insets.bottom = max(inputHeight, layout.standardInputHeight)
            }
        }
        
        if !self.animationNode.visibility {
            self.animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 256, height: 256, playbackMode: animationPlaybackMode, mode: .direct(cachePathPrefix: nil))
            self.animationNode.visibility = true
        }
        
        let animationSize = CGSize(width: 100.0, height: 100.0)
        let titleSize = self.titleNode.updateLayout(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let currentOptionSize = self.currentOptionNode.updateLayout(CGSize(width: maximumWidth - 48.0, height: CGFloat.greatestFiniteMagnitude))
        let currentOptionInfoSize = self.currentOptionInfoNode.measure(CGSize(width: maximumWidth - 48.0, height: CGFloat.greatestFiniteMagnitude))
        let nextOptionSize = self.nextOptionTitleNode.updateLayout(CGSize(width: maximumWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let proceedHeight = self.proceedNode.updateLayout(width: maximumWidth - inset * 2.0, transition: transition)
        let proceedSize = CGSize(width: maximumWidth - inset * 2.0, height: proceedHeight)
        
        let codeLength: Int
        var codePrefix: String = ""
        switch self.codeType {
        case .flashCall:
            codeLength = 6
        case let .call(length):
            codeLength = Int(length)
        case let .otherSession(length):
            codeLength = Int(length)
        case let .missedCall(prefix, length):
            if prefix.hasPrefix("+") {
                codePrefix = prefix
            } else {
                codePrefix = InteractivePhoneFormatter().updateText("+" + prefix).1
            }
            codeLength = Int(length)
        case let .sms(length):
            codeLength = Int(length)
        case let .email(_, length, _, _, _):
            codeLength = Int(length)
        case let .fragment(_, length):
            codeLength = Int(length)
        case let .firebase(_, length):
            codeLength = Int(length)
        case .emailSetupRequired:
            codeLength = 6
        case .none:
            codeLength = 6
        }
        
        let codeFieldSize = self.codeInputView.update(
            theme: CodeInputView.Theme(
                inactiveBorder: self.theme.list.itemPlainSeparatorColor.argb,
                activeBorder: self.theme.list.itemAccentColor.argb,
                succeedBorder: self.theme.list.itemDisclosureActions.constructive.fillColor.argb,
                failedBorder: self.theme.list.itemDestructiveColor.argb,
                foreground: self.theme.list.itemPrimaryTextColor.argb,
                isDark: self.theme.overallDarkAppearance
            ),
            prefix: codePrefix,
            count: codeLength,
            width: maximumWidth - 28.0,
            compact: layout.size.width <= 320.0 || (layout.size.width <= 375.0 && codeLength > 5)
        )
        
        var items: [AuthorizationLayoutItem] = []
        if layout.size.width > 320.0 {
            items.append(AuthorizationLayoutItem(node: self.animationNode, size: animationSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            self.animationNode.updateLayout(size: animationSize)
        } else {
            insets.top = navigationBarHeight
        }
        
        var additionalBottomInset: CGFloat = 20.0
        if let codeType = self.codeType {
            switch codeType {
            case .otherSession:
                items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 30.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.nextOptionButtonNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            case .missedCall:
                self.titleIconNode.isHidden = false
                
                if self.titleIconNode.image == nil {
                    self.titleIconNode.image = generateImage(CGSize(width: 72.0, height: 72.0), rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        
                        context.setFillColor(theme.list.itemAccentColor.cgColor)
                        let _ = try? drawSvgPath(context, path: "M42,10.5 C41.1716,10.5 40.5,11.1716 40.5,12 C40.5,12.8284 41.1716,13.5 42,13.5 L51.3787,13.5 L36,28.8787 L19.0607,11.9393 C18.4749,11.3536 17.5251,11.3536 16.9393,11.9393 C16.3536,12.5251 16.3536,13.4749 16.9393,14.0607 L34.9393,32.0607 C35.5251,32.6464 36.4749,32.6464 37.0607,32.0607 L53.5,15.6213 L53.5,25 C53.5,25.8284 54.1716,26.5 55,26.5 C55.8284,26.5 56.5,25.8284 56.5,25 L56.5,12 C56.5,11.1716 55.8284,10.5 55,10.5 L42,10.5 Z ")
                        
                        context.setFillColor(theme.list.itemPrimaryTextColor.cgColor)
                        
                        let _ = try? drawSvgPath(context, path: "M35.9832,37.4038 C46.3353,37.4066 56.7252,39.7842 62.0325,45.0915 C64.3893,47.4483 65.7444,50.3613 65.6897,53.8677 C65.6717,56.0012 64.9858,57.8376 63.8173,59.0061 C62.8158,60.0076 61.4987,60.5082 59.9403,60.248 L51.6994,58.3061 C49.2077,57.719 47.3333,55.6605 46.9816,53.1249 L46.264,47.9528 C46.2639,47.5446 46.1154,47.2478 45.8742,47.0065 C45.6515,46.7838 45.3175,46.6353 45.0206,46.5239 C43.3508,45.9298 39.7701,45.5763 35.9855,45.5753 C32.2194,45.5557 28.6389,45.9815 26.9694,46.5005 C26.6726,46.6117 26.3387,46.76 26.079,47.0197 C25.8194,47.2793 25.6525,47.5947 25.6526,48.0028 L24.9872,53.09 C24.6524,55.6494 22.7664,57.7335 20.253,58.3214 L11.8346,60.2905 C10.2949,60.5684 9.1074,60.0486 8.2166,59.1579 C6.9733,57.9145 6.3791,55.9107 6.3229,53.9628 C6.1921,50.4193 7.4343,47.5069 9.8639,45.0773 C15.1684,39.7728 25.6683,37.401 35.9832,37.4038 Z ")
                    })
                }
                
                items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 40.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.currentOptionInfoNode, size: currentOptionInfoSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 60.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.nextOptionButtonNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            default:
                items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 18.0, maxValue: 18.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                
                items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 30.0, maxValue: 30.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 104.0, maxValue: 104.0)))

                let inset: CGFloat = 24.0
                if case .fragment = codeType {
                    self.proceedNode.isHidden = false
                    let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - proceedSize.width) / 2.0), y: layout.size.height - insets.bottom - proceedSize.height - inset), size: proceedSize)
                    transition.updateFrame(node: self.proceedNode, frame: buttonFrame)
                } else if self.appleSignInAllowed, let signInWithAppleButton = self.signInWithAppleButton {
                    additionalBottomInset = 80.0
                    
                    self.nextOptionButtonNode.isHidden = true
                    signInWithAppleButton.isHidden = false
                    self.proceedNode.isHidden = true

                    let buttonSize = CGSize(width: layout.size.width - inset * 2.0, height: 50.0)
                    transition.updateFrame(view: signInWithAppleButton, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - buttonSize.width) / 2.0), y: layout.size.height - insets.bottom - buttonSize.height - inset), size: buttonSize))
                    
                    let dividerSize = self.dividerNode.updateLayout(width: layout.size.width)
                    transition.updateFrame(node: self.dividerNode, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - dividerSize.width) / 2.0), y: layout.size.height - insets.bottom - buttonSize.height - inset - dividerSize.height), size: dividerSize))
                } else {
                    self.signInWithAppleButton?.isHidden = true
                    self.dividerNode.isHidden = true
                    self.proceedNode.isHidden = true
                    
                    if case .email = codeType {
                        self.nextOptionButtonNode.isHidden = true
                    } else {
                        self.nextOptionButtonNode.isHidden = false
                        items.append(AuthorizationLayoutItem(node: self.nextOptionButtonNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
                    }
                }
            }
        } else {
            self.titleIconNode.isHidden = true
            items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            items.append(AuthorizationLayoutItem(node: self.currentOptionNode, size: currentOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.codeInputView, size: codeFieldSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 40.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
            
            items.append(AuthorizationLayoutItem(node: self.nextOptionButtonNode, size: nextOptionSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 50.0, maxValue: 120.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        }
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - additionalBottomInset)), items: items, transition: transition, failIfDoesNotFit: false)
        
        if let textLayout = self.currentOptionNode.cachedLayout, !textLayout.spoilers.isEmpty {
            if self.dustNode == nil {
                let dustNode = InvisibleInkDustNode(textNode: nil)
                self.dustNode = dustNode
                self.currentOptionNode.supernode?.insertSubnode(dustNode, aboveSubnode: self.currentOptionNode)
                
            }
            if let dustNode = self.dustNode {
                let textFrame = self.currentOptionNode.frame
                dustNode.update(size: textFrame.size, color: self.theme.list.itemSecondaryTextColor, textColor: self.theme.list.itemPrimaryTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                transition.updateFrame(node: dustNode, frame: textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0))
            }
        } else if let dustNode = self.dustNode {
            self.dustNode = nil
            dustNode.removeFromSupernode()
        }
        
        self.nextOptionTitleNode.frame = self.nextOptionButtonNode.bounds
        
        self.titleActivateAreaNode.frame = self.titleNode.frame
        self.currentOptionActivateAreaNode.frame = self.currentOptionNode.frame
        self.currentOptionInfoActivateAreaNode.frame = self.currentOptionInfoNode.frame
    }
    
    func activateInput() {
        let _ = self.codeInputView.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeInputView.layer.addShakeAnimation()
    }
    
    func animateError(text: String) {
        self.codeInputView.animateError()
        self.codeInputView.layer.addShakeAnimation(amplitude: -30.0, duration: 0.5, count: 6, decay: true)
        
        self.errorTextNode.attributedText = NSAttributedString(string: text, font: Font.regular(17.0), textColor: self.theme.list.itemDestructiveColor, paragraphAlignment: .center)
        
        if let (layout, _) = self.layoutArguments {
            let errorTextSize = self.errorTextNode.updateLayout(CGSize(width: layout.size.width - 48.0, height: .greatestFiniteMagnitude))
            let yOffset: CGFloat = layout.size.width > 320.0 ? 28.0 : 15.0
            self.errorTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - errorTextSize.width) / 2.0), y: self.codeInputView.frame.maxY + yOffset), size: errorTextSize)
        }
        self.errorTextNode.alpha = 1.0
        self.errorTextNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.15)
        self.errorTextNode.layer.addShakeAnimation(amplitude: -8.0, duration: 0.5, count: 6, decay: true)
        
        Queue.mainQueue().after(0.85) {
            self.errorTextNode.alpha = 0.0
            self.errorTextNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15)
        }
    }
    
    func animateSuccess() {
        self.codeInputView.animateSuccess()
        
        let values: [NSNumber] = [1.0, 1.1, 1.0]
        self.codeInputView.layer.animateKeyframes(values: values, duration: 0.4, keyPath: "transform.scale")
    }
    
    @objc func codeFieldTextChanged(_ textField: UITextField) {
        self.textChanged(text: textField.text ?? "")
    }
        
    private func textChanged(text: String) {
        self.updateNextEnabled?(!text.isEmpty)
        if let codeType = self.codeType {
            var codeLength: Int32?
            switch codeType {
                case let .call(length):
                    codeLength = length
                case let .otherSession(length):
                    codeLength = length
                case let .missedCall(_, length):
                    codeLength = length
                case let .sms(length):
                    codeLength = length
                case let .email(_, length, _, _, _):
                    codeLength = length
                case let .fragment(_, length):
                    codeLength = length
                case let .firebase(_, length):
                    codeLength = length
                default:
                    break
            }
            if let codeLength = codeLength, text.count == Int(codeLength) {
                self.loginWithCode?(text)
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.inProgress {
            return false
        }
        var result = ""
        for c in string {
            if c.unicodeScalars.count == 1 {
                let scalar = c.unicodeScalars.first!
                if scalar >= "0" && scalar <= "9" {
                    result.append(c)
                }
            }
        }
        if result != string {
            textField.text = result
            self.codeFieldTextChanged(textField)
            return false
        }
        return true
    }
    
    @objc func nextOptionNodePressed() {
        self.requestAnotherOption?()
    }
    
    @objc func proceedPressed() {
        if case let .fragment(url, _) = self.codeType {
            self.openFragment?(url)
        }
    }
    
    @objc func signInWithApplePressed() {
        self.signInWithApple?()
    }
}
