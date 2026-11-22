import XCTest
import UIKit
import Display
import TelegramCore
import TelegramPresentationData
@testable import TextFormat

// Under a New York body (other people's text without bubbles, spec 5.11), block quotes and code-block titles keep the
// system family, code stays monospace, and links and mentions take the body font.
final class StringWithAppliedEntitiesBlockFontsTests: XCTestCase {
    private let newYork = ChatMessageTextFonts.newYork(baseFontSize: 17.0)
    private let system = ChatMessageTextFonts(regular: Font.regular(17.0), bold: Font.bold(17.0), italic: Font.italic(17.0), boldItalic: Font.semiboldItalic(17.0))
    private let fixedFont = Font.monospace(17.0)
    // `round(17 * 0.8235294117647058)`: a quote's size with `adjustQuoteFontSize`.
    private let quoteSize: CGFloat = 14.0
    // Code in a code block is a quote span sized from the monospace font's own point size, as on master.
    private var quotedFixedFont: UIFont {
        return self.fixedFont.withSize(round(self.fixedFont.pointSize * 0.8235294117647058))
    }

    private func apply(_ text: String, _ entities: [MessageTextEntity], blockFonts: ChatMessageTextFonts?) -> NSAttributedString {
        if let blockFonts {
            return stringWithAppliedEntities(text, entities: entities, baseColor: .black, linkColor: .blue, codeBlockTitleColor: .red, codeBlockAccentColor: .red, codeBlockBackgroundColor: .gray, baseFont: self.newYork.regular, linkFont: self.newYork.regular, boldFont: self.newYork.bold, italicFont: self.newYork.italic, boldItalicFont: self.newYork.boldItalic, fixedFont: self.fixedFont, blockQuoteFont: Font.regular(16.0), blockFonts: blockFonts, message: nil, adjustQuoteFontSize: true)
        } else {
            return stringWithAppliedEntities(text, entities: entities, baseColor: .black, linkColor: .blue, codeBlockTitleColor: .red, codeBlockAccentColor: .red, codeBlockBackgroundColor: .gray, baseFont: self.newYork.regular, linkFont: self.newYork.regular, boldFont: self.newYork.bold, italicFont: self.newYork.italic, boldItalicFont: self.newYork.boldItalic, fixedFont: self.fixedFont, blockQuoteFont: Font.regular(16.0), message: nil, adjustQuoteFontSize: true)
        }
    }

    private func assertFont(_ string: NSAttributedString, at index: Int, is expected: UIFont, file: StaticString = #filePath, line: UInt = #line) {
        guard let font = string.attribute(.font, at: index, effectiveRange: nil) as? UIFont else {
            XCTFail("no font at \(index)", file: file, line: line)
            return
        }
        XCTAssertEqual(font.fontName, expected.fontName, "at \(index)", file: file, line: line)
        XCTAssertEqual(font.pointSize, expected.pointSize, "at \(index)", file: file, line: line)
    }

    private func codeBlockTitle(_ string: NSAttributedString, at index: Int) -> NSAttributedString? {
        return (string.attribute(NSAttributedString.Key(rawValue: "Attribute__Blockquote"), at: index, effectiveRange: nil) as? TextNodeBlockQuoteData)?.title
    }

    func testABlockQuoteKeepsTheBlockFonts() {
        let string = self.apply("Body quoted", [MessageTextEntity(range: 5 ..< 11, type: .BlockQuote(isCollapsed: false))], blockFonts: self.system)
        self.assertFont(string, at: 0, is: self.newYork.regular)
        self.assertFont(string, at: 6, is: self.system.regular.withSize(self.quoteSize))
    }

    func testBoldInsideAQuoteIsSystemBold() {
        let string = self.apply("Body quoted", [MessageTextEntity(range: 5 ..< 11, type: .BlockQuote(isCollapsed: false)), MessageTextEntity(range: 5 ..< 11, type: .Bold)], blockFonts: self.system)
        self.assertFont(string, at: 6, is: self.system.bold.withSize(self.quoteSize))
    }

    func testACodeBlockTitleKeepsTheBlockBold() {
        let string = self.apply("let x", [MessageTextEntity(range: 0 ..< 5, type: .Pre(language: "swift"))], blockFonts: self.system)
        guard let title = self.codeBlockTitle(string, at: 0) else {
            XCTFail("no code-block title")
            return
        }
        self.assertFont(title, at: 0, is: self.system.bold.withSize(self.quoteSize))
        self.assertFont(string, at: 0, is: self.quotedFixedFont)
    }

    // Master's behaviour, which the bubble-free mode relies on: links and mentions take the body font.
    func testLinksAndMentionsTakeTheBodyFont() {
        let string = self.apply("see t.me and @name", [MessageTextEntity(range: 4 ..< 8, type: .Url), MessageTextEntity(range: 13 ..< 18, type: .Mention)], blockFonts: self.system)
        self.assertFont(string, at: 5, is: self.newYork.regular)
        self.assertFont(string, at: 14, is: self.newYork.regular)
        XCTAssertEqual(string.attribute(.foregroundColor, at: 5, effectiveRange: nil) as? UIColor, UIColor.blue)
    }

    func testMixedSpansKeepTheirFamilies() {
        var text = ""
        var entities: [MessageTextEntity] = []
        func add(_ segment: String, _ types: [MessageTextEntityType]) -> Int {
            let start = (text as NSString).length
            text += segment
            for type in types {
                entities.append(MessageTextEntity(range: start ..< start + (segment as NSString).length, type: type))
            }
            return start
        }
        let bold = add("Bold", [.Bold])
        _ = add(" ", [])
        let italic = add("ital", [.Italic])
        _ = add(" ", [])
        let link = add("t.me", [.Url])
        _ = add(" ", [])
        let mention = add("@name", [.Mention])
        _ = add(" ", [])
        let code = add("code", [.Code])
        _ = add("\n", [])
        let quote = add("quote ", [.BlockQuote(isCollapsed: false)])
        let quoteBold = add("BOLD", [.BlockQuote(isCollapsed: false), .Bold])
        _ = add("\n", [])
        let pre = add("let x", [.Pre(language: "swift")])

        let string = self.apply(text, entities, blockFonts: self.system)
        self.assertFont(string, at: bold, is: self.newYork.bold)
        self.assertFont(string, at: italic, is: self.newYork.italic)
        self.assertFont(string, at: link, is: self.newYork.regular)
        self.assertFont(string, at: mention, is: self.newYork.regular)
        self.assertFont(string, at: code, is: self.fixedFont)
        self.assertFont(string, at: quote, is: self.system.regular.withSize(self.quoteSize))
        self.assertFont(string, at: quoteBold, is: self.system.bold.withSize(self.quoteSize))
        self.assertFont(string, at: pre, is: self.quotedFixedFont)
        if let title = self.codeBlockTitle(string, at: pre) {
            self.assertFont(title, at: 0, is: self.system.bold.withSize(self.quoteSize))
        } else {
            XCTFail("no code-block title")
        }
    }

    // Master's behaviour with bubbles: without block fonts a quote takes the body's family.
    func testWithoutBlockFontsQuotesFollowTheBody() {
        let string = self.apply("Body quoted", [MessageTextEntity(range: 5 ..< 11, type: .BlockQuote(isCollapsed: false))], blockFonts: nil)
        self.assertFont(string, at: 6, is: self.newYork.regular.withSize(self.quoteSize))
    }
}
