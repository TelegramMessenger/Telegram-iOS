import XCTest
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
@testable import MessageWidget
import ChatMessageWidgetBubbleContentNode
@testable import WidgetHarnessLib

/// Tier 1: widget-sandbox's interactive corpus (`corpus/interactive/`) through the REAL bubble, its requests answered as
/// the sandbox's own mock bot answers them (`apps/web/src/mock-bot.ts`): the request's data as UTF-8 bytes
/// (docs/integration.md, `onRequest`), the answer's `result` handed to the widget as it came. A widget that updates here
/// but not against a live bot has a bot that does not answer as the sandbox's does.
final class WidgetHarnessSandboxBotTests: XCTestCase {
    private let tickerPath = "interactive/03-live-ticker.html"
    private var savedRequestAnswer: ((AccountContext, EngineMessage.Id, BotWidgetQueryType, Data) -> Signal<Data?, BotWidgetQueryError>)?

    override func setUp() {
        super.setUp()
        self.savedRequestAnswer = MessageWidgetNetwork.requestAnswer
    }

    override func tearDown() {
        if let savedRequestAnswer = self.savedRequestAnswer {
            MessageWidgetNetwork.requestAnswer = savedRequestAnswer
        }
        super.tearDown()
    }

    /// The live ticker alone in a chat with a bot, its message with can_query and background_query (the private chat
    /// with the bot, where the widget asks without a tap), live.
    private func loadTicker() throws -> (WidgetHarnessRootViewController, WidgetHarnessListHost, MessageWidgetInstance) {
        let root = try XCTUnwrap(AppDelegate.widgetHarnessRootViewController)
        root.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)
        var options = WidgetHarnessLaunchOptions()
        options.set = .corpus
        options.postFilter = "03-live-ticker"
        options.canQuery = true
        options.backgroundQuery = true
        options.botChat = true
        root.reload(options: options)
        XCTAssertTrue(self.wait(root) { _ in root.readoutLines().contains { $0.hasPrefix("bubble ") && $0.contains(self.tickerPath) && $0.contains(" widget") } },
                      root.readoutLines().joined(separator: "\n"))
        let host = try XCTUnwrap(root.listHost)
        let instance = try XCTUnwrap(host.widgetView(path: self.tickerPath)?.instance)
        return (root, host, instance)
    }

    private func wait(_ root: WidgetHarnessRootViewController, timeout: TimeInterval = 10.0, until ready: (()) -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            root.view.layoutIfNeeded()
            if ready(()) {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return false
    }

    private func text(_ instance: MessageWidgetInstance, _ id: String) -> String {
        return instance.evaluateForTesting("document.getElementById('\(id)').textContent") ?? "nil"
    }

    /// The sandbox's `ticker` bot answers `tick` with `{t, p}` and `like` by editing the chat state to `{likes}`: the
    /// widget asks as it appears, shows each price, asks again 5 s later, and draws the likes the bot's edit carries.
    func testTheLiveTickerShowsTheSandboxBotsPrices() throws {
        var asked: [String] = []
        MessageWidgetNetwork.requestAnswer = { _, _, _, data in
            let request = String(decoding: data, as: UTF8.self)
            asked.append(request)
            guard request == "tick" else {
                return .single(Data("liked".utf8))
            }
            let price = 100.0 + 1.25 * Double(asked.count)
            return .single(Data("{\"t\":\"12:00:0\(asked.count)\",\"p\":\(price)}".utf8))
        }
        let (root, host, instance) = try self.loadTicker()
        XCTAssertTrue(self.wait(root) { _ in self.text(instance, "price") == "101.25" }, "price \(self.text(instance, "price")), asked \(asked)")
        XCTAssertEqual(self.text(instance, "note"), "live: the bot every 5 s")
        XCTAssertEqual(asked.first, "tick")
        // The next tick, 5 s later, without a tap: the widget's own timer, so the wait leaves room for a loaded machine.
        // That room would also absorb a tick refused as rate limited and retried, which the widget shows in its note.
        var sawRateLimited = false
        XCTAssertTrue(self.wait(root, timeout: 15.0) { _ in
            if self.text(instance, "note") == "live: waiting…" {
                sawRateLimited = true
            }
            return self.text(instance, "price") == "102.50"
        }, "price \(self.text(instance, "price")), asked \(asked)")
        XCTAssertFalse(sawRateLimited, "the second tick was refused as rate limited")
        // The bot's edit of the chat state (its answer to `like`) reaches the widget as chatDataChanged.
        host.replaceWidgetState(path: self.tickerPath, canQuery: true, chatData: "{\"likes\":3}", publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in self.text(instance, "likes") == "3" }, "likes \(self.text(instance, "likes"))")
    }

    /// What the Widget Bot on the test servers answers (2026-10-27): an echo of the data, base64. The request succeeds,
    /// so the widget says it is live, but the answer is no price, and the price stays "—": the screen seen in the app.
    func testAnEchoingBotLeavesThePriceEmpty() throws {
        MessageWidgetNetwork.requestAnswer = { _, _, _, data in
            return .single(Data(("echo: " + data.base64EncodedString().replacingOccurrences(of: "=", with: "")).utf8))
        }
        let (root, _, instance) = try self.loadTicker()
        XCTAssertTrue(self.wait(root) { _ in self.text(instance, "note") == "live: the bot every 5 s" }, "note \(self.text(instance, "note"))")
        XCTAssertEqual(self.text(instance, "price"), "—")
    }
}
