import XCTest
@testable import MessageWidget

/// widget-sandbox v0.2 through the facade (v0.2 W1 plan, Task 6): the message's context and the bot's state go into the
/// runtime at creation and on change (`setState`, no restart); a widget's request, copyText and watchPublicData come out
/// as bridge calls, and a request's outcome goes back in (`completeRequest`).
final class StateTests: MessageWidgetTestCase {
    private let ann = MessageWidgetViewer(id: 42, firstName: "Ann", lastName: "Lee", username: "ann_lee", isPremium: true)

    private var privateContext: MessageWidgetContext {
        return MessageWidgetContext(canQuery: true, backgroundQuery: true, chatType: .private, viewer: self.ann)
    }

    private func state(_ chatData: String?, _ publicData: String?) -> MessageWidgetState {
        return MessageWidgetState(chatData: chatData.map { Data($0.utf8) }, publicData: publicData.map { Data($0.utf8) })
    }

    /// `#b` fills the widget's top 200 × 60 (a div: profile 1 renders no form control), so a tap at (20, 20) clicks it;
    /// `script` runs after it.
    private func page(_ script: String) -> String {
        return "<!doctype html><style>body{margin:0}#b{display:block;width:200px;height:60px}</style><div id=b>b</div>"
            + "<script>const b = document.getElementById('b'); \(script)</script>"
    }

    private func tap(_ instance: MessageWidgetInstance) {
        instance.pointer(.down, at: CGPoint(x: 20.0, y: 20.0))
        instance.pointer(.up, at: CGPoint(x: 20.0, y: 20.0))
    }

    /// The private chat's context with Gram Wallet for the user (widget-sandbox v0.5.0, sdk-v1 §2.18).
    private var walletContext: MessageWidgetContext {
        var context = self.privateContext
        context.wallet = true
        return context
    }

    /// A user-friendly destination and a transaction to it, as a widget writes them.
    private let transaction = "{ messages: [{ address: 'EQ' + 'a'.repeat(46), amount: '1500000000', payload: 'te6/Aw==' }], valid_until: 1900000000 }"

    func testTheWidgetStartsWithItsContextAndState() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext, state: self.state("c", "p"))
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(instance.evaluateForTesting("[TelegramWidget.chatData, TelegramWidget.publicData, TelegramWidget.chatType, TelegramWidget.viewer.id].join()"), "c,p,private,42")
        instance.destroy()
    }

    func testSetStateFiresTheEventsWithoutRestarting() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext, state: self.state("c1", "p1"))
        _ = instance.layout(width: 300.0)
        _ = instance.evaluateForTesting("window.mark = 7; window.log = []; const W = TelegramWidget;"
            + "W.onEvent('chatDataChanged', () => log.push('chat:' + W.chatData)); W.onEvent('publicDataChanged', () => log.push('public:' + W.publicData)); 1")
        instance.setState(self.state("c2", "p2"))
        XCTAssertEqual(instance.evaluateForTesting("log.join() + '|' + window.mark"), "chat:c2,public:p2|7")
        // The same state again changes nothing.
        instance.setState(self.state("c2", "p2"))
        XCTAssertEqual(instance.evaluateForTesting("String(log.length)"), "2")
        instance.destroy()
    }

    /// A state passed before the boot is the state the widget starts with.
    func testAStateSetBeforeTheBootIsTheInitialState() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext, state: self.state("c1", nil))
        instance.setState(self.state("c0", "p0"))
        _ = instance.layout(width: 300.0)
        XCTAssertEqual(instance.evaluateForTesting("[TelegramWidget.chatData, TelegramWidget.publicData].join()"), "c0,p0")
        instance.destroy()
    }

    func testARequestRoundTrips() {
        let instance = self.make(self.page("b.onclick = () => TelegramWidget.request('vote').then(a => document.documentElement.dataset.log = a.result);"), context: self.privateContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { !calls.isEmpty }))
        XCTAssertEqual(calls, [.request(id: 1, data: Data("vote".utf8), wallet: false)])
        instance.completeRequest(id: 1, outcome: .answered(Data("ok".utf8)))
        XCTAssertTrue(self.pump(until: { instance.documentElementAttribute("data-log") == "ok" }))
        instance.destroy()
    }

    /// sdk-v1 §2.18: the widget has `TelegramWidget.wallet` only with the context's wallet.
    func testTheContextsWalletGivesTheWidgetTheWallet() {
        for (context, expected) in [(self.walletContext, "object"), (self.privateContext, "null")] {
            let instance = self.make("<!doctype html><p>x</p>", context: context)
            _ = instance.layout(width: 300.0)
            XCTAssertEqual(instance.evaluateForTesting("TelegramWidget.wallet === null ? 'null' : typeof TelegramWidget.wallet"), expected)
            instance.destroy()
        }
    }

    /// A request for the wallet carries the flag; a wallet call comes out with its checked transaction in TON Connect's
    /// JSON and its label, and goes back in with the wallet's own codes.
    func testAWalletCallRoundTrips() {
        let instance = self.make(self.page("b.onclick = () => TelegramWidget.request('pay', { wallet: true }).then(() => TelegramWidget.wallet.sendTransaction(\(self.transaction), 'paid'))"
            + ".then(a => document.documentElement.dataset.log = a.result, e => document.documentElement.dataset.log = e.code);"), context: self.walletContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { !calls.isEmpty }))
        XCTAssertEqual(calls, [.request(id: 1, data: Data("pay".utf8), wallet: true)])
        instance.completeRequest(id: 1, outcome: .answered(nil))
        XCTAssertTrue(self.pump(until: { calls.count == 2 }))
        let address = "EQ" + String(repeating: "a", count: 46)
        XCTAssertEqual(calls.last, .wallet(id: 2, call: .sendTransaction(json: "{\"messages\":[{\"address\":\"\(address)\",\"amount\":\"1500000000\",\"payload\":\"te6/Aw==\"}],\"valid_until\":1900000000}", data: Data("paid".utf8))))
        instance.completeRequest(id: 2, outcome: .rejected)
        XCTAssertTrue(self.pump(until: { instance.documentElementAttribute("data-log") == "REJECTED" }))
        instance.destroy()
    }

    /// A request's outcome has no wallet codes: `.rejected` and `.badRequest` are FAILED there.
    func testARequestsWalletOutcomeIsFailed() {
        let instance = self.make(self.page("b.onclick = () => TelegramWidget.request('vote').catch(e => document.documentElement.dataset.log = (document.documentElement.dataset.log || '') + e.code + ',');"), context: self.privateContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { calls.count == 1 }))
        instance.completeRequest(id: 1, outcome: .rejected)
        XCTAssertTrue(self.pump(until: { instance.documentElementAttribute("data-log") == "FAILED," }))
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { calls.count == 2 }))
        instance.completeRequest(id: 2, outcome: .badRequest)
        XCTAssertTrue(self.pump(until: { instance.documentElementAttribute("data-log") == "FAILED,FAILED," }))
        instance.destroy()
    }

    /// Review Focus 1: a state edit while a request is in flight neither restarts the widget nor loses the request, which
    /// settles once.
    func testAStateChangeWhileARequestIsInFlightKeepsTheRequest() {
        let instance = self.make(self.page("window.mark = 7; window.settled = 0; b.onclick = () => TelegramWidget.request('vote').then(a => { settled++; document.documentElement.dataset.log = a.result + ':' + TelegramWidget.chatData; });"), context: self.privateContext, state: self.state("c1", nil))
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { !calls.isEmpty }))
        instance.setState(self.state("c2", nil))
        instance.completeRequest(id: 1, outcome: .answered(Data("ok".utf8)))
        instance.completeRequest(id: 1, outcome: .answered(Data("again".utf8)))
        XCTAssertTrue(self.pump(until: { instance.documentElementAttribute("data-log") == "ok:c2" }))
        XCTAssertEqual(instance.evaluateForTesting("settled + ':' + window.mark"), "1:7")
        instance.destroy()
    }

    /// Review Focus 2: a request whose widget went (scrolled away, the node recycled) completes into nothing.
    func testCompletingARequestAfterDestroyDoesNothing() {
        let instance = self.make(self.page("b.onclick = () => TelegramWidget.request('vote');"), context: self.privateContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { !calls.isEmpty }))
        instance.destroy()
        instance.completeRequest(id: 1, outcome: .answered(Data("late".utf8)))
        instance.completeRequest(id: 1, outcome: .failed)
        self.pump(0.1)
        XCTAssertEqual(calls.count, 1)
    }

    /// widget-sandbox v0.2 (W2 plan, Task 5): the host polls a widget's shared state only while it is visible and
    /// watches (upstream integration.md); the instance says when that changes.
    func testPollingInterestFollowsVisibilityAndWatching() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext)
        var changes: [Bool] = []
        instance.onPublicDataPollingChange = { changes.append($0) }
        _ = instance.layout(width: 300.0)
        XCTAssertFalse(instance.wantsPublicDataPolling)
        _ = instance.evaluateForTesting("TelegramWidget.watchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { changes == [true] }), "\(changes)")
        XCTAssertTrue(instance.wantsPublicDataPolling)
        instance.setVisible(false)
        XCTAssertTrue(self.pump(until: { changes == [true, false] }), "\(changes)")
        instance.setVisible(true)
        XCTAssertTrue(self.pump(until: { changes == [true, false, true] }), "\(changes)")
        _ = instance.evaluateForTesting("TelegramWidget.unwatchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { changes == [true, false, true, false] }), "\(changes)")
        _ = instance.evaluateForTesting("TelegramWidget.watchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { changes.last == true }), "\(changes)")
        instance.destroy()
        XCTAssertTrue(self.pump(until: { changes.last == false }), "a destroyed widget is polled no more: \(changes)")
        XCTAssertFalse(instance.wantsPublicDataPolling)
    }

    /// W2 final review, Important 3: the change is delivered on a later main-queue turn, as `onBridge` is, never inside
    /// the call that made it (a layout pass, before the bubble has taken its new item).
    func testThePollingChangeIsDeliveredAfterTheCallThatMadeIt() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext)
        var changes: [Bool] = []
        instance.onPublicDataPollingChange = { changes.append($0) }
        _ = instance.layout(width: 300.0)
        _ = instance.evaluateForTesting("TelegramWidget.watchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { changes == [true] }), "\(changes)")
        instance.setVisible(false)
        XCTAssertEqual(changes, [true], "delivered inside setVisible")
        XCTAssertTrue(self.pump(until: { changes == [true, false] }), "\(changes)")
        instance.destroy()
    }

    func testWatchPublicDataIsTracked() {
        let instance = self.make("<!doctype html><p>x</p>", context: self.privateContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        XCTAssertFalse(instance.watchesPublicData)
        _ = instance.evaluateForTesting("TelegramWidget.watchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { instance.watchesPublicData }))
        _ = instance.evaluateForTesting("TelegramWidget.unwatchPublicData(); 1")
        XCTAssertTrue(self.pump(until: { !instance.watchesPublicData }))
        XCTAssertTrue(self.pump(until: { calls.count == 2 }))
        XCTAssertEqual(calls, [.watchPublicData(true), .watchPublicData(false)])
        instance.destroy()
    }

    func testCopyTextReachesTheHost() {
        let instance = self.make(self.page("b.onclick = () => TelegramWidget.copyText('PROMO');"), context: self.privateContext)
        var calls: [MessageWidgetInstance.BridgeCall] = []
        instance.onBridge = { calls.append($0) }
        _ = instance.layout(width: 300.0)
        self.tap(instance)
        XCTAssertTrue(self.pump(until: { !calls.isEmpty }))
        XCTAssertEqual(calls, [.copyText("PROMO")])
        instance.destroy()
    }

    /// The effective visibility the host's bubble, window and app give, which W2's poller and requests read.
    func testTheEffectiveVisibilityIsPublic() {
        let instance = self.make("<!doctype html><p>x</p>")
        _ = instance.layout(width: 300.0)
        XCTAssertTrue(instance.isVisible)
        instance.setVisible(false)
        XCTAssertFalse(instance.isVisible)
        instance.destroy()
    }
}
