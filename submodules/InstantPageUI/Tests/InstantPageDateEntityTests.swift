import XCTest
import UIKit
import TelegramCore
import TextFormat
@testable import InstantPageUI

/// A `RichText.textDate` is the InstantPage twin of a `FormattedDate` message entity. In a regular
/// text message `StringWithAppliedEntities` paints that range in the link colour AND stamps
/// `TelegramTextAttributes.Date`; in a rich bubble only the stamp was applied, so the date was a
/// tappable hot zone rendered in ordinary body colour — invisible as an affordance.
final class InstantPageDateEntityTests: XCTestCase {
    private let linkColor = UIColor.blue
    private let bodyColor = UIColor.darkGray

    private func stack() -> InstantPageTextStyleStack {
        let stack = InstantPageTextStyleStack()
        stack.push(.fontSize(17.0))
        stack.push(.textColor(self.bodyColor))
        stack.push(.linkColor(self.linkColor))
        return stack
    }

    private func format(_ timestamp: Int32, _ format: MessageTextEntityType.DateTimeFormat) -> String {
        return "FORMATTED"
    }

    private func attributes(_ text: RichText, formatDate: ((Int32, MessageTextEntityType.DateTimeFormat) -> String)?) -> (String, [NSAttributedString.Key: Any]) {
        let string = attributedStringForRichText(text, styleStack: self.stack(), formatDate: formatDate)
        XCTAssertGreaterThan(string.length, 0)
        return (string.string, string.attributes(at: 0, effectiveRange: nil))
    }

    private var dateText: RichText {
        return .textDate(text: .plain("2026-08-17"), date: 1_776_000_000,
                         format: .full(timeFormat: .short, dateFormat: .long, dayOfWeek: false))
    }

    /// The rendered (V2) path: link-coloured, and carrying the tap attribute.
    func test_formattedDate_rendersAsALink() {
        let (text, attributes) = self.attributes(self.dateText, formatDate: self.format)
        XCTAssertEqual(text, "FORMATTED", "the host-supplied formatter produces the displayed text")
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, self.linkColor,
                       "a formatted date must read as a link, like a FormattedDate entity does")
        XCTAssertEqual(attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Date)] as? Int32,
                       1_776_000_000, "the timestamp drives the tap action")
    }

    /// A date with **no** `format` must still read and behave as a link. Every client-composed rich
    /// message produces one — `ChatInputContentInstantPage.richText(from:)` hard-codes `format: nil`
    /// because `ChatInputInlineEntity.date` carries only the timestamp — and the wire maps `flags == 0`
    /// to nil as well. `StringWithAppliedEntities` colours and stamps a `FormattedDate` entity
    /// regardless of its format (the format only decides whether the displayed text is substituted),
    /// so a rich bubble must not silently demote the same entity to plain body text.
    func test_formattedDate_withoutAFormat_isStillALink() {
        let dateText = RichText.textDate(text: .plain("2026-08-17"), date: 1_776_000_000, format: nil)
        let (text, attributes) = self.attributes(dateText, formatDate: self.format)
        XCTAssertEqual(text, "2026-08-17", "with no format there is nothing to autoformat: the literal text stands")
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, self.linkColor,
                       "a format-less date is still a link, exactly as in a plain text message")
        XCTAssertEqual(attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Date)] as? Int32,
                       1_776_000_000, "the timestamp must still drive the tap action")
    }

    /// No underline: `.link(false)` is colour-only, matching the entity path's default
    /// (`underlineLinks && underlineAllLinks` is off for chat text).
    func test_formattedDate_isNotUnderlined() {
        let (_, attributes) = self.attributes(self.dateText, formatDate: self.format)
        XCTAssertNil(attributes[.underlineStyle])
    }

    /// The V1 reader supplies no formatter and renders the server's literal text; it is deliberately
    /// left in body colour rather than turning every reader date blue.
    func test_withoutAFormatter_theReaderPathIsUnchanged() {
        let (text, attributes) = self.attributes(self.dateText, formatDate: nil)
        XCTAssertEqual(text, "2026-08-17")
        XCTAssertEqual(attributes[.foregroundColor] as? UIColor, self.bodyColor)
        XCTAssertNil(attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Date)])
    }

    /// A date inside a link keeps the link's own destination — pushing `.link(false)` for the colour
    /// must not shadow the enclosing URL attribute.
    func test_dateInsideALink_keepsTheUrl() {
        let url = InstantPageUrlItem(url: "https://telegram.org", webpageId: nil)
        let string = attributedStringForRichText(self.dateText, styleStack: self.stack(), url: url,
                                                 formatDate: self.format)
        let attributes = string.attributes(at: 0, effectiveRange: nil)
        XCTAssertEqual((attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? InstantPageUrlItem)?.url,
                       "https://telegram.org")
    }
}
