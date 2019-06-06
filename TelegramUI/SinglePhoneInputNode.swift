import Foundation
import UIKit
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

final class SinglePhoneInputNode: ASDisplayNode, UITextFieldDelegate {
    private let fontSize: CGFloat
    
    var numberField: TextFieldNode?
    var numberFieldText: String?
    
    var enableEditing: Bool = true
    
    var number: String {
        get {
            return cleanPhoneNumber(self.numberField?.textField.text ?? "")
        } set(value) {
            self.updateNumber(value)
        }
    }
    var numberUpdated: ((String) -> Void)?
    
    private let phoneFormatter = InteractivePhoneFormatter()
    
    private var validLayout: CGSize?
    
    init(fontSize: CGFloat = 20.0) {
        self.fontSize = fontSize
        
        super.init()
    }
    
    override func didLoad() {
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
    
    @objc func numberTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return self.enableEditing
    }
    
    private func updateNumberFromTextFields() {
        guard let numberField = self.numberField else {
            return
        }
        let inputText = removeDuplicatedPlus(cleanPhoneNumber(cleanPhoneNumber(numberField.textField.text)))
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
    
    func updateLayout(size: CGSize) {
        self.validLayout = size
        self.numberField?.frame = CGRect(origin: CGPoint(), size: size)
    }
}
