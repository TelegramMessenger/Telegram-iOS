import XCTest
import UIKit
@testable import NavigationBarComponent

final class NavigationButtonAccessibilityTests: XCTestCase {
    // A text button (the chat list's Edit) is labelled with the text it shows.
    func test_textButton_isLabelledWithItsTitle() {
        XCTAssertEqual(navigationButtonTextLabel(.text(title: "Edit", isBold: false)), "Edit")
    }

    // The `___done` sentinel draws the checkmark icon: its title is not a label.
    func test_sentinelTitle_isNoLabel() {
        XCTAssertNil(navigationButtonTextLabel(.text(title: "___done", isBold: true)))
        XCTAssertNil(navigationButtonTextLabel(.text(title: "", isBold: false)))
    }

    func test_iconButton_hasNoTextLabel() {
        XCTAssertNil(navigationButtonTextLabel(.icon(imageName: "Chat List/ComposeIcon")))
    }
}
