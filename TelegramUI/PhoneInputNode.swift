import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

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
    if let text = text {
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

final class PhoneInputNode: ASDisplayNode, UITextFieldDelegate {
    let countryCodeField: TextFieldNode
    let numberField: TextFieldNode
    
    var previousCountryCodeText = "+"
    var previousNumberText = ""
    var enableEditing: Bool = true
    
    var number: String {
        get {
            return cleanPhoneNumber((self.countryCodeField.textField.text ?? "") + (self.numberField.textField.text ?? ""))
        } set(value) {
            self.updateNumber(value)
        }
    }
    
    var codeAndNumber: (Int32?, String) {
        get {
            var code: Int32?
            if let text = self.countryCodeField.textField.text, let number = Int(removePlus(text)) {
                code = Int32(number)
            }
            return (code, cleanPhoneNumber(self.numberField.textField.text))
        } set(value) {
            self.updateNumber("+" + (value.0 == nil ? "" : "\(value.0!)") + value.1)
        }
    }
    
    var countryCodeUpdated: ((String) -> Void)?
    
    private let phoneFormatter = InteractivePhoneFormatter()
    
    private let fontSize: CGFloat
    
    init(fontSize: CGFloat = 20.0) {
        self.fontSize = fontSize
        
        self.countryCodeField = TextFieldNode()
        self.countryCodeField.textField.font = Font.regular(fontSize)
        self.countryCodeField.textField.textAlignment = .center
        self.countryCodeField.textField.keyboardType = .numberPad
        self.countryCodeField.textField.returnKeyType = .next
        
        self.numberField = TextFieldNode()
        self.numberField.textField.font = Font.regular(fontSize)
        self.numberField.textField.keyboardType = .numberPad
        
        super.init()
        
        self.addSubnode(self.countryCodeField)
        self.addSubnode(self.numberField)
        
        self.numberField.textField.didDeleteBackwardWhileEmpty = { [weak self] in
            self?.countryCodeField.textField.becomeFirstResponder()
        }
        self.countryCodeField.textField.addTarget(self, action: #selector(self.countryCodeTextChanged(_:)), for: .editingChanged)
        self.numberField.textField.addTarget(self, action: #selector(self.numberTextChanged(_:)), for: .editingChanged)
        self.countryCodeField.textField.delegate = self
        self.numberField.textField.delegate = self
    }
    
    @objc func countryCodeTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    @objc func numberTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return self.enableEditing
    }
    
    private func updateNumberFromTextFields() {
        let inputText = removeDuplicatedPlus(cleanPhoneNumber(self.countryCodeField.textField.text) + cleanPhoneNumber(self.numberField.textField.text))
        self.updateNumber(inputText)
    }
    
    private func updateNumber(_ inputText: String) {
        let (regionPrefix, text) = self.phoneFormatter.updateText(inputText)
        var realRegionPrefix: String
        let numberText: String
        if let regionPrefix = regionPrefix, !regionPrefix.isEmpty {
            realRegionPrefix = cleanSuffix(regionPrefix)
            if !realRegionPrefix.hasPrefix("+") {
                realRegionPrefix = "+" + realRegionPrefix
            }
            numberText = cleanPrefix(String(text[realRegionPrefix.endIndex...]))
        } else {
            realRegionPrefix = text
            if !realRegionPrefix.hasPrefix("+") {
                realRegionPrefix = "+" + realRegionPrefix
            }
            numberText = ""
        }
        
        var focusOnNumber = false
        if realRegionPrefix != self.countryCodeField.textField.text {
            self.countryCodeField.textField.text = realRegionPrefix
        }
        if self.previousCountryCodeText != realRegionPrefix {
            self.previousCountryCodeText = realRegionPrefix
            let code = removePlus(realRegionPrefix).trimmingCharacters(in: CharacterSet.whitespaces)
            self.countryCodeUpdated?(code)
        }
        
        if numberText != self.numberField.textField.text {
            self.numberField.textField.text = numberText
        }
        
        if self.previousNumberText.isEmpty && !numberText.isEmpty {
            focusOnNumber = true
        }
        self.previousNumberText = numberText
        
        if focusOnNumber && !self.numberField.textField.isFirstResponder {
            self.numberField.textField.becomeFirstResponder()
        }
    }
}
