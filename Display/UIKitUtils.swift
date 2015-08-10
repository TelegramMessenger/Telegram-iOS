import UIKit

public func dumpViews(view: UIView) {
    dumpViews(view, indent: "")
}

private func dumpViews(view: UIView, indent: String = "") {
    print("\(indent)\(view)")
    let nextIndent = indent + "-"
    for subview in view.subviews {
        dumpViews(subview as UIView, indent: nextIndent)
    }
}

public func dumpLayers(layer: CALayer) {
    dumpLayers(layer, indent: "")
}

private func dumpLayers(layer: CALayer, indent: String = "") {
    print("\(indent)\(layer)(\(layer.frame))")
    if layer.sublayers != nil {
        let nextIndent = indent + ".."
        for sublayer in layer.sublayers ?? [] {
            dumpLayers(sublayer as CALayer, indent: nextIndent)
        }
    }
}

public func floorToScreenPixels(value: CGFloat) -> CGFloat {
    return floor(value * 2.0) / 2.0
}

public extension UIColor {
    convenience init(_ rgb: Int) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
}

public extension CGSize {
    public func fitted(size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
}
