//
//  UITextField.swift
//  CurrencyText
//
//  Created by Felipe Lefèvre Marino on 12/26/18.
//

import UIKit

public extension UITextField {

    // MARK: Public

    var selectedTextRangeOffsetFromEnd: Int {
        return offset(from: endOfDocument, to: selectedTextRange?.end ?? endOfDocument)
    }

    /// Sets the selected text range when the text field is starting to be edited.
    /// _Should_ be called when text field start to be the first responder.
    func setInitialSelectedTextRange() {
        // update selected text range if needed
        adjustSelectedTextRange(lastOffsetFromEnd: 0) // at the end when first selected
    }

    /// Interface to update the selected text range as expected.
    /// - Parameter lastOffsetFromEnd: The last stored selected text range offset from end. Used to keep it concise with pre-formatting.
    func updateSelectedTextRange(lastOffsetFromEnd: Int) {
        adjustSelectedTextRange(lastOffsetFromEnd: lastOffsetFromEnd)
    }

    // MARK: Private

    /// Adjust the selected text range to match the best position.
    private func adjustSelectedTextRange(lastOffsetFromEnd: Int) {
        /// If text is empty the offset is set to zero, the selected text range does need to be changed.
        if let text = text, text.isEmpty {
            return
        }

        var offsetFromEnd = lastOffsetFromEnd

        /// Adjust offset if needed. When the last number character offset from end is less than the current offset,
        /// or in other words, is more distant to the end of the string, the offset is readjusted to it,
        /// so the selected text range is correctly set to the last index with a number.
        if let lastNumberOffsetFromEnd = text?.lastNumberOffsetFromEnd,
            case let shouldOffsetBeAdjusted = lastNumberOffsetFromEnd < offsetFromEnd,
            shouldOffsetBeAdjusted {

            offsetFromEnd = lastNumberOffsetFromEnd
        }

        updateSelectedTextRange(offsetFromEnd: offsetFromEnd)
    }

    /// Update the selected text range with given offset from end.
    private func updateSelectedTextRange(offsetFromEnd: Int) {
        if let updatedCursorPosition = position(from: endOfDocument, offset: offsetFromEnd) {
            selectedTextRange = textRange(from: updatedCursorPosition, to: updatedCursorPosition)
        }
    }
}
