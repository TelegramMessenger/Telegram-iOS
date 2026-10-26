#if canImport(UIKit)
import XCTest
import RichTextInputDecObjC
@testable import RichTextEditorUIKit

/// Decision 10 (2026-08-17). Stage 1 ships the eight contract suites parameterised over
/// `BackendContractCases`, so `.inputDec` inherits all interleaving and token-discipline tests
/// instead of getting semantic assertions only. Nothing in stage 1 is edited.
///
/// If any subclass below needs more than a `makeBackend()` override to compile or pass, that
/// is a finding about the CONTRACT, not about this file: it means the ID backend cannot meet a
/// requirement the legacy backend meets. Record it in DIVERGENCES.md and fix the backend --
/// do NOT relax the inherited assertion, and do NOT override a `test_` method here.
///
/// FIX ROUND 1 (2026-08-25, controller review): `makeHost(log:)` is a SECOND legitimate hook
/// alongside `makeBackend()`, not a contract-relaxation. `BackendContractCases`'s own default
/// `makeHost(log:)` vends a `FakeInputHost` whose `hostInputView` is a plain legacy
/// `DocumentCanvasView` — correct for the eight stage-1 legacy suites, but `IDTextEditorBackend`
/// narrows its host's `hostInputView` to `IDDocumentCanvasView` (deviation D23,
/// `IDTextEditorBackend.swift`'s `attach(to:)`, first guard). Without an override every one of
/// these eight suites' `setUpWithError()` threw `.incompatibleHost` before reaching the
/// manifest/kernel gate that Tasks C4-C14 actually fix — a red state Task C4 onward could never
/// turn green. Requiring an ID canvas is a DOCUMENTED design fact (D23), not something this file
/// invented, and Task C2 built the exact fixture this needs
/// (`FakeInputHost.init(hostInputView:log:text:)`, `IDFakeClientHarness.swift`'s
/// `makeIDFakeClientHarness`) — `makeIDContractHost(backend:log:)` below is the same
/// construct-canvas-with-this-backend / detach-the-self-attach / re-wrap-in-a-`FakeInputHost`
/// sequence, shared by all eight `makeHost` overrides so the per-suite code stays a one-liner.
/// `nextHostIsIncompatible` (the flag `BackendAttachDetachTests`'s inherited incompatible-host
/// test flips) is preserved by delegating to `super.makeHost(log:)` on that branch, exactly as
/// the base class's own default implementation does.
///
/// NAMING NOTE: `IDBackendAttachDetachTests` below is the stage-1 subclass this task's own brief
/// specifies (`class IDBackendAttachDetachTests: BackendAttachDetachTests`). Task C0 had already
/// used that exact class name for an unrelated, ID-backend-specific white-box attach/detach
/// suite; that pre-existing suite was renamed to `IDBackendAttachAtomicityTests`
/// (`IDBackendAttachAtomicityTests.swift`) to free this name up — see that file's own doc
/// comment and `task-C3-report.md` for the full reasoning. Both suites still exist; only the
/// older one's name changed.
///
/// `Scripts/matrix.sh` discovery note: each of these eight subclasses extends a STAGE-1
/// CONCRETE class (`Backend{Mutation,Revision,…}ContractTests`), not `BackendContractCases`
/// directly — so `matrix.sh`'s discovery regex needed each of those eight concrete names added
/// to its alternation, not just `BackendContractCases`. See the comment in `Scripts/matrix.sh`
/// and `task-C3-report.md` for why the brief's own Step 6 text (and the supplement's minimal
/// fix) would have left these eight silently undiscovered.

/// Shared by every override below. Mirrors `IDFakeClientHarness.swift`'s `makeIDFakeClientHarness`
/// construction order exactly, and for the same reason its doc comment gives: constructing a
/// SECOND `IDTextEditorBackend` would leave two backends contending for one canvas's associated
/// bridge, so the canvas is built AROUND the suite's own already-constructed `backend` (from
/// `makeBackend()`, called before `makeHost(log:)` by `BackendContractCases.setUpWithError()`),
/// that construction's own self-attach is detached, and the SAME backend instance is left ready
/// for `setUpWithError()`'s subsequent `try backend.attach(to: freshHost)` call. The seeded
/// `utf16Length` is set to 100 to match `FakeInputDocumentClient`'s own stored default (the base
/// `makeHost(log:)`'s plain `FakeInputHost(log:)` path) — `FakeInputHost`'s
/// `init(hostInputView:log:text:)` overload derives `utf16Length` from `text.utf16.count`
/// instead, so an empty `text` would otherwise silently shrink every contract suite's document
/// bound from 100 to 0.
///
/// Task R3 ADDITION: `plainTextToReturn` is ALSO reset here, to a 100-character placeholder
/// matching the `utf16Length` override on the same line — without this it was left at `""` by
/// `FakeInputHost.init(hostInputView:log:text:)` (which sets `plainTextToReturn = text`, i.e. the
/// empty string passed above), a length-0/length-100 mismatch inside one fixture. Harmless before
/// this task (nothing in this package ever reached `-documentPlainTextInRange:` at runtime — see
/// `IDTextEditorBackendClientBridge.documentPlainText(inRange:)`'s own doc comment for the
/// pre-existing selector-exposure bug this task found and fixed), but load-bearing now:
/// `TGRichTextInputDecTextStorageFacade.synchronizeMirrorWithDocumentIfNeeded` calls exactly that
/// selector to seed/resync its mirror, and a client that advertises `documentUTF16Length() == 100`
/// while `documentPlainTextInRange:(0,100)` answers `""` leaves the mirror permanently stuck at
/// length 0 — genuinely reintroducing the `NSMutableRLEArray … Out of bounds` exception this task's
/// facade fix is supposed to eliminate, for any offset a test rebases to beyond 0. The placeholder's
/// exact characters are unread by every test in this cluster (they assert counts/revisions/offsets,
/// never document content), so any 100-length string is correct.
@MainActor
@available(iOS 17.0, *)
private func makeIDContractHost(backend: any RichTextInputBackend,
                                 log: RichTextInputEventLog) -> any RichTextInputHost {
    // `DocumentCanvasView.init` self-attaches `backend` to the new canvas and, on failure, calls
    // `RichTextInputContractViolation.report(...)`. `BackendContractCases.setUpWithError()` does
    // not install ITS OWN reporter until AFTER `makeHost(log:)` returns (it is installed
    // immediately before the REAL `backend.attach(to: freshHost)` call this method's caller sets
    // up for), so with no reporter installed yet, a rejection here would `assertionFailure` --
    // a hard process trap in DEBUG, not a plain observable test failure -- exactly the crash this
    // task's fix-round-1 hit before this guard was added. The self-attach failing at this stage
    // is EXPECTED (nothing routes until C4-C14: the mandatory `incomingCallbacks` capability is
    // still rejected), so it is swallowed here and left for the real, reporter-guarded
    // `attach(to:)` call to surface as a genuine, observable test failure instead.
    // Task R12 (cluster 18) — `backend` is not always fresh here. `BackendAttachDetachTests
    // .test_attachTwice_throwsAlreadyAttached_andPreservesTheFirstAttachment` calls `makeHost(log:)`
    // a SECOND time, mid-test, on the SAME already-attached `backend` (from `setUp`'s first
    // `makeHost(log:)` + the base class's own `attach(to: freshHost)`), purely to obtain a second
    // host object to hand to a REJECTED re-attach attempt. `IDDocumentCanvasView(inputBackend:)`'s
    // self-attach below is UNCONDITIONAL and, when `backend.isAttached` is already true, correctly
    // fails at `attach(to:)`'s own top-line `!isAttached` guard (swallowed by the temporary
    // reporter above) — but the OLD unconditional `backend.detach()` that followed did not
    // distinguish that from the ordinary case, so it silently tore down the backend's FIRST, live
    // attachment as a side effect of merely constructing a second, throwaway host — exactly what
    // R1's clustering flagged as "a self-attach detached before the 'real' attach" and left
    // unresolved. `wasAlreadyAttached` makes the guard `backend.detach()` only when the self-attach
    // just above could plausibly have SUCCEEDED (backend was unattached going in) — the ordinary
    // "fresh backend, first `makeHost(log:)` call" case, unchanged. Confirmed by reading
    // `IDTextEditorBackend.attach(to:)`'s own top guard: a rejected attach never mutates
    // `isAttached`/`host`/`state`, so `wasAlreadyAttached` is exactly the SAME truth after
    // construction as before it -- no race, nothing to re-read post-construction.
    let wasAlreadyAttached = backend.isAttached
    let previousReporter = RichTextInputContractViolation.reporter
    RichTextInputContractViolation.reporter = { _ in }
    let canvas = IDDocumentCanvasView(inputBackend: backend)
    RichTextInputContractViolation.reporter = previousReporter
    canvas.frame = CGRect(x: 0, y: 0, width: 300, height: 600)
    if !wasAlreadyAttached {
        backend.detach()
    }
    let host = FakeInputHost(hostInputView: canvas, log: log, text: "")
    host.fakeDocumentClient.utf16Length = 100
    host.fakeDocumentClient.plainTextToReturn = String(repeating: "x", count: 100)
    return host
}

@available(iOS 17.0, *)
final class IDBackendMutationContractTests: BackendMutationContractTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendRevisionContractTests: BackendRevisionContractTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendPublicationContractTests: BackendPublicationContractTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendSelectionContractTests: BackendSelectionContractTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }

    // Task R11 (cluster 19/15) — the ID backend's own opaque UIKit identity type
    // (`TGRichTextInputDecPosition`/`TGRichTextInputDecRange`), overriding the base class's
    // Legacy-typed default. See `BackendContractCases.makeSelectedTextRange(from:to:)`'s own doc
    // comment for why this hook exists.
    @MainActor override func makeSelectedTextRange(from: Int, to: Int) -> UITextRange {
        TGRichTextInputDecRange(
            from: TGRichTextInputDecPosition(offset: from, affinity: .forward, revision: 0),
            to: TGRichTextInputDecPosition(offset: to, affinity: .forward, revision: 0))
    }
    @MainActor override func readSelectedTextRange(_ range: UITextRange?) -> (from: Int, to: Int)? {
        guard let r = range as? TGRichTextInputDecRange,
              let from = r.start as? TGRichTextInputDecPosition,
              let to = r.end as? TGRichTextInputDecPosition else { return nil }
        return (from.utf16Offset, to.utf16Offset)
    }
}

@available(iOS 17.0, *)
final class IDBackendMarkedTextPolicyTests: BackendMarkedTextPolicyTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendReentrancyTests: BackendReentrancyTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendAttachDetachTests: BackendAttachDetachTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}

@available(iOS 17.0, *)
final class IDBackendEditPolicyTests: BackendEditPolicyTests {
    @MainActor override func makeBackend() -> (any RichTextInputBackend)? {
        IDTextEditorBackend()
    }
    @MainActor override func makeHost(log: RichTextInputEventLog) -> any RichTextInputHost {
        if nextHostIsIncompatible { return super.makeHost(log: log) }
        return makeIDContractHost(backend: self.backend, log: log)
    }
}
#endif
