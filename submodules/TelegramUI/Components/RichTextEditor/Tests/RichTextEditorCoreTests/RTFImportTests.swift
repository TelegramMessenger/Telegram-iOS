import XCTest
@testable import RichTextEditorCore

final class RTFImportTests: XCTestCase {
    private func doc(_ s: String) -> Document? { RTFImport.document(fromRTF: Data(s.utf8)) }
    private func paras(_ d: Document?) -> [ParagraphBlock] {
        (d?.blocks ?? []).compactMap { if case .paragraph(let p) = $0 { return p } else { return nil } }
    }

    func test_notRTF_returnsNil() { XCTAssertNil(doc("plain text, no header")) }

    func test_twoParagraphs_withInlineFormatting() {
        let d = doc("{\\rtf1\\ansi {\\b bold} plain\\par second}")
        let p = paras(d)
        XCTAssertEqual(p.count, 2)
        XCTAssertTrue(p[0].runs.first { $0.text == "bold" }?.attributes.bold == true)
        XCTAssertTrue(p[0].runs.contains { $0.text.contains("plain") })
        XCTAssertEqual(p[1].runs.map(\.text).joined(), "second")
    }

    /// Cocoa/AppKit (TextEdit, Notes, Safari, Mail, Pages) serializes paragraph breaks as a backslash
    /// immediately followed by a literal newline (`a\<LF>b`), which the RTF spec defines as equivalent to
    /// `\par`. Real-world cross-app paste hits this form, NOT a literal `\par`. Regression repro for
    /// "pasting removes newlines" — all paragraphs were gluing into one.
    func test_backslashNewline_isParagraphBreak() {
        let d = doc("{\\rtf1\\ansi\\fs34 a\\\nb\\\nc}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["a", "b", "c"])
    }

    func test_backslashCRLF_isParagraphBreak() {
        let d = doc("{\\rtf1\\ansi\\fs34 a\\\r\nb}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["a", "b"])
    }

    /// A blank line (two paragraph breaks in a row, `a\<LF>\<LF>b` from Cocoa) must survive as an empty
    /// paragraph — an explicit `\par` terminates a paragraph even when empty. Previously the empty middle
    /// paragraph was dropped, folding two blank-separated paragraphs into one ("two newlines fold to one").
    func test_blankLine_preservedAsEmptyParagraph() {
        let d = doc("{\\rtf1\\ansi\\fs34 a\\\n\\\nb}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["a", "", "b"])
    }

    /// Literal `\par\par` (Word style) must likewise keep the blank middle paragraph.
    func test_doubleLiteralPar_preservesEmptyParagraph() {
        let d = doc("{\\rtf1\\ansi\\fs34 a\\par\\par b}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["a", "", "b"])
    }

    /// A trailing `\par` must NOT add a spurious empty final paragraph (matches the editor's own
    /// no-trailing-`\par` export, and avoids a phantom blank line at the end of every paste).
    func test_trailingPar_noSpuriousEmptyParagraph() {
        let d = doc("{\\rtf1\\ansi\\fs34 a\\par b\\par}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["a", "b"])
    }

    func test_skipsFontAndColorTables_noStrayText() {
        let d = doc("{\\rtf1\\ansi{\\fonttbl{\\f0 Helvetica;}}{\\colortbl;\\red0\\green0\\blue0;}Hello}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["Hello"])
    }

    func test_underlineAndStrike() {
        let d = doc("{\\rtf1 {\\ul under}{\\strike strk}}")
        let runs = paras(d).first?.runs ?? []
        XCTAssertTrue(runs.first { $0.text == "under" }?.attributes.underline == true)
        XCTAssertTrue(runs.first { $0.text == "strk" }?.attributes.strikethrough == true)
    }

    func test_ignorableDestinationSkipped() {
        let d = doc("{\\rtf1 {\\*\\generator Word}real}")
        XCTAssertEqual(paras(d).map { $0.runs.map(\.text).joined() }, ["real"])
    }

    func test_hyperlinkField_becomesLinkRun() {
        let d = doc("{\\rtf1 a{\\field{\\*\\fldinst HYPERLINK \"https://x.test\"}{\\fldrslt link}}b}")
        let runs = paras(d).first?.runs ?? []
        XCTAssertTrue(runs.contains { $0.text == "a" })
        let l = runs.first { $0.attributes.link != nil }
        XCTAssertEqual(l?.text, "link"); XCTAssertEqual(l?.attributes.link, "https://x.test")
        XCTAssertTrue(runs.contains { $0.text == "b" })
    }

    func test_emojiMarkerField_becomesEmojiRun() {
        let d = doc("{\\rtf1 {\\field{\\*\\fldinst HYPERLINK \"tg://emoji?id=42&n=0\"}{\\fldrslt :star:}}}")
        let r = paras(d).first?.runs.first { $0.attributes.emoji != nil }
        XCTAssertEqual(r?.text, "\u{FFFC}")
        XCTAssertEqual(r?.attributes.emoji?.id, "42")
        XCTAssertEqual(r?.attributes.emoji?.altText, ":star:")
    }

    func test_headingByFontSize() {
        let d = doc("{\\rtf1 \\fs48 Big\\par \\fs34 Body}")     // 24pt heading1, 17pt body
        let p = paras(d)
        XCTAssertEqual(p.first { $0.runs.map(\.text).joined() == "Big" }?.style, .heading1)
        XCTAssertEqual(p.first { $0.runs.map(\.text).joined() == "Body" }?.style, .body)
    }

    func test_monoParagraph_becomesCodeBlock() {
        // f1 is the modern (mono) font.
        let d = doc("{\\rtf1{\\fonttbl{\\f0 Helvetica;}{\\f1\\fmodern Courier;}}\\f1 let x = 1\\par\\f1 let y = 2}")
        let code = (d?.blocks ?? []).compactMap { if case .code(let c) = $0 { return c } else { return nil } }
        XCTAssertEqual(code.count, 1)
        XCTAssertTrue(code[0].text.contains("let x = 1") && code[0].text.contains("let y = 2"))
    }

    func test_table_twoByTwo_reconstructs() {
        let d = doc("""
        {\\rtf1 \\trowd\\trhdr\\cellx2000\\cellx4000 \\intbl Name\\cell \\intbl Age\\cell\\row \
        \\trowd\\cellx2000\\cellx4000 \\intbl Ann\\cell \\intbl 30\\cell\\row }
        """)
        let tables = (d?.blocks ?? []).compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(tables.count, 1)
        let t = tables[0]
        XCTAssertEqual(t.columns.count, 2)
        XCTAssertEqual(Int(t.columns[0].width), 100)          // 2000 twips / 20
        XCTAssertEqual(Int(t.columns[1].width), 100)          // (4000-2000)/20
        XCTAssertEqual(t.rows.count, 2)
        XCTAssertTrue(t.rows[0].isHeader)
        XCTAssertEqual(cellText(t, 0, 0), "Name"); XCTAssertEqual(cellText(t, 0, 1), "Age")
        XCTAssertEqual(cellText(t, 1, 0), "Ann");  XCTAssertEqual(cellText(t, 1, 1), "30")
    }
    private func cellText(_ t: TableBlock, _ r: Int, _ c: Int) -> String {
        t.rows[r].cells[c].blocks.compactMap { if case .paragraph(let p) = $0 { return p.runs.map(\.text).joined() } else { return nil } }.joined()
    }

    func test_bulletList_fromListtext() {
        let d = doc("{\\rtf1 \\ilvl0 {\\listtext\\f0 \\'b7\\tab}First item\\par}")   // \'b7 = · MIDDLE DOT (cp1252)
        let p = paras(d).first { $0.runs.map(\.text).joined().contains("First item") }
        XCTAssertEqual(p?.list?.marker, .bullet)
        XCTAssertEqual(p?.list?.level, 0)
        XCTAssertFalse(p?.runs.map(\.text).joined().contains("·") ?? true)   // the marker glyph (·, the decoded \'b7) is NOT in the text
    }

    func test_orderedList_fromListtext() {
        let d = doc("{\\rtf1 \\ilvl0 {\\listtext\\f0 1.\\tab}Step one\\par}")
        let p = paras(d).first { $0.runs.map(\.text).joined().contains("Step one") }
        XCTAssertEqual(p?.list?.marker, .ordered)
    }

    /// Real TextEdit/Notes declare \ls\ilvl only on the FIRST item of a list run; later items carry only
    /// {\listtext ...} and rely on paragraph props surviving the backslash-newline \par. Every item must
    /// still import as a list member. (Representative TextEdit bullet output; substitute real pbpaste bytes.)
    func test_textEditStyle_listDeclaredOnlyOnFirstItem_allItemsAreListMembers() {
        let rtf = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2761{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
            + "{\\*\\listtable{\\list\\listtemplateid1\\listhybrid{\\listlevel\\levelnfc23{\\leveltext\\'01\\uc0\\u8226 ;}}{\\listname ;}\\listid1}}\n"
            + "{\\*\\listoverridetable{\\listoverride\\listid1\\listoverridecount0\\ls1}}\n"
            + "\\pard\\li720\\fi-360\\pardirnatural\\partightenfactor0\n"
            + "\\ls1\\ilvl0\\cf0 {\\listtext\t\\uc0\\u8226 \t}First item\\\n"
            + "{\\listtext\t\\uc0\\u8226 \t}Second item\\\n"
            + "{\\listtext\t\\uc0\\u8226 \t}Third item}"
        let list = paras(doc(rtf)).filter { $0.list != nil }
        XCTAssertEqual(list.count, 3, "all three bullet items should be list members")
        XCTAssertTrue(list.allSatisfy { $0.list?.marker == .bullet }, "each should be a bullet")
        XCTAssertFalse(list.contains { $0.runs.map(\.text).joined().contains("\u{2022}") }, "bullet glyph must not leak into item text")
    }

    /// Same, ordered: the marker glyph "1." starts with a digit → .ordered.
    func test_textEditStyle_orderedList_declaredOnlyOnFirstItem() {
        let rtf = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2761{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n"
            + "\\pard\\li720\\fi-360\\pardirnatural\\partightenfactor0\n"
            + "\\ls1\\ilvl0\\cf0 {\\listtext\t1.\t}One\\\n"
            + "{\\listtext\t2.\t}Two}"
        let list = paras(doc(rtf)).filter { $0.list != nil }
        XCTAssertEqual(list.count, 2)
        XCTAssertTrue(list.allSatisfy { $0.list?.marker == .ordered })
    }

    func test_table_multiParagraphCell_preservesAllParagraphs() {
        let d = doc("{\\rtf1 \\trowd\\cellx2000 \\intbl Line one\\par Line two\\cell\\row }")
        let tables = (d?.blocks ?? []).compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(tables.count, 1)
        let cellParas = tables[0].rows[0].cells[0].blocks.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.runs.map(\.text).joined() } else { return nil }
        }
        XCTAssertTrue(cellParas.contains { $0.contains("Line one") })
        XCTAssertTrue(cellParas.contains { $0.contains("Line two") })   // was DROPPED before the fix
    }

    func test_table_thenParagraph_bothSurvive_noLeak() {
        let d = doc("{\\rtf1 \\trowd\\cellx2000 \\intbl A\\cell\\row \\pard Body text\\par}")
        let blocks = d?.blocks ?? []
        let tables = blocks.compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        let paras = blocks.compactMap { if case .paragraph(let p) = $0 { return p } else { return nil } }
        XCTAssertEqual(tables.count, 1)
        XCTAssertEqual(paras.compactMap { p in p.runs.map(\.text).joined() }.first { $0.contains("Body text") }, "Body text")
        // "Body text" must NOT be inside any table cell
        let cellText = tables[0].rows.flatMap { $0.cells }.flatMap { $0.blocks }.compactMap { b -> String? in
            if case .paragraph(let p) = b { return p.runs.map(\.text).joined() } else { return nil }
        }.joined()
        XCTAssertFalse(cellText.contains("Body text"))
        XCTAssertEqual(cellText, "A")
    }

    func test_table_paragraph_table_threeBlocksInOrder() {
        let d = doc("{\\rtf1 \\trowd\\cellx2000 \\intbl A\\cell\\row \\pard Middle\\par \\trowd\\cellx2000 \\intbl B\\cell\\row }")
        let kinds = (d?.blocks ?? []).map { b -> String in
            switch b { case .table: return "table"; case .paragraph(let p): return "p:" + p.runs.map(\.text).joined(); case .code: return "code"; default: return "?" }
        }
        XCTAssertEqual(kinds, ["table", "p:Middle", "table"])
    }

    func test_paragraphBeforeTable_isSeparateBlock_notMergedIntoCell() {
        // Cocoa/TextEdit emits a pre-table paragraph with NO \par before \trowd. It must NOT merge into
        // the table's first cell (the reported ~/Downloads/text1.rtf bug: "Qwefqwef" went into cell[0][0]).
        let d = doc("{\\rtf1 Intro\\trowd\\cellx2000 \\intbl A\\cell\\row }")
        let blocks = d?.blocks ?? []
        let paras = blocks.compactMap { if case .paragraph(let p) = $0 { return p.runs.map(\.text).joined() } else { return nil } }
        let tables = blocks.compactMap { if case .table(let t) = $0 { return t } else { return nil } }
        XCTAssertEqual(paras.first { $0.contains("Intro") }, "Intro")   // Intro is its own top-level paragraph
        XCTAssertEqual(tables.count, 1)
        let c00 = tables[0].rows.first?.cells.first?.blocks.compactMap {
            if case .paragraph(let p) = $0 { return p.runs.map(\.text).joined() } else { return nil }
        }.joined() ?? ""
        XCTAssertEqual(c00, "A")                                        // cell has ONLY its own content, not "IntroA"
        XCTAssertFalse(c00.contains("Intro"))
    }

    func test_emojiCheckbox_inParagraphText_importsAsChecklist() {
        let rtf = "{\\rtf1\\ansi \\pard \\u11036? todo\\par \\pard \\u9989? done}"   // ⬜ todo / ✅ done
        let doc = RTFImport.document(fromRTF: rtf.data(using: .utf8)!)!
        XCTAssertEqual(doc.blocks.count, 2)
        guard case .paragraph(let p0) = doc.blocks[0], case .paragraph(let p1) = doc.blocks[1] else { return XCTFail() }
        XCTAssertEqual(p0.list?.marker, .checklist); XCTAssertEqual(p0.list?.checked, false)
        XCTAssertEqual(p0.text, "todo")    // marker stripped from content
        XCTAssertEqual(p1.list?.marker, .checklist); XCTAssertEqual(p1.list?.checked, true)
        XCTAssertEqual(p1.text, "done")
    }
}
