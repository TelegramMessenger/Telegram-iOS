import Foundation
import Display

private let controlStartCharactersSet = CharacterSet(charactersIn: "[")
private let controlCharactersSet = CharacterSet(charactersIn: "[]()*_-\\")

final class MarkdownAttributeSet {
    let font: UIFont
    let textColor: UIColor
    
    init(font: UIFont, textColor: UIColor) {
        self.font = font
        self.textColor = textColor
    }
}

final class MarkdownAttributes {
    let body: MarkdownAttributeSet
    let link: MarkdownAttributeSet
    let linkAttribute: (String) -> (String, Any)?
    
    init(body: MarkdownAttributeSet, link: MarkdownAttributeSet, linkAttribute: @escaping (String) -> (String, Any)?) {
        self.body = body
        self.link = link
        self.linkAttribute = linkAttribute
    }
}

func escapedPlaintextForMarkdown(_ string: String) -> String {
    let nsString = string as NSString
    var remainingRange = NSMakeRange(0, nsString.length)
    let result = NSMutableString()
    while true {
        let range = nsString.rangeOfCharacter(from: controlCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            result.append("\\")
            result.append(nsString.substring(with: NSMakeRange(range.location, range.length)))
            remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
        } else {
            result.append(nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)))
            break
        }
    }
    return result as String
}

func parseMarkdownIntoAttributedString(_ string: String, attributes: MarkdownAttributes) -> NSAttributedString {
    let nsString = string as NSString
    let result = NSMutableAttributedString()
    var remainingRange = NSMakeRange(0, nsString.length)
    
    let bodyAttributes: [String: Any] = [NSFontAttributeName: attributes.body.font, NSForegroundColorAttributeName: attributes.body.textColor]
    
    while true {
        let range = nsString.rangeOfCharacter(from: controlStartCharactersSet, options: [], range: remainingRange)
        if range.location != NSNotFound {
            if range.location != remainingRange.location {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, range.location - remainingRange.location)), attributes: bodyAttributes))
                remainingRange = NSMakeRange(range.location, remainingRange.location + remainingRange.length - range.location)
            }
            
            let character = nsString.character(at: range.location)
            if character == UInt16(("[" as UnicodeScalar).value) {
                remainingRange = NSMakeRange(range.location + range.length, remainingRange.location + remainingRange.length - (range.location + range.length))
                if let (parsedLinkText, parsedLinkContents) = parseLink(string: nsString, remainingRange: &remainingRange) {
                    var linkAttributes: [String: Any] = [NSFontAttributeName: attributes.link.font, NSForegroundColorAttributeName: attributes.link.textColor]
                    if let (attributeName, attributeValue) = attributes.linkAttribute(parsedLinkContents) {
                        linkAttributes[attributeName] = attributeValue
                    }
                    result.append(NSAttributedString(string: parsedLinkText, attributes: linkAttributes))
                }
            }
        } else {
            if remainingRange.length != 0 {
                result.append(NSAttributedString(string: nsString.substring(with: NSMakeRange(remainingRange.location, remainingRange.length)), attributes: bodyAttributes))
            }
            break
        }
    }
    return result
}

private func parseLink(string: NSString, remainingRange: inout NSRange) -> (text: String, contents: String)? {
    var localRemainingRange = remainingRange
    let closingSquareBraceRange = string.range(of: "]", options: [], range: localRemainingRange)
    if closingSquareBraceRange.location != NSNotFound {
        localRemainingRange = NSMakeRange(closingSquareBraceRange.location + closingSquareBraceRange.length, remainingRange.location + remainingRange.length - (closingSquareBraceRange.location + closingSquareBraceRange.length))
        let openingRoundBraceRange = string.range(of: "(", options: [], range: localRemainingRange)
        let closingRoundBraceRange = string.range(of: ")", options: [], range: localRemainingRange)
        if openingRoundBraceRange.location == closingSquareBraceRange.location + closingSquareBraceRange.length && closingRoundBraceRange.location != NSNotFound && openingRoundBraceRange.location < closingRoundBraceRange.location {
            let linkText = string.substring(with: NSMakeRange(remainingRange.location, closingSquareBraceRange.location - remainingRange.location))
            let linkContents = string.substring(with: NSMakeRange(openingRoundBraceRange.location + openingRoundBraceRange.length, closingRoundBraceRange.location - (openingRoundBraceRange.location + openingRoundBraceRange.length)))
            remainingRange = NSMakeRange(closingRoundBraceRange.location + closingRoundBraceRange.length, remainingRange.location + remainingRange.length - (closingRoundBraceRange.location + closingRoundBraceRange.length))
            return (linkText, linkContents)
        }
    }
    return nil
}
