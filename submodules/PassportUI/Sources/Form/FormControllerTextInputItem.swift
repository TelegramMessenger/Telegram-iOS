import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let textFont = Font.regular(17.0)
private let errorFont = Font.regular(13.0)

enum FormControllerTextInputItemColor {
    case primary
    case error
}

enum FormControllerTextInputItemType: Equatable {
    case regular(capitalization: UITextAutocapitalizationType, autocorrection: Bool)
    case latin(capitalization: UITextAutocapitalizationType)
    case email
    case number
}

final class FormControllerTextInputItem: FormControllerItem {
    let title: String
    let text: String
    let placeholder: String
    let color: FormControllerTextInputItemColor
    let type: FormControllerTextInputItemType
    let returnKeyType: UIReturnKeyType
    let error: String?
    let textUpdated: (String) -> Void
    let returnPressed: () -> Void
    
    init(title: String, text: String, placeholder: String, color: FormControllerTextInputItemColor = .primary, type: FormControllerTextInputItemType, returnKeyType: UIReturnKeyType = .next, error: String? = nil, textUpdated: @escaping (String) -> Void, returnPressed: @escaping () -> Void) {
        self.title = title
        self.text = text
        self.placeholder = placeholder
        self.color = color
        self.type = type
        self.returnKeyType = returnKeyType
        self.error = error
        self.textUpdated = textUpdated
        self.returnPressed = returnPressed
    }
    
    func node() -> ASDisplayNode & FormControllerItemNode {
        return FormControllerTextInputItemNode()
    }
    
    func update(node: ASDisplayNode & FormControllerItemNode, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        guard let node = node as? FormControllerTextInputItemNode else {
            assertionFailure()
            return (FormControllerItemPreLayout(aligningInset: 0.0), { _ in
                return 0.0
            })
        }
        return node.updateInternal(item: self, theme: theme, strings: strings, dateTimeFormat: dateTimeFormat, width: width, previousNeighbor: previousNeighbor, nextNeighbor: nextNeighbor, transition: transition)
    }
}

final class FormControllerTextInputItemNode: FormBlockItemNode<FormControllerTextInputItem>, UITextFieldDelegate {
    private let titleNode: ImmediateTextNode
    private let errorNode: ImmediateTextNode
    private let textField: TextFieldNode
    
    private var item: FormControllerTextInputItem?
    
    init() {
        self.titleNode = ImmediateTextNode()
        self.titleNode.displaysAsynchronously = false
        self.titleNode.maximumNumberOfLines = 1
        
        self.errorNode = ImmediateTextNode()
        self.errorNode.displaysAsynchronously = false
        self.errorNode.maximumNumberOfLines = 0
        
        self.textField = TextFieldNode()
        self.textField.textField.font = textFont
        
        super.init(selectable: false, topSeparatorInset: .regular)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.errorNode)
        self.addSubnode(self.textField)
        
        self.textField.textField.delegate = self
        self.textField.textField.addTarget(self, action: #selector(self.editingChanged), for: [.editingChanged])
    }
    
    override func update(item: FormControllerTextInputItem, theme: PresentationTheme, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, width: CGFloat, previousNeighbor: FormControllerItemNeighbor, nextNeighbor: FormControllerItemNeighbor, transition: ContainedViewLayoutTransition) -> (FormControllerItemPreLayout, (FormControllerItemLayoutParams) -> CGFloat) {
        self.item = item
        
        let leftInset: CGFloat = 16.0
        self.titleNode.attributedText = NSAttributedString(string: item.title, font: textFont, textColor: theme.list.itemPrimaryTextColor)
        let titleSize = self.titleNode.updateLayout(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        let aligningInset: CGFloat
        if titleSize.width.isZero {
            aligningInset = 0.0
        } else {
            aligningInset = leftInset + titleSize.width + 17.0
        }
        
        return (FormControllerItemPreLayout(aligningInset: aligningInset), { params in
            transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset, y: 12.0), size: titleSize))
            
            let capitalizationType: UITextAutocapitalizationType
            let autocorrectionType: UITextAutocorrectionType
            let keyboardType: UIKeyboardType
            
            switch item.type {
                case let .regular(capitalization, autocorrection):
                    capitalizationType = capitalization
                    autocorrectionType = autocorrection ? .default : .no
                    keyboardType = .default
                case let .latin(capitalization):
                    capitalizationType = capitalization
                    autocorrectionType = .no
                    keyboardType = .asciiCapable
                case .email:
                    capitalizationType = .none
                    autocorrectionType = .no
                    keyboardType = .emailAddress
                case .number:
                    capitalizationType = .none
                    autocorrectionType = .no
                    if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                        keyboardType = .asciiCapableNumberPad
                    } else {
                        keyboardType = .numberPad
                    }
            }
            
            if self.textField.textField.keyboardType != keyboardType {
                self.textField.textField.keyboardType = keyboardType
            }
            if self.textField.textField.autocapitalizationType != capitalizationType {
                self.textField.textField.autocapitalizationType = capitalizationType
            }
            if self.textField.textField.autocorrectionType != autocorrectionType {
                self.textField.textField.autocorrectionType = autocorrectionType
            }
            if self.textField.textField.returnKeyType != item.returnKeyType {
                self.textField.textField.returnKeyType = item.returnKeyType
            }
            
            self.textField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
            self.textField.textField.tintColor = theme.list.itemAccentColor
            
            let attributedPlaceholder = NSAttributedString(string: item.placeholder, font: textFont, textColor: theme.list.itemPlaceholderTextColor)
            if !(self.textField.textField.attributedPlaceholder?.isEqual(to: attributedPlaceholder) ?? false) {
                self.textField.textField.attributedPlaceholder = attributedPlaceholder
            }
            switch item.color {
                case .primary:
                    self.textField.textField.textColor = theme.list.itemPrimaryTextColor
                case .error:
                    self.textField.textField.textColor = theme.list.itemDestructiveColor
            }
            
            if self.textField.textField.text != item.text {
                self.textField.textField.text = item.text
            }
            
            transition.updateFrame(node: self.textField, frame: CGRect(origin: CGPoint(x: params.maxAligningInset, y: 3.0), size: CGSize(width: max(1.0, width - params.maxAligningInset - 8.0), height: 40.0)))
            
            self.errorNode.attributedText = NSAttributedString(string: item.error ?? "", font: errorFont, textColor: theme.list.freeTextErrorColor)
            let errorSize = self.errorNode.updateLayout(CGSize(width: width - params.maxAligningInset - 8.0, height: CGFloat.greatestFiniteMagnitude))
            
            transition.updateFrame(node: self.errorNode, frame: CGRect(origin: CGPoint(x: params.maxAligningInset, y: 44.0 - 4.0), size: errorSize))
            
            var height: CGFloat = 44.0
            if !errorSize.width.isZero {
                height += -4.0 + errorSize.height + 8.0
            }
            
            return height
        })
    }
    
    @objc private func editingChanged() {
        self.item?.textUpdated(self.textField.textField.text ?? "")
    }
    
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.item?.returnPressed()
        return false
    }
    
    func activate() {
        self.textField.textField.becomeFirstResponder()
    }
}
