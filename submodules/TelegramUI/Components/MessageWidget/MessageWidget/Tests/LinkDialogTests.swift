import XCTest
@testable import MessageWidget

/// SDK v1 §5.2 (V2b plan, Task 8): one link dialog at a time; an action that arrives while one is shown is dropped.
final class LinkDialogTests: XCTestCase {
    func testASecondRequestWhileShownIsDropped() {
        let dialog = MessageWidgetLinkDialog()
        let shown = NSObject()
        var opened = 0
        XCTAssertTrue(dialog.request { displayUpdated in
            opened += 1
            displayUpdated(shown)
        })
        XCTAssertFalse(dialog.request { _ in
            opened += 1
        })
        XCTAssertEqual(opened, 1)
    }

    func testARequestAfterDismissalIsAllowed() {
        let dialog = MessageWidgetLinkDialog()
        let shown = NSObject()
        var dismiss: ((AnyObject?) -> Void)?
        XCTAssertTrue(dialog.request { displayUpdated in
            displayUpdated(shown)
            dismiss = displayUpdated
        })
        dismiss?(nil)
        var opened = false
        XCTAssertTrue(dialog.request { _ in
            opened = true
        })
        XCTAssertTrue(opened)
    }

    /// A request whose open shows no dialog (it was cancelled before one appeared) blocks nothing.
    func testARequestThatShowsNothingDoesNotBlock() {
        let dialog = MessageWidgetLinkDialog()
        XCTAssertTrue(dialog.request { _ in })
        XCTAssertTrue(dialog.request { _ in })
    }

    /// An earlier dialog's late dismissal does not unblock the one shown now.
    func testALateDismissalOfAnEarlierDialogKeepsTheCurrentOne() {
        let dialog = MessageWidgetLinkDialog()
        let earlier = NSObject()
        let current = NSObject()
        var first: ((AnyObject?) -> Void)?
        XCTAssertTrue(dialog.request { displayUpdated in
            first = displayUpdated
            displayUpdated(earlier)
        })
        first?(nil)
        XCTAssertTrue(dialog.request { displayUpdated in
            displayUpdated(current)
        })
        first?(nil)
        XCTAssertFalse(dialog.request { _ in })
    }

    /// Final review I2: a dialog that is gone without reporting it (never presented for want of a window, or dismissed
    /// by a path that does not call back) does not keep every later link out.
    func testAReleasedDialogNoLongerBlocks() {
        let dialog = MessageWidgetLinkDialog()
        XCTAssertTrue(dialog.request { displayUpdated in
            let presented = NSObject()
            displayUpdated(presented)
        })
        var opened = false
        XCTAssertTrue(dialog.request { _ in
            opened = true
        })
        XCTAssertTrue(opened)
    }
}
