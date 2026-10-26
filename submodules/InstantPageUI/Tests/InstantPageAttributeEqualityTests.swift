import XCTest
import UIKit
import CoreText
import TelegramCore
import TextFormat
@testable import InstantPageUI

final class InstantPageAttributeEqualityTests: XCTestCase {
    private let urlKey = NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)

    func testUrlEqualityHandlesNilAndUnrelatedObjects() {
        let item = InstantPageUrlItem(url: "https://example.com", webpageId: nil)
        XCTAssertFalse(item.isEqual(nil))
        XCTAssertFalse(item.isEqual("https://example.com" as NSString))
        XCTAssertFalse(item.isEqual(NSNumber(value: 1)))
        XCTAssertTrue(item.isEqual(item))
    }

    func testUrlEqualityAndHashIncludeWebpageIdentity() {
        let id = EngineMedia.Id(namespace: 0, id: 1)
        let item = InstantPageUrlItem(url: "https://example.com", webpageId: id)
        let equal = InstantPageUrlItem(url: "https://example.com", webpageId: id)
        XCTAssertEqual(item, equal)
        XCTAssertEqual(item.hash, equal.hash)
        XCTAssertNotEqual(item, InstantPageUrlItem(url: "https://example.com", webpageId: nil))
        XCTAssertNotEqual(item, InstantPageUrlItem(url: "https://example.com", webpageId: EngineMedia.Id(namespace: 0, id: 2)))
        XCTAssertNotEqual(item, InstantPageUrlItem(url: "https://example.org", webpageId: id))
    }

    // Reproduces #2405: scanning past a link into unlinked text compares the payload with nil.
    // Two equal payload instances and a font change must still form one maximal link range.
    func testLongestUrlRangeSpansFormattingAndStopsAtUnlinkedText() {
        let string = self.formattedLink()
        for index in 5 ..< 9 {
            var range = NSRange()
            let value = string.attribute(self.urlKey, at: index, longestEffectiveRange: &range,
                                         in: NSRange(location: 0, length: string.length))
            XCTAssertNotNil(value)
            XCTAssertEqual(range, NSRange(location: 5, length: 4))
        }
        XCTAssertNil(string.attribute(self.urlKey, at: 0, effectiveRange: nil))
        XCTAssertNil(string.attribute(self.urlKey, at: 9, effectiveRange: nil))
    }

    func testAdjacentDifferentUrlsRemainSeparate() {
        let string = NSMutableAttributedString(string: "ab")
        string.addAttribute(self.urlKey, value: InstantPageUrlItem(url: "https://example.com", webpageId: nil),
                            range: NSRange(location: 0, length: 1))
        string.addAttribute(self.urlKey, value: InstantPageUrlItem(url: "https://example.org", webpageId: nil),
                            range: NSRange(location: 1, length: 1))
        var range = NSRange()
        let _ = string.attribute(self.urlKey, at: 0, longestEffectiveRange: &range,
                                 in: NSRange(location: 0, length: string.length))
        XCTAssertEqual(range, NSRange(location: 0, length: 1))
    }

    func testTouchHighlightCoversTheWholeFormattedLink() throws {
        let (result, _, _) = layoutTextItemWithString(self.formattedLink(), boundingWidth: 400.0, offset: .zero)
        let item = try XCTUnwrap(result)
        let line = try XCTUnwrap(item.lines.first)
        let left = CTLineGetOffsetForStringIndex(line.line, 5, nil)
        let next = CTLineGetOffsetForStringIndex(line.line, 6, nil)
        let right = CTLineGetOffsetForStringIndex(line.line, 9, nil)
        let rects = item.linkSelectionRects(at: CGPoint(x: (left + next) / 2.0, y: line.frame.midY))
        let rect = try XCTUnwrap(rects.first)
        XCTAssertEqual(rects.count, 1)
        XCTAssertEqual(rect.minX, floor(left), accuracy: 1.0)
        XCTAssertEqual(rect.maxX, ceil(right), accuracy: 1.0)
        XCTAssertTrue(item.linkSelectionRects(at: CGPoint(x: 1.0, y: line.frame.midY)).isEmpty)
    }

    func testTouchHighlightCoversTheWholeCallbackButton() throws {
        let action = ReplyMarkupButtonAction.callback(
            requiresPassword: false, data: EngineMemoryBuffer(data: Data("test".utf8)))
        let button = InstantPageButton(text: .plain("Open"), action: action, color: nil, isLink: true)
        let styleStack = InstantPageTextStyleStack()
        styleStack.push(.textColor(.black))
        styleStack.push(.linkColor(.blue))
        styleStack.push(.fontSize(17.0))
        let string = attributedStringForRichText(
            .concat([.plain("Test "), .textButton(button), .plain(" after")]), styleStack: styleStack)
        XCTAssertEqual(string.string, "Test Open after")
        let key = NSAttributedString.Key(rawValue: InstantPageButtonActionAttribute)
        let payload = try XCTUnwrap(string.attribute(key, at: 5, effectiveRange: nil) as? InstantPageButtonActionItem)
        XCTAssertEqual(payload.button.action, action)
        XCTAssertNil(string.attribute(self.urlKey, at: 5, effectiveRange: nil))

        let (result, _, _) = layoutTextItemWithString(string, boundingWidth: 400.0, offset: .zero)
        let item = try XCTUnwrap(result)
        let line = try XCTUnwrap(item.lines.first)
        let left = CTLineGetOffsetForStringIndex(line.line, 5, nil)
        let right = CTLineGetOffsetForStringIndex(line.line, 9, nil)
        for index in 5 ..< 9 {
            let start = CTLineGetOffsetForStringIndex(line.line, index, nil)
            let end = CTLineGetOffsetForStringIndex(line.line, index + 1, nil)
            let rects = item.linkSelectionRects(at: CGPoint(x: (start + end) / 2.0, y: line.frame.midY))
            let rect = try XCTUnwrap(rects.first)
            XCTAssertEqual(rects.count, 1)
            XCTAssertEqual(rect.minX, floor(left), accuracy: 1.0)
            XCTAssertEqual(rect.maxX, ceil(right), accuracy: 1.0)
        }
        XCTAssertTrue(item.linkSelectionRects(at: CGPoint(x: 1.0, y: line.frame.midY)).isEmpty)
        XCTAssertTrue(item.linkSelectionRects(at: CGPoint(x: (right + line.frame.maxX) / 2.0, y: line.frame.midY)).isEmpty)
    }

    func testButtonActionEqualityAndRangeHandleUnlinkedText() {
        let button = InstantPageButton(text: .plain("Copy"), action: .copyText(payload: "one"), color: nil, isLink: true)
        let item = InstantPageButtonActionItem(button: button)
        let equal = InstantPageButtonActionItem(button: button)
        let different = InstantPageButtonActionItem(button: InstantPageButton(
            text: .plain("Copy"), action: .copyText(payload: "two"), color: nil, isLink: true))
        XCTAssertFalse(item.isEqual(nil))
        XCTAssertFalse(item.isEqual(NSNumber(value: 1)))
        XCTAssertEqual(item, equal)
        XCTAssertEqual(item.hash, equal.hash)
        XCTAssertNotEqual(item, different)

        let key = NSAttributedString.Key(rawValue: InstantPageButtonActionAttribute)
        let string = NSMutableAttributedString(string: "a Copy z")
        string.addAttribute(key, value: item, range: NSRange(location: 2, length: 2))
        string.addAttribute(key, value: equal, range: NSRange(location: 4, length: 2))
        var range = NSRange()
        let _ = string.attribute(key, at: 3, longestEffectiveRange: &range,
                                 in: NSRange(location: 0, length: string.length))
        XCTAssertEqual(range, NSRange(location: 2, length: 4))
    }

    private func formattedLink() -> NSAttributedString {
        let string = NSMutableAttributedString(string: "Test link after", attributes: [.font: UIFont.systemFont(ofSize: 17.0)])
        string.addAttribute(self.urlKey, value: InstantPageUrlItem(url: "https://example.com", webpageId: nil),
                            range: NSRange(location: 5, length: 2))
        string.addAttributes([
            self.urlKey: InstantPageUrlItem(url: "https://example.com", webpageId: nil),
            .font: UIFont.boldSystemFont(ofSize: 17.0)
        ], range: NSRange(location: 7, length: 2))
        return string
    }
}
