import Foundation
import XCTest
@testable import TelegramApi

/// `"\(apiValue)"` bypasses the logger's redaction, so an Api value describes itself by its
/// constructor name only, never by field values. This also keeps printing independent of Swift
/// reflection metadata, which TelegramApi's release build omits.
final class ApiDescriptionTests: XCTestCase {
    func testInterpolationShowsTheConstructorNameOnly() {
        let peer = Api.Peer.peerUser(Api.Peer.Cons_peerUser(userId: 987654321))
        XCTAssertEqual("\(peer)", "peerUser")
        XCTAssertEqual(String(describing: peer), "peerUser")
        XCTAssertFalse("\(peer)".contains("987654321"))
        XCTAssertEqual("\(Api.Bool.boolTrue)", "boolTrue")
    }

    func testEveryFixtureDescribesAsItsConstructor() {
        for fixture in schemaConstructorFixtures {
            let value = fixture.make()
            let constructor = String(fixture.name.split(separator: "#")[0].split(separator: ".").last!)
            XCTAssertEqual(String(describing: value), constructor, fixture.name)
        }
    }
}
