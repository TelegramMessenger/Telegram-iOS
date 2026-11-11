import XCTest
import UIKit
@testable import Display

/// `accessibilityTextLinks` / `accessibilityDisplayedText` and `AccessibilityAreaNode.applyAccessibilityText`: a text with
/// links as one VoiceOver element (footers like "Everyone can see your birthday. Change >").
final class AccessibilityTextLinksTests: XCTestCase {
    private let urlKey = NSAttributedString.Key(rawValue: "TestURL")

    private func makeText() -> NSAttributedString {
        let text = NSMutableAttributedString(string: "Log into ")
        text.append(NSAttributedString(string: "Telegram ", attributes: [self.urlKey: "desktop"]))
        text.append(NSAttributedString(string: "Desktop", attributes: [self.urlKey: "desktop", .font: UIFont.boldSystemFont(ofSize: 12.0)]))
        text.append(NSAttributedString(string: " or "))
        text.append(NSAttributedString(string: "Web ", attributes: [self.urlKey: "web"]))
        text.append(NSAttributedString(string: ">", attributes: [self.urlKey: "web", .attachment: NSTextAttachment()]))
        return text
    }

    func testAdjacentRunsWithOneValueAreOneLink() {
        let links = accessibilityTextLinks(in: self.makeText(), attribute: self.urlKey)
        XCTAssertEqual(links.map { $0.text }, ["Telegram Desktop", "Web"])
        XCTAssertEqual(links.map { $0.value as? String }, ["desktop", "web"])
    }

    func testDisplayedTextDropsAttachments() {
        XCTAssertEqual(accessibilityDisplayedText(self.makeText()), "Log into Telegram Desktop or Web")
    }

    func testAreaWithLinksIsALinkWithActions() {
        let area = AccessibilityAreaNode()
        var opened: [String] = []
        area.applyAccessibilityText(self.makeText(), linkAttribute: self.urlKey, open: { value in
            opened.append(value as? String ?? "")
        })
        XCTAssertEqual(area.accessibilityLabel, "Log into Telegram Desktop or Web")
        XCTAssertTrue(area.accessibilityTraits.contains(.link))
        XCTAssertTrue(area.accessibilityActivate())
        XCTAssertEqual(opened, ["desktop"])
        XCTAssertEqual(area.view.accessibilityCustomActions?.map { $0.name }, ["Telegram Desktop", "Web"])
    }

    func testAreaWithoutHandlerIsStaticText() {
        let area = AccessibilityAreaNode()
        area.applyAccessibilityText(self.makeText(), linkAttribute: self.urlKey, open: nil)
        XCTAssertEqual(area.accessibilityTraits, .staticText)
        XCTAssertFalse(area.accessibilityActivate())
        XCTAssertNil(area.view.accessibilityCustomActions)
    }

    func testReapplyingTheSameTextKeepsActionsAndUsesTheLatestHandler() {
        let area = AccessibilityAreaNode()
        var opened: [String] = []
        area.applyAccessibilityText(self.makeText(), linkAttribute: self.urlKey, open: { _ in
            opened.append("old")
        })
        let actions = area.view.accessibilityCustomActions
        area.applyAccessibilityText(self.makeText(), linkAttribute: self.urlKey, open: { value in
            opened.append("new:\(value as? String ?? "")")
        })
        XCTAssertEqual(area.view.accessibilityCustomActions?.map { $0.name }, ["Telegram Desktop", "Web"])
        XCTAssertTrue(area.accessibilityActivate())
        // An action built for the first text still reaches the latest handler.
        if let webAction = actions?.last, let handler = webAction.actionHandler {
            XCTAssertTrue(handler(webAction))
        } else {
            XCTFail("no custom actions")
        }
        XCTAssertEqual(opened, ["new:desktop", "new:web"])
    }
}
