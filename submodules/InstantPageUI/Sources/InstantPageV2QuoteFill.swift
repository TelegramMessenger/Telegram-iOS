import Foundation
import UIKit

/// Shared quote/code background: a rounded-rect fill at `accent`@`fillAlpha` with a leading
/// `barWidth`-wide accent bar clipped to the SAME rounded path (so the bar's outer corners follow
/// the fill's arc rather than an independent corner radius). Byte-for-byte port of the editor's
/// `BlockquoteUnderlay.fillImage()` (RichTextEditorUIKit). Returns a resizable image with symmetric
/// cap insets, so a run-tall frame stretches the 1px middle and allocates no large backing store.
func instantPageV2QuoteFillImage(accent: UIColor, barWidth: CGFloat, cornerRadius: CGFloat, fillAlpha: CGFloat) -> UIImage {
    let radius = cornerRadius
    let bar = barWidth
    let cap = max(radius, bar) + 1.0
    let side = cap * 2.0 + 2.0
    let size = CGSize(width: side, height: side)
    let image = UIGraphicsImageRenderer(size: size).image { context in
        let ctx = context.cgContext
        let rect = CGRect(origin: .zero, size: size)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        accent.withAlphaComponent(fillAlpha).setFill()
        path.fill()
        ctx.saveGState()
        path.addClip()
        accent.setFill()
        ctx.fill(CGRect(x: 0.0, y: 0.0, width: bar, height: size.height))
        ctx.restoreGState()
    }
    return image.resizableImage(withCapInsets: UIEdgeInsets(top: cap, left: cap, bottom: cap, right: cap), resizingMode: .stretch)
}
