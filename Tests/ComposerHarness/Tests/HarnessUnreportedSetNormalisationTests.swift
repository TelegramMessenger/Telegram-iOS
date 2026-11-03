import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02; audit of the p23 "a set the editor normalises is reported back" rule).** The p23
/// fix wave made `RichTextEditorChatInputNode.setInputContent` report a normalising set to the chat a turn later, so
/// the chat's copy — what `sendCurrentMessage` reads — is what the composer shows. `holdsContentTheEditorNormalises`
/// lists the three p23 normalisations only (a line break in a one-line field, inline code over an entity, a
/// multi-emoji custom-emoji run). The editor normalises MORE on the way in, and for those the chat keeps sending
/// the content as it was set:
///
/// - formatting, an entity or inline code in a CODE BODY (the p20 rule, `EngineDocumentBridge.plainCodeRuns`):
///   `[p heading1 "H"] [code [b]"let"]` set → the composer shows plain `let`; the chat's copy keeps the bold, and on
///   the RICH route (any heading, list, table… beside the code) the message is sent with bold inside the code block.
///   A mention in a code body is likewise shown plain and kept in the chat's copy;
/// - a code LANGUAGE with surrounding whitespace, or an empty / blank one (the read-back trims: "an emptied line
///   means no language"): set `"  swift "` → the composer holds `swift`, the chat sends `"  swift "`; set `""` →
///   no language shown, the chat sends an empty language;
/// - a `U+2028` in a body paragraph (the read-back's `modelText` turns the engine's line separator into "\n"):
///   the composer holds "a\nb", the chat sends "a\u{2028}b";
/// - one FORMULA run holding two copies of its LaTeX (two adjacent identical formulas, coalesced as the p23 custom-
///   emoji row describes): the bridge makes ONE atom, so the composer shows one formula and the chat sends two.
///
/// Where the set comes from: a draft synced from another client, a chat-side transform (Translate, a bot's
/// switch-inline query, autocomplete over such content), an edit load of a message another client produced. The
/// p20 decoder reads a code region back plain, so a plain edit load of an own rich message does not reach the first
/// class.
///
/// **Suspected cause.** `holdsContentTheEditorNormalises` (`RichTextEditorChatInputNode.swift`) enumerates p23's
/// normalisations by hand; the editor's others (p20 `plainCodeRuns`, the language trim, `modelText`, atoms in a
/// formula run) are not in it. A by-construction rule would compare: after the set, report when the node's read-back
/// differs from the content set (`currentInputContent().content != content`), which also covers any normalisation
/// added later. The formula case also wants the p23 per-occurrence split for formulas (as for custom emoji).
///
/// **Severity.** CORRUPTS WHAT IS SENT (the code-body class on the rich route); the rest is a message that differs
/// from what the composer showed (whitespace, a line-separator character, a duplicated formula).
///
/// **Tier 1**: an external set (`HarnessPanelHost.setInputContent`) into the focused composer, and the send-path
/// oracle.
@available(iOS 18.4, *)
final class HarnessUnreportedSetNormalisationTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: self.driver.host)
        self.verifier = FuzzEngineVerifier.nonFatal()
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("start")])]))
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.host.panel.formulaRenderer = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    /// Sets `content` from outside into the focused composer, lets the deferred report land, and returns the chat's
    /// copy and the node's model.
    private func set(_ content: ChatInputContent) -> (chat: ChatInputContent, model: ChatInputContent) {
        self.driver.host.setInputContent(content)
        self.driver.settle(0.4)
        return (self.driver.chatCopy(), self.driver.model())
    }

    private func assertChatCopyIsTheModel(_ content: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        let (chat, model) = self.set(content)
        XCTAssertEqual(FuzzModel.normalized(chat), FuzzModel.normalized(model),
                       "what Send reads \(chat.blocks) is not what the composer holds \(model.blocks)", file: file, line: line)
    }

    private static var bold: ChatInputInlineAttributes {
        var attributes = ChatInputInlineAttributes()
        attributes.bold = true
        return attributes
    }

    // MARK: - Red

    /// The rich route sends the bold the composer does not show.
    func testFormattingInACodeBodyIsNotSentOnTheRichRoute() {
        let content = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [E.run("H")])),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let", attributes: Self.bold), E.run(" x")])),
        ])
        let (chat, model) = self.set(content)
        XCTAssertEqual(FuzzModel.normalized(chat), FuzzModel.normalized(model), "what Send reads keeps the bold")
        let sent = HarnessSendPath.send(chat)
        XCTAssertEqual(sent.route, .rich, "precondition: the rich route")
        let reloaded = sent.reloaded.map { FuzzModel.normalized($0) }
        XCTAssertEqual(reloaded, FuzzModel.normalized(model), "the message is not what the composer showed")
    }

    func testAMentionInACodeBodyIsReported() {
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: nil, runs: [E.run("x "), E.mention("Al")]))]))
    }

    func testACodeLanguageWithSurroundingWhitespaceIsReported() {
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "  swift ", runs: [E.run("x")]))]))
    }

    func testAnEmptyCodeLanguageIsReported() {
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "", runs: [E.run("x")]))]))
    }

    func testALineSeparatorInABodyParagraphIsReported() {
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a\u{2028}b")])]))
    }

    /// A formula run holding its LaTeX twice is two formulas (the p23 per-occurrence rule), or at least reported.
    func testAFormulaRunOfTwoFormulasIsWhatTheComposerShows() {
        let pair = ChatInputRun(text: "xyxy", attributes: E.formula("xy").attributes)
        let (chat, model) = self.set(ChatInputContent(blocks: [E.paragraph([E.run("a"), pair])]))
        XCTAssertEqual(FuzzModel.normalized(chat), FuzzModel.normalized(model), "what Send reads is not what the composer holds")
        XCTAssertEqual(HarnessComposerFuzzTests.atomCount(model), 2, "two formulas set, \(HarnessComposerFuzzTests.atomCount(model)) held: \(E.describe(model))")
    }

    // MARK: - Controls (the p23 normalisations, reported)

    func testControlALineBreakInALanguageIsReported() {
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "x\ny", runs: [E.run("x")]))]))
    }

    func testControlAMonospacedMentionIsReported() {
        var mono = E.mention("Al").attributes
        mono.monospace = true
        self.assertChatCopyIsTheModel(ChatInputContent(blocks: [E.paragraph([E.run("a "), ChatInputRun(text: "Al", attributes: mono)])]))
    }

    func testControlAPlainCodeBlockIsUnchanged() {
        let content = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: "swift", runs: [E.run("let x")]))])
        let (chat, model) = self.set(content)
        XCTAssertEqual(FuzzModel.normalized(model), FuzzModel.normalized(content))
        XCTAssertEqual(FuzzModel.normalized(chat), FuzzModel.normalized(content))
    }
}
