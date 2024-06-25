import Foundation
import UIKit

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
