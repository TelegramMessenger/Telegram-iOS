import Foundation
import UIKit

public struct Font {
    public static func regular(_ size: CGFloat) -> UIFont {
        return UIFont.systemFont(ofSize: size)
    }
    
    public static func medium(_ size: CGFloat) -> UIFont {
        return UIFont.boldSystemFont(ofSize: size)
    }
}

public extension AttributedString {
    convenience init(string: String, font: UIFont, textColor: UIColor = UIColor.black()) {
        self.init(string: string, attributes: [kCTFontAttributeName as String: font, kCTForegroundColorAttributeName as String: textColor])
    }
}
