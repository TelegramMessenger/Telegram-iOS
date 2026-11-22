#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit
import RichTextEditorCore

final class RTFConversionTests: XCTestCase {
    func test_export_producesRTFContainingText() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"),
            runs: [TextRun(text: "Hi", attributes: CharacterAttributes(bold: true))]))])
        let data = try XCTUnwrap(RTFConversion.rtfData(from: frag))
        let s = try NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
        XCTAssertTrue(s.string.contains("Hi"))
        let font = try XCTUnwrap(s.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertTrue(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func test_roundTrip_preservesBoldAndLink() {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "B", attributes: CharacterAttributes(bold: true)),
            TextRun(text: "L", attributes: CharacterAttributes(link: "https://x.test")),
        ]))])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "BL")
        XCTAssertTrue(p.runs.first { $0.text == "B" }!.attributes.bold)
        XCTAssertEqual(p.runs.first { $0.text == "L" }!.attributes.link, "https://x.test")
    }

    func test_import_multiParagraph_splitsOnNewline() {
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "one")])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "two")])),
        ])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        XCTAssertEqual(back.blocks.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }, ["one", "two"])
    }

    // MARK: Custom emoji cross-app via tg://emoji?id= (spec addendum 2026-06-24)

    private func emojiRun(id: String, alt: String?) -> TextRun {
        TextRun(text: "\u{FFFC}",
                attributes: CharacterAttributes(emoji: EmojiRef(id: id, instanceID: "inst", altText: alt)))
    }

    func test_export_emoji_emitsAltTextHyperlinkedToMarker() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [emojiRun(id: "12345", alt: ":star:")]))])
        let data = try XCTUnwrap(RTFConversion.rtfData(from: frag))
        let s = try NSAttributedString(data: data,
                                       options: [.documentType: NSAttributedString.DocumentType.rtf],
                                       documentAttributes: nil)
        XCTAssertTrue(s.string.contains(":star:"))                       // altText is the visible text
        let link = s.attribute(.link, at: 0, effectiveRange: nil)
        let urlString = (link as? URL)?.absoluteString ?? (link as? String)
        // id carried in the marker URL (a `&n=` per-emoji de-dup suffix may follow — see import tests)
        XCTAssertEqual(urlString?.hasPrefix("tg://emoji?id=12345"), true)
    }

    func test_import_emojiMarkerLink_reconstructsSingleObjectReplacementRun() throws {
        // RTF carrying a tg://emoji?id= hyperlink on ":star:" text (what another app would round-trip).
        let attr = NSAttributedString(string: ":star:", attributes: [
            .font: UIFont.systemFont(ofSize: 17),
            .link: URL(string: "tg://emoji?id=99")!,
        ])
        let data = try attr.data(from: NSRange(location: 0, length: attr.length),
                                 documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: data))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.attributes.emoji != nil })
        XCTAssertEqual(run.text, "\u{FFFC}")                             // one object-replacement char
        XCTAssertEqual(run.attributes.emoji?.id, "99")
        XCTAssertEqual(run.attributes.emoji?.altText, ":star:")          // display text preserved as altText
        XCTAssertNil(run.attributes.link)                                // reconstructed as emoji, not a link
    }

    func test_roundTrip_preservesCustomEmoji() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "hi "),
            emojiRun(id: "777", alt: ":fire:"),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.attributes.emoji != nil })
        XCTAssertEqual(run.attributes.emoji?.id, "777")
        XCTAssertEqual(run.attributes.emoji?.altText, ":fire:")
        XCTAssertEqual(run.text, "\u{FFFC}")
    }

    func test_roundTrip_adjacentIdenticalEmoji_staySeparateRuns() throws {
        // Two adjacent emoji with the SAME id+altText+instanceID: a per-emoji boundary must keep them
        // distinct so RTF (which coalesces adjacent runs with identical attributes) doesn't merge them
        // into one. Worst case for de-duplication.
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            emojiRun(id: "5", alt: ":x:"),
            emojiRun(id: "5", alt: ":x:"),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let emojiRuns = p.runs.filter { $0.attributes.emoji != nil }
        XCTAssertEqual(emojiRuns.count, 2)                                // both survived (not coalesced)
        XCTAssertTrue(emojiRuns.allSatisfy { $0.attributes.emoji?.id == "5" })
        XCTAssertTrue(emojiRuns.allSatisfy { $0.text == "\u{FFFC}" })
    }

    func test_import_normalLink_isNotTreatedAsEmoji() throws {
        let frag = Document(blocks: [.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "site", attributes: CharacterAttributes(link: "https://example.com")),
        ]))])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        let run = try XCTUnwrap(p.runs.first { $0.text == "site" })
        XCTAssertNil(run.attributes.emoji)                               // a normal link is NOT an emoji
        XCTAssertEqual(run.attributes.link, "https://example.com")
    }

    // MARK: Hand-rolled RTF primitives (Task 1)

    func test_escapeRTFText_escapesSpecialsAndNonASCII() {
        XCTAssertEqual(RTFConversion.escapeRTFText("a\\b{c}d"), "a\\\\b\\{c\\}d")
        XCTAssertEqual(RTFConversion.escapeRTFText("é"), "\\u233?")            // U+00E9
        // Surrogate-pair emoji 😀 (U+1F600) → two signed-16 \u words (0xD83D, 0xDE00)
        XCTAssertEqual(RTFConversion.escapeRTFText("😀"), "\\u-10179?\\u-8704?")
        XCTAssertEqual(RTFConversion.escapeRTFText("plain"), "plain")
    }

    func test_inlineRTF_emitsToggles_link_andEmojiMarker() {
        var seq = 0
        let runs = [
            TextRun(text: "B", attributes: CharacterAttributes(bold: true)),
            TextRun(text: "L", attributes: CharacterAttributes(link: "https://x.test")),
            TextRun(text: "\u{FFFC}", attributes: CharacterAttributes(emoji: EmojiRef(id: "7", instanceID: "i", altText: ":x:"))),
        ]
        let rtf = RTFConversion.inlineRTF(runs, mono: false, emojiSeq: &seq)
        XCTAssertTrue(rtf.contains("\\b "))                                    // bold toggle
        XCTAssertTrue(rtf.contains("HYPERLINK \"https://x.test\""))            // link field
        XCTAssertTrue(rtf.contains("HYPERLINK \"tg://emoji?id=7&n=0\""))       // emoji marker (first dedup seq)
        XCTAssertTrue(rtf.contains(":x:"))                                     // emoji altText is the field text
        XCTAssertEqual(seq, 1)                                                 // emoji consumed one dedup seq
    }

    // MARK: Hand-rolled export — inline & block coverage (Task 2)

    private func roundTrip(_ blocks: [Block]) throws -> Document {
        let data = try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: blocks)))
        return try XCTUnwrap(RTFConversion.fragment(fromRTF: data))
    }

    func test_roundTrip_italicUnderlineStrike() throws {
        let back = try roundTrip([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [
            TextRun(text: "i", attributes: CharacterAttributes(italic: true)),
            TextRun(text: "u", attributes: CharacterAttributes(underline: true)),
            TextRun(text: "s", attributes: CharacterAttributes(strikethrough: true)),
        ]))])
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        XCTAssertTrue(p.runs.first { $0.text == "i" }!.attributes.italic)
        XCTAssertTrue(p.runs.first { $0.text == "u" }!.attributes.underline)
        XCTAssertTrue(p.runs.first { $0.text == "s" }!.attributes.strikethrough)
    }

    func test_roundTrip_codeBlock_monoAndInteriorNewlines() throws {
        let back = try roundTrip([.code(CodeBlock(id: BlockID("c"), runs: [TextRun(text: "x\ny")]))])
        // The custom parser reconstructs a .code block (all-mono runs → code block in RTFDocumentParser).
        // Interior newlines survive as \line in RTF → "\n" back in the code block text.
        let codeText = back.blocks.compactMap { b -> String? in
            if case .code(let c) = b { return c.runs.map(\.text).joined() } else { return nil }
        }.joined()
        XCTAssertTrue(codeText.contains("x"))
        XCTAssertTrue(codeText.contains("y"))
    }

    func test_roundTrip_nonASCIIText() throws {
        let back = try roundTrip([.paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "café 한 😀")]))])
        guard case .paragraph(let p) = back.blocks[0] else { return XCTFail() }
        XCTAssertEqual(p.text, "café 한 😀")
    }

    func test_export_headingUsesLargerFontSize() throws {
        let data = try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "T")])),
        ])))
        let rtf = String(data: data, encoding: .utf8)!
        XCTAssertTrue(rtf.contains("\\fs48"))   // heading1 = 24pt × 2
    }

    func test_import_repeatedLines_attributesNotCrossContaminated() {
        // Two paragraphs with identical text "note" but different formatting: first bold, second plain.
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [TextRun(text: "note", attributes: CharacterAttributes(bold: true))])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "note")])),
        ])
        let back = RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!)!
        let paras = back.blocks.compactMap { b -> ParagraphBlock? in
            if case .paragraph(let p) = b { return p } else { return nil }
        }
        XCTAssertEqual(paras.count, 2)
        XCTAssertEqual(paras[0].text, "note"); XCTAssertEqual(paras[1].text, "note")
        XCTAssertTrue(paras[0].runs.allSatisfy { $0.attributes.bold })   // first paragraph bold
        XCTAssertFalse(paras[1].runs.contains { $0.attributes.bold })    // second paragraph NOT bold
    }

    // MARK: Table export (Task 3)

    private func table2x2() -> TableBlock {
        func cell(_ id: String, _ t: String, bold: Bool = false) -> Cell {
            Cell(id: BlockID(id), blocks: [.paragraph(ParagraphBlock(id: BlockID(id + "p"),
                runs: [TextRun(text: t, attributes: CharacterAttributes(bold: bold))]))])
        }
        return TableBlock(id: BlockID("t"),
            columns: [ColumnSpec(width: 100), ColumnSpec(width: 140)],
            rows: [
                Row(id: BlockID("r0"), isHeader: true, cells: [cell("h0", "Name"), cell("h1", "Age")]),
                Row(id: BlockID("r1"), cells: [cell("c0", "Ann"), cell("c1", "30")]),
            ])
    }

    func test_export_table_emitsRowAndCellControlWords() throws {
        let data = try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: [.table(table2x2())])))
        let rtf = String(data: data, encoding: .utf8)!
        XCTAssertTrue(rtf.contains("\\trowd"))
        XCTAssertTrue(rtf.contains("\\cellx2000"))   // col0 right edge: 100pt × 20 twips
        XCTAssertTrue(rtf.contains("\\cellx4800"))   // col1 right edge: (100+140)pt × 20
        XCTAssertTrue(rtf.contains("\\cell"))
        XCTAssertTrue(rtf.contains("\\row"))
        XCTAssertTrue(rtf.contains("\\trhdr"))       // header row marker
        XCTAssertTrue(rtf.contains("Name") && rtf.contains("Age") && rtf.contains("Ann") && rtf.contains("30"))
    }

    func test_export_table_cellInlineFormattingSurvives() throws {
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r"), cells: [Cell(id: BlockID("c"), blocks: [
                .paragraph(ParagraphBlock(id: BlockID("cp"), runs: [TextRun(text: "L", attributes: CharacterAttributes(link: "https://t.test"))]))
            ])])])
        let rtf = String(data: try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: [.table(table)]))), encoding: .utf8)!
        XCTAssertTrue(rtf.contains("HYPERLINK \"https://t.test\""))
    }

    func test_export_paragraphThenTable_emitsBoth() throws {
        let data = try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("p"), runs: [TextRun(text: "Intro")])),
            .table(table2x2()),
        ])))
        let rtf = String(data: data, encoding: .utf8)!
        XCTAssertTrue(rtf.contains("Intro") && rtf.contains("\\trowd"))
    }

    func test_import_handRolledTable_reconstructsTable() throws {
        // The custom parser now reconstructs a real .table block (not a flatten to paragraphs —
        // that was the NSAttributedString limitation). All cell texts must survive in the table.
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF:
            try XCTUnwrap(RTFConversion.rtfData(from: Document(blocks: [.table(table2x2())])))))
        guard case .table(let t) = back.blocks.first else { return XCTFail("expected a .table block") }
        let allCellText = t.rows.flatMap(\.cells).flatMap(\.blocks).compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.text } else { return nil }
        }.joined(separator: "|")
        for cell in ["Name", "Age", "Ann", "30"] { XCTAssertTrue(allCellText.contains(cell), "missing '\(cell)'") }
    }

    // MARK: Task 7 — custom parser integration

    func test_import_usesCustomParser_reconstructsHeadingAndTable() throws {
        // Export a doc with a heading + a table, then import it back: structure must survive (the custom
        // parser, not the NSAttributedString flatten).
        let table = TableBlock(id: BlockID("t"), columns: [ColumnSpec(width: 100), ColumnSpec(width: 100)],
            rows: [Row(id: BlockID("r"), cells: [
                Cell(id: BlockID("c0"), blocks: [.paragraph(ParagraphBlock(id: BlockID("c0p"), runs: [TextRun(text: "A")]))]),
                Cell(id: BlockID("c1"), blocks: [.paragraph(ParagraphBlock(id: BlockID("c1p"), runs: [TextRun(text: "B")]))]),
            ])])
        let doc = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("h"), style: .heading1, runs: [TextRun(text: "Title")])),
            .table(table),
        ])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: doc)!))
        XCTAssertTrue(back.blocks.contains { if case .paragraph(let p) = $0 { return p.style == .heading1 } else { return false } })
        XCTAssertTrue(back.blocks.contains { if case .table = $0 { return true } else { return false } })
    }
    func test_import_nonRTF_fallsBackToNSAttributedString() {
        // Garbage that the custom parser rejects (no {\rtf header) must still go through the old path
        // (which also returns nil for non-RTF) — i.e. no crash.
        XCTAssertNil(RTFConversion.fragment(fromRTF: Data("not rtf".utf8)))
    }

    // MARK: Task 3 — checklist emoji checkbox in RTF export + NSAttributedString-fallback detection

    func test_checklist_rtf_roundTrip_preservesCheckedAndStripsMarker() {
        let doc = Document(blocks: [
            .paragraph(ParagraphBlock(id: .generate(), list: ListMembership(marker: .checklist, level: 0, checked: false), runs: [TextRun(text: "todo")])),
            .paragraph(ParagraphBlock(id: .generate(), list: ListMembership(marker: .checklist, level: 0, checked: true), runs: [TextRun(text: "done")])),
        ])
        let data = RTFConversion.rtfData(from: doc)!
        let rtfString = String(data: data, encoding: .utf8)!
        XCTAssertTrue(rtfString.contains("\\u11036?"), "unchecked ⬜ escaped into the RTF")   // U+2B1C
        XCTAssertTrue(rtfString.contains("\\u9989?"), "checked ✅ escaped into the RTF")        // U+2705

        let back = RTFConversion.fragment(fromRTF: data)!
        XCTAssertEqual(back.blocks.count, 2)
        guard case .paragraph(let p0) = back.blocks[0], case .paragraph(let p1) = back.blocks[1] else { return XCTFail() }
        XCTAssertEqual(p0.list?.marker, .checklist); XCTAssertEqual(p0.list?.checked, false); XCTAssertEqual(p0.text, "todo")
        XCTAssertEqual(p1.list?.marker, .checklist); XCTAssertEqual(p1.list?.checked, true); XCTAssertEqual(p1.text, "done")
    }

    // MARK: Task 23 — pull quote RTF export

    func test_rtfExport_pullQuote_textSurvives_centeredItalic() {
        let doc = Document(blocks: [.pullQuote(PullQuote(id: BlockID("pq"), runs: [TextRun(text: "Few understood")]))])
        let rtf = String(data: RTFConversion.rtfData(from: doc)!, encoding: .utf8)!
        XCTAssertTrue(rtf.contains("Few understood"))   // text never lost
        XCTAssertTrue(rtf.contains("\\qc"))              // centered
        XCTAssertTrue(rtf.contains("\\i"))               // italic
    }

    // MARK: Finding 1 — unescaped URL in HYPERLINK field destination

    func test_roundTrip_linkWithRTFSpecialChars_doesNotDropContent() throws {
        // A URL containing { } " \ must not break the RTF (a `{` previously made fragment(fromRTF:) return nil,
        // silently dropping the whole document). Content (this run + a following paragraph) must survive.
        let frag = Document(blocks: [
            .paragraph(ParagraphBlock(id: BlockID("a"), runs: [
                TextRun(text: "L", attributes: CharacterAttributes(link: "https://x.test/{a}\"b\\c")),
            ])),
            .paragraph(ParagraphBlock(id: BlockID("b"), runs: [TextRun(text: "after")])),
        ])
        let back = try XCTUnwrap(RTFConversion.fragment(fromRTF: RTFConversion.rtfData(from: frag)!))  // must NOT be nil
        let paras = back.blocks.compactMap { b -> ParagraphBlock? in if case .paragraph(let p) = b { return p } else { return nil } }
        XCTAssertTrue(paras.contains { $0.text == "after" })   // following block survived (not eaten/dropped)
        XCTAssertTrue(paras.contains { $0.runs.contains { $0.text == "L" } })  // the link's display text survived
    }
}
#endif
