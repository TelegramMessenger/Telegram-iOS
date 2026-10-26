import XCTest
import UIKit
@testable import ComposerHarnessLib

/// Runs INSIDE the harness app process (`ios_unit_test` with `test_host`). Proves two things at
/// once: that the hosted-test tier works at all, and that the app really came up on the engine
/// backend. "It compiled" has been a false signal in this programme often enough to be worth a
/// test of its own.
final class HarnessPanelSmokeTests: XCTestCase {
    /// The root view controller builds its panel only once the account signal delivers, which is
    /// asynchronous even though nothing touches the network. Polling the run loop is what makes
    /// these cases deterministic; asserting immediately after `loadViewIfNeeded()` reads the state
    /// one turn too early and fails with a nil `panelHost` that looks like a real defect.
    private func root() throws -> HarnessRootViewController {
        let value = try XCTUnwrap(AppDelegate.harnessRootViewController,
                                  "the app did not install a root view controller")
        value.loadViewIfNeeded()
        value.view.frame = CGRect(x: 0.0, y: 0.0, width: 402.0, height: 874.0)

        let deadline = Date().addingTimeInterval(30.0)
        while value.panelHost == nil && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.02))
        }
        XCTAssertNotNil(value.panelHost, "the panel host was never built")

        value.view.layoutIfNeeded()
        return value
    }

    func testThePanelExists() throws {
        XCTAssertNotNil(try self.root().panelHost?.panel)
    }

    /// Reports the arm we GOT, never the arm we asked for. `liveBackend` is optional because
    /// "no input node built" is a third state; unwrapping it here asserts that one exists at all.
    func testTheEngineBackendIsActuallyLive() throws {
        let host = try XCTUnwrap(try self.root().panelHost)
        let backend = try XCTUnwrap(host.liveBackend, "the panel built no rich input node")
        XCTAssertEqual(backend, .engine)
    }

    func testThePanelReportsANonZeroHeight() throws {
        let host = try XCTUnwrap(try self.root().panelHost)
        XCTAssertGreaterThan(host.updateLayout(width: 402.0, bottomInset: 0.0), 0.0)
    }
}
