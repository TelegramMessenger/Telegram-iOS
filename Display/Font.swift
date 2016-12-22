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
            return UIFont.systemFont(ofSize: size, weight: UIFontWeightBold)
        } else {
            return CTFontCreateWithName("HelveticaNeue-Bold" as CFString, size, nil)
        }
    }
    
    public static func italic(_ size: CGFloat) -> UIFont {
        return UIFont.italicSystemFont(ofSize: size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: UIFont, textColor: UIColor = UIColor.black) {
        self.init(string: string, attributes: [NSFontAttributeName: font, NSForegroundColorAttributeName  as String: textColor])
    }
}
