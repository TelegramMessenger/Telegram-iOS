import XCTest
import UIKit
import MessageWidget
@testable import WidgetHarnessLib

/// widget-sandbox v0.3.0 (sdk-v1 §5.2, decisions "Telegram links open without a confirmation"): a widget's
/// `openTelegramLink` opens as a tapped t.me link in a message, with no "Open link?" of the widget's own (the chat's t.me
/// handling keeps its own confirmations); its `openLink` keeps the prompt with the whole URL. `Fixtures/open-telegram-link.html`.
final class WidgetHarnessLinkTests: XCTestCase {
    private let path = "fixture/open-telegram-link.html"

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

    /// Taps the widget at `y` (its first button at 32, its second at 96) through its own pointer path.
    private func tap(_ host: WidgetHarnessListHost, y: CGFloat) throws {
        let instance = try XCTUnwrap(host.widgetView(path: self.path)?.instance)
        instance.pointer(.down, at: CGPoint(x: 40.0, y: y))
        instance.pointer(.up, at: CGPoint(x: 40.0, y: y))
    }

    func testATelegramLinkOpensWithoutTheWidgetsPromptAndAWebLinkWithIt() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "open-telegram-link"
        root.reload(options: options)
        XCTAssertTrue(self.wait(root) { $0.contains { $0.hasPrefix("bubble ") && $0.contains(self.path) && $0.contains(" widget") && !$0.contains("x160 ") } })
        let host = try XCTUnwrap(root.listHost)

        try self.tap(host, y: 32.0)
        XCTAssertTrue(self.wait(root) { $0.contains("openLink https://t.me/harness (not concealed)") }, root.readoutLines().joined(separator: "\n"))

        try self.tap(host, y: 96.0)
        XCTAssertTrue(self.wait(root) { $0.contains("openLink https://example.org/harness") }, root.readoutLines().joined(separator: "\n"))
        XCTAssertFalse(root.readoutLines().contains("openLink https://example.org/harness (not concealed)"))
    }
}
