#if canImport(UIKit)
import UIKit
import RichTextEditorCore

/// The document side of the seam. Exposes ONE linear UTF-16 projection over Telegram's structured
/// document and never hands out blocks, leaf regions, layout engines, TextKit objects or views.
///
/// `utf16Length` returns `documentSizeValue` verbatim. NOTE that axis is STRUCTURAL: it counts the
/// non-renderable token slots between blocks, so it is not a plain character count. Renaming the
/// axis is out of scope for the seam; every position the backend holds lives on this same axis.
@MainActor
@available(iOS 13.0, *)
final class TelegramDocumentInputClient: RichTextInputDocumentClient {
    /// `unowned`, deliberately, not `weak`: the canvas is meant to strictly OUTLIVE its client (the
    /// backend that owns this client is itself owned by the canvas's host), so every read member here can
    /// stay a plain, non-optional forward — no unwrap-or-sentinel on a reference that should never dangle.
    /// If the canvas IS deallocated first, the correct behavior is a loud crash, not a silently-stale
    /// reference: `weak` would force every member below to invent a fallback value for "the document is
    /// gone," which is worse than a trap for a read-only surface with exactly one intended lifetime order.
    /// Proven sharp in review: `let (_, c) = makeClient()` in a test — discarding the canvas via `_` —
    /// released it immediately (nothing else held it), leaving `c`'s reference already dangling before the
    /// first assertion ran. See `TelegramDocumentInputClientReadTests` for the fix (bind `v`, don't `_` it).
    private unowned let canvas: DocumentCanvasView

    /// The single outstanding preparation, if any. A `.ready` preparation is consumed exactly once,
    /// by the same client, before returning to the run loop; `prepareMutation` refuses to retain a
    /// second one (Task 14's transaction discipline — see `commitPreparedMutation`).
    private var outstanding: RichTextInputPreparedMutation?
    /// The mutation intent that `outstanding` was prepared from. Always non-nil exactly when
    /// `outstanding` is non-nil; consumed together in `commitPreparedMutation`.
    private var pending: RichTextInputMutation?

    init(canvas: DocumentCanvasView) { self.canvas = canvas }

    var revision: UInt64 { canvas.documentRevision }
    var utf16Length: Int { canvas.documentSizeValue }

    func plainText(in range: NSRange) -> String? {
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return nil }
        return canvas.legacyPlainText(globalFrom: range.location,
                                      globalTo: range.location + range.length)
    }

    func attributedText(in range: NSRange) -> NSAttributedString? {
        guard range.location >= 0, range.length >= 0,
              range.location + range.length <= canvas.documentSizeValue else { return nil }
        return canvas.legacyAttributedText(globalFrom: range.location,
                                           globalTo: range.location + range.length)
    }

    func typingAttributes(at position: RichTextInputPosition) -> [NSAttributedString.Key: Any] {
        canvas.typingAttributesAtGlobal(canvas.clampGlobal(position.utf16Offset))
    }

    func clamp(_ position: RichTextInputPosition) -> RichTextInputPosition {
        RichTextInputPosition(utf16Offset: canvas.clampGlobal(position.utf16Offset),
                              affinity: position.affinity)
    }

    func isValidInsertionPosition(_ position: RichTextInputPosition) -> Bool {
        canvas.isRenderablePosition(position.utf16Offset)
    }

    /// Legacy rebase is identity-or-nil: the canvas keeps no edit history, so a position from an
    /// older revision cannot be mapped. Anything richer would be new behavior.
    func rebase(_ position: RichTextInputPosition, fromRevision: UInt64) -> RichTextInputPosition? {
        fromRevision == revision ? position : nil
    }

    /// The current selection, in the seam's canonical shape. Read-through — never cached — exactly
    /// like every other member on this client.
    private func currentSelection() -> RichTextCanonicalSelection {
        RichTextCanonicalSelection(anchor: .downstream(canvas.anchor), head: .downstream(canvas.head))
    }

    /// The current marked (IME composition) range, translated from the canvas's `(from, to)` tuple
    /// shape to `NSRange`. `nil` when nothing is composing.
    private func currentMarkedRange() -> NSRange? {
        canvas.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) }
    }

    /// The mutation's own declared range, used by `prepareMutation` to bounds-check before touching
    /// the document. `.unmarkText` carries no range of its own (it acts on whatever `markedRange`
    /// already is) so it returns `nil` — nothing to validate up front.
    private func affectedRange(of mutation: RichTextInputMutation) -> NSRange? {
        switch mutation {
        case .insertText(_, let replacing, _), .insertParagraphBreak(let replacing, _):
            return replacing.normalizedRange
        case .replaceText(let range, _, _):
            return range
        case .deleteBackward(let selection, _), .deleteForward(let selection, _):
            return selection.normalizedRange
        case .setBaseWritingDirection(_, let range, _):
            return range
        case .setMarkedText(_, let replacing, _):
            return replacing
        case .unmarkText:
            return nil
        }
    }
}

@available(iOS 13.0, *)
extension TelegramDocumentInputClient {
    /// Deviation D10: preparation is deliberately CONSERVATIVE. `editing(coalescing:_:)` fires all
    /// four delegate notifications unconditionally before its body runs (+Editing.swift:27-31) and
    /// every refusal is an early `return` INSIDE the body, so a true preflight would both rewrite
    /// ~25 primitives and change observable keyboard behavior. The result carries
    /// `legacyConservativePreparation: true` so contract tests can see the difference.
    func prepareMutation(_ mutation: RichTextInputMutation,
                         expectedRevision: UInt64) -> RichTextInputMutationPreparation {
        func terminal(_ rejection: RichTextInputMutationRejection) -> RichTextInputMutationPreparation {
            .terminal(RichTextInputMutationResult(
                disposition: .rejected(rejection), revision: revision,
                selection: currentSelection(), markedRange: currentMarkedRange(),
                affectedRange: nil, contentChanged: false, selectionChanged: false,
                legacyConservativePreparation: true))
        }
        guard expectedRevision == revision else { return terminal(.revisionMismatch) }
        guard canvas.editPolicy.isEditable else { return terminal(.notEditable) }
        if let range = affectedRange(of: mutation) {
            guard range.location >= 0, range.length >= 0,
                  range.location + range.length <= utf16Length else { return terminal(.invalidRange) }
        }
        if outstanding != nil {
            RichTextInputContractViolation.report(
                "a second preparation was requested while one was outstanding")
            outstanding = nil
        }
        let prepared = RichTextInputPreparedMutation(token: UUID(), expectedRevision: revision,
                                                     contentWillChange: true, selectionWillChange: true)
        outstanding = prepared
        pending = mutation
        return .ready(prepared)
    }

    func commitPreparedMutation(_ prepared: RichTextInputPreparedMutation) -> RichTextInputMutationResult {
        guard let outstanding, outstanding == prepared, let mutation = pending else {
            RichTextInputContractViolation.report(
                "commit of a foreign or already-consumed preparation token")
            return RichTextInputMutationResult(
                disposition: .rejected(.unsupportedOperation), revision: revision,
                selection: currentSelection(), markedRange: currentMarkedRange(),
                affectedRange: nil, contentChanged: false, selectionChanged: false,
                legacyConservativePreparation: true)
        }
        self.outstanding = nil
        self.pending = nil
        let selectionBefore = currentSelection()
        // The whole legacy mutation (`editing { }` and everything it registers with the undo manager)
        // runs as ONE undo group. `editing`'s `registerUndo` requires an open group whenever the host's
        // UndoManager has `groupsByEvent == false` (production's own manager defaults `groupsByEvent`
        // true, where a group is opened for free — see `UndoManager.registerUndo` — so this bracket is a
        // no-op there); bracketing the whole commit here, rather than inside `legacyApplyMutation`, keeps
        // the atomicity guarantee ("commit performs the mutation atomically") in the ONE place that owns
        // the transaction boundary, and tolerates D31's double-`editing{}`-nested-inside-`editing{}` paths
        // for free (nested groups collapse into this one outer group; only the outermost open/close pair
        // matters to the undo stack).
        canvas.effectiveUndoManager?.beginUndoGrouping()
        let applied = canvas.legacyApplyMutation(mutation)
        canvas.effectiveUndoManager?.endUndoGrouping()
        let selection = RichTextCanonicalSelection(anchor: .downstream(applied.anchor),
                                                   head: .downstream(applied.head))
        return RichTextInputMutationResult(
            disposition: applied.contentChanged ? .applied : .noChange,
            revision: applied.revision, selection: selection, markedRange: applied.markedRange,
            affectedRange: applied.affectedRange, contentChanged: applied.contentChanged,
            selectionChanged: selection != selectionBefore,
            legacyConservativePreparation: true)
    }
}
#endif
