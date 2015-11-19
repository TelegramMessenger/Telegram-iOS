import Foundation
import UIKit

public struct Font {
    public static func regular(size: CGFloat) -> UIFont {
        return UIFont.systemFontOfSize(size)
    }
    
    public static func medium(size: CGFloat) -> UIFont {
        return UIFont.boldSystemFontOfSize(size)
    }
}

public extension NSAttributedString {
    convenience init(string: String, font: CTFontRef, textColor: UIColor = UIColor.blackColor()) {
        self.init(string: string, attributes: [kCTFontAttributeName as String: font, kCTForegroundColorAttributeName as String: textColor.CGColor])
    }
}
