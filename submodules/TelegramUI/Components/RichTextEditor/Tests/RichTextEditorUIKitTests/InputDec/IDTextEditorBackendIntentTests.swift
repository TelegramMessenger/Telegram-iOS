#if canImport(UIKit)
import RichTextInputDecObjC
import UIKit
import XCTest
@testable import RichTextEditorUIKit

/// `IDTextEditorBackendIntent.mutation(for:range:text:selection:)` is a PURE function over value
/// types — no kernel, no attach, no `IDDocumentCanvasView`/`IDFakeClientHarness` construction. Every
/// other Family-4 test in this package (`IDBackendIntentLatchTests`, `IDBackendFamily4Tests`) is
/// gated on `IDTextEditorBackend.isSupported()`, which is FALSE on every runtime available in this
/// stage (`incomingCallbacks` stays mandatory-rejected until Task C14 — see DIVERGENCES.md), so
/// those suites are compiled but never actually EXECUTED here. This file exists specifically to give
/// the intent-recovery logic itself at least one path that genuinely RUNS (not skips) on this
/// runtime — a real, unconditional pass, not a compile-only proxy for correctness.
@available(iOS 17.0, *)
final class IDTextEditorBackendIntentTests: XCTestCase {
    private let selection = RichTextCanonicalSelection(anchor: .downstream(2), head: .downstream(5))

    func test_insertTextWithNewline_becomesInsertParagraphBreak() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .insertText, range: NSRange(location: 2, length: 0), text: "\n", selection: selection)
        guard case .insertParagraphBreak(let replacing, let origin) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(replacing, selection)
        XCTAssertEqual(origin, .softwareKeyboard)
    }

    func test_insertTextWithPlainText_becomesInsertText() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .insertText, range: NSRange(location: 2, length: 0), text: "a", selection: selection)
        guard case .insertText(let text, let replacing, let origin) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(text.string, "a")
        XCTAssertEqual(replacing, selection)
        XCTAssertEqual(origin, .softwareKeyboard)
    }

    func test_markedTextIntent_becomesSetMarkedText() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .markedText, range: NSRange(location: 2, length: 0), text: "ni", selection: selection)
        guard case .setMarkedText(let text, let replacing, let selectedRangeInMarkedText) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(text.string, "ni")
        XCTAssertEqual(replacing, selection.normalizedRange)
        XCTAssertEqual(selectedRangeInMarkedText, NSRange(location: 2, length: 0))
    }

    /// Task D4d — the `selectedRange` a `setMarkedText(_:selectedRange:)` call carried, when one was
    /// latched. `{0, 0}` is what a system inline prediction sends (caret at the START of the offer,
    /// so the ghost trails it); the pre-D4d code fabricated `{count, 0}` regardless, which the
    /// differential corpus measured as a uniform `+2` selection offset in all nine
    /// `inline-prediction-ios26.5-v1` scenarios.
    func test_markedTextIntent_carriesTheSuppliedSelectedRange() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .markedText, range: NSRange(location: 2, length: 0), text: "to", selection: selection,
            markedTextSelectedRange: NSRange(location: 0, length: 0))
        guard case .setMarkedText(_, _, let selectedRangeInMarkedText) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(selectedRangeInMarkedText, NSRange(location: 0, length: 0),
                       "the caller's marked-text-relative caret must survive, not be replaced by "
                       + "the end-of-marked-text fallback")
    }

    /// The fallback is deliberate, not a leftover: an unlatched `.markedText` transaction still gets
    /// the end-of-marked-text caret, which is what a CJK composition asks for. `nil` here stands for
    /// "no latch reached this transaction" — see `latchMarkedTextIntent(selectedRange:)`.
    func test_markedTextIntentWithNoSuppliedSelectedRange_fallsBackToEndOfMarkedText() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .markedText, range: NSRange(location: 2, length: 0), text: "ni", selection: selection,
            markedTextSelectedRange: nil)
        guard case .setMarkedText(_, _, let selectedRangeInMarkedText) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(selectedRangeInMarkedText, NSRange(location: 2, length: 0))
    }

    func test_deleteBackwardIntent_forwardsTheProposedRangeVerbatim() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .deleteBackward, range: NSRange(location: 2, length: 3), text: "", selection: selection)
        guard case .deleteBackward(let sel, let proposed) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(sel, selection)
        XCTAssertEqual(proposed, NSRange(location: 2, length: 3))
    }

    func test_pasteIntent_becomesInsertTextWithThePasteOrigin() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .paste, range: NSRange(location: 0, length: 0), text: "xy", selection: selection)
        guard case .insertText(let text, _, let origin) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(text.string, "xy")
        XCTAssertEqual(origin, .paste)
    }

    func test_dictationIntent_becomesInsertTextWithTheDictationOrigin() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .dictation, range: NSRange(location: 0, length: 0), text: "hello", selection: selection)
        guard case .insertText(let text, _, let origin) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(text.string, "hello")
        XCTAssertEqual(origin, .dictation)
    }

    func test_programmaticIntent_becomesReplaceTextWithTheProgrammaticOrigin() {
        let mutation = IDTextEditorBackendIntent.mutation(
            for: .programmatic, range: NSRange(location: 1, length: 2), text: "Q", selection: selection)
        guard case .replaceText(let range, let text, let origin) = mutation else {
            return XCTFail("got \(mutation)")
        }
        XCTAssertEqual(range, NSRange(location: 1, length: 2))
        XCTAssertEqual(text.string, "Q")
        XCTAssertEqual(origin, .programmatic)
    }
}
#endif
