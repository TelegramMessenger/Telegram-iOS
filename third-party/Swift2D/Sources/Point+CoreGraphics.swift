#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

public extension Point {
    /// Initialize a `Point` using the provided `CGPoint` values.
    init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }
}

public extension CGPoint {
    /// Initialize a `CPPoint` using the provided `Point` values.
    init(_ point: Point) {
        self.init(x: point.x, y: point.y)
    }
}
