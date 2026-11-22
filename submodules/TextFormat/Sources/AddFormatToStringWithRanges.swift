import Foundation
import UIKit
import Markdown

public func addAttributesToStringWithRanges(_ stringWithRanges: (String, [(Int, NSRange)]), body: MarkdownAttributeSet, argumentAttributes: [Int: MarkdownAttributeSet], textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    let result = NSMutableAttributedString()
    
    var bodyAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: body.font, NSAttributedString.Key.foregroundColor: body.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
    if !body.additionalAttributes.isEmpty {
        for (key, value) in body.additionalAttributes {
            bodyAttributes[NSAttributedString.Key(rawValue: key)] = value
        }
    }
    
    result.append(NSAttributedString(string: stringWithRanges.0, attributes: bodyAttributes))
    
    for (index, range) in stringWithRanges.1 {
        if let attributes = argumentAttributes[index] {
            var argumentAttributes: [NSAttributedString.Key: Any] = [NSAttributedString.Key.font: attributes.font, NSAttributedString.Key.foregroundColor: attributes.textColor, NSAttributedString.Key.paragraphStyle: paragraphStyleWithAlignment(textAlignment)]
            if !attributes.additionalAttributes.isEmpty {
                for (key, value) in attributes.additionalAttributes {
                    argumentAttributes[NSAttributedString.Key(rawValue: key)] = value
                }
            }
            result.addAttributes(argumentAttributes, range: range)
        }
    }
    
    return result
}
