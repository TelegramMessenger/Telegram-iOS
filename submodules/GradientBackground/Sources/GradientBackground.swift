import Foundation
import UIKit
import Display
import AsyncDisplayKit

private struct GradientPoint {
    var color: UIColor
    var position: CGPoint
}

private func applyTransformerToPoints(step: Int, substep: Int) -> [GradientPoint] {
    var points: [GradientPoint] = []

    var firstSet: [CGPoint]
    var secondSet: [CGPoint]

    let colors: [UIColor] = [
        UIColor(rgb: 0x7FA381),
        UIColor(rgb: 0xFFF5C5),
        UIColor(rgb: 0x336F55),
        UIColor(rgb: 0xFBE37D)
    ]

    let firstStepPoints: [CGPoint] = [
        CGPoint(x: 0.823, y: 0.086),
        CGPoint(x: 0.362, y: 0.254),
        CGPoint(x: 0.184, y: 0.923),
        CGPoint(x: 0.648, y: 0.759)
    ]

    let nextStepPoints: [CGPoint] = [
        CGPoint(x: 0.59, y: 0.16),
        CGPoint(x: 0.28, y: 0.58),
        CGPoint(x: 0.42, y: 0.83),
        CGPoint(x: 0.74, y: 0.42)
    ]

    if step % 2 == 0 {
        firstSet = shiftArray(array: firstStepPoints, offset: step / 2)
        secondSet = shiftArray(array: nextStepPoints, offset: step / 2)
    } else {
        firstSet = shiftArray(array: nextStepPoints, offset: step / 2)
        secondSet = shiftArray(array: firstStepPoints, offset: step / 2 + 1)
    }

    for index in 0 ..< colors.count {
        let point = transformPoint(
            points: (firstSet[index], secondSet[index]),
            substep: substep
        )

        points.append(GradientPoint(
            color: colors[index],
            position: point
        ))
    }

    return points
}

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

private func transformPoint(points: (first: CGPoint, second: CGPoint), substep: Int) -> CGPoint {
    let delta = CGFloat(substep) / CGFloat(30)
    let x = points.first.x + (points.second.x - points.first.x) * delta
    let y = points.first.y + (points.second.y - points.first.y) * delta

    return CGPoint(x: x, y: y)
}

private func generateGradientComponent(size: CGSize, color: UIColor) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, false, 1.0)

    let c = UIGraphicsGetCurrentContext()

    c?.clear(CGRect(origin: CGPoint.zero, size: size))

    c?.setBlendMode(.normal)

    var gradLocs: [CGFloat] = [0, 0.1, 0.35, 1]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let radius = min(size.width / 2.0, size.height / 2.0)

    let colors = [
        color.cgColor,
        color.withAlphaComponent(0.8).cgColor,
        color.withAlphaComponent(0.3).cgColor,
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

private func generateGradient(with size: CGSize, gradPointArray gradPoints: [GradientPoint]) -> UIImage? {
    UIGraphicsBeginImageContextWithOptions(size, true, 1.0)

    let c = UIGraphicsGetCurrentContext()

    c?.setFillColor(UIColor.white.cgColor)
    c?.fill(CGRect(origin: CGPoint.zero, size: size))

    c?.setBlendMode(.multiply)

    var gradLocs: [CGFloat] = [0, 0.0, 0.35, 1]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let radius = max(size.width, size.height)

    for point in gradPoints {
        let colors = [
            point.color.cgColor,
            point.color.withAlphaComponent(0.8).cgColor,
            point.color.withAlphaComponent(0.3).cgColor,
            point.color.withAlphaComponent(0).cgColor
        ]

        let grad = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &gradLocs)
        if let grad = grad {
            let newPoint = point.position.applying(
                .init(scaleX: size.width, y: size.height)
            )

            c?.drawRadialGradient(grad, startCenter: newPoint, startRadius: 0, endCenter: newPoint, endRadius: radius, options: [])
        }
    }

    let i = UIGraphicsGetImageFromCurrentImageContext()

    UIGraphicsEndImageContext()

    return i
}

public final class GradientBackgroundNode: ASDisplayNode {
    //private let imageView: UIImageView

    private var pointImages: [UIImageView] = []

    private let firstStepPoints: [CGPoint] = [
        CGPoint(x: 0.823, y: 0.086),
        CGPoint(x: 0.362, y: 0.254),
        CGPoint(x: 0.184, y: 0.923),
        CGPoint(x: 0.648, y: 0.759)
    ]

    private let nextStepPoints: [CGPoint] = [
        CGPoint(x: 0.59, y: 0.16),
        CGPoint(x: 0.28, y: 0.58),
        CGPoint(x: 0.42, y: 0.83),
        CGPoint(x: 0.74, y: 0.42)
    ]

    private var phase: Int = 0

    private var timer: Timer?

    private var validLayout: CGSize?

    override public init() {
        //self.imageView = UIImageView()

        super.init()

        self.phase = 3

        self.backgroundColor = .white
        self.clipsToBounds = true

        //self.view.addSubview(self.imageView)

        /*let compositingModes: [String] = CIFilter
            .filterNames(inCategory: nil) // fetch all the available filters
            .filter { $0.contains("Compositing")} // retrieve only the compositing ones
            .map {
                let capitalizedFilter = $0.dropFirst(2) // drop the CIn prefix
                let first = capitalizedFilter.first! // fetch the first letter
                // lowercase the first letter and drop the `Compositing` suffix
                return "\(first.lowercased())\(capitalizedFilter.dropFirst().dropLast("Compositing".count))"
            }*/

        //print("compositingModes: \(compositingModes)")

        //self.imageView.alpha = 0.5
        //self.imageView.layer.compositingFilter = "multiplyBlendMode"

        let colors: [UIColor] = [
            UIColor(rgb: 0xfff6bf),
            UIColor(rgb: 0x76a076),
            UIColor(rgb: 0xf6e477),
            UIColor(rgb: 0x316b4d)
        ]

        for color in colors {
            let pointImage = UIImageView(image: generateGradientComponent(size: CGSize(width: 800.0, height: 800.0), color: color.withMultiplied(hue: 1.0, saturation: 1.2, brightness: 1.0)))
            pointImage.layer.compositingFilter = "multiplyBlendMode"
            //pointImage.layer.compositingFilter = "additionBlendMode"
            pointImage.alpha = 0.7
            self.view.addSubview(pointImage)
            self.pointImages.append(pointImage)
        }

        if #available(iOS 10.0, *) {
            let timer = Timer(timeInterval: 2.0, repeats: true, block: { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.phase = (strongSelf.phase + 1) % 4
                if let size = strongSelf.validLayout {
                    strongSelf.updateLayout(size: size, transition: .animated(duration: 0.5, curve: .spring))
                }
            })
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    deinit {
        self.timer?.invalidate()
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size

        let positions: [CGPoint]

        if self.phase % 2 == 0 {
            positions = shiftArray(array: firstStepPoints, offset: self.phase / 2)
        } else {
            positions = shiftArray(array: nextStepPoints, offset: self.phase / 2 + 1)
        }

        for i in 0 ..< firstStepPoints.count {
            if self.pointImages.count <= i {
                break
            }
            let pointCenter = CGPoint(x: size.width * positions[i].x, y: size.height * positions[i].y)
            let pointSide = max(size.width, size.height) * 2.0
            let pointSize = CGSize(width: pointSide, height: pointSide)
            transition.updateFrame(view: self.pointImages[i], frame: CGRect(origin: CGPoint(x: pointCenter.x - pointSize.width / 2.0, y: pointCenter.y - pointSize.height / 2.0), size: pointSize))
        }

        /*self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        self.imageView.layer.magnificationFilter = .linear

        self.imageView.image = generateGradient(with: size.fitted(CGSize(width: 64.0, height: 64.0)), gradPointArray: applyTransformerToPoints(step: 0, substep: 0))*/
    }
}
