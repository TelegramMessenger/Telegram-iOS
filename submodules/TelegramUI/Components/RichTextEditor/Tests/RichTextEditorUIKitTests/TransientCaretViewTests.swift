#if canImport(UIKit)
import XCTest
import UIKit
@testable import RichTextEditorUIKit

final class TransientCaretViewTests: XCTestCase {
    func test_startsHidden() {
        let v = TransientCaretView(frame: .zero)
        XCTAssertTrue(v.isHidden)
        XCTAssertEqual(v.alpha, 0, accuracy: 0.001)
        XCTAssertFalse(v.isUserInteractionEnabled)
    }

    func test_accentColorSetsBackground() {
        let v = TransientCaretView(frame: .zero)
        v.accentColor = .red
        XCTAssertEqual(v.backgroundColor, .red)
    }

    func test_showUnhidesAndOpaque_hideHidesAndClear() {
        let v = TransientCaretView(frame: .zero)
        v.show(animated: false)
        XCTAssertFalse(v.isHidden)
        XCTAssertEqual(v.alpha, 1, accuracy: 0.001)
        v.hide(animated: false)
        XCTAssertTrue(v.isHidden)
        XCTAssertEqual(v.alpha, 0, accuracy: 0.001)
    }
}
#endif
