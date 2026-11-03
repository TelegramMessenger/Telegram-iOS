#if canImport(UIKit)
import UIKit

/// Back-most, non-drawing container that hosts one stretchable-image `UIImageView` per blockquote run,
/// so the run's rounded fill + leading bar render BEHIND the quote paragraphs' (clear-backed) block
/// views. A resizable image stretches a tiny bitmap via the layer's `contentsCenter` on the GPU, so a
/// run-tall frame allocates no large backing store — the size-safe replacement for drawing the fill
/// into the (document-sized) canvas context.
@available(iOS 13.0, *)
final class BlockquoteUnderlay: UIView {
    private var pool: [Int: UIImageView] = [:]   // keyed by run index (stable order along the document)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = false
        // `registerForTraitChanges` is iOS 17+; on iOS 16 the `traitCollectionDidChange` override below
        // provides the same light↔dark rebuild.
        if #available(iOS 17.0, *) {
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: BlockquoteUnderlay, _: UITraitCollection) in
                view.rebuildFillForAppearanceChange()
            }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    // iOS-16 fallback for the iOS-17 `registerForTraitChanges` registered in init. (Deprecated on iOS 17+,
    // where the registration handles appearance changes; the guard avoids a redundant rebuild there.)
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard #unavailable(iOS 17.0) else { return }
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            rebuildFillForAppearanceChange()
        }
    }

    /// A system appearance switch (light↔dark) only fires trait callbacks, not `layoutSubviews`, so the
    /// cached (appearance-baked) fill image would otherwise go stale until the next relayout. Rebuild it
    /// and re-apply to the visible views so the quote fill tracks the system appearance live.
    private func rebuildFillForAppearanceChange() {
        cachedImage = nil
        let image = fillImage()
        for iv in pool.values where !iv.isHidden { iv.image = image }
    }

    /// The bar + fill color. Defaults to `.systemBlue` (prior behavior); set from the editor theme's accent.
    var accentColor: UIColor = .systemBlue {
        didSet {
            cachedImage = nil
            rebuildFillForAppearanceChange()
        }
    }
    /// Leading-bar width (points). Set from `QuoteStyle.barWidth`; invalidates the cached fill image.
    var barWidth: CGFloat = 3 { didSet { guard barWidth != oldValue else { return }; cachedImage = nil; rebuildFillForAppearanceChange() } }
    /// Fill/bar corner radius (points). Set from `QuoteStyle.cornerRadius`.
    var cornerRadius: CGFloat = DocumentCanvasView.blockquoteCornerRadius { didSet { guard cornerRadius != oldValue else { return }; cachedImage = nil; rebuildFillForAppearanceChange() } }
    /// Fill opacity (0…1). Set from `QuoteStyle.fillAlpha`.
    var fillAlpha: CGFloat = 0.10 { didSet { guard fillAlpha != oldValue else { return }; cachedImage = nil; rebuildFillForAppearanceChange() } }

    /// The cached resizable fill+bar image, rebuilt on a trait change (light/dark, tint).
    private var cachedImage: UIImage?
    private var cachedTraits: UITraitCollection?

    private func fillImage() -> UIImage {
        if let img = cachedImage, cachedTraits == traitCollection { return img }
        let radius = self.cornerRadius
        let bar: CGFloat = self.barWidth
        let cap = max(radius, bar) + 1
        let side = cap * 2 + 2
        let size = CGSize(width: side, height: side)
        let img = UIGraphicsImageRenderer(size: size).image { c in
            let ctx = c.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            accentColor.withAlphaComponent(self.fillAlpha).setFill(); path.fill()
            ctx.saveGState(); path.addClip()
            accentColor.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: bar, height: size.height))
            ctx.restoreGState()
        }.resizableImage(withCapInsets: UIEdgeInsets(top: cap, left: cap, bottom: cap, right: cap),
                         resizingMode: .stretch)
        cachedImage = img; cachedTraits = traitCollection
        return img
    }

    /// Reconciles one image view per run rect (canvas coords). Reuses pooled views by index.
    func sync(runFills: [CGRect]) {
        let image = fillImage()
        for (i, fill) in runFills.enumerated() {
            let iv = pool[i] ?? {
                let v = UIImageView(); v.isUserInteractionEnabled = false
                pool[i] = v; addSubview(v); return v
            }()
            iv.image = image
            iv.frame = fill
            iv.isHidden = false
        }
        for (i, iv) in pool where i >= runFills.count { iv.isHidden = true }
    }
}
#endif
