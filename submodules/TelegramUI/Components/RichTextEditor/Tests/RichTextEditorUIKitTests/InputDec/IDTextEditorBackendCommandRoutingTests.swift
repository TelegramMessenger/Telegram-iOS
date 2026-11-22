#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// Task C10 — the NON-skip-gated coverage for Family 7 (responder commands and clipboard).
///
/// Both members `IDTextEditorBackend+Responder.swift` adds — `canPerformCommand(_:sender:)` and
/// `performCommand(_:sender:)` — are thin, attach-requiring dispatchers around two PURE, static
/// decision functions (`canPerformCommandDecision(...)`/`performCommandViaClient(...)`), extracted
/// exactly the way `reconciledMarkedRange(currentMarkedRange:change:rebase:)` was extracted at Task
/// C9 for the identical reason: this is the strongest non-skip-gated coverage this task can give the
/// substance of the family, per the task-C10-C11 supplement §3 ("C10's command routing ... [is] pure
/// Swift decision logic needing no live kernel"). Neither test class below constructs an
/// `IDDocumentCanvasView`/attaches a real kernel, so nothing here is skip-gated by `isSupported()` —
/// every test in this file genuinely EXECUTES on this runtime, unlike every `IDBackendFamily7Tests`
/// assertion, which stays skip-gated until Task C14 (see that file's own header).
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendCommandRoutingTests: XCTestCase {

    // MARK: - `canPerformCommandDecision`

    /// The load-bearing ordering guarantee: the kernel closure is NEVER invoked once the command
    /// client has already declined — mirrors `IDBackendFamily7Tests
    /// .test_canPerformPaste_consultsTheCommandClient_notThePrivateController`'s own assertion, but
    /// observable here with no kernel, no host, no attach at all.
    func test_paste_whenCommandClientDeclines_neverConsultsTheKernelClosure() {
        var kernelClosureCalled = false
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .paste, editPolicyAllowsPaste: true, commandClientAllows: false,
            kernelPasteAvailability: { kernelClosureCalled = true; return true })
        XCTAssertFalse(answer)
        XCTAssertFalse(kernelClosureCalled,
                       "the private controller must never be asked once the command client already said no")
    }

    /// The COMPLEMENT of the test above: once the edit policy AND the command client both say yes,
    /// the kernel closure IS consulted, and its answer is the final word.
    func test_paste_whenBothGatesAllow_consultsTheKernelClosureAndHonoursItsAnswer() {
        var kernelClosureCalled = false
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .paste, editPolicyAllowsPaste: true, commandClientAllows: true,
            kernelPasteAvailability: { kernelClosureCalled = true; return false })
        XCTAssertFalse(answer, "the kernel's own negative answer must be honoured")
        XCTAssertTrue(kernelClosureCalled)
    }

    /// A `nil` kernel answer (detached / no `kernelInput` / a caught kernel failure) falls back to
    /// the higher-level policy that already said yes — never treated as a rejection.
    func test_paste_whenKernelAnswerIsNil_fallsBackToTrue() {
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .paste, editPolicyAllowsPaste: true, commandClientAllows: true,
            kernelPasteAvailability: { nil })
        XCTAssertTrue(answer)
    }

    /// The `allowsPaste` edit-policy gate, in isolation from the command client — mirrors
    /// `IDBackendFamily7Tests.test_allowsPasteFalse_makesCanPerformPasteFalse`'s own assertion,
    /// observable here with plain booleans.
    func test_paste_whenEditPolicyDisallows_isFalseRegardlessOfTheOtherTwoGates() {
        var kernelClosureCalled = false
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .paste, editPolicyAllowsPaste: false, commandClientAllows: true,
            kernelPasteAvailability: { kernelClosureCalled = true; return true })
        XCTAssertFalse(answer)
        XCTAssertFalse(kernelClosureCalled,
                       "a policy that already says no must short-circuit before the kernel is asked")
    }

    /// A non-`.paste` command never consults the kernel closure at all — the kernel only has an
    /// opinion about paste availability.
    func test_nonPasteCommand_neverConsultsTheKernelClosure() {
        var kernelClosureCalled = false
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .copy, editPolicyAllowsPaste: false, commandClientAllows: true,
            kernelPasteAvailability: { kernelClosureCalled = true; return false })
        XCTAssertTrue(answer, "a non-paste command is decided by the command client alone")
        XCTAssertFalse(kernelClosureCalled)
    }

    /// A non-`.paste` command declined by the command client is simply `false` — the
    /// `editPolicyAllowsPaste` gate never applies to it.
    func test_nonPasteCommand_whenCommandClientDeclines_isFalse() {
        let answer = IDTextEditorBackend.canPerformCommandDecision(
            .selectAll, editPolicyAllowsPaste: true, commandClientAllows: false,
            kernelPasteAvailability: { XCTFail("must not be called for a declined non-paste command"); return nil })
        XCTAssertFalse(answer)
    }

    // MARK: - `performCommandViaClient`

    /// `test_pasteGoesThroughPrepareThenCommit`'s own logic, over a bare `FakeInputCommandClient` —
    /// no canvas, no host, no attach.
    func test_performCommandViaClient_pasteGoesThroughPrepareThenCommit() {
        let client = FakeInputCommandClient(log: RichTextInputEventLog())
        IDTextEditorBackend.performCommandViaClient(.paste, sender: nil, client: client)
        XCTAssertEqual(client.prepared, [.paste])
        XCTAssertEqual(client.committed, [.paste])
        XCTAssertFalse(client.sawDoubleCommit)
    }

    /// A `.terminal` preparation (mirrors the real `TelegramCommandInputClient`'s own `.copy` shape —
    /// see `+Responder.swift`'s header) must never reach `commit(_:)` at all.
    func test_performCommandViaClient_terminalPreparationNeverCommits() {
        let client = FakeInputCommandClient(log: RichTextInputEventLog())
        client.nextPreparationTerminalResult = RichTextInputCommandResult(
            performed: true, revision: 1, selection: .caret(at: .downstream(0)),
            contentChanged: false, selectionChanged: false)
        IDTextEditorBackend.performCommandViaClient(.copy, sender: nil, client: client)
        XCTAssertEqual(client.prepared, [.copy])
        XCTAssertTrue(client.committed.isEmpty, "a terminal preparation must never be committed")
    }

    /// Every `RichTextInputCommand` case reaches `prepare` then `commit` exactly once when the fake
    /// stays in its default (always-`.ready`) mode — proving `performCommandViaClient` does not
    /// special-case any one command.
    func test_performCommandViaClient_everyCommandCommitsExactlyOnce() {
        let client = FakeInputCommandClient(log: RichTextInputEventLog())
        let commands: [RichTextInputCommand] = [.cut, .copy, .paste, .selectWord, .selectAll, .delete, .undo, .redo]
        for command in commands {
            IDTextEditorBackend.performCommandViaClient(command, sender: nil, client: client)
        }
        XCTAssertEqual(client.prepared, commands)
        XCTAssertEqual(client.committed, commands)
        XCTAssertFalse(client.sawDoubleCommit)
    }
}
#endif
