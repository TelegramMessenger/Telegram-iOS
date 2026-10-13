#if canImport(UIKit)
import UIKit
@testable import RichTextEditorUIKit

/// TASK 43 — **a permanent TEST-FACING accessor, for exactly the reason D22 keeps permanent
/// test-facing typealiases.**
///
/// `DocumentCanvasView.coalescingSelectionNotifications` was deleted from `Sources/` (it had been a
/// Task-26 computed forwarder onto `inputBackend.suppressesSelectionNotifications`, never storage).
/// One reader of it lives in `Tests/RichTextEditorUIKitTests/Characterization/`
/// (`ResponderLifecycleCharacterizationTests.test_resignFirstResponder_leavesTheCoalescingFlagSet`,
/// the deviation-D18 pin), and **Phase 6 gate item 3 requires the diff over `Characterization/` to be
/// EMPTY** — a characterization suite records what was observed when it was written, so editing one to
/// accommodate a later refactor is exactly the move that gate exists to prevent.
///
/// So the spelling is re-vended here instead. This is a shim, and it is deliberately NOT a second
/// authority:
///
///   * it is `get`-only, so no test can write the flag through it (the two writers a test needs are
///     `beginCoalescedSelectionDrag()` / `endCoalescedSelectionDrag()`, which is what the D18 test
///     already uses);
///   * it reads straight through to the backend, so it cannot shadow;
///   * it lives in the TEST target, so `InputBackendSourceBoundaryTests`' scans over
///     `Sources/RichTextEditorUIKit` never see it and its four-mention `suppressesSelectionNotifications`
///     allowance stays a statement about production code.
///
/// A read-write version would defeat all three, which is why the one write the old forwarder allowed
/// is not reproduced. `DelegateEmissionTests` — the only OTHER reader, and not a characterization
/// suite — was updated to name the backend directly rather than lean on this.
@available(iOS 13.0, *)
extension DocumentCanvasView {
    var coalescingSelectionNotifications: Bool { inputBackend.suppressesSelectionNotifications }
}
#endif
