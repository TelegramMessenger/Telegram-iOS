import Foundation
import UIKit
import TextFormat

public extension UIColor {
    var hexString: String {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        self.getRed(&red, green: &green, blue: &blue, alpha: nil)
        
        let rgb: UInt32 = (UInt32(red * 255.0) << 16) | (UInt32(green * 255.0) << 8) | (UInt32(blue * 255.0))
        
        return String(rgb, radix: 16, uppercase: false).rightJustified(width: 6, pad: "0")
    }
}
