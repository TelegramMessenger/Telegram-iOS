import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CRASH):** an edit over a range that ends INSIDE an emoji modifier sequence
/// (between `👍` and its skin tone `🏽`) in a pull quote's AUTHOR line raises an uncaught
/// `NSRangeException` (`-[__NSArrayM objectAtIndexedSubscript:]: index 1 beyond bounds [0 .. 0]`) from
/// `-[IDBlockDocument replaceCanonicalRange:withAttributedString:]`, which kills the app. Typing, Backspace
/// and an IME composition all reach it: `[pull "abc" author="x👍🏽y"]`, select 1..<7 (or 4..<7, wholly
/// inside the author), type `X` → raise. Controls: the same range across two PARAGRAPHS, and inside the
/// pull quote's BODY, edit without raising (they leave the orphaned `🏽`, as a stock text view does); a
/// range ending on the cluster's boundary (1..<9) edits cleanly.
///
/// **How it was seen:** a greedy reducer replaying default fuzz seed 68 (p20 sweep 46-90) hit it: the raising
/// stack runs `setMarkedText:` → `tgid_resolveSelectionBeforeComposition` → the surface gate's
/// `replaceAcrossBlocks` → `replaceFlat` → UIKit `replaceRange:withText:` → `IDCanonicalTextStorageAdapter`
/// → `IDBlockDocument replaceCanonicalRange:withAttributedString:`. Reachability from UIKit's own gestures
/// is not shown (the handles and ⇧-arrows move by grapheme); a range from a keyboard replacement,
/// dictation or an accessibility client is offset-based.
///
/// **Suspected:** `IDBlockDocument replaceCanonicalRange:withAttributedString:` (upstream engine) indexes a
/// per-block array by a block index computed from the range's end, which on a secondary (author) line with a
/// split cluster resolves one block past the last; or the host's re-attribution of the author line after
/// the edit. The index must be clamped, or the range widened to cluster boundaries before the edit.
///
/// **Tier 1.** XCTest reports the exception as a failure; in the app it is fatal.
@available(iOS 18.4, *)
final class HarnessAuthorLineMidClusterCrashTests: XCTestCase {
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

    /// Body `"abc"` 0..<3; author `"x👍🏽y"`: x 4, 👍 5..<7, 🏽 7..<9, y 9.
    private static let pullQuote = ChatInputContent(blocks: [.pullQuote(ChatInputPullQuote(runs: [ChatInputRun(text: "abc")], author: [ChatInputRun(text: "x👍🏽y")]))])

    private func edit(_ content: ChatInputContent, _ range: NSRange, _ edit: (UIView & UITextInput) -> Void) -> ChatInputContent {
        self.driver.arrange(content)
        self.driver.setViewSelection(range)
        self.driver.settle()
        XCTAssertEqual(self.driver.viewSelection(), range, "precondition: the selection")
        edit(self.driver.view as! (UIView & UITextInput))
        self.driver.settle()
        return self.driver.model()
    }

    func testTypingOverARangeEndingInsideAnAuthorsEmojiDoesNotRaise() {
        let model = self.edit(Self.pullQuote, NSRange(location: 1, length: 6)) { $0.insertText("X") }
        XCTAssertTrue(model.plainText.contains("X"), "the edit did not land: \(HarnessEdited.describe(model))")
    }

    func testBackspaceOverARangeEndingInsideAnAuthorsEmojiDoesNotRaise() {
        let model = self.edit(Self.pullQuote, NSRange(location: 1, length: 6)) { $0.deleteBackward() }
        XCTAssertFalse(model.plainText.contains("bc"), "the deletion did not land: \(HarnessEdited.describe(model))")
    }

    func testAComposingKeyboardInsideTheAuthorDoesNotRaise() {
        let model = self.edit(Self.pullQuote, NSRange(location: 4, length: 3)) { input in
            // A pinyin candidate, then a cancel (the reduced fuzz shape).
            input.setMarkedText("zhong", selectedRange: NSRange(location: 5, length: 0))
            input.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            input.unmarkText()
        }
        XCTAssertFalse(model.blocks.isEmpty)
    }

    /// Control: the same range across two paragraphs edits without raising.
    func testControlTheSameRangeAcrossParagraphsEdits() {
        let content = ChatInputContent(blocks: [HarnessEngine.paragraph("abc"), HarnessEngine.paragraph("x👍🏽y")])
        let model = self.edit(content, NSRange(location: 1, length: 6)) { $0.insertText("X") }
        XCTAssertTrue((model.plainText as NSString).hasPrefix("aX"), HarnessEdited.describe(model))
    }

    /// Control: a range ending on the cluster's boundary edits the author cleanly.
    func testControlARangeEndingOnTheClusterBoundaryEdits() {
        let model = self.edit(Self.pullQuote, NSRange(location: 1, length: 8)) { $0.insertText("X") }
        XCTAssertTrue(model.plainText.contains("X"))
    }
}
