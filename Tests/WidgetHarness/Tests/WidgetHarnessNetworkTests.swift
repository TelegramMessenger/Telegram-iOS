import XCTest
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext
import MessageWidget
import ChatMessageWidgetBubbleContentNode
@testable import WidgetHarnessLib

/// Tier 1 (in the app process; v0.2 W2 plan): the REAL bubble's network paths for a widget, through the seam the
/// harness replaces (`MessageWidgetNetwork`): a request reaches the bot and its outcome the widget (the cancellation of a
/// request whose bubble goes away is `MessageWidgetRequestsTests`, in the bubble's own unit tests).
final class WidgetHarnessNetworkTests: XCTestCase {
    private let requestPath = "fixture/widget-request.html"
    private let watchPath = "fixture/widget-watch.html"
    private var savedRequestAnswer: ((AccountContext, EngineMessage.Id, BotWidgetQueryType, Data) -> Signal<Data?, BotWidgetQueryError>)?
    private var savedPollPublicData: ((AccountContext, EngineMessage.Id, Int64) -> Signal<Never, NoError>)?
    /// What the polling seam saw: `subscribe <message id> <widget id>` and `dispose <message id> <widget id>`.
    private final class PollLog {
        var events: [String] = []
    }
    private var polls = PollLog()

    override func setUp() {
        super.setUp()
        self.savedRequestAnswer = MessageWidgetNetwork.requestAnswer
        self.savedPollPublicData = MessageWidgetNetwork.pollPublicData
        let polls = PollLog()
        self.polls = polls
        MessageWidgetNetwork.pollPublicData = { _, messageId, widgetId in
            return Signal { _ in
                polls.events.append("subscribe \(messageId.id) \(widgetId)")
                return ActionDisposable {
                    polls.events.append("dispose \(messageId.id) \(widgetId)")
                }
            }
        }
    }

    override func tearDown() {
        if let savedRequestAnswer = self.savedRequestAnswer {
            MessageWidgetNetwork.requestAnswer = savedRequestAnswer
        }
        if let savedPollPublicData = self.savedPollPublicData {
            MessageWidgetNetwork.pollPublicData = savedPollPublicData
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

    /// The fixture at `path` alone, its message with can_query, its widget live.
    private func load(_ part: String, path: String) throws -> (WidgetHarnessRootViewController, WidgetHarnessListHost) {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = part
        options.canQuery = true
        root.reload(options: options)
        XCTAssertTrue(self.wait(root) { lines in lines.contains { $0.hasPrefix("bubble ") && $0.contains(path) && $0.contains(" widget") } })
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

    private func log(_ root: WidgetHarnessRootViewController, _ path: String) -> String? {
        return root.readoutLines().first { $0.hasPrefix("log \(path) ") }.map { String($0.dropFirst("log \(path) ".count)) }
    }

    /// Taps the fixture's #ask (at the widget's top left) through its widget's own pointer path.
    private func tapAsk(_ host: WidgetHarnessListHost) throws {
        let instance = try XCTUnwrap(host.widgetView(path: self.requestPath)?.instance)
        instance.pointer(.down, at: CGPoint(x: 20.0, y: 20.0))
        instance.pointer(.up, at: CGPoint(x: 20.0, y: 20.0))
    }

    func testATappedRequestReachesTheBotAndItsAnswerTheWidget() throws {
        var asked: [(EngineMessage.Id, Data)] = []
        MessageWidgetNetwork.requestAnswer = { _, messageId, _, data in
            asked.append((messageId, data))
            return .single(Data("pong".utf8))
        }
        let (root, host) = try self.load("widget-request", path: self.requestPath)
        try self.tapAsk(host)
        XCTAssertTrue(self.wait(root) { _ in self.log(root, self.requestPath) == "ok:pong" }, self.log(root, self.requestPath) ?? "no log")
        XCTAssertEqual(asked.count, 1)
        XCTAssertEqual(asked.first?.0, host.messageId(path: self.requestPath))
        XCTAssertEqual(asked.first?.1, Data("ping".utf8))
    }

    func testEachFailureReachesTheWidgetAsItsCode() throws {
        for (error, code) in [(BotWidgetQueryError.timeout, "TIMEOUT"), (.rateLimited, "RATE_LIMITED"), (.failed, "FAILED")] {
            MessageWidgetNetwork.requestAnswer = { _, _, _, _ in
                return .fail(error)
            }
            let (root, host) = try self.load("widget-request", path: self.requestPath)
            try self.tapAsk(host)
            XCTAssertTrue(self.wait(root) { _ in self.log(root, self.requestPath) == "err:\(code)" }, "\(code): \(self.log(root, self.requestPath) ?? "no log")")
        }
    }

    // MARK: - Polling a shared widget's state (W2 plan, Task 5)

    private func messageIdValue(_ host: WidgetHarnessListHost, _ path: String) -> Int32 {
        return host.messageId(path: path)?.id ?? -1
    }

    /// The watch fixture alone, live, and given the widget id 42 (as a shared widget's message has it).
    private func loadWatching(widgetId: Int64? = 42) throws -> (WidgetHarnessRootViewController, WidgetHarnessListHost) {
        let (root, host) = try self.load("widget-watch", path: self.watchPath)
        XCTAssertTrue(self.wait(root) { _ in self.log(root, self.watchPath)?.hasPrefix("watching|") == true }, self.log(root, self.watchPath) ?? "no log")
        if let widgetId {
            host.replaceWidgetState(path: self.watchPath, canQuery: true, chatData: nil, publicData: nil, widgetId: widgetId)
        }
        return (root, host)
    }

    private func tapToggle(_ host: WidgetHarnessListHost) throws {
        let instance = try XCTUnwrap(host.widgetView(path: self.watchPath)?.instance)
        instance.pointer(.down, at: CGPoint(x: 20.0, y: 20.0))
        instance.pointer(.up, at: CGPoint(x: 20.0, y: 20.0))
    }

    func testAWatchingWidgetWithAnIdOnScreenIsPolled() throws {
        let (root, host) = try self.loadWatching()
        let id = self.messageIdValue(host, self.watchPath)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events == ["subscribe \(id) 42"] }, "\(self.polls.events)")
    }

    func testUnwatchingStopsThePolling() throws {
        let (root, host) = try self.loadWatching()
        let id = self.messageIdValue(host, self.watchPath)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events == ["subscribe \(id) 42"] }, "\(self.polls.events)")
        try self.tapToggle(host)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "dispose \(id) 42" }, "\(self.polls.events)")
        try self.tapToggle(host)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "subscribe \(id) 42" }, "\(self.polls.events)")
    }

    /// A widget that watches without a widget id changes nothing: there is no object to poll (upstream integration.md).
    func testAWidgetWithoutAnIdIsNeverPolled() throws {
        let (root, _) = try self.loadWatching(widgetId: nil)
        XCTAssertFalse(self.wait(root, timeout: 1.0) { _ in !self.polls.events.isEmpty }, "\(self.polls.events)")
    }

    /// Under a pushed screen or with the app in the background the bubble's geometry still says visible; the widget's
    /// own effective visibility (its view's window) ends the polling (Review Focus 5).
    func testLeavingTheWindowStopsThePolling() throws {
        let (root, host) = try self.loadWatching()
        let id = self.messageIdValue(host, self.watchPath)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events == ["subscribe \(id) 42"] }, "\(self.polls.events)")
        let superview = try XCTUnwrap(root.view.superview)
        root.view.removeFromSuperview()
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "dispose \(id) 42" }, "\(self.polls.events)")
        superview.addSubview(root.view)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "subscribe \(id) 42" }, "\(self.polls.events)")
    }

    func testScrollingAwayStopsThePolling() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.canQuery = true
        options.posts = [self.watchPath, "fixture/tall-box.html", "fixture/tall-box.html", "fixture/tall-box.html"]
        root.reload(options: options)
        let host = try XCTUnwrap(root.listHost)
        host.replaceWidgetState(path: self.watchPath, canQuery: true, chatData: nil, publicData: nil, widgetId: 42)
        let id = self.messageIdValue(host, self.watchPath)
        let index = try XCTUnwrap(host.messageIndices(pathContaining: "widget-watch").first)
        host.scrollTo(messageIndex: index)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "subscribe \(id) 42" }, "\(self.polls.events)")
        // To the newest post (`scrollTo` counts messages oldest first: 0 is the watch post itself).
        host.scrollTo(messageIndex: Int.max)
        XCTAssertTrue(self.wait(root) { _ in self.polls.events.last == "dispose \(id) 42" }, "\(self.polls.events) \(root.readoutLines().filter { $0.hasPrefix("bubble ") })")
    }
}
