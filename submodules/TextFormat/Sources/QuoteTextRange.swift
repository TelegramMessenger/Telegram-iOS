import Foundation

/// The range of a reply quote in a message's text: the occurrence of `quoteText` nearest to `offset` (a UTF-16
/// offset into `string`), or the first occurrence when there is no offset.
public func findQuoteRange(string: String, quoteText: String, offset: Int?) -> NSRange? {
    let nsString = string as NSString
    var currentRange: NSRange?
    while true {
        let startOffset = currentRange?.upperBound ?? 0
        let range = nsString.range(of: quoteText, range: NSRange(location: startOffset, length: nsString.length - startOffset))
        if range.location != NSNotFound {
            if let offset {
                if let currentRangeValue = currentRange {
                    if abs(range.location - offset) > abs(currentRangeValue.location - offset) {
                        break
                    } else {
                        currentRange = range
                    }
                } else {
                    currentRange = range
                }
            } else {
                currentRange = range
                break
            }
        } else {
            break
        }
    }
    return currentRange
}

/// The range of a reply quote in a message's text as a text node lays it out, for that layout's rects.
///
/// A text node lays each custom emoji out as a placeholder character carrying the emoji's own text in
/// `originalTextAttributeKey`, while a quote's text and offset are those of the message text, custom emoji included as
/// their emoji characters. The quote is therefore looked for in the original text and its range mapped back onto
/// `layoutString`; a quote boundary falling inside an emoji's text takes in the whole placeholder.
public func findQuoteRange(layoutString: NSAttributedString, quoteText: String, offset: Int?) -> NSRange? {
    // Each placeholder: its range in `layoutString`, and the range of the text it stands for in the original text.
    var replacements: [(layoutRange: NSRange, originalRange: NSRange)] = []
    let originalString = NSMutableString()
    let layoutNSString = layoutString.string as NSString
    layoutString.enumerateAttribute(originalTextAttributeKey, in: NSRange(location: 0, length: layoutString.length), options: [], using: { value, range, _ in
        if let value = value as? OriginalTextAttribute {
            let originalText = value.string as NSString
            replacements.append((layoutRange: range, originalRange: NSRange(location: originalString.length, length: originalText.length)))
            originalString.append(value.string)
        } else {
            originalString.append(layoutNSString.substring(with: range))
        }
    })
    if replacements.isEmpty {
        return findQuoteRange(string: layoutString.string, quoteText: quoteText, offset: offset)
    }
    guard let originalRange = findQuoteRange(string: originalString as String, quoteText: quoteText, offset: offset) else {
        return nil
    }

    func layoutPosition(originalPosition: Int, isUpperBound: Bool) -> Int {
        var delta = 0
        for replacement in replacements {
            if originalPosition >= replacement.originalRange.upperBound {
                delta += replacement.layoutRange.length - replacement.originalRange.length
            } else if originalPosition > replacement.originalRange.location {
                return isUpperBound ? replacement.layoutRange.upperBound : replacement.layoutRange.location
            } else {
                break
            }
        }
        return originalPosition + delta
    }

    let lowerBound = layoutPosition(originalPosition: originalRange.location, isUpperBound: false)
    let upperBound = layoutPosition(originalPosition: originalRange.upperBound, isUpperBound: true)
    return NSRange(location: lowerBound, length: max(0, upperBound - lowerBound))
}
