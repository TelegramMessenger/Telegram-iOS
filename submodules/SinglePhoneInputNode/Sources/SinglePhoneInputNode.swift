import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramStringFormatting
import PhoneNumberFormat

private func removeDuplicatedPlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c == "+" {
                if result.isEmpty {
                    result += String(c)
                }
            } else {
                result += String(c)
            }
        }
    }
    return result
}

private func removePlus(_ text: String?) -> String {
    var result = ""
    if let text = text {
        for c in text {
            if c != "+" {
                result += String(c)
            }
        }
    }
    return result
}

private func cleanPhoneNumber(_ text: String?) -> String {
    var cleanNumber = ""
    if let text = text.flatMap({ normalizeArabicNumeralString($0, type: .western) }) {
        for c in text {
            if c == "+" {
                if cleanNumber.isEmpty {
                    cleanNumber += String(c)
                }
            } else if c >= "0" && c <= "9" {
                cleanNumber += String(c)
            }
        }
    }
    return cleanNumber
}

private func cleanPrefix(_ text: String) -> String {
    var result = ""
    var checked = false
    for c in text {
        if c != " " {
            checked = true
        }
        if checked {
            result += String(c)
        }
    }
    return result
}

private func cleanSuffix(_ text: String) -> String {
    var result = ""
    var checked = false
    for c in text.reversed() {
        if c != " " {
            checked = true
        }
        if checked {
            result = String(c) + result
        }
    }
    return result
}

public final class SinglePhoneInputNode: ASDisplayNode, UITextFieldDelegate {
    private let fontSize: CGFloat
    
    public var numberField: TextFieldNode?
    public var numberFieldText: String?
    
    public var enableEditing: Bool = true
    
    public var number: String {
        get {
            return cleanPhoneNumber(self.numberField?.textField.text ?? "")
        } set(value) {
            self.updateNumber(value)
        }
    }
    public var numberUpdated: ((String) -> Void)?
    public var beginEditing: (() -> Void)?
    public var endEditing: (() -> Void)?
    
    private let phoneFormatter = InteractivePhoneFormatter()
    
    private var validLayout: CGSize?
    
    public init(fontSize: CGFloat = 20.0) {
        self.fontSize = fontSize
        
        super.init()
    }
    
    override public func didLoad() {
        super.didLoad()
        
        let numberField = TextFieldNode()
        numberField.textField.font = Font.regular(self.fontSize)
        numberField.textField.keyboardType = .phonePad
        numberField.textField.text = self.numberFieldText
        
        self.addSubnode(numberField)
        
        numberField.textField.addTarget(self, action: #selector(self.numberTextChanged(_:)), for: .editingChanged)
        numberField.textField.delegate = self
        
        self.numberField = numberField
        
        if let size = self.validLayout {
            numberField.frame = CGRect(origin: CGPoint(), size: size)
        }
    }
    
    @objc private func numberTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return self.enableEditing
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        self.beginEditing?()
    }
    
    public func textFieldDidEndEditing(_ textField: UITextField) {
        self.endEditing?()
    }
    
    private func updateNumberFromTextFields() {
        guard let numberField = self.numberField else {
            return
        }
        let inputText = removeDuplicatedPlus(cleanPhoneNumber(numberField.textField.text))
        self.updateNumber(inputText)
        self.numberUpdated?(inputText)
    }
    
    private func updateNumber(_ inputText: String) {
        let (_, numberText) = self.phoneFormatter.updateText(inputText)
        guard let numberField = self.numberField else {
            self.numberFieldText = numberText
            return
        }
        
        if numberText != numberField.textField.text {
            numberField.textField.text = numberText
        }
    }
    
    public func updateLayout(size: CGSize) {
        self.validLayout = size
        self.numberField?.frame = CGRect(origin: CGPoint(), size: size)
    }
}
