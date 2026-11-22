#if canImport(UIKit)
import UIKit

/// Clipboard and structural actions remain Telegram-owned.
///
/// The backend decides WHEN UIKit requests an action; this client decides WHAT the action means for
/// document fragments, tables, media, structural selections, and Telegram paste hooks. Results are
/// adopted and published using the same prepare/notify/commit/publish ordering as mutations. A ready
/// command is single-use, belongs to its creating client, and must be committed before returning to
/// the run loop. Copy or an unavailable action normally returns a terminal no-change result. Undo/redo
/// initiated through the responder chain is a command; undo/redo initiated directly by a Telegram host
/// is an external change synchronized afterward.
@MainActor
@available(iOS 13.0, *)
protocol RichTextInputCommandClient: AnyObject {
    func canPerform(
        _ command: RichTextInputCommand,
        sender: Any?
    ) -> Bool

    func prepare(
        _ command: RichTextInputCommand,
        sender: Any?
    ) -> RichTextInputCommandPreparation

    func commit(
        _ prepared: RichTextInputPreparedCommand
    ) -> RichTextInputCommandResult

    /// TASK 30 — the manager the responder chain's undo affordances act through, vended so the routed
    /// `DocumentCanvasView.undoManager` override (`UIResponder`) can answer from the seam rather than
    /// from canvas state directly.
    ///
    /// **Read-only, and deliberately so: this does NOT move undo OWNERSHIP here.** Deviation D14 keeps
    /// ownership with the document client / the canvas — `openUndoRun`, `undoRegistrationCount`,
    /// `undoManagerOverride` and `breakUndoCoalescing()` are not this client's, and nothing about this
    /// property changes that. It is the same category as this client's existing `canPerform(.undo)` /
    /// `performUndo()`: reading and invoking a manager somebody else owns. It lives on the COMMAND
    /// client rather than the document one because every other consumer of that manager in this seam
    /// (`canPerform(.undo)`/`.redo`, `performUndo()`/`performRedo()`) is already here, and undo/redo
    /// reached through the responder chain is, by this protocol's own doc comment, a COMMAND.
    ///
    /// **THE INVARIANT A CONFORMER MUST SATISFY, stated because it is load-bearing and NOT implied by
    /// the type (FIX ROUND 1, Min-9).** The manager returned here MUST BE THE SAME INSTANCE this
    /// editor's own undo runs register into — the one the document-mutation path's `registerUndo`
    /// drives, and the one `canPerform(.undo)` and `performUndo()` above act on. It is a read-only VIEW
    /// of that manager, never one this client owns or constructs.
    ///
    /// This is exactly the shape of defect this seam keeps producing, so it is spelled out rather than
    /// implied: **a conformer that returns a freshly-constructed `UndoManager()` compiles, satisfies
    /// every test in the package, and is silently broken in production.** The responder chain's undo
    /// affordances (hardware Cmd-Z / Cmd-Shift-Z, shake-to-undo, the system Edit menu's Undo/Redo) would
    /// act on an empty buffer, while the host's own undo control — which goes through the facade, not
    /// the responder chain — kept working. Two buffers, one of them invisible, and nothing red.
    /// **D14 is what makes it possible to get wrong**: undo OWNERSHIP is deliberately elsewhere, so
    /// this member is a read ACROSS an ownership boundary and a conformer has to go and find the right
    /// instance rather than being handed it. `TelegramCommandInputClient` satisfies it by returning
    /// `canvas.effectiveUndoManager`, which is literally the store every `registerUndo` uses; stage 2's
    /// conformer must make the equivalent identification against ITS editor's manager, not mint one.
    var undoManager: UndoManager? { get }
}
#endif
