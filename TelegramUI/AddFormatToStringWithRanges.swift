import Foundation
import UIKit

func addAttributesToStringWithRanges(_ stringWithRanges: (String, [(Int, NSRange)]), body: MarkdownAttributeSet, argumentAttributes: [Int: MarkdownAttributeSet], textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    let result = NSMutableAttributedString()
    
    var bodyAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: body.font, NSAttributedStringKey.foregroundColor: body.textColor, NSAttributedStringKey.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
    if !body.additionalAttributes.isEmpty {
        for (key, value) in body.additionalAttributes {
            bodyAttributes[NSAttributedStringKey(rawValue: key)] = value
        }
    }
    
    result.append(NSAttributedString(string: stringWithRanges.0, attributes: bodyAttributes))
    
    for (index, range) in stringWithRanges.1 {
        if let attributes = argumentAttributes[index] {
            var argumentAttributes: [NSAttributedStringKey: Any] = [NSAttributedStringKey.font: attributes.font, NSAttributedStringKey.foregroundColor: attributes.textColor, NSAttributedStringKey.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
            if !attributes.additionalAttributes.isEmpty {
                for (key, value) in attributes.additionalAttributes {
                    argumentAttributes[NSAttributedStringKey(rawValue: key)] = value
                }
            }
            result.addAttributes(argumentAttributes, range: range)
        }
    }
    
    return result
}
