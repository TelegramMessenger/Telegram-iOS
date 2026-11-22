import XCTest
@testable import RichTextEditorCore

final class ChecklistEmojiMarkerTests: XCTestCase {
    func test_prefix_exactStrings() {
        XCTAssertEqual(ChecklistEmojiMarker.prefix(checked: false), "⬜ ")
        XCTAssertEqual(ChecklistEmojiMarker.prefix(checked: true), "✅ ")
    }

    func test_stripping_basic() {
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("⬜ buy milk")?.checked, false)
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("⬜ buy milk")?.remainder, "buy milk")
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("✅ done")?.checked, true)
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("✅ done")?.remainder, "done")
    }

    func test_stripping_vs16_andNoSpace_andBareEmoji() {
        // VS16 (U+FE0F) combines into the emoji grapheme — still detected, whole grapheme dropped.
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("✅\u{FE0F} x")?.remainder, "x")
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("⬜x")?.remainder, "x")        // no space
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("✅")?.remainder, "")           // bare (listtext)
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("✅")?.checked, true)
    }

    func test_stripping_stripsExactlyOne_andNonMatchIsNil() {
        // content that itself starts with the other emoji: only the leading marker is stripped
        XCTAssertEqual(ChecklistEmojiMarker.strippingMarker("⬜ ✅ text")?.remainder, "✅ text")
        XCTAssertNil(ChecklistEmojiMarker.strippingMarker("plain text"))
        XCTAssertNil(ChecklistEmojiMarker.strippingMarker("[ ] markdown"))   // markdown NOT detected
        XCTAssertNil(ChecklistEmojiMarker.strippingMarker("☐ ballot"))       // text ballot box NOT detected
        XCTAssertNil(ChecklistEmojiMarker.strippingMarker(""))
    }

    func test_externalChecklistPlainText_prefixesOnlyChecklistParagraphs() {
        let blocks: [Block] = [
            .paragraph(ParagraphBlock(id: .generate(), list: ListMembership(marker: .checklist, level: 0, checked: false), runs: [TextRun(text: "todo")])),
            .paragraph(ParagraphBlock(id: .generate(), list: ListMembership(marker: .checklist, level: 0, checked: true), runs: [TextRun(text: "done")])),
            .paragraph(ParagraphBlock(id: .generate(), runs: [TextRun(text: "plain")])),
            .paragraph(ParagraphBlock(id: .generate(), list: ListMembership(marker: .bullet, level: 0), runs: [TextRun(text: "bullet")])),
        ]
        XCTAssertEqual(externalChecklistPlainText(blocks), "⬜ todo\n✅ done\nplain\nbullet")
    }
}
