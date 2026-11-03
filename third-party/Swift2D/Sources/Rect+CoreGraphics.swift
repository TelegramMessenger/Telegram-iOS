#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

public extension Rect {
    /// Initialize a `Rect` using the provided `CGRect` values.
    init(_ rect: CGRect) {
        self.init(
            origin: Point(rect.origin),
            size: Size(rect.size)
        )
    }

    @available(*, deprecated, renamed: "CGRect(_:)", message: "Use CGRect initializer directly")
    var cgRect: CGRect {
        CGRect(self)
    }
}

public extension CGRect {
    /// Initialize a `CGRect` using the provided `Rect` values.
    init(_ rect: Rect) {
        self.init(
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height
        )
    }
}
