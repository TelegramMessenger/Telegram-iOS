import XCTest
@testable import MessageWidget

/// widget-sandbox v0.5.0 (the final review's #6): an account's wallet availability belongs to the host object that set it
/// last, so an older account context released after a newer one took over does not take the wallet away from widgets.
final class WalletAvailabilityTests: XCTestCase {
    func testAnOlderOwnerReleasingLeavesTheNewerOnesAnswer() {
        let accountId: Int64 = 9_000_001
        let old = NSObject()
        let new = NSObject()
        MessageWidgetWalletAvailability.set(true, accountId: accountId, owner: ObjectIdentifier(old))
        MessageWidgetWalletAvailability.set(true, accountId: accountId, owner: ObjectIdentifier(new))
        MessageWidgetWalletAvailability.release(accountId: accountId, owner: ObjectIdentifier(old))
        XCTAssertTrue(MessageWidgetWalletAvailability.isReady(accountId: accountId))
        MessageWidgetWalletAvailability.release(accountId: accountId, owner: ObjectIdentifier(new))
        XCTAssertFalse(MessageWidgetWalletAvailability.isReady(accountId: accountId))
    }

    /// Only a change posts: the bubbles lay out again once.
    func testOnlyAChangePosts() {
        let accountId: Int64 = 9_000_002
        let owner = NSObject()
        var posts = 0
        let observer = NotificationCenter.default.addObserver(forName: MessageWidgetAvailability.didChangeNotification, object: nil, queue: nil, using: { _ in
            posts += 1
        })
        defer {
            NotificationCenter.default.removeObserver(observer)
        }
        MessageWidgetWalletAvailability.set(true, accountId: accountId, owner: ObjectIdentifier(owner))
        MessageWidgetWalletAvailability.set(true, accountId: accountId, owner: ObjectIdentifier(owner))
        XCTAssertEqual(posts, 1)
        MessageWidgetWalletAvailability.release(accountId: accountId, owner: ObjectIdentifier(owner))
        XCTAssertEqual(posts, 2)
    }
}
