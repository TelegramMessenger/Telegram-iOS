#if os(iOS)
import UIKit
#endif

public struct PixelDimensions: Equatable {
    public let width: Int32
    public let height: Int32
    
    public init(width: Int32, height: Int32) {
        self.width = width
        self.height = height
    }
}

#if os(iOS)

public extension PixelDimensions {
    init(_ size: CGSize) {
        self.init(width: Int32(size.width), height: Int32(size.height))
    }
    
    var cgSize: CGSize {
		return CGSize(width: CGFloat(self.width), height: CGFloat(self.height))
	}
}

#endif
