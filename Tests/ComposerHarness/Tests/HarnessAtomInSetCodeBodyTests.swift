import XCTest
import UIKit
import TelegramCore
import TextFormat
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p24, 2026-10-02).** A CUSTOM EMOJI (or a formula) inside a code block's BODY that arrives by a
/// SET is kept as an atom: the composer draws the custom emoji inside the code block and the model keeps the
/// custom-emoji entity there, while what is sent carries a plain emoji — a `Pre` entity holds no other entity, so
/// the text route drops it (the send oracle: `[code "x " [emoji]😀]` reloads as `[code "x 😀"]`).
///
///     set [p "a"] [code "x " [custom 😀]]  → engine body "x \u{FFFC}" (an attachment drawn in code)
///                                            → sent "a\nx 😀" Pre(2..<6), no CustomEmoji entity
///
/// Every USER path already flattens an atom in a code body to its text (p16 Format ▸ Code, `blockPlainText`; the
/// p21 control `HarnessCustomEmojiIntoCodeLanguageTests.testControlACustomEmojiInTheCodeBodyLandsAsItsAltText`: the
/// emoji keyboard into a code body inserts the alt text). Only the set keeps it.
///
/// **Suspected cause.** `EngineDocumentBridge.plainCodeRuns` (render and read-back of a code body, p20) clears the
/// traits, spoiler, inline code and link but keeps `emoji` / `formula` / `button` attributes, so the mapper renders
/// the atom. It should map an atom to its text as `blockPlainText` does (custom emoji → alt text, formula → LaTeX,
/// pill → label), and the set report it (`HarnessUnreportedSetNormalisationTests`).
///
/// **Severity.** Draws what is not sent (the composer shows a custom emoji the message does not have).
///
/// **Tier 1**: an external set and the send-path oracle.
@available(iOS 18.4, *)
final class HarnessAtomInSetCodeBodyTests: XCTestCase {
    typealias E = HarnessEdited
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        HarnessEdited.installFormulaRenderer(on: self.driver.host)
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.host.panel.formulaRenderer = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    private func codeBodyAttachments() -> Int {
        var count = 0
        let editor = self.driver.editor
        for (index, block) in editor.engine.attributedBlocks.enumerated() where index < editor.currentRoles.count {
            guard case .standalone(.code) = editor.currentRoles[index].position else { continue }
            block.enumerateAttribute(.attachment, in: NSRange(location: 0, length: block.length), options: []) { value, range, _ in
                if value != nil { count += range.length }
            }
        }
        return count
    }

    private func arrange(_ codeRuns: [ChatInputRun]) {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("a")]), .code(ChatInputCode(language: nil, runs: codeRuns)), E.paragraph([E.run("end")])]))
        self.driver.settle(0.3)
    }

    // MARK: - Red

    func testACustomEmojiSetIntoACodeBodyIsNotDrawnAsAnAtom() {
        self.arrange([E.run("x "), E.emoji()])
        XCTAssertEqual(self.codeBodyAttachments(), 0, "the code body draws an atom the message cannot carry")
    }

    func testACustomEmojiSetIntoACodeBodyIsSentAsTheComposerShowsIt() {
        self.arrange([E.run("x "), E.emoji()])
        let divergence = HarnessSendPath.divergence(self.driver.chatCopy())
        XCTAssertNil(divergence, divergence?.description ?? "")
    }

    func testAFormulaSetIntoACodeBodyIsNotDrawnAsAnAtom() {
        self.arrange([E.run("x "), E.formula("a^2")])
        XCTAssertEqual(self.codeBodyAttachments(), 0, "the code body draws a formula the message sends as its LaTeX")
    }

    // MARK: - Controls

    /// The emoji keyboard into a code body inserts the alt text (p21).
    func testControlTheEmojiKeyboardIntoACodeBodyInsertsText() {
        self.arrange([E.run("x")])
        let text = self.driver.viewText() as NSString
        self.driver.setViewSelection(NSRange(location: NSMaxRange(text.range(of: "x")), length: 0))
        self.driver.settle(0.1)
        let attribute = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 5_000_000_001, file: nil)
        HarnessChatInserts.emojiKeyboard(NSAttributedString(string: "😀", attributes: [ChatTextInputAttributes.customEmoji: attribute]))(self.driver.host)
        self.driver.settle(0.3)
        XCTAssertEqual(self.codeBodyAttachments(), 0)
        XCTAssertTrue(self.driver.model().plainText.contains("x😀"), E.describe(self.driver.model()))
    }

    /// A custom emoji in a paragraph is an atom, and is sent as one.
    func testControlACustomEmojiInAParagraphIsAnAtom() {
        HarnessComposerFuzzTests.arrange(self.driver, ChatInputContent(blocks: [E.paragraph([E.run("x "), E.emoji()])]))
        self.driver.settle(0.3)
        XCTAssertNil(HarnessSendPath.divergence(self.driver.chatCopy()))
        XCTAssertEqual(HarnessComposerFuzzTests.atomCount(self.driver.model()), 1)
    }
}
