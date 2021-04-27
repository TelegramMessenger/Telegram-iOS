import Foundation
import UIKit
import Display
import AsyncDisplayKit

private func shiftArray(array: [CGPoint], offset: Int) -> [CGPoint] {
    var newArray = array
    var offset = offset
    while offset > 0 {
        let element = newArray.removeFirst()
        newArray.append(element)
        offset -= 1
    }
    return newArray
}

private func generateGradientComponent(size: CGSize, color: UIColor) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)

    let c = UIGraphicsGetCurrentContext()

    c?.clear(CGRect(origin: CGPoint.zero, size: size))

    c?.setBlendMode(.normal)

    var gradLocs: [CGFloat] = [0.0, 0.1, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let radius = min(size.width / 2.0, size.height / 2.0)

    let colors = [
        color.cgColor,
        color.cgColor,
        color.withAlphaComponent(0).cgColor
    ]

    let grad = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &gradLocs)
    if let grad = grad {
        let newPoint = CGPoint(x: size.width / 2.0, y: size.height / 2.0)

        c?.drawRadialGradient(grad, startCenter: newPoint, startRadius: 0, endCenter: newPoint, endRadius: radius, options: [])
    }

    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return image
}

public final class GradientBackgroundNode: ASDisplayNode {
    private var pointImages: [UIImageView] = []
    private let dimView: UIView

    private var phase: Int = 0

    private var validLayout: CGSize?

    override public init() {
        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor(white: 1.0, alpha: 0.0)

        super.init()

        self.phase = 0

        self.backgroundColor = .white
        self.clipsToBounds = true

        let colors: [UIColor] = [
            UIColor(rgb: 0x7FA381),
            UIColor(rgb: 0xFFF5C5),
            UIColor(rgb: 0x336F55),
            UIColor(rgb: 0xFBE37D)
        ]

        for i in 0 ..< colors.count {
            let pointImage = UIImageView(image: generateGradientComponent(size: CGSize(width: 300.0, height: 300.0), color: colors[i].withMultiplied(hue: 1.0, saturation: 1.1, brightness: 1.1)))
            //pointImage.layer.compositingFilter = "multiplyBlendMode"
            self.view.addSubview(pointImage)
            self.pointImages.append(pointImage)
        }

        self.view.addSubview(self.dimView)
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size

        self.dimView.frame = CGRect(origin: CGPoint(), size: size)

        let positions: [CGPoint]

        let basePositions: [CGPoint] = [
            CGPoint(x: 0.2, y: 0.2),
            CGPoint(x: 0.2, y: 0.8),
            CGPoint(x: 0.8, y: 0.8),
            CGPoint(x: 0.8, y: 0.2),
        ]

        switch self.phase % 4 {
        case 0:
            positions = basePositions
        case 1:
            positions = shiftArray(array: basePositions, offset: 1)
        case 2:
            positions = shiftArray(array: basePositions, offset: 2)
        case 3:
            positions = shiftArray(array: basePositions, offset: 3)
        default:
            preconditionFailure()
        }

        for i in 0 ..< positions.count {
            if self.pointImages.count <= i {
                break
            }
            let pointCenter = CGPoint(x: size.width * positions[i].x, y: size.height * positions[i].y)
            let pointSize = CGSize(width: size.width * 2.0, height: size.height * 2.0)
            transition.updateFrame(view: self.pointImages[i], frame: CGRect(origin: CGPoint(x: pointCenter.x - pointSize.width / 2.0, y: pointCenter.y - pointSize.height / 2.0), size: pointSize))
        }
    }

    public func animateEvent(transition: ContainedViewLayoutTransition) {
        self.phase = (self.phase + 1) % 4
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: transition)
        }
    }
}
