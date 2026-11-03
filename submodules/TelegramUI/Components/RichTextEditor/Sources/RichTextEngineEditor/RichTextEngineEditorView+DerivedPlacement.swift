#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// Where a derived view GOES — one derivation per kind, read by the pass that places it and by the
/// check that says whether it is still there.
///
/// The existing `derivedViewShortfall` asks whether a view EXISTS. Every table bug this branch took
/// from a device report was the other question: the view existed and was in the wrong place. The
/// chrome stayed put while the cells scrolled under it (the placement pass never ran); the outline
/// sat one offset left of its cell (the offset was applied twice); a table drew on top of the one
/// above it (the grid re-derived a number the cells had already been placed by). Each of those is
/// "the view's frame is not what the geometry says it is" — checkable, on every pass, from here.
///
/// The rule these helpers exist to keep: a placement pass and the check that verifies it must not be
/// two derivations of one number. They are the same function, called twice — once to apply, once to
/// compare — so the check can only catch a pass that did not run, never disagree about the answer.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    /// Where an overlay pinned to an inline attachment goes: its host view, and its frame in that
    /// host's coordinates. Inside a placed run the overlay belongs to the run's content view, so it
    /// rides the table's horizontal scroll with the glyphs it is pinned to; elsewhere it is the
    /// engine's own child. The pills, the formula tap targets and the custom emoji all read this.
    /// **The engine answers with the LAYOUT'S RESERVATION, which for a custom emoji is not what the
    /// reader sees.** `id_attachmentFrame` is the box TextKit reserved from `attachmentBounds`;
    /// `EmojiTextAttachment.renderBoost` is the amount an emoji is drawn larger than its reservation,
    /// and the legacy canvas has always added it (its box comes from `BlockLayout.attachmentBox`,
    /// which does). This surface added it nowhere, so the same 15pt emoji measured 17.9pt in an
    /// engine block against 21.9pt in a folded quote's preview — the reported "the custom emoji size
    /// differs between collapsed and expanded quotes". `visibleBox` is the identity for every other
    /// attachment kind, so the pills and the formula targets are untouched by passing through it.
    ///
    /// It belongs HERE rather than in the emoji sync because this function is also what the placement
    /// check re-reads: applied at the sync alone, every hosted emoji would read as drifted by the
    /// boost, which is the check correctly reporting two derivations of one number.
    internal func attachmentOverlayPlacement(canonicalOffset: Int,
                                             roleIndex: Int?) -> (host: UIView, frame: CGRect)? {
        let reserved = engine.id_attachmentFrame(forCanonicalOffset: UInt(canonicalOffset))
        guard !reserved.isNull, reserved.width > 0, reserved.height > 0 else { return nil }
        let frame = EmojiTextAttachment.visibleBox(
            reserved, for: attachment(atCanonicalOffset: canonicalOffset, roleIndex: roleIndex))
        guard let roleIndex, roleIndex >= 0,
              let run = engine.id_placedRunContentViewForBlock(at: UInt(roleIndex)) else {
            return (engine, frame)
        }
        return (run, engine.convert(frame, to: run))
    }

    /// The attachment the engine has at `canonicalOffset`, read out of the engine's own text — the
    /// same copy the layout measured, so the box and the attachment describing it cannot be from two
    /// different documents.
    private func attachment(atCanonicalOffset canonicalOffset: Int,
                            roleIndex: Int?) -> NSTextAttachment? {
        guard let roleIndex, roleIndex >= 0 else { return nil }
        let blocks = engine.attributedBlocks
        guard roleIndex < blocks.count else { return nil }
        let local = canonicalOffset - flatOffset(ofRoleAt: roleIndex)
        guard local >= 0, local < blocks[roleIndex].length else { return nil }
        return blocks[roleIndex].attribute(.attachment, at: local, effectiveRange: nil) as? NSTextAttachment
    }

    /// Where a table's GRID chrome goes: inside the run's content view at the placement the cells
    /// were placed by, or — for a table the engine did not place — at the table's own frame.
    internal func gridChromePlacement(forTableAt index: Int) -> (host: UIView, frame: CGRect)? {
        guard index < currentRoles.count, let table = currentRoles[index].owningTable else { return nil }
        guard let content = engine.id_placedRunContentViewForBlock(at: UInt(index)) else {
            guard let frame = tableFrame(forTableAt: index) else { return nil }
            return (engine, frame)
        }
        guard let placement = tablePlacements[table.id] else { return nil }
        return (content, CGRect(origin: CGPoint(x: placement.indent, y: placement.dy), size: placement.size))
    }

    /// WHERE A TABLE IS CLIPPED, in the engine's own x — **the cells and the chrome, at one
    /// boundary.** The engine cuts the cells here (`placedRunClipOutsets`) and the structural chrome
    /// view IS this window, so nothing the table draws can stop at a different place from anything
    /// else it draws.
    ///
    /// At the TOP LEVEL that is the canvas itself: the table is positioned at the text inset like
    /// every other block, but a scrolled one passes UNDER the inset and is cut at the editor's edge
    /// rather than stopping short of it. NESTED, it is the container's interior opened by a grip's
    /// reach — the table's handles hang off its edges into the container's own indent, and they are
    /// part of what the table draws.
    ///
    /// **Where the table RESTS is a different question** and the clip does not answer it
    /// (`tableColumnOutsets`): the run scrolls until its far edge reaches its column — the
    /// container's interior — and this window shows the gutter beyond that, which is exactly where
    /// the grip hanging off that edge is drawn. Derived from the clip instead, the table would come
    /// to rest out in the container's margin and put the grip back outside the window.
    internal func tableClipX(forTableAt index: Int) -> (min: CGFloat, max: CGFloat)? {
        guard index < currentRoles.count, currentRoles[index].owningTable != nil else { return nil }
        let outsets = tableClipOutsets(forTableAt: index)
        let columnMin = engine.textContainerInset.left
        return (columnMin - outsets.left, columnMin + availableTableWidth + outsets.right)
    }

    /// The same rule as `tableClipX`, in the form the engine takes: how far the run's clip sits
    /// outside its text column, positive to widen and negative to narrow.
    internal func tableClipOutsets(forTableAt index: Int) -> UIEdgeInsets {
        guard index < currentRoles.count, currentRoles[index].owningTable != nil else { return .zero }
        if currentRoles[index].ancestry.isEmpty {
            // Out to the canvas on both sides.
            return UIEdgeInsets(top: 0, left: engine.textContainerInset.left,
                                bottom: 0, right: engine.textContainerInset.right)
        }
        // The container's interior, opened by a grip's reach on each side: a nested table is flush
        // with that interior, so a grip hanging outside the grid hangs into the container's own
        // indent — and the table's window has to admit it, or the handle is cut (K3, 2026-09-11).
        // The interior itself is where the table RESTS, which `tableColumnOutsets` says separately.
        let column = tableColumnOutsets(forTableAt: index)
        let gutter = EngineTableStructuralChrome.gripGutter
        return UIEdgeInsets(top: 0, left: column.left + gutter, bottom: 0, right: column.right + gutter)
    }

    /// WHERE A TABLE RESTS: its own column, as an outset from the text column. The engine scrolls a
    /// run until its far edge reaches this, whatever the clip shows beyond it.
    ///
    /// A top-level table's column IS the text column. A nested one's is its container's interior —
    /// indented past the quote's bar and stopping short of the column by the quote's trailing inset,
    /// which is exactly where its own paragraphs stop.
    internal func tableColumnOutsets(forTableAt index: Int) -> UIEdgeInsets {
        guard index < currentRoles.count, let table = currentRoles[index].owningTable,
              !currentRoles[index].ancestry.isEmpty else { return .zero }
        let placement = tablePlacements[table.id]
        return UIEdgeInsets(top: 0, left: -(placement?.containerIndent ?? 0),
                            bottom: 0, right: -(placement?.containerTrailingInset ?? 0))
    }

    /// Where the STRUCTURAL chrome goes, in the engine's own space: it IS the table's clip window,
    /// horizontally, so `clipsToBounds` cuts the grips and the outline exactly where the engine cuts
    /// the cells. Vertically it reaches a knob's overhang above the table and the column grip's band
    /// below. Hosted in the engine rather than the run so the row grips can ride the scroll by the
    /// per-element offset `viewRect(_:)` applies, rather than by the run moving under them.
    internal func structuralChromeFrame(forTableAt index: Int) -> CGRect? {
        guard index < currentRoles.count, currentRoles[index].owningTable != nil,
              let tableFrame = tableFrame(forTableAt: index),
              let clip = tableClipX(forTableAt: index) else { return nil }
        let offset = engine.id_placedRunContentOffsetForBlock(at: UInt(index))
        // `tableFrame` is where the engine PUT the first cell, and that rides the run's scroll.
        let anchored = tableFrame.offsetBy(dx: offset, dy: 0)
        let knobOverhang = EngineTableStructuralChrome.knobOverhang
        return CGRect(x: clip.min, y: anchored.minY - knobOverhang,
                      width: clip.max - clip.min,
                      height: knobOverhang + anchored.height + EngineTableStructuralChrome.gripHeight)
    }

    /// Where the table's own top-left sits INSIDE that window. The chrome's contents are placed from
    /// here, so the window can move or resize without any of them moving.
    internal func structuralChromeTableOrigin(forTableAt index: Int) -> CGPoint? {
        guard let tableFrame = tableFrame(forTableAt: index), let clip = tableClipX(forTableAt: index)
        else { return nil }
        let offset = engine.id_placedRunContentOffsetForBlock(at: UInt(index))
        return CGPoint(x: tableFrame.minX + offset - clip.min,
                       y: EngineTableStructuralChrome.knobOverhang)
    }

    /// Every derived view whose FRAME the geometry decides, against what it decides now. A finding
    /// here means a placement pass did not run when it should have — the two numbers come from one
    /// function, so they cannot disagree for any other reason.
    ///
    /// Attachment overlays are checked for their HOST as well as their frame: an overlay left in the
    /// engine when it belongs in a run looks right until the table scrolls, and then slides off its
    /// glyphs.
    internal func derivedViewPlacementDrift() -> [String] {
        var findings: [String] = []
        func check(_ label: String, _ view: UIView, _ expected: (host: UIView, frame: CGRect)) {
            if view.superview !== expected.host {
                findings.append("\(label) hosted in \(type(of: view.superview ?? view)) "
                                + "and not \(type(of: expected.host))")
            } else if !frame(view.frame, matches: expected.frame) {
                findings.append("\(label) at \(compact(view.frame)) wants \(compact(expected.frame))")
            }
        }

        var index = 0
        while index < currentRoles.count {
            guard let table = currentRoles[index].owningTable else { index += 1; continue }
            let first = index
            while index < currentRoles.count, currentRoles[index].containerID == table.id { index += 1 }
            if let chrome = tableChromeViews[table.id], let expected = gridChromePlacement(forTableAt: first) {
                check("grid chrome \(table.id.rawValue)", chrome, expected)
            }
            if let chrome = tableStructuralChromeViews[table.id], let expected = structuralChromeFrame(forTableAt: first) {
                check("structural chrome \(table.id.rawValue)", chrome, (engine, expected))
                // The chrome's frame is anchored at the table's UNSCROLLED origin, so it does not
                // move when the run scrolls — the scroll reaches its contents through these two
                // values instead, and they are what went stale while the outline, the knobs and the
                // column grip stayed put over moving cells.
                let offset = engine.id_placedRunContentOffsetForBlock(at: UInt(first))
                if abs(chrome.currentContentOffsetX - offset) >= 0.5 {
                    findings.append("structural chrome \(table.id.rawValue) drawn at offset "
                                    + String(format: "%.1f", chrome.currentContentOffsetX)
                                    + " with the run at " + String(format: "%.1f", offset))
                }
                if let origin = structuralChromeTableOrigin(forTableAt: first),
                   abs(chrome.currentTableOrigin.x - origin.x) >= 0.5 {
                    findings.append("structural chrome \(table.id.rawValue) draws its table at "
                                    + String(format: "%.1f", chrome.currentTableOrigin.x)
                                    + " with the clip putting it at " + String(format: "%.1f", origin.x))
                }
            }
        }

        for occurrence in inlineButtonOccurrences() {
            guard let view = inlineButtonPillViews[occurrence.offset],
                  let expected = attachmentOverlayPlacement(canonicalOffset: occurrence.offset,
                                                            roleIndex: occurrence.roleIndex) else { continue }
            check("inline pill at \(occurrence.offset)", view, expected)
        }
        for occurrence in formulaOccurrences() {
            guard let view = formulaTapTargets[occurrence.offset],
                  let expected = attachmentOverlayPlacement(canonicalOffset: occurrence.offset,
                                                            roleIndex: occurrence.roleIndex) else { continue }
            check("formula target at \(occurrence.offset)", view, expected)
        }
        for occurrence in emojiOccurrences() {
            guard let view = customEmojiViews[occurrence.ref.instanceID], !view.isHidden,
                  let expected = attachmentOverlayPlacement(canonicalOffset: occurrence.range.location,
                                                            roleIndex: roleIndex(atFlatOffset: occurrence.range.location))
            else { continue }
            check("custom emoji at \(occurrence.range.location)", view, expected)
        }
        return findings
    }

    /// Half a point: the placements are float arithmetic on the same inputs, so equality is the
    /// intent and the tolerance is for the arithmetic, not for drift.
    private func frame(_ lhs: CGRect, matches rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) < 0.5 && abs(lhs.minY - rhs.minY) < 0.5
            && abs(lhs.width - rhs.width) < 0.5 && abs(lhs.height - rhs.height) < 0.5
    }

    private func compact(_ rect: CGRect) -> String {
        String(format: "(%.1f %.1f %.1fx%.1f)", rect.minX, rect.minY, rect.width, rect.height)
    }
}
#endif
