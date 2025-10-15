import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ActivityIndicator
import AppBundle

private let passwordFont = Font.regular(16.0)
private let buttonFont = Font.regular(17.0)

final class SecureIdAuthPasswordOptionContentNode: ASDisplayNode, SecureIdAuthContentNode, UITextFieldDelegate {
    private let checkPassword: (String) -> Void
    private let passwordHelp: () -> Void
    
    private let inputContainer: ASDisplayNode
    private let titleNode: ImmediateTextNode
    private let inputBackground: ASImageNode
    private let inputField: TextFieldNode
    private var clearOnce: Bool = false
    private let inputButtonNode: HighlightableButtonNode
    private let inputActivityNode: ActivityIndicator
    
    private let buttonNode: HighlightableButtonNode
    private let buttonBackground: ASImageNode
    private let buttonLabel: ImmediateTextNode
    
    private var validLayout: CGFloat?
    
    private var isChecking = false
    
    private let hapticFeedback = HapticFeedback()
    
    init(theme: PresentationTheme, strings: PresentationStrings, hint: String, checkPassword: @escaping (String) -> Void, passwordHelp: @escaping () -> Void) {
        self.checkPassword = checkPassword
        self.passwordHelp = passwordHelp
        
        self.inputContainer = ASDisplayNode()
        self.inputBackground = ASImageNode()
        self.inputBackground.isLayerBacked = true
        self.inputBackground.displaysAsynchronously = false
        self.inputBackground.displayWithoutProcessing = true
        self.titleNode = ImmediateTextNode()
        self.titleNode.attributedText = NSAttributedString(string: strings.Passport_PasswordHelp, font: Font.regular(14.0), textColor: theme.list.freeTextColor)
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.textAlignment = .center
        self.inputField = TextFieldNode()
        
        self.inputButtonNode = HighlightableButtonNode()
        self.inputActivityNode = ActivityIndicator(type: .custom(theme.list.freeInputField.controlColor, 18.0, 1.5, false))
       
        if let image = generateTintedImage(image: UIImage(bundleImageName: "Secure ID/PasswordHelpIcon"), color: theme.list.freeInputField.controlColor) {
            self.inputButtonNode.setImage(image, for: [])
            self.inputButtonNode.frame = CGRect(origin: CGPoint(), size: image.size)
        }
        
        self.inputBackground.image = generateStretchableFilledCircleImage(radius: 10.0, color: theme.list.freeInputField.backgroundColor)
        
        self.inputField.textField.isSecureTextEntry = true
        self.inputField.textField.font = passwordFont
        self.inputField.textField.textColor = theme.list.freeInputField.primaryColor
        self.inputField.textField.attributedPlaceholder = NSAttributedString(string: hint.isEmpty ? strings.LoginPassword_PasswordPlaceholder : hint, font: passwordFont, textColor: theme.list.freeInputField.placeholderColor)
        self.inputField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.inputField.textField.tintColor = theme.list.itemAccentColor
        
        self.buttonNode = HighlightableButtonNode()
        
        self.buttonBackground = ASImageNode()
        self.buttonBackground.isLayerBacked = true
        self.buttonBackground.displaysAsynchronously = false
        self.buttonBackground.displayWithoutProcessing = true
        self.buttonBackground.image = generateStretchableFilledCircleImage(radius: 10.0, color: theme.list.itemCheckColors.fillColor)
        self.buttonNode.addSubnode(self.buttonBackground)
        
        self.buttonLabel = ImmediateTextNode()
        self.buttonLabel.attributedText = NSAttributedString(string: strings.Common_Next, font: buttonFont, textColor: theme.list.itemCheckColors.foregroundColor)
        self.buttonNode.addSubnode(self.buttonLabel)
        
        super.init()
        
        self.inputContainer.addSubnode(self.titleNode)
        self.inputContainer.addSubnode(self.inputBackground)
        self.inputContainer.addSubnode(self.inputField)
        self.inputContainer.addSubnode(self.inputButtonNode)
        self.inputContainer.addSubnode(self.inputActivityNode)
        self.inputContainer.addSubnode(self.buttonNode)
        
        self.addSubnode(self.inputContainer)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.buttonBackground.layer.removeAnimation(forKey: "opacity")
                    strongSelf.buttonBackground.alpha = 0.55
                } else {
                    strongSelf.buttonBackground.alpha = 1.0
                    strongSelf.buttonBackground.layer.animateAlpha(from: 0.55, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        
        self.inputField.textField.delegate = self
        
        self.inputButtonNode.hitTestSlop = UIEdgeInsets(top: -4.0, left: -4.0, bottom: -4.0, right: -4.0)
        self.inputButtonNode.addTarget(self, action: #selector(self.inputButtonPressed), forControlEvents: .touchUpInside)
        self.inputActivityNode.isHidden = true
    }
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> SecureIdAuthContentLayout {
        let transition = self.validLayout == nil ? .immediate : transition
        self.validLayout = width
        
        let inputWidth = min(270.0, width - 30.0)
        
        let labelSize = self.buttonLabel.updateLayout(CGSize(width: width - 20.0, height: 100.0))
        let buttonSize = CGSize(width: max(labelSize.width + 30.0, 100.0), height: 36.0)
        
        let titleSpacing: CGFloat = 15.0
        
        let titleSize = self.titleNode.updateLayout(CGSize(width: inputWidth, height: CGFloat.greatestFiniteMagnitude))
        
        let buttonSpacing: CGFloat = 16.0
        
        let inputFrame = CGRect(origin: CGPoint(x: floor((width - inputWidth) / 2.0), y: titleSize.height + titleSpacing), size: CGSize(width: inputWidth, height: 32.0))
        
        let inputContainerFrame = CGRect(origin: CGPoint(), size: CGSize(width: width, height: titleSize.height + titleSpacing + inputFrame.height + buttonSpacing + buttonSize.height))
        
        let titleFrame = CGRect(origin: CGPoint(x: floor((width - titleSize.width) / 2.0), y: 0.0), size: titleSize)
        
        transition.updateFrame(node: self.inputContainer, frame: inputContainerFrame)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.inputBackground, frame: inputFrame)
        var inputFieldFrame = inputFrame.insetBy(dx: 6.0, dy: 0.0)
        inputFieldFrame.size.width -= 16.0
        transition.updateFrame(node: self.inputField, frame: inputFieldFrame)
        
        transition.updateFrame(node: self.inputButtonNode, frame: CGRect(origin: CGPoint(x: inputFrame.maxX - self.inputButtonNode.bounds.size.width - 6.0, y: inputFrame.minY + floor((inputFrame.height - self.inputButtonNode.bounds.size.height) / 2.0)), size: self.inputButtonNode.bounds.size))
        
        let activitySize = CGSize(width: 18.0, height: 18.0)
        transition.updateFrame(node: self.inputActivityNode, frame: CGRect(origin: CGPoint(x: inputFrame.maxX - activitySize.width - 6.0, y: inputFrame.minY + floor((inputFrame.height - activitySize.height) / 2.0)), size: activitySize))
        
        let buttonBounds = CGRect(origin: CGPoint(), size: buttonSize)
        transition.updateFrame(node: self.buttonNode, frame: buttonBounds.offsetBy(dx: floor((width - buttonSize.width) / 2.0), dy: inputFrame.maxY + buttonSpacing))
        transition.updateFrame(node: self.buttonBackground, frame: buttonBounds)
        transition.updateFrame(node: self.buttonLabel, frame: CGRect(origin: CGPoint(x: floor((buttonSize.width - labelSize.width) / 2.0), y: floor((buttonSize.height - labelSize.height) / 2.0)), size: buttonSize))
        
        return SecureIdAuthContentLayout(height: inputContainerFrame.size.height, centerOffset: floor((inputContainerFrame.size.height) / 2.0))
    }
    
    func animateIn() {
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
            completion()
        })
    }
    
    func didAppear() {
        self.inputField.textField.becomeFirstResponder()
    }
    
    func willDisappear() {
        self.inputField.textField.resignFirstResponder()
    }
    
    @objc private func buttonPressed() {
        if self.isChecking {
            return
        }
        
        if self.inputField.textField.text?.isEmpty ?? true {
            self.inputField.layer.addShakeAnimation()
            self.inputBackground.layer.addShakeAnimation()
            self.hapticFeedback.error()
        } else {
            self.checkPassword(self.inputField.textField.text ?? "")
        }
    }
    
    @objc private func inputButtonPressed() {
        self.passwordHelp()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if self.isChecking {
            return false
        }
        
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
        if !self.isChecking {
            self.buttonPressed()
        }
        return false
    }
    
    func updateIsChecking(_ isChecking: Bool) {
        self.isChecking = isChecking
        self.inputField.alpha = isChecking ? 0.5 : 1.0
        self.inputActivityNode.isHidden = !isChecking
        self.inputButtonNode.isHidden = isChecking
    }
    
    func updateIsInvalid() {
        self.clearOnce = true
    }
}
