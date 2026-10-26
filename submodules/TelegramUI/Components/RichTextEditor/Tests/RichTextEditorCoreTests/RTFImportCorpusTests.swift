import XCTest
@testable import RichTextEditorCore

/// Corpus tests for RTFImport against hand-authored real-world RTF snippets.
/// Each snippet uses a realistic preamble (fonttbl, colortbl, generator) and
/// asserts the recovered Document STRUCTURE — not exact paragraph IDs.
final class RTFImportCorpusTests: XCTestCase {

    private func doc(_ s: String) -> Document? {
        RTFImport.document(fromRTF: Data(s.utf8))
    }

    // MARK: - Helpers

    /// Returns every paragraph block (recursing into table cells) to check for control-word leaks.
    private func allParagraphTexts(in document: Document) -> [String] {
        var result: [String] = []
        for block in document.blocks {
            switch block {
            case .paragraph(let p):
                result.append(p.text)
            case .table(let t):
                for row in t.rows {
                    for cell in row.cells {
                        for b in cell.blocks {
                            if case .paragraph(let p) = b { result.append(p.text) }
                        }
                    }
                }
            case .code(let c):
                result.append(c.runs.map(\.text).joined())
            case .media:
                break
            case .pullQuote(let pq):
                result.append(pq.text)
            case .blockQuote:
                break
            case .details:
                break
            case .buttonRow:
                // A button row holds no paragraph text; RTF import never produces one.
                break
            }
        }
        return result
    }

    /// Tokens that must never appear in user-visible text produced by the parser.
    private let forbiddenFragments = [
        "trowd", "cellx", "fonttbl", "colortbl", "generator",
        "Helvetica", "Arial", "Times-Roman", "Microsoft Word",
        "\\rtf", "\\f0", "\\fs", "\\par"
    ]

    private func assertNoLeaks(in texts: [String], file: StaticString = #file, line: UInt = #line) {
        for text in texts {
            for frag in forbiddenFragments {
                XCTAssertFalse(
                    text.contains(frag),
                    "Control-word fragment \"\(frag)\" leaked into paragraph text: \"\(text)\"",
                    file: file, line: line
                )
            }
        }
    }

    // MARK: - Test 1: Word-style 2×2 table

    func test_wordStyleTable_2x2() throws {
        // A Word-style RTF table: 2 columns (4320 twips / 8640 twips), 2 rows.
        // Each cell contains one short text run.
        let rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\deff0
        {\\fonttbl{\\f0\\froman\\fcharset0 Times New Roman;}{\\f1\\fswiss\\fcharset0 Arial;}}
        {\\colortbl ;\\red0\\green0\\blue0;}
        {\\*\\generator Microsoft Word 16.0;}
        \\trowd\\trgaph108\\trleft-108
        \\cellx4320\\cellx8640
        \\pard\\intbl\\f1\\fs20 Alpha\\cell
        \\pard\\intbl\\f1\\fs20 Beta\\cell
        \\row
        \\trowd\\trgaph108\\trleft-108
        \\cellx4320\\cellx8640
        \\pard\\intbl\\f1\\fs20 Gamma\\cell
        \\pard\\intbl\\f1\\fs20 Delta\\cell
        \\row
        }
        """

        let document = try XCTUnwrap(doc(rtf), "Parser returned nil for Word-style table RTF")

        // Must produce exactly one .table block.
        let tableBlocks = document.blocks.compactMap { b -> TableBlock? in
            if case .table(let t) = b { return t } else { return nil }
        }
        XCTAssertEqual(tableBlocks.count, 1, "Expected exactly 1 table block")

        let table = try XCTUnwrap(tableBlocks.first)
        XCTAssertEqual(table.columns.count, 2, "Expected 2 columns")
        XCTAssertEqual(table.rows.count, 2, "Expected 2 rows")

        // Collect all cell texts.
        let cellTexts = table.rows.flatMap { row in
            row.cells.map { cell in
                cell.blocks.compactMap { b -> String? in
                    if case .paragraph(let p) = b { return p.text } else { return nil }
                }.joined()
            }
        }
        XCTAssertTrue(cellTexts.contains("Alpha"), "Cell text 'Alpha' not found; got: \(cellTexts)")
        XCTAssertTrue(cellTexts.contains("Beta"),  "Cell text 'Beta' not found; got: \(cellTexts)")
        XCTAssertTrue(cellTexts.contains("Gamma"), "Cell text 'Gamma' not found; got: \(cellTexts)")
        XCTAssertTrue(cellTexts.contains("Delta"), "Cell text 'Delta' not found; got: \(cellTexts)")

        // No control-word leaks anywhere.
        assertNoLeaks(in: allParagraphTexts(in: document))
    }

    // MARK: - Test 2: Pages-style heading + body

    func test_pagesStyleHeadingAndBody() throws {
        // A Pages-style RTF: large-font paragraph (\fs48 = 24pt → heading1) followed
        // by a \fs24 body paragraph. Includes colortbl + generator destination.
        let rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\cocoartf2639
        \\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;\\f1\\fswiss\\fcharset0 Helvetica-Light;}
        {\\colortbl;\\red255\\green255\\blue255;}
        {\\*\\expandedcolortbl;;}
        {\\*\\generator Pages Version 12.2;}
        \\paperw11900\\paperh16840\\margl1440\\margr1440\\vieww11520\\viewh8400\\viewkind0
        \\pard\\tx566\\tx1133\\tx1700\\tx2267\\tx2834\\tx3401\\tx3968\\tx4535\\tx5102\\tx5669\\tx6236\\tx6803\\pardirnatural\\partightenfactor0
        \\f0\\fs48 \\cf0 My Big Title\\par
        \\f1\\fs24 This is a body paragraph with normal text.\\par
        }
        """

        let document = try XCTUnwrap(doc(rtf), "Parser returned nil for Pages-style heading RTF")

        // Filter paragraph blocks only.
        let paragraphs = document.blocks.compactMap { b -> ParagraphBlock? in
            if case .paragraph(let p) = b { return p } else { return nil }
        }
        XCTAssertGreaterThanOrEqual(paragraphs.count, 2, "Expected at least 2 paragraph blocks")

        // The heading paragraph must have a heading style (fs48 = 24pt ≥ 23 → .heading1).
        let headingPara = paragraphs.first { $0.style == .heading1 || $0.style == .heading2 || $0.style == .heading3 }
        XCTAssertNotNil(headingPara, "Expected at least one heading-styled paragraph")

        // fs48 → 24pt → .heading1 per parser rule (pt >= 23 → .heading1).
        if let h = headingPara {
            XCTAssertEqual(h.style, .heading1, "fs48 (24pt) should map to .heading1")
        }

        // The heading text must contain the title words (no control-word contamination).
        let headingText = headingPara?.text ?? ""
        XCTAssertTrue(
            headingText.contains("Big Title") || headingText.contains("Title"),
            "Heading text should contain 'Title'; got: \"\(headingText)\""
        )

        // The body paragraph must have .body style.
        let bodyPara = paragraphs.first { $0.style == .body }
        XCTAssertNotNil(bodyPara, "Expected at least one .body paragraph")
        let bodyText = bodyPara?.text ?? ""
        XCTAssertTrue(
            bodyText.contains("body paragraph"),
            "Body text should contain 'body paragraph'; got: \"\(bodyText)\""
        )

        // No control-word leaks.
        assertNoLeaks(in: allParagraphTexts(in: document))

        // Specifically: font names from fonttbl must not appear in user text.
        for text in allParagraphTexts(in: document) {
            XCTAssertFalse(text.contains("Helvetica"),
                           "Font name 'Helvetica' leaked into text: \"\(text)\"")
        }
    }

    // MARK: - Test 3: Bulleted list (Word style)

    func test_wordStyleBulletedList() throws {
        // A Word-style bulleted list with \ilvl0 and \listtext containing the bullet glyph \'b7.
        // Two list items: "First item" and "Second item".
        let rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\deff0
        {\\fonttbl{\\f0\\fswiss\\fcharset0 Arial;}{\\f1\\fnil\\fcharset2 Symbol;}}
        {\\colortbl ;\\red0\\green0\\blue0;}
        {\\*\\generator Microsoft Word 16.0;}
        {\\*\\listtable{\\list\\listtemplateid1\\listhybrid
        {\\listlevel\\levelnfc23\\levelnfcn23\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat1\\levelspace360\\levelindent0
        {\\*\\levelmarker \\{disc\\}}{\\leveltext\\leveltemplateid2\\'01\\uc0\\u8226 ;}{\\levelnumbers;}\\fi-360\\li720\\lin720 }
        {\\listname ;}\\listid1}}
        {\\*\\listoverridetable{\\listoverride\\listid1\\listoverridecount0\\ls1}}
        \\pard\\pardeftab720\\fi-360\\li720\\sl276\\slmult1\\partightenfactor0
        \\ls1\\ilvl0
        {\\listtext\\f1 \\uc0\\u8226 \\tab}\\f0\\fs24 \\cf0 First item\\par
        \\ls1\\ilvl0
        {\\listtext\\f1 \\uc0\\u8226 \\tab}\\f0\\fs24 \\cf0 Second item\\par
        }
        """

        let document = try XCTUnwrap(doc(rtf), "Parser returned nil for bulleted-list RTF")

        // Extract paragraphs that are list members.
        let listParas = document.blocks.compactMap { b -> ParagraphBlock? in
            if case .paragraph(let p) = b, p.list != nil { return p } else { return nil }
        }
        XCTAssertGreaterThanOrEqual(listParas.count, 1, "Expected at least 1 list paragraph")

        // Every list paragraph must have marker == .bullet.
        for para in listParas {
            let membership = try XCTUnwrap(para.list)
            XCTAssertEqual(membership.marker, .bullet, "List marker should be .bullet")
        }

        // Collect texts for content checks.
        let listTexts = listParas.map(\.text)

        // The bullet glyph U+00B7 (·) or U+2022 (•) must NOT appear in item text.
        for text in listTexts {
            XCTAssertFalse(
                text.contains("\u{00B7}") || text.contains("\u{2022}") || text.contains("\u{F0B7}"),
                "Bullet glyph leaked into item text: \"\(text)\""
            )
        }

        // At least one item should contain recognizable content.
        let allText = listTexts.joined()
        XCTAssertTrue(
            allText.contains("First") || allText.contains("Second") || allText.contains("item"),
            "Expected list item text not found; got: \(listTexts)"
        )

        // The \tab separator that follows the listtext glyph must not leak into paragraph text.
        for text in listTexts {
            // A raw tab character may appear if \tab is emitted; assert it's absent in this list context.
            XCTAssertFalse(text.hasPrefix("\t"), "Tab leaked as first character of list item: \"\(text)\"")
        }

        // No control-word leaks anywhere.
        assertNoLeaks(in: allParagraphTexts(in: document))

        // Generator and colortbl destinations must be fully skipped.
        for text in allParagraphTexts(in: document) {
            XCTAssertFalse(text.contains("Microsoft Word"), "Generator text leaked: \"\(text)\"")
            XCTAssertFalse(text.contains("listtable"),      "\\listtable leaked: \"\(text)\"")
            XCTAssertFalse(text.contains("listoverride"),   "\\listoverride leaked: \"\(text)\"")
        }
    }

    // MARK: - Test 4: TextEdit/Notes paragraph breaks (backslash + newline, NOT literal \par)

    /// The exact form Cocoa/AppKit (TextEdit, Notes, Safari, Mail) emits for a multi-paragraph string:
    /// each paragraph break is a backslash immediately followed by a literal newline (`a\<LF>b`), which
    /// the RTF spec defines as equivalent to `\par`. Every other corpus test above uses a literal `\par`,
    /// so this is the case real cross-app paste actually exercises. Regression guard for the
    /// "pasting removes newlines" bug (all paragraphs were collapsing into one).
    func test_cocoaStyle_backslashNewlineParagraphBreaks() throws {
        // Note: a regular string literal (NOT `"""`) — a trailing `\` before a newline is a Swift
        // line-continuation inside a multiline literal, which would eat the newline we need to emit.
        let rtf = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2869\n"
            + "\\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fnil\\fcharset0 HelveticaNeue;}\n"
            + "{\\colortbl;\\red255\\green255\\blue255;}\n"
            + "{\\*\\expandedcolortbl;;}\n"
            + "\\pard\\tx560\\tx1120\\pardirnatural\\partightenfactor0\n\n"
            + "\\f0\\fs34 \\cf0 First line\\\nSecond line\\\nThird line}"

        let document = try XCTUnwrap(doc(rtf), "Parser returned nil for Cocoa-style RTF")
        let paragraphs = allParagraphTexts(in: document)
        XCTAssertEqual(paragraphs, ["First line", "Second line", "Third line"])
        assertNoLeaks(in: paragraphs)
    }
}
