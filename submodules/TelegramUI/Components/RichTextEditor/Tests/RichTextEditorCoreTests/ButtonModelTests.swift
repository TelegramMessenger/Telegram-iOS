import XCTest
@testable import RichTextEditorCore

final class ButtonModelTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    func testButtonRefRoundTripsThroughJSON() throws {
        let button = ButtonRef(
            label: [TextRun(text: "Open site", attributes: CharacterAttributes(bold: true))],
            action: .url("https://telegram.org"),
            color: .danger,
            isLink: true
        )
        XCTAssertEqual(try roundTrip(button), button)
    }

    func testUnsupportedActionRoundTripsVerbatim() throws {
        let button = ButtonRef(label: [TextRun(text: "Pay")], action: .unsupported(kind: "payment", payload: "AAEC"), color: nil, isLink: false)
        XCTAssertEqual(try roundTrip(button), button)
    }

    func testButtonRowBlockRoundTripsThroughBlock() throws {
        let row = ButtonRowBlock(
            id: BlockID.generate(),
            buttons: [ButtonRef(label: [TextRun(text: "A")], action: .url("https://a.example"), color: .primary, isLink: false),
                      ButtonRef(label: [TextRun(text: "B")], action: .disabled, color: nil, isLink: false)],
            alignment: .center
        )
        let block = Block.buttonRow(row)
        XCTAssertEqual(try roundTrip(block), block)
        XCTAssertEqual(block.id, row.id)
    }

    // The raw values are persisted and must equal the TelegramCore enums they mirror.
    func testRawValuesArePinned() {
        XCTAssertEqual(ButtonColor.primary.rawValue, 0)
        XCTAssertEqual(ButtonColor.danger.rawValue, 1)
        XCTAssertEqual(ButtonColor.success.rawValue, 2)
        XCTAssertEqual(ButtonRowAlignment.justify.rawValue, 0)
        XCTAssertEqual(ButtonRowAlignment.left.rawValue, 1)
        XCTAssertEqual(ButtonRowAlignment.center.rawValue, 2)
        XCTAssertEqual(ButtonRowAlignment.right.rawValue, 3)
    }

    // A document written before this field existed must still decode (the lenient-decoder invariant).
    func testCharacterAttributesDecodeWithoutButtonKey() throws {
        let json = Data(#"{"bold":true}"#.utf8)
        let decoded = try JSONDecoder().decode(CharacterAttributes.self, from: json)
        XCTAssertTrue(decoded.bold)
        XCTAssertNil(decoded.button)
    }

    // A button row contributes n atom positions plus the 2 container tokens.
    func testButtonRowPositionSize() {
        let row = ButtonRowBlock(
            id: BlockID.generate(),
            buttons: [ButtonRef(label: [TextRun(text: "A")], action: .disabled, color: nil, isLink: false),
                      ButtonRef(label: [TextRun(text: "B")], action: .disabled, color: nil, isLink: false),
                      ButtonRef(label: [TextRun(text: "C")], action: .disabled, color: nil, isLink: false)],
            alignment: .justify
        )
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.buttonRow(row)])), 5)
    }

    // An empty row still needs one caret target, or it cannot be selected or deleted.
    func testEmptyButtonRowStillHasOneAtom() {
        let row = ButtonRowBlock(id: BlockID.generate(), buttons: [], alignment: .justify)
        XCTAssertEqual(DocumentTree.documentSize(Document(blocks: [.buttonRow(row)])), 3)
    }

    // MARK: - Pasting an un-editable action

    private func unsupported() -> ButtonAction { .unsupported(kind: "replyMarkupButtonAction", payload: "AAEC") }

    /// A pasted opaque action is downgraded to `.disabled`: it belongs to the message it arrived in and
    /// can never work elsewhere, and the editor can neither show nor edit it.
    func testPastedUnsupportedActionBecomesDisabled() {
        let row = ButtonRowBlock(id: BlockID.generate(),
                                 buttons: [ButtonRef(label: [TextRun(text: "Cb")], action: unsupported()),
                                           ButtonRef(label: [TextRun(text: "Go")], action: .url("https://telegram.org"))],
                                 alignment: .justify)
        guard case let .buttonRow(converted) = Document(blocks: [.buttonRow(row)])
            .convertingUnsupportedButtonActions().blocks.first else {
            return XCTFail("expected a button row")
        }
        XCTAssertEqual(converted.buttons[0].action, .disabled)
        XCTAssertEqual(converted.buttons[1].action, .url("https://telegram.org"), "a URL action is untouched")
    }

    /// Inline pills convert too, and everything else about the button survives.
    func testPastedInlineUnsupportedActionBecomesDisabled() {
        var attributes = CharacterAttributes.plain
        attributes.button = ButtonRef(label: [TextRun(text: "Cb")], action: unsupported(), color: .danger, isLink: true)
        let document = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID.generate(), style: .body, runs: [
            TextRun(text: "\u{FFFC}", attributes: attributes),
        ]))])
        guard case let .paragraph(p) = document.convertingUnsupportedButtonActions().blocks.first,
              let button = p.runs.first?.attributes.button else {
            return XCTFail("expected an inline button")
        }
        XCTAssertEqual(button.action, .disabled)
        XCTAssertEqual(button.labelText, "Cb", "the label survives")
        XCTAssertEqual(button.color, .danger, "the style survives")
        XCTAssertTrue(button.isLink)
    }

    /// `.copyText` is self-contained text that still works anywhere, so it is deliberately NOT converted.
    func testPastedCopyTextActionIsPreserved() {
        let row = ButtonRowBlock(id: BlockID.generate(),
                                 buttons: [ButtonRef(label: [TextRun(text: "Copy")], action: .copyText("hello"))],
                                 alignment: .justify)
        guard case let .buttonRow(converted) = Document(blocks: [.buttonRow(row)])
            .convertingUnsupportedButtonActions().blocks.first else {
            return XCTFail("expected a button row")
        }
        XCTAssertEqual(converted.buttons[0].action, .copyText("hello"))
    }

    /// The conversion recurses containers — a row nested in a details body is reached too.
    func testConversionRecursesContainers() {
        let row = ButtonRowBlock(id: BlockID.generate(),
                                 buttons: [ButtonRef(label: [TextRun(text: "Cb")], action: unsupported())],
                                 alignment: .justify)
        let details = DetailsBlock(id: BlockID.generate(), title: [], children: [.buttonRow(row)], expanded: true)
        guard case let .details(converted) = Document(blocks: [.details(details)])
            .convertingUnsupportedButtonActions().blocks.first,
              case let .buttonRow(inner) = converted.children.first else {
            return XCTFail("expected a nested button row")
        }
        XCTAssertEqual(inner.buttons[0].action, .disabled)
    }

    // MARK: - Table borders

    /// A document written before `bordered` existed must decode as TRUE: such a table always drew its
    /// grid, and both forward converters hard-coded `bordered: true`.
    func testTableWithoutBorderedKeyDecodesAsBordered() throws {
        let json = Data(#"{"id":"t","columns":[],"rows":[]}"#.utf8)
        XCTAssertTrue(try JSONDecoder().decode(TableBlock.self, from: json).bordered)
    }

    /// REGRESSION: `regeneratingIDs` rebuilt a pasted table field-by-field and forwarded neither the
    /// table's `compact`/`bordered` nor each cell's `colspan`/`rowspan`, so copying an unbordered table
    /// with merged cells pasted back a bordered one with the merges split apart. Only IDENTITIES are
    /// meant to be regenerated.
    func testPastedTablePreservesItsAttributes() {
        let cell = Cell(id: BlockID("c"), blocks: [], colspan: 2, rowspan: 3)
        let table = TableBlock(id: BlockID("t"),
                               columns: [ColumnSpec(width: 10)],
                               rows: [Row(id: BlockID("r"), height: nil, cells: [cell])],
                               compact: true, bordered: false)
        let pasted = Document(blocks: [.table(table)]).regeneratingTopLevelIDs()
        guard case let .table(out) = pasted.blocks.first else {
            return XCTFail("expected a table")
        }
        XCTAssertFalse(out.bordered, "bordered must survive a paste")
        XCTAssertTrue(out.compact, "compact must survive a paste")
        XCTAssertEqual(out.rows[0].cells[0].colspan, 2, "colspan must survive a paste")
        XCTAssertEqual(out.rows[0].cells[0].rowspan, 3, "rowspan must survive a paste")
        XCTAssertNotEqual(out.id, table.id, "the identity IS regenerated")
    }
}

