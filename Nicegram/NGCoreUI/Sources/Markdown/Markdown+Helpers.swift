import Markdown
import UIKit

public extension MarkdownAttributes {
    func withBold(_ bold: MarkdownAttributeSet) -> MarkdownAttributes {
        return MarkdownAttributes(body: self.body, bold: bold, link: self.link, linkAttribute: self.linkAttribute)
    }
    
    func withLink(_ link: MarkdownAttributeSet) -> MarkdownAttributes {
        return MarkdownAttributes(body: self.body, bold: self.bold, link: link, linkAttribute: self.linkAttribute)
    }
    
    func withBold(font: UIFont? = nil, textColor: UIColor? = nil) -> MarkdownAttributes {
        let bold = MarkdownAttributeSet(
            font: font ?? self.body.font,
            textColor: textColor ?? self.body.textColor
        )
        return withBold(bold)
    }
    
    func withLink(font: UIFont? = nil, textColor: UIColor? = nil, additionalAttributes: [NSAttributedString.Key: Any]? = nil) -> MarkdownAttributes {
        let link = MarkdownAttributeSet(
            font: font ?? self.body.font,
            textColor: textColor ?? self.body.textColor,
            additionalAttributes: mapAdditionalAttributes(additionalAttributes) ?? self.body.additionalAttributes
        )
        return withLink(link)
    }
    
    func withLinkDetector(_ detector: @escaping (String) -> URL?) -> MarkdownAttributes {
        return MarkdownAttributes(body: self.body, bold: self.bold, link: self.link) { content in
            let url: URL?
            if let _url = detector(content) {
                url = _url
            } else {
                url = URL(string: content)
            }
        
            if let url {
                return (NSAttributedString.Key.link.rawValue, url)
            } else {
                return nil
            }
        }
    }
}

public extension MarkdownAttributes {
    static func plain(font: UIFont, textColor: UIColor, additionalAttributes: [NSAttributedString.Key: Any]? = nil) -> MarkdownAttributes {
        let set = MarkdownAttributeSet(
            font: font,
            textColor: textColor,
            additionalAttributes: mapAdditionalAttributes(additionalAttributes) ?? [:]
        )
        return MarkdownAttributes(body: set, bold: set, link: set, linkAttribute: { _ in return nil })
            .withLinkDetector { _ in return nil }
    }
}

private func mapAdditionalAttributes(_ additionalAttributes: [NSAttributedString.Key: Any]?) -> [String: Any]? {
    if let additionalAttributes {
        var attributes: [String: Any] = [:]
        additionalAttributes.forEach { key, value in
            attributes[key.rawValue] = value
        }
        return attributes
    } else {
        return nil
    }
    
}
