import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CORRUPTS WHAT IS SENT):** a Format command (Bold, Spoiler, Monospace, …)
/// over a selection that splits an emoji's surrogate pair — `"a😀b"`, select 1..<2 (the high surrogate) —
/// restyles half of the character, the model's runs split between the two halves, and each lone surrogate
/// becomes `U+FFFD` in the model: `[p "a"+[b]"\u{FFFD}"+"\u{FFFD}b"]`. The composer still shows `😀` (the
/// engine's storage keeps the pair), so the user sees an emoji and sends two replacement characters. A
/// stock `UITextView` accepts the same selection (`selectedRange` stays {1, 1}), so an offset-based client
/// can make it; the fuzz reached it at default seed 68 (a `typeInFormat` Spoiler over 6..<7). Control: the
/// same format over the whole emoji is clean.
///
/// **Suspected:** the inline format commands (`recordingInlineFormatStep`, `transformInlineAttributes`)
/// apply to the range as given, and the model read-back (`DocumentChatInputContentBridge` over
/// `engine.attributedBlocks`) splits runs at the attribute boundary inside the pair. A format range should
/// be widened to composed-character boundaries (a stock text view's typing never splits a pair either).
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessFormatSplitSurrogateTests: XCTestCase {
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

    private func format(_ format: FuzzFormat, _ range: NSRange) -> ChatInputContent {
        self.driver.arrange(HarnessContent.plainText("a😀b"))
        self.driver.setViewSelection(range)
        self.driver.settle()
        XCTAssertEqual(self.driver.viewSelection(), range, "precondition: the selection")
        self.driver.format(format)
        self.driver.settle()
        return self.driver.model()
    }

    private func assertEmojiIntact(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(model.plainText.contains("\u{FFFD}"), "the emoji became replacement characters in the model: \(HarnessEdited.describe(model, merging: false))", file: file, line: line)
        XCTAssertTrue(model.plainText.contains("😀"), "the emoji is gone from the model", file: file, line: line)
        XCTAssertFalse(HarnessSendPath.send(model).messages.contains { $0.text.contains("\u{FFFD}") }, "the SENT text carries U+FFFD", file: file, line: line)
    }

    func testBoldOverTheHighSurrogateKeepsTheEmoji() {
        self.assertEmojiIntact(self.format(.bold, NSRange(location: 1, length: 1)))
    }

    func testSpoilerOverTheLowSurrogateKeepsTheEmoji() {
        self.assertEmojiIntact(self.format(.spoiler, NSRange(location: 2, length: 1)))
    }

    /// Control: the whole emoji formats cleanly.
    func testControlBoldOverTheWholeEmoji() {
        let model = self.format(.bold, NSRange(location: 1, length: 2))
        self.assertEmojiIntact(model)
    }
}
