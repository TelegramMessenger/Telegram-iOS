import Foundation
import Cocoa

extension NSValue {
    convenience init(cgRect: CGRect) {
        self.init(rect: NSRect(origin: cgRect.origin, size: cgRect.size))
    }
    
    convenience init(cgPoint: CGPoint) {
        self.init(point: NSPoint(x: cgPoint.x, y: cgPoint.y))
    }
}
