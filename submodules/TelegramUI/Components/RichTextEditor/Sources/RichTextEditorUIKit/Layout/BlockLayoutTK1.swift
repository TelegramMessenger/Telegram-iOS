#if canImport(UIKit)
import UIKit

/// A **TextKit 1** implementation of `BlockLayoutEngine` for the iOS-15/16 back-port.
///
/// Uses `NSLayoutManager` + `NSTextStorage` + `NSTextContainer` — all available since iOS 7 — so this
/// type carries **no `@available` gate** (cf. `BlockLayout`, gated `@available(iOS 13.0, *)`): the
/// per-paragraph layout engine needs no TextKit 2 / iOS 17.
///
/// Mapping vs the TextKit 2 original:
/// - `enumerateTextSegments(.selection)` → `enumerateEnclosingRects(forGlyphRange:…)`;
/// - `enumerateTextLayoutFragments` height → `usedRect(for:)`;
/// - caret/baseline geometry → `lineFragmentRect` + `location(forGlyphAt:)` + `extraLineFragmentRect`.
///
/// **Display-only foreground (ghost + spoiler-hide) is intentionally disabled here.** TextKit 2's
/// rendering attributes have NO UIKit TextKit-1 analog (`add/removeTemporaryAttribute` is AppKit-only),
/// and the two features that need it — the inline-prediction ghost (an iOS-17 API, absent on 15/16) and
/// spoiler text-hiding — are accepted losses on the TK1 path. The methods only track ranges + bump
/// `renderVersion` to satisfy the change-detection contract; nothing is recolored.
final class BlockLayoutTK1: BlockLayoutEngine {
    let textStorage: NSTextStorage
    let layoutManager: NSLayoutManager
    let container: NSTextContainer

    private(set) var renderVersion = 0
    private var ghostRange: NSRange?

    private var measureScratch: BlockLayoutTK1?
    private var memoWidth: CGFloat = .nan
    private var memoRenderVersion: Int = -1
    private var memoHeight: CGFloat = 0
    private var spoilerRanges: [NSRange] = []

    init(attributedString: NSAttributedString, width: CGFloat) {
        textStorage = NSTextStorage(attributedString: attributedString)
        layoutManager = NSLayoutManager()
        container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        textStorage.addLayoutManager(layoutManager)
    }

    var attributedString: NSAttributedString {
        get { textStorage }
        set {
            textStorage.setAttributedString(newValue); renderVersion &+= 1
            ghostRange = nil; spoilerRanges = []
        }
    }

    func bumpRenderVersion() { renderVersion &+= 1 }

    var length: Int { textStorage.length }

    var backingStorage: NSTextStorage? { textStorage }
    var containerWidth: CGFloat { container.size.width }

    func setWidth(_ width: CGFloat) {
        container.size = CGSize(width: width, height: .greatestFiniteMagnitude)
    }

    /// The baseline TextKit actually produced for the first line, relative to the layout top, with NO
    /// correction applied. `BlockLayoutEngine`'s shared extension derives `baselineDelta` from it.
    /// (The TextKit-1 `NSLayoutManagerDelegate.shouldSetLineFragmentRect` baseline hook is NOT invoked
    /// under the TextKit-2-backed `NSLayoutManager` on modern iOS, so the correction is applied manually
    /// via that delta rather than through the delegate.)
    var rawFirstBaselineFromTop: CGFloat? {
        guard textStorage.length > 0 else { return nil }
        layoutManager.ensureLayout(for: container)
        guard layoutManager.numberOfGlyphs > 0 else { return nil }
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: nil)
        return lineRect.minY + layoutManager.location(forGlyphAt: 0).y
    }

    var boundingHeight: CGFloat {
        layoutManager.ensureLayout(for: container)
        return layoutManager.usedRect(for: container).height
    }

    func boundingHeight(forWidth width: CGFloat) -> CGFloat {
        if abs(width - container.size.width) < 0.5 { return boundingHeight }
        if memoRenderVersion == renderVersion && abs(memoWidth - width) < 0.5 { return memoHeight }
        let scratch: BlockLayoutTK1
        if let s = measureScratch { scratch = s }
        else { scratch = BlockLayoutTK1(attributedString: attributedString, width: width); measureScratch = scratch }
        // The reuse is allocation-only: we re-feed the current string + width and reflow each call (a
        // different width per call is the norm). The live layout is never touched.
        scratch.attributedString = attributedString
        scratch.setWidth(width)
        let h = scratch.boundingHeight
        memoWidth = width; memoRenderVersion = renderVersion; memoHeight = h
        return h
    }

    /// When set, `caretRect(atOffset:)` returns the trailing-edge position for EMPTY text, so an empty
    /// RTL-keyboard paragraph shows its caret on the right before the first keystroke. nil = default (0).
    var emptyTextCaretDirection: NSWritingDirection?

    /// Baseline of the first laid-out line relative to the layout top. `location(forGlyphAt:).y` is the
    /// glyph baseline measured from the line-fragment origin, so `lineRect.minY + loc.y` is the absolute
    /// baseline — the TK1 analog of TK2's `fragment.minY + line.glyphOrigin.y`.
    var firstLineBaselineFromTop: CGFloat? {
        guard textStorage.length > 0 else { return nil }
        layoutManager.ensureLayout(for: container)
        guard layoutManager.numberOfGlyphs > 0 else { return nil }
        var lineRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: 0, effectiveRange: &lineRange)
        let loc = layoutManager.location(forGlyphAt: 0)
        // Report the CORRECTED baseline (raised by `baselineDelta`) so a list marker tracks the drawn glyphs.
        return lineRect.minY + loc.y - baselineDelta
    }

    /// The resolved writing direction of this (single-paragraph) box, used to place the caret on the correct
    /// edge of a glyph's advance box. A forced override is baked into the paragraph style
    /// (`.leftToRight`/`.rightToLeft`); `.natural` falls back to CoreText content detection. Cached per
    /// `renderVersion` because `closestOffset` calls `caretRect` once per offset and the CTLine build in
    /// `baseDirection` is not free. (Per-paragraph direction is the editor's model; a paragraph mixing an
    /// embedded opposite-direction run is positioned by its base direction — the same as TextKit-2's path.)
    private var cachedDirectionVersion = -1
    private var cachedDirection: NSWritingDirection = .leftToRight
    private func resolvedCaretDirection() -> NSWritingDirection {
        if cachedDirectionVersion == renderVersion { return cachedDirection }
        var dir: NSWritingDirection = .leftToRight
        if textStorage.length > 0,
           let ps = textStorage.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle {
            switch ps.baseWritingDirection {
            case .leftToRight: dir = .leftToRight
            case .rightToLeft: dir = .rightToLeft
            default: dir = baseDirection(atOffset: 0) ?? .leftToRight   // .natural → detect from content
            }
        }
        cachedDirection = dir; cachedDirectionVersion = renderVersion
        return dir
    }

    /// The glyph's enclosing (advance) box in container coordinates — the geometry selection uses, so its
    /// leading/trailing edges are the true caret boundaries (vs. `boundingRect`, which is INK bounds, and
    /// `location`, which is only the LTR pen origin). nil if no rect is produced.
    private func enclosingBox(forGlyph glyph: Int) -> CGRect? {
        var result: CGRect?
        layoutManager.enumerateEnclosingRects(forGlyphRange: NSRange(location: glyph, length: 1),
                                              withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: container) { r, _ in if result == nil { result = r } }
        return result
    }

    func caretRect(atOffset offset: Int) -> CGRect {
        // Empty text with direction override: position caret at the trailing edge for RTL.
        if textStorage.length == 0, emptyTextCaretDirection == .rightToLeft {
            return CGRect(x: container.size.width - 2, y: 0, width: 2, height: 20)
        }
        let fallback = CGRect(x: 0, y: 0, width: 2, height: 20)
        layoutManager.ensureLayout(for: container)
        let count = textStorage.length

        // Empty text, or caret on a trailing empty line after a final newline: the extra line fragment.
        if count == 0 || offset >= count {
            let extra = layoutManager.extraLineFragmentRect
            if extra.height > 0 {
                // RTL: trailing (left) end is the line's leading side — put the caret at the right edge.
                let rtl = count > 0 ? resolvedCaretDirection() == .rightToLeft : (emptyTextCaretDirection == .rightToLeft)
                let x = rtl ? extra.maxX : extra.minX
                return CGRect(x: x, y: extra.minY, width: 2, height: max(extra.height, 20))
            }
        }
        if count == 0 { return fallback }

        let isRTL = resolvedCaretDirection() == .rightToLeft

        if offset >= count {
            // Caret AFTER the last char: the trailing edge of its advance box — RIGHT (maxX) in LTR, LEFT
            // (minX) in RTL (where the text grows leftward, so "after" is the left side).
            let lastGlyph = layoutManager.numberOfGlyphs - 1
            guard lastGlyph >= 0 else { return fallback }
            var lineRange = NSRange()
            let lineRect = layoutManager.lineFragmentRect(forGlyphAt: lastGlyph, effectiveRange: &lineRange)
            let box = enclosingBox(forGlyph: lastGlyph)
                ?? layoutManager.boundingRect(forGlyphRange: NSRange(location: lastGlyph, length: 1), in: container)
            let x = isRTL ? box.minX : box.maxX
            return CGRect(x: x, y: lineRect.minY, width: 2, height: max(lineRect.height, 20))
        }

        // Caret BEFORE the char at `offset`: the LEADING edge of its advance box — LEFT (minX) in LTR, RIGHT
        // (maxX) in RTL (the boundary with the preceding char, which sits to the right).
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: offset)
        var lineRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
        let x: CGFloat
        if let box = enclosingBox(forGlyph: glyphIndex) {
            x = isRTL ? box.maxX : box.minX
        } else {
            let loc = layoutManager.location(forGlyphAt: glyphIndex)   // fallback: LTR pen origin
            x = lineRect.minX + loc.x
        }
        return CGRect(x: x, y: lineRect.minY, width: 2, height: max(lineRect.height, 20))
    }

    func selectionRects(start: Int, end: Int) -> [CGRect] {
        guard start < end else { return [] }
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: start, length: end - start),
                                                  actualCharacterRange: nil)
        var rects: [CGRect] = []
        layoutManager.enumerateEnclosingRects(forGlyphRange: glyphRange,
                                              withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0),
                                              in: container) { rect, _ in rects.append(rect) }
        return rects
    }

    /// UITextView-style wash rects: same per-line enumeration as `selectionRects`, then the identical
    /// leading/trailing-edge extension math as the TK2 original.
    func selectionFillRects(start: Int, end: Int, fillTrailingLine: Bool, isRTL: Bool) -> [CGRect] {
        let segs = selectionRects(start: start, end: end)
        guard !segs.isEmpty else { return [] }
        let edge = container.size.width
        let coveredFromStart = (start == 0)
        return segs.enumerated().map { i, seg in
            let toLeadingEdge = (i > 0) || coveredFromStart                  // covered from the line's beginning
            let toTrailingEdge = (i < segs.count - 1) || fillTrailingLine    // covered to the line's end
            // The line's "beginning" is the left edge in LTR but the right (container) edge in RTL; the
            // "end" is the opposite. Extend whichever physical edge corresponds to the covered logical side.
            let left: CGFloat
            let right: CGFloat
            if isRTL {
                right = toLeadingEdge ? max(seg.maxX, edge) : seg.maxX
                left = toTrailingEdge ? min(seg.minX, 0) : seg.minX
            } else {
                left = toLeadingEdge ? min(seg.minX, 0) : seg.minX
                right = toTrailingEdge ? max(seg.maxX, edge) : seg.maxX
            }
            return CGRect(x: left, y: seg.minY, width: right - left, height: seg.height)
        }
    }

    func attachmentBox(at offset: Int) -> CGRect? {
        guard offset >= 0, offset + 1 <= textStorage.length,
              let attachment = textStorage.attribute(.attachment, at: offset, effectiveRange: nil) as? NSTextAttachment
        else { return nil }
        layoutManager.ensureLayout(for: container)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: offset)
        let runFont = (textStorage.attribute(.font, at: offset, effectiveRange: nil) as? UIFont)
            ?? UIFont.preferredFont(forTextStyle: .body)
        // Baseline of the attachment's line, taken from a TEXT glyph on that line. The emoji view must sit on
        // the SAME baseline TextKit draws the neighbouring text at (`lineFragmentRect.minY +
        // location(forGlyphAt:).y`), then raised by `baselineDelta` exactly like the drawn text — so the emoji
        // tracks the centered glyphs. It must NOT be read from the attachment glyph's own `location.y` (that y
        // tracks the box bottom, floating the emoji down).
        var lineGlyphRange = NSRange()
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineGlyphRange)
        let centerDelta = baselineDelta
        var baseline = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: nil).minY
            + runFont.ascender - centerDelta                    // fallback: a lone-attachment line (no text)
        for g in lineGlyphRange.location ..< (lineGlyphRange.location + lineGlyphRange.length) {
            let ci = layoutManager.characterIndexForGlyph(at: g)
            if textStorage.attribute(.attachment, at: ci, effectiveRange: nil) == nil {
                baseline = lineRect.minY + layoutManager.location(forGlyphAt: g).y - centerDelta
                break
            }
        }
        let glyphRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1),
                                                   in: container)
        // TK1 attachment-bounds API (iOS 7+), no NSTextLocation. EmojiTextAttachment overrides this variant
        // (alongside the TK2 one), so emoji size to the run font here too.
        let bounds = attachment.attachmentBounds(for: container, proposedLineFragment: lineRect,
                                                 glyphPosition: CGPoint(x: glyphRect.minX, y: baseline),
                                                 characterIndex: offset)
        var box = CGRect(x: glyphRect.minX + bounds.minX, y: baseline - bounds.maxY,
                         width: bounds.width, height: bounds.height)
        if let boost = (attachment as? EmojiTextAttachment)?.renderBoost, boost > 0 {
            box = box.insetBy(dx: -boost / 2, dy: -boost / 2)
        }
        return box
    }

    func closestOffset(toPoint point: CGPoint) -> Int {
        let ns = attributedString.string as NSString
        var best = 0
        var bestDy = CGFloat.greatestFiniteMagnitude
        var bestDx = CGFloat.greatestFiniteMagnitude
        for offset in 0...length {
            // Skip offsets INSIDE a composed character sequence (a surrogate-pair / ZWJ / variation-selector
            // emoji is ONE caret stop). A mid-cluster caret would let a later insert/delete split the cluster,
            // leaving a stray code unit (the "service character"). Endpoints (0, length) are always stops.
            if offset > 0, offset < length, ns.rangeOfComposedCharacterSequence(at: offset).location != offset {
                continue
            }
            let caret = caretRect(atOffset: offset)
            let dy = point.y < caret.minY ? caret.minY - point.y
                   : point.y > caret.maxY ? point.y - caret.maxY : 0
            let dx = abs(caret.midX - point.x)
            if dy < bestDy - 0.5 || (dy <= bestDy + 0.5 && dx < bestDx) {
                bestDy = dy; bestDx = dx; best = offset
            }
        }
        return best
    }

    func drawText(in ctx: CGContext, at origin: CGPoint) {
        layoutManager.ensureLayout(for: container)
        let glyphRange = layoutManager.glyphRange(for: container)
        // Raise the glyphs by the line-centering delta so they sit centered in the (taller) lineHeightMultiple
        // box — whose height (caret/selection geometry) is untouched. One block is one paragraph (uniform line
        // height), so a single context translate centers every line.
        let delta = glyphRange.length > 0 ? baselineDelta : 0
        UIGraphicsPushContext(ctx)
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y - delta)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        ctx.restoreGState()
        UIGraphicsPopContext()
    }

    func replace(start: Int, end: Int, with string: NSAttributedString) {
        textStorage.replaceCharacters(in: NSRange(location: start, length: end - start), with: string)
        renderVersion &+= 1
        ghostRange = nil; spoilerRanges = []
    }

    // Display-only foreground is disabled on TK1 (see the type doc). Track + bump only.
    func setGhostForeground(_ color: UIColor?, start: Int, end: Int) {
        ghostRange = nil
        renderVersion &+= 1
        guard color != nil, start < end else { return }
        ghostRange = NSRange(location: start, length: end - start)
    }

    @discardableResult
    func setSpoilerHidden(_ ranges: [NSRange]) -> Bool {
        let effective = ranges.filter { $0.length > 0 }
        if effective == spoilerRanges { return false }
        spoilerRanges = effective
        renderVersion &+= 1
        return true
    }
}
#endif
