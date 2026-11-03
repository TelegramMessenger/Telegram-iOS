#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `IDTextEditorBackend.setMarkedText(_:selectedRange:)`/`unmarkText()`/`markedTextRange`
/// (Family 6, Task C9, `+TextBackend.swift`) route through `kernelInput` guarded, exactly like
/// `deleteBackward()` (Family 5, Task C8, `+KeyInput.swift`). Every OTHER Family-6 assertion in this
/// package (`IDBackendFamily6Tests`) needs a LIVE kernel attach and SKIPS on this runtime
/// (`incomingCallbacks` stays mandatory-rejected until Task C14 — see DIVERGENCES.md). Following the
/// precedent `IDTextEditorBackendDeleteBackwardRoutingTests` set for the identical situation one
/// family over, this file gives the routing itself at least one path that genuinely RUNS on this
/// runtime too.
///
/// **Deliberately constructs NO `IDDocumentCanvasView` and attempts NO `attach(to:)`** — same reason
/// `IDTextEditorBackendDeleteBackwardRoutingTests`' own header gives in full: `IDDocumentCanvasView
/// (inputBackend:)`'s self-attach can hit `RichTextInputContractViolation.report(...)` →
/// `assertionFailure()` → a process trap, and `makeIDFakeClientHarness()` force-`try!`s a real
/// `attach(to:)` that currently always throws. A bare `IDTextEditorBackend()` has `kernelInput == nil`
/// by construction and touches none of that machinery.
///
/// What this proves: all three witnesses' guarded kernel-witness calls really do take the
/// nil-optional-chain branch cleanly on an unattached backend — no force-unwrap, no unguarded message
/// send. `unmarkText()`'s ADDITIONAL `commitMarkedTextStateIfComposing()` call is likewise proven safe
/// when there is nothing composing to commit (the guard's `guard state.markedRange != nil else {
/// return }` early-out). What it does NOT prove: anything about behavior once a live `kernelInput`
/// exists (the private controller genuinely composing/committing text) — that is
/// `IDBackendFamily6Tests`'s job, and it stays skip-gated until C14 clears the remaining 8
/// `incomingCallbacks` mismatches.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendMarkedTextRoutingTests: XCTestCase {

    /// Would trap the process (a force-unwrap or unguarded message send on a nil `kernelInput`) if
    /// `setMarkedText`/`unmarkText`/`markedTextRange` reached into `kernelInput` any other way than
    /// through the optional chain each uses.
    func test_markedTextWitnessesOnAnUnattachedBackend_areSafeNoOps() {
        let backend = IDTextEditorBackend()
        XCTAssertFalse(backend.isAttached)
        backend.setMarkedText("hi", selectedRange: NSRange(location: 2, length: 0))
        XCTAssertNil(backend.markedTextRange)
        backend.unmarkText()
        XCTAssertTrue(backend.witnessFailures.isEmpty,
                      "an unattached backend's kernelInput is nil, so every guarded call must " +
                      "short-circuit cleanly — never record a witness failure")
        XCTAssertNil(backend.markedRange, "no adoption path exists without a live kernel, so state " +
                     "must stay exactly what it started as")
        XCTAssertFalse(backend.isComposing)
    }

    /// Same shape, called twice in a row — proves the routing carries no hidden one-shot state.
    func test_markedTextWitnessesOnAnUnattachedBackend_areRepeatablySafe() {
        let backend = IDTextEditorBackend()
        backend.setMarkedText("a", selectedRange: NSRange(location: 1, length: 0))
        backend.unmarkText()
        backend.setMarkedText("b", selectedRange: NSRange(location: 1, length: 0))
        backend.unmarkText()
        XCTAssertTrue(backend.witnessFailures.isEmpty)
    }

    /// `markedTextStyle` needs no attach at all — neither the getter nor the setter reads `state`/
    /// `kernelInput`/`host` (see `+TextBackend.swift`'s own doc comment on why this member is a
    /// deliberate exception to `kernelInput` routing). Duplicates
    /// `IDBackendFamily6Tests.test_markedTextStyleGetterReturnsNil_andTheSetterIsANoOp` under a
    /// distinct name so the claim has a genuinely-running proof alongside the skip-gated one.
    func test_markedTextStyle_getterReturnsNil_andTheSetterIsANoOp_withNoAttachAtAll() {
        let backend = IDTextEditorBackend()
        XCTAssertNil(backend.markedTextStyle)
        backend.markedTextStyle = [.underlineStyle: NSUnderlineStyle.single.rawValue]
        XCTAssertNil(backend.markedTextStyle)
    }
}
#endif
