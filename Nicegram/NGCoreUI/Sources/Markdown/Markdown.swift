import Foundation
import Markdown
import UIKit

public func parseMarkdownIntoAttributedString(_ string: String, attributes: MarkdownAttributes, textAlignment: NSTextAlignment = .natural) -> NSAttributedString {
    return Markdown.parseMarkdownIntoAttributedString(string, attributes: attributes, textAlignment: textAlignment)
}
