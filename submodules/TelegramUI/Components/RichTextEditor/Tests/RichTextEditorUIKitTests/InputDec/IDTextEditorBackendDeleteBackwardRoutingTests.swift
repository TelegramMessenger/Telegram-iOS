#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `IDTextEditorBackend.deleteBackward()` (Family 5, Task C8, `+KeyInput.swift`) is a plain
/// two-call forward onto `kernelInput` — see that file's doc comment. Every OTHER Family-5
/// assertion in this package (`IDBackendFamily5Tests`) needs a LIVE kernel attach and SKIPS on
/// this runtime (`incomingCallbacks` stays mandatory-rejected until Task C14 — see
/// DIVERGENCES.md). Following the precedent Task C7 set with `IDTextEditorBackendIntentTests` /
/// `IDTextStorageFacadeTests` (both zero-skip-gate, both genuinely RUN), this file gives the
/// routing itself at least one path that genuinely runs on this runtime too.
///
/// **Deliberately constructs NO `IDDocumentCanvasView` and attempts NO `attach(to:)`.**
/// `IDDocumentCanvasView(inputBackend:)`'s own init self-attaches and can hit
/// `RichTextInputContractViolation.report(...)` → `assertionFailure()` → a process trap (the
/// latent hard crash `task-C8-supplement.md` §6 names, confirmed by a real crash-and-restart run
/// in Task C3) — `makeIDFakeClientHarness()`/`makeBackendHarness(backend: .inputDec)` are both
/// safe against it only because their construction sequences detach-then-reattach or install a
/// temporary no-op reporter FIRST, and neither is usable un-gated (`makeIDFakeClientHarness`
/// force-`try!`s a real `attach(to:)`, which currently always throws — see below — so calling it
/// from a NON-skip-gated test would crash the process, not merely fail an assertion). A bare
/// `IDTextEditorBackend()` with NO canvas has `kernelInput == nil` by construction and touches
/// none of that machinery, which is what makes it safe to exercise unconditionally here.
///
/// What this proves: `deleteBackward()`'s two guarded kernel-witness calls
/// (`kernelInput?.preflightBackwardDeleteRanges()` / `kernelInput?.deleteBackward()`) really do
/// take the nil-optional-chain branch cleanly — no force-unwrap, no unguarded message send that
/// would crash on an unattached backend — a REAL execution of the new code's exact shape, not a
/// hypothetical. What it does NOT prove: anything about behavior once a live `kernelInput` exists
/// (routing the controller's own resolved range, grapheme-cluster width, …) — that is
/// `IDBackendFamily5Tests`'s job, and it stays skip-gated until C14 clears the remaining 8
/// `incomingCallbacks` mismatches.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendDeleteBackwardRoutingTests: XCTestCase {

    /// Would trap the process (a force-unwrap or unguarded message send on a nil `kernelInput`)
    /// if `deleteBackward()` reached into `kernelInput` other than through the optional chain both
    /// of its calls use.
    func test_deleteBackwardOnAnUnattachedBackend_isASafeNoOp() {
        let backend = IDTextEditorBackend()
        XCTAssertFalse(backend.isAttached)
        backend.deleteBackward()
        XCTAssertTrue(backend.witnessFailures.isEmpty,
                      "an unattached backend's kernelInput is nil, so both guarded calls must " +
                      "short-circuit cleanly — never record a witness failure")
    }

    /// Same shape, called twice in a row — proves the routing carries no hidden one-shot state
    /// (e.g. a stale `NSError` local that would leak into, or be mistaken for, a second call).
    func test_deleteBackwardOnAnUnattachedBackend_isRepeatablySafe() {
        let backend = IDTextEditorBackend()
        backend.deleteBackward()
        backend.deleteBackward()
        XCTAssertTrue(backend.witnessFailures.isEmpty)
    }
}
#endif
