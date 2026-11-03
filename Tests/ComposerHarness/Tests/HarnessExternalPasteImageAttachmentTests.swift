import XCTest
import UIKit
import TelegramCore
import ChatInputTextNode
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CORRUPTS WHAT IS SENT):** rich text copied in ANOTHER app with an image
/// in it — an RTFD from Notes / Pages / TextEdit, an HTML fragment with an `<img>` from Safari or Mail —
/// pastes the image as an `NSTextAttachment`, and the model gets it as a bare `U+FFFC` run with no entity:
/// `"First before \u{FFFC} after paragraph."`. The message sends the replacement character literally.
/// Every destination does it (paragraph, heading, list item, quote, code, cell, caption, pull quote,
/// author, details title — p20 probe). An RTFD whose item ALSO carries plain text pastes the text without
/// the image (control): the text-only reading is the one a composer can hold.
///
/// **How it was seen:** p20 external-paste sweep (pasteboards written in-process, never read first),
/// `FuzzModel.bareAttachments`. Legacy control: the legacy composer leaves the same bare `U+FFFC` (shared;
/// recorded, legacy is not the subject).
///
/// **Suspected:** the engine's own paste (`TGIDObservingBlockTextView.paste:` → `IDBlockTextView` →
/// `textPasteConfigurationSupporting:combineItemAttributedStrings:` → `IDInlineTextStyleResolver
/// importAttributedString:`) keeps every attribute it does not know, `NSAttachment` included; the bridge
/// then reads the attachment character as text. An import should drop a foreign attachment (or the paste
/// should hand the image to the chat's media flow, `onPasteMedia`, as an image-only pasteboard does).
///
/// **Tier 1:** a real `paste:` on the engine view.
@available(iOS 18.4, *)
final class HarnessExternalPasteImageAttachmentTests: XCTestCase {
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

    static func image() -> UIImage {
        return UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    static func rtfd(withImage: Bool) -> Data {
        let text = NSMutableAttributedString(string: "before ")
        if withImage {
            let attachment = NSTextAttachment()
            attachment.image = Self.image()
            text.append(NSAttributedString(attachment: attachment))
        }
        text.append(NSAttributedString(string: " after"))
        return try! text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtfd])
    }

    static let htmlWithImage = "<meta charset=\"utf-8\"><p>x<img src=\"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==\">y</p>"

    private func paste(_ items: [[String: Any]], into content: ChatInputContent, at selection: NSRange, settle: TimeInterval = 0.5) -> ChatInputContent {
        self.driver.arrange(content)
        self.driver.setViewSelection(selection)
        self.driver.settle(0.1)
        UIPasteboard.general.items = items
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        // An HTML import warms WebKit up the first time and lands ~1 s later (measured, p20).
        self.driver.settle(settle)
        return self.driver.model()
    }

    private func assertNoBareAttachment(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(self.driver.viewText().contains("before") || self.driver.viewText().contains("xy") || self.driver.viewText().contains("x\u{FFFC}"), "precondition: the paste landed: \(HarnessEdited.describe(model))", file: file, line: line)
        let bare = FuzzModel.bareAttachments(model)
        XCTAssertTrue(bare.isEmpty, "the pasted image is a bare U+FFFC in the model (sent literally): \(bare.map { "\($0.container): \(fuzzEscaped($0.text))" }); model \(HarnessEdited.describe(model))", file: file, line: line)
        let sent = HarnessSendPath.send(model)
        XCTAssertFalse(sent.messages.contains { $0.text.contains("\u{FFFC}") }, "the SENT text carries U+FFFC", file: file, line: line)
    }

    func testAnRTFDImagePastedIntoAParagraphIsNotABareAttachment() {
        let model = self.paste([["com.apple.flat-rtfd": Self.rtfd(withImage: true)]], into: HarnessContent.plainText("First paragraph."), at: NSRange(location: 6, length: 0))
        self.assertNoBareAttachment(model)
    }

    func testAnRTFDImagePastedIntoATableCellIsNotABareAttachment() {
        func cell(_ text: String) -> ChatInputTableCell { ChatInputTableCell(runs: [ChatInputRun(text: text)]) }
        let table = ChatInputContent(blocks: [
            HarnessEngine.paragraph("Table below:"),
            .table(ChatInputTable(columns: [ChatInputColumnSpec(width: 0.0), ChatInputColumnSpec(width: 0.0)], rows: [ChatInputTableRow(cells: [cell("alpha"), cell("1")])])),
            HarnessEngine.paragraph("After."),
        ])
        let model = self.paste([["com.apple.flat-rtfd": Self.rtfd(withImage: true)]], into: table, at: NSRange(location: 15, length: 0))
        self.assertNoBareAttachment(model)
    }

    func testAnHTMLImagePastedIntoAParagraphIsNotABareAttachment() {
        let model = self.paste([["public.html": Self.htmlWithImage.data(using: .utf8)!]], into: HarnessContent.plainText("First paragraph."), at: NSRange(location: 6, length: 0), settle: 2.0)
        self.assertNoBareAttachment(model)
    }

    /// Control: the same RTFD without the image pastes cleanly.
    func testControlAnRTFDWithoutAnImagePastesItsText() {
        let model = self.paste([["com.apple.flat-rtfd": Self.rtfd(withImage: false)]], into: HarnessContent.plainText("First paragraph."), at: NSRange(location: 6, length: 0))
        XCTAssertEqual(model.plainText, "First before  after paragraph.")
        XCTAssertTrue(FuzzModel.bareAttachments(model).isEmpty)
    }
}
