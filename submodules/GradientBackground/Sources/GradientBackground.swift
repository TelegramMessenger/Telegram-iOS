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
    private final class PointImage {
        let stack: [UIImageView]

        init(image: UIImage, count: Int) {
            self.stack = (0 ..< count).map { _ in
                let imageView = UIImageView(image: image)
                imageView.alpha = min(1.0, (1.0 / CGFloat(count)) * 1.2)
                return imageView
            }
        }

        func updateFrame(frame: CGRect, transition: ContainedViewLayoutTransition) {
            for imageView in stack {
                transition.updateFrame(view: imageView, frame: frame)
            }
        }
    }
    private var pointImages: [PointImage] = []
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

        let layerCount = 2

        for i in 0 ..< colors.count {
            let image = generateGradientComponent(size: CGSize(width: 300.0, height: 300.0), color: colors[i].withMultiplied(hue: 1.0, saturation: 1.1, brightness: 1.0))!

            let pointImage = PointImage(image: image, count: layerCount)

            self.pointImages.append(pointImage)
        }

        for i in 0 ..< layerCount {
            for pointImage in self.pointImages {
                self.view.addSubview(pointImage.stack[i])
            }
        }

        self.view.addSubview(self.dimView)
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size

        self.dimView.frame = CGRect(origin: CGPoint(), size: size)

        let positions: [CGPoint]

        let basePositions: [CGPoint] = [
            CGPoint(x: 0.80, y: 0.10),
            CGPoint(x: 0.60, y: 0.20),
            CGPoint(x: 0.35, y: 0.25),
            CGPoint(x: 0.25, y: 0.60),
            CGPoint(x: 0.20, y: 0.90),
            CGPoint(x: 0.40, y: 0.80),
            CGPoint(x: 0.65, y: 0.75),
            CGPoint(x: 0.75, y: 0.40)
        ]/*.map { point -> CGPoint in
            var point = point
            if point.x < 0.5 {
                point.x *= 0.5
            } else {
                point.x = 1.0 - (1.0 - point.x) * 0.5
            }
            if point.y < 0.5 {
                point.y *= 0.5
            } else {
                point.y = 1.0 - (1.0 - point.x) * 0.5
            }
            return point
        }*/

        positions = shiftArray(array: basePositions, offset: self.phase % 8)

        for i in 0 ..< positions.count / 2 {
            if self.pointImages.count <= i {
                break
            }
            let position = positions[i * 2]
            let pointCenter = CGPoint(x: size.width * position.x, y: size.height * position.y)
            let pointSize = CGSize(width: size.width * 1.8, height: size.height * 1.5)
            self.pointImages[i].updateFrame(frame: CGRect(origin: CGPoint(x: pointCenter.x - pointSize.width / 2.0, y: pointCenter.y - pointSize.height / 2.0), size: pointSize), transition: transition)
        }
    }

    public func animateEvent(transition: ContainedViewLayoutTransition) {
        self.phase = self.phase + 1
        if let size = self.validLayout {
            self.updateLayout(size: size, transition: transition)
        }
    }
}
