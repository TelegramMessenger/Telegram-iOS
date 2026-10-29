import XCTest
@testable import RichTextEditorCore

/// `RTFImport.document(fromRTF:paragraphSpacingAsBlankLines:)`: a paragraph gap that only exists as spacing
/// (`\saN` / `\sbN`) — how WebKit writes the margins of a copied web page, a ChatGPT reply among them — becomes
/// an empty paragraph, i.e. a blank line once flattened to text. Items of one list stay on consecutive lines.
final class RTFImportParagraphSpacingTests: XCTestCase {
    private func lines(_ rtf: String, blankLines: Bool = true) -> [String] {
        let document = RTFImport.document(fromRTF: Data(rtf.utf8), paragraphSpacingAsBlankLines: blankLines)
        return (document?.blocks ?? []).compactMap { block -> String? in
            guard case .paragraph(let paragraph) = block else { return nil }
            let text = paragraph.runs.map(\.text).joined()
            return paragraph.list == nil ? text : "• " + text
        }
    }

    /// What iOS Safari puts on the pasteboard (`public.rtf`) for a ChatGPT-shaped page: `<h3>`, `<p>`, `<ul>`/`<ol>`
    /// of `<li><p>`, and a `<p>` of `<b>Key:</b> value<br>` lines (captured from the iPhone 18 Pro simulator).
    private let webKitReply = """
    {\\rtf1\\ansi\\ansicpg1252\\cocoartf2907
    \\cocoatextscaling1\\cocoaplatform1{\\fonttbl\\f0\\fnil\\fcharset0 .SFUI-Bold;\\f1\\fnil\\fcharset0 .SFUI-Regular;}
    {\\colortbl;\\red255\\green255\\blue255;\\red0\\green0\\blue0;}
    {\\*\\listtable{\\list\\listtemplateid1\\listhybrid{\\listlevel\\levelnfc23\\levelnfcn23\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat0\\levelspace360\\levelindent0{\\*\\levelmarker \\{disc\\}}{\\leveltext\\leveltemplateid1\\'01\\uc0\\u8226 ;}{\\levelnumbers;}\\fi-360\\li720\\lin720 }{\\listname ;}\\listid1}}
    \\deftab720
    \\pard\\pardeftab720\\sa280\\partightenfactor0

    \\f0\\b\\fs42 \\cf0 Silver Service Training & Experience\\
    \\pard\\pardeftab720\\sa300\\partightenfactor0

    \\f1\\b0\\fs46 \\cf0 Candidates should have formal 
    \\f0\\b Silver Service
    \\f1\\b0  training.\\
    They should have a good understanding of:\\
    \\pard\\tx220\\tx720\\pardeftab720\\li720\\fi-720\\sa300\\partightenfactor0
    \\ls1\\ilvl0\\cf0 {\\listtext\t\\uc0\\u8226 \t}Formal table setting and dining etiquette.
    \\fs30 \\
    \\ls1\\ilvl0
    \\fs46 {\\listtext\t\\uc0\\u8226 \t}Silver Service techniques.
    \\fs30 \\
    \\pard\\pardeftab720\\sa280\\partightenfactor0

    \\f0\\b\\fs42 \\cf0 Position Summary\\
    \\pard\\pardeftab720\\sa300\\partightenfactor0

    \\fs46 \\cf0 Position:
    \\f1\\b0  Private Household Butler
    \\fs30 \\uc0\\u8232 
    \\f0\\b\\fs46 Employment:
    \\f1\\b0  Full-time\\
    We are looking for a candidate.\\
    }
    """

    func test_webKitReply_paragraphGapsBecomeBlankLines_listItemsStayTogether() {
        XCTAssertEqual(lines(webKitReply), [
            "Silver Service Training & Experience",
            "",
            "Candidates should have formal Silver Service training.",
            "",
            "They should have a good understanding of:",
            "",
            "• Formal table setting and dining etiquette.",
            "• Silver Service techniques.",
            "",
            "Position Summary",
            "",
            "Position: Private Household Butler\u{2028}Employment: Full-time",
            "",
            "We are looking for a candidate."
        ])
    }

    func test_withoutTheOption_importIsUnchanged() {
        XCTAssertEqual(lines(webKitReply, blankLines: false), [
            "Silver Service Training & Experience",
            "Candidates should have formal Silver Service training.",
            "They should have a good understanding of:",
            "• Formal table setting and dining etiquette.",
            "• Silver Service techniques.",
            "Position Summary",
            "Position: Private Household Butler\u{2028}Employment: Full-time",
            "We are looking for a candidate."
        ])
    }

    func test_smallSpacing_isNotABlankLine() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa120 a\\\nb\\\n}"), ["a", "b"])
    }

    func test_spaceBeforeTheNextParagraph_isABlankLine() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard a\\\n\\pard\\sb240 b\\\n}"), ["a", "", "b"])
    }

    /// Notes and TextEdit write a blank line as an empty paragraph; spacing on top of it adds no second one.
    func test_existingBlankLine_isNotDoubled() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa300 a\\\n\\\nb\\\n}"), ["a", "", "b"])
    }

    /// RTF that separates paragraphs with `\pard` alone (no `\par`): the gap is the spacing of the paragraph
    /// `\pard` ends, read before `\pard` resets it.
    func test_pardSeparatedParagraphs_useTheEndingParagraphsSpacing() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa300 a\\pard\\sa0 b\\pard c}"), ["a", "", "b", "c"])
    }

    func test_noTrailingBlankLine() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa300 a\\\nb\\\n}"), ["a", "", "b"])
    }

    /// A stylesheet entry's spacing is not the body's.
    func test_stylesheetSpacing_isIgnored() {
        XCTAssertEqual(lines("{\\rtf1\\ansi{\\stylesheet{\\s1\\sa400 Heading;}}a\\\nb\\\n}"), ["a", "b"])
    }

    /// A spacer paragraph (`<p>&nbsp;</p>`, `<p><br></p>`) already is the blank line: none is added beside it.
    func test_whitespaceOnlySpacer_isABlankLine() {
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa300 a\\\n\\uc0\\u160 \\\nb\\\n}"), ["a", "\u{00A0}", "b"])
        XCTAssertEqual(lines("{\\rtf1\\ansi\\pard\\sa300 a\\\n\\uc0\\u8232 \\\nb\\\n}"), ["a", "\u{2028}", "b"])
    }
}
