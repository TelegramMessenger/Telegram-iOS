import Foundation
import UIKit

public struct Font {
    public static func regular(size: CGFloat) -> UIFont {
        if matchMinimumSystemVersion(9) {
            return UIFont(name: ".SFUIDisplay-Regular", size: size)!
        } else {
            return UIFont(name: "HelveticaNeue", size: size)!
        }
    }
    
    public static func medium(size: CGFloat) -> UIFont {
        if matchMinimumSystemVersion(9) {
            return UIFont(name: ".SFUIDisplay-Medium", size: size)!
        } else {
            return UIFont(name: "HelveticaNeue-Medium", size: size)!
        }
    }
}
