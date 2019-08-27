import Foundation
import UIKit

public struct Font {
    public static func regular(_ size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.medium)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, size, nil)
        }
    }
    
    public static func semibold(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.semibold)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, size, nil)
        }
    }
    
    public static func bold(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.boldSystemFont(ofSize: size)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        }
    }
    
    public static func light(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.light)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Light" as CFString, size, nil)
        }
    }
    
    public static func semiboldItalic(_ size: CGFloat) -> UIFont {
        if let descriptor = UIFont.systemFont(ofSize: size).fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            return UIFont(descriptor: descriptor, size: size)
        } else {
            return UIFont.italicSystemFont(ofSize: size)
        }
    }
    
    public static func monospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Regular", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Bold", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-Italic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func semiboldItalicMonospace(_ size: CGFloat) -> UIFont {
        return UIFont(name: "Menlo-BoldItalic", size: size - 1.0) ?? UIFont.systemFont(ofSize: size)
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont? = nil, textColor: UIColor = UIColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [NSAttributedString.Key: AnyObject] = [:]
        if let font = font {
            attributes[NSAttributedString.Key.font] = font
        }
        attributes[NSAttributedString.Key.foregroundColor] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[NSAttributedString.Key.paragraphStyle] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }
}
