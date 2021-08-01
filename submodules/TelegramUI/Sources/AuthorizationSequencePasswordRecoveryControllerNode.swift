import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import AuthorizationUI

final class AuthorizationSequencePasswordRecoveryControllerNode: ASDisplayNode, UITextFieldDelegate {
    private let strings: PresentationStrings
    private let theme: PresentationTheme
    
    private let titleNode: ASTextNode
    private let noticeNode: ASTextNode
    private let noAccessNode: HighlightableButtonNode
    
    private let codeField: TextFieldNode
    private let codeSeparatorNode: ASDisplayNode
    
    private var layoutArguments: (ContainerViewLayout, CGFloat)?
    
    var currentCode: String {
        return self.codeField.textField.text ?? ""
    }
    
    var recoverWithCode: ((String) -> Void)?
    var noAccess: (() -> Void)?
    
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
        self.titleNode.attributedText = NSAttributedString(string: strings.TwoStepAuth_RecoveryTitle, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        
        self.noticeNode = ASTextNode()
        self.noticeNode.isUserInteractionEnabled = false
        self.noticeNode.displaysAsynchronously = false
        self.noticeNode.attributedText = NSAttributedString(string: strings.TwoStepAuth_RecoveryCodeHelp, font: Font.regular(16.0), textColor: self.theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.noAccessNode = HighlightableButtonNode()
        self.noAccessNode.displaysAsynchronously = false
        
        self.codeSeparatorNode = ASDisplayNode()
        self.codeSeparatorNode.isLayerBacked = true
        self.codeSeparatorNode.backgroundColor = self.theme.list.itemPlainSeparatorColor
        
        self.codeField = TextFieldNode()
        self.codeField.textField.font = Font.regular(20.0)
        self.codeField.textField.textColor = self.theme.list.itemPrimaryTextColor
        self.codeField.textField.textAlignment = .center
        self.codeField.textField.attributedPlaceholder = NSAttributedString(string: self.strings.TwoStepAuth_RecoveryCode, font: Font.regular(20.0), textColor: self.theme.list.itemPlaceholderTextColor)
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
        self.addSubnode(self.noAccessNode)
        self.addSubnode(self.noticeNode)
        
        self.noAccessNode.addTarget(self, action: #selector(self.noAccessPressed), forControlEvents: .touchUpInside)
    }
    
    func updateData(emailPattern: String) {
        self.noAccessNode.setAttributedTitle(NSAttributedString(string: self.strings.TwoStepAuth_RecoveryEmailUnavailable(emailPattern).string, font: Font.regular(16.0), textColor: self.theme.list.itemAccentColor, paragraphAlignment: .center), for: [])
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.layoutArguments = (layout, navigationBarHeight)
        
        var insets = layout.insets(options: [.input])
        insets.top = navigationBarHeight
        
        if max(layout.size.width, layout.size.height) > 1023.0 {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.TwoStepAuth_RecoveryTitle, font: Font.light(40.0), textColor: self.theme.list.itemPrimaryTextColor)
        } else {
            self.titleNode.attributedText = NSAttributedString(string: self.strings.TwoStepAuth_RecoveryTitle, font: Font.light(30.0), textColor: self.theme.list.itemPrimaryTextColor)
        }
        
        let titleSize = self.titleNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        let noticeSize = self.noticeNode.measure(CGSize(width: layout.size.width - 28.0, height: CGFloat.greatestFiniteMagnitude))
        let noAccessSize = self.noAccessNode.measure(CGSize(width: layout.size.width, height: CGFloat.greatestFiniteMagnitude))
        
        var items: [AuthorizationLayoutItem] = []
        items.append(AuthorizationLayoutItem(node: self.titleNode, size: titleSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.noticeNode, size: noticeSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 10.0, maxValue: 10.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.codeField, size: CGSize(width: layout.size.width - 88.0, height: 44.0), spacingBefore: AuthorizationLayoutItemSpacing(weight: 32.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        items.append(AuthorizationLayoutItem(node: self.codeSeparatorNode, size: CGSize(width: layout.size.width - 88.0, height: UIScreenPixel), spacingBefore: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        items.append(AuthorizationLayoutItem(node: self.noAccessNode, size: noAccessSize, spacingBefore: AuthorizationLayoutItemSpacing(weight: 48.0, maxValue: 100.0), spacingAfter: AuthorizationLayoutItemSpacing(weight: 0.0, maxValue: 0.0)))
        
        let _ = layoutAuthorizationItems(bounds: CGRect(origin: CGPoint(x: 0.0, y: insets.top), size: CGSize(width: layout.size.width, height: layout.size.height - insets.top - insets.bottom - 20.0)), items: items, transition: transition, failIfDoesNotFit: false)
    }
    
    func activateInput() {
        self.codeField.textField.becomeFirstResponder()
    }
    
    func animateError() {
        self.codeField.layer.addShakeAnimation()
    }
    
    @objc func passwordFieldTextChanged(_ textField: UITextField) {
        
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.recoverWithCode?(self.currentCode)
        return false
    }
    
    @objc func noAccessPressed() {
        self.noAccess?()
    }
}

