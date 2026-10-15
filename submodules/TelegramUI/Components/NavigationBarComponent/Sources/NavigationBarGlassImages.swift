import Foundation
import UIKit
import Display
import AppBundle

public let glassBackArrowImage: UIImage? = {
    let imageSize = CGSize(width: 44.0, height: 44.0)
    let topRightPoint = CGPoint(x: 24.6, y: 14.0)
    let centerPoint = CGPoint(x: 17.0, y: imageSize.height * 0.5)
    return generateImage(imageSize, rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: topRightPoint)
        context.addLine(to: centerPoint)
        context.addLine(to: CGPoint(x: topRightPoint.x, y: size.height - topRightPoint.y))
        context.strokePath()
    })?.withRenderingMode(.alwaysTemplate)
}()

public let glassCloseImage: UIImage? = {
    return generateTintedImage(image: UIImage(bundleImageName: "Navigation/Close"), color: .white)?.withRenderingMode(.alwaysTemplate)
}()
