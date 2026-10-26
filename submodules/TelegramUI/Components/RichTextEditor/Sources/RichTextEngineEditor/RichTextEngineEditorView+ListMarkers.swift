#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit
import RichTextInputDecUpstream

/// List markers — the bullet, the ordinal, the checkbox — as host-positioned views in the gutter.
///
/// **A marker is not text, and it must not become text.** The mapper already reserves the gutter:
/// `StyleSheet.paragraphStyle(list:)` indents a list item by `listIndentStep * level` plus the
/// marker spacing, so the space is there whether or not anything is drawn in it — which is exactly
/// what the engine editor showed before this file existed, a correctly indented list with an empty
/// gutter. What was missing is the ornament.
///
/// It cannot come from the two seams that carry the editor's other non-text decoration.
/// `IDBlockLayout.displayDecorator` returns an `NSAttributedString`, so it can only restyle text
/// that is already there; it has nothing to say about the gutter. And writing the marker INTO the
/// block's text is worse than it looks: a role is structure only, so the engine's text is the one
/// copy of the document's characters, and a prefix would shift every canonical offset after it —
/// selection, the flat geometry in `+EditPrimitives.swift`, and every rule the surface gate decides
/// by offset. The legacy editor does not do that either: it draws the marker in `BlockBox.draw`.
///
/// So a marker is a pooled view per list block, positioned from that block's frame — the third
/// member of the family `+ContainerDecoration.swift` documents, and parented the same way, INTO the
/// engine's scroll content so it scrolls with the text instead of needing a scroll hook.
///
/// Geometry is legacy's, re-derived rather than guessed: the marker hangs at
/// `listIndentStep * level` from the block's leading edge (NOT past `listMarkerSpacing` — that gap
/// is what the text hangs past, and the marker sits in it).
///
/// **Its BASELINE is the engine's, measured rather than assumed.** This file used to put the marker's
/// line box at the block's top on the strength of the V2 identity `firstBaselineFromTop(font) ==
/// font.ascender` — true of legacy, which CORRECTS TextKit's placement back to V2's
/// (`BlockLayoutEngine.baselineDelta`) before drawing a marker on it, and false here: the engine
/// draws its own attributed text with no such correction, and TextKit bottom-aligns a line inside
/// the box the paragraph style pins (`minimumLineHeight == maximumLineHeight` at V2's pitch, which
/// is taller than the font's natural line). So the marker floated `pitch - lineHeight` above its
/// text — 1.7pt at body, 4.0pt at a heading — which is the misalignment the device reported
/// (K3, 2026-09-11). `EngineListMarkerGeometry.baselineFromLineTop` is where the engine's rule
/// lives now, and `EngineListMarkerAlignmentTests` pins it against RENDERED INK, the only evidence
/// that can speak about where a glyph actually lands.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// One marker label per engine block that is a list item, keyed by the block's id.
    ///
    /// Computed by Core's `ListNumbering` from structure ALONE — `currentRoles`, never
    /// `currentBlocks` — so a layout pass costs no text materialisation. A role that is not a
    /// paragraph (a code block, a cell, an author line) contributes a list-less paragraph, which is
    /// what makes a container END a numbered run rather than being counted through: exactly the
    /// answer `EngineBlockAccessors.listMembership` already gives for the model side.
    ///
    /// **Every container body is its own numbering scope**, in both directions. A quote's author line
    /// ends a run AFTER its children, but nothing list-less precedes its first child, so a quoted
    /// item used to continue the list above the quote (`1. 2. ▌3.`) — the legacy canvas numbers each
    /// expanded quote/details body from 1 (`DocumentCanvasView.listMarkerLabels`). So a list-less
    /// boundary is fed wherever the enclosing containers change (composer harness, 2026-09-23,
    /// `HarnessQuotedListNumberingTests`).
    internal func listMarkerLabels() -> [BlockID: String] {
        var paragraphs: [ParagraphBlock] = []
        paragraphs.reserveCapacity(currentRoles.count + 1)
        var previousScope: [BlockID]?
        for role in currentRoles {
            let scope = role.ancestry.map(\.id)
            if let previousScope, previousScope != scope {
                paragraphs.append(ParagraphBlock(id: Self.listNumberingScopeBoundaryID))
            }
            previousScope = scope
            guard let paragraph = role.shape.paragraph, role.owningTable == nil else {
                paragraphs.append(ParagraphBlock(id: role.blockID))
                continue
            }
            paragraphs.append(ParagraphBlock(id: paragraph.id, style: paragraph.style, list: paragraph.list))
        }
        return ListNumbering.labels(for: paragraphs)
    }

    /// The id of the synthetic list-less paragraph `listMarkerLabels()` feeds at a scope boundary. It
    /// is never labelled (only list items are), so every boundary can share it.
    private static let listNumberingScopeBoundaryID = BlockID("tgid.list-numbering-scope-boundary")

    /// The extra LEFT inset each ordered item needs for a marker wider than one character, by ROLE
    /// index. Pushed to the engine as a block inset (`syncContainerBlockInsets`), which moves that
    /// block's text right and narrows it, and subtracted again where the marker is placed so the
    /// marker stays in its gutter and only the TEXT moves.
    ///
    /// **A block inset rather than the paragraph style**, deliberately. The indent is a function of
    /// the item's NUMBER, and the number changes without the item being edited — insert an item
    /// above and everything below renumbers. An indent baked into the attributed string would go
    /// stale exactly then, and only the blocks settle happened to touch would be repaired; this is
    /// recomputed from the roles on every layout pass, like the markers themselves, so it cannot.
    ///
    /// Cells are excluded for the same reason they are unmarked: a list inside a table cell draws
    /// no marker in either editor, so indenting its text would open a gap for a marker that is
    /// never there.
    internal func orderedListMarkerInsets() -> [Int: CGFloat] {
        orderedListMarkerColumns().compactMapValues { $0.reservation > 0 ? $0.reservation : nil }
    }

    /// **The COLUMN each ordered item belongs to — one per list, not one per item.**
    ///
    /// The V2 renderer measures every marker in a list, keeps `maxIndexWidth`, RIGHT-aligns each
    /// marker to that shared column and starts every item's text past it
    /// (`InstantPageV2Layout.swift:3390,3428,3463,3489`). So the bubble draws a list that crosses
    /// ten with its periods in one column and its text in another.
    ///
    /// This file used to answer per ITEM, which put the extra width of `10.` onto that item's text
    /// alone: measured on a 1…12 list, items 1–9 laid text at x=5.0 and items 10–12 at 15.28, and no
    /// two periods aligned anywhere. Taking the run's MAXIMUM is the whole fix — the reservation is
    /// still counted in CHARACTERS rather than measured off the rendered glyphs, so `1.` and `7.`
    /// cannot indent differently and a renumber cannot shift the text, but it is counted once for
    /// the list instead of once per item.
    ///
    /// `width` is measured rather than counted, because it positions the marker rather than
    /// reserving space for it: it is the widest label actually drawn in the run, which is exactly
    /// what V2's `maxIndexWidth` is.
    ///
    /// **A run ends where the numbering does.** Any role that is not an ordered item at the same
    /// level closes it — a paragraph between two lists, a container, a different nesting level — so
    /// a short list below a long one gets its own column rather than inheriting a width it has no
    /// numbers for. That mirrors `ListNumbering`, which restarts its count at the same boundaries.
    internal func orderedListMarkerColumns() -> [Int: (reservation: CGFloat, width: CGFloat)] {
        let labels = listMarkerLabels()
        var result: [Int: (reservation: CGFloat, width: CGFloat)] = [:]

        var index = 0
        while index < currentRoles.count {
            guard let level = orderedItemLevel(at: index, labels: labels) else {
                index += 1
                continue
            }
            var end = index
            // A container boundary ends the run too, as it ends the numbering (`listMarkerLabels`).
            let scope = currentRoles[index].ancestry.map(\.id)
            while end < currentRoles.count, orderedItemLevel(at: end, labels: labels) == level,
                  currentRoles[end].ancestry.map(\.id) == scope {
                end += 1
            }
            var reservation: CGFloat = 0
            var width: CGFloat = 0
            for member in index..<end {
                guard let paragraph = currentRoles[member].shape.paragraph,
                      let label = labels[paragraph.id] else { continue }
                // The mapper the BRIDGE rendered this role with — a quoted item is 15pt, and a digit
                // measured on the plain 17pt sheet would reserve too much.
                let styleSheet = bridge.renderMapper(for: currentRoles[member]).styleSheet
                let font = styleSheet.font(for: paragraph.style, attributes: .plain)
                reservation = max(reservation,
                                  EngineListMarkerGeometry.orderedMarkerExtraInset(label: label,
                                                                                   font: font))
                width = max(width, (label as NSString).size(withAttributes: [.font: font]).width)
            }
            for member in index..<end { result[member] = (reservation, width) }
            index = end
        }
        return result
    }

    /// The nesting level of the ordered list item at `index`, or nil if that role is not one — the
    /// single rule the run walk above breaks on.
    private func orderedItemLevel(at index: Int, labels: [BlockID: String]) -> Int? {
        let role = currentRoles[index]
        guard role.owningTable == nil,
              let paragraph = role.shape.paragraph,
              let list = paragraph.list, list.marker == .ordered,
              labels[paragraph.id] != nil else { return nil }
        return list.level
    }

    /// Reconciles marker views against the list items in the current document. Idempotent; driven
    /// from `layoutSubviews` once the engine has laid out, like every other host-positioned overlay.
    internal func syncListMarkers() {
        guard !currentRoles.isEmpty || !listMarkerViews.isEmpty else { return }
        let labels = listMarkerLabels()
        let orderedColumns = orderedListMarkerColumns()
        var live: Set<BlockID> = []

        for (index, role) in currentRoles.enumerated() {
            // Cells are deliberately unmarked, matching legacy: `stampListMarkers` skips table-cell
            // boxes, so a list inside a cell draws no marker in either editor.
            guard role.owningTable == nil,
                  let paragraph = role.shape.paragraph,
                  let membership = paragraph.list,
                  let label = labels[paragraph.id] else { continue }
            let frame = engine.id_frameForBlock(at: UInt(index))
            // CGRectNull is the engine's answer for an unknown index — never treated as a rect.
            guard !frame.isNull, frame.width > 0, frame.height > 0 else { continue }

            // The mapper the BRIDGE rendered this role with, never the plain one: a quote renders its
            // text at 15pt, and a marker resolving its own font from the plain mapper is a 17pt "1."
            // beside 15pt text.
            let styleSheet = bridge.renderMapper(for: role).styleSheet
            let font = styleSheet.font(for: paragraph.style, attributes: .plain)
            // MINUS the block inset a wide ordinal moved this block's text by: the engine reports a
            // frame that already carries it, and the marker is the one thing that must NOT move —
            // it stays in its gutter while the text hangs further past it.
            let leading = frame.minX - (orderedColumns[index]?.reservation ?? 0)
                + role.contentIndent(styleSheet: styleSheet)
                + StyleSheet.listIndentStep * CGFloat(max(0, membership.level))
            // WHERE THE ENGINE PUTS THE TEXT'S BASELINE, not where V2 says a baseline goes.
            //
            // `frame` is the block's line box, and the engine's paragraph style PINS that box to
            // V2's pitch (`minimumLineHeight == maximumLineHeight`), which is TALLER than the font's
            // natural line. TextKit bottom-aligns the line inside a pinned box — measured across
            // every style, the baseline sits exactly `descender` above the box's bottom — so placing
            // the marker at the font's ascender from the box TOP leaves it `pitch - lineHeight`
            // high: 1.7pt at body and 4.0pt at a heading, which is what the device reported.
            //
            // Legacy does not have this problem because it CORRECTS TextKit's placement back to
            // V2's (`BlockLayoutEngine.baselineDelta`) and then puts the marker on the corrected
            // baseline. The engine draws its own attributed text with no such correction, so the
            // marker has to meet the engine where it actually draws.
            // READ OFF THE STRING THE ENGINE LAID OUT, NEVER OFF THE STYLESHEET. `engineReadable`
            // re-expresses the pinned box (`EngineDocumentBridge.V2BaselinePlacement`) as a smaller
            // box plus a `lineSpacing` remainder, so `styleSheet.paragraphStyle(...)` still reports
            // the PITCH while the glyphs sit in the smaller box. Using it left the marker
            // `pitch - box` BELOW its text — measured the moment the mode was turned on, before this
            // line changed: body -2.0, H1 -3.0, H2 -4.0, caption -2.0, quoted -1.0. That is the
            // defect this file was written to fix in 2026-09-11, with its sign flipped.
            let pinnedLineHeight = (bridge.lineAttributes(for: role)[.paragraphStyle]
                as? NSParagraphStyle)?.maximumLineHeight ?? 0
            let markerTop = frame.minY + EngineListMarkerGeometry.baselineFromLineTop(
                font: font, pinnedLineHeight: pinnedLineHeight) - font.ascender

            live.insert(paragraph.id)
            if membership.marker == .checklist, deferredConfiguration.checklistMarkerViewProvider != nil {
                syncChecklistMarker(id: paragraph.id, checked: membership.checked == true,
                                    font: font, leading: leading, markerTop: markerTop)
            } else {
                syncLabelMarker(id: paragraph.id, label: label, font: font,
                                leading: leading, markerTop: markerTop,
                                columnWidth: orderedColumns[index]?.width,
                                isChecklist: membership.marker == .checklist)
            }
        }

        for (id, view) in listMarkerViews where !live.contains(id) {
            view.removeFromSuperview()
            listMarkerViews.removeValue(forKey: id)
        }
    }

    /// A drawn marker: the bullet glyph, the ordinal, or — with no host checkbox provider — the
    /// checklist's own `☐`/`☑`, which is what `ListNumbering` hands back for one.
    /// `columnWidth` is the ordered run's shared marker column (nil for a bullet or a checklist,
    /// which have nothing to align to each other). The label is RIGHT-aligned inside it, which is
    /// what puts every period in one column — V2's `alignment: .right` for a `.number` marker. A
    /// bullet keeps its left edge on the gutter, as it always did: its column is one glyph wide, so
    /// the two placements coincide.
    private func syncLabelMarker(id: BlockID, label: String, font: UIFont,
                                 leading: CGFloat, markerTop: CGFloat,
                                 columnWidth: CGFloat? = nil, isChecklist: Bool) {
        let marker: ListMarkerLabelView
        if let existing = listMarkerViews[id] as? ListMarkerLabelView {
            marker = existing
        } else {
            listMarkerViews[id]?.removeFromSuperview()
            let fresh = ListMarkerLabelView()
            // ABOVE the container bands: a quoted list's marker draws over the quote's fill.
            engine.addSubview(fresh)
            listMarkerViews[id] = fresh
            marker = fresh
        }
        marker.apply(label: label, font: font, color: bridge.theme.listMarker)
        // `markerTop` is the top of the marker's own LINE BOX — the label draws its glyphs with
        // their baseline one ascender below its origin, so this lands the marker's baseline on the
        // text's.
        let width = marker.intrinsicWidth
        // Right-aligned to the run's column when there is one, so the periods line up. `max(0, …)`
        // because the column is the widest label MEASURED in the run and this label is one of them —
        // the offset cannot go negative, but a run whose labels changed between the column being
        // computed and the view being framed would otherwise pull the marker left of its gutter.
        let x = leading + max(0, (columnWidth ?? width) - width)
        marker.frame = CGRect(x: x, y: markerTop, width: width, height: font.lineHeight)
        // A checklist drawn as a glyph is still a checkbox: legacy hit-tests the marker rect whether
        // or not a host supplied a view, so ticking one must not depend on the host's configuration.
        marker.isTappableCheckbox = isChecklist
        marker.isUserInteractionEnabled = isChecklist
        if isChecklist, marker.gestureRecognizers?.isEmpty ?? true {
            marker.addGestureRecognizer(gatedTapRecognizer(action: #selector(handleChecklistMarkerTap(_:))))
        }
    }

    /// The host's tappable checkbox. Sized and placed by legacy's rule: a square of the font's cap
    /// height scaled by `checklistMarkerScale`, left edge on the gutter, and the growth taken
    /// equally above and below the unscaled box's centre so a bigger checkbox stays on the text's
    /// optical line rather than sinking below it.
    private func syncChecklistMarker(id: BlockID, checked: Bool, font: UIFont,
                                     leading: CGFloat, markerTop: CGFloat) {
        let baseSide = StyleSheet.checklistMarkerSize(for: font)
        let side = (baseSide * StyleSheet.checklistMarkerScale).rounded(.down)
        let marker: ListCheckboxHostView
        if let existing = listMarkerViews[id] as? ListCheckboxHostView {
            marker = existing
            marker.setChecked(checked)
        } else {
            listMarkerViews[id]?.removeFromSuperview()
            guard let provided = deferredConfiguration.checklistMarkerViewProvider?(checked, CGSize(width: side, height: side))
            else { return }
            let host = ListCheckboxHostView(checkbox: provided)
            host.addGestureRecognizer(gatedTapRecognizer(action: #selector(handleChecklistMarkerTap(_:))))
            engine.addSubview(host)
            listMarkerViews[id] = host
            marker = host
        }
        // Anchored on the same baseline the drawn markers use — `markerTop + ascender` — so the
        // checkbox and a bullet sit on one line.
        let baseCentre = markerTop + font.ascender - baseSide / 2.0
        marker.frame = CGRect(x: leading.rounded(.down), y: (baseCentre - side / 2.0).rounded(.down),
                              width: side, height: side)
    }

    @objc internal func handleChecklistMarkerTap(_ recognizer: UITapGestureRecognizer) {
        guard let view = recognizer.view,
              let id = listMarkerViews.first(where: { $0.value === view })?.key else { return }
        toggleChecklistItem(id)
    }

    /// Flips one checklist item's `checked`, as ONE undo step that does not disturb the text.
    ///
    /// `adoptRolePlan` is the right primitive and the only one that fits: a role is structure, the
    /// checkbox state IS structure, and nothing about the block's characters changes — so this is
    /// precisely the "structure change WITHOUT an edit" that primitive exists for. Going through a
    /// document set instead would rebuild every role for a change of one flag. One undo step, taken
    /// as a snapshot before the flip (`+UndoStack.swift`), so redo falls out of the same mechanism.
    public func toggleChecklistItem(_ id: BlockID) {
        guard let index = currentRoles.firstIndex(where: { $0.blockID == id }),
              var paragraph = currentRoles[index].shape.paragraph,
              let list = paragraph.list, list.marker == .checklist else { return }
        let undoBefore = currentUndoSnapshot()
        paragraph.list = ListMembership(marker: .checklist, level: list.level,
                                        checked: !(list.checked == true))
        var plan = currentRoles
        plan[index] = currentRoles[index].replacingShape(.paragraph(paragraph))
        let selection = engineSelectedRange
        performHostStructuralChange {
            adoptRolePlan(plan)
            engineSelectedRange = selection
        }
        recordUndoStepForCommand(restoring: undoBefore)
        setNeedsLayout()
    }
}

/// The one piece of marker geometry both marker kinds need, kept in one place so the drawn label
/// and the hosted checkbox cannot drift apart on where the text's baseline is.
@available(iOS 18.4, *)
internal enum EngineListMarkerGeometry {
    /// Where the ENGINE puts a line's baseline inside the box it laid out, measured from the box's
    /// top. TextKit bottom-aligns the line in a box pinned by `minimumLineHeight ==
    /// maximumLineHeight`, so the baseline sits one descender above the bottom.
    ///
    /// `pinnedLineHeight` is that paragraph style's `maximumLineHeight`; 0 means the style pins
    /// nothing (an explicit model-level `lineHeightMultiple` takes over instead — see
    /// `StyleSheet.paragraphStyle`), and the box is then the font's own line, for which this
    /// degrades to the font's ascender exactly.
    static func baselineFromLineTop(font: UIFont, pinnedLineHeight: CGFloat) -> CGFloat {
        let box = pinnedLineHeight > 0 ? pinnedLineHeight : font.lineHeight
        return box + font.descender      // `descender` is negative
    }

    /// How much further right an ORDERED item's text must start than the base indent reserves,
    /// because its marker is wider than one character: `10.` beside text laid out for `1.` is drawn
    /// straight through it (K3, 2026-09-11 — the list read `10F`, `11F`).
    ///
    /// **Counted in characters and measured on ONE digit, never on the rendered label.** The label's
    /// own width varies with its glyphs, so `1.` and `7.` would indent differently and the text
    /// would shift as a list is renumbered; `count × digit + constant` gives every label of the same
    /// length the same indent, which is what keeps a decade of items in one column. The digit is
    /// `0`, whose advance is the tabular figure width in the system font, and the level-1 and
    /// level-2 ladders (`a.`, `iii.`) are counted the same way — their glyphs are narrower than a
    /// figure, so they are reserved slightly generously rather than clipped.
    ///
    /// Zero for a one-character label, which is every ordinal below 10 at level 0: the base indent
    /// (`listMarkerSpacing + orderedListTextInset`) is exactly the `constant` of that formula and
    /// stays the whole answer there, so no existing document moves.
    static func orderedMarkerExtraInset(label: String, font: UIFont) -> CGFloat {
        let characters = label.hasSuffix(".") ? label.count - 1 : label.count
        guard characters > 1 else { return 0 }
        let digit = ("0" as NSString).size(withAttributes: [.font: font]).width
        return CGFloat(characters - 1) * digit
    }

    /// Legacy's rule, reused: a checkbox is about 17pt of drawn glyph at body size, so the RECT is
    /// inflated to at least 30pt in each direction before it is asked whether it was hit
    /// (`DocumentCanvasView.checklistBox(atCanvasPoint:)`). Drawn size and touch target are
    /// different questions, and answering the second with the first makes a checkbox that ignores
    /// most taps aimed at it.
    static let minimumTouchTarget: CGFloat = 30.0

    static func touchTarget(for bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: -max(0.0, (minimumTouchTarget - bounds.width) / 2.0),
                       dy: -max(0.0, (minimumTouchTarget - bounds.height) / 2.0))
    }
}

/// The host's checkbox, in a wrapper the editor owns.
///
/// The wrapper exists for the touch target. A provided view is sized to the DRAWN checkbox, and the
/// editor cannot override `point(inside:)` on someone else's view — so the tap lands on this
/// instead, which is the same size but answers the hit test for the inflated rect. It also keeps
/// `setChecked` in one place, so the model and the drawn state cannot drift.
@available(iOS 18.4, *)
internal final class ListCheckboxHostView: UIView {
    private let checkbox: UIView & RichTextChecklistMarkerView

    init(checkbox: UIView & RichTextChecklistMarkerView) {
        self.checkbox = checkbox
        super.init(frame: .zero)
        backgroundColor = .clear
        addSubview(checkbox)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setChecked(_ checked: Bool) { checkbox.setChecked(checked, animated: true) }

    /// Test seam: what the host actually supplied, so a test can assert the drawn state rather than
    /// the wrapper's.
    internal var hostedCheckbox: UIView & RichTextChecklistMarkerView { checkbox }

    override func layoutSubviews() {
        super.layoutSubviews()
        checkbox.frame = bounds
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        EngineListMarkerGeometry.touchTarget(for: bounds).contains(point)
    }
}

/// A drawn marker. Its own view rather than a `UILabel` because the marker's BASELINE has to land on
/// the text's, and a label centres its text in its bounds instead — the marker would sit a fraction
/// low at every font size, differently per style. Drawing the string at the view's origin puts the
/// line box where the caller placed it, which is the same thing `BlockBox.draw` does.
@available(iOS 18.4, *)
internal final class ListMarkerLabelView: UIView {
    private(set) var label: String = ""
    private(set) var markerFont: UIFont = .systemFont(ofSize: 17.0)
    private(set) var markerColor: UIColor = .label
    /// A checklist glyph is a control, not an ornament: it takes taps, with the same enlarged target
    /// the hosted checkbox gets.
    var isTappableCheckbox = false

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard isTappableCheckbox else { return super.point(inside: point, with: event) }
        return EngineListMarkerGeometry.touchTarget(for: bounds).contains(point)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(label: String, font: UIFont, color: UIColor) {
        guard label != self.label || font != markerFont || color != markerColor else { return }
        self.label = label
        markerFont = font
        markerColor = color
        setNeedsDisplay()
    }

    var intrinsicWidth: CGFloat {
        (label as NSString).size(withAttributes: [.font: markerFont]).width
    }

    override func draw(_ rect: CGRect) {
        (label as NSString).draw(at: .zero, withAttributes: [.font: markerFont,
                                                             .foregroundColor: markerColor])
    }
}
#endif
