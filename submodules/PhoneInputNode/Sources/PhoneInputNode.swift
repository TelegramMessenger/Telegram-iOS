import Foundation
import UIKit
import AsyncDisplayKit
import Display
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

public final class PhoneInputNode: ASDisplayNode, UITextFieldDelegate {
    public let countryCodeField: TextFieldNode
    public let numberField: TextFieldNode
    
    public var previousCountryCodeText = "+"
    public var previousNumberText = ""
    public var enableEditing: Bool = true
    
    public var number: String {
        get {
            return cleanPhoneNumber((self.countryCodeField.textField.text ?? "") + (self.numberField.textField.text ?? ""))
        } set(value) {
            self.updateNumber(value)
        }
    }
    
    public var countryCodeText: String {
        get {
            return self.countryCodeField.textField.text ?? ""
        } set(value) {
            if self.countryCodeField.textField.text != value {
                self.countryCodeField.textField.text = value
                self.countryCodeTextChanged(self.countryCodeField.textField)
            }
        }
    }
    
    public var numberText: String {
        get {
            return self.numberField.textField.text ?? ""
        } set(value) {
            if self.numberField.textField.text != value {
                self.numberField.textField.text = value
                self.numberTextChanged(self.numberField.textField)
            }
        }
    }
    
    private var countryNameForCode: (Int32, String)?
    
    public var codeAndNumber: (Int32?, String?, String) {
        get {
            var code: Int32?
            if let text = self.countryCodeField.textField.text, text.count <= 4, let number = Int(removePlus(text)) {
                code = Int32(number)
                var countryName: String?
                if self.countryNameForCode?.0 == code {
                    countryName = self.countryNameForCode?.1
                }
                return (code, countryName, cleanPhoneNumber(self.numberField.textField.text))
            } else if let text = self.countryCodeField.textField.text {
                return (nil, nil, cleanPhoneNumber(text + (self.numberField.textField.text ?? "")))
            } else {
                return (nil, nil, "")
            }
        } set(value) {
            let updatedCountryName = self.countryNameForCode?.0 != value.0 || self.countryNameForCode?.1 != value.1
            if let code = value.0, let name = value.1 {
                self.countryNameForCode = (code, name)
            } else {
                self.countryNameForCode = nil
            }
            self.updateNumber("+" + (value.0 == nil ? "" : "\(value.0!)") + value.2, forceNotifyCountryCodeUpdated: updatedCountryName)
        }
    }
    
    public var countryCodeUpdated: ((String, String?) -> Void)?
    
    public var countryCodeTextUpdated: ((String) -> Void)?
    public var numberTextUpdated: ((String) -> Void)?
    
    public var returnAction: (() -> Void)?
    
    private let phoneFormatter = InteractivePhoneFormatter()
    
    private let fontSize: CGFloat
    
    public init(fontSize: CGFloat = 20.0) {
        self.fontSize = fontSize
        
        self.countryCodeField = TextFieldNode()
        self.countryCodeField.textField.font = Font.regular(fontSize)
        self.countryCodeField.textField.textAlignment = .center
        self.countryCodeField.textField.returnKeyType = .next
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.countryCodeField.textField.keyboardType = .asciiCapableNumberPad
            self.countryCodeField.textField.textContentType = .telephoneNumber
        } else {
            self.countryCodeField.textField.keyboardType = .numberPad
        }
        
        self.numberField = TextFieldNode()
        self.numberField.textField.font = Font.regular(fontSize)
        if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
            self.numberField.textField.keyboardType = .asciiCapableNumberPad
            self.numberField.textField.textContentType = .telephoneNumber
        } else {
            self.numberField.textField.keyboardType = .numberPad
        }
        
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
    
    @objc private func countryCodeTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    @objc private func numberTextChanged(_ textField: UITextField) {
        self.updateNumberFromTextFields()
    }
    
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if !self.enableEditing {
            return false
        }
        if range.length == 0, string.count > 1 {
            self.updateNumber(cleanPhoneNumber(string), tryRestoringInputPosition: false)
            return false
        }
        return true
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == self.numberField.textField {
            self.returnAction?()
        }
        return false
    }
    
    private func updateNumberFromTextFields() {
        let inputText = removeDuplicatedPlus(cleanPhoneNumber(self.countryCodeField.textField.text) + cleanPhoneNumber(self.numberField.textField.text))
        self.updateNumber(inputText)
    }
    
    private func updateNumber(_ inputText: String, tryRestoringInputPosition: Bool = true, forceNotifyCountryCodeUpdated: Bool = false) {
        let (regionPrefix, text) = self.phoneFormatter.updateText(inputText)
        var realRegionPrefix: String
        let numberText: String
        if let regionPrefix = regionPrefix, !regionPrefix.isEmpty, regionPrefix != "+" {
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
        if self.previousCountryCodeText != realRegionPrefix || forceNotifyCountryCodeUpdated {
            self.previousCountryCodeText = realRegionPrefix
            let code = removePlus(realRegionPrefix).trimmingCharacters(in: .whitespaces)
            var countryName: String?
            if self.countryNameForCode?.0 == Int32(code) {
                countryName = self.countryNameForCode?.1
            }
            self.countryCodeUpdated?(code, countryName)
        }
        self.countryCodeTextUpdated?(realRegionPrefix)
        
        if numberText != self.numberField.textField.text {
            var restorePosition: Int?
            if let text = self.numberField.textField.text, let selectedTextRange = self.numberField.textField.selectedTextRange {
                let initialOffset = self.numberField.textField.offset(from: self.numberField.textField.beginningOfDocument, to: selectedTextRange.start)
                var significantIndex = 0
                for i in 0 ..< min(initialOffset, text.count) {
                    let unicodeScalars = String(text[text.index(text.startIndex, offsetBy: i)]).unicodeScalars
                    if unicodeScalars.count == 1 && CharacterSet.decimalDigits.contains(unicodeScalars[unicodeScalars.startIndex]) {
                        significantIndex += 1
                    }
                }
                var restoreIndex = 0
                for i in 0 ..< numberText.count {
                    if significantIndex <= 0 {
                        break
                    }
                    let unicodeScalars = String(numberText[numberText.index(numberText.startIndex, offsetBy: i)]).unicodeScalars
                    if unicodeScalars.count == 1 && CharacterSet.decimalDigits.contains(unicodeScalars[unicodeScalars.startIndex]) {
                        significantIndex -= 1
                    }
                    restoreIndex += 1
                }
                restorePosition = restoreIndex
            }
            self.numberField.textField.text = numberText
            if tryRestoringInputPosition, let restorePosition = restorePosition {
                if let startPosition = self.numberField.textField.position(from: self.numberField.textField.beginningOfDocument, offset: restorePosition) {
                    let selectionRange = self.numberField.textField.textRange(from: startPosition, to: startPosition)
                    self.numberField.textField.selectedTextRange = selectionRange
                }
            }
        }
        self.numberTextUpdated?(numberText)
        
        if self.previousNumberText.isEmpty && !numberText.isEmpty {
            focusOnNumber = true
        }
        self.previousNumberText = numberText
        
        if focusOnNumber && !self.numberField.textField.isFirstResponder {
            self.numberField.textField.becomeFirstResponder()
        }
    }
}
