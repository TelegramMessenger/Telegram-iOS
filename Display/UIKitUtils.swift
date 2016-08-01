import UIKit

public func dumpViews(_ view: UIView) {
    dumpViews(view, indent: "")
}

private func dumpViews(_ view: UIView, indent: String = "") {
    print("\(indent)\(view)")
    let nextIndent = indent + "-"
    for subview in view.subviews {
        dumpViews(subview as UIView, indent: nextIndent)
    }
}

public func dumpLayers(_ layer: CALayer) {
    dumpLayers(layer, indent: "")
}

private func dumpLayers(_ layer: CALayer, indent: String = "") {
    print("\(indent)\(layer)(\(layer.frame))")
    if layer.sublayers != nil {
        let nextIndent = indent + ".."
        for sublayer in layer.sublayers ?? [] {
            dumpLayers(sublayer as CALayer, indent: nextIndent)
        }
    }
}

public let UIScreenScale = UIScreen.main().scale
public func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
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
    public func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
    
    public func fittedToArea(_ area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: floor(width), height: floor(height))
    }
    
    public func aspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func aspectFitted(_ size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    public func multipliedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
    
    public func dividedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width / scale, height: self.height / scale)
    }
}

public func assertNotOnMainThread(_ file: String = #file, line: Int = #line) {
    assert(!Thread.isMainThread, "\(file):\(line) running on main thread")
}

public extension UIImage {
    public func precomposed() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: CGPoint())
        let result = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        if !UIEdgeInsetsEqualToEdgeInsets(self.capInsets, UIEdgeInsetsZero) {
            return result.resizableImage(withCapInsets: self.capInsets, resizingMode: self.resizingMode)
        }
        return result
    }
}

private func makeSubtreeSnapshot(layer: CALayer) -> UIView? {
    let view = UIView()
    view.layer.contents = layer.contents
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeSubtreeSnapshot(layer: sublayer)
            if let subtree = subtree {
                subtree.frame = sublayer.frame
                view.addSubview(subtree)
            } else {
                return nil
            }
        }
    }
    return view
}

public extension UIView {
    public func snapshotContentTree() -> UIView? {
        if let snapshot = makeSubtreeSnapshot(layer: self.layer) {
            snapshot.frame = self.frame
            return snapshot
        } else {
            return nil
        }
    }
}
