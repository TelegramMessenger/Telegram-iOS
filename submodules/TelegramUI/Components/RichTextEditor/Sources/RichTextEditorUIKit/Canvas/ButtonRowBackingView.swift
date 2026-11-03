#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The backing view for one `ButtonRowBox`: hosts a `ButtonPillView` per pill instead of drawing the row
/// into its own bitmap, so a pill's label can carry a live custom emoji.
///
/// Mirrors `TableBackingView`'s arrangement — a `BlockBackingView` subclass that owns subviews and draws
/// nothing itself — and is selected by the same `box is …` arm in `DocumentCanvasView.realize`.
@available(iOS 13.0, *)
final class ButtonRowBackingView: BlockBackingView {
    private var pillViews: [ButtonPillView] = []
    private let menuPillView = ButtonRowMenuPillView()

    /// Nothing is drawn into the backing store: every pill is a subview. (`BlockBackingView.draw(_:)`
    /// would otherwise call `box.draw`, which for a row is a deliberate no-op.)
    override func draw(_ rect: CGRect) {}

    /// Re-hosts and re-frames the pills. Called from `layoutSubviews` and after any rebind, so a recycled
    /// view rebound to a different row cannot keep the previous row's pills.
    func syncPills() {
        guard let box = self.box as? ButtonRowBox, let canvas = self.canvas else {
            for view in pillViews { view.removeFromSuperview() }
            pillViews.removeAll()
            menuPillView.removeFromSuperview()
            return
        }

        // Pools positionally (pill *i* reuses view *i*), matching how the packing returns frames in model
        // order. A pill has no stable identity of its own — `ButtonRef` is a pure value.
        while pillViews.count > box.attachments.count {
            pillViews.removeLast().removeFromSuperview()
        }
        while pillViews.count < box.attachments.count {
            let view = ButtonPillView()
            addSubview(view)
            pillViews.append(view)
        }

        for (index, attachment) in box.attachments.enumerated() {
            guard box.pillFrames.indices.contains(index) else { continue }
            let view = pillViews[index]
            // `pillFrames` are box-local; the backing view's frame IS the box's frame, so they are also
            // view-local.
            //
            // The pill FILLS its slot — `pill.frame = entry.frame` is exactly what
            // `InstantPageV2ButtonRowView.layoutSubviews` does. A block pill's height is the fixed
            // 40pt touch target, NOT `attachment.size.height` (the label's ink box plus padding, ~20pt,
            // which is an INLINE pill's height). Shrinking it to the ink box made block rows read as
            // inline pills even though the packing had allocated the right space; the capsule radius is
            // `bounds.height / 2`, so it shrank too.
            view.configure(attachment: attachment, metrics: canvas.mapper.styleSheet.metrics.button)
            view.frame = box.pillFrames[index]
            view.syncEmoji(provider: canvas.emojiViewProvider, dynamicColor: attachment.colors.label)
        }

        // The trailing "…" — editor-only chrome, so it is positioned from `menuButtonFrame` rather than
        // from the packing (which stays V2-exact).
        if menuPillView.superview == nil {
            addSubview(menuPillView)
        }
        menuPillView.tintColorOverride = canvas.mapper.theme.accent
        menuPillView.frame = box.menuButtonFrame
        menuPillView.isHidden = !box.showsMenuAffordance
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        syncPills()
    }
}
#endif
