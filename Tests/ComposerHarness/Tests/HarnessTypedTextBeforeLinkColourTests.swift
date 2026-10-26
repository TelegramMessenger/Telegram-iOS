import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20 fix wave, 2026-10-01; found by the fuzz's new model-unrepresentable check, edited seeds
/// 9 and 42 and default 24, 25, 43):** text typed — or composed — at the START of a block that opens with a
/// link or a mention took the link's accent colour without the link: `[p [link]"Al" " said"]`, caret 0,
/// type `xy` → model `[p "xy" [link]"Al" " said"]`, storage draws `xy` in the accent. The typed-text policy
/// dropped the link at a block start but kept its colour (mid-block it already restores the block's
/// colour). The model holds `xy` plain, so the composer showed accent text that is sent plain.
///
/// **Fixed:** the block-start branch of `attributesForTypedText` restores the block's colour whenever it
/// drops a link, as the mid-block branch does.
///
/// **Tier 1.**
@available(iOS 18.4, *)
final class HarnessTypedTextBeforeLinkColourTests: XCTestCase {
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

    private static func linked() -> ChatInputContent {
        var link = ChatInputInlineAttributes()
        link.entity = .url("https://telegram.org")
        return ChatInputContent(blocks: [.paragraph(ChatInputParagraph(style: .body, list: nil, runs: [ChatInputRun(text: "Al", attributes: link), ChatInputRun(text: " said")]))])
    }

    private func atStart(_ edit: (UIView & UITextInput) -> Void) {
        self.driver.arrange(Self.linked())
        self.driver.setViewSelection(NSRange(location: 0, length: 0))
        self.driver.settle()
        edit(self.driver.view as! (UIView & UITextInput))
        self.driver.settle()
    }

    private func assertTypedTextHasTheBlocksColour(_ typed: String, file: StaticString = #filePath, line: UInt = #line) {
        let model = self.driver.model()
        XCTAssertTrue(model.plainText.hasPrefix(typed), "precondition: \(HarnessEdited.describe(model))", file: file, line: line)
        XCTAssertEqual(self.driver.editor.modelUnrepresentableFields(atBlock: 0), [], "\(HarnessEdited.describe(model))", file: file, line: line)
        guard let block = self.driver.editor.engine.attributedBlocks.first else { return }
        let typedColour = block.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        let saidColour = block.attribute(.foregroundColor, at: (block.string as NSString).range(of: "said").location, effectiveRange: nil) as? UIColor
        XCTAssertEqual(typedColour, saidColour, "the typed text is drawn in \(String(describing: typedColour)), the block's text in \(String(describing: saidColour))", file: file, line: line)
    }

    func testTextTypedBeforeALinkAtABlockStartTakesTheBlocksColour() {
        self.atStart { $0.insertText("xy") }
        self.assertTypedTextHasTheBlocksColour("xy")
    }

    func testTextComposedBeforeALinkAtABlockStartTakesTheBlocksColour() {
        self.atStart { input in
            input.setMarkedText("zh", selectedRange: NSRange(location: 2, length: 0))
            input.setMarkedText("中国", selectedRange: NSRange(location: 2, length: 0))
            input.unmarkText()
        }
        self.assertTypedTextHasTheBlocksColour("中国")
    }

    /// Control: text typed INSIDE the link continues it (accent, linked) — `HarnessLinkInteriorTypingTests`.
    func testControlTextTypedInsideTheLinkContinuesIt() {
        self.driver.arrange(Self.linked())
        self.driver.setViewSelection(NSRange(location: 1, length: 0))
        self.driver.settle()
        self.driver.insert("x")
        self.driver.settle()
        guard case let .paragraph(p)? = self.driver.model().blocks.first else { return XCTFail() }
        XCTAssertTrue(p.runs.contains { $0.text.contains("x") && $0.attributes.entity != nil }, HarnessEdited.describe(self.driver.model()))
    }
}
