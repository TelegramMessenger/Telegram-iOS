import XCTest
import UIKit
@testable import WidgetHarnessLib

/// Tier 1 (in the app process): a widget's localStorage through the REAL chat bubbles (SDK v1 §2.8, §5.4; V2b plan,
/// Task 9): a widget built again for its message reads what it stored, through the store's memory before any write.
final class WidgetHarnessStorageTests: XCTestCase {
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

    private func load(_ options: WidgetHarnessLaunchOptions, until ready: ([String]) -> Bool) throws -> [String] {
        let root = try self.root()
        root.reload(options: options)
        let deadline = Date(timeIntervalSinceNow: 20.0)
        var lines: [String] = []
        while Date() < deadline {
            root.view.layoutIfNeeded()
            lines = root.readoutLines().filter { $0.hasPrefix("bubble ") }
            if ready(lines) {
                break
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        return lines
    }

    /// Review Focus 2: the bubbles rebuilt (a reload makes new nodes for the same messages) and the widget's second boot
    /// counts 2, read from the store before its 1 s write could land.
    func testAWidgetsLocalStorageSurvivesItsRebuild() throws {
        var options = WidgetHarnessLaunchOptions()
        options.set = .fixture
        options.postFilter = "storage-counter"
        let first = try self.load(options, until: { lines in lines.contains { $0.contains("storage-counter") && $0.contains("x100 ") } })
        XCTAssertTrue(first.contains { $0.contains("x100 ") }, first.joined(separator: "\n"))
        // The commit reaches the store on the main queue after its snapshot; 0.2 s is well inside the 1 s write delay.
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.2))
        let second = try self.load(options, until: { lines in lines.contains { $0.contains("storage-counter") && $0.contains("x150 ") } })
        XCTAssertTrue(second.contains { $0.contains("x150 ") }, second.joined(separator: "\n"))
    }
}
