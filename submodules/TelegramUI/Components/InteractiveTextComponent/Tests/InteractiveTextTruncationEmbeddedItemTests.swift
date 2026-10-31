import XCTest
import UIKit
import Display
import InteractiveTextComponent

/// A truncated line keeps only the text before its cut. An embedded item (a custom emoji) that the cut removed must not
/// be laid out on that line: CoreText has no offset for it, so it lands at the line's start, over its first letter
/// (story captions, issue #96).
final class InteractiveTextTruncationEmbeddedItemTests: XCTestCase {
    private let font = UIFont.systemFont(ofSize: 16.0)

    /// "xI xI xI …": every item is the second character of a word, so it always follows a letter on its line.
    private func makeString(wordCount: Int, blockQuote: TextNodeBlockQuoteData? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for i in 0 ..< wordCount {
            result.append(NSAttributedString(string: "x", attributes: [.font: self.font]))
            result.append(NSAttributedString(string: "I", attributes: [.font: self.font, NSAttributedString.Key("Attribute__EmbeddedItem"): AnyHashable(i)]))
            result.append(NSAttributedString(string: " ", attributes: [.font: self.font]))
        }
        if let blockQuote {
            result.addAttribute(NSAttributedString.Key("Attribute__Blockquote"), value: blockQuote, range: NSRange(location: 0, length: result.length))
        }
        return result
    }

    private func layout(_ string: NSAttributedString, maximumNumberOfLines: Int, customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)? = nil) -> InteractiveTextNodeLayout {
        return InteractiveTextNode.asyncLayout(nil)(InteractiveTextNodeLayoutArguments(
            attributedString: string,
            maximumNumberOfLines: maximumNumberOfLines,
            truncationType: .end,
            constrainedSize: CGSize(width: 240.0, height: 10000.0),
            customTruncationToken: customTruncationToken
        )).0
    }

    private func assertItemsTakeTheirOwnPlace(_ items: [InteractiveTextNodeLayout.EmbeddedItem], file: StaticString = #filePath, line: UInt = #line) {
        // Each item is one "I" wide.
        let itemWidth = ceil(NSAttributedString(string: "I", attributes: [.font: self.font]).size().width)
        for item in items {
            XCTAssertGreaterThan(item.rect.minX, 0.0, "item \(item.value) is laid out at its line's start", file: file, line: line)
            XCTAssertGreaterThan(item.rect.width, 0.0, "item \(item.value) has no width", file: file, line: line)
            XCTAssertLessThanOrEqual(item.rect.width, itemWidth + 2.0, "item \(item.value) is wider than its character", file: file, line: line)
        }
        for i in 0 ..< items.count {
            for j in (i + 1) ..< items.count {
                let a = items[i].rect.insetBy(dx: 0.5, dy: 0.5)
                let b = items[j].rect.insetBy(dx: 0.5, dy: 0.5)
                XCTAssertFalse(a.intersects(b), "items \(items[i].value) and \(items[j].value) overlap", file: file, line: line)
            }
        }
    }

    func testLastLineTruncationWithCustomTokenDropsItemsAfterTheCut() {
        let wordCount = 60
        let customTruncationToken: (UIFont, Bool) -> NSAttributedString? = { font, _ in
            return NSAttributedString(string: "\u{2026} Show more", attributes: [.font: font])
        }
        let layout = self.layout(self.makeString(wordCount: wordCount), maximumNumberOfLines: 3, customTruncationToken: customTruncationToken)
        let items = layout.segments.flatMap(\.embeddedItems)

        XCTAssertFalse(items.isEmpty)
        XCTAssertLessThan(items.count, wordCount)
        // Items stay in text order: what the cut keeps is a prefix.
        XCTAssertEqual(items.map(\.value), (0 ..< items.count).map { AnyHashable($0) })
        self.assertItemsTakeTheirOwnPlace(items)
    }

    func testLastLineTruncationWithDefaultTokenDropsItemsAfterTheCut() {
        let wordCount = 60
        let layout = self.layout(self.makeString(wordCount: wordCount), maximumNumberOfLines: 1)
        let items = layout.segments.flatMap(\.embeddedItems)

        XCTAssertFalse(items.isEmpty)
        XCTAssertLessThan(items.count, wordCount)
        self.assertItemsTakeTheirOwnPlace(items)
    }

    func testCollapsedQuoteTruncationDropsItemsAfterTheCut() {
        let blockQuote = TextNodeBlockQuoteData(kind: .quote, title: nil, color: .white, secondaryColor: nil, tertiaryColor: nil, backgroundColor: .clear, isCollapsible: true)
        let layout = self.layout(self.makeString(wordCount: 120, blockQuote: blockQuote), maximumNumberOfLines: 0)
        let items = layout.segments.flatMap(\.embeddedItems)

        XCTAssertTrue(layout.segments.contains(where: { $0.hasBlockQuote && $0.visibleLineCount == 3 }))
        self.assertItemsTakeTheirOwnPlace(items)
    }

    func testHighlightOfAnAttributeAroundTheCutStaysOnItsText() {
        let customTruncationToken: (UIFont, Bool) -> NSAttributedString? = { font, _ in
            return NSAttributedString(string: "\u{2026} Show more", attributes: [.font: font])
        }
        // "word word …": about six words a line. A one-word link in the middle or at the end of the second line, before,
        // across or after the "… Show more" cut.
        var highlightCount = 0
        for linkWordIndex in 8 ... 11 {
            let string = NSMutableAttributedString(string: String(repeating: "word ", count: 30), attributes: [.font: self.font])
            let linkRange = NSRange(location: linkWordIndex * 5, length: 4)
            string.addAttribute(NSAttributedString.Key("TestLink"), value: "link", range: linkRange)
            let layout = self.layout(string, maximumNumberOfLines: 2, customTruncationToken: customTruncationToken)

            for (_, rect) in layout.lineAndAttributeRects(name: "TestLink", at: linkRange.location) ?? [] {
                highlightCount += 1
                XCTAssertGreaterThan(rect.minX, 20.0, "the highlight of word \(linkWordIndex) starts at the line's start")
            }
        }
        XCTAssertGreaterThan(highlightCount, 0)
    }

    func testUntruncatedTextKeepsEveryItem() {
        let wordCount = 20
        let layout = self.layout(self.makeString(wordCount: wordCount), maximumNumberOfLines: 0)
        let items = layout.segments.flatMap(\.embeddedItems)

        XCTAssertEqual(items.map(\.value), (0 ..< wordCount).map { AnyHashable($0) })
        self.assertItemsTakeTheirOwnPlace(items)
    }
}
