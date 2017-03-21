import Foundation
import UIKit

public struct Font {
    public static func regular(_ size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        if #available(iOS 8.2, *) {
            return UIFont.systemFont(ofSize: size, weight: UIFontWeightMedium)
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
            return UIFont.systemFont(ofSize: size, weight: UIFontWeightLight)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Light" as CFString, size, nil)
        }
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont? = nil, textColor: UIColor = UIColor.black, paragraphAlignment: NSTextAlignment? = nil) {
        var attributes: [String: AnyObject] = [:]
        if let font = font {
            attributes[NSFontAttributeName] = font
        }
        attributes[NSForegroundColorAttributeName] = textColor
        if let paragraphAlignment = paragraphAlignment {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = paragraphAlignment
            attributes[NSParagraphStyleAttributeName] = paragraphStyle
        }
        self.init(string: string, attributes: attributes)
    }
}
