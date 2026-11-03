#if canImport(UIKit)
import UIKit
import CoreText
import RichTextEditorCore

/// One rendered pill — a capsule fill plus its label — used by BOTH pill kinds: a block row's pills are
/// subviews of `ButtonRowBackingView`, an inline `textButton`'s pill is hosted in the canvas overlay at
/// its attachment's rect (mirroring how an inline emoji's host view is placed).
///
/// **A pill is a VIEW, not a rasterised image, because a label can contain a custom emoji** — which needs
/// a live host view (`InlineStickerItemLayer`) that a bitmap can never carry. The V2 renderer draws pills
/// as views for the same reason.
///
/// It is NOT interactive: taps still reach the canvas's own recognizers, which resolve a pill through
/// `ButtonRowBox.pillIndex(atCanvasPoint:)`. Keeping it passthrough preserves the canvas's
/// sole-`UITextInput` invariant.
@available(iOS 13.0, *)
final class ButtonPillView: UIView {
    private(set) var labelString: NSAttributedString = NSAttributedString()
    private var horizontalPadding: CGFloat = 0.0
    private var ascent: CGFloat = 0.0
    private var colors: (fill: UIColor, label: UIColor) = (.clear, .label)
    /// The host-supplied type icon and the trailing width the measurement held for it. Both come from
    /// the attachment, so what is drawn and what was reserved cannot disagree.
    private var icon: RichTextButtonIcon?
    private var iconReserve: CGFloat = 0.0
    private var isBlockPill: Bool = false
    private var blockIconInset: CGPoint = .zero

    /// Emoji host views inside this pill's label, pooled by `EmojiRef.instanceID` exactly as the canvas
    /// pools body-text emoji — so a re-layout reuses the same view and its animation survives.
    private var emojiViews: [String: UIView & RichTextEmojiView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        // LOAD-BEARING: `clipsToBounds` is what makes the capsule a capsule when a label overflows, and
        // it is why the pill must not host anything it needs to draw outside its own bounds.
        clipsToBounds = true
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    func configure(attachment: ButtonTextAttachment, metrics: RichTextButtonMetrics) {
        self.labelString = attachment.labelString
        self.horizontalPadding = attachment.horizontalPadding
        self.ascent = attachment.ascent
        self.colors = attachment.colors
        self.icon = attachment.icon
        self.iconReserve = attachment.iconReserve
        self.isBlockPill = attachment.isBlockPill
        self.blockIconInset = metrics.blockIconInset
        setNeedsDisplay()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2.0
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), bounds.width > 0, bounds.height > 0 else {
            return
        }
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2.0)
        ctx.addPath(path.cgPath)
        ctx.setFillColor(colors.fill.cgColor)
        ctx.fillPath()

        // Recoloured HERE, not baked into `labelString` at measurement time: the mapper bakes the
        // PARAGRAPH's foreground and has no notion of a pill's colour role, so a danger/success label
        // would otherwise render in body-text colour and a disabled one would never dim.
        let recoloured = NSMutableAttributedString(attributedString: labelString)
        recoloured.addAttribute(.foregroundColor, value: colors.label,
                                range: NSRange(location: 0, length: recoloured.length))
        recoloured.draw(at: labelOrigin())

        // The action's type icon, drawn after the label so a pill too narrow for both keeps the icon
        // rather than losing it under the text.
        // Tinted here rather than at measurement, for the same reason the label is: the pill's colour
        // role is resolved with the theme, and a `danger`/disabled icon must dim with its text.
        if let image = icon?.image(colors.label), let frame = iconFrame(image) {
            image.draw(in: frame)
        }
    }

    /// Where the type icon lands, in pill-local coordinates, or nil when there is none.
    ///
    /// Mirrors the V2 renderer (`instantPageInlineButtonIconFrame` / the block badge in
    /// `InstantPageV2ButtonPillContentView`). An INLINE icon trails the label — an inline pill is the
    /// label's ink box plus 2pt, with nowhere to put a corner badge, so the pill was measured
    /// `iconReserve` wider to hold this. A BLOCK pill is a 40pt touch target and has the room for the
    /// badge, whose clearance comes from the packer's side inset rather than from the pill's width.
    ///
    /// The icon is drawn at its own natural size, so the reserve and the drawn ink stay consistent even
    /// if the host ever supplies a differently sized asset: the gap absorbs the difference and the
    /// trailing edge still lands on the pill's padding.
    private func iconFrame(_ icon: UIImage) -> CGRect? {
        guard bounds.width > 0, bounds.height > 0 else {
            return nil
        }
        if isBlockPill {
            return CGRect(origin: CGPoint(x: bounds.width - blockIconInset.x - icon.size.width,
                                          y: blockIconInset.y),
                          size: icon.size)
        }
        let origin = labelOrigin()
        let inkWidth = labelString.length > 0
            ? CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(labelString), nil, nil, nil))
            : 0.0
        // The reserve is the gap plus the icon, so the gap is whatever the icon does not take.
        let spacing = max(0.0, iconReserve - icon.size.width)
        // Centred on the label's CAP box rather than on the pill box: the pill's box is asymmetric
        // around the text because it also holds the descender, so pill-centring reads visibly low.
        let baselineY = origin.y + ascent
        let capHeight = (labelString.length > 0
            ? (labelString.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)?.capHeight
            : nil) ?? 0.0
        return CGRect(origin: CGPoint(x: origin.x + inkWidth + spacing,
                                      y: baselineY - capHeight / 2.0 - icon.size.height / 2.0),
                      size: icon.size)
    }

    /// Top-left of the label's drawing box, centred within whatever width the pill was given. In justify
    /// mode that width is the stretched column, wider than the label's natural pill.
    private func labelOrigin() -> CGPoint {
        let inkWidth = labelString.length > 0
            ? CGFloat(CTLineGetTypographicBounds(CTLineCreateWithAttributedString(labelString), nil, nil, nil))
            : 0.0
        // The icon's reserve is trailing room belonging to the label+icon GROUP, so it comes off the
        // width the label centres within — otherwise the label slides right by half of it and the
        // hosted emoji, which are placed from this origin, slide with it.
        let x = max(horizontalPadding, (bounds.width - inkWidth - iconReserve) / 2.0)
        let labelHeight = labelString.size().height
        return CGPoint(x: x, y: max(0.0, (bounds.height - labelHeight) / 2.0))
    }

    /// Hosts a live view for each custom emoji in the label. `provider` is the canvas's own
    /// `emojiViewProvider`, so a pill emoji is rendered by exactly the same host machinery as a body one.
    ///
    /// Called on every layout pass; the pooling makes a re-sync cheap and keeps a running animation alive.
    func syncEmoji(provider: (_ id: String, _ size: CGSize) -> (UIView & RichTextEmojiView)?,
                   dynamicColor: UIColor) {
        guard labelString.length > 0 else {
            for (_, view) in emojiViews { view.removeFromSuperview() }
            emojiViews.removeAll()
            return
        }
        let line = CTLineCreateWithAttributedString(labelString)
        let origin = labelOrigin()
        var present = Set<String>()

        labelString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: labelString.length), options: []) { value, range, _ in
            guard let emoji = value as? EmojiTextAttachment else {
                return
            }
            let font = labelString.attribute(.font, at: range.location, effectiveRange: nil) as? UIFont
            let side = ((font?.ascender ?? 0.0) - (font?.descender ?? 0.0)) * emoji.scale
            guard side > 0 else {
                return
            }
            let x = origin.x + CTLineGetOffsetForStringIndex(line, range.location, nil)
            // The label box's baseline is `ascent` down from its top; the square spans descender→ascender
            // and sits on the baseline, exactly as `EmojiTextAttachment.box(for:)` defines it.
            let baselineY = origin.y + ascent
            let frame = CGRect(x: x, y: baselineY - side - (font?.descender ?? 0.0), width: side, height: side)

            present.insert(emoji.ref.instanceID)
            let view: UIView & RichTextEmojiView
            if let existing = emojiViews[emoji.ref.instanceID] {
                view = existing
            } else if let fresh = provider(emoji.ref.id, frame.size) {
                fresh.isUserInteractionEnabled = false
                emojiViews[emoji.ref.instanceID] = fresh
                addSubview(fresh)
                view = fresh
            } else {
                return   // no view available yet; retried on the next layout pass
            }
            // A template emoji tints to the PILL's label colour, not the body text colour — the same
            // reason the label itself is recoloured here rather than at construction.
            view.dynamicColor = dynamicColor
            view.frame = frame
        }

        for (instanceID, view) in emojiViews where !present.contains(instanceID) {
            view.removeFromSuperview()
            emojiViews[instanceID] = nil
        }
    }
}
#endif
