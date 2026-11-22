import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02; audit of the p23 one-line-field rule, compositions).** An IME composition whose
/// marked text holds a `"\n"`, committed in a pull quote's AUTHOR or a details TITLE, splits the field: the text
/// after the newline leaves the quote / the title as a body paragraph.
///
///     [p "a"] [pull "pq" author="auth"] [p "end"], caret after "auth",
///     marked "k" → "か" → "か\nき", unmark (or insertText of the final)
///       → [pull "pq" author="authか"] [p "き"] …        typing "か\nき" there gives author "authか き"
///
/// The same composition with `U+2028`, `U+2029` or CR is flattened to one space by settle's repair
/// (`settleLineBreaksInOneLineFields`, p23) — only "\n" escapes, because it is the engine's block separator: the
/// marked text has already split the engine block before the commit's settle runs, and the repair only rewrites
/// characters inside a field. A code LANGUAGE line is not split (its Return rule holds); the author and the title
/// are.
///
/// **Suspected cause.** Marked text bypasses the surface gate (p23 lists "a composition's commit" as what only settle
/// sees), and `settleLineBreaksInOneLineFields` repairs characters, not a block the "\n" already split off. The
/// commit's settle should rejoin a block split from a one-line field by the composition (or the gate should rewrite
/// "\n" in marked text for a one-line field, as `oneLineFieldText` does for typed text).
///
/// **Severity.** Low (no keyboard known to put a newline into marked text; dictation and handwriting IMEs are the
/// candidates). The structure changes: the author's tail is sent as message text.
///
/// **Tier 1**: `setMarkedText(_:selectedRange:)` / `unmarkText` on the engine view, as a keyboard sends them.
@available(iOS 18.4, *)
final class HarnessCompositionNewlineInOneLineFieldTests: XCTestCase {
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

    private static let pull = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .pullQuote(ChatInputPullQuote(runs: [E.run("pq")], author: [E.run("auth")])), E.paragraph([E.run("end")])])
    private static let details = ChatInputContent(blocks: [E.paragraph([E.run("a")]), .details(ChatInputDetails(content: ChatInputContent(blocks: [E.paragraph([E.run("b")])]), title: [E.run("ttl")], expanded: true)), E.paragraph([E.run("end")])])

    private func caret(after needle: String, in content: ChatInputContent) {
        HarnessComposerFuzzTests.arrange(self.driver, content)
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: needle)), length: 0))
        self.driver.settle(0.1)
    }

    private func compose(_ final: String) -> ChatInputContent {
        let input = self.driver.view as! (UIView & UITextInput)
        for step in ["k", "か", final] {
            input.setMarkedText(step, selectedRange: NSRange(location: (step as NSString).length, length: 0))
            self.driver.settle(0.05)
        }
        input.unmarkText()
        self.driver.settle(0.3)
        return FuzzModel.normalized(self.driver.model())
    }

    private func typed(_ text: String, after needle: String, in content: ChatInputContent) -> ChatInputContent {
        self.caret(after: needle, in: content)
        self.driver.insert(text)
        self.driver.settle(0.3)
        return FuzzModel.normalized(self.driver.model())
    }

    // MARK: - Red

    func testANewlineCompositionInAnAuthorDoesWhatTypingDoes() {
        let typed = self.typed("か\nき", after: "auth", in: Self.pull)
        self.caret(after: "auth", in: Self.pull)
        let composed = self.compose("か\nき")
        XCTAssertEqual(composed.blocks.count, 3, "the author was split: \(E.describe(composed))")
        XCTAssertEqual(composed, typed, "composed \(E.describe(composed)), typed \(E.describe(typed))")
    }

    func testANewlineCompositionInADetailsTitleDoesWhatTypingDoes() {
        let typed = self.typed("か\nき", after: "ttl", in: Self.details)
        self.caret(after: "ttl", in: Self.details)
        let composed = self.compose("か\nき")
        XCTAssertEqual(composed, typed, "composed \(E.describe(composed)), typed \(E.describe(typed))")
    }

    // MARK: - Controls

    func testControlALineSeparatorCompositionInAnAuthorIsFlattened() {
        self.caret(after: "auth", in: Self.pull)
        let composed = self.compose("か\u{2028}き")
        guard case let .pullQuote(quote) = composed.blocks[1] else { return XCTFail(E.describe(composed)) }
        XCTAssertEqual(quote.author.map(\.text).joined(), "authか き")
        XCTAssertEqual(composed.blocks.count, 3)
    }

    func testControlTypingANewlineIntoAnAuthorIsFlattened() {
        let typed = self.typed("か\nき", after: "auth", in: Self.pull)
        guard case let .pullQuote(quote) = typed.blocks[1] else { return XCTFail(E.describe(typed)) }
        XCTAssertEqual(quote.author.map(\.text).joined(), "authか き")
    }
}
