import UIKit

public func linearInterpolatedColor(from: UIColor, to: UIColor, fraction: CGFloat) -> UIColor {
    let f = min(max(0, fraction), 1)

    guard let c1 = from.getComponents(),
          let c2 = to.getComponents() else {
        return from
    }

    let r = c1.r + (c2.r - c1.r) * f
    let g = c1.g + (c2.g - c1.g) * f
    let b = c1.b + (c2.b - c1.b) * f
    let a = c1.a + (c2.a - c1.a) * f

    return UIColor(red: r, green: g, blue: b, alpha: a)
}

public extension UIColor {
    func getComponents() -> (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)? {
        let c = cgColor.components ?? []
        if c.count == 2 {
            return (r: c[0], g: c[0], b: c[0], a: c[1])
        } else if c.count == 4 {
            return (r: c[0], g: c[1], b: c[2], a: c[3])
        } else {
            return nil
        }
    }
}
