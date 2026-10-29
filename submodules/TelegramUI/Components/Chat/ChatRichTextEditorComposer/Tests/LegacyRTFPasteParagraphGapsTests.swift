import XCTest
import ChatRichTextEditorComposer

/// The legacy composer's paste of external RTF that carries a list (`legacyChatInputAttributedString`):
/// list markers as text, and paragraph gaps that exist only as paragraph spacing as blank lines (#70, a ChatGPT
/// reply copied in Safari: before, every paragraph followed the last with no blank line between them).
final class LegacyRTFPasteParagraphGapsTests: XCTestCase {
    /// iOS Safari's `public.rtf` for a ChatGPT-shaped page: `<h3>`, `<p>` with bold, `<ul>` and `<ol>` of
    /// `<li><p>`, and a `<p>` of `<b>Key:</b> value<br>` lines (captured from the iPhone 18 Pro simulator).
    private let webKitRTF = """
        {\\rtf1\\ansi\\ansicpg1252\\cocoartf2907
        \\cocoatextscaling1\\cocoaplatform1{\\fonttbl\\f0\\froman\\fcharset0 TimesNewRomanPS-BoldMT;\\f1\\froman\\fcharset0 TimesNewRomanPSMT;}
        {\\colortbl;\\red255\\green255\\blue255;\\red0\\green0\\blue0;}
        {\\*\\expandedcolortbl;;\\cssrgb\\c0\\c0\\c0;}
        {\\*\\listtable{\\list\\listtemplateid1\\listhybrid{\\listlevel\\levelnfc23\\levelnfcn23\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat0\\levelspace360\\levelindent0{\\*\\levelmarker \\{disc\\}}{\\leveltext\\leveltemplateid1\\'01\\uc0\\u8226 ;}{\\levelnumbers;}\\fi-360\\li720\\lin720 }{\\listname ;}\\listid1}
        {\\list\\listtemplateid2\\listhybrid{\\listlevel\\levelnfc0\\levelnfcn0\\leveljc0\\leveljcn0\\levelfollow0\\levelstartat1\\levelspace360\\levelindent0{\\*\\levelmarker \\{decimal\\}}{\\leveltext\\leveltemplateid101\\'01\\'00;}{\\levelnumbers\\'01;}\\fi-360\\li720\\lin720 }{\\listname ;}\\listid2}}
        {\\*\\listoverridetable{\\listoverride\\listid1\\listoverridecount0\\ls1}{\\listoverride\\listid2\\listoverridecount0\\ls2}}
        \\deftab720
        \\pard\\pardeftab720\\sa280\\partightenfactor0

        \\f0\\b\\fs42 \\cf0 \\expnd0\\expndtw0\\kerning0
        \\outl0\\strokewidth0 \\strokec2 Silver Service Training & Experience\\
        \\pard\\pardeftab720\\sa240\\partightenfactor0

        \\f1\\b0\\fs40 \\cf0 \\strokec2 Candidates should have formal 
        \\f0\\b \\strokec2 Silver Service
        \\f1\\b0 \\strokec2  training.\\
        They should have a good understanding of:\\
        \\pard\\tx220\\tx720\\pardeftab720\\li720\\fi-720\\sa240\\partightenfactor0
        \\ls1\\ilvl0\\cf0 \\kerning1\\expnd0\\expndtw0 \\outl0\\strokewidth0 {\\listtext\t\\uc0\\u8226 \t}\\expnd0\\expndtw0\\kerning0
        \\outl0\\strokewidth0 \\strokec2 Formal table setting and dining etiquette.
        \\fs24 \\strokec2 \\
        \\ls1\\ilvl0
        \\fs40 \\kerning1\\expnd0\\expndtw0 \\outl0\\strokewidth0 {\\listtext\t\\uc0\\u8226 \t}\\expnd0\\expndtw0\\kerning0
        \\outl0\\strokewidth0 \\strokec2 Silver Service techniques.
        \\fs24 \\strokec2 \\
        \\pard\\tx220\\tx720\\pardeftab720\\li720\\fi-720\\sa240\\partightenfactor0
        \\ls2\\ilvl0
        \\fs40 \\cf0 \\kerning1\\expnd0\\expndtw0 \\outl0\\strokewidth0 {\\listtext\t1\t}\\expnd0\\expndtw0\\kerning0
        \\outl0\\strokewidth0 \\strokec2 First step
        \\fs24 \\strokec2 \\
        \\ls2\\ilvl0
        \\fs40 \\kerning1\\expnd0\\expndtw0 \\outl0\\strokewidth0 {\\listtext\t2\t}\\expnd0\\expndtw0\\kerning0
        \\outl0\\strokewidth0 \\strokec2 Second step
        \\fs24 \\strokec2 \\
        \\pard\\pardeftab720\\sa280\\partightenfactor0

        \\f0\\b\\fs42 \\cf0 \\strokec2 Position Summary\\
        \\pard\\pardeftab720\\sa240\\partightenfactor0

        \\fs40 \\cf0 \\strokec2 Position:
        \\f1\\b0 \\strokec2  Private Household Butler
        \\fs24 \\strokec2 \\uc0\\u8232 
        \\f0\\b\\fs40 \\strokec2 Employment:
        \\f1\\b0 \\strokec2  Full-time
        \\fs24 \\strokec2 \\uc0\\u8232 
        \\f0\\b\\fs40 \\strokec2 Working Hours:
        \\f1\\b0 \\strokec2  Flexible\\
        We are looking for a candidate.\\
        }
        """

    func test_chatGPTReplyFromSafari_keepsBlankLinesMarkersAndLineBreaks() throws {
        let pasted = try XCTUnwrap(legacyChatInputAttributedString(fromRTF: Data(webKitRTF.utf8)))
        XCTAssertEqual(pasted.string, [
            "Silver Service Training & Experience",
            "",
            "Candidates should have formal Silver Service training.",
            "",
            "They should have a good understanding of:",
            "",
            "• Formal table setting and dining etiquette.",
            "• Silver Service techniques.",
            "1. First step",
            "2. Second step",
            "",
            "Position Summary",
            "",
            "Position: Private Household Butler\u{2028}Employment: Full-time\u{2028}Working Hours: Flexible",
            "",
            "We are looking for a candidate."
        ].joined(separator: "\n"))
    }
}
