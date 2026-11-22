import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
import Display
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02; Priority 2, message length limits).** The composer panel's length COUNTER and the
/// Send guard for an edit with a length limit (`editMessage.inputTextMaxLength` — editing a media caption, a
/// business link's 4096) count `richTextInputNode.text.count`. On the engine, `text`
/// (`RichTextEditorChatInputNode.text`) is the document's PARAGRAPHS and block-quote children only, so a code
/// block's text counts as nothing, although it is sent as message text on the text route (a `Pre` entity):
///
///     [p "ab"] [code "let x = 1234567890"]   text = "ab" (2)      sent "ab\nlet x = 1234567890" (21)
///     [code <40 characters>], limit 12        counter blank        sent 40 characters
///
/// So a caption edit whose code block takes it over the limit shows no counter and passes the Send guard
/// (`sendButtonPressed`'s shake), and the server refuses or truncates the edit. Legacy counts the code
/// (control: its flat text holds the code's characters).
///
/// **Suspected cause.** `RichTextEditorChatInputNode.text`'s `blockText` returns nil for `.code` (and for every
/// block but a paragraph and a block quote); the comment says it "mirrors ChatInputContent.plainText", which does
/// count code (`plainText` is 21 here). The counter wants the length of what is SENT; the chat copy's `plainText`
/// is that on the text route.
///
/// **Severity.** Chat integration: a limit the composer does not enforce or show (an edit that fails at the server).
///
/// **Tier 1**: the panel's own counter (`customInputTextMaxLength`, read back through `Mirror`) and the node's
/// `text`, compared with what the send-path oracle sends.
@available(iOS 18.4, *)
final class HarnessLengthCounterCodeBlockTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.host.panel.customInputTextMaxLength = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private func counterText(_ panel: AnyObject) -> String? {
        for child in Mirror(reflecting: panel).children where child.label == "counterTextNode" {
            return (child.value as? ImmediateTextNode)?.attributedText?.string
        }
        return nil
    }

    private func arrange(_ content: ChatInputContent, limit: Int? = nil) {
        HarnessComposerFuzzTests.arrange(self.driver, content)
        self.driver.host.panel.customInputTextMaxLength = limit
        self.driver.root.view.setNeedsLayout()
        self.driver.settle(0.3)
    }

    private static let codeOnly = ChatInputContent(blocks: [.code(ChatInputCode(language: nil, runs: [E.run(String(repeating: "0123456789", count: 4))]))])

    // MARK: - Red

    func testTheCountedLengthIncludesACodeBlock() {
        self.arrange(ChatInputContent(blocks: [E.paragraph([E.run("ab")]), .code(ChatInputCode(language: "swift", runs: [E.run("let x = 1234567890")]))]))
        let sent = HarnessSendPath.send(self.driver.chatCopy())
        XCTAssertEqual(sent.route, .textEntities, "precondition: the text route")
        let sentLength = sent.messages.map { $0.text.count }.reduce(0, +)
        XCTAssertEqual(self.driver.node.text.count, sentLength, "the panel counts \(fuzzEscaped(self.driver.node.text)), the chat sends \(sent.messages.map { fuzzEscaped($0.text) })")
    }

    func testTheCounterShowsACodeBlockOverTheLimit() {
        self.arrange(Self.codeOnly, limit: 12)
        let counter = self.counterText(self.driver.host.panel)
        XCTAssertNotNil(counter, "precondition: no counter node found")
        XCTAssertEqual(counter, "-28", "40 characters against a limit of 12: the counter reads \(counter.map(fuzzEscaped) ?? "nil")")
    }

    // MARK: - Controls

    func testControlTheCounterCountsAParagraph() {
        self.arrange(ChatInputContent(blocks: [E.paragraph([E.run("abcdefghij")])]), limit: 12)
        XCTAssertEqual(self.counterText(self.driver.host.panel), "2")
    }

    func testControlACustomEmojiCountsAsOneCharacterAsSent() {
        self.arrange(ChatInputContent(blocks: [E.paragraph([E.run("a"), E.emoji("👨‍👩‍👧"), E.run("b")])]))
        let sent = HarnessSendPath.send(self.driver.chatCopy())
        XCTAssertEqual(self.driver.node.text.count, sent.messages.map { $0.text.count }.reduce(0, +))
    }

    /// Legacy's flat text holds the code block's characters, so its counter counts them.
    func testControlLegacyCountsTheCodeBlock() throws {
        let root = self.driver.root
        root.setBackend(.legacy)
        defer { root.setBackend(.engine) }
        let host = try XCTUnwrap(root.panelHost)
        host.setInputContent(Self.codeOnly)
        HarnessEngine.settle(root, seconds: 0.3)
        let node = try XCTUnwrap(host.panel.richTextInputNode)
        XCTAssertEqual(node.text.count, 40, "legacy text \(fuzzEscaped(node.text))")
    }
}
