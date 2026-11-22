import UIKit

/// The calibrated marker-pixel instrument, in one place so every hosted suite reads the SAME
/// predicate, the same render call and the same band.
///
/// The body is copied verbatim from
/// `Tests/RichTextEditorUIKitTests/StockParity/IDBlockSpellingIntegrationParityTests.swift`,
/// including both of its hard-won corrections — and neither is optional:
///
///   * **`layer.render(in:)`, never `drawHierarchy(in:afterScreenUpdates:)`.** The latter renders
///     nothing for a window that is not on a real screen and returned zero for a KNOWN red underline
///     once already, which was then very nearly reported as an environment limit.
///   * **the band is the whole line box plus 6pt below**, not a tight strip under the baseline: a
///     marker can be drawn below the rect `firstRect(for:)` reports.
///
/// `IDCountRedPixels` / `IDRenderView` (`Tests/StockParitySupport/IDStockParityPixels.m`, ported
/// verbatim from upstream's `IDTextCanvasTestSupport.m`) are the second, independent counter. Their
/// predicate is STRICTER than the Swift one, so the two disagreeing in magnitude is expected and the
/// two disagreeing about presence is a finding.
enum HostedPixelInstrument {

    /// `red` is what the misspelling marker paints; `ink` is every pixel that is not the white
    /// background. **`ink` exists to tell a real zero from a blank render** — the difference between
    /// a finding and an instrument bug.
    struct PixelCounts: CustomStringConvertible {
        var red = 0
        var ink = 0
        var description: String { "red=\(red) ink=\(ink)" }
    }

    static func pixels(in view: UIView, band: CGRect) -> PixelCounts {
        let bounds = view.bounds
        guard bounds.width > 1, bounds.height > 1 else { return PixelCounts() }
        let roi = band.intersection(bounds)
        guard !roi.isNull, roi.width >= 1, roi.height >= 1 else { return PixelCounts() }

        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }
        guard let cgImage = image.cgImage else { return PixelCounts() }

        let width = cgImage.width, height = cgImage.height
        var raw = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &raw, width: width, height: height,
                                      bitsPerComponent: 8, bytesPerRow: width * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return PixelCounts() }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let scale = CGFloat(width) / bounds.width
        let x0 = max(0, Int(roi.minX * scale)), x1 = min(width, Int(roi.maxX * scale))
        let y0 = max(0, Int(roi.minY * scale)), y1 = min(height, Int(roi.maxY * scale))
        var counts = PixelCounts()
        for y in y0..<max(y0, y1) {
            for x in x0..<max(x0, x1) {
                let i = (y * width + x) * 4
                let r = Int(raw[i]), g = Int(raw[i + 1]), b = Int(raw[i + 2]), a = Int(raw[i + 3])
                if a > 8 && !(r > 240 && g > 240 && b > 240) { counts.ink += 1 }
                if r > 96 && r - g > 48 && r - b > 48 { counts.red += 1 }
            }
        }
        return counts
    }

    /// The band a misspelling marker is drawn in, **expressed in `renderView`'s coordinates**.
    ///
    /// The conversion is the part that is easy to get wrong and impossible to see. `firstRect(for:)`
    /// answers in the coordinate space of the text-input view, and for a Telegram host that is the
    /// CANVAS, which is a scrolled subview of the `RichTextEditorView` the render is taken of. Using
    /// the unconverted rect samples the wrong strip of the image and reads zero — a false negative
    /// that looks exactly like the defect being measured.
    static func markerBand(_ input: UITextInput, characterRange: NSRange,
                           in renderView: UIView) -> CGRect? {
        guard let start = input.position(from: input.beginningOfDocument,
                                         offset: characterRange.location),
              let end = input.position(from: start, offset: characterRange.length),
              let range = input.textRange(from: start, to: end) else { return nil }
        let rect = input.firstRect(for: range)
        guard rect.width.isFinite, rect.height.isFinite, rect.width > 0, !rect.isInfinite else {
            return nil
        }
        let converted = (input as? UIView).map { renderView.convert(rect, from: $0) } ?? rect
        return converted.insetBy(dx: 0, dy: -6.0)
    }

    /// Upstream's own counter over the same band.
    static func upstreamRedPixels(in view: UIView, band: CGRect) -> Int {
        Int(IDCountRedPixels(IDRenderView(view), band))
    }
}
