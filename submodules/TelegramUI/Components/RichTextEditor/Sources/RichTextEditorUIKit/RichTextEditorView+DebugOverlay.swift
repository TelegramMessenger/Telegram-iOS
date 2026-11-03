#if DEBUG
#if canImport(UIKit)
import UIKit

@available(iOS 13.0, *)
extension RichTextEditorView {
    /// DEBUG-only switch that visualizes the editor's layout geometry. **On by default in DEBUG builds** —
    /// set it to `false` (in code or via lldb: `expression RichTextEditorView.debugShowLayoutOverlay = false`)
    /// to hide the overlay. Changes take effect on the next layout or scroll pass (type a character / scroll,
    /// or the next `update`). Compiled out of release builds entirely (`#if DEBUG`), so there is no flag,
    /// overlay, or hook in release.
    public static var debugShowLayoutOverlay = false

    /// Installs/updates (or removes) the layout-debug overlay to match `debugShowLayoutOverlay`. Called from
    /// `performLayout` and `scrollViewDidScroll`. Reads geometry through `bounds` / `debugContentInset` /
    /// `canvas`, so it needs no access to the private scroll view beyond the inset accessor. The overlay is
    /// the topmost, non-interactive subview, so it never perturbs real layout or hit-testing.
    func refreshDebugLayoutOverlay() {
        let existing = subviews.compactMap { $0 as? DebugLayoutOverlayView }.first
        guard RichTextEditorView.debugShowLayoutOverlay else {
            existing?.removeFromSuperview()
            return
        }
        let overlay = existing ?? {
            let v = DebugLayoutOverlayView()
            v.isUserInteractionEnabled = false
            v.backgroundColor = .clear
            v.contentMode = .redraw
            addSubview(v)
            return v
        }()
        overlay.frame = bounds
        bringSubviewToFront(overlay)
        // Block frames live in the (scrolling) canvas; convert them into the field's coordinate space so
        // the outlines track content scrolling.
        let blockRects = canvas.boxes.map { canvas.convert($0.frame, to: self) }
        overlay.update(insets: debugContentInset, margins: canvas.contentMargins, blockRects: blockRects)
    }
}

/// DEBUG-only overlay that draws the editor's frame, scroll insets, content margins, and per-block frames
/// as distinct translucent regions with small numeric labels. Insets and margins are drawn separately
/// because they are distinct concepts (non-interactive scroll bands vs. interior content padding).
@available(iOS 13.0, *)
final class DebugLayoutOverlayView: UIView {
    private var insets: UIEdgeInsets = .zero
    private var margins: UIEdgeInsets = .zero
    private var blockRects: [CGRect] = []

    func update(insets: UIEdgeInsets, margins: UIEdgeInsets, blockRects: [CGRect]) {
        self.insets = insets
        self.margins = margins
        self.blockRects = blockRects
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let frame = bounds

        // 1. Field frame — red outline.
        UIColor.systemRed.setStroke()
        ctx.setLineWidth(2)
        ctx.stroke(frame.insetBy(dx: 1, dy: 1))

        // 2. Scroll insets — blue translucent bands (the non-interactive regions content scrolls under).
        UIColor.systemBlue.withAlphaComponent(0.25).setFill()
        if insets.top > 0 { ctx.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: insets.top)) }
        if insets.bottom > 0 { ctx.fill(CGRect(x: frame.minX, y: frame.maxY - insets.bottom, width: frame.width, height: insets.bottom)) }
        if insets.left > 0 { ctx.fill(CGRect(x: frame.minX, y: frame.minY, width: insets.left, height: frame.height)) }
        if insets.right > 0 { ctx.fill(CGRect(x: frame.maxX - insets.right, y: frame.minY, width: insets.right, height: frame.height)) }

        // 3. Content margins — green ring just inside the content area (interior padding, distinct from insets).
        let contentRect = frame.inset(by: insets)
        let marginRect = contentRect.inset(by: margins)
        if margins != .zero, contentRect.width > 0, contentRect.height > 0 {
            UIColor.systemGreen.withAlphaComponent(0.25).setFill()
            ctx.saveGState()
            ctx.addRect(contentRect)
            ctx.addRect(marginRect)
            ctx.clip(using: .evenOdd)   // ring = contentRect minus marginRect
            ctx.fill(contentRect)
            ctx.restoreGState()
        }
        UIColor.systemGreen.setStroke()
        ctx.setLineWidth(1)
        ctx.stroke(marginRect)

        // 4. Per-block frames — orange outlines, indexed.
        UIColor.systemOrange.setStroke()
        ctx.setLineWidth(1)
        for (i, r) in blockRects.enumerated() {
            ctx.stroke(r)
            drawLabel("\(i)", at: CGPoint(x: r.minX + 2, y: r.minY + 1), color: .systemOrange)
        }

        // 5. Numeric labels for insets / margins.
        let lines: [(String, UIColor)] = [
            ("inset T\(Int(insets.top)) L\(Int(insets.left)) B\(Int(insets.bottom)) R\(Int(insets.right))", .systemBlue),
            ("margin T\(Int(margins.top)) L\(Int(margins.left)) B\(Int(margins.bottom)) R\(Int(margins.right))", .systemGreen),
        ]
        for (i, line) in lines.enumerated() {
            drawLabel(line.0, at: CGPoint(x: contentRect.minX + 4, y: contentRect.minY + 4 + CGFloat(i) * 13), color: line.1)
        }
    }

    private func drawLabel(_ text: String, at point: CGPoint, color: UIColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 9, weight: .bold),
            .foregroundColor: color,
            .backgroundColor: UIColor.black.withAlphaComponent(0.5),
        ]
        (text as NSString).draw(at: point, withAttributes: attrs)
    }
}
#endif
#endif
