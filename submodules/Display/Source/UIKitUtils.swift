import UIKit
import UIKitRuntimeUtils
import AVFoundation

public extension UIView {
    static func animationDurationFactor() -> Double {
        return animationDurationFactorImpl()
    }
}

public func makeSpringAnimation(_ keyPath: String) -> CABasicAnimation {
    return makeSpringAnimationImpl(keyPath)
}

public func makeSpringBounceAnimation(_ keyPath: String, _ initialVelocity: CGFloat, _ damping: CGFloat) -> CABasicAnimation {
    return makeSpringBounceAnimationImpl(keyPath, initialVelocity, damping)
}

public func springAnimationValueAt(_ animation: CABasicAnimation, _ t: CGFloat) -> CGFloat {
    return springAnimationValueAtImpl(animation, t)
}

public func makeCustomZoomBlurEffect(isLight: Bool) -> UIBlurEffect? {
    return makeCustomZoomBlurEffectImpl(isLight)
}

public func applySmoothRoundedCorners(_ layer: CALayer) {
    applySmoothRoundedCornersImpl(layer)
}

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
    print("\(indent)\(layer)(frame: \(layer.frame), bounds: \(layer.bounds))")
    if layer.sublayers != nil {
        let nextIndent = indent + ".."
        if let sublayers = layer.sublayers {
            for sublayer in sublayers {
                dumpLayers(sublayer as CALayer, indent: nextIndent)
            }
        }
    }
}

public let UIScreenScale = UIScreen.main.scale
public func floorToScreenPixels(_ value: CGFloat) -> CGFloat {
    return floor(value * UIScreenScale) / UIScreenScale
}
public func ceilToScreenPixels(_ value: CGFloat) -> CGFloat {
    return ceil(value * UIScreenScale) / UIScreenScale
}

public let UIScreenPixel = 1.0 / UIScreenScale

public extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: 1.0)
    }
    
    convenience init(rgb: UInt32, alpha: CGFloat) {
        self.init(red: CGFloat((rgb >> 16) & 0xff) / 255.0, green: CGFloat((rgb >> 8) & 0xff) / 255.0, blue: CGFloat(rgb & 0xff) / 255.0, alpha: alpha)
    }
    
    convenience init(argb: UInt32) {
        self.init(red: CGFloat((argb >> 16) & 0xff) / 255.0, green: CGFloat((argb >> 8) & 0xff) / 255.0, blue: CGFloat(argb & 0xff) / 255.0, alpha: CGFloat((argb >> 24) & 0xff) / 255.0)
    }
    
    convenience init?(hexString: String) {
        let scanner = Scanner(string: hexString)
        if hexString.hasPrefix("#") {
            scanner.scanLocation = 1
        }
        var value: UInt32 = 0
        if scanner.scanHexInt32(&value) {
            if hexString.count > 7 {
                self.init(argb: value)
            } else {
                self.init(rgb: value)
            }
        } else {
            return nil
        }
    }
    
    var alpha: CGFloat {
        var alpha: CGFloat = 0.0
        if self.getRed(nil, green: nil, blue: nil, alpha: &alpha) {
            return alpha
        } else if self.getWhite(nil, alpha: &alpha) {
            return alpha
        } else {
            return 0.0
        }
    }
    
    var rgb: UInt32 {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: nil) {
            return (UInt32(max(0.0, red) * 255.0) << 16) | (UInt32(max(0.0, green) * 255.0) << 8) | (UInt32(max(0.0, blue) * 255.0))
        } else if self.getWhite(&red, alpha: nil) {
            return (UInt32(max(0.0, red) * 255.0) << 16) | (UInt32(max(0.0, red) * 255.0) << 8) | (UInt32(max(0.0, red) * 255.0))
        } else {
            return 0
        }
    }
    
    var argb: UInt32 {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return (UInt32(alpha * 255.0) << 24) | (UInt32(max(0.0, red) * 255.0) << 16) | (UInt32(max(0.0, green) * 255.0) << 8) | (UInt32(max(0.0, blue) * 255.0))
        } else if self.getWhite(&red, alpha: &alpha) {
            return (UInt32(max(0.0, alpha) * 255.0) << 24) | (UInt32(max(0.0, red) * 255.0) << 16) | (UInt32(max(0.0, red) * 255.0) << 8) | (UInt32(max(0.0, red) * 255.0))
        } else {
            return 0
        }
    }
    
    var hsb: (h: CGFloat, s: CGFloat, b: CGFloat) {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil) {
            return (hue, saturation, brightness)
        } else {
            return (0.0, 0.0, 0.0)
        }
    }
    
    var lightness: CGFloat {
        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: nil) {
            return 0.2126 * red + 0.7152 * green + 0.0722 * blue
        } else if self.getWhite(&red, alpha: nil) {
            return red
        } else {
            return 0.0
        }
    }
    
    func withMultipliedBrightnessBy(_ factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0.0
        var saturation: CGFloat = 0.0
        var brightness: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        
        return UIColor(hue: hue, saturation: saturation, brightness: max(0.0, min(1.0, brightness * factor)), alpha: alpha)
    }
    
    func withMultiplied(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> UIColor {
        var hueValue: CGFloat = 0.0
        var saturationValue: CGFloat = 0.0
        var brightnessValue: CGFloat = 0.0
        var alphaValue: CGFloat = 0.0
        self.getHue(&hueValue, saturation: &saturationValue, brightness: &brightnessValue, alpha: &alphaValue)
        
        return UIColor(hue: max(0.0, min(1.0, hueValue * hue)), saturation: max(0.0, min(1.0, saturationValue * saturation)), brightness: max(0.0, min(1.0, brightnessValue * brightness)), alpha: alphaValue)
    }
    
    func mixedWith(_ other: UIColor, alpha: CGFloat) -> UIColor {
        let alpha = min(1.0, max(0.0, alpha))
        let oneMinusAlpha = 1.0 - alpha
        
        var r1: CGFloat = 0.0
        var r2: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var g2: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var b2: CGFloat = 0.0
        var a1: CGFloat = 0.0
        var a2: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) &&
            other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        {
            let r = r1 * oneMinusAlpha + r2 * alpha
            let g = g1 * oneMinusAlpha + g2 * alpha
            let b = b1 * oneMinusAlpha + b2 * alpha
            let a = a1 * oneMinusAlpha + a2 * alpha
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return self
    }
    
    func blitOver(_ other: UIColor, alpha: CGFloat) -> UIColor {
        let alpha = min(1.0, max(0.0, alpha))
        
        var r1: CGFloat = 0.0
        var r2: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var g2: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var b2: CGFloat = 0.0
        var a1: CGFloat = 0.0
        var a2: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) &&
            other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        {
            let resultingAlpha = max(0.0, min(1.0, alpha * a1))
            let oneMinusResultingAlpha = 1.0 - resultingAlpha
            
            let r = r1 * resultingAlpha + r2 * oneMinusResultingAlpha
            let g = g1 * resultingAlpha + g2 * oneMinusResultingAlpha
            let b = b1 * resultingAlpha + b2 * oneMinusResultingAlpha
            let a: CGFloat = 1.0
            return UIColor(red: r, green: g, blue: b, alpha: a)
        }
        return self
    }
    
    func withMultipliedAlpha(_ alpha: CGFloat) -> UIColor {
        var r1: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var a1: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) {
            return UIColor(red: r1, green: g1, blue: b1, alpha: max(0.0, min(1.0, a1 * alpha)))
        }
        return self
    }
    
    func interpolateTo(_ color: UIColor, fraction: CGFloat) -> UIColor? {
        let f = min(max(0, fraction), 1)
        
        var r1: CGFloat = 0.0
        var r2: CGFloat = 0.0
        var g1: CGFloat = 0.0
        var g2: CGFloat = 0.0
        var b1: CGFloat = 0.0
        var b2: CGFloat = 0.0
        var a1: CGFloat = 0.0
        var a2: CGFloat = 0.0
        if self.getRed(&r1, green: &g1, blue: &b1, alpha: &a1) &&
            color.getRed(&r2, green: &g2, blue: &b2, alpha: &a2) {
            let r: CGFloat = CGFloat(r1 + (r2 - r1) * f)
            let g: CGFloat = CGFloat(g1 + (g2 - g1) * f)
            let b: CGFloat = CGFloat(b1 + (b2 - b1) * f)
            let a: CGFloat = CGFloat(a1 + (a2 - a1) * f)
            
            return UIColor(red: r, green: g, blue: b, alpha: a)
        } else {
            return self
        }
    }
    
    private var colorComponents: (r: Int32, g: Int32, b: Int32) {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        if self.getRed(&r, green: &g, blue: &b, alpha: nil) {
            return (Int32(max(0.0, r) * 255.0), Int32(max(0.0, g) * 255.0), Int32(max(0.0, b) * 255.0))
        } else if self.getWhite(&r, alpha: nil) {
            return (Int32(max(0.0, r) * 255.0), Int32(max(0.0, r) * 255.0), Int32(max(0.0, r) * 255.0))
        }
        return (0, 0, 0)
    }
    
    func distance(to other: UIColor) -> Int32 {
        let e1 = self.colorComponents
        let e2 = other.colorComponents
        let rMean = (e1.r + e2.r) / 2
        let r = e1.r - e2.r
        let g = e1.g - e2.g
        let b = e1.b - e2.b
        return ((512 + rMean) * r * r) >> 8 + 4 * g * g + ((767 - rMean) * b * b) >> 8
    }

    static func average(of colors: [UIColor]) -> UIColor {
        var sr: CGFloat = 0.0
        var sg: CGFloat = 0.0
        var sb: CGFloat = 0.0
        var sa: CGFloat = 0.0

        for color in colors {
            var r: CGFloat = 0.0
            var g: CGFloat = 0.0
            var b: CGFloat = 0.0
            var a: CGFloat = 0.0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            sr += r
            sg += g
            sb += b
            sa += a
        }

        return UIColor(red: sr / CGFloat(colors.count), green: sg / CGFloat(colors.count), blue: sb / CGFloat(colors.count), alpha: sa / CGFloat(colors.count))
    }
}

public extension CGSize {
    func fitted(_ size: CGSize) -> CGSize {
        var fittedSize = self
        if fittedSize.width > size.width {
            fittedSize = CGSize(width: size.width, height: floor((fittedSize.height * size.width / max(fittedSize.width, 1.0))))
        }
        if fittedSize.height > size.height {
            fittedSize = CGSize(width: floor((fittedSize.width * size.height / max(fittedSize.height, 1.0))), height: size.height)
        }
        return fittedSize
    }
    
    func cropped(_ size: CGSize) -> CGSize {
        return CGSize(width: min(size.width, self.width), height: min(size.height, self.height))
    }
    
    func fittedToArea(_ area: CGFloat) -> CGSize {
        if self.height < 1.0 || self.width < 1.0 {
            return CGSize()
        }
        let aspect = self.width / self.height
        let height = sqrt(area / aspect)
        let width = aspect * height
        return CGSize(width: floor(width), height: floor(height))
    }
    
    func aspectFilled(_ size: CGSize) -> CGSize {
        let scale = max(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func aspectFitted(_ size: CGSize) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func aspectFittedOrSmaller(_ size: CGSize) -> CGSize {
        let scale = min(1.0, min(size.width / max(1.0, self.width), size.height / max(1.0, self.height)))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func aspectFittedWithOverflow(_ size: CGSize, leeway: CGFloat) -> CGSize {
        let scale = min(size.width / max(1.0, self.width), size.height / max(1.0, self.height))
        var result = CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
        if result.width < size.width && result.width > size.width - leeway {
            result.height += size.width - result.width
            result.width = size.width
        }
        if result.height < size.height && result.height > size.height - leeway {
            result.width += size.height - result.height
            result.height = size.height
        }
        return result
    }
    
    func fittedToWidthOrSmaller(_ width: CGFloat) -> CGSize {
        let scale = min(1.0, width / max(1.0, self.width))
        return CGSize(width: floor(self.width * scale), height: floor(self.height * scale))
    }
    
    func multipliedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width * scale, height: self.height * scale)
    }
    
    func dividedByScreenScale() -> CGSize {
        let scale = UIScreenScale
        return CGSize(width: self.width / scale, height: self.height / scale)
    }
    
    var integralFloor: CGSize {
        return CGSize(width: floor(self.width), height: floor(self.height))
    }
}

public func assertNotOnMainThread(_ file: String = #file, line: Int = #line) {
    assert(!Thread.isMainThread, "\(file):\(line) running on main thread")
}

public extension UIImage {
    func precomposed() -> UIImage {        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        self.draw(at: CGPoint())
        let result = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        if self.capInsets != UIEdgeInsets() {
            return result.resizableImage(withCapInsets: self.capInsets, resizingMode: self.resizingMode)
        }
        return result
    }
}

private func makeSubtreeSnapshot(layer: CALayer, keepTransform: Bool = false) -> UIView? {
    if layer is AVSampleBufferDisplayLayer {
        return nil
    }
    let view = UIView()
    view.layer.isHidden = layer.isHidden
    view.layer.opacity = layer.opacity
    view.layer.contents = layer.contents
    view.layer.contentsRect = layer.contentsRect
    view.layer.contentsScale = layer.contentsScale
    view.layer.contentsCenter = layer.contentsCenter
    view.layer.contentsGravity = layer.contentsGravity
    view.layer.masksToBounds = layer.masksToBounds
    view.layer.layerTintColor = layer.layerTintColor
    if let mask = layer.mask {
        if let shapeMask = mask as? CAShapeLayer {
            let maskLayer = CAShapeLayer()
            maskLayer.path = shapeMask.path
            view.layer.mask = maskLayer
        } else {
            let maskLayer = CALayer()
            maskLayer.contents = mask.contents
            maskLayer.contentsRect = mask.contentsRect
            maskLayer.contentsScale = mask.contentsScale
            maskLayer.contentsCenter = mask.contentsCenter
            maskLayer.contentsGravity = mask.contentsGravity
            maskLayer.transform = mask.transform
            maskLayer.position = mask.position
            maskLayer.bounds = mask.bounds
            maskLayer.anchorPoint = mask.anchorPoint
            maskLayer.layerTintColor = mask.layerTintColor
            view.layer.mask = maskLayer
        }
    }
    view.layer.cornerRadius = layer.cornerRadius
    view.layer.backgroundColor = layer.backgroundColor
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeSubtreeSnapshot(layer: sublayer, keepTransform: keepTransform)
            if let subtree = subtree {
                if keepTransform {
                    subtree.layer.transform = sublayer.transform
                }
                subtree.layer.transform = sublayer.transform
                subtree.layer.position = sublayer.position
                subtree.layer.bounds = sublayer.bounds
                subtree.layer.anchorPoint = sublayer.anchorPoint
                subtree.layer.layerTintColor = sublayer.layerTintColor
                if let maskLayer = subtree.layer.mask {
                    maskLayer.transform = sublayer.transform
                    maskLayer.position = sublayer.position
                    maskLayer.bounds = sublayer.bounds
                    maskLayer.anchorPoint = sublayer.anchorPoint
                    maskLayer.layerTintColor = sublayer.layerTintColor
                }
                view.addSubview(subtree)
            } else {
                continue
            }
        }
    }
    return view
}

private func makeLayerSubtreeSnapshot(layer: CALayer) -> CALayer? {
    if layer is AVSampleBufferDisplayLayer {
        return nil
    }
    let view = CALayer()
    view.isHidden = layer.isHidden
    view.opacity = layer.opacity
    view.contents = layer.contents
    view.contentsRect = layer.contentsRect
    view.contentsScale = layer.contentsScale
    view.contentsCenter = layer.contentsCenter
    view.contentsGravity = layer.contentsGravity
    view.masksToBounds = layer.masksToBounds
    view.cornerRadius = layer.cornerRadius
    view.backgroundColor = layer.backgroundColor
    view.layerTintColor = layer.layerTintColor
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeLayerSubtreeSnapshot(layer: sublayer)
            if let subtree = subtree {
                subtree.transform = sublayer.transform
                subtree.position = sublayer.position
                subtree.bounds = sublayer.bounds
                subtree.anchorPoint = sublayer.anchorPoint
                view.addSublayer(subtree)
            } else {
                return nil
            }
        }
    }
    return view
}

private func makeLayerSubtreeSnapshotAsView(layer: CALayer) -> UIView? {
    if layer is AVSampleBufferDisplayLayer {
        return nil
    }
    let view = UIView()
    view.layer.isHidden = layer.isHidden
    view.layer.opacity = layer.opacity
    view.layer.contents = layer.contents
    view.layer.contentsRect = layer.contentsRect
    view.layer.contentsScale = layer.contentsScale
    view.layer.contentsCenter = layer.contentsCenter
    view.layer.contentsGravity = layer.contentsGravity
    view.layer.masksToBounds = layer.masksToBounds
    view.layer.cornerRadius = layer.cornerRadius
    view.layer.backgroundColor = layer.backgroundColor
    view.layer.layerTintColor = layer.layerTintColor
    if let sublayers = layer.sublayers {
        for sublayer in sublayers {
            let subtree = makeLayerSubtreeSnapshotAsView(layer: sublayer)
            if let subtree = subtree {
                subtree.layer.transform = sublayer.transform
                subtree.layer.position = sublayer.position
                subtree.layer.bounds = sublayer.bounds
                subtree.layer.anchorPoint = sublayer.anchorPoint
                subtree.layer.layerTintColor = sublayer.layerTintColor
                view.addSubview(subtree)
            } else {
                return nil
            }
        }
    }
    return view
}


public extension UIView {
    func snapshotContentTree(unhide: Bool = false, keepTransform: Bool = false) -> UIView? {
        let wasHidden = self.isHidden
        if unhide && wasHidden {
            self.isHidden = false
        }
        let snapshot = makeSubtreeSnapshot(layer: self.layer, keepTransform: keepTransform)
        if unhide && wasHidden {
            self.isHidden = true
        }
        if let snapshot = snapshot {
            snapshot.layer.position = self.layer.position
            snapshot.layer.bounds = self.layer.bounds
            snapshot.layer.anchorPoint = self.layer.anchorPoint
            return snapshot
        }
        
        return nil
    }
}

public extension CALayer {
    func snapshotContentTree(unhide: Bool = false) -> CALayer? {
        let wasHidden = self.isHidden
        if unhide && wasHidden {
            self.isHidden = false
        }
        let snapshot = makeLayerSubtreeSnapshot(layer: self)
        if unhide && wasHidden {
            self.isHidden = true
        }
        if let snapshot = snapshot {
            snapshot.frame = self.frame
            snapshot.bounds = self.bounds
            return snapshot
        }
        
        return nil
    }
}

public extension CALayer {
    var layerTintColor: CGColor? {
        get {
            if let value = self.value(forKey: "contentsMultiplyColor"), CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
                let result = value as! CGColor
                return result
            } else {
                return nil
            }
        } set(value) {
            self.setValue(value, forKey: "contentsMultiplyColor")
        }
    }
}

public extension CALayer {
    func snapshotContentTreeAsView(unhide: Bool = false) -> UIView? {
        let wasHidden = self.isHidden
        if unhide && wasHidden {
            self.isHidden = false
        }
        let snapshot = makeLayerSubtreeSnapshotAsView(layer: self)
        if unhide && wasHidden {
            self.isHidden = true
        }
        if let snapshot = snapshot {
            snapshot.frame = self.frame
            snapshot.bounds = self.bounds
            return snapshot
        }
        
        return nil
    }
}

public extension CGRect {
    var topLeft: CGPoint {
        return self.origin
    }
    
    var topRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.minY)
    }
    
    var bottomLeft: CGPoint {
        return CGPoint(x: self.minX, y: self.maxY)
    }
    
    var bottomRight: CGPoint {
        return CGPoint(x: self.maxX, y: self.maxY)
    }
}

public extension CGPoint {
    func offsetBy(dx: CGFloat, dy: CGFloat) -> CGPoint {
        return CGPoint(x: self.x + dx, y: self.y + dy)
    }
}
