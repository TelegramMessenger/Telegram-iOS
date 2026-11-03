#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// The visible half of a container: a code block's background band, a pull quote's accent bar.
///
/// **These are real views, one per container block — not drawing into a shared canvas.** The engine
/// already gives every block its own `IDTextLayoutCanvasView`, so a decoration view is simply a
/// sibling behind it, positioned from that block's frame. Nothing is composited into the text
/// bitmap, which is what keeps a container's appearance independent of what the text pass does.
///
/// It is the third host-positioned overlay family here, after the custom-emoji views and the spoiler
/// dust, and it follows the same pool-and-cull shape. It differs from both in ONE respect, and that
/// difference is load-bearing: **decoration is parented INTO the engine's scroll content**, not onto
/// the editor view.
///
/// `IDBlockTextView` is a `UIScrollView`. `id_frameForBlockAtIndex:` answers in the engine's own
/// coordinate system, which for a scroll view is CONTENT space — an origin that does not move as the
/// user scrolls. A view parented to the editor (outside the scroll view) therefore has to subtract
/// `contentOffset` and be re-synced on every scroll, or it slides out from under the text it
/// decorates. Parenting into the scroll content instead makes it scroll for free and removes the
/// offset arithmetic entirely, so there is no scroll hook to forget.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// How wide the "Add author" prompt is, in the face it is drawn in.
    fileprivate static func authorPromptWidth(styleSheet: StyleSheet) -> CGFloat {
        let font = EngineDocumentBridge.authorPromptFont(styleSheet: styleSheet)
        return (quoteAuthorPlaceholderText as NSString)
            .size(withAttributes: [.font: font]).width
    }

    /// One band per container the document draws: every QUOTE in any ancestry (spanning everything
    /// within it) and every LEAF container that has a band. `level` is the quote's index in the
    /// ancestry (0 = outermost); a leaf band's `level` is its role's depth, and it is drawn above.
    ///
    /// A block quote used to draw one segment PER CHILD, on the reasoning that abutting segments
    /// read as one continuous bar. They do not: each segment's accent bar is capped with
    /// `barWidth / 2` of corner radius, so every seam is a visible pinch, and the fill is a separate
    /// rect either side of it. With the author line added — a short strip at the end — the quote
    /// read as several stacked backgrounds, which is how this was reported. The legacy canvas draws
    /// ONE underlay per quote for the same reason.
    private struct Band { let key: BlockID; let kind: ContainerDecorationKind; let span: ClosedRange<Int>; let level: Int; let isLeaf: Bool }

    /// Reconciles decoration views against the container blocks in the current document.
    /// Idempotent; driven from `layoutSubviews` after the engine has laid out.
    internal func syncContainerDecorations() {
        guard !currentRoles.isEmpty || !containerDecorationViews.isEmpty else { return }
        var bands: [Band] = []
        var seen: Set<BlockID> = []
        for (index, role) in currentRoles.enumerated() {
            for (level, ancestor) in role.ancestry.enumerated() where seen.insert(ancestor.id).inserted {
                // The KIND is the ancestor's, not a constant: hardcoded `.blockQuote`, a details
                // ancestor drew a quote's fill and bar instead of its hairline.
                bands.append(Band(key: ancestor.id,
                                  kind: ancestor.details != nil ? .detailsSeparator : .blockQuote,
                                  span: span(of: ancestor.id, around: index), level: level, isLeaf: false))
            }
            // A container can own SEVERAL engine blocks — a code block and its language line — and
            // one band covers all of them, so the first role of a group draws and the rest fold into
            // its frame. Without this the two roles share a key, the second overwrites the first's
            // frame, and the band covers only the code.
            if let kind = ContainerDecorationKind(role), seen.insert(role.containerID).inserted {
                bands.append(Band(key: role.containerID, kind: kind, span: containerSpan(containing: index), level: role.containerDepth, isLeaf: true))
            }
        }

        var live: Set<BlockID> = []
        // NOT the same set as `live`, and that is the whole of this variable. `live` holds every
        // BAND's key, and a folded quote's LEAF band keeps its id in there — so culling glyphs
        // against `live` would leave a quote's collapse glyph on screen after the quote folded,
        // floating over its own preview. A glyph is live only where one was actually placed.
        var liveQuoteGlyphs: Set<BlockID> = []
        let pullQuoteStyle = deferredConfiguration.pullQuoteStyle
        let overhangs = EngineBlockSpacing.trailingLineBoxOverhangs(for: currentRoles,
                                                                    lineAttributes: spacingLineAttributes())
        for band in bands {
            var frame = CGRect.null
            for owned in band.span {
                // A PLACED cell's own frame is its TEXT frame, which sits `border + padding` inside
                // the grid, so unioning it left a band that started below the table's real top. The
                // table's frame is the rect the user sees.
                let part = currentRoles[owned].owningTable != nil
                    ? (tableFrame(forTableAt: owned) ?? engine.id_frameForBlock(at: UInt(owned)))
                    : engine.id_frameForBlock(at: UInt(owned))
                // CGRectNull is the engine's answer for an unknown index — never treated as a rect.
                guard !part.isNull, part.width > 0, part.height > 0 else { continue }
                frame = frame.isNull ? part : frame.union(part)
            }
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }
            // The interior this band grows into: its own level's contribution and every level nested
            // inside it, at the span's first role (top) and last role (bottom) — spec §5.1. The space
            // is reserved AROUND the block, so a band placed on the block's own frame sits inside the
            // padding and the container reads as having none. The gap SEPARATING it from its
            // neighbours is not its to cover, which is why this asks for the interior part only.
            func interior(at index: Int) -> UIEdgeInsets {
                let contributions = EngineBlockSpacing.interiorContributions(
                    for: currentRoles, at: index, styleSheet: bridge.styleSheet,
                    quoteStyle: deferredConfiguration.quoteStyle, pullQuoteStyle: pullQuoteStyle)
                let from = band.isLeaf ? max(0, contributions.count - 1) : band.level
                return contributions[min(from, contributions.count)...].reduce(UIEdgeInsets.zero) {
                    UIEdgeInsets(top: $0.top + $1.top, left: 0.0, bottom: $0.bottom + $1.bottom, right: 0.0)
                }
            }
            let interiorTop = interior(at: band.span.lowerBound).top
            // A band's bottom is measured from its last block's FRAME, which is a pinned line box and
            // so stands one trailing overhang below the glyphs — the same band of empty space the
            // rhythm gives back (`EngineBlockSpacing.trailingLineBoxOverhang`). Left in, the band
            // reaches one overhang past where the renderer's does, and now that the rhythm no longer
            // pays for that space, straight over the top of the line below it.
            let interiorBottom = interior(at: band.span.upperBound).bottom
                - (overhangs[band.span.upperBound] ?? 0)

            live.insert(band.key)
            let decoration: ContainerDecorationView
            if let existing = containerDecorationViews[band.key] {
                decoration = existing
            } else {
                let fresh = ContainerDecorationView()
                fresh.isUserInteractionEnabled = false
                // BELOW the block stack, so text draws over the band rather than under it.
                engine.insertSubview(fresh, at: 0)
                containerDecorationViews[band.key] = fresh
                decoration = fresh
            }
            // Inside a quote a band is flush with the quote's inner edge: one quoteIndent per level in.
            // The sum over the ancestors OUTSIDE this band, not the level times a constant: a
            // details among them contributes nothing (R7-details spec §3.4).
            let indent = currentRoles[band.span.lowerBound].ancestry.prefix(band.level)
                .contentIndent(styleSheet: bridge.styleSheet)
            var horizontal = (x: frame.minX + indent, width: frame.width - indent)
            if band.kind == .blockQuote {
                // A quote's band spans the text COLUMN at its level — never the union of what it
                // holds. Every ordinary child returns a full-width line frame, so the union was the
                // column by accident; a table returns PLACED rects, and a quote whose only child was
                // a table got a band hugging the grid (device, K3 2026-09-08). The union still
                // decides the band's VERTICAL extent, which is what it is for.
                horizontal = (x: engine.textContainerInset.left + indent, width: availableTableWidth - indent)
            }
            if band.kind == .code, band.level == 0 {
                // A code band's side padding IS the paragraph inset, so the band BLEEDS outward past
                // the text rather than the text being inset within it. `nil` — the document default —
                // means reach the container's own edge, which is what makes a top-level code block in
                // the article editor flush and full-width. A compact host cannot do that (its canvas
                // sits inside the field's rounded background) and passes 0, pinning the band to the
                // text column; it moves its code INWARD with `horizontalInset` instead.
                //
                // A code block INSIDE a quote does not bleed (§5.1) — it is flush with the quote's
                // inner edge — so this arm is level 0 only.
                if let bleed = deferredConfiguration.codeStyle.horizontalBleed {
                    horizontal = (x: frame.minX - bleed, width: frame.width + bleed * 2.0)
                } else {
                    horizontal = (x: 0.0, width: engine.bounds.width)
                }
            }
            if band.kind == .pullQuote {
                // A pull quote HUGS: its pill is the WIDER of the quote and its author line plus the
                // horizontal padding on each side, centred within the width available at its level —
                // the shape V2 and the legacy editor both give it, and what keeps a long attribution
                // under a short quote from being clipped (`PullQuoteBox.pillContentWidth` does the
                // same). Every other container fills its column.
                //
                // An EMPTY author line counts as its PROMPT: the line measures zero, but what is on
                // screen is "Add author", and a pill sized to the quote alone clipped it.
                let content = band.span.map { index -> CGFloat in
                    if currentRoles[index].secondaryKind == .pullQuoteAuthor, flatLength(ofRoleAt: index) == 0 {
                        return Self.authorPromptWidth(styleSheet: bridge.styleSheet)
                    }
                    return contentWidth(ofBlockAt: index)
                }.max() ?? 0.0
                let available = frame.width - indent
                let hugged = min(max(content + pullQuoteStyle.horizontalPadding * 2.0, pullQuoteStyle.minWidth), available)
                horizontal = (x: frame.minX + indent + (available - hugged) / 2.0, width: hugged)
            }
            if band.kind == .detailsSeparator {
                // A HAIRLINE at the bottom of the span, in both states — not a band (spec §5.1).
                //
                // Its width is the COLUMN at the details' own level, pinned rather than taken from the
                // union: probe P2 measured that the union gives the column only BY ACCIDENT, because
                // every ordinary child returns a full-width line frame. A details whose only child is a
                // TABLE returns PLACED cell rects, and the hairline would hug the grid — the same trap
                // the quote band hit and was fixed for.
                let column = engine.textContainerInset.left
                decoration.frame = CGRect(x: column + indent,
                                          y: frame.maxY + interiorBottom - Self.detailsSeparatorThickness,
                                          width: availableTableWidth - indent,
                                          height: Self.detailsSeparatorThickness)
            } else {
                decoration.frame = CGRect(x: horizontal.x, y: frame.minY - interiorTop,
                                          width: horizontal.width, height: frame.height + interiorTop + interiorBottom)
            }
            // The band's own frame IS the wash's column — one derivation, so the two cannot drift.
            // A hairline is not a box and declares nothing; a PLACED cell keeps its own slot, so a
            // quote holding a table does not stretch each cell's wash across the grid. That skip
            // also excludes a container nested inside a cell, which is already parented to the
            // engine rather than to the run's content view and so does not travel with its cell —
            // a pre-existing limitation, and a column from a misplaced band would be worse than the
            // plain cell. Bands run outermost-first, leaf-last, so the innermost one wins.
            if band.kind != .detailsSeparator {
                for owned in band.span where currentRoles[owned].owningTable == nil {
                    pendingSelectionBoxes[currentRoles[owned].blockID] = decoration.frame
                }
            }
            decoration.update(kind: band.kind, codeBackground: composerHostState.theme.codeBackground,
                              accent: composerHostState.theme.accent, pullQuoteStyle: pullQuoteStyle,
                              codeStyle: deferredConfiguration.codeStyle)
            // The glyph's position is defined against the BAND, and the band's frame is only known
            // here, so the glyph is synced from this pass rather than from one of its own. Gated on
            // `!band.isLeaf`: a quote that draws a LEAF band is a FOLDED one, whose glyph belongs to
            // its preview view.
            if band.kind == .blockQuote, !band.isLeaf,
               syncQuoteCollapseGlyph(quoteID: band.key, band: decoration.frame, span: band.span) {
                liveQuoteGlyphs.insert(band.key)
            }
        }

        for (id, decoration) in containerDecorationViews where !live.contains(id) {
            containerDecorationViews[id] = nil
            decoration.removeFromSuperview()
        }
        for (id, glyph) in quoteCollapseGlyphViews where !liveQuoteGlyphs.contains(id) {
            glyph.removeFromSuperview()
            quoteCollapseGlyphViews[id] = nil
        }

        // Z-order by depth on every pass (probe P3): quote bands outermost first, leaf bands above
        // every quote band, all of them below the engine's own subviews. Re-inserted only when the
        // order differs, so a pass that changes nothing changes nothing.
        let desired = bands.filter { live.contains($0.key) }
            .sorted { ($0.isLeaf ? 1 : 0, $0.level) < ($1.isLeaf ? 1 : 0, $1.level) }
            .compactMap { containerDecorationViews[$0.key] }
        let current = engine.subviews.compactMap { $0 as? ContainerDecorationView }
        if !current.elementsEqual(desired, by: { $0 === $1 }) {
            for (position, view) in desired.enumerated() { engine.insertSubview(view, at: position) }
        }
    }
}

/// What a container looks like. Derived from the block, so a block kind that grows decoration later
/// declares it in one place.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    /// Legacy's `DetailsBox` bottom rule.
    internal static let detailsSeparatorThickness: CGFloat = 0.5
}

internal enum ContainerDecorationKind {
    case code
    case pullQuote
    case blockQuote
    /// A details draws no fill at all — one hairline at the bottom of its span, in BOTH states
    /// (R7-details spec §5.1). Task 5 gives it its geometry; it is a kind here so the decoration pool
    /// owns its lifecycle like every other ornament.
    case detailsSeparator

    /// The LEAF container's band, from the role's own container. A quote's bands come from the
    /// ancestry pass, so a quote's author line — whose container IS the quote — has none here.
    ///
    /// Not a `default`: a new container case should fail to compile here and be decided
    /// deliberately, rather than silently rendering as undecorated text.
    init?(_ role: EngineBlockRole) {
        switch role.container {
        case .block(.code): self = .code
        case .block(.pullQuote): self = .pullQuote
        // A FOLDED quote draws the quote's own band, from the LEAF path: it is no longer in
        // anyone's ancestry, so the ancestry pass will not draw it (R7-collapse §4.2).
        case .block(.collapsedQuote): self = .blockQuote
        case .details: self = .detailsSeparator
        // A button row draws NO band: its pills are the ornament, and they are subviews of the
        // hosted row view rather than anything this pool owns.
        case .block(.paragraph), .block(.media), .block(.buttonRow), .blockQuote, .table: return nil
        }
    }
}

/// One container's decoration. A plain view with a background and an optional leading bar — no
/// `draw(_:)`, so it costs a layer and no bitmap.
@available(iOS 18.4, *)
/// The widest laid-out line in the block at `index`, in the engine's content space.
///
/// Derived from the rendered lines rather than from the text's measured width, because the pill has
/// to hug what TextKit actually produced — a wrapped line's ink, not the container it was measured
/// against.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {
    internal func contentWidth(ofBlockAt index: Int) -> CGFloat {
        let blocks = engine.attributedBlocks
        guard index < blocks.count else { return 0.0 }
        var start = 0
        for preceding in 0..<index { start += blocks[preceding].length + 1 }
        // Line by line, the separators left out: the rect of a range that ends in a line separator
        // runs to the trailing edge of its line, so a block whose first line is empty measured the
        // whole column (measured on device: a Return at the start of a pull quote made its pill
        // full-width). An empty line has no ink and contributes nothing.
        let text = blocks[index].string as NSString
        var widest: CGFloat = 0.0
        var lineStart = 0
        while lineStart <= text.length {
            let separator = text.range(of: EngineDocumentBridge.lineSeparator,
                                       range: NSRange(location: lineStart, length: text.length - lineStart))
            let lineEnd = separator.location == NSNotFound ? text.length : separator.location
            if lineEnd > lineStart {
                let rects = engine.id_rects(forCanonicalRange: NSRange(location: start + lineStart,
                                                                      length: lineEnd - lineStart))
                widest = max(widest, rects.map(\.cgRectValue.width).max() ?? 0.0)
            }
            if separator.location == NSNotFound { break }
            lineStart = NSMaxRange(separator)
        }
        return widest
    }
}

internal final class ContainerDecorationView: UIView {
    private let bar = UIView()
    private var marksView: PullQuoteMarksView?
    private var pullQuoteStyle: PullQuoteStyle = .default

    internal override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(bar)
    }

    @available(*, unavailable)
    internal required init?(coder: NSCoder) { fatalError("not supported") }

    internal func update(kind: ContainerDecorationKind, codeBackground: UIColor, accent: UIColor,
                         pullQuoteStyle: PullQuoteStyle, codeStyle: CodeStyle) {
        self.pullQuoteStyle = pullQuoteStyle
        switch kind {
        case .detailsSeparator:
            // No bar and no marks: the hairline IS the whole ornament (R7-details spec §5.1). It is
            // drawn AS this view's background, over a frame the decoration pass makes 0.5pt tall —
            // this said "rather than by a background" directly above the line that assigns one.
            marksView?.isHidden = true
            bar.isHidden = true
            backgroundColor = accent.withAlphaComponent(0.2)
            layer.cornerRadius = 0.0
        case .code:
            marksView?.isHidden = true
            backgroundColor = codeBackground
            // The HOST's radius, not a constant: a document band is square and a compact one is
            // rounded, because the compact band sits inside the field's own rounded background.
            layer.cornerRadius = codeStyle.cornerRadius
            bar.isHidden = true
        case .blockQuote:
            marksView?.isHidden = true
            // The accent BAR belongs to a block quote — that is where the legacy editor and the
            // InstantPage V2 renderer both put it — over a field tinted with the same accent.
            backgroundColor = accent.withAlphaComponent(Self.quoteFillAlpha)
            layer.cornerRadius = 0.0
            bar.isHidden = false
            bar.backgroundColor = accent
            bar.layer.cornerRadius = Self.quoteBarWidth / 2.0
        case .pullQuote:
            // NO bar. A pull quote is a centred HUG — the pill is sized to its content by the sync
            // pass — and `.pullQuote` is already centred and italic from the stylesheet; a leading
            // bar would make it read as a block quote. It carries a corner mark at each end instead,
            // which is what V2 draws and what the legacy editor's `PullQuoteMarksView` exists for.
            backgroundColor = accent.withAlphaComponent(pullQuoteStyle.fillAlpha)
            layer.cornerRadius = pullQuoteStyle.cornerRadius
            bar.isHidden = true
            let marks = marksView ?? {
                let fresh = PullQuoteMarksView()
                addSubview(fresh)
                marksView = fresh
                return fresh
            }()
            marks.isHidden = false
            marks.accentColor = accent
        }
        setNeedsLayout()
    }

    internal override func layoutSubviews() {
        super.layoutSubviews()
        // Positions its own subview against `bounds`; it never writes its own frame — the sync pass
        // owns that (the repo-wide view-frame-ownership rule).
        bar.frame = CGRect(x: 0.0, y: 0.0, width: Self.quoteBarWidth, height: bounds.height)
        if let marks = marksView, !marks.isHidden {
            marks.frame = bounds
            // Opening mark at the leading top corner, closing mark at the trailing bottom one, each
            // inset from its corner. Sizes come from the assets themselves, which is what the marks
            // view exposes them for.
            let inset = pullQuoteStyle.markInset
            let open = PullQuoteMarksView.openImageNaturalSize
            let close = PullQuoteMarksView.closeImageNaturalSize
            marks.sync(marks: [(
                open: CGRect(x: inset, y: inset, width: open.width, height: open.height),
                close: CGRect(x: bounds.width - inset - close.width,
                              y: bounds.height - inset - close.height,
                              width: close.width, height: close.height))])
        }
    }

    private static let quoteCornerRadius: CGFloat = 4.0
    private static let quoteBarWidth: CGFloat = 3.0
    private static let quoteFillAlpha: CGFloat = 0.1
}

@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Reserves the vertical rhythm and container padding through the engine's per-block insets.
    ///
    /// Both come from `EngineBlockSpacing`, which derives them from the renderer's own spacing table
    /// and the stylesheet — so this method chooses no numbers of its own. It replaced a set of
    /// hand-picked constants that could drift from the legacy editor and the sent bubble.
    /// What each role's line is rendered with, for `EngineBlockSpacing`'s trailing-overhang read.
    ///
    /// The engine's own storage answers it for a block that HAS text — the last character carries the
    /// pinned line box and the font of the last line, which is the line the overhang sits under — and
    /// the bridge's probe render answers for an empty one, where there is no character to ask. The
    /// storage is read ONCE and captured: `attributedBlocks` materialises the whole document, so
    /// calling it per role would make a linear walk quadratic.
    internal func spacingLineAttributes() -> (Int) -> [NSAttributedString.Key: Any] {
        let texts = engine.attributedBlocks
        let roles = currentRoles
        return { [self] index in
            if index < texts.count, texts[index].length > 0 {
                return texts[index].attributes(at: texts[index].length - 1, effectiveRange: nil)
            }
            guard index < roles.count else { return [:] }
            return self.cachedLineAttributes(for: roles[index])
        }
    }

    /// The empty band the block at `index` reserves below its last line and the renderer does not —
    /// the quantity every space below that block gives back (`EngineBlockSpacing`).
    ///
    /// A block's FRAME still carries it: the engine sizes each canvas to its own pinned line box, and
    /// nothing host-side can shorten that. So anything measuring a gap from a frame's bottom edge —
    /// a band, a separator, a test — is measuring from one overhang below the glyphs and has to say
    /// so. It is per role because it is per line box: a quote's 15pt child gives back 1pt where a
    /// 17pt body paragraph gives back 2.
    internal func trailingLineBoxOverhang(atRole index: Int) -> CGFloat {
        guard index >= 0, index < currentRoles.count, currentRoles[index].owningTable == nil else { return 0 }
        return EngineBlockSpacing.trailingLineBoxOverhang(of: spacingLineAttributes()(index))
    }

    /// How far the pinned box puts this role's line BELOW V2's baseline, which
    /// `EngineBlockSpacing` takes back out of its top inset and returns below it.
    ///
    /// **The consequence for anything measuring geometry: after the lift, a text block's canvas IS
    /// its glyph box.** Its TOP is exactly V2's item top, so a gap measured to a canvas top needs no
    /// correction. Its BOTTOM is the last descender, where V2's item runs `drop` further — so a gap
    /// measured from a frame's bottom edge, or an inset read against a design constant, has to say
    /// so, exactly as it already did for `trailingLineBoxOverhang` (which the lift's own placement
    /// arm has since driven to 0).
    ///
    /// Per role, because it is a rounding remainder of each font's own box: 0.0996 at 15pt against
    /// 0.7129 at 17pt body. That is the reason it is not a host-side constant.
    internal func v2BaselineDrop(atRole index: Int) -> CGFloat {
        guard index >= 0, index < currentRoles.count, currentRoles[index].owningTable == nil else { return 0 }
        return EngineBlockSpacing.v2BaselineDrop(of: spacingLineAttributes()(index))
    }

    internal func syncContainerBlockInsets() {
        let identifiers = engine.tgid_blockIdentifiers
        guard identifiers.count == currentRoles.count else { return }

        var computed = EngineBlockSpacing.blockLayout(for: currentRoles,
                                                      styleSheet: bridge.styleSheet,
                                                      quoteStyle: deferredConfiguration.quoteStyle,
                                                      pullQuoteStyle: deferredConfiguration.pullQuoteStyle,
                                                      grids: tableGrids,
                                                      standaloneFormulas: standaloneFormulaRoleIndices(),
                                                      lineAttributes: spacingLineAttributes()).insets
        // An ordered item whose marker is wider than one character hangs its TEXT further right.
        // Added here rather than inside the spacing walk because the amount is measured on the
        // role's OWN font, which only the bridge's per-role mapper knows (a quoted item renders at
        // 15pt), and `EngineBlockSpacing` is handed one style sheet. `syncListMarkers` subtracts the
        // same number so the marker stays put — one derivation, `orderedListMarkerInsets()`.
        for (index, extra) in orderedListMarkerInsets() where index < computed.count {
            computed[index].left += extra
        }
        var insets: [UUID: NSValue] = [:]
        for (index, inset) in computed.enumerated() where inset != .zero {
            insets[identifiers[index]] = NSValue(uiEdgeInsets: inset)
        }
        engine.blockInsets = insets.isEmpty ? nil : insets
    }
}

#endif
