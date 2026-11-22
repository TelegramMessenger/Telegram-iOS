#if canImport(UIKit)
import UIKit
import RichTextEditorCore

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// Inserts an inline emoji (one `U+FFFC` carrying an `EmojiRef`) at the caret, in whatever leaf
    /// region (body paragraph / image caption / table cell) owns it. Clears any selection first. The
    /// emoji is a 1-UTF-16 character, so this is an in-place text insert — no block split. Caret lands
    /// after the emoji. No-op when the caret is on a structural slot with no owning leaf region (e.g. an
    /// image gap) — unlike `insertText`, a gap caret is a no-op here, not a paragraph-spawn (there is no
    /// inline place to put the emoji). Wrapped in `editing { }` (one undo step).
    func insertEmoji(id: String, altText: String?) {
        guard !boxes.isEmpty else { return }
        // A code block's language is a plain string on the wire; a custom-emoji U+FFFC there would survive
        // into the model as part of the language name.
        if selectionIsEntirelyInCodeLanguageRegion() { return }
        let ref = EmojiRef(id: id, instanceID: BlockID.generate().rawValue, altText: altText)
        editing {
            // THE CLAIM IS APPLIED HERE, ON THE NEXT INSTRUCTION — never batched to the end of this
            // transaction's own `return`: the container-snap and `leafRegion(containingGlobal: head)` below read the caret back. A deferred claim re-resolves at the
            // pre-delete caret and silently produces a DIFFERENT document. Why, and the full list of
            // fourteen such sites: `applyReplaceOutcome`'s doc in `+Editing.swift`. Pinned by
            // `CaretLandingCharacterizationTests.test_insertEmojiOverAMidParagraphSelectionLandsBetweenTheHalves`.
            if selFrom != selTo {
                applyCaretOutcome(applySelectionReplaceOutcome(globalFrom: selFrom, globalTo: selTo, text: ""))
            }
            // A collapsed caret resolving to a table or block-quote box is a structural boundary —
            // snap into the nearest in-container text start (mirrors insertText).
            if !isInsideTable(head) && !isInsideBlockQuote(head),
               let r = resolveBox(at: head), r.box is TableBlockBox || r.box is BlockQuoteBox {
                // Applied HERE, not returned as this body's claim, for the reason the block above
                // states: the `leafRegion(containingGlobal: head)` test below and its `guard` read
                // this caret back, so a deferred claim would resolve the insert at the PRE-snap caret.
                let snapped = caretSnappedIntoContainer(head)
                applyCaretOutcome(.caret(at: snapped))
            }
            // A caret on a structural slot with no owning leaf region (e.g. document start = position 0,
            // which sits before the first block's textStart) snaps forward to the nearest renderable slot
            // so the insert lands in a real region — mirroring how insertText reaches position 0 via
            // resolveBox. An image gap stays un-snappable (still renderable but region-less) → a no-op.
            if leafRegion(containingGlobal: head) == nil {
                let snapped = snapToRenderable(head, forward: true)
                applyCaretOutcome(.caret(at: snapped))   // read back by the `guard` below
            }
            guard let (region, local) = leafRegion(containingGlobal: head) else { return .unchanged }
            // Start from the caret's typing attributes (correct font + paragraph style for the context,
            // incl. empty captions/cells), then stamp our attachment over them. Any inherited attachment
            // from a neighbouring emoji is replaced; read-back is emoji-only regardless, so nothing leaks.
            var attrs = typingAttributeDict(region: region, atLocal: local)
            // Match the body render-boost the mapper bakes in on reload (captions/cells are body-styled, so
            // an unresolved ref defaults to .body) — otherwise a freshly-inserted body emoji would render at
            // its bare glyph box until the next full document reload.
            let regionStyle = boxes.compactMap { $0 as? BlockBox }.first { $0.textRef == region.ref }?.style ?? .body
            attrs[.attachment] = EmojiTextAttachment(ref: ref, scale: mapper.emojiScale,
                                                     renderBoost: mapper.emojiRenderBoost(for: regionStyle))
            let frag = NSAttributedString(string: "\u{FFFC}", attributes: attrs)
            region.layout.replace(start: local, end: local, with: frag)
            recomputeSpans()
            let caret = region.globalStart + local + 1
            return .caret(at: caret)
        }
    }
}

@available(iOS 13.0, *)
extension DocumentCanvasView {
    /// One emoji occurrence found in the laid-out text.
    private struct EmojiOccurrence { let ref: EmojiRef; let canvasRect: CGRect; let regionStart: Int }

    /// Reconciles the pooled host emoji views against the laid-out document: reuse by `instanceID`,
    /// create via the provider for new ones, position each at its glyph rect, tear down removed ones.
    /// Body/caption emoji are hosted in `emojiOverlay` (canvas coords); table-cell emoji are hosted in
    /// the table's scrolling content view (Task 5). Called from `layoutSubviews` after `syncBlockViews`.
    func syncEmojiViews() {
        var occ: [EmojiOccurrence] = []
        for region in allLeafRegions() {
            let attr = region.layout.attributedString
            let full = NSRange(location: 0, length: attr.length)
            attr.enumerateAttribute(.attachment, in: full, options: []) { value, range, _ in
                guard let att = value as? EmojiTextAttachment,
                      let box = region.layout.attachmentBox(at: range.location)
                else { return }
                let canvasRect = box.offsetBy(dx: region.canvasOrigin.x, dy: region.canvasOrigin.y)
                occ.append(EmojiOccurrence(ref: att.ref, canvasRect: canvasRect, regionStart: region.globalStart))
            }
        }

        var present = Set<String>()
        for o in occ {
            present.insert(o.ref.instanceID)
            let hosted: HostedEmoji
            if let h = emojiViews[o.ref.instanceID] {
                hosted = h
            } else if let v = emojiViewProvider(o.ref.id, o.canvasRect.size) {
                v.isUserInteractionEnabled = false
                hosted = HostedEmoji(view: v, canvasFrame: o.canvasRect)
                emojiViews[o.ref.instanceID] = hosted
            } else {
                continue   // no view available yet (re-tried on the next layout pass)
            }
            // Keep the template-emoji tint synced to the current text color, every pass — cheap (the host
            // setter no-ops on an unchanged value) and self-healing across theme changes (a theme reload
            // relays out → syncEmojiViews). `primaryText` is the default run foreground the mapper bakes in.
            hosted.view.dynamicColor = self.mapper.theme.primaryText
            hosted.canvasFrame = o.canvasRect
            placeEmoji(hosted, canvasRect: o.canvasRect, regionStart: o.regionStart)
        }
        for (iid, h) in emojiViews where !present.contains(iid) {
            h.view.removeFromSuperview()
            emojiViews[iid] = nil
        }
        cullEmojiViews()
    }

    /// Parents + frames one hosted emoji. Table-cell emoji go into the table's scrolling content view
    /// (content-local = canvas rect − table.frame.origin; the scroll view carries `contentOffsetX`, so
    /// the view rides the horizontal scroll). Everything else goes into the canvas-level `emojiOverlay`.
    func placeEmoji(_ hosted: HostedEmoji, canvasRect: CGRect, regionStart: Int) {
        if let table = tableBox(containingGlobal: regionStart),
           let tv = blockViews[table.id] as? TableBackingView {
            let contentFrame = canvasRect.offsetBy(dx: -table.frame.minX, dy: -table.frame.minY)
            tv.hostEmoji(hosted.view, at: contentFrame)
        } else {
            if hosted.view.superview !== emojiOverlay { emojiOverlay.addSubview(hosted.view) }
            hosted.view.frame = canvasRect
        }
    }

    /// Hides emoji views whose canvas frame is > `emojiCullMargin` outside the visible viewport
    /// (the host scroll view's window onto the canvas content). No-arg form computes the viewport.
    /// Table-cell emoji are NOT culled here — their `canvasFrame` is the UNSCROLLED canvas rect, which
    /// would mis-score a horizontally-scrolled cell; the table's own `clipsToBounds` hides them instead.
    func cullEmojiViews() {
        let visible: CGRect
        if let sv = superview as? UIScrollView {
            visible = CGRect(origin: sv.contentOffset, size: sv.bounds.size)
        } else {
            visible = bounds
        }
        cullEmojiViews(visibleRect: visible)
    }

    func cullEmojiViews(visibleRect: CGRect) {
        let expanded = visibleRect.insetBy(dx: -emojiCullMargin, dy: -emojiCullMargin)
        for (_, h) in emojiViews {
            // A table-cell emoji rides the table's horizontal scroll; its `canvasFrame` is unscrolled, so
            // culling it by that rect can wrongly hide a scrolled-into-view cell. The table clips instead.
            if h.view.superview is TableContentView { h.view.isHidden = false; continue }
            h.view.isHidden = !expanded.intersects(h.canvasFrame)
        }
    }

    // MARK: Test accessors
    var hostedEmojiCountForTesting: Int { emojiViews.count }
    var firstHostedEmojiForTesting: (UIView & RichTextEmojiView)? { emojiViews.values.first?.view }
}
#endif
