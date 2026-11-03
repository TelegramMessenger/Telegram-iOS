import XCTest
@testable import NewsFeedSupport

/// The deferred Remove from Chats and the bar's toasts (spec §1.4, §1.5).
final class NewsChannelBarEffectsTests: XCTestCase {
    func testCommitPerformsOnceFromAnyNumberOfTriggers() {
        var performed = 0
        var finish: (() -> Void)?
        let action = NewsDeferredAction(perform: { completion in
            performed += 1
            finish = completion
        })
        // The toast's timeout, another toast, and the panel's teardown can all commit.
        action.commit()
        action.commit()
        XCTAssertEqual(performed, 1)
        XCTAssertEqual(action.state, .performing)
        finish?()
        action.commit()
        XCTAssertEqual(performed, 1)
        XCTAssertEqual(action.state, .done)
    }

    func testCompletionsRunOnceThePerformEnds() {
        var finish: (() -> Void)?
        let action = NewsDeferredAction(perform: { completion in
            finish = completion
        })
        var order: [String] = []
        action.commit(completion: { order.append("first") })
        action.commit(completion: { order.append("second") })
        XCTAssertEqual(order, [])
        finish?()
        XCTAssertEqual(order, ["first", "second"])
        action.commit(completion: { order.append("late") })
        XCTAssertEqual(order, ["first", "second", "late"])
    }

    // The bar lets go of the action when "+ Add to News" commits it, and the toast holding it fades out soon after:
    // a leave slower than that must still run the add that waits on it.
    func testThePerformsCompletionRunsAfterTheLastOutsideReferenceIsGone() {
        var finish: (() -> Void)?
        var completed = false
        var action: NewsDeferredAction? = NewsDeferredAction(perform: { completion in
            finish = completion
        })
        action?.commit(completion: { completed = true })
        action = nil
        finish?()
        XCTAssertTrue(completed)
    }

    func testUndoBeforeTheCommitSendsNothing() {
        var performed = 0
        let action = NewsDeferredAction(perform: { completion in
            performed += 1
            completion()
        })
        XCTAssertTrue(action.cancel())
        var completed = false
        action.commit(completion: { completed = true })
        XCTAssertEqual(performed, 0)
        XCTAssertFalse(completed)
        XCTAssertEqual(action.state, .cancelled)
    }

    func testUndoAfterTheCommitIsRefused() {
        let action = NewsDeferredAction(perform: { _ in })
        action.commit()
        XCTAssertFalse(action.cancel())
        XCTAssertEqual(action.state, .performing)
    }

    func testOnlyTheLeaveHasUndo() {
        XCTAssertEqual(NewsChannelToast.allCases.filter(\.hasUndo), [.removedFromChats])
        XCTAssertEqual(NewsChannelToast.removedFromChats.timeout, 5.0)
        XCTAssertNil(NewsChannelToast.archived.timeout)
    }

    func testToastsUseTheMockupsIcons() {
        XCTAssertEqual(NewsChannelToast.addedToNews.iconName, "News/Channel/ToastNews")
        XCTAssertEqual(NewsChannelToast.addedToChats.iconName, "News/Channel/ToastChats")
        XCTAssertEqual(NewsChannelToast.removedFromNews.iconName, "News/Channel/ToastNewsCrossed")
        XCTAssertEqual(NewsChannelToast.removedFromChats.iconName, "News/Channel/ToastChatsCrossed")
        XCTAssertEqual(NewsChannelToast.notificationsOn.iconName, NewsChannelMenuItem.notify.iconName)
        XCTAssertEqual(NewsChannelToast.notificationsOff.iconName, NewsChannelMenuItem.doNotNotify.iconName)
        XCTAssertEqual(NewsChannelToast.archived.iconName, NewsChannelMenuItem.archive.iconName)
        XCTAssertEqual(NewsChannelToast.unarchived.iconName, NewsChannelMenuItem.unarchive.iconName)
    }
}
