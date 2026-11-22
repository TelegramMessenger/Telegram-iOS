import XCTest
import UIKit
import MessageWidget
@testable import WidgetHarnessLib

/// Tier 1 (in the app process; v0.2 W1 plan, Task 8): the REAL bubble passes its message's context and the bot's state
/// to the widget (widget-sandbox v0.2, sdk-v1 §2.13), a state edit reaches the running widget without restarting it, the
/// bubble shows no network marker, even where the message has can_query (the user, 2026-10-29), and copyText copies and
/// shows the text (§2.15).
final class WidgetHarnessStateTests: XCTestCase {
    private let path = "fixture/widget-state.html"

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

    /// The fixture alone, its widget live.
    private func load(copyProtected: Bool = false) throws -> (WidgetHarnessRootViewController, WidgetHarnessListHost) {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "widget-state"
        options.copyProtected = copyProtected
        root.reload(options: options)
        XCTAssertTrue(self.wait(root) { lines in lines.contains { $0.hasPrefix("bubble ") && $0.contains(self.path) && $0.contains(" widget") } })
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

    func testTheBubblePassesTheMessagesState() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: "c1", publicData: "p1")
        let expected = "c1|p1|private|\(host.accountPeerIdValue)|0|0"
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == expected }, self.log(root) ?? "no log")
    }

    /// A state edit (the server's updateMessageWidgetData, or a supergroup's channel edit) reaches the running widget as
    /// chatDataChanged: the same widget, not a restarted one.
    func testAStateEditReachesTheRunningWidget() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: "c1", publicData: "p1")
        XCTAssertTrue(self.wait(root) { _ in self.log(root)?.hasPrefix("c1|p1|") == true })
        let before = host.widgetView(path: self.path)?.instance
        XCTAssertNotNil(before)
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: "c2", publicData: "p1")
        let expected = "c2|p1|private|\(host.accountPeerIdValue)|1|0"
        XCTAssertTrue(self.wait(root) { _ in self.log(root) == expected }, self.log(root) ?? "no log")
        XCTAssertTrue(host.widgetView(path: self.path)?.instance === before, "the state edit restarted the widget")
    }

    /// The user, 2026-10-29: no network marker on any widget, even where the message has can_query (a divergence from
    /// sdk-v1 §5.11). The widget area's bottom-right corner, where the marker sat, is the widget's like the rest of it:
    /// the bubble's estimate at a touch's down there starts a press the widget sees.
    func testNoNetworkMarkerEvenWithCanQuery() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: "c1", publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in self.log(root)?.hasPrefix("c1|") == true }, self.log(root) ?? "no log")
        let pointers = { self.log(root)?.split(separator: "|", omittingEmptySubsequences: false).last.map(String.init) }
        XCTAssertTrue(self.wait(root) { _ in pointers() == "0" }, self.log(root) ?? "no log")
        let widgetView = try XCTUnwrap(host.widgetView(path: self.path))
        let contentView = try XCTUnwrap(widgetView.superview?.superview)
        let corner = widgetView.convert(CGPoint(x: widgetView.bounds.maxX - 18.0, y: widgetView.bounds.maxY - 18.0), to: contentView)
        let answers = try XCTUnwrap(host.widgetContentAnswers(path: self.path, at: corner))
        XCTAssertTrue(answers.ignoresTap, "a live widget takes its own taps")
        XCTAssertTrue(self.wait(root) { _ in pointers() != "0" }, "the corner did not press the widget: \(self.log(root) ?? "no log")")
    }

    /// sdk-v1 §2.15: the client copies the text and shows a toast that says what it copied; a chat that forbids copying
    /// copies nothing and shows why.
    func testCopyTextCopiesAndShowsTheText() throws {
        UIPasteboard.general.string = "before"
        let (root, host) = try self.load()
        let instance = try XCTUnwrap(host.widgetView(path: self.path)?.instance)
        instance.pointer(.down, at: CGPoint(x: 20.0, y: 20.0))
        instance.pointer(.up, at: CGPoint(x: 20.0, y: 20.0))
        XCTAssertTrue(self.wait(root) { $0.contains("toast PROMO") }, root.readoutLines().joined(separator: "\n"))
        XCTAssertEqual(UIPasteboard.general.string, "PROMO")

        UIPasteboard.general.string = "before"
        let (protectedRoot, protectedHost) = try self.load(copyProtected: true)
        let protectedInstance = try XCTUnwrap(protectedHost.widgetView(path: self.path)?.instance)
        protectedInstance.pointer(.down, at: CGPoint(x: 20.0, y: 20.0))
        protectedInstance.pointer(.up, at: CGPoint(x: 20.0, y: 20.0))
        XCTAssertTrue(self.wait(protectedRoot) { lines in lines.contains { $0.hasPrefix("toast ") && $0 != "toast PROMO" } }, protectedRoot.readoutLines().joined(separator: "\n"))
        XCTAssertFalse(protectedRoot.readoutLines().contains("toast PROMO"))
        XCTAssertEqual(UIPasteboard.general.string, "before")
    }
}
