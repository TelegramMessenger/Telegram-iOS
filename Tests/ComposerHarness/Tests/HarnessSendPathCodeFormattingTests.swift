import XCTest
import UIKit
import TelegramCore
import TextFormat
import AccountContext
import ChatInputTextNode
import RichTextEditorUIKit
@testable import ComposerHarnessLib
@testable import RichTextEngineEditor

/// **What broke (p20, 2026-09-30; CORRUPTS WHAT IS SENT):** the engine's Format menu applies every inline
/// format — Bold, Italic, Monospace, Strikethrough, Underline, Spoiler — and a link inside a CODE block's
/// body, the composer shows it, and the model (`currentInputContent`) carries it:
/// `[p "Intro"] [code "let "+[b]"value"+" = 1"]`. A message holding only paragraphs, quotes and code is
/// sent on the TEXT route, which serialises a code block as its plain text (`attributedString(from:)`'s
/// `.code` arm appends `code.text`, TextFormat `ChatInputContentConversion.swift`), so the message goes
/// out as `Pre` over `"let value = 1"` with no Bold, and the link the user set is simply not sent. The
/// same code block in a message that also holds a heading goes the RICH route (`.preformatted` carries
/// `RichText`) and keeps it (control), so one composer state sends two different messages.
///
/// **How it was seen:** the p20 send-path oracle (`HarnessSendPath`) — send the model as the chat does,
/// load the message back as message editing does, compare. Found on the stress documents, then reached
/// through the Format menu here.
///
/// **Decision (p20 fix wave): the platform cannot carry it, so the engine refuses it.** A Telegram `Pre`
/// / `Code` entity can contain no other entity (the Bot API's nesting rule), the shared decoder reads a
/// code region back as one plain run (`chatInputContent(from:)`), and the legacy composer's model holds
/// code plain. So the engine's inline commands skip a code body (`inlineFormatTargetRanges`), the menu
/// shows them disabled there (`inlineFormatsReachSelection`), and the bridge renders and reads a code body
/// plain (`EngineDocumentBridge.plainCodeRuns`), so a paste or a move of formatted text into code lands
/// plain. Each case checks all three: what is sent equals the model, the model carries no format in code,
/// and the composer does not SHOW one (the engine storage, which is what is drawn).
///
/// **Tier 1:** Format ▸ … is the panel's `performFormatAction`, the send conversion is pure.
@available(iOS 18.4, *)
final class HarnessSendPathCodeFormattingTests: XCTestCase {
    private var driver: EngineFuzzDriver!
    private var verifier: FuzzEngineVerifier?

    override func setUpWithError() throws {
        self.driver = try EngineFuzzDriver()
        self.verifier = FuzzEngineVerifier.nonFatal()
    }

    override func tearDown() {
        self.verifier?.restore()
        self.driver.root.linkPromptOverride = nil
        _ = self.driver.node.resignInputFirstResponder()
        self.driver = nil
    }

    /// `[p "Intro"] [code "let value = 1"]`; on the engine axis the code's (empty) language line is line
    /// 1, so `value` is 11..<16.
    private static let start = ChatInputContent(blocks: [
        HarnessEngine.paragraph("Intro"),
        .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let value = 1")])),
    ])
    private static let value = NSRange(location: 11, length: 5)

    private func formatInsideCode(_ format: FuzzFormat) -> ChatInputContent {
        self.driver.arrange(Self.start)
        XCTAssertEqual((self.driver.viewText() as NSString).substring(with: Self.value), "value", "precondition: the selection is the code's word")
        self.driver.setViewSelection(Self.value)
        self.driver.settle(0.1)
        self.driver.format(format)
        self.driver.settle(0.2)
        return self.driver.model()
    }

    private func assertSentAsComposed(_ model: ChatInputContent, file: StaticString = #filePath, line: UInt = #line) {
        let sent = HarnessSendPath.send(model)
        XCTAssertEqual(sent.route, .textEntities, "precondition: code and paragraphs go the text route", file: file, line: line)
        if let divergence = HarnessSendPath.divergence(model) {
            XCTFail("what is sent is not what the composer holds: \(divergence.description)", file: file, line: line)
        }
    }

    private func codeRuns(_ model: ChatInputContent) -> [ChatInputRun] {
        for block in model.blocks {
            if case let .code(code) = block {
                return FuzzModel.merged(code.runs)
            }
        }
        return []
    }

    /// The engine's own trait markers (`IDInlineTextStyleResolver.m`), which its trait pass derives a face from.
    private static let boldMarker = NSAttributedString.Key("IDInlineTextBold")
    private static let italicMarker = NSAttributedString.Key("IDInlineTextItalic")

    /// The code is ONE plain run in the model, and the engine draws `value` with no user format:
    /// no bold / italic marker, no spoiler, no link, the code face.
    private func assertCodeIsPlain(_ model: ChatInputContent, _ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let runs = self.codeRuns(model)
        XCTAssertEqual(runs.map(\.text), ["let value = 1"], "\(label): the code's runs: \(HarnessEdited.describe(model))", file: file, line: line)
        XCTAssertTrue(runs.allSatisfy { $0.attributes == ChatInputInlineAttributes() }, "\(label): the model carries a format inside code: \(HarnessEdited.describe(model))", file: file, line: line)
        for block in self.driver.editor.engine.attributedBlocks {
            let range = (block.string as NSString).range(of: "value")
            guard range.location != NSNotFound else { continue }
            let drawn = block.attributes(at: range.location, effectiveRange: nil)
            XCTAssertNil(drawn[Self.boldMarker], "\(label): the composer still marks the code bold", file: file, line: line)
            XCTAssertNil(drawn[Self.italicMarker], "\(label): the composer still marks the code italic", file: file, line: line)
            XCTAssertNil(drawn[.rtSpoiler], "\(label): the composer still hides the code behind a spoiler", file: file, line: line)
            XCTAssertNil(drawn[.link], "\(label): the composer still links the code", file: file, line: line)
            if let font = drawn[.font] as? UIFont {
                XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold), "\(label): the code is drawn bold: \(font)", file: file, line: line)
            }
        }
    }

    func testBoldInsideCodeIsRefusedSoWhatIsSentIsWhatIsShown() {
        self.driver.arrange(Self.start)
        self.driver.setViewSelection(Self.value)
        self.driver.settle(0.1)
        XCTAssertFalse(self.driver.node.canPerformFormatAction(.bold), "Format ▸ Bold is offered inside code")
        XCTAssertFalse(self.driver.node.canPerformFormatAction(.monospace), "Format ▸ Monospace is offered inside code")
        let model = self.formatInsideCode(.bold)
        self.assertCodeIsPlain(model, "bold")
        self.assertSentAsComposed(model)
    }

    func testItalicInsideCodeIsRefusedSoWhatIsSentIsWhatIsShown() {
        let model = self.formatInsideCode(.italic)
        self.assertCodeIsPlain(model, "italic")
        self.assertSentAsComposed(model)
    }

    func testSpoilerInsideCodeIsRefusedSoWhatIsSentIsWhatIsShown() {
        let model = self.formatInsideCode(.spoiler)
        self.assertCodeIsPlain(model, "spoiler")
        self.assertSentAsComposed(model)
    }

    func testLinkInsideCodeIsRefusedSoWhatIsSentIsWhatIsShown() {
        self.driver.arrange(Self.start)
        self.driver.setViewSelection(Self.value)
        self.driver.settle(0.1)
        self.driver.root.linkPromptOverride = { _, _ in "https://telegram.org" }
        self.driver.host.panel.formatAttributesLink(self.driver.host.panel)
        self.driver.settle(0.2)
        let model = self.driver.model()
        self.assertCodeIsPlain(model, "link")
        self.assertSentAsComposed(model)
    }

    /// Bold RTF pasted into code lands plain: the paste's bold marker is presentation there.
    func testFormattedTextPastedIntoCodeLandsPlain() {
        self.driver.arrange(Self.start)
        self.driver.setViewSelection(NSRange(location: 13, length: 0))
        self.driver.settle(0.1)
        let bold = NSAttributedString(string: "XY", attributes: [.font: UIFont.boldSystemFont(ofSize: 17), .underlineStyle: NSUnderlineStyle.single.rawValue])
        UIPasteboard.general.items = [["public.rtf": FuzzExternalPaste.rtf(bold)]]
        HarnessComposerFuzzTests.notePasteboardWritten()
        _ = self.driver.view.perform(#selector(UIResponderStandardEditActions.paste(_:)), with: nil)
        self.driver.settle(FuzzConfig.pasteSettle + 0.3)
        let model = self.driver.model()
        let runs = self.codeRuns(model)
        XCTAssertEqual(runs.map(\.text).joined(), "let vaXYlue = 1", "precondition: the paste landed in the code: \(HarnessEdited.describe(model))")
        XCTAssertTrue(runs.allSatisfy { $0.attributes == ChatInputInlineAttributes() }, "the pasted format is kept inside code: \(HarnessEdited.describe(model))")
        XCTAssertTrue(self.driver.engineVerifierViolations().isEmpty, "\(self.driver.engineVerifierViolations())")
        self.assertSentAsComposed(model)
    }

    /// Control: a selection reaching OUT of the code still formats the text outside it.
    func testControlBoldAcrossCodeAndParagraphFormatsTheParagraph() {
        self.driver.arrange(Self.start)
        self.driver.setViewSelection(NSRange(location: 0, length: 16))
        self.driver.settle(0.1)
        XCTAssertTrue(self.driver.node.canPerformFormatAction(.bold))
        self.driver.format(.bold)
        self.driver.settle(0.2)
        let model = self.driver.model()
        guard case let .paragraph(intro)? = model.blocks.first else {
            XCTFail("precondition: \(HarnessEdited.describe(model))")
            return
        }
        XCTAssertTrue(intro.runs.allSatisfy { $0.attributes.bold }, "the paragraph part was not bolded: \(HarnessEdited.describe(model))")
        XCTAssertTrue(self.codeRuns(model).allSatisfy { !$0.attributes.bold })
        self.assertSentAsComposed(model)
    }

    /// Control: the same Bold in a paragraph is sent (`Bold` entity) and comes back on edit.
    func testControlBoldInAParagraphIsSent() {
        self.driver.arrange(ChatInputContent(blocks: [HarnessEngine.paragraph("Intro"), HarnessEngine.paragraph("let value = 1")]))
        self.driver.setViewSelection(NSRange(location: 10, length: 5))
        self.driver.settle(0.1)
        self.driver.format(.bold)
        self.driver.settle(0.2)
        let model = self.driver.model()
        let sent = HarnessSendPath.send(model)
        XCTAssertTrue(sent.messages.first?.entities.contains { $0.type == .Bold && $0.range == 10 ..< 15 } == true, "the paragraph's Bold is sent: \(sent.messages.first.map { "\($0.entities)" } ?? "-")")
        XCTAssertNil(HarnessSendPath.divergence(model).map(\.description))
    }

    /// Control: the RICH route (the document also holds a heading) sends the code's formatting — so the same
    /// composer code block is sent two ways depending on what else is in the message.
    func testControlTheRichRouteSendsCodeFormatting() {
        var bold = ChatInputInlineAttributes()
        bold.bold = true
        let model = ChatInputContent(blocks: [
            .paragraph(ChatInputParagraph(style: .heading1, list: nil, runs: [ChatInputRun(text: "Title")])),
            .code(ChatInputCode(language: nil, runs: [ChatInputRun(text: "let "), ChatInputRun(text: "value", attributes: bold), ChatInputRun(text: " = 1")])),
        ])
        XCTAssertEqual(HarnessSendPath.send(model).route, .rich)
        XCTAssertNil(HarnessSendPath.divergence(model).map(\.description))
    }
}
