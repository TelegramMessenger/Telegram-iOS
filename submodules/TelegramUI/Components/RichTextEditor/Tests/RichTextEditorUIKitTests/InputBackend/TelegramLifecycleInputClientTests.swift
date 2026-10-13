#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

@available(iOS 13.0, *)
@MainActor
final class TelegramLifecycleInputClientTests: XCTestCase {
    /// Mirrors the Task-12 fixture pattern (`TelegramDocumentInputClientReadTests.makeClient`). No
    /// paragraphs/frame are needed here — every test below exercises lifecycle plumbing (policy reads,
    /// hook forwarding, publication routing), never layout/geometry.
    private func makeClient() -> (DocumentCanvasView, TelegramLifecycleInputClient) {
        let v = DocumentCanvasView()
        return (v, TelegramLifecycleInputClient(canvas: v))
    }

    private func snapshot(revision: UInt64 = 0) -> RichTextInputStateSnapshot {
        RichTextInputStateSnapshot(
            documentRevision: revision,
            selection: .caret(at: .downstream(0)),
            markedRange: nil,
            isComposing: false)
    }

    // MARK: - editPolicy

    /// Pins the central risk of this task: no edit policy exists today, so the seam's default MUST be
    /// the all-permissive value. (This sentence used to locate the two unconditional `true` literals at
    /// `+UITextInput.swift:215` and `DCV:665`. TASK 31 ROUTED BOTH witnesses: `isEditable` and
    /// `canBecomeFirstResponder` are now one-line `inputBackend.…` routers on the canvas, and the
    /// literals live on `LegacyRichTextInputBackend+Responder.swift` as `isEditableForWritingTools`
    /// and `canBecomeFirstResponder`, still unconditional and still un-gated on any policy field.
    /// Cited by name rather than by line, on the register item that line citations here rot silently.) Red if `.legacyUnrestricted` were ever narrowed, or if
    /// the client's default read fell back to something else.
    func test_defaultEditPolicyIsLegacyUnrestricted() {
        // NOTE: `c` holds the canvas `unowned` (by design), so the canvas must be bound to a name
        // (`v`), not `_` — a discard pattern releases it immediately, deallocating the canvas out
        // from under `c` before the assertion runs (proven sharp in Task 12 review).
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            XCTAssertEqual(c.editPolicy, .legacyUnrestricted)
        }
    }

    /// The spec requires the policy be read AT OPERATION TIME, never cached at init. Red if `init`
    /// captured `canvas.editPolicy` into a stored property instead of forwarding through a computed one.
    func test_editPolicyIsReadThroughOnEveryAccess_notCachedAtInit() {
        let (v, c) = makeClient()
        XCTAssertEqual(c.editPolicy, .legacyUnrestricted)
        let restrictive = RichTextInputEditPolicy(
            isEditable: false, isSelectable: false, allowsRichText: false,
            allowsPaste: false, allowsDictation: false, allowsWritingTools: false)
        v.editPolicy = restrictive
        XCTAssertEqual(c.editPolicy, restrictive, "the client must re-read canvas.editPolicy, not a cached copy")
    }

    // MARK: - Responder lifecycle hooks

    func test_backendDidBeginEditing_firesTheCanvasBecameFirstResponderHook() {
        let (v, c) = makeClient()
        var became = 0
        v.onBecameFirstResponder = { became += 1 }
        c.backendDidBeginEditing()
        XCTAssertEqual(became, 1)
    }

    func test_backendDidEndEditing_firesTheCanvasResignedHook() {
        let (v, c) = makeClient()
        var resigned = 0
        v.onResignedFirstResponder = { resigned += 1 }
        c.backendDidEndEditing()
        XCTAssertEqual(resigned, 1)
    }

    /// No veto hook exists today — `canBecomeFirstResponder` is an unconditional `true` (since TASK 31
    /// on the BACKEND, `+Responder.swift`; the canvas override is a one-line router to it) and nothing
    /// gates entering edit mode. Under `.legacyUnrestricted` this must stay unconditionally
    /// `true`; red if a future edit ever threaded `editPolicy.isEditable` in here without updating this
    /// pin (which would still pass under `.legacyUnrestricted` alone). Task 14 is what first wires
    /// `editPolicy` into a live decision, but it does so in `TelegramDocumentInputClient.prepareMutation`
    /// (mutation preparation), not here — this lifecycle hook stays an unconditional stub. The case that
    /// actually catches a wiring regression is
    /// `TelegramDocumentInputClientMutationTests.test_prepareUnderANonEditablePolicyIsTerminalNotEditable`.
    func test_backendWillBeginEditingIsAlwaysTrueUnderLegacy() {
        // NOTE: `c` holds the canvas `unowned` — bind it (`v`), don't discard it, and extend its
        // lifetime across the assertion (see the footgun note on `test_defaultEditPolicyIsLegacyUnrestricted`).
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            XCTAssertTrue(c.backendWillBeginEditing())
        }
    }

    func test_backendShouldEndEditingIsAlwaysTrueUnderLegacy() {
        let (v, c) = makeClient()
        withExtendedLifetime(v) {
            XCTAssertTrue(c.backendShouldEndEditing())
        }
    }

    // MARK: - State publication routing

    /// `.content` must route through `notifyContentSizeChanged()` (the synchronous content channel),
    /// not `onSelectionChange`. Red if the switch's content arm were dropped or mis-mapped to selection.
    func test_publishContentReasonFiresNotifyContentSizeChanged() {
        let (v, c) = makeClient()
        var contentFired = 0
        var selectionFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        c.backendDidPublishState(snapshot(), reason: .content)
        XCTAssertEqual(contentFired, 1)
        XCTAssertEqual(selectionFired, 0)
    }

    /// `.selection` must route through `onSelectionChange` (the async-coalesced channel) and must NOT
    /// also fire the content channel. Red if both channels fired, or if the reason were mapped backwards.
    func test_publishSelectionReasonFiresOnSelectionChange() {
        let (v, c) = makeClient()
        var contentFired = 0
        var selectionFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        c.backendDidPublishState(snapshot(), reason: .selection)
        XCTAssertEqual(selectionFired, 1)
        XCTAssertEqual(contentFired, 0, "selection publication must not also touch the content channel")
    }

    /// `.markedText` shares the content channel with `.content` (both relay synchronously to the
    /// facade's `onChange`, RichTextEditorView.swift:258). Red if marked-text publication were ever
    /// pointed at the selection channel instead.
    func test_publishMarkedTextReasonUsesTheContentChannel() {
        let (v, c) = makeClient()
        var contentFired = 0
        var selectionFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        c.backendDidPublishState(snapshot(), reason: .markedText)
        XCTAssertEqual(contentFired, 1)
        XCTAssertEqual(selectionFired, 0)
    }

    /// `.interaction` shares the selection channel with `.selection` (both relay async-coalesced,
    /// RichTextEditorView.swift:725-733). Red if interaction publication were ever pointed at the
    /// content channel instead.
    func test_publishInteractionReasonUsesTheSelectionChannel() {
        let (v, c) = makeClient()
        var contentFired = 0
        var selectionFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        c.backendDidPublishState(snapshot(), reason: .interaction)
        XCTAssertEqual(selectionFired, 1)
        XCTAssertEqual(contentFired, 0)
    }

    /// The two-step-paste behavior at +Clipboard.swift:169: while `suppressHostChangeNotification` is
    /// set, NEITHER channel should reach the host for a publication that would otherwise fire it. The
    /// content arm inherits this for free (`notifyContentSizeChanged()` already gates on the flag at its
    /// definition); the selection arm needs its own explicit guard in the client, which this test also
    /// covers via the `.selection` reason. Red if either channel fired while suppressed.
    func test_publicationRespectsSuppressHostChangeNotification() {
        let (v, c) = makeClient()
        var contentFired = 0
        var selectionFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        v.suppressHostChangeNotification = true
        c.backendDidPublishState(snapshot(), reason: .content)
        c.backendDidPublishState(snapshot(), reason: .selection)
        XCTAssertEqual(contentFired, 0, "content channel must stay silent while suppressed")
        XCTAssertEqual(selectionFired, 0, "selection channel must stay silent while suppressed")
    }

    // MARK: - Layout requests

    /// `backendRequiresLayout` always routes to the content-size channel, regardless of `reason` — there
    /// is no finer-grained layout-request channel on the canvas today. Red if it were routed to
    /// `onSelectionChange` instead, or dropped.
    func test_backendRequiresLayoutFiresTheContentSizeChannel() {
        let (v, c) = makeClient()
        var contentFired = 0
        v.onContentSizeChange = { contentFired += 1 }
        c.backendRequiresLayout(for: nil, reason: .textMutation)
        XCTAssertEqual(contentFired, 1)
        c.backendRequiresLayout(for: NSRange(location: 0, length: 3), reason: .viewport)
        XCTAssertEqual(contentFired, 2)
    }

    // MARK: - Rejection and attach/detach are silent under the legacy policy

    /// No rejection concept exists today, so a legacy rejection must be a pure no-op: none of the four
    /// canvas hooks may fire. Red if any hook fired, which would mean the stub grew a side effect.
    func test_backendDidRejectMutationIsSilentUnderLegacy() {
        let (v, c) = makeClient()
        var became = 0, resigned = 0, contentFired = 0, selectionFired = 0
        v.onBecameFirstResponder = { became += 1 }
        v.onResignedFirstResponder = { resigned += 1 }
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        let mutation = RichTextInputMutation.insertText(
            text: NSAttributedString(string: "x"),
            replacing: .caret(at: .downstream(0)),
            origin: .softwareKeyboard)
        c.backendDidRejectMutation(mutation, reason: .notEditable)
        XCTAssertEqual(became, 0)
        XCTAssertEqual(resigned, 0)
        XCTAssertEqual(contentFired, 0)
        XCTAssertEqual(selectionFired, 0)
    }

    /// `backendDidAttach`/`backendWillDetach` have no legacy analogue at all (attachment is new seam
    /// machinery Task 20 wires up) — both must be pure no-ops today. Red if either grew a side effect
    /// that touched any of the four canvas hooks.
    func test_attachAndDetachAreSilentUnderLegacy() {
        let (v, c) = makeClient()
        var became = 0, resigned = 0, contentFired = 0, selectionFired = 0
        v.onBecameFirstResponder = { became += 1 }
        v.onResignedFirstResponder = { resigned += 1 }
        v.onContentSizeChange = { contentFired += 1 }
        v.onSelectionChange = { selectionFired += 1 }
        c.backendDidAttach()
        c.backendWillDetach()
        XCTAssertEqual(became, 0)
        XCTAssertEqual(resigned, 0)
        XCTAssertEqual(contentFired, 0)
        XCTAssertEqual(selectionFired, 0)
    }

    // MARK: - Client retains the canvas unowned (Task-12 precedent: proven sharp in review)

    func test_clientHoldsTheCanvasWithoutRetainingIt() {
        weak var probe: DocumentCanvasView?
        autoreleasepool {
            let (v, c) = makeClient()
            probe = v
            _ = c.editPolicy
        }
        XCTAssertNil(probe, "the client must hold the canvas unowned")
    }
}
#endif
