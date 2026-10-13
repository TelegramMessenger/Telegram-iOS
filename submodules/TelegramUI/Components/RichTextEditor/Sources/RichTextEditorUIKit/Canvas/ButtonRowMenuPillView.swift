#if canImport(UIKit)
import UIKit

/// The trailing "…" affordance in a button row — editor-only chrome that opens the row's menu
/// (Add Button / Alignment / Delete Row). Drawn as a dashed circle so it reads as a control rather
/// than a real, labelled pill.
///
/// Passthrough like `ButtonPillView`: the tap is resolved by the canvas's own recognizers through
/// `ButtonRowBox.hitsMenuButton(atCanvasPoint:)`, preserving the sole-`UITextInput` invariant.
@available(iOS 13.0, *)
final class ButtonRowMenuPillView: UIView {
    var tintColorOverride: UIColor = .systemBlue {
        didSet {
            if tintColorOverride != oldValue { setNeedsDisplay() }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), bounds.width > 2, bounds.height > 2 else {
            return
        }
        let circle = bounds.insetBy(dx: 1.0, dy: 1.0)
        ctx.setStrokeColor(tintColorOverride.withAlphaComponent(0.5).cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineDash(phase: 0.0, lengths: [4.0, 3.0])
        ctx.strokeEllipse(in: circle)
        ctx.setLineDash(phase: 0.0, lengths: [])

        let dotRadius: CGFloat = 1.75
        let gap: CGFloat = 5.0
        let centre = CGPoint(x: circle.midX, y: circle.midY)
        ctx.setFillColor(tintColorOverride.cgColor)
        for offset in [-gap, 0.0, gap] {
            ctx.fillEllipse(in: CGRect(x: centre.x + offset - dotRadius, y: centre.y - dotRadius,
                                       width: dotRadius * 2.0, height: dotRadius * 2.0))
        }
    }
}
#endif
