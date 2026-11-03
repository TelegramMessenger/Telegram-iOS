#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `IDTextEditorBackend.reconciledMarkedRange(currentMarkedRange:change:rebase:)` (Family 6, Task C9)
/// is the `static`, self-contained decision logic behind `synchronizeAfterExternalChange(_:)`'s three
/// `RichTextMarkedTextPolicy` branches — deliberately extracted to take the CURRENT marked range and
/// a `rebase` callback as plain values, so it needs NO attached kernel, NO host, and NO canvas at
/// all. Per the task-C9 supplement §3 ("do not ship untested code behind the skip gate... the
/// strong candidates are Swift-side... testable against fakes with no kernel at all"), this is the
/// most intricate logic in this task and the strongest non-skip-gated coverage it can get — every
/// test below genuinely EXECUTES on this runtime (no `XCTSkipUnless`), unlike every `IDBackendFamily6Tests`
/// assertion, which needs `IDTextEditorBackend.isSupported()` and stays skip-gated until Task C14.
///
/// **Proven capable of failing, not merely capable of passing** (per the supplement's "match C7/C8's
/// standard" instruction): `test_preserveIfRebasable_rebasesBothEndpoints_whenTheReasonMovesText`
/// and `test_discard_neverCallsRebase` were run against a deliberately reverted body — swapping
/// `.discard`'s case to `return range` (keep-instead-of-drop) and swapping the rebase-arithmetic
/// `min`/`max` pair — and both went genuinely red before being reverted; see this task's report for
/// the exact failure text quoted from that run.
@available(iOS 17.0, *)
@MainActor
final class IDTextEditorBackendMarkedTextPolicyTests: XCTestCase {

    /// A helper `RichTextInputExternalChange` — every field but `reason`/`markedTextPolicy` is inert
    /// to `reconciledMarkedRange`, which reads only those two plus `oldRevision` (passed to `rebase`).
    private func change(reason: RichTextInputExternalChangeReason,
                        policy: RichTextMarkedTextPolicy,
                        oldRevision: UInt64 = 5) -> RichTextInputExternalChange {
        RichTextInputExternalChange(
            oldRevision: oldRevision, newRevision: oldRevision + 1, reason: reason,
            changedRangeBefore: nil, changedRangeAfter: nil,
            selection: .caret(at: .downstream(0)), markedTextPolicy: policy)
    }

    // MARK: - No composition open: every policy answers nil, and NEVER calls rebase

    func test_nilCurrentMarkedRange_returnsNilForEveryPolicy_withNoRebaseCall() {
        var rebaseCallCount = 0
        let policies: [RichTextMarkedTextPolicy] = [.discard, .commitBeforeChange, .preserveIfRebasable]
        for policy in policies {
            let result = IDTextEditorBackend.reconciledMarkedRange(
                currentMarkedRange: nil,
                change: change(reason: .remoteUpdate, policy: policy),
                rebase: { _, _ in rebaseCallCount += 1; return nil })
            XCTAssertNil(result, "policy \(policy) must answer nil when nothing is composing")
        }
        XCTAssertEqual(rebaseCallCount, 0, "there is nothing to rebase when no composition is open")
    }

    // MARK: - `.discard` always drops the range without ever consulting rebase

    /// RED IF: `.discard`'s case were changed to `return range` (keep instead of drop) — confirmed by
    /// a real mutation-and-revert run; see this task's report for the quoted failure.
    func test_discard_dropsTheMarkedRange_withoutEverCallingRebase() {
        var rebaseCallCount = 0
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: NSRange(location: 3, length: 4),
            change: change(reason: .remoteUpdate, policy: .discard),
            rebase: { _, _ in rebaseCallCount += 1; return nil })
        XCTAssertNil(result)
        XCTAssertEqual(rebaseCallCount, 0,
                       "`.discard` drops the composition WITHOUT asking the document client to " +
                       "change anything — the host already applied the change")
    }

    // MARK: - `.commitBeforeChange` is observably identical to `.discard` here (disclosed, not a gap)

    /// `.commitBeforeChange` has never had a production call site in this package (mirrors
    /// `LegacyRichTextInputBackend`'s own identical finding for its matching branches) — this pins
    /// the disclosed, deliberate equivalence rather than leaving it unasserted.
    func test_commitBeforeChange_dropsTheMarkedRangeIdenticallyToDiscard() {
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: NSRange(location: 3, length: 4),
            change: change(reason: .undo, policy: .commitBeforeChange),
            rebase: { _, _ in nil })
        XCTAssertNil(result)
    }

    // MARK: - `.preserveIfRebasable`'s fast path: an offset-preserving reason skips rebase entirely

    /// `.layoutOnly` and `.formatting` both answer `true` from `RichTextInputExternalChangeReason
    /// .preservesTextOffsets` — the range must survive VERBATIM with zero rebase callouts.
    func test_preserveIfRebasable_skipsRebase_forAnOffsetPreservingReason() {
        for reason: RichTextInputExternalChangeReason in [.layoutOnly, .formatting] {
            var rebaseCallCount = 0
            let range = NSRange(location: 3, length: 4)
            let result = IDTextEditorBackend.reconciledMarkedRange(
                currentMarkedRange: range,
                change: change(reason: reason, policy: .preserveIfRebasable),
                rebase: { _, _ in rebaseCallCount += 1; return nil })
            XCTAssertEqual(result, range, "reason \(reason) preserves offsets — nothing moved")
            XCTAssertEqual(rebaseCallCount, 0)
        }
    }

    // MARK: - `.preserveIfRebasable`'s real path: a text-moving reason rebases both endpoints

    /// RED IF: the rebased `lo`/`hi` computation used `max`/`min` swapped (or dropped the `min`/`max`
    /// normalization entirely) — confirmed by a real mutation-and-revert run; see this task's report.
    func test_preserveIfRebasable_rebasesBothEndpoints_whenTheReasonMovesText() {
        var rebasedOffsets: [Int] = []
        let range = NSRange(location: 10, length: 5)   // [10, 15)
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: range,
            change: change(reason: .remoteUpdate, policy: .preserveIfRebasable, oldRevision: 7),
            rebase: { position, revision in
                rebasedOffsets.append(position.utf16Offset)
                XCTAssertEqual(revision, 7, "rebase must be called against the change's oldRevision")
                return RichTextInputPosition(utf16Offset: position.utf16Offset + 20)
            })
        XCTAssertEqual(rebasedOffsets, [10, 15], "both endpoints rebase, start before end")
        XCTAssertEqual(result, NSRange(location: 30, length: 5),
                       "the rebased range keeps the same length and moves by +20")
    }

    /// A rebase that returns endpoints out of ORDER must still produce a normalized (min, max) range —
    /// `reconciledMarkedRange` does not trust the callback to preserve start < end.
    func test_preserveIfRebasable_normalizesAnOutOfOrderRebaseResult() {
        let range = NSRange(location: 10, length: 5)
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: range,
            change: change(reason: .remoteUpdate, policy: .preserveIfRebasable),
            // First call (the START endpoint, offset 10) rebases PAST the end endpoint's own result.
            rebase: { position, _ in
                position.utf16Offset == 10
                    ? RichTextInputPosition(utf16Offset: 50)
                    : RichTextInputPosition(utf16Offset: 40)
            })
        XCTAssertEqual(result, NSRange(location: 40, length: 10))
    }

    // MARK: - `.preserveIfRebasable` discards on a failed rebase, short-circuiting the second endpoint

    /// D32 (the real `TelegramDocumentInputClient`'s documented contract): AT MOST ONE rebase attempt
    /// per endpoint — the first (failing) endpoint's rebase must short-circuit the second.
    func test_preserveIfRebasable_discardsWhenTheFirstEndpointFailsToRebase_andNeverAttemptsTheSecond() {
        var rebaseCallCount = 0
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: NSRange(location: 10, length: 5),
            change: change(reason: .remoteUpdate, policy: .preserveIfRebasable),
            rebase: { _, _ in rebaseCallCount += 1; return nil })
        XCTAssertNil(result)
        XCTAssertEqual(rebaseCallCount, 1,
                       "the first (failing) endpoint rebase must short-circuit the second endpoint's " +
                       "call, per D32's at-most-one-attempt-per-offset rule")
    }

    /// The contrasting failure point: the FIRST endpoint succeeds but the SECOND fails.
    func test_preserveIfRebasable_discardsWhenTheSecondEndpointFailsToRebase() {
        var rebaseCallCount = 0
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: NSRange(location: 10, length: 5),
            change: change(reason: .remoteUpdate, policy: .preserveIfRebasable),
            rebase: { position, _ in
                rebaseCallCount += 1
                return position.utf16Offset == 10 ? RichTextInputPosition(utf16Offset: 30) : nil
            })
        XCTAssertNil(result)
        XCTAssertEqual(rebaseCallCount, 2)
    }

    // MARK: - `.preserveIfRebasable` collapses a zero-length rebased range to nil

    /// Mirrors `LegacyRichTextInputBackend`'s own convention: `isComposing` must never read `true`
    /// while composing nothing, so both endpoints rebasing to the SAME offset must answer nil, not a
    /// zero-length `NSRange`.
    func test_preserveIfRebasable_collapsesAZeroLengthRebasedRangeToNil() {
        let result = IDTextEditorBackend.reconciledMarkedRange(
            currentMarkedRange: NSRange(location: 10, length: 5),
            change: change(reason: .remoteUpdate, policy: .preserveIfRebasable),
            rebase: { _, _ in RichTextInputPosition(utf16Offset: 0) })
        XCTAssertNil(result)
    }
}
#endif
