import UIKit

/// Pixel measurement for questions that are about what is ON SCREEN.
///
/// `drawHierarchy(afterScreenUpdates:)` does NOT work for an off-screen window — it yields an
/// all-black image, which during R7-collapse read as "every row has ink" until a darkness profile
/// caught it. `layer.render(in:)` over an OPAQUE fill is the form that works.
enum EngineInk {
    static func render(_ view: UIView) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = true
        return UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(view.bounds)
            view.layer.render(in: ctx.cgContext)
        }
    }

    /// The first row of `rect` (top-down, in POINTS) holding a pixel materially darker than the
    /// background. nil when the region has no ink.
    static func firstInkRow(in image: UIImage, rect: CGRect) -> CGFloat? {
        guard let cg = image.cgImage else { return nil }
        let scale = image.scale
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        let x0 = max(0, Int(rect.minX * scale)), x1 = min(width, Int(rect.maxX * scale))
        let y0 = max(0, Int(rect.minY * scale)), y1 = min(height, Int(rect.maxY * scale))
        guard x0 < x1, y0 < y1 else { return nil }
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * width + x) * 4
                if pixels[i] < 100 && pixels[i + 1] < 100 && pixels[i + 2] < 100 {
                    return CGFloat(y) / scale
                }
            }
        }
        return nil
    }
}
