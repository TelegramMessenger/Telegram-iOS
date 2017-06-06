import Foundation

func addAttributesToStringWithRanges(_ stringWithRanges: (String, [(Int, NSRange)]), body: MarkdownAttributeSet, argumentAttributes: [Int: MarkdownAttributeSet], textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    let result = NSMutableAttributedString()
    
    var bodyAttributes: [String: Any] = [NSFontAttributeName: body.font, NSForegroundColorAttributeName: body.textColor, NSParagraphStyleAttributeName: paragraphStyleWithAlignment(textAlignment)]
    if !body.additionalAttributes.isEmpty {
        for (key, value) in body.additionalAttributes {
            bodyAttributes[key] = value
        }
    }
    
    result.append(NSAttributedString(string: stringWithRanges.0, attributes: bodyAttributes))
    
    for (index, range) in stringWithRanges.1 {
        if let attributes = argumentAttributes[index] {
            var argumentAttributes: [String: Any] = [NSFontAttributeName: attributes.font, NSForegroundColorAttributeName: attributes.textColor, NSParagraphStyleAttributeName: paragraphStyleWithAlignment(textAlignment)]
            if !attributes.additionalAttributes.isEmpty {
                for (key, value) in attributes.additionalAttributes {
                    argumentAttributes[key] = value
                }
            }
            result.addAttributes(argumentAttributes, range: range)
        }
    }
    
    return result
}
