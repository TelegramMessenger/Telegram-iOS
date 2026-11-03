#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

/// A before/after fingerprint of every piece of canvas-owned state a Phase-4 router must NOT touch on
/// its own — the negative half of "the witness is a one-line router": the router may read/write
/// whatever the ONE backend call it forwards to needs, but it must not independently advance the
/// document revision, the layout generation, the selection, the marked range, the undo log, or dismiss
/// the edit menu, since all of those are the BACKEND's job once Phase 4 lands, not the canvas router's.
///
/// `markedRange` is flattened from the canvas's own `(from: Int, to: Int)?` tuple to `NSRange?` —
/// mirrors `RichTextInputBackendHarness.markedRange`'s own flatten — because a bare Swift tuple does
/// not conform to `Equatable` (no protocol conformance exists for tuple types), so a struct storing one
/// directly could not synthesize `==` at all; storing the flattened `NSRange?` is both comparable and
/// consistent with the harness's established shape for the same field.
@MainActor
@available(iOS 16.0, *)
struct RouterStateSnapshot: Equatable {
    let revision: UInt64
    let layoutGeneration: UInt64
    let anchor: Int
    let head: Int
    let markedRange: NSRange?
    let undoRegistrationCount: Int
    let dismissEditMenuCountForTesting: Int

    init(_ canvas: DocumentCanvasView) {
        self.revision = canvas.documentRevision
        self.layoutGeneration = canvas.layoutGeneration
        self.anchor = canvas.anchor
        self.head = canvas.head
        self.markedRange = canvas.markedRange.map { NSRange(location: $0.from, length: $0.to - $0.from) }
        self.undoRegistrationCount = canvas.undoRegistrationCount
        self.dismissEditMenuCountForTesting = canvas.dismissEditMenuCountForTesting
    }

    /// TASK 27b (review m2) — the field-isolating init, for `RouterHarnessTests`' negative controls ONLY.
    ///
    /// Those controls exist to prove each of the seven watched fields is LIVE in the comparison, and for
    /// SOME fields a control driven by a real canvas operation cannot prove that: **no driver in this
    /// package moves `documentRevision` alone.** `bumpDocumentRevision()` is the canvas's only writer of
    /// it (`DocumentCanvasView.swift`) and bumps `layoutGeneration` in the same breath; the pre-27b
    /// driver, `canvas.insertText("x")`, moved five of the seven. So a revision control built that way
    /// fails for a reason it cannot attribute — it would stay green if `revision` were dropped from
    /// `==`, because a co-moving field would still carry the inequality.
    ///
    /// **This is per-field, not a blanket rule** (narrowed at Task 27b's second review round, which
    /// caught the over-generalisation): `bumpLayoutGeneration()` DOES move `layoutGeneration` alone, and
    /// is the driver to reach for when building that field's control. Reach for a real driver first and
    /// use this init only for the fields where none isolates — today, `revision` and
    /// `undoRegistrationCount`.
    ///
    /// **TASK 28 checked for a real driver before adding the second helper, as the handover note asked,
    /// and the note was half right.** `dismissEditMenuCountForTesting` DOES have an isolating driver —
    /// `dismissEditMenu()` (`DocumentCanvasView+EditMenu.swift`) bumps the counter and touches nothing
    /// else this struct watches — so its control uses that driver and gets NO `withX(_:)` helper.
    /// `undoRegistrationCount` does NOT: its only writer anywhere in `Sources/` is inside
    /// `editing(coalescing:_:)` (`DocumentCanvasView+Editing.swift`), which also bumps `revision`,
    /// `layoutGeneration` and — via its own `dismissEditMenuForSelectionOrTextChange()` — the dismiss
    /// counter. `editing { }` IS a real driver, just not an isolating one, which is exactly `revision`'s
    /// situation, so it gets the same two-half treatment.
    ///
    /// This init lets a control build a baseline that agrees with the live canvas in every field but one,
    /// so the resulting failure is attributable BY CONSTRUCTION. It is deliberately NOT for building
    /// expectations out of thin air: a control must derive it from a real `RouterStateSnapshot(canvas)`
    /// and vary exactly the field under test (see `withRevision(_:)` below).
    ///
    /// `private`, per Task 27b's second review round — the answer to "an unguarded fabrication surface"
    /// that costs nothing: `withRevision(_:)` below lives in this same struct body and still compiles,
    /// while every OTHER file loses the ability to fabricate a snapshot, with the compiler enforcing it
    /// rather than this doc comment. Declaring any init also suppresses Swift's implicit memberwise one,
    /// so there is no synthesized replacement to leak. A future field-isolating control adds a
    /// `withX(_:)` helper HERE, beside `withRevision(_:)`; it does not widen this back to internal.
    private init(revision: UInt64, layoutGeneration: UInt64, anchor: Int, head: Int,
                 markedRange: NSRange?, undoRegistrationCount: Int, dismissEditMenuCountForTesting: Int) {
        self.revision = revision
        self.layoutGeneration = layoutGeneration
        self.anchor = anchor
        self.head = head
        self.markedRange = markedRange
        self.undoRegistrationCount = undoRegistrationCount
        self.dismissEditMenuCountForTesting = dismissEditMenuCountForTesting
    }

    /// A copy of `self` with only `revision` changed — the one-field variation the revision control needs.
    func withRevision(_ revision: UInt64) -> RouterStateSnapshot {
        RouterStateSnapshot(revision: revision, layoutGeneration: layoutGeneration,
                            anchor: anchor, head: head, markedRange: markedRange,
                            undoRegistrationCount: undoRegistrationCount,
                            dismissEditMenuCountForTesting: dismissEditMenuCountForTesting)
    }

    /// TASK 28 — the second field-isolating variation, for the same reason and by the same rule as
    /// `withRevision(_:)` above: `undoRegistrationCount`'s only writer co-moves three other watched
    /// fields, so a control driven by a real operation cannot attribute its failure to this term.
    /// `dismissEditMenuCountForTesting` deliberately has NO such helper — `dismissEditMenu()` isolates
    /// it, and a helper nobody needs is a fabrication surface nobody asked for.
    func withUndoRegistrationCount(_ undoRegistrationCount: Int) -> RouterStateSnapshot {
        RouterStateSnapshot(revision: revision, layoutGeneration: layoutGeneration,
                            anchor: anchor, head: head, markedRange: markedRange,
                            undoRegistrationCount: undoRegistrationCount,
                            dismissEditMenuCountForTesting: dismissEditMenuCountForTesting)
    }
}

/// Proves a router forwarded to EXACTLY ONE backend member, with EXACTLY the expected arguments, and
/// NOTHING ELSE happened — the "and nothing else" half is what makes this more than an
/// "at-least-one-call-happened" check (the vacuity trap a router-spy mechanism exists to avoid: a
/// helper that only confirms "some call was recorded" would pass just as happily for a router that
/// forwards to the WRONG member, or forwards TWICE, as for a correct one-line router). On a count
/// mismatch the whole call log is printed so a failure names what actually happened, not just that
/// something didn't match.
@MainActor
@available(iOS 16.0, *)
func XCTAssertSingleBackendCall(
    _ spy: SpyRichTextInputBackend, member: String, arguments: [String],
    file: StaticString = #filePath, line: UInt = #line
) {
    let expected = SpyRichTextInputBackend.Call(member: member, arguments: arguments)
    guard spy.calls.count == 1 else {
        XCTFail(
            "expected exactly one backend call, \(expected), but recorded \(spy.calls.count): " +
            "[\(spy.calls.map(\.description).joined(separator: ", "))]",
            file: file, line: line)
        return
    }
    XCTAssertEqual(
        spy.calls[0], expected,
        "expected the one recorded call to be \(expected), got \(spy.calls[0])",
        file: file, line: line)
}

/// Asserts the router did NO work of its own: `revision`, `layoutGeneration`, `anchor`, `head`,
/// `markedRange`, `undoRegistrationCount` and `dismissEditMenuCountForTesting` are all unchanged from
/// `before` (captured by the caller prior to the operation under test).
@MainActor
@available(iOS 16.0, *)
func XCTAssertRouterDidNoWork(
    _ canvas: DocumentCanvasView, _ before: RouterStateSnapshot,
    file: StaticString = #filePath, line: UInt = #line
) {
    let after = RouterStateSnapshot(canvas)
    XCTAssertEqual(
        after, before,
        "the router did work of its own — canvas state moved from \(before) to \(after)",
        file: file, line: line)
}

/// Added task-23 fix round 1 (review Major 4). `XCTAssertSingleBackendCall`'s "one exact call, exact
/// arguments" half is unskippable by construction (count and arguments are one assertion), but
/// `XCTAssertRouterDidNoWork`'s canvas-side "and nothing else" half is NOT: it needs a separate
/// pre-operation `RouterStateSnapshot` line plus a separate assertion, and nothing forces either — the
/// plan's own canonical Task-24 template already omits it from 3 of 11 worked examples. This wrapper
/// folds `spy.reset()`, the `before` snapshot, running the operation, and BOTH assertions into one
/// call, so a Phase-4 author writes exit criterion 3's all four clauses ("one backend call", "exact
/// arguments", "exact return propagation" via the operation's return value, "and nothing else" on both
/// the backend log AND the canvas state) in a single line:
///
///     let result = XCTAssertRoutesOnly(canvas, spy, member: "text(in:)", arguments: [id]) {
///         canvas.text(in: someRange)
///     }
///
/// Does not replace `XCTAssertSingleBackendCall`/`XCTAssertRouterDidNoWork` — both remain for call
/// sites that need only one half (e.g. a test that intentionally does not care about canvas state).
@discardableResult
@MainActor
@available(iOS 16.0, *)
func XCTAssertRoutesOnly<R>(
    _ canvas: DocumentCanvasView, _ spy: SpyRichTextInputBackend,
    member: String, arguments: [String],
    file: StaticString = #filePath, line: UInt = #line,
    _ operation: () -> R
) -> R {
    spy.reset()
    let before = RouterStateSnapshot(canvas)
    let result = operation()
    XCTAssertSingleBackendCall(spy, member: member, arguments: arguments, file: file, line: line)
    XCTAssertRouterDidNoWork(canvas, before, file: file, line: line)
    return result
}
#endif
