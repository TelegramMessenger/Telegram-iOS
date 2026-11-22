import XCTest
import SwiftSignalKit
import TelegramCore
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// widget-sandbox v0.2 (W2 plan, Task 2): the requests a bubble's widget has on their way to its bot. Each outcome is
/// delivered once, and every request in flight is cancelled when the bubble shows another message and with the bubble.
final class MessageWidgetRequestsTests: XCTestCase {
    func testAnAnswerIsDeliveredOnce() {
        let requests = MessageWidgetRequests()
        var outcomes: [MessageWidgetRequestOutcome] = []
        requests.send(id: 1, .single(Data("pong".utf8)), deliver: { outcomes.append($0) })
        XCTAssertEqual(outcomes, [.answered(Data("pong".utf8))])
    }

    func testEachErrorIsDeliveredAsItsOutcome() {
        let requests = MessageWidgetRequests()
        var outcomes: [MessageWidgetRequestOutcome] = []
        requests.send(id: 1, .fail(.timeout), deliver: { outcomes.append($0) })
        requests.send(id: 2, .fail(.rateLimited), deliver: { outcomes.append($0) })
        requests.send(id: 3, .fail(.failed), deliver: { outcomes.append($0) })
        XCTAssertEqual(outcomes, [.timeout, .rateLimited, .failed])
    }

    /// The bubble shows another message (its widget is destroyed): the requests in flight are cancelled and deliver
    /// nothing; a later request runs.
    func testCancelAllDisposesTheRequestsInFlight() {
        let requests = MessageWidgetRequests()
        var disposed = false
        var outcomes: [MessageWidgetRequestOutcome] = []
        let pending = Promise<Data?>()
        requests.send(id: 1, Signal { subscriber in
            let inner = pending.get().start(next: { subscriber.putNext($0) })
            return ActionDisposable {
                disposed = true
                inner.dispose()
            }
        }, deliver: { outcomes.append($0) })
        requests.cancelAll()
        XCTAssertTrue(disposed)
        pending.set(.single(Data("late".utf8)))
        XCTAssertEqual(outcomes, [])
        requests.send(id: 1, .single(Data("again".utf8)), deliver: { outcomes.append($0) })
        XCTAssertEqual(outcomes, [.answered(Data("again".utf8))])
    }

    func testReleasingTheRequestsCancelsThem() {
        var disposed = false
        do {
            let requests = MessageWidgetRequests()
            requests.send(id: 1, Signal { _ in
                return ActionDisposable {
                    disposed = true
                }
            }, deliver: { _ in })
        }
        XCTAssertTrue(disposed)
    }

    /// W2 final review, Important 1: request ids restart at 1 when a widget restarts under the same message. The old
    /// request's completion, already queued for the main queue when it was cancelled, must not cancel the new request
    /// with the same id (which would then never get an outcome).
    func testAStaleCompletionDoesNotCancelANewRequestWithTheSameId() {
        let requests = MessageWidgetRequests()
        let posted = DispatchSemaphore(value: 0)
        requests.send(id: 1, Signal { subscriber in
            DispatchQueue.global().async {
                subscriber.putNext(Data("old".utf8))
                subscriber.putCompletion()
                posted.signal()
            }
            return EmptyDisposable
        }, deliver: { _ in })
        // The old answer and its completion are now queued for the main queue (deliverOnMainQueue hops from global).
        posted.wait()
        var disposed = false
        requests.send(id: 1, Signal { _ in
            return ActionDisposable {
                disposed = true
            }
        }, deliver: { _ in })
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.3))
        XCTAssertFalse(disposed, "the old request's completion cancelled the new request with the same id")
    }
}
