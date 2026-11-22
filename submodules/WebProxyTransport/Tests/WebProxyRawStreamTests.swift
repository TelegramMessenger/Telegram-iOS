import XCTest
@testable import WebProxyTransport

final class WebProxyRawStreamTests: XCTestCase {
    private final class Page {
        private let lock = NSLock()
        private var frames: [WebProxyFrame] = []

        func record(_ frame: WebProxyFrame) {
            self.lock.lock()
            self.frames.append(frame)
            self.lock.unlock()
        }

        func sent(_ type: WebProxyFrameType, streamId: UInt32) -> [WebProxyFrame] {
            self.lock.lock()
            defer { self.lock.unlock() }
            return self.frames.filter { $0.type == type && $0.streamId == streamId }
        }

        func dataBytes(streamId: UInt32) -> Int {
            return self.sent(.data, streamId: streamId).reduce(0) { $0 + $1.payload.count }
        }

        func windowGranted(streamId: UInt32) -> Int {
            return self.sent(.window, streamId: streamId).reduce(0) { $0 + Int($1.windowDelta ?? 0) }
        }
    }

    private final class Owner {
        let queue = DispatchQueue(label: "WebProxyRawStreamTests.owner")
        private(set) var opened = false
        private(set) var received = 0
        private(set) var sent = 0
        private(set) var closed: Error??
        private(set) var closeCount = 0

        func open(_ transport: WebProxyTransport, timeout: TimeInterval = 10.0) -> WebProxyRawStream {
            return transport.openRawStream(timeout: timeout, queue: self.queue, opened: { [unowned self] in
                self.opened = true
            }, received: { [unowned self] data in
                self.received += data.count
            }, sent: { [unowned self] count in
                self.sent += count
            }, closed: { [unowned self] error in
                self.closed = .some(error)
                self.closeCount += 1
            })
        }

        func settled<T>(_ read: () -> T) -> T {
            return self.queue.sync(execute: read)
        }
    }

    private func transport(_ page: Page) throws -> WebProxyTransport {
        let configuration = try XCTUnwrap(WebProxyConfiguration(host: "proxy.example.com", secret: XCTUnwrap(WebProxyConfiguration.parseSecret("000102030405060708090a0b0c0d0e0f"))))
        let transport = WebProxyTransport()
        transport.attachTestPage(configuration: configuration, page: page.record)
        return transport
    }

    private func wait(_ owner: Owner, timeout: TimeInterval = 5.0, until condition: @escaping () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if owner.settled(condition) {
                return
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        XCTFail("condition not met in \(timeout) s")
    }

    func testWritesAreConfirmedOnlyAsTheyLeaveWithinTheWindow() throws {
        let page = Page()
        let transport = try self.transport(page)
        let owner = Owner()
        let stream = owner.open(transport)
        self.wait(owner) { owner.opened }
        XCTAssertEqual(page.sent(.open, streamId: 1).count, 1)

        let total = WebProxyProtocol.initialWindow + 100_000
        stream.write(Data(count: total))
        self.wait(owner) { owner.sent == WebProxyProtocol.initialWindow }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(owner.settled { owner.sent }, WebProxyProtocol.initialWindow, "nothing past the window is confirmed")
        XCTAssertEqual(page.dataBytes(streamId: 1), WebProxyProtocol.initialWindow)
        XCTAssertTrue(page.sent(.data, streamId: 1).allSatisfy { $0.payload.count <= WebProxyProtocol.maximumDataPayload })

        transport.receiveFromTestPage(.window(streamId: 1, delta: 60_000))
        self.wait(owner) { owner.sent == WebProxyProtocol.initialWindow + 60_000 }
        transport.receiveFromTestPage(.window(streamId: 1, delta: 60_000))
        self.wait(owner) { owner.sent == total }
        XCTAssertEqual(page.dataBytes(streamId: 1), total)
    }

    func testReceivedBytesAreGrantedBackWhenTheOwnerConsumesThem() throws {
        let page = Page()
        let transport = try self.transport(page)
        let owner = Owner()
        let stream = owner.open(transport)
        self.wait(owner) { owner.opened }

        transport.receiveFromTestPage(WebProxyFrame(type: .data, streamId: 1, payload: Data(count: 300_000)))
        self.wait(owner) { owner.received == 300_000 }
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(page.windowGranted(streamId: 1), 0, "credit stays with the owner until it takes the bytes")

        stream.consumed(200_000)
        self.wait(owner) { page.windowGranted(streamId: 1) == 200_000 }
        stream.consumed(100_000)
        self.wait(owner) { page.windowGranted(streamId: 1) == 300_000 }
    }

    func testPacedStreamsAreBoundByTheirOwnWindowNotTheSharedCap() throws {
        let page = Page()
        let transport = try self.transport(page)
        let count = WebProxyProtocol.maximumQueuedBytes / WebProxyProtocol.initialWindow + 1
        let owners = (0 ..< count).map { _ in Owner() }
        let streams = owners.map { $0.open(transport) }
        for owner in owners {
            self.wait(owner) { owner.opened }
        }
        let chunk = WebProxyProtocol.maximumPayload
        for streamId in 1 ... UInt32(count) {
            for _ in 0 ..< WebProxyProtocol.initialWindow / chunk {
                transport.receiveFromTestPage(WebProxyFrame(type: .data, streamId: streamId, payload: Data(count: chunk)))
            }
        }
        for owner in owners {
            self.wait(owner) { owner.received == WebProxyProtocol.initialWindow }
        }
        for owner in owners {
            XCTAssertNil(owner.settled { owner.closed }, "a full window held by its owner closes nothing")
        }

        transport.receiveFromTestPage(WebProxyFrame(type: .data, streamId: 1, payload: Data(count: 1)))
        self.wait(owners[0]) { owners[0].closed != nil }
        XCTAssertEqual(page.sent(.close, streamId: 1).count, 1, "a byte past the window breaks flow control")
        _ = streams
    }

    func testARestartClosesTheStreamAndConfirmsNothingThatNeverLeft() throws {
        let page = Page()
        let transport = try self.transport(page)
        let owner = Owner()
        let stream = owner.open(transport)
        self.wait(owner) { owner.opened }
        stream.write(Data(count: WebProxyProtocol.initialWindow + 50_000))
        self.wait(owner) { owner.sent == WebProxyProtocol.initialWindow }

        transport.restartTestPage()
        self.wait(owner) { owner.closed != nil }
        XCTAssertTrue(owner.settled { owner.closed.flatMap { $0 } } is WebProxyTransportError)
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertEqual(owner.settled { owner.sent }, WebProxyProtocol.initialWindow)
    }

    func testAStreamFromBeforeARestartCannotTouchTheOneThatReusedItsId() throws {
        let page = Page()
        let transport = try self.transport(page)
        let old = Owner()
        let oldStream = old.open(transport)
        self.wait(old) { old.opened }
        transport.restartTestPage()
        self.wait(old) { old.closed != nil }

        let fresh = Owner()
        let freshStream = fresh.open(transport)
        self.wait(fresh) { fresh.opened }
        XCTAssertEqual(page.sent(.open, streamId: 1).count, 2, "the new stream got id 1 again")

        oldStream.write(Data(count: 1000))
        oldStream.consumed(1000)
        oldStream.close()
        freshStream.write(Data(count: 10))
        self.wait(fresh) { fresh.sent == 10 }
        XCTAssertEqual(page.dataBytes(streamId: 1), 10, "only the new stream's bytes went")
        XCTAssertEqual(page.windowGranted(streamId: 1), 0)
        XCTAssertEqual(page.sent(.close, streamId: 1).count, 0)
        XCTAssertNil(fresh.settled { fresh.closed })
    }

    func testTheRelayClosingTheStreamReachesTheOwnerOnce() throws {
        let page = Page()
        let transport = try self.transport(page)
        let owner = Owner()
        let stream = owner.open(transport)
        self.wait(owner) { owner.opened }
        transport.receiveFromTestPage(WebProxyFrame(type: .close, streamId: 1))
        self.wait(owner) { owner.closed != nil }
        XCTAssertNil(owner.settled { owner.closed.flatMap { $0 } })
        stream.write(Data(count: 10))
        stream.close()
        transport.receiveFromTestPage(WebProxyFrame(type: .close, streamId: 1))
        let next = Owner()
        _ = next.open(transport)
        self.wait(next) { next.opened }
        XCTAssertEqual(page.sent(.open, streamId: 2).count, 1, "a late close for a closed stream leaves the carrier up")
        XCTAssertEqual(page.dataBytes(streamId: 1), 0)
        XCTAssertEqual(owner.settled { owner.sent }, 0)
        XCTAssertEqual(owner.settled { owner.closeCount }, 1)
        XCTAssertEqual(page.sent(.close, streamId: 1).count, 0, "a stream the relay closed is not closed back")
    }
}
