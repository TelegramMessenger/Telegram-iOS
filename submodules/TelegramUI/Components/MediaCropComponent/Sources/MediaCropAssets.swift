import Foundation
import UIKit
import AppBundle

enum MediaCropAssets {
    static func image(named name: String) -> UIImage? {
        return UIImage(named: name, in: getAppBundle(), compatibleWith: nil)
    }

    static let cropFrame: UIImage = {
        let arm = mediaCropCornerHandleLength
        let thickness = mediaCropHandleThickness
        let side = arm * 2.0 + 1.0
        let size = CGSize(width: side, height: side)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.white.cgColor)
            let border = thickness - 1.0
            cgContext.fill(CGRect(x: border, y: border, width: side - border * 2.0, height: 1.0))
            cgContext.fill(CGRect(x: border, y: side - thickness, width: side - border * 2.0, height: 1.0))
            cgContext.fill(CGRect(x: border, y: border, width: 1.0, height: side - border * 2.0))
            cgContext.fill(CGRect(x: side - thickness, y: border, width: 1.0, height: side - border * 2.0))
            for (x, y) in [(0.0, 0.0), (side - arm, 0.0), (0.0, side - thickness), (side - arm, side - thickness)] {
                cgContext.fill(CGRect(x: x, y: y, width: arm, height: thickness))
            }
            for (x, y) in [(0.0, 0.0), (side - thickness, 0.0), (0.0, side - arm), (side - thickness, side - arm)] {
                cgContext.fill(CGRect(x: x, y: y, width: thickness, height: arm))
            }
        }
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: arm, left: arm, bottom: arm, right: arm), resizingMode: .stretch)
    }()

    static let transparentContents: CGImage? = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 1.0, height: 1.0), format: format).image { _ in }.cgImage
    }()
}
