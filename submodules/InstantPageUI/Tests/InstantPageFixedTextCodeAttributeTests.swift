import XCTest
import UIKit
import TelegramCore
import TextFormat
@testable import InstantPageUI

/// A `RichText.fixed` run is the InstantPage twin of a `.Code` message entity. In a plain text message
/// `StringWithAppliedEntities` stamps that range with `TelegramTextAttributes.Code`, and tapping it copies
/// the text. A rich message (anything with a table, heading, list…) only switched the font, so the same
/// inline code — typically a command in a table cell — could not be copied by tap.
final class InstantPageFixedTextCodeAttributeTests: XCTestCase {
    private let codeKey = NSAttributedString.Key(rawValue: TelegramTextAttributes.Code)

    private func stack() -> InstantPageTextStyleStack {
        let stack = InstantPageTextStyleStack()
        stack.push(.fontSize(17.0))
        stack.push(.textColor(.darkGray))
        stack.push(.linkColor(.blue))
        return stack
    }

    private func render(_ text: RichText) -> NSAttributedString {
        return attributedStringForRichText(text, styleStack: self.stack())
    }

    func test_fixedRun_carriesTheCodeAttribute() {
        let string = self.render(.fixed(.plain("/my_keys")))
        XCTAssertEqual(string.string, "/my_keys")
        var range = NSRange()
        let value = string.attribute(self.codeKey, at: 0, effectiveRange: &range) as? String
        XCTAssertEqual(value, "/my_keys", "the tap handler copies this value")
        XCTAssertEqual(range, NSRange(location: 0, length: string.length), "the whole run is tappable")
    }

    func test_nestedFormatting_copiesThePlainText() {
        let string = self.render(.fixed(.concat([.bold(.plain("/reset")), .plain("_devices")])))
        XCTAssertEqual(string.attribute(self.codeKey, at: 0, effectiveRange: nil) as? String, "/reset_devices")
        XCTAssertEqual(string.attribute(self.codeKey, at: string.length - 1, effectiveRange: nil) as? String, "/reset_devices")
    }

    func test_onlyTheFixedRunIsStamped() {
        let string = self.render(.concat([.plain("Run "), .fixed(.plain("/transfer")), .plain(" now")]))
        XCTAssertNil(string.attribute(self.codeKey, at: 0, effectiveRange: nil), "body text is not code")
        let codeStart = ("Run " as NSString).length
        XCTAssertEqual(string.attribute(self.codeKey, at: codeStart, effectiveRange: nil) as? String, "/transfer")
        XCTAssertNil(string.attribute(self.codeKey, at: string.length - 1, effectiveRange: nil))
    }

    /// A link wrapping code keeps its URL: the bubble resolves URLs before entities, so the link still wins.
    func test_fixedInsideALink_keepsTheUrl() {
        let string = self.render(.url(text: .fixed(.plain("example")), url: "https://example.com", webpageId: nil))
        let url = string.attribute(NSAttributedString.Key(rawValue: TelegramTextAttributes.URL), at: 0, effectiveRange: nil) as? InstantPageUrlItem
        XCTAssertEqual(url?.url, "https://example.com")
    }

    func test_emptyFixedRun_staysEmpty() {
        let string = self.render(.fixed(.empty))
        XCTAssertEqual(string.length, 0)
    }
}
