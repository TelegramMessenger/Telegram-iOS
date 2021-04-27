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

    //var gradLocs: [CGFloat] = [0, 0.1, 0.35, 1]
    var gradLocs: [CGFloat] = [0.0, 1.0]
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let radius = min(size.width / 2.0, size.height / 2.0)

    let colors = [
        color.cgColor,
        //color.withAlphaComponent(0.8).cgColor,
        //color.withAlphaComponent(0.3).cgColor,
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
    //private let imageView: UIImageView

    private var pointImages: [UIImageView] = []
    private let dimView: UIView

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
    private var subphase: Int = 0

    private var timer: Timer?

    private var validLayout: CGSize?

    override public init() {
        //self.imageView = UIImageView()

        self.dimView = UIView()
        self.dimView.backgroundColor = UIColor(white: 1.0, alpha: 0.0)

        super.init()

        self.phase = 0

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

        /*if #available(iOS 10.0, *) {
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
        }*/
    }

    deinit {
        self.timer?.invalidate()
    }

    public func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        self.validLayout = size

        self.dimView.frame = CGRect(origin: CGPoint(), size: size)

        let positions: [CGPoint]

        let basePositions: [CGPoint] = [
            CGPoint(x: 0.1, y: 0.1),
            CGPoint(x: 0.1, y: 0.9),
            CGPoint(x: 0.9, y: 0.9),
            CGPoint(x: 0.9, y: 0.1),
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

        for i in 0 ..< firstStepPoints.count {
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
