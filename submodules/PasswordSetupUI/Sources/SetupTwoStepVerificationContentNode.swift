import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramPresentationData

enum SetupTwoStepVerificationInputType {
    case password
    case text
    case code
    case email
}

struct SetupTwoStepVerificationContentAction {
    let title: String
    let action: () -> Void
}

final class SetupTwoStepVerificationContentNode: ASDisplayNode, UITextFieldDelegate {
    private var theme: PresentationTheme
    let kind: SetupTwoStepVerificationStateKind
    private let leftAction: SetupTwoStepVerificationContentAction?
    private let rightAction: SetupTwoStepVerificationContentAction?
    private let textUpdated: (String) -> Void
    private let returnPressed: () -> Void
    
    private let titleNode: ImmediateTextNode
    private let subtitleNode: ImmediateTextNode
    private let inputNode: TextFieldNode
    private let inputSeparator: ASDisplayNode
    private let leftActionButton: HighlightableButtonNode
    private let rightActionButton: HighlightableButtonNode
    
    private var isEnabled = true
    private var clearOnce: Bool = false
    
    init(theme: PresentationTheme, kind: SetupTwoStepVerificationStateKind, title: String, subtitle: String, inputType: SetupTwoStepVerificationInputType, placeholder: String, text: String, isPassword: Bool, textUpdated: @escaping (String) -> Void, returnPressed: @escaping () -> Void, leftAction: SetupTwoStepVerificationContentAction?, rightAction: SetupTwoStepVerificationContentAction?) {
        self.theme = theme
        self.kind = kind
        self.leftAction = leftAction
        self.rightAction = rightAction
        self.textUpdated = textUpdated
        self.returnPressed = returnPressed
        
        self.titleNode = ImmediateTextNode()
        self.titleNode.maximumNumberOfLines = 0
        self.titleNode.displaysAsynchronously = false
        self.titleNode.textAlignment = .center
        self.titleNode.attributedText = NSAttributedString(string: title, font: Font.light(30.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.subtitleNode = ImmediateTextNode()
        self.subtitleNode.maximumNumberOfLines = 0
        self.subtitleNode.displaysAsynchronously = false
        self.subtitleNode.textAlignment = .center
        self.subtitleNode.attributedText = NSAttributedString(string: subtitle, font: Font.regular(16.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center)
        
        self.inputNode = TextFieldNode()
        self.inputNode.textField.textColor = theme.list.itemPrimaryTextColor
        self.inputNode.textField.font = Font.regular(22.0)
        self.inputNode.textField.attributedPlaceholder = NSAttributedString(string: placeholder, font: Font.regular(22.0), textColor: theme.list.itemPlaceholderTextColor)
        self.inputNode.textField.textAlignment = .center
        self.inputNode.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
        self.inputNode.textField.tintColor = theme.list.itemAccentColor
        switch inputType {
            case .password:
                self.inputNode.textField.isSecureTextEntry = true
                self.inputNode.textField.autocapitalizationType = .none
                self.inputNode.textField.autocorrectionType = .no
                if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
                    #if DEBUG
                    self.inputNode.textField.textContentType = .newPassword
                    #endif
                }
            case .text:
                break
            case .code:
                self.inputNode.textField.autocapitalizationType = .none
                self.inputNode.textField.autocorrectionType = .no
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.inputNode.textField.keyboardType = .asciiCapableNumberPad
                } else {
                    self.inputNode.textField.keyboardType = .numberPad
                }
                if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
                    self.inputNode.textField.textContentType = .oneTimeCode
                }
            case .email:
                self.inputNode.textField.autocapitalizationType = .none
                self.inputNode.textField.autocorrectionType = .no
                self.inputNode.textField.keyboardType = .emailAddress
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.inputNode.textField.textContentType = .emailAddress
                }
        }
        self.inputSeparator = ASDisplayNode()
        self.inputSeparator.isLayerBacked = true
        self.inputSeparator.backgroundColor = theme.list.itemPlainSeparatorColor
        
        self.leftActionButton = HighlightableButtonNode()
        self.leftActionButton.hitTestSlop = UIEdgeInsets(top: -10.0, left: -16.0, bottom: -10.0, right: -16.0)
        self.rightActionButton = HighlightableButtonNode()
        self.rightActionButton.hitTestSlop = UIEdgeInsets(top: -10.0, left: -16.0, bottom: -10.0, right: -16.0)
        
        super.init()
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.inputNode)
        self.addSubnode(self.inputSeparator)
        
        self.inputNode.textField.addTarget(self, action: #selector(self.inputNodeTextChanged(_:)), for: .editingChanged)
        self.inputNode.textField.returnKeyType = .next
        self.inputNode.textField.delegate = self
        
        if let leftAction = self.leftAction {
            self.leftActionButton.setAttributedTitle(NSAttributedString(string: leftAction.title, font: Font.regular(16.0), textColor: theme.list.itemAccentColor), for: [])
            self.leftActionButton.setAttributedTitle(NSAttributedString(string: leftAction.title, font: Font.regular(16.0), textColor: theme.list.itemDisabledTextColor), for: [.disabled])
            self.addSubnode(self.leftActionButton)
            self.leftActionButton.addTarget(self, action: #selector(self.actionButtonPressed(_:)), forControlEvents: .touchUpInside)
        }
        if let rightAction = self.rightAction {
            self.rightActionButton.setAttributedTitle(NSAttributedString(string: rightAction.title, font: Font.regular(16.0), textColor: theme.list.itemAccentColor), for: [])
            self.rightActionButton.setAttributedTitle(NSAttributedString(string: rightAction.title, font: Font.regular(16.0), textColor: theme.list.itemDisabledTextColor), for: [.disabled])
            self.addSubnode(self.rightActionButton)
            self.rightActionButton.addTarget(self, action: #selector(self.actionButtonPressed(_:)), forControlEvents: .touchUpInside)
        }
    }
    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.theme = presentationData.theme
        self.inputNode.textField.keyboardAppearance = self.theme.rootController.keyboardColor.keyboardAppearance
        self.inputSeparator.backgroundColor = self.theme.list.itemPlainSeparatorColor
        self.inputNode.textField.tintColor = self.theme.list.itemAccentColor
    }
    
    func updateIsEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        self.leftActionButton.isEnabled = isEnabled
        self.rightActionButton.isEnabled = isEnabled
    }
    
    /// `safeInsets`: the layout's safe insets. Only their sides are read, and only when they differ (iPhone Duo's side
    /// strip): the texts and the field then center in the band between them. `reservedCorners`: the layout's corner
    /// blocks; the action buttons at the bottom span the strip and keep clear only of a block at the bottom (folded
    /// landscape-left put the right action under the status block). Equal sides change nothing.
    func updateLayout(size: CGSize, insets: UIEdgeInsets, visibleInsets: UIEdgeInsets, safeInsets: UIEdgeInsets = UIEdgeInsets(), reservedCorners: ContainerViewLayoutCorners = .none, transition: ContainedViewLayoutTransition) {
        let sidePadding: CGFloat = 20.0
        let sideButtonInset: CGFloat = 16.0
        let insetsDiffer = safeInsets.left != safeInsets.right
        let bandMinX: CGFloat = insetsDiffer ? safeInsets.left : 0.0
        let bandWidth: CGFloat = insetsDiffer ? size.width - safeInsets.left - safeInsets.right : size.width
        let bottomSideInsets = bottomEdgeSideInsets(safeInsets: safeInsets, reservedCorners: reservedCorners)
        let bottomBandMinX: CGFloat = insetsDiffer ? bottomSideInsets.left : 0.0
        let bottomBandWidth: CGFloat = insetsDiffer ? size.width - bottomSideInsets.left - bottomSideInsets.right : size.width
        let titleSize = self.titleNode.updateLayout(CGSize(width: bandWidth - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let subtitleSize = self.subtitleNode.updateLayout(CGSize(width: bandWidth - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        
        let leftButtonSize = self.leftActionButton.measure(CGSize(width: bottomBandWidth - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let rightButtonSize = self.rightActionButton.measure(CGSize(width: bottomBandWidth - sidePadding * 2.0, height: .greatestFiniteMagnitude))
        let buttonsHeight: CGFloat
        if self.leftActionButton.supernode != nil || self.rightActionButton.supernode != nil {
            buttonsHeight = 56.0
        } else {
            buttonsHeight = 0.0
        }
        
        let titleSubtitleSpacing: CGFloat = 12.0
        
        let textHeight = titleSize.height + titleSubtitleSpacing + subtitleSize.height
        let inputHeight: CGFloat = 44.0
        let inputWidth: CGFloat = min(300.0, bandWidth - 37.0 * 2.0)
        
        let minContentHeight = textHeight + inputHeight
        let contentHeight = min(215.0, max(size.height - insets.top - insets.bottom - 40.0, minContentHeight))
        let contentOrigin = max(56.0, insets.top + floor((size.height - insets.top - insets.bottom - contentHeight) / 2.0))
        let titleFrame = CGRect(origin: CGPoint(x: bandMinX + floor((bandWidth - titleSize.width) / 2.0), y: contentOrigin), size: titleSize)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        transition.updateFrame(node: self.subtitleNode, frame: CGRect(origin: CGPoint(x: bandMinX + floor((bandWidth - subtitleSize.width) / 2.0), y: titleFrame.maxY + titleSubtitleSpacing), size: subtitleSize))
        transition.updateFrame(node: self.inputSeparator, frame: CGRect(origin: CGPoint(x: bandMinX + floor((bandWidth - inputWidth) / 2.0), y: contentOrigin + contentHeight - UIScreenPixel), size: CGSize(width: inputWidth, height: UIScreenPixel)))
        transition.updateFrame(node: self.inputNode, frame: CGRect(origin: CGPoint(x: bandMinX + floor((bandWidth - inputWidth) / 2.0), y: contentOrigin + contentHeight - inputHeight), size: CGSize(width: inputWidth, height: inputHeight)))
        transition.updateFrame(node: self.leftActionButton, frame: CGRect(origin: CGPoint(x: bottomBandMinX + sideButtonInset, y: size.height - visibleInsets.bottom - buttonsHeight + floor((buttonsHeight - leftButtonSize.height) / 2.0)), size: leftButtonSize))
        transition.updateFrame(node: self.rightActionButton, frame: CGRect(origin: CGPoint(x: bottomBandMinX + bottomBandWidth - sideButtonInset - rightButtonSize.width, y: size.height - visibleInsets.bottom - buttonsHeight + floor((buttonsHeight - rightButtonSize.height) / 2.0)), size: rightButtonSize))
    }
    
    func activate() {
        self.inputNode.textField.becomeFirstResponder()
    }
    
    func dataEntryError() {
        self.clearOnce = true
    }
    
    @objc private func inputNodeTextChanged(_ textField: UITextField) {
        self.textUpdated(textField.text ?? "")
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
        self.returnPressed()
        return false
    }
    
    @objc private func actionButtonPressed(_ node: ASDisplayNode) {
        if node === self.leftActionButton {
            self.leftAction?.action()
        } else if node === self.rightActionButton {
            self.rightAction?.action()
        }
    }
}
