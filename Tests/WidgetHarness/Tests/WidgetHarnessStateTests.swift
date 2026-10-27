import XCTest
import UIKit
import MessageWidget
@testable import WidgetHarnessLib

/// Tier 1 (in the app process; v0.2 W1 plan, Task 8): the REAL bubble passes its message's context and the bot's state
/// to the widget (widget-sandbox v0.2, sdk-v1 §2.13), a state edit reaches the running widget without restarting it, the
/// network marker shows exactly where the message has can_query (§5.11), and copyText copies and shows the text (§2.15).
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

    func testTheNetworkMarkerShowsExactlyWithCanQuery() throws {
        let (root, host) = try self.load()
        let bubble = { root.readoutLines().first { $0.hasPrefix("bubble ") && $0.contains(self.path) } ?? "" }
        XCTAssertFalse(bubble().contains("+marker"), bubble())
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: nil, publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in bubble().contains("+marker") }, bubble())
        host.replaceWidgetState(path: self.path, canQuery: false, chatData: nil, publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in !bubble().contains("+marker") && bubble().contains(" widget") }, bubble())
    }

    /// A tap on the marker explains it with a tooltip the chat shows (it shows none without a node), pointing at the
    /// marker.
    func testTappingTheMarkerShowsItsExplanation() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: nil, publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in host.networkMarker(path: self.path) != nil }, root.readoutLines().joined(separator: "\n"))
        let marker = try XCTUnwrap(host.networkMarker(path: self.path))
        marker.sendActions(for: .touchUpInside)
        let tooltips = root.readoutLines().filter { $0.hasPrefix("tooltip ") }
        XCTAssertEqual(tooltips, ["tooltip Taps on this widget can send data to the bot."])
        let anchor = try XCTUnwrap(host.lastTooltipRect)
        let markerFrame = marker.convert(marker.bounds, to: nil)
        XCTAssertEqual(anchor.minX, markerFrame.minX, accuracy: 0.5)
        XCTAssertEqual(anchor.minY, markerFrame.minY, accuracy: 0.5)
        XCTAssertEqual(anchor.size, markerFrame.size)
    }

    /// VoiceOver reads the marker as what its tap explains, a button (W1's deferred minor: it read "cellular data", the
    /// symbol's own name).
    func testTheMarkerReadsItsExplanationToVoiceOver() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: nil, publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in host.networkMarker(path: self.path) != nil }, root.readoutLines().joined(separator: "\n"))
        let marker = try XCTUnwrap(host.networkMarker(path: self.path))
        XCTAssertEqual(marker.accessibilityLabel, "Taps on this widget can send data to the bot.")
        XCTAssertTrue(marker.isAccessibilityElement)
        XCTAssertTrue(marker.accessibilityTraits.contains(.button))
    }

    /// The marker is a button of its own above the widget's corner: a touch on it is the marker's, so the bubble's
    /// estimate at the touch's down starts no press in the widget under it (no pointerdown, pointercancel or haptic
    /// window from a tap that never touched the widget), claims no hold and no horizontal drag.
    func testATouchOnTheMarkerIsNeverAPressInTheWidget() throws {
        let (root, host) = try self.load()
        host.replaceWidgetState(path: self.path, canQuery: true, chatData: nil, publicData: nil)
        XCTAssertTrue(self.wait(root) { _ in host.networkMarker(path: self.path) != nil })
        let marker = try XCTUnwrap(host.networkMarker(path: self.path))
        let pointers = { self.log(root)?.split(separator: "|", omittingEmptySubsequences: false).last.map(String.init) }
        XCTAssertTrue(self.wait(root) { _ in pointers() == "0" }, self.log(root) ?? "no log")

        let answers = try XCTUnwrap(host.widgetContentAnswers(path: self.path, at: CGPoint(x: marker.frame.midX, y: marker.frame.midY)))
        XCTAssertTrue(answers.ignoresTap, "the bubble's tap recognizer must fail so the marker's button gets the tap")
        XCTAssertFalse(answers.claimsHold)
        XCTAssertFalse(answers.claimsHorizontalDrag)
        XCTAssertFalse(self.wait(root, timeout: 1.0) { _ in pointers() != "0" }, "a touch on the marker pressed the widget: \(self.log(root) ?? "no log")")

        // The control: the same estimate inside the widget, away from the marker, is a press the widget sees.
        _ = host.widgetContentAnswers(path: self.path, at: CGPoint(x: 20.0, y: 20.0))
        XCTAssertTrue(self.wait(root) { _ in pointers() != "0" }, self.log(root) ?? "no log")
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
