import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let titleFont = Font.regular(17.0)

enum BotPaymentFieldContentType {
    case generic
    case name
    case phoneNumber
    case email
    case address
}

final class BotPaymentFieldItemNode: BotPaymentItemNode, UITextFieldDelegate {
    private let title: String
    var text: String {
        get {
            return self.textField.textField.text ?? ""
        } set(value) {
            self.textField.textField.text = value
        }
    }
    private let contentType: BotPaymentFieldContentType
    private let placeholder: String
    private let titleNode: ASTextNode
    
    private let textField: TextFieldNode
    
    private var theme: PresentationTheme?
    
    var focused: (() -> Void)?
    var textUpdated: (() -> Void)?
    var returnPressed: (() -> Void)?
    
    init(title: String, placeholder: String, text: String = "", contentType: BotPaymentFieldContentType = .generic) {
        self.title = title
        self.placeholder = placeholder
        self.contentType = contentType
        
        self.titleNode = ASTextNode()
        self.titleNode.maximumNumberOfLines = 1
        
        self.textField = TextFieldNode()
        self.textField.textField.font = titleFont
        self.textField.textField.returnKeyType = .next
        self.textField.textField.text = text
        switch contentType {
            case .generic:
                break
            case .name:
                self.textField.textField.autocorrectionType = .no
                self.textField.textField.keyboardType = .asciiCapable
            case .address:
                self.textField.textField.autocorrectionType = .no
            case .phoneNumber:
                self.textField.textField.keyboardType = .phonePad
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.textField.textField.textContentType = .telephoneNumber
                }
            case .email:
                self.textField.textField.keyboardType = .emailAddress
                if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                    self.textField.textField.textContentType = .emailAddress
                }
        }

        super.init(needsBackground: true)
        
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textField)
        
        self.textField.textField.addTarget(self, action: #selector(self.editingChanged), for: [.editingChanged])
        self.textField.textField.delegate = self
    }
    
    override func measureInset(theme: PresentationTheme, width: CGFloat) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            self.textField.textField.textColor = theme.list.itemPrimaryTextColor
            self.textField.textField.attributedPlaceholder = NSAttributedString(string: placeholder, font: titleFont, textColor: theme.list.itemPlaceholderTextColor)
            self.textField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
            self.textField.textField.tintColor = theme.list.itemAccentColor
        }
        
        let leftInset: CGFloat = 16.0
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0, height: CGFloat.greatestFiniteMagnitude))
        
        if titleSize.width.isZero {
            return 0.0
        } else {
            return leftInset + titleSize.width + 17.0
        }
    }
    
    override func layoutContents(theme: PresentationTheme, width: CGFloat, sideInset: CGFloat, measuredInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        if self.theme !== theme {
            self.theme = theme
            self.titleNode.attributedText = NSAttributedString(string: self.title, font: titleFont, textColor: theme.list.itemPrimaryTextColor)
            self.textField.textField.keyboardAppearance = theme.rootController.keyboardColor.keyboardAppearance
            self.textField.textField.tintColor = theme.list.itemAccentColor
        }
        
        let leftInset: CGFloat = 16.0
        
        let titleSize = self.titleNode.measure(CGSize(width: width - leftInset - 70.0 - sideInset * 2.0, height: CGFloat.greatestFiniteMagnitude))
        
        transition.updateFrame(node: self.titleNode, frame: CGRect(origin: CGPoint(x: leftInset + sideInset, y: 11.0), size: titleSize))
        
        var textInset = leftInset
        if !titleSize.width.isZero {
            textInset += titleSize.width + 18.0
        }
        
        textInset = max(measuredInset, textInset)
        
        transition.updateFrame(node: self.textField, frame: CGRect(origin: CGPoint(x: textInset + sideInset, y: 0.0), size: CGSize(width: max(1.0, width - textInset - 8.0), height: 40.0)))
        
        return 44.0
    }
    
    func activateInput() {
        self.textField.textField.becomeFirstResponder()
    }
    
    @objc func editingChanged() {
        self.textUpdated?()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        self.focused?()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.returnPressed?()
        return false
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !string.isEmpty {
            if case .name = self.contentType {
                if let lowerBound = textField.position(from: textField.beginningOfDocument, offset: range.lowerBound), let upperBound = textField.position(from: textField.beginningOfDocument, offset: range.upperBound), let fieldRange = textField.textRange(from: lowerBound, to: upperBound) {
                    textField.replace(fieldRange, withText: string.uppercased())
                    self.editingChanged()
                    return false
                }
            }
        }
        return true
    }
}
