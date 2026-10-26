import Foundation
import XCTest
import TelegramApiObjC
@testable import TelegramApi

private func peer(_ id: Int64) -> Api.Peer {
    return .peerUser(Api.Peer.Cons_peerUser(userId: id))
}

private func assertNoLeak(_ name: String, file: StaticString = #filePath, line: UInt = #line, _ body: () -> Void) {
    let before = TLObjectLiveCount()
    body()
    XCTAssertEqual(TLObjectLiveCount(), before, "\(name) leaked", file: file, line: line)
}

final class LeakTests: XCTestCase {
    func testOwnershipPatternsAreBalanced() {
        assertNoLeak("create/destroy") { _ = peer(1) }
        assertNoLeak("copy + switch") {
            let a = peer(1)
            let b = a
            if case let .peerUser(data) = b { XCTAssertEqual(data.userId, 1) }
        }
        assertNoLeak("wrap/unwrap") {
            let b = Api.Peer(tlObject: peer(2).tlObject)
            if case let .peerUser(data) = b { XCTAssertEqual(data.userId, 2) }
        }
        assertNoLeak("arrays + map/filter") {
            let peers = (0 ..< 10).map { peer(Int64($0)) }
            XCTAssertEqual(peers.filter { if case .peerUser = $0 { return true } else { return false } }.count, 10)
        }
        assertNoLeak("optional") {
            var p: Api.Peer? = peer(3)
            p = nil
            XCTAssertNil(p)
        }
        assertNoLeak("dictionary") {
            var d: [Int: Api.Peer] = [:]
            d[1] = peer(1)
            d[2] = peer(2)
            d[1] = nil
            XCTAssertEqual(d.count, 1)
        }
        assertNoLeak("Any round trip") {
            let any: Any = peer(4)
            XCTAssertNotNil(any as? Api.Peer)
        }
        assertNoLeak("closure capture") {
            let p = peer(5)
            var f: (() -> Void)? = { _ = p }
            f?()
            f = nil
        }
    }

    func testEveryGoldenFixtureIsBalanced() {
        for fixture in goldenFixtures {
            assertNoLeak(fixture.name) {
                let buffer = Buffer()
                Api.serializeObject(fixture.value, buffer: buffer, boxed: true)
                let parsed = Api.parse(Buffer(data: buffer.makeData()))
                XCTAssertNotNil(parsed)
                _ = loggerDescription(redact: true, of: parsed as Any)
            }
        }
    }

    func testConcurrentReadsOfOneObjectAreBalanced() {
        assertNoLeak("concurrent getters") {
            let message = Api.Updates.updateShortMessage(Api.Updates.Cons_updateShortMessage(
                flags: 1 << 7, id: 1, userId: 2, message: "m", pts: 3, ptsCount: 1, date: 4,
                fwdFrom: nil, viaBotId: nil, replyTo: nil,
                entities: [.messageEntityBold(Api.MessageEntity.Cons_messageEntityBold(offset: 0, length: 1))],
                ttlPeriod: nil))
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
                for _ in 0 ..< 5_000 {
                    if case let .updateShortMessage(data) = message {
                        XCTAssertEqual(data.entities?.count, 1)
                        XCTAssertEqual(data.message, "m")
                    }
                }
            }
        }
    }

    func testEveryConstructorFixtureParsesAndSerializesWithoutLeaking() {
        for fixture in schemaConstructorFixtures {
            assertNoLeak(fixture.name) {
                _ = schemaConstructorRecord(fixture)
            }
        }
    }

    func testEveryFunctionFixtureWithoutLeaking() {
        for fixture in schemaFunctionFixtures {
            assertNoLeak(fixture.name) {
                _ = schemaFunctionRecord(fixture)
            }
        }
    }

    func testConcurrentFirstParseOfManyConstructors() {
        let payloads = schemaConstructorFixtures.prefix(400).map { fixture -> Data in
            let buffer = Buffer()
            Api.serializeObject(fixture.make(), buffer: buffer, boxed: true)
            return buffer.makeData()
        }
        assertNoLeak("concurrent parse") {
            DispatchQueue.concurrentPerform(iterations: 8) { _ in
                for payload in payloads {
                    XCTAssertNotNil(Api.parse(Buffer(data: payload)))
                }
            }
        }
    }

    func testSwiftInitializersBalanceEveryReference() {
        for fixture in schemaConstructorFixtures {
            assertNoLeak(fixture.name) { _ = fixture.make() }
        }
    }
}
