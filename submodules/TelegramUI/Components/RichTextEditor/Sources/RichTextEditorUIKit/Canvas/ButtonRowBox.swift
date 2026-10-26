#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// One `pageBlockButtonRow` in the canvas: a row of pills, packed by `richTextPackButtonRow`.
///
/// **This is the editor's only TEXT-FREE block.** Every other `CanvasBlock` owns at least one editable
/// text region; a button row owns none — a pill's label is button chrome, not document text, and is
/// edited through the host's property sheet rather than in the canvas. So `leafRegions()` is empty and
/// the single-text-region protocol members are degenerate, exactly as `TableBlockBox`/`BlockQuoteBox`
/// supply degenerate values for members that do not apply to them.
///
/// The position model gives the row one atom per pill (`DocumentTree` maps it to the `.mediaBlock` +
/// `.mediaAtom` shape a collapsed block quote already uses), so `nodeSize == max(1, buttons.count) + 2`
/// and the caret can stop on each pill.
@available(iOS 13.0, *)
final class ButtonRowBox {
    let id: BlockID
    let mapper: AttributedStringMapper
    private(set) var buttons: [ButtonRef]
    private(set) var alignment: ButtonRowAlignment

    var frame: CGRect = .zero
    var globalStart: Int = 0

    /// Pill frames in the box's own coordinate space (origin at the row's top-left), model order.
    private(set) var pillFrames: [CGRect] = []
    /// Box-local rect of the trailing "…" menu affordance — EDITOR-ONLY chrome, placed after packing and
    /// deliberately NOT part of `richTextPackButtonRow`: that transcription is pinned to the V2 renderer
    /// by `RichTextV2ButtonParityTests`, and a sent message has no such control.
    private(set) var menuButtonFrame: CGRect = .zero
    private(set) var attachments: [ButtonTextAttachment] = []
    private var packedHeight: CGFloat = 0.0
    private var layoutWidth: CGFloat = 0.0

    /// A degenerate layout for the protocol's single-text-region members. Mirrors `TableBlockBox.n` /
    /// `MediaBlockBox`'s caption-less path — nothing reads it, because `leafRegions()` is empty.
    private let emptyLayout = makeBlockLayout(attributedString: NSAttributedString(string: ""), width: 1)

    init(row: ButtonRowBlock, mapper: AttributedStringMapper, width: CGFloat) {
        self.id = row.id
        self.mapper = mapper
        self.buttons = row.buttons
        self.alignment = row.alignment
        repack(width: width)
    }

    /// Side of the trailing "…" control and the gap before it. Deliberately smaller than a pill: it is
    /// chrome, not content.
    static let menuButtonSide: CGFloat = 28.0
    static let menuButtonGap: CGFloat = 6.0
    /// Width the row reserves so the "…" always has room.
    static var menuButtonReserve: CGFloat { menuButtonSide + menuButtonGap }

    /// Whether this row shows its "…" menu control. Stamped by the canvas from whether a host is
    /// actually listening (`buttonRowMenuRequested != nil`), so the article editor shows it and the
    /// chat composer — which is preservation-only and wires no authoring hooks — does not.
    ///
    /// When hidden the row ALSO stops reserving width for it, so composer pills match the sent message
    /// exactly rather than being needlessly narrower.
    var showsMenuAffordance: Bool = false {
        didSet {
            if showsMenuAffordance != oldValue { repack(width: layoutWidth) }
        }
    }

    private func repack(width: CGFloat) {
        layoutWidth = width
        // Pills pack into the width MINUS the "…" reserve, so the control always fits on the last line.
        // Reserving beats letting it wrap: the default alignment is `justify`, where pills stretch to
        // fill the width, so an unreserved control never fits and EVERY row would be two lines tall
        // (86pt for a single button). The cost is that a justified pill is ~34pt narrower here than in
        // the sent message — a smaller distortion than doubling the row's height.
        //
        // This happens in the BOX, never in `richTextPackButtonRow`: that function stays V2-exact and is
        // pinned by `RichTextV2ButtonParityTests`.
        let packed = richTextPackButtonRow(
            buttons: buttons,
            alignment: alignment,
            availableWidth: max(0.0, width - (showsMenuAffordance ? ButtonRowBox.menuButtonReserve : 0.0)),
            metrics: mapper.styleSheet.metrics.button,
            isRTL: mapper.baseWritingDirection == .rightToLeft,
            hasIcon: { [mapper] button in mapper.buttonHasIcon(button.action) },
            measure: { [mapper] button, maxWidth, padding in
                mapper.buttonAttachment(button: button, isBlockPill: true, maxWidth: maxWidth,
                                        horizontalPadding: padding)
            }
        )
        attachments = packed.attachments
        pillFrames = packed.frames
        packedHeight = packed.totalHeight
        layoutMenuButton(availableWidth: max(0.0, width))
    }

    /// Places the trailing "+" after the last pill when it fits on that visual row, else on a new line
    /// (growing the row's height so it is always reachable). An EMPTY row shows it at the origin.
    private func layoutMenuButton(availableWidth: CGFloat) {
        guard showsMenuAffordance else {
            menuButtonFrame = .zero   // `.zero.contains` is false, so hit-testing declines it too
            packedHeight = max(packedHeight, mapper.styleSheet.metrics.button.blockRowHeight)
            return
        }
        let side = ButtonRowBox.menuButtonSide
        let rowHeight = mapper.styleSheet.metrics.button.blockRowHeight
        let lastLineY = pillFrames.last?.minY ?? 0.0
        packedHeight = max(packedHeight, rowHeight)
        menuButtonFrame = CGRect(
            x: max(0.0, availableWidth - side),
            y: lastLineY + (rowHeight - side) / 2.0,
            width: side, height: side
        )
    }

    /// True when `point` (canvas space) lands on the "…".
    func hitsMenuButton(atCanvasPoint point: CGPoint) -> Bool {
        menuButtonFrame.offsetBy(dx: frame.minX, dy: frame.minY).contains(point)
    }

    /// The "…" rect in canvas space, for menu anchoring.
    func menuButtonCanvasRect() -> CGRect {
        menuButtonFrame.offsetBy(dx: frame.minX, dy: frame.minY)
    }

    /// Appends a pill and returns its index.
    @discardableResult
    func appendButton(_ button: ButtonRef) -> Int {
        buttons.append(button)
        repack(width: layoutWidth)
        return buttons.count - 1
    }

    /// The pill index at a canvas point, or nil. Used by tap routing and `closestPosition`.
    func pillIndex(atCanvasPoint point: CGPoint) -> Int? {
        let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        return pillFrames.firstIndex { $0.contains(local) }
    }

    /// The pill index nearest a canvas point — never nil for a non-empty row, so a tap anywhere in the
    /// row's band lands on a pill rather than falling through to a neighbouring block.
    func nearestPillIndex(toCanvasPoint point: CGPoint) -> Int? {
        guard !pillFrames.isEmpty else {
            return nil
        }
        if let hit = pillIndex(atCanvasPoint: point) {
            return hit
        }
        let local = CGPoint(x: point.x - frame.minX, y: point.y - frame.minY)
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, rect) in pillFrames.enumerated() {
            let dx = max(rect.minX - local.x, 0.0, local.x - rect.maxX)
            let dy = max(rect.minY - local.y, 0.0, local.y - rect.maxY)
            let distance = dx * dx + dy * dy
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// The canvas-space rect of a pill, for menu anchoring.
    func pillCanvasRect(_ index: Int) -> CGRect? {
        guard pillFrames.indices.contains(index) else {
            return nil
        }
        return pillFrames[index].offsetBy(dx: frame.minX, dy: frame.minY)
    }

    func currentRow() -> ButtonRowBlock {
        ButtonRowBlock(id: id, buttons: buttons, alignment: alignment)
    }

    /// Replaces one pill (nil removes it). Returns false when the index is out of range.
    @discardableResult
    func replaceButton(at index: Int, with button: ButtonRef?) -> Bool {
        guard buttons.indices.contains(index) else {
            return false
        }
        if let button {
            buttons[index] = button
        } else {
            buttons.remove(at: index)
        }
        repack(width: layoutWidth)
        return true
    }

    func setAlignment(_ alignment: ButtonRowAlignment) {
        self.alignment = alignment
        repack(width: layoutWidth)
    }
}

@available(iOS 13.0, *)
extension ButtonRowBox: CanvasBlock {
    /// View-backed, like every other block type. TWO reasons, and the first alone is decisive:
    /// `reconcileBlockViews` realizes a `BlockBackingView` only when this is true and the canvas has no
    /// `draw(_:)` override, so a block that opts out is never drawn AT ALL. And the pills must be views
    /// anyway — a label can carry a custom emoji, which needs a live host view a bitmap cannot provide.
    var rendersAsBlockView: Bool { true }

    var nodeStart: Int { get { globalStart } set { globalStart = newValue } }

    /// One atom per pill plus the two container tokens. MUST equal what `DocumentTree` produces for the
    /// same row, including the `max(1, …)` floor that keeps an EMPTY row selectable.
    var nodeSize: Int { max(1, buttons.count) + 2 }

    // The single-text-region members are degenerate: this block owns no editable text.
    var textLayout: BlockLayoutEngine { emptyLayout }
    var textStart: Int { globalStart }
    var textLength: Int { 0 }
    var textRef: TextNodeRef { .paragraph(id) }
    var textOrigin: CGPoint { frame.origin }

    var height: CGFloat { packedHeight }

    func measuredHeight(forWidth width: CGFloat) -> CGFloat {
        // Pure: packs against `width` without mutating this box's live layout.
        let packed = richTextPackButtonRow(
            buttons: buttons,
            alignment: alignment,
            availableWidth: max(0.0, width - (showsMenuAffordance ? ButtonRowBox.menuButtonReserve : 0.0)),
            metrics: mapper.styleSheet.metrics.button,
            isRTL: mapper.baseWritingDirection == .rightToLeft,
            hasIcon: { [mapper] button in mapper.buttonHasIcon(button.action) },
            measure: { [mapper] button, maxWidth, padding in
                mapper.buttonAttachment(button: button, isBlockPill: true, maxWidth: maxWidth,
                                        horizontalPadding: padding)
            }
        )
        // Mirrors `layoutMenuButton`: the reserve guarantees the control fits, so the height is just
        // the packed height, floored at one pill row (an EMPTY row still shows the control).
        return max(packed.totalHeight, mapper.styleSheet.metrics.button.blockRowHeight)
    }

    func setWidth(_ width: CGFloat) { repack(width: width) }

    func currentBlock() -> Block { .buttonRow(currentRow()) }

    /// Snaps to the atom position of the nearest pill. An empty row has one atom and no pill, so it
    /// resolves to that single interior slot.
    func closestPosition(toCanvasPoint point: CGPoint) -> Int {
        guard let index = nearestPillIndex(toCanvasPoint: point) else {
            return globalStart + 1
        }
        return globalStart + 1 + index
    }

    /// EMPTY by design — the row owns no editable text. This is what keeps the caret off a pill's
    /// label and routes every interaction through the atom positions instead.
    func leafRegions() -> [LeafTextRegion] { [] }

    /// Deliberately EMPTY: the row draws nothing into a bitmap. Its pills are `ButtonPillView` subviews
    /// of `ButtonRowBackingView`, so each can host a live custom-emoji view in its label.
    func draw(in ctx: CGContext, imageProvider: (String) -> UIImage?) {}

    var spacingKind: RichTextBlockSpacingKind { .buttonRow }
}
#endif
