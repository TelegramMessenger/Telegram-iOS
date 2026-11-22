import Foundation
import CoreGraphics

#if !os(macOS)
extension NSValue {
    var rectValue: CGRect {
        var rect = CGRect.zero
        self.getValue(&rect)
        return rect
    }
}
#endif
