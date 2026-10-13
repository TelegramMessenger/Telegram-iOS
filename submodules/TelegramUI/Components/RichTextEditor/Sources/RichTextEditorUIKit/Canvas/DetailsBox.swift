#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One detail (folding) block in the canvas: a `CanvasBlock` recursive container whose FIRST child is the
/// always-visible, editable title (summary) paragraph, followed by the body children shown only when expanded.
/// A right-side chevron folds/unfolds the body. `expanded` is the INVERSE of `BlockQuote.collapsed`.
/// Round-trips to `Block.details`.
///
/// **Title is a real first child `BlockBox`**, not a container-owned leaf region — so the box is structurally
/// identical to an (author-less) `BlockQuoteBox`, and the existing recursive descent / editing / navigation /
/// selection engine handles both the title and the body uniformly (see `activeStack`'s `DetailsBox` branch).
/// This mirrors `DocumentTree`'s `.details(children: [titleParagraph] + (expanded ? body : []))` exactly, so
/// `nodeSize` = `Σchildren + 2` and each child's leaf region lands at the token layout the position model expects.
@available(iOS 13.0, *)
final class DetailsBox: CanvasBlock {
    static let chevronSize: CGFloat = 18
    /// Left edge → the leading chevron (matches the V2 renderer, which puts the arrow at the leading side inset).
    static let chevronLeadingInset: CGFloat = 3.0
    /// Left edge → the title/body text — leaves room for the leading chevron.
    static let contentLeadingInset: CGFloat = 26.0
    /// Vertical gap between the title row and the first body block. Independent of the inter-body-paragraph
    /// spacing (which is `BlockStack`'s tight Body-stacking, 0) — adjust this alone to change ONLY the
    /// title↔body separation.
    static let titleBodyGap: CGFloat = 14.0

    /// Host placeholder strings (stamped by the canvas). Drives the empty-title hint. An empty
    /// `detailsTitle` string means "no placeholder".
    var placeholders: RichTextEditorPlaceholders = .default
    /// Host-provided fold chevron (stamped by the canvas): the V2 `ExpandingItemVerticalRegularArrow`,
    /// drawn pointing down when collapsed and rotated 180° up when expanded. `nil` ⇒ a drawn-arrow fallback.
    var chevronImage: UIImage?

    let id: BlockID
    let mapper: AttributedStringMapper
    let quoteStyle: QuoteStyle
    let pullQuoteStyle: PullQuoteStyle
    let expandImage: UIImage?
    let collapseImage: UIImage?
    /// Whether the body is shown/editable. The INVERSE of `BlockQuote.collapsed`; equals the sent
    /// `InstantPageBlock.details(expanded:)` value.
    let expanded: Bool

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    private(set) var layoutWidth: CGFloat

    var topInset: CGFloat
    var bottomInset: CGFloat

    /// The child stack: `[titleBox]` when folded, `[titleBox] + bodyBoxes` when expanded. Built via the
    /// recursive `makeBox` factory, so any block nests in the body (incl. nested detail blocks).
    let children: BlockStack
    /// Body preserved (in the `Block` model) while folded — OFF the position axis, restored by `currentBlock()`.
    private let foldedBodyModel: [Block]

    init(details d: DetailsBlock, mapper: AttributedStringMapper,
         quoteStyle: QuoteStyle = .default,
         pullQuoteStyle: PullQuoteStyle = .default,
         expandImage: UIImage? = nil,
         collapseImage: UIImage? = nil,
         width: CGFloat) {
        self.id = d.id
        self.mapper = mapper
        self.quoteStyle = quoteStyle
        self.pullQuoteStyle = pullQuoteStyle
        self.expandImage = expandImage
        self.collapseImage = collapseImage
        self.expanded = d.expanded
        self.layoutWidth = max(width, 1)
        // Top inset is the SAME in both states so the title/chevron never move when folding. Only the bottom
        // differs: EXPANDED reserves the body→bottom-separator gap (default block inset + 8pt); COLLAPSED puts
        // 17pt between the title line and the bottom separator.
        self.topInset = 6.0
        self.bottomInset = d.expanded ? (BlockBox.defaultVerticalInset + 8.0) : 17.0

        // The title is the first child paragraph. Its BlockID is a DERIVED, distinct id (NOT `d.id`): the
        // `DetailsBox` chrome and the title box are BOTH realized as separate backing views keyed by BlockID,
        // so sharing `d.id` would collide in the canvas's `blockViews` map (one would overwrite the other,
        // dropping the chrome). The derived id is stable across rebuilds (so the title view reuses). The title
        // is ALWAYS the Body style; its paragraph style is implicit, so the model stores only the inline runs.
        // Only the TITLE's TEXT is indented past the leading chevron — via a display-only paragraph indent, so
        // its frame stays full width and the BODY sits at the normal body inset (flush, not aligned with it).
        let titleBox = BlockBox(paragraph: ParagraphBlock(id: DetailsBox.titleBlockID(d.id), style: .body,
                                                          paragraph: ParagraphAttributes(firstLineIndent: DetailsBox.contentLeadingInset,
                                                                                         headIndent: DetailsBox.contentLeadingInset),
                                                          runs: d.title),
                                mapper: mapper, width: max(width, 1))
        var boxes: [CanvasBlock] = [titleBox]
        if d.expanded {
            boxes.append(contentsOf: d.children.compactMap {
                makeBox(for: $0, mapper: mapper, quoteStyle: quoteStyle, pullQuoteStyle: pullQuoteStyle,
                        expandImage: expandImage, collapseImage: collapseImage, horizontalBleed: 0, width: max(width, 1))
            })
            self.foldedBodyModel = []
        } else {
            self.foldedBodyModel = d.children
        }
        let stack = BlockStack(boxes: boxes)
        stack.spacingModel = .containerInterior
            stack.verticalInsetBase = 0
        self.children = stack
    }

    /// A stable, distinct BlockID for the title child box, derived from the details block's id so it never
    /// collides with the `DetailsBox`'s own id in the canvas `blockViews` map (both are realized as views).
    /// The `\u{1}` suffix can't occur in a real UUID id, so it can't collide with another block's id either.
    static func titleBlockID(_ base: BlockID) -> BlockID { BlockID(base.description + "\u{1}detailsTitle") }

    private var titleBox: BlockBox? { children.boxes.first as? BlockBox }

    /// The LEADING chevron rect in canvas coordinates (used by the canvas's tap routing + `draw`), vertically
    /// centered on the title row — mirrors the V2 renderer's left-arrow placement.
    func chevronRect() -> CGRect {
        let titleFrame = children.boxes.first?.frame ?? CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 20)
        return CGRect(x: frame.minX + DetailsBox.chevronLeadingInset,
                      y: titleFrame.minY + (titleFrame.height - DetailsBox.chevronSize) / 2,
                      width: DetailsBox.chevronSize, height: DetailsBox.chevronSize)
    }

    // MARK: - CanvasBlock

    var rendersAsBlockView: Bool { true }

    /// container(2) + Σ children (title + body when expanded). Matches `DocumentTree`'s `.details` mapping.
    var spacingKind: RichTextBlockSpacingKind { .details }

    var nodeSize: Int {
        children.boxes.reduce(0) { $0 + $1.nodeSize } + 2
    }

    func setWidth(_ width: CGFloat) {
        layoutWidth = max(width, 1)
        for box in children.boxes { box.setWidth(layoutWidth) }   // full width; only the title's TEXT is indented
    }

    /// The extra title↔body gap, present only when there IS a body (expanded + ≥1 body child).
    private var titleBodyExtent: CGFloat { (expanded && children.boxes.count > 1) ? DetailsBox.titleBodyGap : 0 }

    var height: CGFloat {
        topInset + children.measuredHeight(forWidth: layoutWidth) + bottomInset + titleBodyExtent
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        topInset + children.measuredHeight(forWidth: max(width, 1)) + bottomInset + titleBodyExtent
    }

    func recompute() {
        // Children own the position axis: assign nodeStarts (title first, body after) and lay out frames.
        children.recompute(baseOffset: nodeStart)
        // Full width at the block's leading edge — the body sits at the normal inset; only the title's TEXT
        // is indented (via its paragraph indent) to clear the leading chevron.
        children.layout(origin: CGPoint(x: frame.minX, y: frame.minY + topInset), width: frame.width)
        // Independent title↔body gap: `BlockStack` stacks Body-styled boxes tight (0) — and the title is
        // Body-styled — so title↔body lands at 0 too. Shift the body down by `titleBodyGap` to open THAT
        // boundary alone, leaving body↔body at 0. Done before the nested recompute below so nested containers
        // lay their own children out against the shifted frame.
        if expanded, children.boxes.count > 1 {
            for i in 1 ..< children.boxes.count { children.boxes[i].frame.origin.y += DetailsBox.titleBodyGap }
        }
        for case let nested as DetailsBox in children.boxes { nested.recompute() }
        for case let nested as BlockQuoteBox in children.boxes { nested.recompute() }
        for case let nested as TableBlockBox in children.boxes { nested.recompute() }
    }

    func currentBlock() -> Block {
        // The title style is implicit (always Body), so strip the display-pinned font size from its runs — the
        // model title carries only the inline text + real user attributes (bold/italic/link/emoji).
        let title = (titleBox?.currentParagraph().runs ?? []).map { run -> TextRun in
            var r = run; r.attributes.fontSize = nil; return r
        }
        let body: [Block] = expanded ? children.boxes.dropFirst().map { $0.currentBlock() } : foldedBodyModel
        return .details(DetailsBlock(id: id, title: title, children: body, expanded: expanded))
    }

    func leafRegions() -> [LeafTextRegion] { children.leafRegions() }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int { children.closestPosition(toCanvasPoint: point) }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        // Chrome only — the title + body children each render via their OWN backing views (hosted by the
        // canvas's recursive `reconcileBlockViews`), so this must NOT flatten them (that would double-draw
        // and, for view-hosted children like tables/media, draw only their non-view part).
        // Empty-title placeholder (the title is children[0], Body style; it is not top-level so it draws no
        // placeholder of its own). Aligned to where centered Body text will appear (half the extra leading).
        if let titleBox = children.boxes.first as? BlockBox, titleBox.textLength == 0, !placeholders.detailsTitle.isEmpty {
            let font = mapper.styleSheet.font(for: .body, attributes: .plain)
            let ps = mapper.styleSheet.paragraphStyle(for: .body, attributes: ParagraphAttributes(),
                                                      list: nil, baseWritingDirection: mapper.baseWritingDirection)
            let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
            let shift = (mult - 1) * font.lineHeight / 2
            NSAttributedString(string: placeholders.detailsTitle,
                               attributes: [.font: font, .foregroundColor: mapper.theme.placeholder])
                .draw(at: CGPoint(x: frame.minX + DetailsBox.contentLeadingInset, y: titleBox.textOrigin.y + shift))
        }
        // Leading chevron — the host-provided V2 `ExpandingItemVerticalRegularArrow`, body/primary-tinted,
        // pointing down when collapsed and rotated 180° up when expanded. Falls back to a drawn arrow when the
        // host supplied no image (e.g. a nested details not reached by stamping).
        let rect = chevronRect()
        if let image = chevronImage {
            let tinted = image.withTintColor(mapper.theme.primaryText, renderingMode: .alwaysOriginal)
            if expanded {
                ctx.saveGState()
                ctx.translateBy(x: rect.midX, y: rect.midY)
                ctx.rotate(by: .pi)
                tinted.draw(in: CGRect(x: -rect.width / 2, y: -rect.height / 2, width: rect.width, height: rect.height))
                ctx.restoreGState()
            } else {
                tinted.draw(in: rect)
            }
        } else {
            drawChevron(in: ctx, rect: rect, pointingDown: !expanded, color: mapper.theme.primaryText)
        }
        // Bottom separator hairline — ALWAYS (collapsed shows just this one, on the single row's bottom edge).
        ctx.saveGState()
        ctx.setFillColor(mapper.theme.tableBorder.cgColor)
        ctx.fill(CGRect(x: frame.minX, y: frame.maxY - 0.5, width: frame.width, height: 0.5))
        ctx.restoreGState()
    }

    private func drawChevron(in ctx: CGContext, rect: CGRect, pointingDown: Bool, color: UIColor) {
        let inset = rect.width * 0.28
        let midX = rect.midX, top = rect.minY + inset, bottom = rect.maxY - inset
        let left = rect.minX + inset, right = rect.maxX - inset
        ctx.saveGState()
        ctx.setStrokeColor(color.cgColor); ctx.setLineWidth(1.5); ctx.setLineCap(.round); ctx.setLineJoin(.round)
        ctx.beginPath()
        if pointingDown {
            ctx.move(to: CGPoint(x: left, y: top)); ctx.addLine(to: CGPoint(x: midX, y: bottom)); ctx.addLine(to: CGPoint(x: right, y: top))
        } else {
            ctx.move(to: CGPoint(x: left, y: bottom)); ctx.addLine(to: CGPoint(x: midX, y: top)); ctx.addLine(to: CGPoint(x: right, y: bottom))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: - Degenerate single-text-region members (unused: the canvas uses leafRegions()).
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { nodeStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .detailsTitle(id) }
    var textOrigin: CGPoint { frame.origin }
}
#endif
