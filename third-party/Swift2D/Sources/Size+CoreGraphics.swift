#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

public extension Size {
    /// Initialize a `Size` using the provided `CGSize` values.
    init(_ size: CGSize) {
        self.init(width: size.width, height: size.height)
    }
}

public extension CGSize {
    /// Initialize a `CGSize` using the provided `Size` values.
    init(_ size: Size) {
        self.init(width: size.width, height: size.height)
    }
}
