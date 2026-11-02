import XCTest
import SwiftSignalKit
import TelegramCore
import WalletContext
import MessageWidget
@testable import ChatMessageWidgetBubbleContentNode

/// widget-sandbox v0.5.0 (sdk-v1 §2.18, §5.13; the v0.5.0 plan's decisions 6–9): a widget's wallet call through the
/// bubbles' coordinator: the wallet's part (`perform`), then the bot's query with the outcome and the call's `data`, then
/// the bot's answer to the widget; one window at a time; the query held outside any bubble.
final class MessageWidgetWalletCallsTests: XCTestCase {
    private let card = EngineUserWallet(address: "UQ" + String(repeating: "a", count: 46), balance: 5, signing: nil)
    private let transaction = MessageWidgetWalletCall.sendTransaction(json: "{\"messages\":[]}", data: Data("paid:1".utf8))

    private func pump(until done: () -> Bool) {
        let deadline = Date(timeIntervalSinceNow: 2.0)
        while !done() && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.01))
        }
    }

    func testAPaymentAsksTheBotWithTheSentTransaction() {
        let calls = MessageWidgetWalletCalls()
        var asked: [(BotWidgetQueryType, Data)] = []
        var outcomes: [MessageWidgetRequestOutcome] = []
        calls.handle(call: self.transaction, hasBot: true, perform: { done in
            done(.success(.sent(msgHash: "aGFzaA==", wallet: self.card)))
        }, query: { type, data in
            asked.append((type, data))
            return .single(Data("thanks".utf8))
        }, completion: { outcomes.append($0) })
        self.pump(until: { !outcomes.isEmpty })
        XCTAssertEqual(asked.map(\.0), [.sentTransaction(wallet: self.card, msgHash: "aGFzaA==")])
        XCTAssertEqual(asked.map(\.1), [Data("paid:1".utf8)])
        XCTAssertEqual(outcomes, [.answered(Data("thanks".utf8))])
    }

    func testASignatureAsksTheBotWithTonConnectsResult() {
        let calls = MessageWidgetWalletCalls()
        var asked: [BotWidgetQueryType] = []
        var outcomes: [MessageWidgetRequestOutcome] = []
        calls.handle(call: .signData(json: "{\"type\":\"text\",\"text\":\"x\"}", data: Data("sign:1".utf8)), hasBot: true, perform: { done in
            done(.success(.signed(json: "{\"signature\":\"c2ln\"}", wallet: self.card)))
        }, query: { type, _ in
            asked.append(type)
            return .single(nil)
        }, completion: { outcomes.append($0) })
        self.pump(until: { !outcomes.isEmpty })
        XCTAssertEqual(asked, [.signData(wallet: self.card, json: "{\"signature\":\"c2ln\"}")])
        XCTAssertEqual(outcomes, [.answered(nil)])
    }

    /// The wallet's failures keep their codes (a short balance, after the top-up's offer, is the wallet's refusal) and ask
    /// the bot nothing; the query's map as a request's.
    func testFailuresReachTheWidgetAsTheirCodes() {
        for (failure, outcome) in [(WalletContext.WidgetWalletFailure.rejected, MessageWidgetRequestOutcome.rejected), (.badRequest, .badRequest),
                                   (.insufficientBalance, .badRequest), (.failed, .failed)] {
            let calls = MessageWidgetWalletCalls()
            var outcomes: [MessageWidgetRequestOutcome] = []
            var asked = 0
            calls.handle(call: self.transaction, hasBot: true, perform: { done in done(.failure(failure)) }, query: { _, _ in
                asked += 1
                return .single(nil)
            }, completion: { outcomes.append($0) })
            XCTAssertEqual(outcomes, [outcome])
            XCTAssertEqual(asked, 0)
        }
        let calls = MessageWidgetWalletCalls()
        var outcomes: [MessageWidgetRequestOutcome] = []
        calls.handle(call: self.transaction, hasBot: true, perform: { done in done(.success(.sent(msgHash: "h", wallet: self.card))) }, query: { _, _ in
            return .fail(.timeout)
        }, completion: { outcomes.append($0) })
        self.pump(until: { !outcomes.isEmpty })
        XCTAssertEqual(outcomes, [.timeout])
    }

    /// Without the message's bot there is nobody to name in the window: FAILED, and no window.
    func testWithoutABotNothingOpens() {
        let calls = MessageWidgetWalletCalls()
        var performed = 0
        var outcomes: [MessageWidgetRequestOutcome] = []
        calls.handle(call: self.transaction, hasBot: false, perform: { _ in performed += 1 }, query: { _, _ in .single(nil) }, completion: { outcomes.append($0) })
        XCTAssertEqual(performed, 0)
        XCTAssertEqual(outcomes, [.failed])
    }

    /// One wallet window at a time: a call while one is up is declined at once; once it closes, the next opens.
    func testOneWindowAtATime() {
        let calls = MessageWidgetWalletCalls()
        var pending: ((Result<MessageWidgetWallet.Outcome, WalletContext.WidgetWalletFailure>) -> Void)?
        var outcomes: [String] = []
        calls.handle(call: self.transaction, hasBot: true, perform: { pending = $0 }, query: { _, _ in .single(nil) }, completion: { outcomes.append("first:\($0)") })
        calls.handle(call: self.transaction, hasBot: true, perform: { _ in XCTFail("a second window") }, query: { _, _ in .single(nil) }, completion: { outcomes.append("second:\($0)") })
        XCTAssertEqual(outcomes, ["second:rejected"])
        pending?(.failure(.rejected))
        var thirdOpened = false
        calls.handle(call: self.transaction, hasBot: true, perform: { done in
            thirdOpened = true
            done(.failure(.rejected))
        }, query: { _, _ in .single(nil) }, completion: { _ in })
        XCTAssertTrue(thirdOpened)
        XCTAssertEqual(outcomes, ["second:rejected", "first:rejected"])
    }

    /// The final review's #1: a window that leaves any way but its own buttons (an account switch, a navigation stack
    /// replaced) ends its call as declined, so the one-window flag and the widget's gate are free again.
    func testAWindowReleasedBeforeTheConfirmationEndsTheCallDeclined() {
        let calls = MessageWidgetWalletCalls()
        var outcomes: [MessageWidgetRequestOutcome] = []
        var lifetime: MessageWidgetWalletWindowLifetime?
        calls.handle(call: self.transaction, hasBot: true, perform: { done in
            lifetime = MessageWidgetWalletWindowLifetime(end: { done(.failure(.rejected)) })
        }, query: { _, _ in .single(nil) }, completion: { outcomes.append($0) })
        XCTAssertNotNil(lifetime)
        XCTAssertEqual(outcomes, [])
        lifetime = nil
        XCTAssertEqual(outcomes, [.rejected])
        var opened = false
        calls.handle(call: self.transaction, hasBot: true, perform: { done in
            opened = true
            done(.failure(.rejected))
        }, query: { _, _ in .single(nil) }, completion: { _ in })
        XCTAssertTrue(opened)
    }

    /// Once the confirmation has begun, the window's release ends nothing: the send's own outcome does, so a payment in
    /// flight is never reported as declined.
    func testAWindowReleasedDuringTheConfirmationEndsNothing() {
        var ended = 0
        var lifetime: MessageWidgetWalletWindowLifetime? = MessageWidgetWalletWindowLifetime(end: { ended += 1 })
        lifetime?.beginConfirmation()
        lifetime = nil
        XCTAssertEqual(ended, 0)
    }

    /// The fix-wave review's finding: the wiring. The lifetime's only strong hold is the window it is attached to: alive with
    /// the window, its release ends the call.
    func testTheLifetimeLivesAndDiesWithItsWindow() {
        var ended = 0
        var window: NSObject? = MessageWidgetWalletWindowLifetime.attach(end: { ended += 1 }, to: { _ in NSObject() })
        XCTAssertNotNil(window)
        XCTAssertEqual(ended, 0, "the window holds its lifetime")
        window = nil
        XCTAssertEqual(ended, 1)
    }

    /// Confirm begins the confirmation while the window lives, after which its release ends nothing; a Confirm that finds
    /// the lifetime gone sends nothing.
    func testConfirmBeginsTheConfirmationWhileTheWindowLives() {
        var ended = 0
        var beginConfirmation: (() -> Bool)?
        var window: NSObject? = MessageWidgetWalletWindowLifetime.attach(end: { ended += 1 }, to: { begin in
            beginConfirmation = begin
            return NSObject()
        })
        XCTAssertNotNil(window)
        XCTAssertEqual(beginConfirmation?(), true)
        window = nil
        XCTAssertEqual(ended, 0, "a payment in flight is never reported as declined")
        XCTAssertEqual(beginConfirmation?(), false, "a Confirm after the window went sends nothing")
    }

    /// The query that reports a payment is the coordinator's, not the caller's: dropping everything the caller holds (the
    /// bubble's requests cancelled, the bubble gone) neither disposes it nor loses its answer; it is subscribed once.
    func testThePaymentsQueryOutlivesItsCaller() {
        let answer = ValuePipe<Data?>()
        var subscriptions = 0
        var disposals = 0
        var outcomes: [MessageWidgetRequestOutcome] = []
        do {
            let requests = MessageWidgetRequests()
            MessageWidgetWalletCalls.shared.handle(call: self.transaction, hasBot: true, perform: { done in
                done(.success(.sent(msgHash: "h", wallet: self.card)))
            }, query: { _, _ in
                return Signal { subscriber in
                    subscriptions += 1
                    let disposable = answer.signal().start(next: { value in
                        subscriber.putNext(value)
                        subscriber.putCompletion()
                    })
                    return ActionDisposable {
                        disposals += 1
                        disposable.dispose()
                    }
                }
            }, completion: { outcomes.append($0) })
            requests.cancelAll()
        }
        self.pump(until: { subscriptions == 1 })
        XCTAssertEqual(disposals, 0)
        answer.putNext(Data("late".utf8))
        self.pump(until: { !outcomes.isEmpty })
        XCTAssertEqual(outcomes, [.answered(Data("late".utf8))])
        XCTAssertEqual(subscriptions, 1)
    }
}
