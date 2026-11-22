import XCTest
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import WalletContext
import MessageWidget
import ChatMessageWidgetBubbleContentNode
@testable import WidgetHarnessLib

/// Tier 1 (in the app process; the v0.5.0 plan's Task 7): a widget's wallet call through the REAL bubble, widget-sandbox
/// v0.5.0's `corpus/interactive/05-wallet` flow (`Fixtures/wallet/pay.html`). The harness has no wallet and no server, so
/// a test replaces the wallet's part (`MessageWidgetWallet.perform`, the window and the send) and the bot
/// (`MessageWidgetNetwork.requestAnswer`), and passes the wallet in the context as the app does where this device can sign
/// (`MessageWidgetWalletAvailability`). The coordinator between them is the shipping one (`MessageWidgetWalletCallsTests`
/// pins it alone).
final class WidgetHarnessWalletTests: XCTestCase {
    private let path = "fixture/wallet/pay.html"
    private let card = EngineUserWallet(address: "UQ" + String(repeating: "a", count: 46), balance: 2_000_000_000, signing: nil)
    private let transaction = "{\"valid_until\":1900000000,\"messages\":[{\"address\":\"EQ\(String(repeating: "b", count: 46))\",\"amount\":\"1500000000\"}]}"
    private var savedRequestAnswer: ((AccountContext, EngineMessage.Id, BotWidgetQueryType, Data) -> Signal<Data?, BotWidgetQueryError>)?
    private var savedPerform: ((MessageWidgetWallet.Request, @escaping (Result<MessageWidgetWallet.Outcome, WalletContext.WidgetWalletFailure>) -> Void) -> Void)?
    private var accountId: Int64?

    override func setUp() {
        super.setUp()
        self.savedRequestAnswer = MessageWidgetNetwork.requestAnswer
        self.savedPerform = MessageWidgetWallet.perform
    }

    override func tearDown() {
        if let savedRequestAnswer = self.savedRequestAnswer {
            MessageWidgetNetwork.requestAnswer = savedRequestAnswer
        }
        if let savedPerform = self.savedPerform {
            MessageWidgetWallet.perform = savedPerform
        }
        if let accountId = self.accountId {
            MessageWidgetWalletAvailability.set(false, accountId: accountId)
        }
        super.tearDown()
    }

    private func root() throws -> WidgetHarnessRootViewController {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        let deadline = Date(timeIntervalSinceNow: 30.0)
        while root.listHost == nil && Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertNotNil(root.listHost, "the harness account never opened")
        return root
    }

    /// The fixture alone, from the chat's bot (incoming, can_query), with the wallet for this account or without it.
    private func load(wallet: Bool) throws -> (WidgetHarnessRootViewController, WidgetHarnessListHost) {
        let root = try self.root()
        let accountId = try XCTUnwrap(root.listHost?.accountPeerIdValue)
        self.accountId = accountId
        MessageWidgetWalletAvailability.set(wallet, accountId: accountId)
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.posts = [self.path]
        options.canQuery = true
        options.botChat = true
        options.incoming = true
        root.reload(options: options)
        let expected = wallet ? "wallet" : "no-wallet"
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == expected }, self.log(root) ?? "no log")
        return (root, try XCTUnwrap(root.listHost))
    }

    private func wait(_ root: WidgetHarnessRootViewController, timeout: TimeInterval = 10.0, until ready: ([String]) -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            root.view.layoutIfNeeded()
            if ready(root.readoutLines()) {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return false
    }

    private func log(_ root: WidgetHarnessRootViewController) -> String? {
        return root.readoutLines().first { $0.hasPrefix("log \(self.path) ") }.map { String($0.dropFirst("log \(self.path) ".count)) }
    }

    /// Clicks #pay (y 20) or #sign (y 80) through the widget's own pointer path.
    private func tap(_ host: WidgetHarnessListHost, y: CGFloat) throws {
        let instance = try XCTUnwrap(host.widgetView(path: self.path)?.instance)
        instance.pointer(.down, at: CGPoint(x: 20.0, y: y))
        instance.pointer(.up, at: CGPoint(x: 20.0, y: y))
    }

    /// The bot answers `pay:0` with the transaction and the payment's query with `ok`; every query is recorded.
    private func shop(_ asked: @escaping (BotWidgetQueryType, Data) -> Void) {
        let transaction = self.transaction
        MessageWidgetNetwork.requestAnswer = { _, _, type, data in
            asked(type, data)
            switch type {
            case .data:
                return .single(Data(transaction.utf8))
            default:
                return .single(Data("ok".utf8))
            }
        }
    }

    func testATapPaysWithoutASecondTap() throws {
        var queries: [(BotWidgetQueryType, String)] = []
        var calls: [MessageWidgetWallet.Request] = []
        self.shop { queries.append(($0, String(decoding: $1, as: UTF8.self))) }
        MessageWidgetWallet.perform = { request, done in
            calls.append(request)
            done(.success(.sent(msgHash: "aGFzaA==", wallet: self.card)))
        }
        let (root, host) = try self.load(wallet: true)
        try self.tap(host, y: 20.0)
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == "paid:ok" }, self.log(root) ?? "no log")
        XCTAssertEqual(queries.map(\.0), [.data(withWallet: true), .sentTransaction(wallet: self.card, msgHash: "aGFzaA==")])
        XCTAssertEqual(queries.map(\.1), ["pay:0", "paid:0"])
        // The wallet got the transaction the runtime checked, from the message's bot.
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first?.bot.id, EnginePeer(WidgetHarnessListHost.botChatPeer).id)
        if case let .sendTransaction(json, data)? = calls.first?.call {
            XCTAssertTrue(json.contains("\"amount\":\"1500000000\""), json)
            XCTAssertEqual(data, Data("paid:0".utf8))
        } else {
            XCTFail("not a transaction: \(String(describing: calls.first?.call))")
        }
    }

    func testTheWalletsFailuresReachTheWidget() throws {
        for (failure, code) in [(WalletContext.WidgetWalletFailure.rejected, "REJECTED"), (.badRequest, "BAD_REQUEST"), (.insufficientBalance, "BAD_REQUEST")] {
            var queries: [BotWidgetQueryType] = []
            self.shop { type, _ in queries.append(type) }
            MessageWidgetWallet.perform = { _, done in done(.failure(failure)) }
            let (root, host) = try self.load(wallet: true)
            try self.tap(host, y: 20.0)
            XCTAssertTrue(self.wait(root) { _ in self.log(root) == "err:\(code)" }, "\(code): \(self.log(root) ?? "no log")")
            XCTAssertEqual(queries, [.data(withWallet: true)])
        }
    }

    func testASignatureReachesTheBot() throws {
        var queries: [(BotWidgetQueryType, String)] = []
        self.shop { queries.append(($0, String(decoding: $1, as: UTF8.self))) }
        MessageWidgetWallet.perform = { request, done in
            XCTAssertEqual(request.call, .signData(json: "{\"text\":\"I agree\",\"type\":\"text\"}", data: Data("sign:1".utf8)))
            done(.success(.signed(json: "{\"signature\":\"c2ln\"}", wallet: self.card)))
        }
        let (root, host) = try self.load(wallet: true)
        try self.tap(host, y: 80.0)
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == "signed:ok" }, self.log(root) ?? "no log")
        XCTAssertEqual(queries.map(\.0), [.signData(wallet: self.card, json: "{\"signature\":\"c2ln\"}")])
        XCTAssertEqual(queries.map(\.1), ["sign:1"])
    }

    /// Without the wallet for this account the widget has none, and its request for the wallet asks nothing.
    func testWithoutTheWalletTheWidgetHasNone() throws {
        var queries = 0
        self.shop { _, _ in queries += 1 }
        MessageWidgetWallet.perform = { _, _ in XCTFail("a wallet window") }
        let (root, host) = try self.load(wallet: false)
        try self.tap(host, y: 20.0)
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == "err:NOT_ALLOWED" }, self.log(root) ?? "no log")
        XCTAssertEqual(queries, 0)
    }

    /// The wallet set up while the chat is open: the widget boots again, with the wallet.
    func testTheWalletSetUpReachesAWidgetOnScreen() throws {
        let (root, host) = try self.load(wallet: false)
        MessageWidgetWalletAvailability.set(true, accountId: host.accountPeerIdValue)
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == "wallet" }, self.log(root) ?? "no log")
    }
}
