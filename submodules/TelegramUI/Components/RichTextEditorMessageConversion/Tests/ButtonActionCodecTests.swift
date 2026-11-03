import XCTest
import Postbox
import TelegramCore
import RichTextEditorCore
@testable import RichTextEditorMessageConversion

final class ButtonActionCodecTests: XCTestCase {
    private func assertRoundTrips(_ action: ReplyMarkupButtonAction, file: StaticString = #filePath, line: UInt = #line) {
        let core = buttonAction(from: action)
        XCTAssertEqual(replyMarkupButtonAction(from: core), action, file: file, line: line)
    }

    func testNamedActionsRoundTrip() {
        assertRoundTrips(.url("https://telegram.org"))
        assertRoundTrips(.copyText(payload: "hello"))
        assertRoundTrips(.disabled)
    }

    func testNamedActionsUseNamedCases() {
        XCTAssertEqual(buttonAction(from: .url("https://telegram.org")), .url("https://telegram.org"))
        XCTAssertEqual(buttonAction(from: .copyText(payload: "hi")), .copyText("hi"))
        XCTAssertEqual(buttonAction(from: .disabled), .disabled)
    }

    /// Every action Core cannot name must survive verbatim through the opaque blob.
    func testUnsupportedActionsRoundTripVerbatim() {
        assertRoundTrips(.callback(requiresPassword: true, data: MemoryBuffer(data: Data([0x01, 0x02, 0xff]))))
        assertRoundTrips(.urlAuth(url: "https://telegram.org", buttonId: 7))
        assertRoundTrips(.openWebView(url: "https://telegram.org/app", simple: true))
        assertRoundTrips(.switchInline(samePeer: true, query: "q", peerTypes: [.users, .bots]))
        assertRoundTrips(.openWebApp)
        assertRoundTrips(.payment)
    }

    func testUnsupportedActionIsOpaqueToCore() {
        guard case let .unsupported(kind, payload) = buttonAction(from: .payment) else {
            return XCTFail("expected .unsupported")
        }
        XCTAssertFalse(kind.isEmpty)
        XCTAssertFalse(payload.isEmpty)
    }

    /// A blob written by a future build with an unknown `kind`, or a corrupt payload, must degrade
    /// rather than crash — a Document can arrive from a newer build via .rtdoc or the clipboard.
    func testUnknownBlobDegradesToDisabled() {
        XCTAssertEqual(replyMarkupButtonAction(from: .unsupported(kind: "notARealKind", payload: "%%%")), .disabled)
        XCTAssertEqual(replyMarkupButtonAction(from: .unsupported(kind: "notARealKind", payload: "")), .disabled)
    }

    func testColorAndAlignmentMapBothWays() {
        XCTAssertEqual(buttonColor(from: .danger), .danger)
        XCTAssertNil(buttonColor(from: nil))
        XCTAssertEqual(replyMarkupColor(from: .success), .success)
        XCTAssertNil(replyMarkupColor(from: nil))
        XCTAssertEqual(buttonRowAlignment(from: .center), .center)
        XCTAssertEqual(instantPageRowAlignment(from: .justify), .justify)
    }

    /// The raw values are persisted on both sides and must stay in lockstep.
    func testColorAndAlignmentRawValuesAgreeAcrossTheSeam() {
        XCTAssertEqual(ButtonColor.primary.rawValue, ReplyMarkupButton.Style.Color.primary.rawValue)
        XCTAssertEqual(ButtonColor.danger.rawValue, ReplyMarkupButton.Style.Color.danger.rawValue)
        XCTAssertEqual(ButtonColor.success.rawValue, ReplyMarkupButton.Style.Color.success.rawValue)
        XCTAssertEqual(ButtonRowAlignment.justify.rawValue, InstantPageButtonRowAlignment.justify.rawValue)
        XCTAssertEqual(ButtonRowAlignment.left.rawValue, InstantPageButtonRowAlignment.left.rawValue)
        XCTAssertEqual(ButtonRowAlignment.center.rawValue, InstantPageButtonRowAlignment.center.rawValue)
        XCTAssertEqual(ButtonRowAlignment.right.rawValue, InstantPageButtonRowAlignment.right.rawValue)
    }

    func testChatInputButtonRoundTripsThroughButtonRef() {
        let original = ChatInputButton(
            label: [ChatInputRun(text: "Open")],
            action: .callback(requiresPassword: false, data: MemoryBuffer(data: Data([9]))),
            color: .danger,
            isLink: true
        )
        XCTAssertEqual(chatInputButton(fromButtonRef: buttonRef(fromChatInputButton: original)), original)
    }

    /// Inline formatting on a label survives; a `.url` entity becomes the run's `link`.
    func testLabelFormattingRoundTrips() {
        let original = ChatInputButton(
            label: [
                ChatInputRun(text: "bold", attributes: ChatInputInlineAttributes(bold: true)),
                ChatInputRun(text: "link", attributes: {
                    var a = ChatInputInlineAttributes()
                    a.entity = .url("https://telegram.org")
                    return a
                }()),
            ],
            action: .url("https://telegram.org")
        )
        XCTAssertEqual(chatInputButton(fromButtonRef: buttonRef(fromChatInputButton: original)), original)
    }
}

/// The article-editor send path (`composeRichMessage`). A button has no message-entity form, so its
/// presence must force the rich InstantPage path — otherwise the message is sent as plain text +
/// entities and the buttons are destroyed on the way out.
final class ButtonSendPathTests: XCTestCase {
    private func paragraph(_ runs: [TextRun]) -> Block {
        .paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: runs))
    }

    private func inlineButtonRun(_ label: String) -> TextRun {
        var attributes = CharacterAttributes.plain
        attributes.button = ButtonRef(label: [TextRun(text: label)], action: .url("https://telegram.org"))
        return TextRun(text: "\u{FFFC}", attributes: attributes)
    }

    func testButtonRowForcesTheRichPath() {
        let row = ButtonRowBlock(id: BlockID.generate(),
                                 buttons: [ButtonRef(label: [TextRun(text: "Go")], action: .url("https://telegram.org"))],
                                 alignment: .justify)
        let document = Document(blocks: [paragraph([TextRun(text: "hi")]), .buttonRow(row)])
        guard case let .rich(page) = composeRichMessage(from: document) else {
            return XCTFail("a button row must force the rich path")
        }
        XCTAssertTrue(page.blocks.contains { if case .buttonRow = $0 { return true } else { return false } })
    }

    func testInlineButtonForcesTheRichPath() {
        let document = Document(blocks: [paragraph([TextRun(text: "tap "), inlineButtonRun("Go")])])
        guard case .rich = composeRichMessage(from: document) else {
            return XCTFail("an inline button must force the rich path")
        }
    }

    /// The pill must reach the page as a `RichText.textButton`. It is an if-let chain rather than an
    /// exhaustive switch, so a missing arm compiles and silently emits the bare U+FFFC placeholder.
    func testInlineButtonEmitsATextButtonNotAPlaceholder() {
        let document = Document(blocks: [paragraph([inlineButtonRun("Go")])])
        guard case let .rich(page) = composeRichMessage(from: document),
              case let .paragraph(text) = page.blocks.first else {
            return XCTFail("expected one rich paragraph block")
        }
        guard case let .textButton(button) = text else {
            return XCTFail("expected a RichText.textButton, got \(text)")
        }
        XCTAssertEqual(button.text.plainText, "Go")
        XCTAssertEqual(button.action, .url("https://telegram.org"))
    }

    func testEmittedRowCarriesAlignmentActionAndStyle() {
        let row = ButtonRowBlock(
            id: BlockID.generate(),
            buttons: [ButtonRef(label: [TextRun(text: "Open")], action: .url("https://telegram.org"), color: .success, isLink: true)],
            alignment: .center
        )
        guard case let .rich(page) = composeRichMessage(from: Document(blocks: [.buttonRow(row)])),
              case let .buttonRow(alignment, buttons) = page.blocks.first else {
            return XCTFail("expected one buttonRow block")
        }
        XCTAssertEqual(alignment, .center)
        XCTAssertEqual(buttons[0].action, .url("https://telegram.org"))
        XCTAssertEqual(buttons[0].color, .success)
        XCTAssertTrue(buttons[0].isLink)
    }

    /// A preserved non-URL action must reach the wire intact.
    func testPreservedActionReachesThePage() {
        let action = ReplyMarkupButtonAction.callback(requiresPassword: false, data: MemoryBuffer(data: Data([4, 2])))
        let row = ButtonRowBlock(id: BlockID.generate(),
                                 buttons: [ButtonRef(label: [TextRun(text: "Cb")], action: buttonAction(from: action))],
                                 alignment: .justify)
        guard case let .rich(page) = composeRichMessage(from: Document(blocks: [.buttonRow(row)])),
              case let .buttonRow(_, buttons) = page.blocks.first else {
            return XCTFail("expected one buttonRow block")
        }
        XCTAssertEqual(buttons[0].action, action)
    }

    /// Plain content must still take the entity path — the gate must not over-trigger.
    func testPlainContentStillTakesTheEntityPath() {
        guard case .plain = composeRichMessage(from: Document(blocks: [paragraph([TextRun(text: "just text")])])) else {
            return XCTFail("plain text must not be promoted to the rich path")
        }
    }
}

