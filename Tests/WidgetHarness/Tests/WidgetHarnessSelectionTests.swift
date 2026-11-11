import XCTest
import UIKit
import AsyncDisplayKit
import MessageWidget
import TextSelectionNode
@testable import WidgetHarnessLib

/// Tier 1: a text selection in a lifted widget bubble (sdk-v1 §5.10) goes with the widget it was made on.
final class WidgetHarnessSelectionTests: XCTestCase {
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

    private func wait(_ root: WidgetHarnessRootViewController, until condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: 20.0)
        while Date() < deadline {
            root.view.layoutIfNeeded()
            if condition() {
                return true
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return false
    }

    private func find<T>(_ type: T.Type, in view: UIView) -> [UIView] {
        return (view is T ? [view] : []) + view.subviews.flatMap { self.find(type, in: $0) }
    }

    private func count<T>(_ type: T.Type, in view: UIView) -> Int {
        return (view is T ? 1 : 0) + view.subviews.reduce(0) { $0 + self.count(type, in: $1) }
    }

    /// Review Focus 2: the kill switch turns a lifted widget with a selection into the pill; the selection, its overlay
    /// (which would take every touch on the bubble) and its highlight go with it.
    func testASelectionGoesWhenTheWidgetIsReplaced() throws {
        let root = try self.root()
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "selection"
        options.captions = false
        options.holdsMenu = true
        root.reload(options: options)
        defer {
            root.listHost?.endContextMenu()
            MessageWidgetKillSwitch.isEngaged = false
        }
        XCTAssertTrue(self.wait(root) { root.readoutLines().contains { $0.hasPrefix("bubble ") && $0.contains(" widget") } })
        root.listHost?.openContextMenuOnNewestWidget()
        XCTAssertTrue(self.wait(root) { self.count(TextSelectionNodeView.self, in: root.view) == 1 }, "no selection overlay after the lift")
        // A word selected, its menu showing (as a hold on it begins one: the recognizer's own entry).
        let overlay = try XCTUnwrap(self.find(TextSelectionNodeView.self, in: root.view).first)
        let node = try XCTUnwrap(overlay.asyncdisplaykit_node as? TextSelectionNode)
        node.recognizer?.beginSelection?(CGPoint(x: 70.0, y: 10.0))
        XCTAssertTrue(self.wait(root) { root.readoutLines().contains { $0.hasPrefix("selectionMenu") } })

        MessageWidgetKillSwitch.isEngaged = true
        XCTAssertTrue(self.wait(root) { root.readoutLines().contains { $0.hasPrefix("bubble ") && $0.contains(" pill") } })
        XCTAssertEqual(self.count(TextSelectionNodeView.self, in: root.view), 0)
        XCTAssertEqual(self.count(MessageWidgetView.self, in: root.view), 0)
        // Final review I1: its menu went with it, rather than floating on with a Copy that does nothing.
        XCTAssertTrue(root.readoutLines().contains("selectionMenuDismissed"), root.readoutLines().joined(separator: " | "))
    }
}
