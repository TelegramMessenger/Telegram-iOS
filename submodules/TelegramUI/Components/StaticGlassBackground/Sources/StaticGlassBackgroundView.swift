import Foundation
import UIKit
import AppBundle

/// A shape drawn with an image captured from iOS 27 glass instead of live glass: what the chat shows per message
/// without bubbles, where live glass costs a backdrop effect per button. Laid out as GlassBackgroundView is: content goes
/// into `contentView`, which spans the shape; the image reaches past it for the rim and the shadow.
public final class StaticGlassBackgroundView: UIView {
    public let contentView: UIView
    private let imageView: UIImageView

    override public init(frame: CGRect) {
        self.imageView = UIImageView()
        self.imageView.isUserInteractionEnabled = false
        self.contentView = UIView()

        super.init(frame: frame)

        self.addSubview(self.imageView)
        self.addSubview(self.contentView)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `updateFrame` sets the frames of the image and the content as the caller animates this view's own frame (they
    /// are set at once without it).
    public func update(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tint: StaticGlassTint, updateFrame: ((UIView, CGRect) -> Void)? = nil) {
        let setFrame: (UIView, CGRect) -> Void = updateFrame ?? { view, frame in
            view.frame = frame
        }
        setFrame(self.contentView, CGRect(origin: CGPoint(), size: size))
        guard let (image, margins) = StaticGlassImageCache.shared.image(size: size, cornerRadius: cornerRadius, isDark: isDark, tint: tint) else {
            self.imageView.image = nil
            return
        }
        if self.imageView.image !== image {
            self.imageView.image = image
        }
        setFrame(self.imageView, CGRect(x: -margins.left, y: -margins.top, width: size.width + margins.left + margins.right, height: size.height + margins.top + margins.bottom))
    }
}

/// Decoded assets and the images made from them, per asset, mode, tint, scale and (for a shape narrower than its
/// asset's ends) width. Main thread.
private final class StaticGlassImageCache {
    static let shared = StaticGlassImageCache()

    private struct ImageKey: Hashable {
        var name: String
        var tint: [Int]
        var scale: Int
        var cutLength: Int?
    }

    private var assets: [String: StaticGlassAssetData] = [:]
    private var images: [ImageKey: (UIImage, UIEdgeInsets)] = [:]

    private func asset(name: String) -> StaticGlassAssetData? {
        if let current = self.assets[name] {
            return current
        }
        guard let path = getAppBundle().path(forResource: name, ofType: "bin"), let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let asset = StaticGlassAssetData(data: data) else {
            assertionFailure("StaticGlass: no asset \(name)")
            return nil
        }
        self.assets[name] = asset
        return asset
    }

    func image(size: CGSize, cornerRadius: CGFloat, isDark: Bool, tint: StaticGlassTint) -> (UIImage, UIEdgeInsets)? {
        assert(Thread.isMainThread)
        guard size.width > 0.0, size.height > 0.0 else {
            return nil
        }
        let choice = staticGlassAssetChoice(size: size, cornerRadius: cornerRadius)
        let name = "static-glass-\(choice.shape.rawValue)-\(isDark ? "dark" : "light")"
        guard let asset = self.asset(name: name) else {
            return nil
        }
        // Asset pixels per point of the image.
        let imageScale = CGFloat(asset.scale) / choice.scale

        var tintComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)?
        if case let .color(color) = tint {
            var r: CGFloat = 0.0, g: CGFloat = 0.0, b: CGFloat = 0.0, a: CGFloat = 0.0
            if color.getRed(&r, green: &g, blue: &b, alpha: &a) {
                tintComponents = (r, g, b, a)
            }
        }

        // A shape shorter along its run than the asset's two ends is cut from them, across columns or rows.
        let isVertical = asset.capInsets.top > 0.0 || asset.capInsets.bottom > 0.0
        let isHorizontal = asset.capInsets.left > 0.0 || asset.capInsets.right > 0.0
        var cutLength: Int?
        if isHorizontal || isVertical {
            let shapeLengthInAsset = (isVertical ? size.height : size.width) * imageScale
            let assetLength = Int(isVertical ? asset.frame.height : asset.frame.width)
            if staticGlassNeedsCutting(shapeWidth: shapeLengthInAsset / CGFloat(asset.scale), assetFrameWidth: assetLength, scale: asset.scale) {
                cutLength = max(2, Int(shapeLengthInAsset.rounded()))
            }
        }

        let key = ImageKey(name: name, tint: tintComponents.flatMap { [$0.r, $0.g, $0.b, $0.a].map { Int(($0 * 255.0).rounded()) } } ?? [], scale: Int((choice.scale * 1000.0).rounded()), cutLength: cutLength)
        if let current = self.images[key] {
            return current
        }

        var width = asset.width
        var height = asset.height
        var frame = asset.frame
        var pixels = asset.pixels
        if let cutLength {
            (width, height, frame, pixels) = staticGlassCutPixels(pixels, width: width, height: height, frame: frame, vertical: isVertical, shapeLength: cutLength)
        }
        if let tintComponents {
            pixels = staticGlassTinted(pixels: pixels, width: width, height: height, frame: frame, scale: asset.scale, outset: staticGlassTintOutset(isDark: isDark), tint: tintComponents)
        }
        guard let provider = CGDataProvider(data: pixels as CFData), let colorSpace = CGColorSpace(name: CGColorSpace.sRGB), let cgImage = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            return nil
        }
        var image = UIImage(cgImage: cgImage, scale: imageScale, orientation: .up)
        let capInsets = cutLength == nil ? asset.capInsets : UIEdgeInsets()
        if capInsets != UIEdgeInsets() {
            image = image.resizableImage(withCapInsets: UIEdgeInsets(top: capInsets.top / imageScale, left: capInsets.left / imageScale, bottom: capInsets.bottom / imageScale, right: capInsets.right / imageScale), resizingMode: .stretch)
        }
        let margins = UIEdgeInsets(top: frame.minY / imageScale, left: frame.minX / imageScale, bottom: (CGFloat(height) - frame.maxY) / imageScale, right: (CGFloat(width) - frame.maxX) / imageScale)
        self.images[key] = (image, margins)
        return (image, margins)
    }
}

/// A shape shorter along its run than its asset's ends, cut from them: the first end up to half the shape's length, the
/// second end from there (columns for a horizontal capsule, rows for a vertical one), the margins kept.
public func staticGlassCutPixels(_ pixels: Data, width: Int, height: Int, frame: CGRect, vertical: Bool, shapeLength: Int) -> (width: Int, height: Int, frame: CGRect, pixels: Data) {
    if vertical {
        let topRows = Int(frame.minY) + shapeLength / 2
        let bottomRows = shapeLength - shapeLength / 2 + (height - Int(frame.maxY))
        let rowBytes = width * 4
        var result = Data(count: (topRows + bottomRows) * rowBytes)
        result.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) in
            pixels.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                target.baseAddress!.copyMemory(from: source.baseAddress!, byteCount: topRows * rowBytes)
                target.baseAddress!.advanced(by: topRows * rowBytes).copyMemory(from: source.baseAddress!.advanced(by: (height - bottomRows) * rowBytes), byteCount: bottomRows * rowBytes)
            }
        }
        return (width, topRows + bottomRows, CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: CGFloat(shapeLength)), result)
    } else {
        let leftColumns = Int(frame.minX) + shapeLength / 2
        let rightColumns = shapeLength - shapeLength / 2 + (width - Int(frame.maxX))
        let resultWidth = leftColumns + rightColumns
        var result = Data(count: resultWidth * height * 4)
        result.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) in
            pixels.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                for y in 0 ..< height {
                    let sourceRow = source.baseAddress!.advanced(by: y * width * 4)
                    let targetRow = target.baseAddress!.advanced(by: y * resultWidth * 4)
                    targetRow.copyMemory(from: sourceRow, byteCount: leftColumns * 4)
                    targetRow.advanced(by: leftColumns * 4).copyMemory(from: sourceRow.advanced(by: (width - rightColumns) * 4), byteCount: rightColumns * 4)
                }
            }
        }
        return (resultWidth, height, CGRect(x: frame.minX, y: frame.minY, width: CGFloat(shapeLength), height: frame.height), result)
    }
}

/// The tint laid over the shape (reaching `outset` points past it, anti-aliased), lightening toward its edge as tinted
/// glass does. Per pixel: no allocation, and nothing but a read outside the shape.
private func staticGlassTinted(pixels: Data, width: Int, height: Int, frame: CGRect, scale: Int, outset: CGFloat, tint: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat)) -> Data {
    let outsetPixels = outset * CGFloat(scale)
    // Rim distances are measured at the captures' 3x.
    let rimScale = 3.0 / CGFloat(scale)
    // The glass's own outline (continuous corners, not a stadium's arcs), filled anti-aliased.
    var coverageMap = [UInt8](repeating: 0, count: width * height)
    coverageMap.withUnsafeMutableBytes { buffer in
        guard let context = CGContext(data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return
        }
        // Bitmap contexts count rows from the bottom.
        let shape = CGRect(x: frame.minX, y: CGFloat(height) - frame.maxY, width: frame.width, height: frame.height).insetBy(dx: -outsetPixels, dy: -outsetPixels)
        context.setFillColor(gray: 1.0, alpha: 1.0)
        context.addPath(UIBezierPath(roundedRect: shape, cornerRadius: min(shape.width, shape.height) * 0.5).cgPath)
        context.fillPath()
    }
    let tintValues = (r: tint.r * 255.0, g: tint.g * 255.0, b: tint.b * 255.0)
    var result = pixels
    result.withUnsafeMutableBytes { (target: UnsafeMutableRawBufferPointer) in
        guard let bytes = target.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
            return
        }
        coverageMap.withUnsafeBufferPointer { coverageBuffer in
            for y in 0 ..< height {
                for x in 0 ..< width {
                    let index = y * width + x
                    let coverage = CGFloat(coverageBuffer[index]) / 255.0
                    if coverage <= 0.0 {
                        continue
                    }
                    let (distance, normalY) = staticGlassCapsuleDistanceAndNormal(CGPoint(x: CGFloat(x) + 0.5, y: CGFloat(y) + 0.5), frame: frame)
                    let t = tint.a * coverage
                    // The edge lightens where it faces up or down; the part past the frame is a shade darker.
                    let gain = distance < 0.0 ? -0.08 : staticGlassTintRimGain(distance: distance * rimScale) * coverage * normalY * normalY
                    let p = bytes.advanced(by: index * 4)
                    let r = CGFloat(p[0]) * (1.0 - t) + t * tintValues.r
                    let g = CGFloat(p[1]) * (1.0 - t) + t * tintValues.g
                    let b = CGFloat(p[2]) * (1.0 - t) + t * tintValues.b
                    let a = 255.0 - (255.0 - CGFloat(p[3])) * (1.0 - t)
                    p[0] = UInt8(max(0.0, min(255.0, (r.rounded() * (1.0 + gain)).rounded())))
                    p[1] = UInt8(max(0.0, min(255.0, (g.rounded() * (1.0 + gain)).rounded())))
                    p[2] = UInt8(max(0.0, min(255.0, (b.rounded() * (1.0 + gain)).rounded())))
                    p[3] = UInt8(max(0.0, min(255.0, a.rounded())))
                }
            }
        }
    }
    return result
}
