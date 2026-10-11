import XCTest
import SwiftSignalKit
import Postbox
import TelegramCore
@testable import HarnessAppContext

final class HarnessAccountTests: XCTestCase {
    /// The whole premise of the harness's app context. `Account`'s designated initialiser is
    /// internal to TelegramCore, so if this cannot produce one, the harness cannot host the real
    /// panel at all and the design's §4.3 has to change.
    func testMakeProducesAnAuthorizedAccountForTheHarnessPeer() {
        let done = XCTestExpectation(description: "account created")
        var received: HarnessAccount?
        let disposable = HarnessAccount.make().start(next: { value in
            received = value
            done.fulfill()
        })
        defer { disposable.dispose() }
        wait(for: [done], timeout: 60.0)

        XCTAssertNotNil(received, "no account was produced")
        XCTAssertEqual(received?.account.peerId, HarnessAccount.harnessPeerId)
    }

    /// Determinism: two harness launches must not share a database.
    func testEachAccountGetsItsOwnDisposableRoot() {
        var roots: [String] = []
        for _ in 0 ..< 2 {
            let done = XCTestExpectation(description: "account created")
            let disposable = HarnessAccount.make().start(next: { value in
                roots.append(value.rootPath)
                done.fulfill()
            })
            defer { disposable.dispose() }
            wait(for: [done], timeout: 60.0)
        }
        XCTAssertEqual(roots.count, 2)
        XCTAssertNotEqual(roots[0], roots[1])
        for root in roots {
            XCTAssertTrue(FileManager.default.fileExists(atPath: root), "root \(root) missing")
        }
    }
}
