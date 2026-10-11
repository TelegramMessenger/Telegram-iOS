import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; reaches what is SENT):** plain text with Windows (CRLF) or classic-Mac
/// (CR) line endings — text copied from a Windows-authored file, a terminal, some web forms — pasted where
/// the engine's own paste takes it (a paragraph when the markdown parser declines, a code block, a pull
/// quote) keeps every `U+000D`: `"First paragraph."`, paste `"a\r\nb\rc"` at 5 → `[p "First a\u{D}"]
/// [p "b\u{D}c paragraph."]`, and the message is sent with the carriage returns. In a code block the engine's
/// paragraph tokenizer then answers a boundary on the wrong side of the selection (the fuzz's
/// `FuzzTextInputConsistency`: default seeds 8, 40, edited 31). The same text as RTF is normalised to `\n`
/// (control), and so is a drop (`insertPlainText(from:)` replaces `"\r\n"`).
///
/// **How it was seen:** the p20 `externalPaste` fuzz op (an RTF source carrying a literal CR), reduced here.
///
/// **Suspected:** the paste path hands the pasteboard string to UIKit's paste unnormalised (only the drop
/// path, and markdown's `plainTextFragment`, replace `"\r\n"`, and neither replaces a lone `"\r"`).
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessPastedCarriageReturnTests: XCTestCase {
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

    private func paste(_ items: [[String: Any]], into content: ChatInputContent, at caret: Int) -> ChatInputContent {
        self.driver.arrange(content)
        self.driver.setViewSelection(NSRange(location: caret, length: 0))
        self.driver.settle(0.1)
        UIPasteboard.general.items = items
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(0.5)
        return self.driver.model()
    }

    private static func carriageReturns(_ content: ChatInputContent) -> Int {
        return FuzzModel.describe(content).components(separatedBy: "\\u{D}").count - 1
    }

    func testAPlainCRLFPasteIntoAParagraphLeavesNoCarriageReturn() {
        let model = self.paste([["public.utf8-plain-text": "a\r\nb\rc"]], into: HarnessContent.plainText("First paragraph."), at: 5)
        XCTAssertTrue(model.plainText.contains("a"), "precondition: the paste landed")
        XCTAssertEqual(Self.carriageReturns(model), 0, "U+000D in the model (sent): \(FuzzModel.describe(model))")
        XCTAssertFalse(HarnessSendPath.send(model).messages.contains { $0.text.contains("\r") }, "the SENT text carries U+000D")
    }

    func testAPlainCRLFPasteIntoACodeBlockLeavesNoCarriageReturn() {
        let content = ChatInputContent(blocks: [HarnessEngine.paragraph("Code below:"), .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let x = 1")]))])
        let model = self.paste([["public.utf8-plain-text": "a\r\nb\rc"]], into: content, at: 17)
        XCTAssertEqual(Self.carriageReturns(model), 0, "U+000D in the model (sent): \(FuzzModel.describe(model))")
        XCTAssertNil(FuzzTextInputConsistency.violation(of: self.driver.view as! (UIView & UITextInput)))
    }

    /// Control: the same text as RTF is normalised to `\n`.
    func testControlAnRTFCRLFPasteIsNormalised() {
        let rtf = FuzzExternalPaste.rtf(NSAttributedString(string: "a\r\nb\rc"))
        let model = self.paste([["public.rtf": rtf]], into: HarnessContent.plainText("First paragraph."), at: 5)
        XCTAssertEqual(Self.carriageReturns(model), 0)
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(model)), "[p body \"First a\"] [p body \"b\"] [p body \"c paragraph.\"]")
    }
}
