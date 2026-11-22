#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// The hosted view over a folded quote's atom: the ≤3-line preview and the expand glyph
/// (R7-collapse §4.3).
///
/// **It claims only the GLYPH's touches.** The view itself is passthrough, so a tap on the folded
/// body reaches the engine and places a caret at the atom's gap — legacy's invariant ("tap the body
/// to place the caret at the gap; tap the corner glyph to expand"), and the one place this rung does
/// NOT follow the media atom, whose host claims the poster and selects it.
@available(iOS 18.4, *)
internal final class CollapsedQuotePreviewView: UIView {
    internal let blockID: BlockID
    internal var onExpand: (() -> Void)?

    private let glyph = InflatedTouchGlyphView()
    private var leadingInset: CGFloat = 0
    private var trailingInset: CGFloat = 0

    /// The editor's OWN text layout, not a second one. Everything the overlays need comes from it:
    /// the baseline (§7), an emoji's box, a spoiler's rects. A `UILabel` could show the traits but
    /// hands out none of that, and a parallel layout built only to compute rects would be a second
    /// implementation of text layout — the one thing the seam exists to prevent.
    /// Where the expand glyph goes, in this view's own coordinates — supplied by the host from the
    /// quote's band, because the band is the rect that means the same thing folded and open.
    private var glyphFrame: CGRect?
    private var layout: RichTextBlockLayout?
    private var textOrigin: CGPoint = .zero

    /// Pooled by `EmojiRef.instanceID`, NOT by emoji id: the same sticker twice is two views, and
    /// re-vending on every layout would restart every animation — `syncCustomEmojiViews`'s rule.
    internal private(set) var emojiViews: [String: UIView & RichTextEmojiView] = [:]
    /// Where each hosted emoji sits in the preview string, so the spoiler pass can ask whether it is
    /// inside a hidden run. Keyed like `emojiViews`, and culled with it.
    private var emojiRanges: [String: NSRange] = [:]
    private var emojiProvider: ((String, CGSize) -> (UIView & RichTextEmojiView)?)?
    /// The preview's own text colour — the tint a template emoji takes, and the dust's colour.
    private var previewForeground: UIColor?

    internal private(set) var dustViews: [NSRange: SpoilerDustView] = [:]
    /// XCTest's window onto what was hidden. The ranges are the layout's, so a test can assert the
    /// hiding happened without reaching into TextKit's rendering attributes.
    internal private(set) var hiddenSpoilerRangesForTesting: [NSRange] = []
    /// XCTest's window onto where the expand glyph landed, so the toggle's two states can be
    /// compared without reaching into the view hierarchy for it.
    internal var glyphFrameForTesting: CGRect { glyph.frame }

    /// The room the expand glyph takes on the trailing side. ONE definition, read by `update` (to
    /// size the layout) and by `layoutSubviews` (to place the glyph): two copies of the glyph's
    /// width are two chances for the text column and the glyph to disagree about where one ends.
    private var glyphReserve: CGFloat {
        max(trailingInset, 0) + CollapsedQuoteGeometry.glyphSize + CollapsedQuoteGeometry.glyphGap
    }

    internal init(blockID: BlockID) {
        self.blockID = blockID
        super.init(frame: .zero)
        backgroundColor = .clear
        // Passthrough: only the glyph is interactive. `hitTest` below is what keeps the glyph
        // reachable despite this.
        isUserInteractionEnabled = false
        // Drawn, not subviewed: `draw(_:)` renders the layout. `contentMode = .redraw` because a
        // width change must RE-LAY-OUT rather than stretch the last rendering.
        isOpaque = false
        contentMode = .redraw
        glyph.isUserInteractionEnabled = true
        glyph.contentMode = .scaleAspectFit
        glyph.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleGlyphTap)))
        addSubview(glyph)
    }
    internal required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    /// The glyph is the only interactive part, so hit-testing goes straight to it: this view is
    /// `isUserInteractionEnabled = false`, and UIKit's own `hitTest` would otherwise refuse the
    /// whole subtree and make the glyph unreachable too.
    internal override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01 else { return nil }
        let local = convert(point, to: glyph)
        return glyph.point(inside: local, with: event) ? glyph : nil
    }

    /// `glyphFrame` is the expand glyph's box IN THIS VIEW'S COORDINATES, derived by the host from
    /// the quote's BAND so the glyph does not move when the quote is toggled
    /// (`quoteCollapseGlyphFrame`). nil falls back to this view's own trailing-top corner, which is
    /// only reachable on a pass where the quote has no band placed yet.
    internal func update(attachment: CollapsedQuoteTextAttachment, image: UIImage?, tint: UIColor,
                         glyphFrame: CGRect? = nil,
                         emojiProvider: ((String, CGSize) -> (UIView & RichTextEmojiView)?)? = nil) {
        self.glyphFrame = glyphFrame
        self.emojiProvider = emojiProvider
        previewForeground = attachment.attributes[.foregroundColor] as? UIColor
        leadingInset = attachment.leadingInset
        trailingInset = attachment.trailingInset
        let width = max(bounds.width - leadingInset - glyphReserve, 1)
        layout = richTextMakeBlockLayout(attributedString: attachment.previewText, width: width)
        // THE THREE-LINE CAP IS THE LAYOUT'S, not the string's. The box is already exactly
        // `maxPreviewLines * pitch` tall (`CollapsedQuoteTextAttachment.slot`), so without a cap here
        // the layout wraps on past the bottom of its own box and the overflow is simply not seen —
        // and with the truncation carried in the paragraph style instead, the text system truncates
        // the FIRST line rather than wrapping to three, which is what a device pass reported as "the
        // height is correct but it shows one ellipsized line".
        layout?.capLines(CollapsedQuoteGeometry.maxPreviewLines, truncating: .byTruncatingTail)
        // The text column starts at the quote's own leading inset. The vertical origin carries the
        // DIFFERENCE between two baselines, which is the whole of §7:
        //
        //   the layout puts its first baseline `firstLineBaselineFromTop` below the origin;
        //   an engine body line puts its own `firstBaselineFromTop(font)` below the block's top.
        //
        // The preview view's top IS the atom's block top, so drawing at y = 0 aligns the layout's
        // TOP rather than its baseline and the text sits high by exactly that difference (measured
        // at 1.33pt before this line existed). Both terms are READ — one from the layout, one from
        // the metrics contract the engine lays out by — so this stays a relationship rather than a
        // constant fitted to one font at one scale.
        // Both terms come from the LAYOUT, which is why this is a relationship and not a constant
        // fitted to one font at one scale:
        //
        //   `rawFirstBaselineFromTop`  — where TextKit actually draws, and where the ENGINE's own
        //                                blocks land (measured: block ink 4.67 below the block top).
        //   `firstLineBaselineFromTop` — the CORRECTED contract value, and where a bare layout's
        //                                `drawText` lands (measured: ink 3.33 below the origin).
        //
        // So the preview must draw one gap lower, or its text sits high by exactly that much. The
        // first two attempts at this line computed ZERO, because they compared the contract value
        // against itself — `firstLineBaselineFromTop` is what the layout REPORTS, not where it
        // draws. Only rendering both and scanning for ink told them apart.
        textOrigin = CGPoint(
            x: leadingInset,
            y: (layout?.rawFirstBaselineFromTop ?? 0) - (layout?.firstLineBaselineFromTop ?? 0))
        glyph.image = image ?? Self.drawnExpandGlyph
        glyph.tintColor = tint
        syncEmojiViews(in: attachment.previewText)
        syncSpoilers(in: attachment.previewText)
        setNeedsDisplay()
        setNeedsLayout()
    }

    /// One hosted view per `EmojiTextAttachment` in the preview, framed on the box the LAYOUT gives
    /// it — not on a selection rect, which is the LINE's height and would stretch the emoji
    /// (`syncCustomEmojiViews` records the measurement: 20.29 × 22.0 for a 17pt run).
    ///
    /// A MARKER is deliberately not hosted: `CollapsedQuoteMarkerAttachment` carries its own image
    /// and TextKit draws it, where an emoji's attachment is a spacer whose picture is a live view.
    private func syncEmojiViews(in text: NSAttributedString) {
        guard let layout else { return }
        var live: Set<String> = []
        text.enumerateAttribute(.attachment, in: NSRange(location: 0, length: text.length),
                                options: []) { value, range, _ in
            guard let emoji = value as? EmojiTextAttachment else { return }
            guard let box = layout.attachmentBox(at: range.location),
                  box.width > 0, box.height > 0 else { return }
            live.insert(emoji.ref.instanceID)
            emojiRanges[emoji.ref.instanceID] = range
            let view: UIView & RichTextEmojiView
            if let existing = emojiViews[emoji.ref.instanceID] {
                view = existing
            } else {
                guard let fresh = emojiProvider?(emoji.ref.id, box.size) else { return }
                fresh.isUserInteractionEnabled = false
                addSubview(fresh)
                emojiViews[emoji.ref.instanceID] = fresh
                view = fresh
            }
            view.frame = box.offsetBy(dx: textOrigin.x, dy: textOrigin.y)
            // Re-pushed every pass, as `syncCustomEmojiViews` does: a template emoji takes the
            // preview's own text colour, and a full-colour one ignores it.
            view.dynamicColor = previewForeground
        }
        for (id, view) in emojiViews where !live.contains(id) {
            view.removeFromSuperview()
            emojiViews[id] = nil
            emojiRanges[id] = nil
        }
    }

    internal override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard let layout, let ctx = UIGraphicsGetCurrentContext() else { return }
        layout.drawText(in: ctx, at: textOrigin)
    }

    internal override func layoutSubviews() {
        super.layoutSubviews()
        let side = CollapsedQuoteGeometry.glyphSize
        // The layout is sized here too: `update` runs before the view has its final bounds on the
        // first pass, and a layout at the wrong width would break the line in the wrong place.
        layout?.setWidth(max(bounds.width - leadingInset - glyphReserve, 1))
        glyph.frame = glyphFrame ?? CGRect(
            x: bounds.maxX - CollapsedQuoteGeometry.glyphCornerInset - side,
            y: bounds.minY + CollapsedQuoteGeometry.glyphCornerInset,
            width: side, height: side)
    }

    @objc private func handleGlyphTap() { onExpand?() }

    /// XCTest's door to the glyph's action. A `UITapGestureRecognizer` cannot be fired without a
    /// real touch, and driving one through `UIApplication` from a unit test would be testing the
    /// harness rather than the editor. The UI-level check is the K3 pass's.
    internal func simulateGlyphTapForTesting() { onExpand?() }

    /// Hide the glyphs, hide the hosted views, draw the dust — ONE pass with ONE answer.
    ///
    /// **The middle step is the one that is easy to miss and the one that leaks.** A spoiler hides
    /// TEXT with a foreground colour, which does nothing to a hosted view: the emoji would sit fully
    /// visible behind the dust, showing exactly what the spoiler exists to conceal.
    /// `+CustomEmoji.swift` records that LEGACY HAS THIS BUG TODAY, and it is worse in a folded
    /// quote, where a reader cannot open the spoiler to check.
    ///
    /// Every spoiler here is hidden, always — and that is the editor's EXISTING rule applied, not a
    /// new one. Its single definition is "the selection reveals a run it is inside", and a folded
    /// quote's content is off the engine's axis, so a selection can never be inside it.
    private func syncSpoilers(in text: NSAttributedString) {
        guard let layout else { return }
        var runs: [NSRange] = []
        text.enumerateAttribute(RichTextEngineEditorView.spoilerAttributeKey,
                                in: NSRange(location: 0, length: text.length), options: []) { value, range, _ in
            if (value as? Bool) == true { runs.append(range) }
        }
        hiddenSpoilerRangesForTesting = runs
        layout.setSpoilerHidden(runs)

        // The hosted views inside a hidden run go with it. Read from `emojiRanges`, which
        // `syncEmojiViews` wrote as it walked — not re-derived here, or the two walks could disagree
        // about where an emoji is.
        for (id, view) in emojiViews {
            guard let range = emojiRanges[id] else { continue }
            view.isHidden = runs.contains { NSIntersectionRange($0, range).length > 0 }
        }

        var live: Set<NSRange> = []
        for run in runs {
            let rects = layout.selectionRects(start: run.location, end: run.location + run.length)
                .map { $0.offsetBy(dx: textOrigin.x, dy: textOrigin.y) }
            let bounding = rects.reduce(CGRect.null) { $0.union($1) }
            guard !bounding.isNull, bounding.width > 0, bounding.height > 0 else { continue }
            live.insert(run)
            let dust: SpoilerDustView
            if let existing = dustViews[run] {
                dust = existing
            } else {
                let fresh = SpoilerDustView(frame: bounding)
                fresh.isUserInteractionEnabled = false
                addSubview(fresh)
                dustViews[run] = fresh
                dust = fresh
            }
            dust.frame = bounding
            let local = rects.map { $0.offsetBy(dx: -bounding.minX, dy: -bounding.minY) }
            dust.update(size: bounding.size, color: previewForeground ?? .label,
                        lineRects: local, wordRects: local)
        }
        for (run, dust) in dustViews where !live.contains(run) {
            dust.removeFromSuperview()
            dustViews[run] = nil
        }
    }

    /// The fallback when the host supplies no `quoteCollapseIcons`, so a quote is unfoldable whether
    /// or not a host configures artwork — the rule `detailsChevronImage` already follows.
    private static let drawnExpandGlyph: UIImage = {
        let side = CollapsedQuoteGeometry.glyphSize
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: side * 0.30, y: side * 0.42))
            path.addLine(to: CGPoint(x: side * 0.50, y: side * 0.62))
            path.addLine(to: CGPoint(x: side * 0.70, y: side * 0.42))
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.label.setStroke()
            path.stroke()
        }.withRenderingMode(.alwaysTemplate)
    }()
}
#endif
