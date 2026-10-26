#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Folding a block quote: the body moves BETWEEN the engine and the role's shape, never copied, so
/// there is only ever one of it (R7-collapse §5). `+Details.swift`'s `setExpanded` is this
/// function's twin and carries the same three caret arms for the same reasons.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// §5. The glyph's action, and the one a host menu would call if this rung had given it one.
    public func toggleQuoteCollapsed(id: BlockID) {
        guard case let .blockQuote(block)? = document.blocksByID[id] else { return }
        setCollapsed(!block.collapsed, forQuoteWithID: id, block: block)
    }

    /// The fold both directions share. It rebuilds through the DOCUMENT — the model already holds
    /// the body, and flipping `collapsed` lets `flatten` decide what reaches the engine, so the body
    /// moves across for free.
    private func setCollapsed(_ collapsed: Bool, forQuoteWithID id: BlockID, block: BlockQuote) {
        let before = document
        let selectionBefore = engineSelectedRange
        guard let spanBefore = quoteSpan(ofQuoteWithID: id) else { return }
        let spanStartBefore = flatOffset(ofRoleAt: spanBefore.lowerBound)
        let spanEndBefore = flatOffset(ofRoleAt: spanBefore.upperBound)
            + flatLength(ofRoleAt: spanBefore.upperBound)
        // A fold ADDS or REMOVES the whole body from the axis, so every offset past the block moves
        // by exactly that much. Restoring the absolute offset left the caret on different text in
        // the details case (K3, 2026-09-08).
        //
        // The two OVERLAP at the span's end, deliberately, and that is what makes the order below
        // load-bearing rather than decorative. For a FOLDED quote the atom's end IS the span's end,
        // and the atom's end is exactly where Backspace parks a caret arriving from the block after
        // it — so a caret there is ON the quote and must be claimed by the first arm. Spelt with
        // `inside` excluding `after` the two became mutually exclusive, the order stopped meaning
        // anything, and unfolding from that parked caret threw it to the end of the body the unfold
        // had just revealed. That is the same defect `+Details.swift` records for a folded title's
        // end, one container kind over.
        let caretWasInside = selectionBefore.location >= spanStartBefore
            && selectionBefore.location <= spanEndBefore
        let caretWasAfterTheBlock = selectionBefore.location >= spanEndBefore

        var updated = block
        updated.collapsed = collapsed
        deliveringOneChangeNotification {
            document = before.replacingBlock(withID: id, with: .blockQuote(updated))
            guard let spanAfter = quoteSpan(ofQuoteWithID: id) else { return }
            if caretWasInside {
                // FIRST, and that order is the whole of it: for a FOLDED quote the atom's end IS the
                // span's end, so the "after the block" test below would claim it too.
                engineSelectedRange = NSRange(location: flatOffset(ofRoleAt: spanAfter.lowerBound),
                                              length: 0)
            } else if caretWasAfterTheBlock {
                let spanEndAfter = flatOffset(ofRoleAt: spanAfter.upperBound)
                    + flatLength(ofRoleAt: spanAfter.upperBound)
                engineSelectedRange = NSRange(
                    location: max(0, selectionBefore.location + (spanEndAfter - spanEndBefore)),
                    length: selectionBefore.length)
            } else {
                // Before the quote: nothing at or before the block moved. A RANGE, not a caret —
                // this arm PRESERVES a selection that need not be collapsed, and `NSRange` keeps
                // both endpoints as they were.
                engineSelectedRange = selectionBefore
            }
        }
        recordUndoStepForStructuralChange(restoring: before, selection: selectionBefore)
    }

    /// The role range the quote `id` occupies, folded or open.
    ///
    /// TWO doors, because the two states are different role shapes: folded, the quote is a LEAF and
    /// its span is the single atom role; open, it is an ANCESTOR and `span(of:around:)` answers.
    /// Asked only as the ancestor question, a folded quote has no span at all and the toggle would
    /// silently do nothing.
    internal func quoteSpan(ofQuoteWithID id: BlockID) -> ClosedRange<Int>? {
        if let atom = currentRoles.firstIndex(where: { $0.shape.collapsedQuote?.id == id }) {
            return atom...atom
        }
        guard let inside = currentRoles.firstIndex(where: { $0.isWithin(id) }) else { return nil }
        return span(of: id, around: inside)
    }

    // MARK: - The preview view (§4.3)

    /// Reconciles preview views against the folded quotes in the current document. Idempotent;
    /// driven from `layoutSubviews` once the engine has laid out, like every other hosted overlay.
    internal func syncCollapsedQuoteViews() {
        guard !currentRoles.isEmpty || !collapsedQuoteViews.isEmpty else { return }
        var live: Set<BlockID> = []
        for index in currentRoles.indices {
            guard let shape = currentRoles[index].shape.collapsedQuote else { continue }
            // The ATTACHMENT's own frame, not a selection rect: a selection rect is the LINE's
            // height, which for an atom is not the atom's box.
            let frame = engine.id_attachmentFrame(forCanonicalOffset: UInt(flatOffset(ofRoleAt: index)))
            // CGRectNull is the engine's answer for an unknown offset — never treated as a rect.
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }
            guard let attachment = collapsedQuoteAttachment(atRoleAt: index) else { continue }
            live.insert(shape.id)

            let view: CollapsedQuotePreviewView
            if let existing = collapsedQuoteViews[shape.id] {
                view = existing
            } else {
                let fresh = CollapsedQuotePreviewView(blockID: shape.id)
                let id = shape.id
                fresh.onExpand = { [weak self] in self?.toggleQuoteCollapsed(id: id) }
                // Into the ENGINE, which is a scroll view, because `id_attachmentFrame` answers in
                // its CONTENT space. Parented to the editor instead, the view would be correct only
                // while `contentOffset` is zero and then stay pinned as its text scrolled away.
                engine.addSubview(fresh)
                collapsedQuoteViews[shape.id] = fresh
                view = fresh
            }
            view.frame = frame
            // The glyph is placed against the BAND, not against this view — see
            // `quoteCollapseGlyphFrame`. The decoration pass runs earlier in `layoutSubviews`, so the
            // band is this pass's, not the previous one's. Converted into the preview's own space
            // because that is where the glyph is hosted; a quote whose band has not been placed yet
            // falls back to the view's own corner, which is where it was before and is only ever
            // seen on a pass that has no band to be consistent with.
            let glyphFrame = containerDecorationViews[shape.id].map {
                view.convert(Self.quoteCollapseGlyphFrame(inBand: $0.frame), from: engine)
            }
            view.update(attachment: attachment,
                        image: deferredConfiguration.quoteCollapseIcons?.expand,
                        tint: composerHostState.theme.secondaryText,
                        glyphFrame: glyphFrame,
                        emojiProvider: deferredConfiguration.emojiViewProvider)
        }

        for (id, view) in collapsedQuoteViews where !live.contains(id) {
            view.removeFromSuperview()
            collapsedQuoteViews[id] = nil
        }
    }

    // MARK: - The collapse glyph on an OPEN quote (§4.4)

    /// Whether an OPEN quote is worth folding: taller than the preview a fold would leave.
    ///
    /// Measured against the engine's LAID-OUT frames rather than re-measured, which is both cheaper
    /// and the only way to be sure the question is being asked about what is on screen.
    ///
    /// The quote's own `#author` line is EXCLUDED, matching legacy's `isCollapsible`, which measures
    /// the child stack alone: an attribution is not content the fold is hiding, and counting it would
    /// make a two-line quote with an author claim it was worth folding.
    internal func quoteIsCollapsible(_ span: ClosedRange<Int>) -> Bool {
        var content = CGRect.null
        for index in span where !currentRoles[index].isOwnedByAnAncestorContainer {
            let frame = engine.id_frameForBlock(at: UInt(index))
            guard !frame.isNull, frame.height > 0 else { continue }
            content = content.isNull ? frame : content.union(frame)
        }
        guard !content.isNull else { return false }
        let font = bridge.styleSheet.font(for: .body, attributes: .plain)
        let pitch = RichTextRenderMetrics.linePitch(
            font, factor: bridge.styleSheet.metrics.body.lineSpacingFactor)
        return content.height > pitch * CGFloat(CollapsedQuoteGeometry.maxPreviewLines)
    }

    /// WHERE the collapse/expand glyph sits: the trailing-top corner of the quote's BAND, in the
    /// band's own coordinate space.
    ///
    /// **ONE derivation, because the glyph must not MOVE when the quote is toggled.** The two states
    /// draw different glyphs from different pools — an open quote's collapse glyph is placed by the
    /// decoration pass, a folded one's expand glyph lives in its preview view — and each spelled this
    /// corner against the rect it happened to have. They are not the same rect: the preview view's
    /// frame is the ATOM's, which is the band inset by the quote's interior padding, so the glyph
    /// dropped by exactly that padding (measured 8pt: y 16 open, y 24 folded) every time a quote was
    /// folded. The BAND is the right reference for both — it is legacy's own
    /// (`BlockQuoteBox.expandGlyphRect()` insets from the quote BOX's corner, which is what the band
    /// draws) and it is the one rect that means the same thing in both states.
    internal static func quoteCollapseGlyphFrame(inBand band: CGRect) -> CGRect {
        let side = CollapsedQuoteGeometry.glyphSize
        let inset = CollapsedQuoteGeometry.glyphCornerInset
        return CGRect(x: band.maxX - inset - side, y: band.minY + inset, width: side, height: side)
    }

    /// The collapse glyph for one OPEN quote, in the band's trailing-top corner. Removed when the
    /// quote is not worth folding, so the pool's keys are exactly the quotes that show one.
    ///
    /// Returns whether a glyph is live for this quote, which the decoration pass's cull NEEDS: that
    /// pass's own `live` set is BANDS, and a folded quote still has one of those — culling against it
    /// would leave a collapse glyph on screen after the fold, floating over its own preview.
    @discardableResult
    internal func syncQuoteCollapseGlyph(quoteID: BlockID, band: CGRect,
                                         span: ClosedRange<Int>) -> Bool {
        guard band.width > 0, band.height > 0, quoteIsCollapsible(span) else {
            if let existing = quoteCollapseGlyphViews.removeValue(forKey: quoteID) {
                existing.removeFromSuperview()
            }
            return false
        }
        let glyph: InflatedTouchGlyphView
        if let existing = quoteCollapseGlyphViews[quoteID] {
            glyph = existing
        } else {
            let fresh = InflatedTouchGlyphView()
            fresh.contentMode = .scaleAspectFit
            fresh.isUserInteractionEnabled = true
            fresh.addGestureRecognizer(gatedTapRecognizer(action: #selector(handleQuoteCollapseGlyphTap(_:))))
            engine.addSubview(fresh)
            quoteCollapseGlyphViews[quoteID] = fresh
            glyph = fresh
        }
        glyph.image = deferredConfiguration.quoteCollapseIcons?.collapse ?? Self.drawnCollapseGlyph
        glyph.tintColor = composerHostState.theme.secondaryText
        glyph.frame = Self.quoteCollapseGlyphFrame(inBand: band)
        return true
    }

    @objc internal func handleQuoteCollapseGlyphTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view,
              let id = quoteCollapseGlyphViews.first(where: { $0.value === view })?.key else { return }
        toggleQuoteCollapsed(id: id)
    }

    /// Whether `point` (engine content space) is inside a collapse glyph's OWN box — never its
    /// inflated target. See `textInteractionMayBegin`'s note on the details chevron for what the
    /// inflated spelling cost there.
    internal func quoteCollapseGlyphContains(_ point: CGPoint) -> Bool {
        quoteCollapseGlyphViews.values.contains { $0.frame.contains(point) }
    }

    /// The fallback when the host supplies no `quoteCollapseIcons` — an inward chevron, the mirror
    /// of the preview view's outward one.
    private static let drawnCollapseGlyph: UIImage = {
        let side = CollapsedQuoteGeometry.glyphSize
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            let path = UIBezierPath()
            path.move(to: CGPoint(x: side * 0.30, y: side * 0.58))
            path.addLine(to: CGPoint(x: side * 0.50, y: side * 0.38))
            path.addLine(to: CGPoint(x: side * 0.70, y: side * 0.58))
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            UIColor.label.setStroke()
            path.stroke()
        }.withRenderingMode(.alwaysTemplate)
    }()

    /// The atom's own attachment, read off the engine's text rather than rebuilt.
    ///
    /// That is the point: the measurement and the drawing then cannot disagree about what is on
    /// screen, which is the one way a three-line cap can be wrong without anything looking wrong.
    internal func collapsedQuoteAttachment(atRoleAt index: Int) -> CollapsedQuoteTextAttachment? {
        let blocks = engine.attributedBlocks
        guard index >= 0, index < blocks.count, blocks[index].length > 0 else { return nil }
        return blocks[index].attribute(.attachment, at: 0, effectiveRange: nil)
            as? CollapsedQuoteTextAttachment
    }
}
#endif
