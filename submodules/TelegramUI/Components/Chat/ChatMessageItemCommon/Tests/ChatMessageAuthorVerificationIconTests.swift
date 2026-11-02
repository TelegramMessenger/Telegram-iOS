import XCTest
import UIKit
import ChatMessageItemCommon

/// A bubble's author line draws the sender's third-party verification icon left of the name, as the chat header does:
/// the icon takes the name's place, the name follows it, and the name's width budget loses what the icon takes.
final class ChatMessageAuthorVerificationIconTests: XCTestCase {
    private let nameFrame = CGRect(x: 12.0, y: 7.0, width: 84.0, height: 18.0)

    /// The chat header's metrics: a 20pt icon, 4pt before the name.
    func testMetricsMatchChatHeader() {
        XCTAssertEqual(ChatMessageAuthorVerificationIcon.size, CGSize(width: 20.0, height: 20.0))
        XCTAssertEqual(ChatMessageAuthorVerificationIcon.spacing, 4.0)
    }

    /// Without an icon nothing moves and the name keeps its whole width.
    func testNoIconKeepsName() {
        XCTAssertEqual(ChatMessageAuthorVerificationIcon.leadingWidth(iconSize: nil), 0.0)
        let layout = ChatMessageAuthorVerificationIcon.layout(nameFrame: self.nameFrame, iconSize: nil)
        XCTAssertEqual(layout.name, self.nameFrame)
        XCTAssertNil(layout.icon)
    }

    /// The icon and its spacing come out of the name's width budget.
    func testLeadingWidth() {
        XCTAssertEqual(ChatMessageAuthorVerificationIcon.leadingWidth(iconSize: ChatMessageAuthorVerificationIcon.size), 24.0)
    }

    /// The icon starts where the name would have, and the name follows it after the spacing, keeping its size.
    func testIconTakesNamePlace() {
        let layout = ChatMessageAuthorVerificationIcon.layout(nameFrame: self.nameFrame, iconSize: ChatMessageAuthorVerificationIcon.size)
        guard let icon = layout.icon else {
            XCTFail("no icon frame")
            return
        }
        XCTAssertEqual(icon.minX, self.nameFrame.minX)
        XCTAssertEqual(icon.size, ChatMessageAuthorVerificationIcon.size)
        XCTAssertEqual(layout.name.minX, icon.maxX + ChatMessageAuthorVerificationIcon.spacing)
        XCTAssertEqual(layout.name.minX - self.nameFrame.minX, ChatMessageAuthorVerificationIcon.leadingWidth(iconSize: icon.size))
        XCTAssertEqual(layout.name.size, self.nameFrame.size)
        XCTAssertEqual(layout.name.minY, self.nameFrame.minY)
    }

    /// The icon is centred on the name's line, as the right-side emoji status is.
    func testIconCentredOnNameLine() {
        let layout = ChatMessageAuthorVerificationIcon.layout(nameFrame: self.nameFrame, iconSize: ChatMessageAuthorVerificationIcon.size)
        guard let icon = layout.icon else {
            XCTFail("no icon frame")
            return
        }
        XCTAssertEqual(icon.minY, self.nameFrame.minY + floor((self.nameFrame.height - icon.height) / 2.0))
    }
}
