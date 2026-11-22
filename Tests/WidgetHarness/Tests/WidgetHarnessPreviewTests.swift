import XCTest
import UIKit
import AsyncDisplayKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
@testable import MessageWidget
import ChatMessageWidgetBubbleContentNode
@testable import WidgetHarnessLib

/// Tier 1 (in the app process; v0.2 W3 plan, Task 2): an inline result's widget as the results lists preview it
/// (sdk-v1 §2.16): the result's state, nothing about the user, no request and no input; one height report per height; a
/// node shown for another result runs another widget; a payload that does not inflate shows none.
final class WidgetHarnessPreviewTests: XCTestCase {
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

    /// A preview node in the window, so its widget gets its frames.
    private func node() throws -> MessageWidgetPreviewNode {
        let root = try self.root()
        let node = MessageWidgetPreviewNode()
        node.frame = CGRect(x: 20.0, y: 200.0, width: 350.0, height: MessageWidgetPreviewLayout.maximumListHeight)
        root.view.addSubview(node.view)
        self.addTeardownBlock {
            node.view.removeFromSuperview()
        }
        return node
    }

    private func widget(_ name: String, height: Int32 = 0, chatData: String? = nil, publicData: String? = nil) throws -> TelegramMediaWidget {
        let url = try XCTUnwrap(Bundle.main.resourceURL?.appendingPathComponent("Fixtures").appendingPathComponent(name))
        return try self.widget(html: try String(contentsOf: url, encoding: .utf8), height: height, chatData: chatData, publicData: publicData)
    }

    private func widget(html: String, height: Int32 = 0, chatData: String? = nil, publicData: String? = nil) throws -> TelegramMediaWidget {
        let compressed = try XCTUnwrap(TelegramMediaWidget(html: html, width: 0, height: height))
        return TelegramMediaWidget(width: 0, height: height, payload: compressed.payload, chatData: chatData.map { Data($0.utf8) }, publicData: publicData.map { Data($0.utf8) })
    }

    /// Laid out as a results row 350 pt wide lays it out.
    private func update(_ node: MessageWidgetPreviewNode, _ widget: TelegramMediaWidget, owner: AnyHashable = "a", locale: String = "en") {
        let content = MessageWidgetPreviewLayout.contentSize(anchors: MessageWidgetAnchors(width: widget.width, height: widget.height), availableWidth: 350.0, reportedHeight: nil)
        let display = MessageWidgetPreviewLayout.fitted(content, in: CGSize(width: 350.0, height: MessageWidgetPreviewLayout.maximumListHeight))
        let theme = messageWidgetPreviewTheme(theme: defaultPresentationTheme, wallpaper: .builtin(WallpaperSettings()), fontSize: .regular)
        node.update(widget: widget, ownerId: owner, theme: theme, locale: locale, stoppedLabel: "Widget stopped", contentWidth: content.width, displaySize: display.size, cornerRadius: 16.0)
    }

    private func wait(timeout: TimeInterval = 10.0, until ready: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if ready() {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return false
    }

    private func drain(_ seconds: TimeInterval) {
        let deadline = Date(timeIntervalSinceNow: seconds)
        while Date() < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
    }

    private func log(_ node: MessageWidgetPreviewNode) -> String? {
        return node.widgetView?.documentElementAttribute("data-log")
    }

    func testAPreviewRunsWithTheResultsStateAndNothingAboutTheUser() throws {
        let node = try self.node()
        self.update(node, try self.widget("preview/widget-preview.html", chatData: "c1", publicData: "p1"))
        let expected = "true|null|null|c1|p1|NOT_ALLOWED|0"
        XCTAssertTrue(self.wait { self.log(node) == expected }, self.log(node) ?? "no log")
    }

    /// The runtime's preview gate drops input (the widget's own pointer path, below the node), and the node takes no
    /// touch either, so the results row takes the tap.
    func testAPreviewTakesNoTouches() throws {
        let node = try self.node()
        self.update(node, try self.widget("preview/widget-preview.html"))
        XCTAssertTrue(self.wait { self.log(node)?.hasSuffix("|NOT_ALLOWED|0") == true }, self.log(node) ?? "no log")
        let instance = try XCTUnwrap(node.widgetView?.instance)
        instance.pointer(.down, at: CGPoint(x: 50.0, y: 50.0))
        instance.pointer(.up, at: CGPoint(x: 50.0, y: 50.0))
        self.drain(1.0)
        XCTAssertEqual(self.log(node)?.split(separator: "|").last, "0", self.log(node) ?? "no log")
        XCTAssertNil(node.view.hitTest(CGPoint(x: 50.0, y: 50.0), with: nil))
    }

    func testAPreviewReportsEachHeightOnce() throws {
        let node = try self.node()
        var heights: [CGFloat] = []
        node.onContentHeightChange = { heights.append($0) }
        self.update(node, try self.widget("box-240.html"))
        XCTAssertTrue(self.wait { !heights.isEmpty })
        self.drain(1.0)
        XCTAssertEqual(heights, [240.0])
    }

    func testAPreviewOfAnotherResultIsAnotherWidget() throws {
        let node = try self.node()
        let widget = try self.widget("box-240.html")
        self.update(node, widget, owner: "a")
        XCTAssertTrue(self.wait { node.widgetView?.instance != nil })
        let first = node.widgetView?.instance
        self.update(node, widget, owner: "b")
        XCTAssertTrue(self.wait { node.widgetView?.instance != nil })
        XCTAssertFalse(node.widgetView?.instance === first, "the node kept the other result's widget")
    }

    /// The final review: a preview runs in the app's language, as its sent bubble will (sdk-v1 §2.16, "the same first
    /// state"), not the registry's en-US default.
    func testAPreviewRunsInTheAppsLanguage() throws {
        let node = try self.node()
        self.update(node, try self.widget("preview/widget-preview.html"), locale: "ru")
        XCTAssertTrue(self.wait { node.widgetView?.documentElementAttribute("data-language") == "ru" }, node.widgetView?.documentElementAttribute("data-language") ?? "no language")
    }

    /// The final review: a fixed height is the row's whatever the widget reports, so nothing re-lays the row out.
    func testAFixedHeightPreviewReportsNoHeight() throws {
        let node = try self.node()
        var heights: [CGFloat] = []
        node.onContentHeightChange = { heights.append($0) }
        self.update(node, try self.widget("box-240.html", height: 300))
        XCTAssertTrue(self.wait { node.widgetView?.instance?.reportedHeight != nil })
        self.drain(1.0)
        XCTAssertEqual(heights, [])
    }

    /// The final review: the report is the height the row lays out at (clamped to 50…600), so a report the clamp
    /// absorbs re-lays nothing out.
    func testAShortPreviewReportsItsClampedHeight() throws {
        let node = try self.node()
        var heights: [CGFloat] = []
        node.onContentHeightChange = { heights.append($0) }
        self.update(node, try self.widget(html: "<!doctype html><html><head><style>body { margin: 0 } div { height: 20px }</style></head><body><div></div></body></html>"))
        XCTAssertTrue(self.wait { !heights.isEmpty })
        self.drain(1.0)
        XCTAssertEqual(heights, [50.0])
    }

    /// The final review: only a preview on screen runs a widget (the list's preload rows run none), and one leaving the
    /// screen stops its own, so a fling through many widget results runs only the visible ones.
    func testAHiddenPreviewRunsNoWidget() throws {
        let node = try self.node()
        node.setVisible(false)
        self.update(node, try self.widget("box-240.html"))
        self.drain(1.0)
        XCTAssertNil(node.widgetView, "a hidden preview booted")
        node.setVisible(true)
        XCTAssertTrue(self.wait { node.widgetView != nil }, "the preview did not boot once visible")
        node.setVisible(false)
        XCTAssertNil(node.widgetView, "a preview leaving the screen kept its widget")
    }

    /// The fix wave's review: a boot that outlasts the pass's wait is sized by the pass as the 160 pt placeholder; when
    /// it lands, the preview lays its view out again (a fixed height reports nothing that would re-lay it out).
    func testALateBootIsSizedOnceItLands() throws {
        let node = try self.node()
        self.update(node, try self.widget("preview/slow-box.html", height: 300))
        XCTAssertTrue(self.wait { node.widgetView?.instance?.reportedHeight != nil }, "the boot never landed")
        XCTAssertTrue(self.wait { node.widgetView?.frame.height == 300.0 }, "the view stayed \(node.widgetView?.frame.height ?? -1) tall")
    }

    /// The fix wave's review: a preview shown again boots afresh; when that boot lands late, its view is laid out again
    /// although the height it reports is the one already reported.
    func testALateBootShownAgainIsSizedOnceItLands() throws {
        let node = try self.node()
        self.update(node, try self.widget("preview/slow-box.html"))
        XCTAssertTrue(self.wait { node.widgetView?.frame.height == 300.0 }, "the first boot was not laid out")
        node.setVisible(false)
        node.setVisible(true)
        XCTAssertTrue(self.wait { node.widgetView?.instance?.reportedHeight != nil }, "the second boot never landed")
        XCTAssertTrue(self.wait { node.widgetView?.frame.height == 300.0 }, "the view stayed \(node.widgetView?.frame.height ?? -1) tall")
    }

    /// The fix wave's review: a widget that failed to start is remembered, not booted again each time its row is shown
    /// (a parse that fails costs a pool thread its time), as the bubble's registry remembers it.
    func testAFailedPreviewIsNotBootedAgainWhenShownAgain() throws {
        let node = try self.node()
        MessageWidgetCore.startFailureForTesting = { _ in true }
        defer {
            MessageWidgetCore.startFailureForTesting = nil
        }
        self.update(node, try self.widget("box-240.html"))
        self.drain(1.0)
        XCTAssertNil(node.widgetView, "the widget started though its start fails")
        MessageWidgetCore.startFailureForTesting = nil
        node.setVisible(false)
        node.setVisible(true)
        self.drain(1.0)
        XCTAssertNil(node.widgetView, "a widget that failed to start was booted again")
    }

    func testAPreviewWithAnUndecodablePayloadShowsNoWidget() throws {
        let node = try self.node()
        var heights: [CGFloat] = []
        node.onContentHeightChange = { heights.append($0) }
        self.update(node, TelegramMediaWidget(width: 0, height: 0, payload: Data([1, 2, 3])))
        self.drain(1.0)
        XCTAssertNil(node.widgetView)
        XCTAssertEqual(heights, [])
    }
}
