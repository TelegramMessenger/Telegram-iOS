import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20 fix wave, 2026-10-01; found by the fuzz's new model-unrepresentable check):** Format ▸
/// Monospace over a selection, then TYPING (or an IME composition) over that selection, gives text that is
/// not inline code in the model — the typed-text policy runs only for an insertion at a caret, and the
/// controller's typing attributes keep the inline-code marker out — but that keeps the inline-code PILL's
/// grey fill in storage: `"ab"`, select `a`, Monospace, type `中国` → model `[p "中国b"]`, storage
/// `NSBackgroundColor systemGray5` over `中国`. The composer drew a grey highlight that is not sent. The
/// derived-presentation check could not see it: the read-back took the fill for a user highlight, so the
/// re-render drew it again. Default fuzz seeds 13, 14 and ~20 others (p20 fix wave sweep).
///
/// **Fixed:** the bridge's read-back treats the theme's inline-code fill on a run that is not inline code
/// as carried presentation (`withoutCarriedPresentation`), as it already treated the theme's text colour;
/// settle then re-derives the block without it.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessTypingOverMonospaceSelectionTests: XCTestCase {
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

    private func overMonospaceSelection(_ edit: (UIView & UITextInput) -> Void) -> ChatInputContent {
        self.driver.arrange(HarnessContent.plainText("ab"))
        self.driver.setViewSelection(NSRange(location: 0, length: 1))
        self.driver.settle()
        self.driver.format(.monospace)
        self.driver.settle()
        edit(self.driver.view as! (UIView & UITextInput))
        self.driver.settle()
        return self.driver.model()
    }

    private func assertNoFillOutsideCode(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        let isCode = model.blocks.contains { block in
            if case let .paragraph(p) = block { return p.runs.contains { $0.attributes.monospace } }
            return false
        }
        for block in self.driver.editor.engine.attributedBlocks {
            block.enumerateAttribute(.backgroundColor, in: NSRange(location: 0, length: block.length)) { value, range, _ in
                if value != nil && !isCode {
                    XCTFail("a grey fill is drawn over \(fuzzEscaped((block.string as NSString).substring(with: range))) although the model has no inline code: \(HarnessEdited.describe(model))", file: file, line: line)
                }
            }
        }
        XCTAssertEqual(self.driver.editor.modelUnrepresentableFields(atBlock: 0), [], file: file, line: line)
    }

    func testTypingOverAMonospaceSelectionDrawsNoFill() {
        self.assertNoFillOutsideCode(self.overMonospaceSelection { $0.insertText("中国") })
    }

    func testComposingOverAMonospaceSelectionDrawsNoFill() {
        self.assertNoFillOutsideCode(self.overMonospaceSelection { input in
            input.setMarkedText("zh", selectedRange: NSRange(location: 2, length: 0))
            input.setMarkedText("中国", selectedRange: NSRange(location: 2, length: 0))
            input.unmarkText()
        })
    }

    /// Control: Monospace at a CARET, then typing, is inline code with its fill (the typed-text policy).
    func testControlTypingAfterMonospaceAtACaretIsCode() {
        self.driver.arrange(HarnessContent.plainText(""))
        self.driver.format(.monospace)
        self.driver.settle()
        self.driver.insert("code")
        self.driver.settle()
        XCTAssertEqual(FuzzModel.describe(FuzzModel.normalized(self.driver.model())), "[p body [m]\"code\"]")
    }
}
