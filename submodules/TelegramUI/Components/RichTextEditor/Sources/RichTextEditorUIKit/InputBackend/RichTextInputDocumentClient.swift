#if canImport(UIKit)
import UIKit

/// The document client exposes one linear UTF-16 projection over Telegram's structured document. It
/// does not expose blocks, tables, model nodes, leaf regions, `BlockLayoutEngine`, TextKit objects, or
/// views.
///
/// Authority: Telegram document structure/content, structural edit semantics, document revision, and
/// undo registration/coalescing policy are ALL sole authority of this client (or the Telegram mutation
/// engine behind it). The active backend never mutates the document directly.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputDocumentClient: AnyObject {
    var revision: UInt64 { get }
    var utf16Length: Int { get }

    /// Owns Telegram's projection rules: inserts contextual paragraph separators and maps inline atoms
    /// to their textual representation. The backend must not walk blocks to reconstruct keyboard
    /// context.
    ///
    /// TASK 24 FIX ROUND 1 (reviewer Major 3 / D27 follow-on note) — this member's bounds semantics
    /// are DELIBERATELY a REJECTING guard (`location >= 0, length >= 0, location + length <=
    /// utf16Length`, else `nil`), not a clamp: `TelegramDocumentInputClient`'s own implementation
    /// rejects an out-of-bounds `NSRange` outright. That is NOT what the legacy `UITextInput` witness's
    /// pre-seam behavior did (it CLAMPED via `clampGlobal`), which is why `LegacyRichTextInputBackend`'s
    /// `text(in:)` (`+TextReads.swift`) currently calls the canvas's `legacyPlainText(globalFrom:
    /// globalTo:)` directly instead of this method — going through this method with an unclamped range
    /// would be a real, if rare, behavior change relative to the original witness. A caller that wants
    /// to route through this client instead of bypassing it MUST clamp both endpoints to
    /// `[0, utf16Length]` itself before calling — do not "fix" this method to clamp instead of reject;
    /// that would just move the incompatibility rather than resolve it, and other callers may
    /// legitimately want the strict/rejecting form. Recorded so Task 25 (geometry — `firstRect(for:)`/
    /// `selectionRects(for:)` face the identical clamp-vs-reject question against their own clients)
    /// does not have to rediscover this from scratch.
    func plainText(in range: NSRange) -> String?

    /// Returns a snapshot. A backend cannot retain and mutate the returned attributed string as
    /// document storage.
    func attributedText(in range: NSRange) -> NSAttributedString?

    func typingAttributes(
        at position: RichTextInputPosition
    ) -> [NSAttributedString.Key: Any]

    func clamp(
        _ position: RichTextInputPosition
    ) -> RichTextInputPosition

    func isValidInsertionPosition(
        _ position: RichTextInputPosition
    ) -> Bool

    /// A stale object is explicitly rebased or rejected; its integer offset is not silently
    /// reinterpreted against a new document.
    func rebase(
        _ position: RichTextInputPosition,
        fromRevision: UInt64
    ) -> RichTextInputPosition?

    /// Preparation validates revision, edit policy, ranges, and structural feasibility WITHOUT changing
    /// document, selection, annotations, or undo. Synchronous on the main actor. A ready preparation is
    /// consumed exactly once by the same document client before returning to the run loop; the client
    /// may retain only one outstanding preparation.
    func prepareMutation(
        _ mutation: RichTextInputMutation,
        expectedRevision: UInt64
    ) -> RichTextInputMutationPreparation

    /// Performs the complete mutation atomically; must agree with the preparation's
    /// `contentWillChange`/`selectionWillChange` flags. Rejection cannot partially mutate content,
    /// selection, or undo state. The document client never calls `UITextInputDelegate` — the backend
    /// owns delegate ordering around this call.
    func commitPreparedMutation(
        _ prepared: RichTextInputPreparedMutation
    ) -> RichTextInputMutationResult
}
#endif
