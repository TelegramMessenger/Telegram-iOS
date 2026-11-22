import XCTest
import UIKit
import Display
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

    // The Done checkmark and the close X show no text: they are labelled from the bar's strings.
    func test_iconSentinels_areLabelledFromStrings() {
        let strings = NavigationBarStrings(back: "Back", close: "Close", more: "More", done: "Done")
        XCTAssertEqual(navigationButtonIconLabel(.icon(imageName: "Navigation/Done"), strings: strings), "Done")
        XCTAssertEqual(navigationButtonIconLabel(.text(title: "___done", isBold: true), strings: strings), "Done")
        XCTAssertEqual(navigationButtonIconLabel(.icon(imageName: "Navigation/Close"), strings: strings), "Close")
        XCTAssertNil(navigationButtonIconLabel(.icon(imageName: "Chat List/ComposeIcon"), strings: strings))
        XCTAssertNil(navigationButtonIconLabel(.icon(imageName: "Navigation/Done"), strings: NavigationBarStrings(back: "Back", close: "Close", more: "More")))
    }
}
