#if canImport(UIKit)
import UIKit

/// TASK 34 — Family 11 (spellchecking and annotations), the LAST Phase-4 family. **TWO routed backend
/// members**, each a plain forward onto an already-narrowly-named canvas method:
///
///   1. `installCheckingIfNeeded()` -> `legacyCanvas?.installNativeCheckingIfNeeded()`
///   2. `checkOnSelectionChange()`  -> `legacyCanvas?.nativeCheckOnSelectionChange()`
///
/// # This family has NO UIKit witness, and that is why it needed a contract change
///
/// Every earlier family routed a `UITextInput`/`UIResponder` witness: UIKit called the canvas, the
/// canvas called the backend, the backend called a `legacy…` hook. Family 11 has no such witness. Its
/// entry points are CANVAS-INTERNAL — the `isSpellCheckingEnabled` `didSet`,
/// `legacyFinishBecomingFirstResponder()`, `refreshSelectionUI()` and `endCoalescedSelectionDrag()` —
/// and `DocumentCanvasView.inputBackend` is typed `any RichTextInputBackend`, so a backend-internal
/// member is unreachable from all but one of them.
///
/// **The task brief asked for both halves of a contradiction** ("nothing is added to any protocol" AND
/// "the call sites now call the backend instead"), and the coordinator ruled on the measurement:
/// **DEVIATION D37** adds `RichTextInputCheckingBackend` with these two requirements, on D33's own
/// rationale — the one that already justified seven contract members, and `undoManager` an eighth.
/// `RichTextInputBackend.swift` carries the full reasoning, including why **D36 does not transfer**
/// (Task 32's four stayed off the contract because Global Constraint 12 forbids an `@available` gate
/// above iOS 13 on a requirement; these two take no parameters at all).
///
/// # No rename, no new hook — the Task-29 amendment applied for the third time
///
/// Both callees keep their names. `installNativeCheckingIfNeeded()` and `nativeCheckOnSelectionChange()`
/// are ALREADY narrowly named, and D24's clause (a) says the `legacy…` prefix is a **provenance marker
/// for a renamed witness body**, not a magic string — a canvas member that needs no rename gets none.
/// Same call Task 29 made for `commitMarkedText`/`dismissPrediction`/`finalizeMarkedText`, Task 30 for
/// its clipboard hooks, and Task 32 for `installSelectionInteractions()`/`stopDragAutoScroll()`/
/// `cancelFloatingCursor()`. The consequence for rule R17 is the same as Task 32's: `.canvasForward`
/// requires the literal `legacyCanvas?.legacy`, so both members are `.statements` with the WHOLE call
/// as the allowed text — a TIGHTER pin than `.canvasForward` would have been, since it names the exact
/// callee rather than only the prefix.
///
/// **TASK 34 ADDS NO D24 CLAUSE-(b) EXCEPTION.** Both members INVOKE a hook; neither reads canvas state.
///
/// # The forwards are BARE, and that is measured rather than assumed
///
/// Neither body opens a delegate bracket, a transaction or a publication. `installNativeCheckingIfNeeded()`
/// touches no document and no selection at all (it constructs the driver and preheats it), and
/// `nativeCheckOnSelectionChange()` is itself REACHED FROM inside the selection funnels — `refreshSelectionUI()`
/// runs as the tail of a bracket the backend has already emitted (`notifyingSelectionChange`), and
/// `endCoalescedSelectionDrag()` calls it immediately after `notifyCoalescedSelectionResync()`. A bracket
/// here would nest inside one already open. R17's `backendBracketTokens` half is what keeps that true.
///
/// # What did NOT move, and the line is D11's
///
/// **The `NativeTextChecker` handle stays canvas-owned** (`DocumentCanvasView.swift`), so `deinit` keeps
/// invalidating it. **The teardown stays canvas-side too**: the `isSpellCheckingEnabled` `didSet`'s
/// disable branch invalidates the driver, nils it and clears `spellResults`/`spellingAlternatives`
/// inline. Only the ENABLE branch routes. That asymmetry is deliberate and is the whole of D11's
/// boundary: the backend owns *when* checking is installed, preheated and driven — not the resource, not
/// the storage, not the annotations.
///
/// The task brief asked for a third member, `driveCheck(style:_:)`. It is not here; see
/// `RichTextInputBackend.swift`'s D37 note for why (a bracket over canvas-owned `inFlightCheckStyle`,
/// all three call sites inside canvas bodies, and it would put the canvas-nested
/// `DocumentCanvasView.SpellStyle` on a contract member's face).
///
/// # Detached behaviour, stated because it is the one thing that could differ
///
/// Both members carry the family-standard `guard isAttached else { return }`. It changes nothing
/// observable: `legacyCanvas` is `host?.legacyCanvas` and `performDetachSteps()` clears `host`, so a
/// detached forward is already a no-op with or without the guard. What DOES differ from the pre-seam
/// code is that a canvas whose backend is detached no longer runs these two methods on itself — and
/// that state exists only between `detach()` (first statement of `DocumentCanvasView.deinit`) and
/// deallocation, or in a test that detaches explicitly. No production path calls either member there.
@available(iOS 13.0, *)
extension LegacyRichTextInputBackend {

    /// Reached from `DocumentCanvasView.legacyFinishBecomingFirstResponder()` (Task 31's third
    /// become-first-responder hook — **not** `legacyDidBecomeFirstResponder()`, which the brief and the
    /// coordinator supplement both named; those are different hooks and the boundary between them is
    /// observable) and from the `isSpellCheckingEnabled` `didSet`'s ENABLE branch.
    ///
    /// Idempotence is the callee's, unchanged: `installNativeCheckingIfNeeded()` guards on
    /// `nativeChecker == nil`. This member adds no guard of its own, because adding one would put a
    /// second, independently-drifting copy of that condition on the other side of the seam.
    func installCheckingIfNeeded() {
        guard isAttached else { return }
        legacyCanvas?.installNativeCheckingIfNeeded()
    }

    /// Reached from `DocumentCanvasView.refreshSelectionUI()` and `endCoalescedSelectionDrag()` — the
    /// two selection funnels.
    ///
    /// The callee's own guards are load-bearing and stay exactly where they are: it returns early unless
    /// `isSpellCheckingEnabled`, unless a `nativeChecker` exists, and while
    /// a coalesced drag is in progress. **That third guard reads THIS backend's
    /// `suppressesSelectionNotifications` directly** — it was a canvas `coalescingSelectionNotifications`
    /// forwarder from Task 26 until TASK 43 deleted the forwarder, so the coalescing suppression this
    /// member's callee performs has always been the backend's own state, and is now spelled that way.
    /// Task 43 collapsed that forwarder rather than this member.
    func checkOnSelectionChange() {
        guard isAttached else { return }
        legacyCanvas?.nativeCheckOnSelectionChange()
    }
}
#endif
