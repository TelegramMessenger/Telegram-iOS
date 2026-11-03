import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; corrupts an EDITED message):** a text message whose composer model has
/// exactly ONE empty line between two block quotes, two code blocks, or a quote and a code block —
/// `[quote "A"] [p ""] [quote "B"]` — is SENT right (`"A\n\nB"`, a `BlockQuote` on each side), but loading
/// it back for editing loses the empty line: the composer opens `[quote "A"] [quote "B"]`, and saving the
/// edit sends `"A\nB"`. Two empty lines survive (control), and so does one between a quote and a paragraph
/// (control).
///
/// **How it was seen:** the p20 send-path oracle (`HarnessSendPath`): the model sent as the chat sends it,
/// the message loaded back as `ChatControllerLoadDisplayNode`'s edit does
/// (`ChatTextInputState(inputText: chatInputStateStringWithAppliedEntities(text, entities:))`), and here set
/// into the engine composer the way the edit load sets it (an external set).
///
/// **Suspected:** `chatInputContent(from:)` (TextFormat `ChatInputContentConversion.swift`): after a carve
/// (code / quote) the cursor skips the separator; before the next carve `gapEnd` steps back over the
/// preceding `"\n"`, and with exactly one empty line the gap is then empty, so the empty paragraph is never
/// emitted. Shared code (the legacy composer loads through the same decoder); the engine is where the
/// structure is visible. Draft sync (`.textEntities` drafts) likely shares it — not driven (out of scope).
///
/// **Fixed (p20 fix wave):** the decoder emits the one empty paragraph a gap of exactly one separator
/// holds. The legacy composer loads through it too and is pinned below.
///
/// **Tier 1:** a conversion plus an external set.
@available(iOS 18.4, *)
final class HarnessSendPathBlankLineReloadTests: XCTestCase {
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

    private static func quote(_ text: String) -> ChatInputBlock {
        return .blockQuote(ChatInputBlockQuote(content: ChatInputContent(blocks: [HarnessEngine.paragraph(text)]), collapsed: false))
    }

    private static func code(_ text: String) -> ChatInputBlock {
        return .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: text)]))
    }

    private static let blank = ChatInputBlock.paragraph(ChatInputParagraph(style: .body, list: nil, runs: []))

    /// Composes `blocks`, sends what the composer holds, loads the message back into the composer as an
    /// edit does, and returns (composed, sent text, re-opened).
    private func sendAndReopen(_ blocks: [ChatInputBlock]) -> (composed: ChatInputContent, text: String?, reopened: ChatInputContent?) {
        self.driver.arrange(ChatInputContent(blocks: blocks))
        let composed = FuzzModel.normalized(self.driver.model())
        let sent = HarnessSendPath.send(composed)
        XCTAssertEqual(sent.route, .textEntities, "precondition: quotes, code and paragraphs go the text route")
        guard let reloaded = sent.reloaded else {
            return (composed, sent.messages.first?.text, nil)
        }
        self.driver.host.setInputContent(reloaded)
        self.driver.settle(0.2)
        return (composed, sent.messages.first?.text, FuzzModel.normalized(self.driver.model()))
    }

    func testABlankLineBetweenTwoQuotesSurvivesEditing() {
        let result = self.sendAndReopen([Self.quote("A"), Self.blank, Self.quote("B")])
        XCTAssertEqual(result.text, "A\n\nB", "precondition: the SENT text has the empty line")
        XCTAssertEqual(result.reopened.map(FuzzModel.describe), FuzzModel.describe(result.composed), "editing the sent message lost the empty line between the quotes")
    }

    func testABlankLineBetweenTwoCodeBlocksSurvivesEditing() {
        let result = self.sendAndReopen([Self.code("x"), Self.blank, Self.code("y")])
        XCTAssertEqual(result.text, "x\n\ny", "precondition: the SENT text has the empty line")
        XCTAssertEqual(result.reopened.map(FuzzModel.describe), FuzzModel.describe(result.composed), "editing the sent message lost the empty line between the code blocks")
    }

    func testABlankLineBetweenAQuoteAndACodeBlockSurvivesEditing() {
        let result = self.sendAndReopen([HarnessEngine.paragraph("Top"), Self.quote("A"), Self.blank, Self.code("y"), HarnessEngine.paragraph("End")])
        XCTAssertEqual(result.text, "Top\nA\n\ny\nEnd", "precondition: the SENT text has the empty line")
        XCTAssertEqual(result.reopened.map(FuzzModel.describe), FuzzModel.describe(result.composed), "editing the sent message lost the empty line between the quote and the code block")
    }

    /// Legacy control (p20 fix wave): the legacy composer opens an edit through the SAME decoder
    /// (`ChatTextInputState(inputText:)` → `chatInputContent(from:)`) and shows `attributedString(from:)`
    /// of it, so it lost the same line; with the decoder fixed it shows the sent text again. Shared code,
    /// so this is the legacy half of the same fix, not a legacy behaviour change of its own.
    func testLegacyEditLoadShowsTheBlankLineBetweenQuotes() throws {
        _ = self.driver.node.resignInputFirstResponder()
        let composed = ChatInputContent(blocks: [Self.quote("A"), Self.blank, Self.quote("B")])
        let sent = HarnessSendPath.send(composed)
        XCTAssertEqual(sent.messages.first?.text, "A\n\nB", "precondition: the SENT text has the empty line")
        let reloaded = try XCTUnwrap(sent.reloaded)
        let arranged = try HarnessLegacy.arrange(reloaded)
        defer { HarnessLegacy.restore(arranged) }
        XCTAssertEqual(arranged.textView.text, "A\n\nB", "the legacy composer's edit load lost the empty line")
    }

    /// Control: two empty lines between the quotes both survive.
    func testControlTwoBlankLinesSurvive() {
        let result = self.sendAndReopen([Self.quote("A"), Self.blank, Self.blank, Self.quote("B")])
        XCTAssertEqual(result.reopened.map(FuzzModel.describe), FuzzModel.describe(result.composed))
    }

    /// Control: one empty line between a quote and a paragraph survives.
    func testControlABlankLineBeforeAParagraphSurvives() {
        let result = self.sendAndReopen([Self.quote("A"), Self.blank, HarnessEngine.paragraph("B")])
        XCTAssertEqual(result.reopened.map(FuzzModel.describe), FuzzModel.describe(result.composed))
    }
}
