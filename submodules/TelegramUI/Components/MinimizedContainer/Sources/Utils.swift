import Foundation
import UIKit
import Display

extension CATransform3D {
    func interpolate(with other: CATransform3D, fraction: CGFloat) -> CATransform3D {
        var vectors = Array<CGFloat>(repeating: 0.0, count: 16)
        vectors[0]  = self.m11 + (other.m11 - self.m11) * fraction
        vectors[1]  = self.m12 + (other.m12 - self.m12) * fraction
        vectors[2]  = self.m13 + (other.m13 - self.m13) * fraction
        vectors[3]  = self.m14 + (other.m14 - self.m14) * fraction
        vectors[4]  = self.m21 + (other.m21 - self.m21) * fraction
        vectors[5]  = self.m22 + (other.m22 - self.m22) * fraction
        vectors[6]  = self.m23 + (other.m23 - self.m23) * fraction
        vectors[7]  = self.m24 + (other.m24 - self.m24) * fraction
        vectors[8]  = self.m31 + (other.m31 - self.m31) * fraction
        vectors[9]  = self.m32 + (other.m32 - self.m32) * fraction
        vectors[10] = self.m33 + (other.m33 - self.m33) * fraction
        vectors[11] = self.m34 + (other.m34 - self.m34) * fraction
        vectors[12] = self.m41 + (other.m41 - self.m41) * fraction
        vectors[13] = self.m42 + (other.m42 - self.m42) * fraction
        vectors[14] = self.m43 + (other.m43 - self.m43) * fraction
        vectors[15] = self.m44 + (other.m44 - self.m44) * fraction
        
        return CATransform3D(m11: vectors[0], m12: vectors[1], m13: vectors[2], m14: vectors[3], m21: vectors[4], m22: vectors[5], m23: vectors[6], m24: vectors[7], m31: vectors[8], m32: vectors[9], m33: vectors[10], m34: vectors[11], m41: vectors[12], m42: vectors[13], m43: vectors[14], m44: vectors[15])
    }
}

private extension CGFloat {
    func interpolate(with other: CGFloat, fraction: CGFloat) -> CGFloat {
        let invT = 1.0 - fraction
        let result = other * fraction + self * invT
        return result
    }
}

private extension CGPoint {
    func interpolate(with other: CGPoint, fraction: CGFloat) -> CGPoint {
        return CGPoint(x: self.x.interpolate(with: other.x, fraction: fraction), y: self.y.interpolate(with: other.y, fraction: fraction))
    }
}

private extension CGSize {
    func interpolate(with other: CGSize, fraction: CGFloat) -> CGSize {
        return CGSize(width: self.width.interpolate(with: other.width, fraction: fraction), height: self.height.interpolate(with: other.height, fraction: fraction))
    }
}

extension CGRect {
    func interpolate(with other: CGRect, fraction: CGFloat) -> CGRect {
        return CGRect(origin: self.origin.interpolate(with: other.origin, fraction: fraction), size: self.size.interpolate(with: other.size, fraction: fraction))
    }
}

private let maxInteritemSpacing: CGFloat = 240.0
let additionalInsetTop: CGFloat = 16.0
private let additionalInsetBottom: CGFloat = 0.0
private let zOffset: CGFloat = -60.0

private let perspectiveCorrection: CGFloat = -1.0 / 1000.0
private let maxRotationAngle: CGFloat = -CGFloat.pi / 2.2

func angle(for origin: CGFloat, itemCount: Int, scrollBounds: CGRect, contentHeight: CGFloat?, insets: UIEdgeInsets) -> CGFloat {
    var rotationAngle = rotationAngleAt0(itemCount: itemCount)
    
    var contentOffset = scrollBounds.origin.y
    if contentOffset < 0.0 {
        contentOffset *= 2.0
    }
    
    var yOnScreen = origin - contentOffset - additionalInsetTop - insets.top
    if yOnScreen < 0 {
        yOnScreen = 0
    } else if yOnScreen > scrollBounds.height {
        yOnScreen = scrollBounds.height
    }
    
    let maxRotationVariance = maxRotationAngle - rotationAngleAt0(itemCount: itemCount)
    rotationAngle += (maxRotationVariance / scrollBounds.height) * yOnScreen

    return rotationAngle
}

func final3dTransform(for origin: CGFloat, size: CGSize, contentHeight: CGFloat?, itemCount: Int, forcedAngle: CGFloat? = nil, additionalAngle: CGFloat? = nil, scrollBounds: CGRect, insets: UIEdgeInsets) -> CATransform3D {
    var transform = CATransform3DIdentity
    transform.m34 = perspectiveCorrection
    
    let rotationAngle = forcedAngle ?? angle(for: origin, itemCount: itemCount, scrollBounds: scrollBounds, contentHeight: contentHeight, insets: insets)
    var effectiveRotationAngle = rotationAngle
    if let additionalAngle = additionalAngle {
        effectiveRotationAngle += additionalAngle
    }
    
    let r = size.height / 2.0 + abs(zOffset / sin(rotationAngle))
    
    let zTranslation = r * sin(rotationAngle)
    let yTranslation: CGFloat = r * (1 - cos(rotationAngle))
    
    let zTranslateTransform = CATransform3DTranslate(transform, 0.0, -yTranslation, zTranslation)
    
    let rotateTransform = CATransform3DRotate(zTranslateTransform, effectiveRotationAngle, 1.0, 0.0, 0.0)
    
    return rotateTransform
}

func interitemSpacing(itemCount: Int, boundingSize: CGSize, insets: UIEdgeInsets) -> CGFloat {
    var interitemSpacing = maxInteritemSpacing
    if itemCount > 0 {
        interitemSpacing = (boundingSize.height - additionalInsetTop - additionalInsetBottom  - insets.top) / CGFloat(min(itemCount, 5))
    }
    return interitemSpacing
}

func frameForIndex(index: Int, size: CGSize, insets: UIEdgeInsets, itemCount: Int, boundingSize: CGSize) -> CGRect {
    let spacing = interitemSpacing(itemCount: itemCount, boundingSize: boundingSize, insets: insets)
    var y = additionalInsetTop + insets.top + spacing * CGFloat(index)
    if itemCount == 1 {
        y += 72.0
    }
    let origin = CGPoint(x: insets.left, y: y)
    
    return CGRect(origin: origin, size: CGSize(width: size.width - insets.left - insets.right, height: size.height))
}

func rotationAngleAt0(itemCount: Int) -> CGFloat {
    let multiplier: CGFloat = min(CGFloat(itemCount), 5.0) - 1.0
    return -CGFloat.pi / 7.0 - CGFloat.pi / 7.0 * multiplier / 4.0
}

final class BlurView: UIVisualEffectView {
    private func setup() {
        for subview in self.subviews {
            if subview.description.contains("VisualEffectSubview") {
                subview.isHidden = true
            }
        }
        
        if let sublayer = self.layer.sublayers?[0], let filters = sublayer.filters {
            sublayer.backgroundColor = nil
            sublayer.isOpaque = false
            let allowedKeys: [String] = [
                "gaussianBlur",
                "colorSaturate"
            ]
            sublayer.filters = filters.filter { filter in
                guard let filter = filter as? NSObject else {
                    return true
                }
                let filterName = String(describing: filter)
                if !allowedKeys.contains(filterName) {
                    return false
                }
                return true
            }
        }
    }
    
    override var effect: UIVisualEffect? {
        get {
            return super.effect
        }
        set {
            super.effect = newValue
            self.setup()
        }
    }
    
    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)
        self.setup()
    }
}

let shadowImage: UIImage? = {
    return generateImage(CGSize(width: 1.0, height: 480.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let gradientColors = [UIColor.black.withAlphaComponent(0.0).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor, UIColor.black.withAlphaComponent(0.55).cgColor] as CFArray
        
        var locations: [CGFloat] = [0.0, 0.65, 1.0]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: &locations)!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: bounds.height), options: [])
    })
}()
