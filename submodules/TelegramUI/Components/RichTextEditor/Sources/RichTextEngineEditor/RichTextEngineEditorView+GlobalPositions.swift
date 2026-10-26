#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// **The global position axis is `RichTextEditorCore`'s, and the engine can answer it.**
///
/// `selectedGlobalRange()` / `replaceRange(from:to:with:)` used to trap here at rung `R7-paste`, on
/// the stated premise that they speak "offsets into legacy's global position model, which the engine
/// does not have". Both halves of that were wrong, and the crash it produced was real: tapping the
/// AI button in the article editor killed the app (`EXC_BREAKPOINT`, K3 2026-09-17), because
/// `RichTextAttachmentScreen` opens that flow with `if let sel = self.editor.selectedGlobalRange()`
/// and so trapped on the CALL — whether anything was selected never got a chance to matter.
///
/// 1. The axis is **Core's**: `DocumentTree.documentSize`, `Document.globalTextStart(ofBlockAt:)`,
///    `PositionResolver`. It is a pure function of a `Document`, and it is the axis
///    `Document.extractFragment` and `Document.replacingRange` already speak. Legacy merely stores
///    its caret on it.
/// 2. The engine owns a `Document`, and every role carries the key a `TextNodeRef` is keyed on — a
///    `BlockID` plus which region of that block it is. So a role maps onto a text node one-to-one and
///    `PositionResolver` walks the rest of the tree, at any depth, through cells and containers
///    alike. No arithmetic over containers is re-derived here.
///
/// **The one genuine asymmetry is inside a run**, and it is why this cannot be `offset - roleStart`:
/// a formula's `TextRun.text` is its LaTeX source while the engine renders it as a single `U+FFFC`
/// (`EngineDocumentBridge.modelRuns(readingBack:)`). Custom emoji and inline buttons are one `U+FFFC`
/// on BOTH sides and need no conversion. The conversion also has to read the ENGINE rather than
/// assume the substitution happened: with no formula renderer registered the engine holds the LaTeX
/// verbatim, which is `attributedFormulaString`'s documented degradation.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: - A role is a text node

    /// The `TextNodeRef` naming the text this role holds, or `nil` for a role that holds no text at
    /// all — a media atom, a button row, a collapsed quote. Exhaustive over `Position`, so a seventh
    /// shape or a sixth secondary kind fails to build here rather than resolving to a wrong region.
    internal func textNodeRef(of role: EngineBlockRole) -> TextNodeRef? {
        switch role.position {
        case let .standalone(shape):
            switch shape {
            case let .paragraph(paragraph): return .paragraph(paragraph.id)
            case let .code(id, _): return .code(id)
            case let .pullQuote(id): return .pullQuote(id)
            case .media, .buttonRow, .collapsedQuote: return nil
            }
        case let .secondary(owner, _, kind):
            switch kind {
            case .codeLanguage: return .codeLanguage(owner.id)
            case .pullQuoteAuthor, .blockQuoteAuthor: return .quoteAuthor(owner.id)
            case .mediaCaption: return .caption(owner.id)
            case .detailsTitle: return .detailsTitle(owner.id)
            }
        case let .tableCell(_, _, _, cell):
            return .paragraph(cell)
        }
    }

    internal func textNodeRef(ofRoleAt index: Int) -> TextNodeRef? {
        guard index >= 0, index < currentRoles.count else { return nil }
        return textNodeRef(of: currentRoles[index])
    }

    // MARK: - Engine extent vs model extent, within one role

    /// How many UTF-16 units `run` occupies in the ENGINE. Equal to its model length except for a
    /// formula the engine actually rendered, which is one attachment character — established by
    /// reading the engine's own string rather than by assuming a renderer is registered.
    private func engineLength(of run: TextRun, atEngineOffset offset: Int,
                              in attributed: NSAttributedString) -> Int {
        guard let formula = run.attributes.formula, !formula.isEmpty else { return run.utf16Count }
        guard offset >= 0, offset < attributed.length,
              attributed.attribute(.attachment, at: offset, effectiveRange: nil) != nil else {
            return run.utf16Count
        }
        return 1
    }

    /// Walks a role's runs on both axes at once, handing each to `step` until it claims the walk.
    private func walkRuns<T>(ofRoleAt index: Int,
                             _ step: (_ run: TextRun, _ engineStart: Int, _ modelStart: Int,
                                      _ engineLength: Int) -> T?) -> (result: T?, engineEnd: Int, modelEnd: Int)? {
        guard let ref = textNodeRef(ofRoleAt: index), let runs = document.runs(for: ref) else { return nil }
        let blocks = engine.attributedBlocks
        guard index < blocks.count else { return nil }
        let attributed = blocks[index]
        var engineCursor = 0, modelCursor = 0
        for run in runs {
            let length = engineLength(of: run, atEngineOffset: engineCursor, in: attributed)
            if let claimed = step(run, engineCursor, modelCursor, length) {
                return (claimed, engineCursor, modelCursor)
            }
            engineCursor += length
            modelCursor += run.utf16Count
        }
        return (nil, engineCursor, modelCursor)
    }

    /// An engine offset within the role at `index`, as a MODEL offset within the same text node.
    /// An offset landing on a rendered formula's atom resolves to the run's start — the atom stands
    /// for the whole source and has no interior position.
    internal func modelOffset(fromEngineOffset offset: Int, inRoleAt index: Int) -> Int? {
        guard let walk = walkRuns(ofRoleAt: index, { run, engineStart, modelStart, engineLength -> Int? in
            guard offset < engineStart + engineLength else { return nil }
            guard engineLength == run.utf16Count else { return modelStart }
            return modelStart + (offset - engineStart)
        }) else { return nil }
        return walk.result ?? walk.modelEnd
    }

    /// The inverse. A model offset inside a formula's source resolves to the atom standing for it.
    internal func engineOffset(fromModelOffset offset: Int, inRoleAt index: Int) -> Int? {
        guard let walk = walkRuns(ofRoleAt: index, { run, engineStart, modelStart, engineLength -> Int? in
            guard offset < modelStart + run.utf16Count else { return nil }
            guard engineLength == run.utf16Count else { return engineStart }
            return engineStart + (offset - modelStart)
        }) else { return nil }
        return walk.result ?? walk.engineEnd
    }

    // MARK: - The two axes

    /// An offset on the engine's flat axis, as a position on Core's global axis.
    ///
    /// A role holding no text (a media atom, a button row, a collapsed quote) has no text node to
    /// measure into, so it answers its whole BLOCK's span instead and `side` picks which end. That
    /// keeps a selection endpoint that landed on an atom expressible — and for media and tables it
    /// is the same snap `Document.expandingRangeOverNonTextBlocks` performs a moment later anyway.
    internal func globalPosition(atFlatOffset offset: Int, preferring side: BlockSpanSide) -> Int? {
        guard let index = roleIndex(atFlatOffset: offset) else { return nil }
        let tree = DocumentTree.build(from: document)
        guard let ref = textNodeRef(ofRoleAt: index) else {
            guard let span = PositionResolver.blockSpan(ofBlockWithID: currentRoles[index].containerID,
                                                        in: tree) else { return nil }
            return side == .start ? span.start : span.end
        }
        guard let local = modelOffset(fromEngineOffset: offset - flatOffset(ofRoleAt: index), inRoleAt: index)
        else { return nil }
        return PositionResolver.globalPosition(of: ref, offset: local, in: tree)
    }

    internal enum BlockSpanSide { case start, end }

    /// A position on Core's global axis, as an offset on the engine's flat axis.
    ///
    /// **A position inside no text node resolves to the NEAREST one that is**, searching forward
    /// first. That is not a convenience: `Document.replacingRange` parks its caret in the gap
    /// BETWEEN two blocks whenever neither boundary was mid-paragraph — the ordinary shape of a
    /// whole-block delete, which is what the AI flow's empty result performs — and a gap has no text
    /// position at all. Forward first because such a caret means "after what I removed".
    ///
    /// The scan is outward rather than `±1` because one token is not always enough: a media block's
    /// atom sits two tokens from its caption's first offset, so a caret parked on it would find
    /// nothing on either side. `nil` means the document has no text region anywhere.
    internal func flatOffset(atGlobalPosition position: Int) -> Int? {
        let tree = DocumentTree.build(from: document)
        let size = tree.nodeSize
        let origin = Swift.max(0, Swift.min(position, size))
        for distance in 0...Swift.max(size, 0) {
            let candidates = distance == 0 ? [origin] : [origin + distance, origin - distance]
            for candidate in candidates where candidate >= 0 && candidate <= size {
                guard let textPosition = PositionResolver.textPosition(at: candidate, in: tree),
                      let index = currentRoles.firstIndex(where: { textNodeRef(of: $0) == textPosition.ref }),
                      let local = engineOffset(fromModelOffset: textPosition.offset, inRoleAt: index)
                else { continue }
                return flatOffset(ofRoleAt: index) + local
            }
        }
        return nil
    }
}
#endif
