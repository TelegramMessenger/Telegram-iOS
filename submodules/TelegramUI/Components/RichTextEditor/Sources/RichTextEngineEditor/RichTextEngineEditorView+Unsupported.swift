#if canImport(UIKit)
import UIKit
import RichTextEditorCore
import RichTextEditorUIKit

/// PERFORM-OR-TRAP: actions the engine path cannot do yet.
///
/// Every member here traps naming the rung that will implement it. None returns a plausible default,
/// and that is the whole point: the previous attempt at this project answered `hasText -> false` and
/// `isEditableForWritingTools -> false`, which were indistinguishable from correct answers at every
/// call site and cost five manual debugging sessions to find. A trap cannot be mistaken for a
/// correct answer.
///
/// The consequence is deliberate and accepted (spec §5.3): under the opt-in Debug Settings flag, a
/// user who taps "code block" crashes with the rung name in the message. That is the right behaviour
/// when the audience chose the flag — a silent no-op would leave them thinking the editor is broken
/// in some unnameable way, which is strictly worse to diagnose.
///
/// Contrast `+DeferredConfiguration.swift`: those members ACCEPT something the host pushes and store
/// it for a later rung. These members are asked to DO something, now, and cannot.
@available(iOS 18.4, *)
extension RichTextEngineEditorView {

    // MARK: Block structure — R7


    // Links CLIMBED at R9-inline — see `+Links.swift`. They are no longer here, and the members
    // they replaced are worth remembering: `currentLink()` used to trap rather than return nil,
    // because nil is a REAL answer ("the selection carries no link") and an unimplemented member
    // answering it would have been indistinguishable from a correct one.
}
#endif
