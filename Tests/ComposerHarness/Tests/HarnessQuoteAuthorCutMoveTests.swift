import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (CORRUPTS THE SENT MODEL).** Found by the p19 fix wave's sweep, once a local move had
/// become Cut + Paste (default seed 27, edited seeds 19 and 27, `move` op): two ways a quote's AUTHOR line
/// was lost.
///
/// 1. Cut over a range from a paragraph through a block quote's whole BODY — not its author line — deletes
///    the author too (the gate drops a quote whose body the range covers, author and all), while the copy
///    stops at the body's end and so carries an empty author. Cut then Paste in place loses the author:
///    `[p "Top"] [quote [p "xy"] author="Ann"] [p "end"]`, cut 3..<6 ("⏎xy"), paste → author "".
/// 2. A pull-quote fragment pasted where only RUNS go (another pull quote's body, a caption, a cell)
///    is degraded to its body runs alone (`blockInlineRuns`), so the author part the copy carried is
///    dropped: `[pull "abc" author="def"] [pull "ghi"]`, move 1..<6 ("bc⏎de") into "g|hi".
/// 3. The same for a code block's LANGUAGE (edited seed 57): a move from a paragraph through a code
///    block's language line into a table cell deleted the language and pasted the code as its text alone.
///    Such a move is refused now (the cell cannot hold the language).
///
/// **Tier 1**: `cut:` / `paste:` and the move's own entry points on the engine view.
@available(iOS 18.4, *)
final class HarnessQuoteAuthorCutMoveTests: XCTestCase {
    private typealias E = HarnessEdited

    private func letters(_ text: String) -> String {
        return String(text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.map(Character.init).sorted())
    }

    func testCuttingAQuotesBodyThenPastingKeepsItsAuthor() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let start = ChatInputContent(blocks: [E.paragraph([E.run("Top")]),
                                              .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("xy")])]), collapsed: false, author: [E.run("Ann")])),
                                              E.paragraph([E.run("end")])])
        HarnessComposerFuzzTests.arrange(driver, start)
        let before = self.letters(driver.viewText())
        // "Top\nxy\nAnn\nend": 3..<6 is "⏎xy".
        HarnessComposerFuzzTests.perform(driver, start: start, ops: [.select(3, 6), .cut, .select(3, 3), .paste])
        driver.settle(0.3)
        XCTAssertEqual(self.letters(driver.viewText()), before, "Cut + Paste lost text: \(E.describe(driver.model()))")
    }

    func testMovingFromAPullQuotesBodyIntoItsAuthorKeepsEveryLetter() throws {
        let driver = try EngineFuzzDriver()
        let verifier = FuzzEngineVerifier.nonFatal()
        defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
        let start = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [E.run("abc")], author: [E.run("def")])),
                                              .pullQuote(ChatInputPullQuote(runs: [E.run("ghi")]))])
        HarnessComposerFuzzTests.arrange(driver, start)
        let before = self.letters(driver.viewText())
        // "abc\ndef\nghi\n": 1..<6 is "bc⏎de"; 9 is "g|hi".
        driver.setViewSelection(NSRange(location: 1, length: 5))
        driver.settle(0.1)
        let context = try XCTUnwrap(driver.editor.makeTextDragContext())
        guard driver.editor.performLocalMove(context, toFlatOffset: 9) else { return }
        driver.settle(0.3)
        XCTAssertEqual(self.letters(driver.viewText()), before, "the move lost text: \(E.describe(driver.model()))")
    }

    func testMovingThroughACodeLanguageIntoACellKeepsEveryLetter() throws {
        // "a\nb\ntop\nswift\nlet": 5..<14 is "op⏎swift⏎" (up to the code text), 5..<15 reaches into it
        // (edited seed 57's shape); 1 is the end of cell "a".
        for length in [9, 10] {
            let driver = try EngineFuzzDriver()
            let verifier = FuzzEngineVerifier.nonFatal()
            defer { verifier.restore(); _ = driver.node.resignInputFirstResponder() }
            let start = ChatInputContent(blocks: [.table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)],
                                                                        rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [E.run("a")]), ChatInputTableCell(runs: [E.run("b")])])])),
                                                  E.paragraph([E.run("top")]),
                                                  .code(ChatInputCode(language: "swift", runs: [E.run("let")]))])
            HarnessComposerFuzzTests.arrange(driver, start)
            let before = self.letters(driver.viewText())
            driver.setViewSelection(NSRange(location: 5, length: length))
            driver.settle(0.1)
            let context = try XCTUnwrap(driver.editor.makeTextDragContext())
            guard driver.editor.performLocalMove(context, toFlatOffset: 1) else { continue }
            driver.settle(0.3)
            XCTAssertEqual(self.letters(driver.viewText()), before, "5..<\(5 + length): the move lost text: \(E.describe(driver.model()))")
        }
    }
}
