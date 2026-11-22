import XCTest
import UIKit
@testable import Display

/// `ImmediateTextView`'s links for VoiceOver: the tappable ranges with their words, the text without image
/// attachments, and activation following the first link.
final class TextLinkAccessibilityTests: XCTestCase {
    private let urlKey = NSAttributedString.Key(rawValue: "TestURL")

    private func makeTextView() -> ImmediateTextView {
        let text = NSMutableAttributedString(string: "Not on Telegram. ")
        text.append(NSAttributedString(string: "Invite ", attributes: [self.urlKey: "invite"]))
        text.append(NSAttributedString(string: ">", attributes: [self.urlKey: "invite", .attachment: NSTextAttachment()]))
        let view = ImmediateTextView()
        view.attributedText = text
        let urlKey = self.urlKey
        view.highlightAttributeAction = { attributes in
            return attributes[urlKey] != nil ? urlKey : nil
        }
        return view
    }

    func testLinksAreTheTappableWords() {
        let view = self.makeTextView()
        let links = view.accessibilityLinks()
        XCTAssertEqual(links.map { $0.text }, ["Invite"])
        XCTAssertEqual(links.first?.index, 17)
        XCTAssertEqual(view.accessibilityDisplayedText, "Not on Telegram. Invite")
    }

    func testActivationFollowsTheFirstLink() {
        let view = self.makeTextView()
        var tapped: [String] = []
        view.tapAttributeAction = { attributes, _ in
            tapped.append(attributes[self.urlKey] as? String ?? "")
        }
        view.isAccessibilityElement = true
        XCTAssertTrue(view.accessibilityActivate())
        XCTAssertEqual(tapped, ["invite"])
    }

    func testTextWithoutLinksHasNone() {
        let view = ImmediateTextView()
        view.attributedText = NSAttributedString(string: "Plain")
        XCTAssertTrue(view.accessibilityLinks().isEmpty)
    }
}
