import Foundation
import UIKit
import LegacyImpl

public func drawSvgImage(data: Data, size: CGSize, backgroundColor: UIColor?, foregroundColor: UIColor?, scale: CGFloat, opaque: Bool) -> UIImage? {
    return drawSvgImageImpl(data, size, backgroundColor, foregroundColor, scale, opaque)
}
