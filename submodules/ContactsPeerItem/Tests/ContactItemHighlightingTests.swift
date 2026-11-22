import XCTest
import ContactsPeerItem

/// Folding iPhone Duo ends the split view, and the split clears the chat it highlighted in its masters with
/// `updateNavigationCustomData(nil, progress: 0.0)`. Contacts kept that progress beside no chat, so every row on
/// screen at that moment took `1 - 0` as its highlight and stayed gray.
final class ContactItemHighlightingTests: XCTestCase {
    func test_clearingTheSplitSelection_leavesUnselectedRowsUnhighlighted() {
        let highlighting = ContactItemHighlighting()
        highlighting.update(chatLocation: nil, progress: 0.0)
        XCTAssertEqual(highlighting.highlightAlpha(isSelected: false), 0.0)
    }

    func test_clearingTheSplitSelection_keepsAPressedRowFullyHighlighted() {
        let highlighting = ContactItemHighlighting()
        highlighting.update(chatLocation: nil, progress: 0.0)
        XCTAssertEqual(highlighting.highlightAlpha(isSelected: true), 1.0)
    }

    func test_noSelection_highlightsOnlyAPressedRow() {
        let highlighting = ContactItemHighlighting()
        XCTAssertEqual(highlighting.highlightAlpha(isSelected: false), 0.0)
        XCTAssertEqual(highlighting.highlightAlpha(isSelected: true), 1.0)
    }
}
