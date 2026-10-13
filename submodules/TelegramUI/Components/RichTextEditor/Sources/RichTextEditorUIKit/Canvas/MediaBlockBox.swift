#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import MosaicLayout

/// The grey "Add caption" hint shown under an image while its caption is empty. `rect` spans the full
/// caption content width so a centered paragraph style centers the text horizontally.
@available(iOS 13.0, *)
struct CaptionPlaceholder { let text: String; let rect: CGRect; let font: UIFont }

/// A media-with-caption block: a host-supplied media view (resolved from `mediaID` via the canvas's
/// `mediaViewProvider`, positioned at `mediaRect()`) above an editable caption. Contributes
/// `captionLength + 5` tokens; the caption text begins at `nodeStart + 2` (after the media atom and the
/// caption paragraph's open token). The position `nodeStart` (before the atom) is a gap.
@available(iOS 13.0, *)
final class MediaBlockBox: CanvasBlock {
    let id: BlockID
    var items: [MediaItem]
    var displayWidth: Double?
    var alignment: MediaAlignment
    var displayMode: MediaDisplayMode
    let caption: BlockLayoutEngine
    let mapper: AttributedStringMapper
    /// How far the media bleeds beyond its text-strip `frame` on each side (points). Default
    /// `CanvasMetrics.pageMargin` reproduces the document edge-to-edge look; a compact host (composer)
    /// passes 0 so media insets like text. A nested (table-cell) media passes 0 too.
    let horizontalBleed: CGFloat

    var frame: CGRect = .zero
    var nodeStart: Int = 0
    let verticalInset: CGFloat = 8
    let captionGap: CGFloat = 4
    /// The most-recently-set layout width (from `setWidth` or `init`). Used by `height`,
    /// `imageAreaHeight`, and `mediaRect` so they are correct before `frame` is assigned by
    /// `layoutSubviews`.
    private(set) var layoutWidth: CGFloat

    /// A degenerate empty layout for an audio block, which has NO editable text region (caption-less). The
    /// `caption` layout is still built in `init` but is unused for audio. Mirrors `TableBlockBox.emptyLayout`.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)

    /// The caption renders centered. Render-only — NOT persisted: `currentBlock()` extracts only the
    /// caption runs, so alignment never enters the model (and markdown carries none).
    private static let captionParagraph = ParagraphAttributes(alignment: .center)

    /// Host placeholder strings, stamped by the canvas during layout.
    var placeholders: RichTextEditorPlaceholders = .default

    /// A caption-less block renders as a fixed-height row (NOT aspect-scaled). Both heights match the V2
    /// renderer's frame height in `InstantPageV2Layout.swift` (`audioFrame` / `documentFrame`), so the
    /// editor preview equals the sent bubble.
    static let audioRowHeight: CGFloat = 44.0
    static let documentRowHeight: CGFloat = 52.0

    /// The full canvas width this image bleeds across: its content-strip frame width plus both page
    /// margins (the inverse of the inset top-level frame). The image draws edge-to-edge over this by
    /// default; a host can inset media via `horizontalBleed` (0 = flush with text, e.g. composer or table cell).
    private var canvasWidth: CGFloat { layoutWidth + horizontalBleed * 2 }

    /// The box is an audio block iff its single item is audio (audio is always single). Narrower than
    /// `isCaptionless` — kept for callers that mean audio SPECIFICALLY, mirroring `MediaBlock.isAudio`.
    var isAudio: Bool { items.first?.kind == .audio }
    /// The box is a caption-less row (audio or document) iff its single item is one — both are always single.
    var isCaptionless: Bool { items.first?.kind.isCaptionless ?? false }
    /// The fixed row height for a caption-less block. Meaningless for captioned media.
    var rowHeight: CGFloat {
        items.first?.kind == .document ? MediaBlockBox.documentRowHeight : MediaBlockBox.audioRowHeight
    }
    /// The primary medium's opaque key (single-media paths / control routing default).
    var mediaID: String { items.first?.mediaID ?? "" }
    /// First item's natural size (single-media layout path).
    private var primaryNaturalSize: Size2D { items.first?.naturalSize ?? Size2D(width: 0, height: 0) }

    init(media block: MediaBlock, mapper: AttributedStringMapper, width: CGFloat,
         horizontalBleed: CGFloat = CanvasMetrics.pageMargin) {
        id = block.id
        items = block.items
        displayWidth = block.displayWidth
        alignment = block.alignment
        displayMode = block.displayMode
        self.mapper = mapper
        self.horizontalBleed = horizontalBleed
        layoutWidth = max(width, 1)
        // The caption's paragraph id matches the media block's id — it only keys the paragraph style
        // here; `currentBlock()` extracts the caption runs, not this temporary paragraph's id.
        let captionPara = ParagraphBlock(id: block.id, style: .caption,
                                         paragraph: MediaBlockBox.captionParagraph,
                                         runs: block.caption)
        caption = makeBlockLayout(attributedString: mapper.attributedString(for: captionPara),
                                  width: max(width, 1))
    }

    // CanvasBlock — text region is the caption (absent for audio).
    var rendersAsBlockView: Bool { true }
    // The medium is now an overlay view (not drawn into the backing store), so the backing view only needs
    // to cover the caption (its own inset frame). The full-bleed medium is hosted in the canvas mediaOverlay.
    var blockViewFrame: CGRect { frame }
    var textLayout: BlockLayoutEngine { isCaptionless ? emptyLayout : caption }
    var textLength: Int { isCaptionless ? 0 : caption.length }
    /// `hasCredit` is ALWAYS false: `InstantPageBuilder` maps the editor's single caption to
    /// `InstantPageCaption.text` and always passes `credit: .empty`. The editor has no credit field — do
    /// NOT wire the caption here, or every captioned image loses its flush-below gap.
    /// Raw media is V2's image/video/slideshow/collage/map set; audio and document are not.
    var spacingKind: RichTextBlockSpacingKind {
        // A multi-item box (mosaic/slideshow) maps to `.collage`/`.slideshow`, both of which are in V2's
        // raw-media set, so it is raw regardless of the primary item's kind.
        let raw: Bool
        if items.count > 1 {
            raw = true
        } else {
            switch items.first?.kind {
            case .image, .video, .location: raw = true
            case .audio, .document:         raw = false
            case nil:                       raw = true
            }
        }
        return .media(hasCredit: false, isRawMedia: raw)
    }

    var nodeSize: Int { isCaptionless ? 3 : caption.length + 5 }
    var textStart: Int { isCaptionless ? nodeStart : nodeStart + 2 }
    var textRef: TextNodeRef { .caption(id) } // unchanged; unused for audio (leafRegions is empty)

    func setWidth(_ width: CGFloat) {
        layoutWidth = max(width, 1)
        caption.setWidth(max(width, 1))
    }

    /// Displayed image slot: `displayWidth` clamped to `maxWidth` (or fills `maxWidth`), height = the
    /// aspect-preserving height CAPPED at `min(1000, maxWidth)` (media is never taller than its display
    /// width). A capped portrait becomes a `width × cap` slot; the renderer aspect-fits + blur-fills it.
    func imageDisplaySize(maxWidth: CGFloat) -> CGSize {
        let naturalW = CGFloat(primaryNaturalSize.width), naturalH = CGFloat(primaryNaturalSize.height)
        let targetW = displayWidth.map { min(CGFloat($0), maxWidth) } ?? maxWidth
        let cap = min(1000.0, maxWidth)
        guard naturalW > 0, naturalH > 0 else { return CGSize(width: targetW, height: min(targetW * 0.5625, cap)) }
        let aspectHeight = naturalH * (targetW / naturalW)
        return CGSize(width: targetW, height: min(aspectHeight, cap))
    }

    /// Mosaic-assembled size for a multi-item container at `maxWidth`, using the SAME engine + cap the
    /// renderer applies. The engine is width-driven (a ≥5-item pack can exceed the cap), so scale-to-fit:
    /// when the packed height exceeds `min(1000, maxWidth)`, the mosaic is reserved at full width × cap
    /// (the renderer scales the cells down + centers them).
    private func mosaicSize(maxWidth: CGFloat) -> CGSize {
        let itemSizes = items.map { CGSize(width: $0.naturalSize.width, height: $0.naturalSize.height) }
        let cap = min(1000.0, maxWidth)
        let (_, size) = chatMessageBubbleMosaicLayout(maxSize: CGSize(width: maxWidth, height: cap), itemSizes: itemSizes)
        if size.height > cap {
            return CGSize(width: maxWidth, height: cap)
        }
        return size
    }

    /// Slideshow-assembled size for a multi-item container: full width × the TALLEST item's aspect height
    /// fitted to `maxWidth`, capped at `min(1000, maxWidth)` (matches `layoutSlideshow`'s per-image
    /// `fitted(width × 1200)` taking the max, and the mosaic cap). Each page renders aspect-fit within this.
    private func slideshowSize(maxWidth: CGFloat) -> CGSize {
        let cap = min(1000.0, maxWidth)
        var tallest: CGFloat = 0
        for item in items {
            let w = CGFloat(item.naturalSize.width), h = CGFloat(item.naturalSize.height)
            let fitted = (w > 0 && h > 0) ? h * (maxWidth / w) : maxWidth * 0.5625
            tallest = max(tallest, fitted)
        }
        return CGSize(width: maxWidth, height: min(tallest, cap))
    }

    /// The container size for the current mode (count >= 2 only): slideshow vs mosaic.
    private func containerSize(maxWidth: CGFloat) -> CGSize {
        displayMode == .slideshow ? slideshowSize(maxWidth: maxWidth) : mosaicSize(maxWidth: maxWidth)
    }

    var imageAreaHeight: CGFloat {
        if isCaptionless { return rowHeight }
        if items.count >= 2 { return containerSize(maxWidth: max(canvasWidth, 1)).height }
        return imageDisplaySize(maxWidth: max(canvasWidth, 1)).height
    }

    /// One line of the caption's (body) font height, reserved only when the caption is EMPTY — TextKit 2
    /// lays out no fragment for empty text, so `caption.boundingHeight` is ~0 and the caption row would
    /// otherwise collapse. Mirrors `BlockBox.emptyLineHeight`. Keeps the "Add caption" line always visible.
    private var captionEmptyLineHeight: CGFloat {
        guard caption.length == 0 else { return 0 }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: MediaBlockBox.captionParagraph, list: nil,
                                                   baseWritingDirection: mapper.baseWritingDirection)
        let mult = ps.lineHeightMultiple > 0 ? ps.lineHeightMultiple : 1
        return font.lineHeight * mult
    }

    /// Width of the "Add caption" placeholder in the caption (body) font — used to align the empty-caption
    /// caret to the START (left edge) of the centered placeholder rather than the line's center.
    private var captionPlaceholderTextWidth: CGFloat {
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        return (placeholders.caption as NSString).size(withAttributes: [.font: font]).width
    }

    var height: CGFloat {
        if isCaptionless { return verticalInset + rowHeight + verticalInset }
        return verticalInset + imageAreaHeight + captionGap
            + max(caption.correctedBoundingHeight, captionEmptyLineHeight) + verticalInset
    }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        if isCaptionless { return verticalInset + rowHeight + verticalInset }
        let imageArea: CGFloat
        if items.count >= 2 {
            imageArea = containerSize(maxWidth: max(width + horizontalBleed * 2, 1)).height
        } else {
            imageArea = imageDisplaySize(maxWidth: max(width + horizontalBleed * 2, 1)).height
        }
        return verticalInset + imageArea + captionGap
            + max(caption.correctedBoundingHeight(forWidth: max(width, 1)), captionEmptyLineHeight) + verticalInset
    }

    var textOrigin: CGPoint {
        CGPoint(x: frame.minX,
                y: frame.minY + verticalInset + imageAreaHeight + captionGap)
    }

    // NOTE: bleed is per-box via `horizontalBleed`. Top-level media uses the host's `mediaBlockStyle`
    // (default `CanvasMetrics.pageMargin`); nested (table-cell) media already passes `horizontalBleed: 0`
    // to skip the bleed.
    func mediaRect() -> CGRect {
        let avail = max(canvasWidth, 1)
        if isCaptionless {
            // Audio is a fixed-height full-width row (see imageAreaHeight); NOT aspect-scaled. The hosted
            // audio view lays out its content within this width. `bleedX` matches the image full-bleed origin.
            let bleedX = frame.minX - horizontalBleed
            return CGRect(x: bleedX, y: frame.minY + verticalInset, width: avail, height: rowHeight)
        }
        if items.count >= 2 {
            // Full-bleed mosaic container rect; per-cell frames are the host view's concern.
            let bleedX = frame.minX - horizontalBleed
            return CGRect(x: bleedX, y: frame.minY + verticalInset, width: avail, height: imageAreaHeight)
        }
        let size = imageDisplaySize(maxWidth: avail)
        let bleedX = frame.minX - horizontalBleed
        let x: CGFloat
        switch alignment {
        case .left: x = bleedX
        case .center: x = bleedX + (avail - size.width) / 2
        case .right: x = bleedX + (avail - size.width)
        }
        return CGRect(x: x, y: frame.minY + verticalInset, width: size.width, height: size.height)
    }

    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        if isCaptionless { return nodeStart }
        if point.y < textOrigin.y { return nodeStart }   // image area → gap before the atom
        let local = CGPoint(x: point.x - textOrigin.x, y: point.y - textOrigin.y)
        return textStart + caption.closestOffset(toPoint: local)
    }

    func currentBlock() -> Block {
        .media(MediaBlock(id: id, items: items, displayWidth: displayWidth, alignment: alignment,
                          displayMode: displayMode,
                          caption: isCaptionless ? [] : mapper.runs(from: caption.attributedString, style: .caption)))
    }

    func leafRegions() -> [LeafTextRegion] {
        if isCaptionless { return [] }
        // When the caption is empty, place its caret at the START (left edge) of the centered "Add caption"
        // placeholder — not the line center — so the caret sits just before the placeholder text rather than
        // bisecting it. The placeholder is centered in a layoutWidth-wide rect, so its left edge is
        // (layoutWidth - textWidth)/2 (clamped ≥ 0). TextKit lays out no fragment for empty text, so
        // caretRect(atOffset:0) falls back to x=0; the consumers (caretRect(for:)/updateCaretView) add this
        // offset. 0 once text exists — the glyph layout (centered) then positions the caret.
        let emptyOffset = caption.length == 0 ? max((layoutWidth - captionPlaceholderTextWidth) / 2, 0) : 0
        return [LeafTextRegion(layout: caption, globalStart: textStart, length: caption.length,
                               ref: .caption(id), canvasOrigin: textOrigin,
                               emptyLineLeadingIndent: emptyOffset, emptyLineHeight: captionEmptyLineHeight)]
    }

    /// Attributes for text typed into an EMPTY caption: body character attributes plus the render-only
    /// centered paragraph style. The caption renders centered, but that centering is render-only (not in
    /// the model), so an empty caption carries no run to inherit it from — without this, the first typed
    /// character would be left-aligned. Mirrors the empty-paragraph path in `typingAttributeDict`.
    func captionTypingAttributes() -> [NSAttributedString.Key: Any] {
        var attrs = mapper.attributes(for: CharacterAttributes(), style: .caption)
        attrs[.paragraphStyle] = mapper.styleSheet.paragraphStyle(for: .caption,
                                                                  attributes: MediaBlockBox.captionParagraph, list: nil,
                                                                  baseWritingDirection: mapper.baseWritingDirection)
        return attrs
    }

    /// Non-nil only when the caption is EMPTY: a centered "Add caption" placeholder at the caption line.
    /// Drawn by THIS block (inside its `BlockBackingView`), not the canvas `placeholderDraws()` seam,
    /// because an image is view-backed (`rendersAsBlockView`) — its caption and placeholder must share
    /// the same render layer. Mirrors the paragraph placeholder's color/font.
    func captionPlaceholder() -> CaptionPlaceholder? {
        guard !isCaptionless, caption.length == 0, !placeholders.caption.isEmpty else { return nil }
        let font = mapper.styleSheet.font(for: .caption, attributes: .plain)
        let rect = CGRect(x: textOrigin.x, y: textOrigin.y, width: layoutWidth, height: captionEmptyLineHeight)
        return CaptionPlaceholder(text: placeholders.caption, rect: rect, font: font)
    }

    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {
        guard !isCaptionless else { return } // caption-less: the media is a host overlay; nothing to draw here
        // The medium itself is now a host-supplied overlay view (positioned at `mediaRect()` by the canvas
        // media reconciler), so the backing store draws only the caption (+ its placeholder). `imageProvider`
        // is retained as the shared `CanvasBlock.draw` parameter but is unused here.
        caption.drawText(in: ctx, at: textOrigin)
        if let ph = captionPlaceholder() {
            // Use the caption's OWN paragraph style (centered + body line-height metrics) so the
            // placeholder is metrically identical to real caption text — same centering AND same baseline,
            // so nothing shifts vertically the instant the user types.
            let ps = mapper.styleSheet.paragraphStyle(for: .caption, attributes: MediaBlockBox.captionParagraph, list: nil,
                                                       baseWritingDirection: mapper.baseWritingDirection)
            NSAttributedString(string: ph.text, attributes: [
                .font: ph.font,
                .foregroundColor: mapper.theme.placeholder,
                .paragraphStyle: ps,
            ]).draw(in: ph.rect)
        }
    }
}
#endif
