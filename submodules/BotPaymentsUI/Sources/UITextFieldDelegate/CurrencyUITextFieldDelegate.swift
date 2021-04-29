//
//  CurrencyUITextFieldDelegate.swift
//  CurrencyText
//
//  Created by Felipe Lefèvre Marino on 12/26/18.
//  Copyright © 2018 Felipe Lefèvre Marino. All rights reserved.
//

import UIKit

/// Custom text field delegate, that formats user inputs based on a given currency formatter.
public class CurrencyUITextFieldDelegate: NSObject {

    public var formatter: (CurrencyFormatting & CurrencyAdjusting)!

    public var textUpdated: (() -> Void)?

    /// Text field clears its text when value value is equal to zero.
    public var clearsWhenValueIsZero: Bool = false

    /// A delegate object to receive and potentially handle `UITextFieldDelegate events` that are sent to `CurrencyUITextFieldDelegate`.
    ///
    /// Note: Make sure the implementation of this object does not wrongly interfere with currency formatting.
    ///
    /// By returning `false` on`textField(textField:shouldChangeCharactersIn:replacementString:)` no currency formatting is done.
    public var passthroughDelegate: UITextFieldDelegate? {
        get { return _passthroughDelegate }
        set {
            guard newValue !== self else { return }
            _passthroughDelegate = newValue
        }
    }
    weak private(set) var _passthroughDelegate: UITextFieldDelegate?
    
    public init(formatter: CurrencyFormatter) {
        self.formatter = formatter
    }
}

// MARK: - UITextFieldDelegate

extension CurrencyUITextFieldDelegate: UITextFieldDelegate {
    
    @discardableResult
    open func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        return passthroughDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }
    
    public func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.setInitialSelectedTextRange()
        passthroughDelegate?.textFieldDidBeginEditing?(textField)
    }
    
    @discardableResult
    public func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        if let text = textField.text, text.representsZero && clearsWhenValueIsZero {
            textField.text = ""
        }
        else if let text = textField.text, let updated = formatter.formattedStringAdjustedToFitAllowedValues(from: text), updated != text {
            textField.text = updated
        }
        return passthroughDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }
    
    open func textFieldDidEndEditing(_ textField: UITextField) {
        passthroughDelegate?.textFieldDidEndEditing?(textField)
    }
    
    @discardableResult
    open func textFieldShouldClear(_ textField: UITextField) -> Bool {
        return passthroughDelegate?.textFieldShouldClear?(textField) ?? true
    }
    
    @discardableResult
    open func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        return passthroughDelegate?.textFieldShouldReturn?(textField) ?? true
    }
    
    @discardableResult
    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let shouldChangeCharactersInRange = passthroughDelegate?.textField?(textField,
                                                                            shouldChangeCharactersIn: range,
                                                                            replacementString: string) ?? true
        guard shouldChangeCharactersInRange else {
            return false
        }

        // Store selected text range offset from end, before updating and reformatting the currency string.
        let lastSelectedTextRangeOffsetFromEnd = textField.selectedTextRangeOffsetFromEnd

        // Before leaving the scope, update selected text range,
        // respecting previous selected text range offset from end.
        defer {
            textField.updateSelectedTextRange(lastOffsetFromEnd: lastSelectedTextRangeOffsetFromEnd)
            textUpdated?()
        }
        
        guard !string.isEmpty else {
            handleDeletion(in: textField, at: range)
            return false
        }
        guard string.hasNumbers else {
            addNegativeSymbolIfNeeded(in: textField, at: range, replacementString: string)
            return false
        }
        
        setFormattedText(in: textField, inputString: string, range: range)
        
        return false
    }

    public func textFieldDidChangeSelection(_ textField: UITextField) {
        if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
            passthroughDelegate?.textFieldDidChangeSelection?(textField)
        }
    }
}

// MARK: - Private

extension CurrencyUITextFieldDelegate {

    /// Verifies if user inputed a negative symbol at the first lowest
    /// bound of the text field and add it.
    ///
    /// - Parameters:
    ///   - textField: text field that user interacted with
    ///   - range: user input range
    ///   - string: user input string
    private func addNegativeSymbolIfNeeded(in textField: UITextField, at range: NSRange, replacementString string: String) {
        guard textField.keyboardType == .numbersAndPunctuation else { return }
        
        if string == .negativeSymbol && textField.text?.isEmpty == true {
            textField.text = .negativeSymbol
        } else if range.lowerBound == 0 && string == .negativeSymbol &&
            textField.text?.contains(String.negativeSymbol) == false {
            
            textField.text = .negativeSymbol + (textField.text ?? "")
        }
    }
    
    /// Correctly delete characters when user taps remove key.
    ///
    /// - Parameters:
    ///   - textField: text field that user interacted with
    ///   - range: range to be removed
    private func handleDeletion(in textField: UITextField, at range: NSRange) {
        if var text = textField.text {
            if let textRange = Range(range, in: text) {
                text.removeSubrange(textRange)
            } else {
                text.removeLast()
            }
            
            if text.isEmpty {
                textField.text = text
            } else {
                textField.text = formatter.formattedStringWithAdjustedDecimalSeparator(from: text)
            }
        }
    }
    
    /// Formats text field's text with new input string and changed range
    ///
    /// - Parameters:
    ///   - textField: text field that user interacted with
    ///   - inputString: typed string
    ///   - range: range where the string should be added
    private func setFormattedText(in textField: UITextField, inputString: String, range: NSRange) {
        var updatedText = ""
        
        if let text = textField.text {
            if text.isEmpty {
                updatedText = formatter.initialText + inputString
            } else if let range = Range(range, in: text) {
                updatedText = text.replacingCharacters(in: range, with: inputString)
            } else {
                updatedText = text.appending(inputString)
            }
        }
        
        if updatedText.numeralFormat().count > formatter.maxDigitsCount {
            updatedText.removeLast()
        }
        
        textField.text = formatter.formattedStringWithAdjustedDecimalSeparator(from: updatedText)
    }
}
