import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What this pins (p24 fix wave, 2026-10-02; defence in depth from the p23 audit).** When the engine holds a
/// different number of blocks than the editor has roles, the layout pass rebuilds the roles from the engine's own
/// block identities (`recoverRolesFromEngineIdentities`, p23). The audit found that rebuild POSITIONAL in effect:
/// the document setter recorded identity → role by zipping the engine's identities with the roles after a rendered
/// block had been split by its `U+000A` (the engine's block separator), so every role after the split already
/// belonged to the wrong engine block, and "by identity" rebuilt from that shifted table:
///
///     [code lang="x\ny" "body"]                → [code lang="x" "y"] [p "body"]    (the body became a paragraph)
///     [code lang="x\ny" …] [table "c1" | "c2"] → the cells shift one place
///     [quote "q1\nz" "q2" author="auth"]       → the last child becomes the author
///
/// Since the fix the setter gives each rendered block's role to the FIRST engine block of its lines, leaves the
/// lines after it unknown (the recovery makes each a body paragraph where it stands) and matches the blocks after
/// the replaced span from the end. So a desync never hands a role to a block it did not render: the recovered model
/// is the set one except that the split block keeps its first line and its tail is a body paragraph.
///
/// No shipping path reaches the mismatch since p23 (every renderer maps its own newlines and the bridge's
/// `withoutBlockSeparators` is the backstop), so the test FORCES it, the p23 audit's neuter approach done through a
/// test hook instead of a product edit: `EngineDocumentBridge.testHookRenderedBlocks` turns a marker character in
/// the rendering into "\n" after the bridge's contract has run, and `testHookExpectsRoleCountMismatch` turns the
/// debug assertion off so the release path runs.
///
/// **Tier 1**: an external set through the chat node, the model read back.
@available(iOS 18.4, *)
final class HarnessRoleRecoveryByIdentityTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    /// The character the hook turns into a block separator.
    private static let marker = "\u{00A6}"

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        EngineDocumentBridge.testHookRenderedBlocks = nil
        RichTextEngineEditorView.testHookExpectsRoleCountMismatch = false
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    /// Sets `content` with every `marker` in the RENDERING made a block separator, and returns the model read back.
    private func setSplitting(_ content: ChatInputContent) -> ChatInputContent {
        RichTextEngineEditorView.testHookExpectsRoleCountMismatch = true
        EngineDocumentBridge.testHookRenderedBlocks = { blocks, _ in
            blocks.map { block in
                let result = NSMutableAttributedString(attributedString: block)
                var location = (result.string as NSString).range(of: Self.marker, options: .literal).location
                while location != NSNotFound {
                    result.replaceCharacters(in: NSRange(location: location, length: (Self.marker as NSString).length), with: "\n")
                    location = (result.string as NSString).range(of: Self.marker, options: .literal).location
                }
                return result
            }
        }
        HarnessComposerFuzzTests.arrange(self.driver, content)
        EngineDocumentBridge.testHookRenderedBlocks = nil
        self.driver.root.view.setNeedsLayout()
        self.driver.root.view.layoutIfNeeded()
        self.driver.settle(0.3)
        RichTextEngineEditorView.testHookExpectsRoleCountMismatch = false
        return FuzzModel.normalized(self.driver.model())
    }

    /// `content` with the body paragraphs holding exactly `tail` removed — at any depth: the tail stands where the
    /// engine put it, inside a quote when the split block was a quote's child — and how many were.
    private func removingTailParagraphs(_ tail: String, from content: ChatInputContent) -> (ChatInputContent, Int) {
        var removed = 0
        func strip(_ blocks: [ChatInputBlock]) -> [ChatInputBlock] {
            return blocks.compactMap { block in
                switch block {
                case let .paragraph(paragraph) where paragraph.style == .body && paragraph.list == nil && paragraph.text == tail:
                    removed += 1
                    return nil
                case var .blockQuote(quote):
                    quote.content = ChatInputContent(blocks: strip(quote.content.blocks))
                    return .blockQuote(quote)
                case var .details(details):
                    details.content = ChatInputContent(blocks: strip(details.content.blocks))
                    return .details(details)
                default:
                    return block
                }
            }
        }
        let blocks = strip(content.blocks)
        return (ChatInputContent(blocks: blocks), removed)
    }

    private func assertRecovered(_ content: ChatInputContent, expected: ChatInputContent, tail: String,
                                 file: StaticString = #filePath, line: UInt = #line) {
        let recovered = self.setSplitting(content)
        let (rest, removed) = self.removingTailParagraphs(tail, from: recovered)
        XCTAssertEqual(removed, 1, "the split block's tail \(fuzzEscaped(tail)) is not one body paragraph: \(E.describe(recovered))", file: file, line: line)
        // Through the send oracle's rich canonical form on both sides: a table's widths and heights are layout the
        // read-back fills in, not structure.
        XCTAssertEqual(HarnessSendPath.canonical(rest, route: .rich), HarnessSendPath.canonical(FuzzModel.normalized(expected), route: .rich),
                       "roles went to blocks they did not render:\n  recovered \(E.describe(recovered))\n  expected  \(E.describe(expected)) + [p \(fuzzEscaped(tail))]",
                       file: file, line: line)
    }

    func testASplitLanguageKeepsTheCodeBody() {
        let set = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "x\(Self.marker)y", runs: [E.run("body")])), E.paragraph([E.run("end")])])
        let expected = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "x", runs: [E.run("body")])), E.paragraph([E.run("end")])])
        self.assertRecovered(set, expected: expected, tail: "y")
    }

    func testASplitBeforeATableLeavesTheCellsInPlace() {
        let table = ChatInputBlock.table(ChatInputTable(
            columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)],
            rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [E.run("c1")]), ChatInputTableCell(runs: [E.run("c2")])])]))
        let set = ChatInputContent(blocks: [.code(ChatInputCode(language: "x\(Self.marker)y", runs: [E.run("body")])), table, E.paragraph([E.run("end")])])
        let expected = ChatInputContent(blocks: [.code(ChatInputCode(language: "x", runs: [E.run("body")])), table, E.paragraph([E.run("end")])])
        self.assertRecovered(set, expected: expected, tail: "y")
    }

    /// A block quote's author split, with a code block after the quote: positionally the tail took the code's
    /// LANGUAGE role and every role after it shifted.
    func testASplitAuthorStaysTheAuthor() {
        let quote = { (author: String) -> ChatInputBlock in
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("q1")]), E.paragraph([E.run("q2")])]), collapsed: false, author: [E.run(author)]))
        }
        let code = ChatInputBlock.code(ChatInputCode(language: "L", runs: [E.run("c")]))
        let set = ChatInputContent(blocks: [E.paragraph([E.run("a")]), quote("a\(Self.marker)b"), code, E.paragraph([E.run("end")])])
        let expected = ChatInputContent(blocks: [E.paragraph([E.run("a")]), quote("a"), code, E.paragraph([E.run("end")])])
        self.assertRecovered(set, expected: expected, tail: "b")
    }

    /// A quote CHILD split: positionally the last child took the AUTHOR's role (the p23 audit's "the last child
    /// becomes the author"); the tail is a child where it stands.
    func testASplitQuoteChildKeepsTheAuthor() {
        let quote = { (first: String) -> ChatInputBlock in
            .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run(first)]), E.paragraph([E.run("q2")])]), collapsed: false, author: [E.run("auth")]))
        }
        let set = ChatInputContent(blocks: [E.paragraph([E.run("a")]), quote("q1\(Self.marker)z"), E.paragraph([E.run("end")])])
        let expected = ChatInputContent(blocks: [E.paragraph([E.run("a")]), quote("q1"), E.paragraph([E.run("end")])])
        self.assertRecovered(set, expected: expected, tail: "z")
    }

    /// Control: with nothing split, the hook changes nothing and the set reads back as set.
    func testControlNoSplitReadsBackAsSet() {
        let set = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "xy", runs: [E.run("body")])), E.paragraph([E.run("end")])])
        XCTAssertEqual(self.setSplitting(set), FuzzModel.normalized(set))
    }
}
