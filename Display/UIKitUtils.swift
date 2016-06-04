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

public let UIScreenScale = UIScreen.mainScreen().scale
public func floorToScreenPixels(value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}

public let UIScreenPixel = 1.0 / UIScreenScale

public extension UIColor {
    convenience init(_ rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(_ rgb: UInt32, _ alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
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
    
    public func fittedToArea(area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: floor(width), height: floor(height))
    }
    
    public func aspectFilled(size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFitted(size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
}

public func assertNotOnMainThread(file: String = #file, line: Int = #line) {
    assert(!NSThread.isMainThread(), "\(file):\(line) running on main thread")
}

public extension UIImage {
    public func precomposed() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.drawAtPoint(CGPoint())
        let result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        if !UIEdgeInsetsEqualToEdgeInsets(self.capInsets, UIEdgeInsetsZero) {
            return result.resizableImageWithCapInsets(self.capInsets, resizingMode: self.resizingMode)
        }
        return result
    }
}
