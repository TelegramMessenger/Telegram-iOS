import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib

/// **What broke.** Engine: one undo after an IME composition did not revert exactly the composition.
/// The fuzz's extended sweep (seeds 31-90, 2026-09-24) left three residuals with this signature, from
/// two causes:
///
/// 1. **Seeds 63 and 86: a composition over a selection the gate resolves to NOTHING.** The selection
///    runs from the end of a code body in a block quote into the quote's (empty) author line:
///
///        [quote [p "Cob:"] [code "\nl"]]   engine "Cob:\n\n\u{2028}l\n", select 8..<9, compose 한글
///        undo → the state before the edit BEFORE the composition (seed 63: a deletion; seed 86:
///               five typed and pasted steps)
///
///    The gate decides such a selection itself: it collapses the caret and changes no character. A
///    composition that starts over a selection re-opens the typing run at the collapsed caret
///    (`endHostDecidedKeystroke`), so that the deletion and the composition are one undo step, as a
///    stock `UITextView`'s are. Here no deletion registered a step, so the composition continued a run
///    with no step behind it, registered none of its own, and one undo popped whatever step came
///    before it.
///
/// 2. **Seed 58: a composition whose selection deletion mints a list item.** The selection runs from
///    a bulleted quote child into the paragraph after the quote:
///
///        [quote [• q] [• a] [• nested]] [p "ed"]   select 4..<14, compose k → か → … → cancel
///        undo → [quote [• q] [• a] [• "k"]]  (the first candidate, committed)
///
///    The deletion leaves a fresh block after a list item, so the editor schedules its list
///    continuation for the next run-loop turn. That turn lands INSIDE the composition, after the first
///    candidate. The document set that carries the correction ended the typing run, and the next
///    candidate opened a step that restored a baseline holding `k`. The history dependence in the
///    fuzz (a pasted list many steps earlier) is only what put list items there.
///
/// 3. **Found while reducing seed 63: a composition over the join before an EMPTY paragraph.** The
///    same selection with an empty paragraph after the code block instead of the quote's author line:
///
///        [p "Cob:"] [code "\nl"] [p ""]   select 8..<9 (the join), compose 한글
///        composed → [p "Cob:"] [code "\nl한글"]            typed → [p "Cob:"] [code "\nl한글"] [p ""]
///
///    The composition's selection is resolved as a deletion, and a one-character deletion over the
///    join before a block is exactly the shape of a Backspace at that block's start, so the gate ran
///    the Backspace join rules on it and removed the empty paragraph. Nobody pressed Backspace:
///    a composition over a selection replaces it, as typing does.
///
/// **How it was seen.** The fuzz's `compose` op (invariant: one undo reverts exactly the composition),
/// reduced with a probe that traced the typing run through each candidate.
///
/// **Tier 1**: the selection, `setMarkedText(_:selectedRange:)`, the commit and the undo are the
/// keyboard's calls on the engine view (the fuzz's own `compose` op, with its invariants).
final class HarnessCompositionUndoResidualTests: XCTestCase {
    private static func code(_ text: String) -> ChatInputBlock {
        return .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: text)]))
    }

    private static func bullet(_ text: String) -> ChatInputBlock {
        return .paragraph(ChatInputParagraph(style: .body, list: ChatInputListMembership(marker: .bullet, level: 0), runs: [ChatInputRun(text: text)]))
    }

    /// `[quote [p "Cob:"] [code "\nl"]]`, engine text `"Cob:\n\n\u{2028}l\n"`: offset 8 is the end of
    /// the code body, 9 the quote's empty author line.
    private static let codeInQuote = ChatInputContent(blocks: [
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Cob:"), code("\nl")]), collapsed: false)),
    ])

    /// `[quote [• q] [• a] [• nested]] [p "ed"]`, engine text `"q\na\nnested\n\ned"`.
    private static let bulletedQuote = ChatInputContent(blocks: [
        .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [bullet("q"), bullet("a"), bullet("nested")]), collapsed: false)),
        HarnessEngine.paragraph("ed"),
    ])

    /// Replays `ops` with the fuzz's per-step invariants; returns the final model.
    @discardableResult
    private func replay(_ start: ChatInputContent, _ ops: [FuzzOp], file: StaticString = #filePath, line: UInt = #line) throws -> ChatInputContent {
        guard #available(iOS 18.4, *) else {
            throw XCTSkip("the engine editor needs iOS 18.4")
        }
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer {
            verifier.restore()
            _ = driver.node.resignInputFirstResponder()
        }
        if let failure = HarnessComposerFuzzTests.replay(driver, start: start, ops: ops) {
            XCTFail("step \(failure.step) \(ops[failure.step]): \(failure.violations.joined(separator: "; "))", file: file, line: line)
        }
        return FuzzModel.normalized(driver.model())
    }

    /// Control: typing over the same selection, then one undo, restores the document.
    func testTypingOverASelectionTheGateResolvesToNothingUndoesInOneStep() throws {
        let undone = try self.replay(Self.codeInQuote, [.select(8, 9), .insert("x"), .select(0, 0), .undo])
        XCTAssertEqual(undone, FuzzModel.normalized(Self.codeInQuote),
                       "control: one undo of typing over the selection did not restore the document")
    }

    /// Seed 63: the step before the composition is a deletion.
    func testACompositionOverASelectionTheGateResolvesToNothingIsItsOwnUndoStep() throws {
        let start = ChatInputContent(blocks: [
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph("Cob:"), Self.code("\nlet x = 1")]), collapsed: false)),
        ])
        // "Cob:\n\n\u{2028}let x = 1\n": delete 8..<17 (leaves "\nl"), then compose over 8..<9.
        try self.replay(start, [.select(8, 17), .deleteBackward, .compose(.korean, .unmark, selecting: (8, 9))])
    }

    /// Seed 86: the steps before the composition are typing; one undo took them back as well.
    func testACompositionOverASelectionTheGateResolvesToNothingKeepsTheTypingBeforeIt() throws {
        // Type "xyz" at the end of the code body (8), then compose over the "\n" into the author line.
        try self.replay(Self.codeInQuote, [.select(8, 8), .insert("xyz"), .compose(.pinyin, .unmark, selecting: (11, 12))])
    }

    /// Found while reducing seed 63: the composition must do what typing over the selection does.
    func testACompositionOverTheJoinBeforeAnEmptyParagraphReplacesItAsTypingDoes() throws {
        let start = ChatInputContent(blocks: [HarnessEngine.paragraph("Cob:"), Self.code("\nl"), HarnessEngine.paragraph("")])
        try self.replay(start, [.compose(.korean, .unmark, selecting: (8, 9))])
    }

    /// Seed 58, cancelled: one undo must restore the selection's text, not leave the first candidate.
    func testACancelledCompositionThatMintsAListItemUndoesInOneStep() throws {
        try self.replay(Self.bulletedQuote, [.compose(.japanese, .cancel, selecting: (4, 14))])
    }

    /// Seed 58's shape, committed.
    func testACommittedCompositionThatMintsAListItemUndoesInOneStep() throws {
        try self.replay(Self.bulletedQuote, [.compose(.japanese, .unmark, selecting: (4, 14))])
    }
}
