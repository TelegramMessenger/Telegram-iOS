import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
import TelegramPresentationData
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p23, 2026-10-01; CRASH in a debug build, CORRUPTS WHAT IS SENT in a release build).** A
/// code block's LANGUAGE or a quote's / pull quote's AUTHOR that holds a newline is rendered into the engine
/// with the newline RAW. `U+000A` is the engine's block separator, so the line becomes two engine blocks
/// while the roles still count one, and the next layout pass stops at
/// `RichTextEngineEditorView+TableLayout.swift:65`:
///
///     Fatal error: RichTextEngineEditor: 5 engine blocks against 4 roles — table frames not synced, grids left stale
///
/// — the unreduced trap of the p22 fix wave (default seed 73, "at a move"). It is reached two ways:
///
/// 1. **A set of content holding such a field** — the edit load of a message (`chatInputContent(fromInstantPage:)`
///    takes a preformatted block's language and a quote caption as they are), a draft, the chat's own sets:
///    `[p "a"] [code lang="x\ny" "body"] [p "end"]` set → trap (likewise a pull-quote or block-quote author
///    `"au\nth"`).
/// 2. **Text holding `U+2028` delivered into the line** — `insertText:` (a keyboard; a text replacement),
///    a marked-text commit, the chat's own insert on the user's behalf (`chatComposerInsertTextOnUsersBehalf`).
///    The gate's one-line rule (`oneLineFieldText`) is asked only for text containing `"\n"`
///    (`decideTextInput`: `guard hasNewline else { return .forward(text) }`), so `"M\u{2028}X"` lands raw;
///    the read-back turns `U+2028` into `"\n"` (`modelText`), and the NEXT render of the line — a theme
///    change, an undo / redo replay, a format pass, Send + edit — writes the raw `"\n"` back: trap. (Paste and
///    a drop flatten it; they go through `oneLineFieldText` first.)
///
/// **In a release build** the `assertionFailure` is compiled out and the layout pass returns with the grids
/// stale; measured with the assertion temporarily disabled: the roles stay shifted against the engine
/// blocks, the model reads `[p "a"] [code lang="x" "y"] [p "body"]` — the code body leaves the code block,
/// and the document's LAST block (`"end"`) is gone from the model; typing after it sends
/// `… [p "body"] [p "endZ"]`; after the theme change the view itself loses `"end"`.
///
/// **Suspected cause.** `EngineDocumentBridge.languageLine(text:using:)` and `authorLine(runs:centred:using:)`
/// build the line from model text without `engineText` / `engineRuns` (every other line — caption, cell,
/// details title, code and pull-quote bodies — maps `"\n"` to `U+2028` there), while the read-back maps
/// `U+2028` to `"\n"` for every secondary line (`block(for:from:)` → `modelRuns`). Both ends of a one-line
/// field should agree: flatten a newline to a space (the gate's own rule) on render and at the gate for every
/// newline character, not only `"\n"`. Independently, the count check that traps here is the right invariant
/// but recovers nothing in release; a mismatch should rebuild the roles from the document, not leave them.
///
/// **Tier 1**: an external set (`HarnessPanelHost.setInputContent`), `insertText:`, the chat's insert, a
/// theme change and the send path's edit load. A red case here TRAPS the test process (XCTest relaunches
/// and goes on): count it from the `Fatal error` line, not from the summary.
@available(iOS 18.4, *)
final class HarnessNewlineInOneLineFieldCrashTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private static func document(_ middle: ChatInputBlock) -> ChatInputContent {
        return ChatInputContent(blocks: [E.paragraph([E.run("a")]), middle, E.paragraph([E.run("end")])])
    }

    private static let code = ChatInputBlock.code(ChatInputCode(language: "swift", runs: [E.run("body")]))
    private static let pull = ChatInputBlock.pullQuote(ChatInputPullQuote(runs: [E.run("pq")], author: [E.run("auth")]))
    private static let quote = ChatInputBlock.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("qb")])]), collapsed: false, author: [E.run("auth")]))

    /// The engine and the roles agree, nothing the per-step invariants check is broken, and the blocks around
    /// the field are intact in what Send reads.
    private func assertConsistent(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let editor = self.driver.editor
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count, "\(label): engine blocks vs roles", file: file, line: line)
        let chat = self.driver.chatCopy()
        XCTAssertEqual(chat.blocks.count, 3, "\(label): what Send reads \(FuzzModel.describe(chat))", file: file, line: line)
        if case let .paragraph(last)? = chat.blocks.last {
            XCTAssertEqual(last.text, "end", "\(label): the last paragraph, \(FuzzModel.describe(chat))", file: file, line: line)
        } else {
            XCTFail("\(label): the last block is not the paragraph \"end\": \(FuzzModel.describe(chat))", file: file, line: line)
        }
        let violations = self.driver.unfilteredViolations()
        XCTAssertTrue(violations.isEmpty, "\(label): \(violations)", file: file, line: line)
    }

    private func caret(after needle: String) {
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: needle)), length: 0))
        self.driver.settle(0.1)
    }

    private func themeRoundTrip() {
        for dark in [true, false] {
            self.driver.host.updatePresentationInterfaceState { $0.updatedTheme(dark ? defaultDarkPresentationTheme : defaultPresentationTheme) }
            self.driver.root.view.setNeedsLayout()
            self.driver.settle(0.2)
        }
    }

    // MARK: - Red: a set holding a newline in a one-line field

    func testASetOfACodeLanguageHoldingANewlineKeepsTheEngineInStep() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(.code(ChatInputCode(language: "x\ny", runs: [E.run("body")]))))
        self.assertConsistent("set")
    }

    func testASetOfAPullQuoteAuthorHoldingANewlineKeepsTheEngineInStep() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(.pullQuote(ChatInputPullQuote(runs: [E.run("pq")], author: [E.run("au\nth")]))))
        self.assertConsistent("set")
    }

    func testASetOfABlockQuoteAuthorHoldingANewlineKeepsTheEngineInStep() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(.blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [E.paragraph([E.run("qb")])]), collapsed: false, author: [E.run("au\nth")]))))
        self.assertConsistent("set")
    }

    // MARK: - Red: U+2028 delivered into the line, then a re-render

    func testALineSeparatorTypedIntoALanguageSurvivesAThemeChange() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.code))
        self.caret(after: "sw")
        self.driver.insert("M\u{2028}X")
        self.driver.settle(0.2)
        self.themeRoundTrip()
        self.assertConsistent("typed, theme round trip")
    }

    func testALineSeparatorTypedIntoAnAuthorSurvivesUndoAndRedo() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.pull))
        self.caret(after: "au")
        self.driver.insert("M\u{2028}X")
        self.driver.settle(0.2)
        self.driver.undoManager?.undo()
        self.driver.settle(0.2)
        self.driver.undoManager?.redo()
        self.driver.settle(0.2)
        self.assertConsistent("typed, undo, redo")
    }

    /// The chat's own insert on the user's behalf (`chatComposerInsertTextOnUsersBehalf`) into a block quote's
    /// author, then a theme change.
    func testTheChatsInsertOfALineSeparatorIntoAnAuthorSurvivesAThemeChange() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.quote))
        self.caret(after: "au")
        HarnessChatInserts.emojiKeyboard(NSAttributedString(string: "M\u{2028}X"))(self.driver.host)
        self.driver.settle(0.2)
        self.themeRoundTrip()
        self.assertConsistent("chat insert, theme round trip")
    }

    /// Typed into a language, SENT, and opened for editing (the send path's edit load): the sent message
    /// carries the newline in its language, and loading it back traps.
    func testALanguageWithATypedLineSeparatorSurvivesSendAndEdit() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.code))
        self.caret(after: "sw")
        self.driver.insert("M\u{2028}X")
        self.driver.settle(0.2)
        let sent = HarnessSendPath.send(self.driver.model())
        guard let reloaded = sent.reloaded else { return XCTFail("precondition: the send path reloads nothing (route \(sent.route))") }
        // Send's clear, then the edit load of the sent message (two external sets, as the chat makes them).
        self.driver.host.setInputContent(ChatInputContent())
        self.driver.settle(0.1)
        self.driver.host.setInputContent(reloaded)
        self.driver.settle(0.2)
        self.assertConsistent("send + edit load")
    }

    /// The same gap without a trap: the other line-break characters (`U+2029`, CR, NEL) typed into a language,
    /// an author or a details title land in the one-line field as they are (`hasNewline` reads only "\n"), and
    /// are sent so. Fails cleanly (no render splits on them).
    func testOtherLineBreaksTypedIntoOneLineFieldsAreFlattened() {
        let doc = ChatInputContent(blocks: [E.paragraph([E.run("a")]), Self.code, Self.pull,
                                            .details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("db")])]), title: [E.run("title")], expanded: true)),
                                            E.paragraph([E.run("end")])])
        for separator in ["\u{2029}", "\r", "\u{85}"] {
            for needle in ["sw", "au", "ti"] {
                HarnessComposerFuzzTests.arrange(self.driver, doc)
                self.caret(after: needle)
                self.driver.insert("M" + separator + "X")
                self.driver.settle(0.2)
                let found = FuzzModel.lineBreaksInOneLineFields(self.driver.chatCopy())
                XCTAssertTrue(found.isEmpty, "\(fuzzEscaped(separator)) after \(needle): \(found.map { "\($0.field) \(fuzzEscaped($0.text))" })")
            }
        }
    }

    // MARK: - Controls

    /// A details TITLE renders its newline as `U+2028` (`detailsTitleLine` → `engineRuns`): no split.
    func testControlASetOfADetailsTitleHoldingANewlineKeepsTheEngineInStep() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(.details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("db")])]), title: [E.run("ti\ntle")], expanded: true))))
        let editor = self.driver.editor
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count)
        self.themeRoundTrip()
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count)
        XCTAssertEqual(self.driver.chatCopy().blocks.count, 3, FuzzModel.describe(self.driver.chatCopy()))
    }

    /// A media CAPTION and a table CELL holding a newline: no split.
    func testControlACaptionAndACellHoldingANewlineKeepTheEngineInStep() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [
            E.paragraph([E.run("a")]), E.media(1, caption: "ca\nption"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0)], rows: [ChatInputTableRow(cells: [ChatInputTableCell(runs: [E.run("ce\nll")])])])),
            E.paragraph([E.run("end")]),
        ]))
        let editor = self.driver.editor
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count)
        self.themeRoundTrip()
        XCTAssertEqual(editor.engine.tgid_blockIdentifiers.count, editor.currentRoles.count)
    }

    /// A pasted `U+2028` into a language is flattened (the paste goes through `oneLineFieldText`), so a theme
    /// change after it is safe.
    func testControlAPastedLineSeparatorIntoALanguageIsFlattened() {
        HarnessComposerFuzzTests.arrange(self.driver, Self.document(Self.code))
        self.caret(after: "sw")
        UIPasteboard.general.string = "M\u{2028}X"
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.4)
        self.themeRoundTrip()
        self.assertConsistent("pasted, theme round trip")
        guard case let .code(code) = self.driver.chatCopy().blocks[1] else { return XCTFail(FuzzModel.describe(self.driver.chatCopy())) }
        XCTAssertEqual(code.language, "swM Xift")
    }
}
