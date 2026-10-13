import XCTest
import SwiftSignalKit
import MtProtoKit
import EncryptionProvider
import MTProtoEngineFFI
@testable import TelegramCore
@testable import MTProtoRustEngine
import MTProtoRustEngineMapping

private let callConstructor: UInt32 = 0x7e57_0001
private let callResultConstructor: UInt32 = 0x7e57_0002
private let tagFloodOnce: UInt32 = 1001
private let tagDropConnectionOnce: UInt32 = 1002
private let tagNever: UInt32 = 1004
private let tagBadSaltOnce: UInt32 = 1007

private final class TestServerProcess {
    let address: String
    let port: Int32
    let key: Data
    let salt: Int64
    let publicKeyPem: String
    let webFront: (host: String, port: UInt16)?
    let blackhole: (host: String, port: UInt16)?

    private let process: Process
    private let input: Pipe
    private let output: Pipe
    private var buffer = Data()

    static func binaryPath() -> String? {
        let engineDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("../../../../third-party/mtproto-engine/target")
            .standardizedFileURL
        for configuration in ["release", "debug"] {
            let path = engineDirectory.appendingPathComponent("\(configuration)/mtproto-testserver").path
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        return nil
    }

    init(binary: String) throws {
        self.process = Process()
        self.input = Pipe()
        self.output = Pipe()
        self.process.executableURL = URL(fileURLWithPath: binary)
        self.process.arguments = ["--web-front"]
        self.process.standardInput = self.input
        self.process.standardOutput = self.output
        self.process.standardError = FileHandle.nullDevice
        try self.process.run()

        var line: String?
        let handle = self.output.fileHandleForReading
        while line == nil {
            let chunk = handle.availableData
            if chunk.isEmpty {
                break
            }
            self.buffer.append(chunk)
            line = TestServerProcess.takeLine(&self.buffer)
        }
        guard let ready = line, let object = try JSONSerialization.jsonObject(with: Data(ready.utf8)) as? [String: Any], let address = object["address"] as? String, let keyHex = object["key_hex"] as? String, let salt = object["salt"] as? NSNumber, let publicKeyPem = object["public_key_pem"] as? String, let separator = address.lastIndex(of: ":"), let port = Int32(address[address.index(after: separator)...]) else {
            throw NSError(domain: "TestServerProcess", code: 1)
        }
        self.publicKeyPem = publicKeyPem
        self.webFront = (object["web_front"] as? String).flatMap(TestServerProcess.hostAndPort)
        self.blackhole = (object["blackhole"] as? String).flatMap(TestServerProcess.hostAndPort)
        self.address = String(address[..<separator])
        self.port = port
        self.key = TestServerProcess.data(hex: keyHex)
        self.salt = salt.int64Value
    }

    deinit {
        self.input.fileHandleForWriting.write(Data("quit\n".utf8))
        self.process.waitUntilExit()
    }

    private static func hostAndPort(_ text: String) -> (host: String, port: UInt16)? {
        guard let separator = text.lastIndex(of: ":"), let port = UInt16(text[text.index(after: separator)...]) else {
            return nil
        }
        return (String(text[..<separator]), port)
    }

    func webFrontStats() -> [String: Any] {
        return self.stats(command: "web-front-stats")
    }

    func stats(command: String = "stats") -> [String: Any] {
        self.input.fileHandleForWriting.write(Data("\(command)\n".utf8))
        let handle = self.output.fileHandleForReading
        while true {
            if let line = TestServerProcess.takeLine(&self.buffer) {
                return ((try? JSONSerialization.jsonObject(with: Data(line.utf8))) as? [String: Any]) ?? [:]
            }
            let chunk = handle.availableData
            if chunk.isEmpty {
                return [:]
            }
            self.buffer.append(chunk)
        }
    }

    func executions(tag: UInt32) -> Int {
        return ((self.stats()["tags"] as? [String: Any])?["\(tag)"] as? NSNumber)?.intValue ?? 0
    }

    func handshakes() -> [(datacenterId: Int, temporary: Bool)] {
        let entries = (self.stats()["handshake_dcs"] as? [[String: Any]]) ?? []
        return entries.map { entry in
            ((entry["dc"] as? NSNumber)?.intValue ?? 0, (entry["temporary"] as? Bool) ?? false)
        }
    }

    func invokeAfterWrappers() -> Int {
        return (self.stats()["invoke_after"] as? NSNumber)?.intValue ?? 0
    }

    func binds() -> Int {
        return (self.stats()["binds"] as? NSNumber)?.intValue ?? 0
    }

    func dropTemporaryKeys() {
        self.input.fileHandleForWriting.write(Data("drop-temporary-keys\n".utf8))
        _ = self.stats()
    }

    func addKey(_ key: Data) {
        let hex = key.map { String(format: "%02x", $0) }.joined()
        self.input.fileHandleForWriting.write(Data("add-key \(hex)\n".utf8))
        _ = self.stats()
    }

    func setWebSocketRefused(_ refused: Bool) {
        self.input.fileHandleForWriting.write(Data("websocket-refused \(refused ? "on" : "off")\n".utf8))
        _ = self.stats()
    }

    func setTcpBlackhole(_ enabled: Bool) {
        self.input.fileHandleForWriting.write(Data("tcp-blackhole \(enabled ? "on" : "off")\n".utf8))
    }

    func obfuscationDatacenterIds() -> [Int] {
        return ((self.stats()["obfuscation_dc_ids"] as? [NSNumber]) ?? []).map { $0.intValue }
    }

    private static func takeLine(_ buffer: inout Data) -> String? {
        guard let index = buffer.firstIndex(of: 0x0a) else {
            return nil
        }
        let line = String(decoding: buffer[buffer.startIndex ..< index], as: UTF8.self)
        buffer.removeSubrange(buffer.startIndex ... index)
        return line
    }

    private static func data(hex: String) -> Data {
        var result = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            result.append(UInt8(hex[index ..< next], radix: 16) ?? 0)
            index = next
        }
        return result
    }
}

private final class InMemoryKeychain: NSObject, MTKeychain {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    func setObject(_ object: Any!, forKey aKey: String!, group: String!) {
        guard let object = object, let data = try? NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false) else {
            return
        }
        self.lock.lock()
        self.storage[group + ":" + aKey] = data
        self.lock.unlock()
    }

    private func value(_ aKey: String, _ group: String) -> Any? {
        self.lock.lock()
        let data = self.storage[group + ":" + aKey]
        self.lock.unlock()
        return data.flatMap { MTDeprecated.unarchiveDeprecated(with: $0) }
    }

    func dictionary(forKey aKey: String!, group: String!) -> [AnyHashable: Any]? {
        return (self.value(aKey, group) as? NSDictionary) as? [AnyHashable: Any]
    }

    func number(forKey aKey: String!, group: String!) -> NSNumber? {
        return self.value(aKey, group) as? NSNumber
    }

    func removeObject(forKey aKey: String!, group: String!) {
        self.lock.lock()
        self.storage.removeValue(forKey: group + ":" + aKey)
        self.lock.unlock()
    }
}

private final class UnusedEncryptionProvider: NSObject, EncryptionProvider {
    func createBignumContext() -> MTBignumContext {
        preconditionFailure("the seeded auth key makes MtProtoKit cryptography unnecessary")
    }

    func rsaEncrypt(withPublicKey publicKey: String, data: Data) -> Data? {
        return nil
    }

    func rsaEncryptPKCS1OAEP(withPublicKey publicKey: String, data: Data) -> Data? {
        return nil
    }

    func parseRSAPublicKey(_ publicKey: String) -> MTRsaPublicKey {
        preconditionFailure("the seeded auth key makes MtProtoKit cryptography unnecessary")
    }

    func macosRSAEncrypt(_ publicKey: String, data: Data) -> Data {
        return Data()
    }
}

private final class StateRecorder: NetworkEngineSessionDelegate {
    private let lock = NSLock()
    private var states: [NetworkEngineConnectionState] = []

    func networkSessionAuthorizationRequired() {
    }

    func networkSessionSoftAuthReset() {
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        self.lock.lock()
        self.states.append(state)
        self.lock.unlock()
    }

    var sawConnected: Bool {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.states.contains(where: { $0.isConnected })
    }
}

private struct CallResult: Equatable {
    let tag: UInt32
    let payload: Data
}

final class RustEngineEndToEndTests: XCTestCase {
    private static let datacenterId = 2
    private static let timeout: TimeInterval = 15.0

    private var server: TestServerProcess!
    private var context: MTContext!
    private var engine: NetworkEngine!

    override func setUpWithError() throws {
        try super.setUpWithError()
        guard let binary = TestServerProcess.binaryPath() else {
            throw XCTSkip("build third-party/mtproto-engine first: cargo build --release -p mtproto-testserver")
        }
        guard RustEngineRuntime.shared != nil else {
            XCTFail("engine did not start")
            return
        }
        self.server = try TestServerProcess(binary: binary)

        let context = self.makeContext(useTempAuthKeys: false)
        self.setAddress(of: context, preferForMedia: false)
        context.updateAuthInfoForDatacenter(withId: RustEngineEndToEndTests.datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        self.context = context

        guard let engine = RustNetworkEngineFactory().makeEngine(context: context, isAppExtension: false) else {
            XCTFail("factory declined a plain configuration")
            return
        }
        XCTAssertEqual(engine.kind, NetworkEngineKind.rust)
        self.engine = engine
    }

    override func tearDown() {
        self.engine = nil
        self.context = nil
        self.server = nil
        super.tearDown()
    }

    private func makeContext(useTempAuthKeys: Bool) -> MTContext {
        let serialization = Serialization()
        var apiEnvironment = MTApiEnvironment(deviceModelName: "MTProtoRustEngine end-to-end tests")
        apiEnvironment.apiId = 9
        apiEnvironment.appVersion = "1.0"
        apiEnvironment.langPack = "macos"
        apiEnvironment.layer = NSNumber(value: Int(serialization.currentLayer()))
        apiEnvironment.disableUpdates = false
        apiEnvironment = apiEnvironment.withUpdatedLangPackCode("en")
        let context = MTContext(serialization: serialization, encryptionProvider: UnusedEncryptionProvider(), apiEnvironment: apiEnvironment, isTestingEnvironment: false, useTempAuthKeys: useTempAuthKeys)
        context.keychain = InMemoryKeychain()
        return context
    }

    private func setAddress(of context: MTContext, preferForMedia: Bool) {
        let address = MTDatacenterAddress(ip: self.server.address, port: UInt16(self.server.port), preferForMedia: preferForMedia, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        context.updateAddressSetForDatacenter(withId: RustEngineEndToEndTests.datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
    }

    private func authInfo(key: Data, validUntil: Int32 = Int32.max) -> MTDatacenterAuthInfo {
        let keyHash = MTSha1(key)
        var authKeyId: Int64 = 0
        _ = withUnsafeMutableBytes(of: &authKeyId) { buffer in
            keyHash.copyBytes(to: buffer, from: keyHash.count - 8 ..< keyHash.count)
        }
        let now = Int64(Date().timeIntervalSince1970)
        let saltInfo = MTDatacenterSaltInfo(salt: self.server.salt, firstValidMessageId: (now - 86_400) << 32, lastValidMessageId: (now + 86_400) << 32)!
        return MTDatacenterAuthInfo(authKey: key, authKeyId: authKeyId, validUntilTimestamp: validUntil, saltSet: [saltInfo], authKeyAttributes: [:])!
    }

    private static func append(_ value: UInt32, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func readUInt32(_ data: Data, _ offset: Int) -> UInt32? {
        guard offset + 4 <= data.count else {
            return nil
        }
        return data.subdata(in: offset ..< offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }.littleEndian
    }

    private func call(tag: UInt32, payload: Data = Data()) -> Data {
        var data = Data()
        RustEngineEndToEndTests.append(callConstructor, to: &data)
        RustEngineEndToEndTests.append(tag, to: &data)
        if payload.count < 254 {
            data.append(UInt8(payload.count))
        } else {
            RustEngineEndToEndTests.append(UInt32(payload.count) << 8 | 254, to: &data)
        }
        data.append(payload)
        while data.count % 4 != 0 {
            data.append(0)
        }
        return data
    }

    private static func parse(_ data: Data) -> Any? {
        guard readUInt32(data, 0) == callResultConstructor, let tag = readUInt32(data, 4), data.count > 8 else {
            return nil
        }
        let first = Int(data[data.startIndex + 8])
        let length: Int
        let start: Int
        if first < 254 {
            length = first
            start = 9
        } else {
            guard let header = readUInt32(data, 8) else {
                return nil
            }
            length = Int(header >> 8)
            start = 12
        }
        guard start + length <= data.count else {
            return nil
        }
        return CallResult(tag: tag, payload: data.subdata(in: data.startIndex + start ..< data.startIndex + start + length))
    }

    private func request(
        tag: UInt32,
        payload: Data = Data(),
        options: NetworkEngineRequestOptions = NetworkEngineRequestOptions(),
        shouldContinueAfterError: @escaping (NetworkEngineErrorContext) -> Bool = { _ in false },
        acknowledged: (() -> Void)? = nil,
        dependsOn: ((WrappedRequestMetadata) -> Bool)? = nil,
        label: String? = nil,
        completed: @escaping (Result<NetworkEngineResponse, NetworkEngineRequestFailure>) -> Void
    ) -> NetworkEngineRequest {
        let description = label ?? "call \(tag)"
        return NetworkEngineRequest(
            payload: self.call(tag: tag, payload: payload),
            metadata: WrappedRequestMetadata(metadata: description, tag: nil),
            shortMetadata: WrappedRequestShortMetadata(shortMetadata: description),
            parse: RustEngineEndToEndTests.parse,
            options: options,
            shouldContinueAfterError: shouldContinueAfterError,
            dependsOn: dependsOn,
            acknowledged: acknowledged,
            progress: nil,
            completed: completed
        )
    }

    private func makeSession(delegate: NetworkEngineSessionDelegate? = nil, role: NetworkEngineSessionRole = .main) -> NetworkEngineSession {
        let session = self.engine.makeSession(datacenterId: RustEngineEndToEndTests.datacenterId, role: role, usageCalculationInfo: nil, delegate: delegate)
        session.setPaused(false)
        return session
    }

    func testRequestCompletesThroughContextEngineAndServer() {
        let recorder = StateRecorder()
        let session = self.makeSession(delegate: recorder)
        defer { session.stop() }
        let done = self.expectation(description: "completed")
        let payload = Data("hello from swift".utf8)
        let disposable = session.requestService.add(self.request(tag: 7, payload: payload) { result in
            switch result {
            case let .success(response):
                XCTAssertEqual(response.result as? CallResult, CallResult(tag: 7, payload: payload))
                XCTAssertGreaterThan(response.info.timestamp, 1_600_000_000)
            case let .failure(failure):
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertTrue(recorder.sawConnected)
        XCTAssertEqual(self.server.executions(tag: 7), 1)
    }

    func testMediaWorkerFollowsItsAddressesBetweenMediaAndMainKeys() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        guard let mainKey = self.keptTemporaryKey(media: false, tag: 71), let mediaKey = self.keptTemporaryKey(media: true, tag: 72) else {
            XCTFail("could not make the keys")
            return
        }
        XCTAssertNotEqual(mainKey.authKeyId, mediaKey.authKeyId)
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: mainKey, selector: .ephemeralMain)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: mediaKey, selector: .ephemeralMedia)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        let handshakes = self.server.handshakes().count

        self.setAddress(of: context, preferForMedia: false)
        guard self.completes(tag: 73, on: session) else {
            return
        }
        XCTAssertEqual(self.server.obfuscationDatacenterIds().last, datacenterId)

        self.setAddress(of: context, preferForMedia: true)
        guard self.completes(tag: 74, on: session) else {
            return
        }
        XCTAssertEqual(self.server.obfuscationDatacenterIds().last, -datacenterId)
        XCTAssertEqual(self.server.handshakes().count, handshakes, "both address classes ran under the keys the context keeps")
    }

    private func keptTemporaryKey(media: Bool, tag: UInt32) -> MTDatacenterAuthInfo? {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let selector: MTDatacenterAuthInfoSelector = media ? .ephemeralMedia : .ephemeralMain
        let context = self.pfsContext(permanentKey: true, preferForMedia: media)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: tag, on: session), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: selector) != nil }) else {
            return nil
        }
        return context.authInfoForDatacenter(withId: datacenterId, selector: selector)
    }

    private func runOverTelegramWeb(refuseWebSocket: Bool, firstTag: UInt32) throws -> [String: Any] {
        guard #available(macOS 10.14, *), let front = self.server.webFront, let blackhole = self.server.blackhole else {
            throw XCTSkip("needs macOS 10.14 and the test server's web front")
        }
        self.server.setWebSocketRefused(refuseWebSocket)
        RustNetworkSession.webEndpointOverride = (host: "venus.web.test", port: front.port, path: "/apiw1", wsPath: "/apiws", address: front.host)
        defer {
            RustNetworkSession.webEndpointOverride = nil
        }
        let address = MTDatacenterAddress(ip: blackhole.host, port: blackhole.port, preferForMedia: false, restrictToTcp: false, cdn: false, preferForProxy: false, secret: nil)
        self.context.updateAddressSetForDatacenter(withId: RustEngineEndToEndTests.datacenterId, addressSet: MTDatacenterAddressSet(addressList: [address]), forceUpdateSchemes: true)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        let session = self.makeSession()
        defer { session.stop() }
        let started = Date()
        guard self.completes(tag: firstTag, on: session) else {
            return [:]
        }
        XCTAssertTrue(self.completes(tag: firstTag + 1, on: session))
        XCTAssertLessThan(Date().timeIntervalSince(started), 8.0, "the web front is probed with the first round")
        let stats = self.server.webFrontStats()
        XCTAssertGreaterThan((stats["handshakes"] as? NSNumber)?.intValue ?? 0, 0, "\(stats)")
        XCTAssertEqual(Set((stats["server_names"] as? [String]) ?? []), ["venus.web.test"], "SNI is the web host")
        XCTAssertEqual(Set((stats["alpn"] as? [String]) ?? []), ["http/1.1"])
        XCTAssertEqual((stats["violations"] as? NSNumber)?.intValue ?? -1, 0, "no frame Telegram's server drops a connection for")
        return stats
    }

    func testTheStreamMovesToTelegramWebsWebSocketThroughTheNetworkFrameworkHost() throws {
        let stats = try self.runOverTelegramWeb(refuseWebSocket: false, firstTag: 41)
        XCTAssertGreaterThan((stats["websockets"] as? NSNumber)?.intValue ?? 0, 0, "\(stats)")
        let requests = (stats["requests"] as? [String]) ?? []
        XCTAssertTrue(requests.allSatisfy { $0 == "GET /apiws HTTP/1.1 @ venus.web.test:\(self.server.webFront?.port ?? 0)" }, "\(requests)")
    }

    func testTelegramWebsHttpsTakesOverWhenTheWebSocketIsRefused() throws {
        let stats = try self.runOverTelegramWeb(refuseWebSocket: true, firstTag: 43)
        let requests = (stats["requests"] as? [String]) ?? []
        XCTAssertTrue(requests.contains("POST /apiw1 HTTP/1.1 @ venus.web.test:\(self.server.webFront?.port ?? 0)"), "\(requests)")
    }

    private func completes(tag: UInt32, on session: NetworkEngineSession) -> Bool {
        let done = XCTestExpectation(description: "request \(tag) completed")
        let disposable = session.requestService.add(self.request(tag: tag) { result in
            if case let .failure(failure) = result {
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        let waited = XCTWaiter().wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        if waited != .completed {
            XCTFail("request \(tag) did not complete")
            return false
        }
        return true
    }

    func testConcurrentRequestsFromManyThreadsCompleteExactlyOnce() {
        let session = self.makeSession()
        defer { session.stop() }
        let count = 400
        let lock = NSLock()
        var completions: [Int: Int] = [:]
        let done = self.expectation(description: "all completed")
        done.expectedFulfillmentCount = count
        var disposables: [Disposable] = []
        DispatchQueue.concurrentPerform(iterations: count) { index in
            var payload = Data(count: 4)
            payload.withUnsafeMutableBytes { $0.storeBytes(of: UInt32(index).littleEndian, as: UInt32.self) }
            let disposable = session.requestService.add(self.request(tag: 100, payload: payload) { result in
                guard case let .success(response) = result, let value = response.result as? CallResult else {
                    XCTFail("request \(index) failed")
                    done.fulfill()
                    return
                }
                XCTAssertEqual(value.payload, payload)
                lock.lock()
                completions[index, default: 0] += 1
                lock.unlock()
                done.fulfill()
            })
            lock.lock()
            disposables.append(disposable)
            lock.unlock()
        }
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        XCTAssertEqual(completions.count, count)
        XCTAssertTrue(completions.values.allSatisfy { $0 == 1 })
        XCTAssertEqual(self.server.executions(tag: 100), count)
        disposables.forEach { $0.dispose() }
    }

    func testCancelledRequestNeverCompletes() {
        let session = self.makeSession()
        defer { session.stop() }
        let cancelled = self.request(tag: tagNever) { _ in
            XCTFail("a cancelled request must not complete")
        }
        let disposable = session.requestService.add(cancelled)
        disposable.dispose()
        let done = self.expectation(description: "next request completes")
        let next = session.requestService.add(self.request(tag: 8) { result in
            if case .failure = result {
                XCTFail("follow-up request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        next.dispose()
    }

    func testFloodWaitAsksTheRequestBeforeRetrying() {
        let session = self.makeSession()
        defer { session.stop() }
        let lock = NSLock()
        var contexts: [NetworkEngineErrorContext] = []
        let done = self.expectation(description: "completed after the flood wait")
        let disposable = session.requestService.add(self.request(tag: tagFloodOnce, shouldContinueAfterError: { context in
            lock.lock()
            contexts.append(context)
            lock.unlock()
            return true
        }) { result in
            if case let .failure(failure) = result {
                XCTFail("\(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertEqual(contexts.count, 1)
        XCTAssertEqual(contexts.first?.floodWaitSeconds, 1)
        XCTAssertEqual(contexts.first?.floodWaitErrorText, "FLOOD_WAIT_1")
        XCTAssertEqual(self.server.executions(tag: tagFloodOnce), 2)
    }

    func testFloodWaitDeclinedByTheRequestFailsWithTheServerError() {
        let session = self.makeSession()
        defer { session.stop() }
        let done = self.expectation(description: "failed")
        let disposable = session.requestService.add(self.request(tag: tagFloodOnce, shouldContinueAfterError: { _ in false }) { result in
            switch result {
            case .success:
                XCTFail("declined flood wait must fail")
            case let .failure(failure):
                XCTAssertEqual(failure.error.errorCode, 420)
                XCTAssertEqual(failure.error.errorDescription, "FLOOD_WAIT_1")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
    }

    func testDroppedConnectionCompletesOnceWithoutReexecution() {
        let session = self.makeSession()
        defer { session.stop() }
        let lock = NSLock()
        var completions = 0
        let done = self.expectation(description: "completed")
        let disposable = session.requestService.add(self.request(tag: tagDropConnectionOnce) { result in
            if case .failure = result {
                XCTFail("request failed")
            }
            lock.lock()
            completions += 1
            lock.unlock()
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(completions, 1)
        let stats = self.server.stats()
        XCTAssertEqual(self.server.executions(tag: tagDropConnectionOnce), 1)
        XCTAssertGreaterThanOrEqual((stats["connections"] as? NSNumber)?.intValue ?? 0, 2)
        XCTAssertEqual((stats["state_requests"] as? NSNumber)?.intValue, 0)
    }

    func testServerSaltChangeIsPersistedThroughTheContext() {
        let session = self.makeSession()
        defer { session.stop() }
        let done = self.expectation(description: "completed")
        let disposable = session.requestService.add(self.request(tag: tagBadSaltOnce) { result in
            if case .failure = result {
                XCTFail("request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        disposable.dispose()
        XCTAssertEqual(self.server.executions(tag: tagBadSaltOnce), 1)
        let expected = self.server.salt &+ 1
        let deadline = Date().addingTimeInterval(5.0)
        var persisted = false
        while Date() < deadline && !persisted {
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
            let authInfo = self.context.authInfoForDatacenter(withId: RustEngineEndToEndTests.datacenterId, selector: .persistent)
            persisted = authInfo?.saltSet.contains(where: { ($0 as? MTDatacenterSaltInfo)?.salt == expected }) ?? false
            if !persisted {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
        XCTAssertTrue(persisted, "MTContext must stay the single writer of salts")
    }

    func testOnlyNonCdnSessionsMoveTheAppClock() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let cdn = self.engine.makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: false, isCdn: true), usageCalculationInfo: nil, delegate: nil)
        let main = self.engine.makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer {
            cdn.stop()
            main.stop()
        }
        guard let cdnSession = cdn as? RustNetworkSession, let mainSession = main as? RustNetworkSession else {
            XCTFail("the Rust engine made a session of another type")
            return
        }
        let initial = self.context.globalTimeDifference()
        let deliver: (RustNetworkSession, Double) -> Void = { session, difference in
            var event = MTEvent()
            event.kind = MTEventKindTimeDifferenceUpdated
            event.value1 = difference
            session.handleEngineEvent(withUnsafePointer(to: &event) { RustEngineEvent($0) })
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        }

        deliver(cdnSession, initial + 86_400.0)
        XCTAssertEqual(self.context.globalTimeDifference(), initial, "a CDN must not set the app-wide clock")

        deliver(mainSession, initial + 30.0)
        XCTAssertEqual(self.context.globalTimeDifference(), initial + 30.0)
    }

    func testWorkerSessionSharesTheEngineWithTheMainSession() {
        let main = self.makeSession()
        let worker = self.makeSession(role: .worker(masterDatacenterId: RustEngineEndToEndTests.datacenterId, isMedia: true, isCdn: false))
        defer {
            main.stop()
            worker.stop()
        }
        let done = self.expectation(description: "both completed")
        done.expectedFulfillmentCount = 2
        let first = main.requestService.add(self.request(tag: 11) { result in
            if case .failure = result {
                XCTFail("main request failed")
            }
            done.fulfill()
        })
        let second = worker.requestService.add(self.request(tag: 12) { result in
            if case .failure = result {
                XCTFail("worker request failed")
            }
            done.fulfill()
        })
        self.wait(for: [done], timeout: RustEngineEndToEndTests.timeout)
        first.dispose()
        second.dispose()
    }

    private func pfsContext(permanentKey: Bool, preferForMedia: Bool = false) -> MTContext {
        let context = self.makeContext(useTempAuthKeys: true)
        self.setAddress(of: context, preferForMedia: preferForMedia)
        if permanentKey {
            context.updateAuthInfoForDatacenter(withId: RustEngineEndToEndTests.datacenterId, authInfo: self.authInfo(key: self.server.key), selector: .persistent)
        }
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        return context
    }

    private func pfsEngine(_ context: MTContext) -> NetworkEngine {
        return RustNetworkEngine(runtime: RustEngineRuntime.shared!, context: context, serverPublicKeys: [self.server.publicKeyPem], httpPort: 0)
    }

    private func eventually(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(RustEngineEndToEndTests.timeout)
        while Date() < deadline {
            MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return false
    }

    private var permanentKeyId: Int64 {
        return self.authInfo(key: self.server.key).authKeyId
    }

    func testTheEngineMakesBindsAndKeepsTheTemporaryKey() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 31, on: session) else {
            return
        }
        XCTAssertTrue(self.server.handshakes().map { $0.temporary } == [true], "one temporary key and no permanent one: \(self.server.handshakes())")
        XCTAssertEqual(self.server.binds(), 1)
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }, "the bound key is kept in the context")
        guard let kept = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) else {
            return
        }
        XCTAssertNotEqual(kept.authKeyId, self.permanentKeyId)
        XCTAssertEqual((kept.authKeyAttributes?[rustEngineBoundToAttribute] as? NSNumber)?.int64Value, self.permanentKeyId)
        let lifetime = Int64(kept.validUntilTimestamp) - Int64(Date().timeIntervalSince1970)
        XCTAssertTrue(abs(lifetime - Int64(context.tempKeyExpiration)) < 60, "valid until \(kept.validUntilTimestamp), \(lifetime) s from now")
        XCTAssertNil(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMedia))
    }

    func testANewSessionStartsUnderTheKeptTemporaryKey() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let first = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        first.setPaused(false)
        guard self.completes(tag: 32, on: first), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }) else {
            first.stop()
            return
        }
        first.stop()
        let second = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        second.setPaused(false)
        defer { second.stop() }
        guard self.completes(tag: 33, on: second) else {
            return
        }
        XCTAssertEqual(self.server.handshakes().count, 1, "the second session made no key")
        XCTAssertEqual(self.server.binds(), 1, "and bound nothing")
    }

    func testMediaKeysAreMadeForTheMediaDatacenterIdAndKeptApart() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 36, on: session) else {
            return
        }
        XCTAssertEqual(self.server.handshakes().map { $0.datacenterId }, [-datacenterId], "a media key, as MtProtoKit makes it")
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMedia) != nil })
        XCTAssertNil(context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain))
    }

    func testWithTcpBlockedKeysAreMadeAndBoundOverHttp() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        self.server.setTcpBlackhole(true)
        let context = self.pfsContext(permanentKey: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 37, on: session) else {
            return
        }
        XCTAssertEqual(self.server.handshakes().count, 1)
        XCTAssertEqual(self.server.binds(), 1)
        XCTAssertTrue(self.eventually { context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil })
    }

    func testAKeyKeptForTheOldPermanentKeyIsNotTakenAfterThePermanentKeyChanges() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        guard let boundToA = self.keptTemporaryKey(media: false, tag: 50) else {
            XCTFail("could not make the key")
            return
        }
        let otherPermanent = Data((0 ..< 256).map { _ in UInt8.random(in: 0 ... 255) })
        self.server.addKey(otherPermanent)
        let context = self.pfsContext(permanentKey: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 52, on: session), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }) else {
            return
        }
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: boundToA, selector: .ephemeralMain)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        Thread.sleep(forTimeInterval: 0.3)
        let handshakes = self.server.handshakes().count
        let binds = self.server.binds()
        let permanentB = self.authInfo(key: otherPermanent)
        context.updateAuthInfoForDatacenter(withId: datacenterId, authInfo: permanentB, selector: .persistent)
        MTContext.contextQueue().dispatch(onQueue: {}, synchronous: true)
        Thread.sleep(forTimeInterval: 0.3)
        guard self.completes(tag: 53, on: session) else {
            return
        }
        XCTAssertEqual(self.server.handshakes().count, handshakes + 1, "a new temporary key is made for the new permanent key")
        XCTAssertEqual(self.server.binds(), binds + 1, "and bound to it, instead of taking the key kept for the old one")
        XCTAssertTrue(self.eventually {
            (context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain)?.authKeyAttributes?[rustEngineBoundToAttribute] as? NSNumber)?.int64Value == permanentB.authKeyId
        }, "the context keeps the key bound to the new permanent key")
    }

    func testAKeyTheServerDroppedLeavesTheContextAndIsReplaced() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 54, on: session), self.eventually({ context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) != nil }), let dropped = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) else {
            return
        }
        self.server.dropTemporaryKeys()
        guard self.completes(tag: 55, on: session) else {
            return
        }
        XCTAssertTrue(self.eventually {
            guard let kept = context.authInfoForDatacenter(withId: datacenterId, selector: .ephemeralMain) else {
                return false
            }
            return kept.authKeyId != dropped.authKeyId
        }, "the dropped key left the context and the new one took its place")
        XCTAssertEqual(self.server.handshakes().count, 2)
    }

    func testACallInFlightAcrossAnAddressClassChangeGoesAgainUnderTheNewKey() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 63, on: session) else {
            return
        }
        let finished = XCTestExpectation(description: "the call in flight finished")
        finished.isInverted = true
        let outcome = Atomic<String>(value: "still pending")
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in true }) { result in
            if case let .failure(failure) = result {
                let _ = outcome.swap("failed \(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            } else {
                let _ = outcome.swap("completed")
            }
            finished.fulfill()
        })
        Thread.sleep(forTimeInterval: 0.5)
        self.setAddress(of: context, preferForMedia: false)
        _ = XCTWaiter().wait(for: [finished], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(outcome.with { $0 }, "still pending", "the call goes again under the new key, as with MtProtoKit")
        XCTAssertEqual(self.server.executions(tag: tagNever), 2, "it ran again under the new key")
    }

    func testACallThatMayNotRetryFailsWhenItsTemporaryKeyGoes() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 66, on: session) else {
            return
        }
        let finished = XCTestExpectation(description: "the call in flight failed")
        let outcome = Atomic<String>(value: "still pending")
        let disposable = session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in false }) { result in
            if case let .failure(failure) = result {
                let _ = outcome.swap("failed \(failure.error.errorCode) \(failure.error.errorDescription ?? "")")
            }
            finished.fulfill()
        })
        Thread.sleep(forTimeInterval: 0.5)
        self.setAddress(of: context, preferForMedia: false)
        _ = XCTWaiter().wait(for: [finished], timeout: 5.0)
        disposable.dispose()
        XCTAssertEqual(outcome.with { $0 }, "failed 500 TEMP_KEY_ROTATED", "a request that fails on server errors is not run again")
    }

    func testChainedCallsGoAgainInTheirOrderAfterARotation() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 67, on: session) else {
            return
        }
        let order = Atomic<[Int]>(value: [])
        var disposables: [Disposable] = []
        for index in 0 ..< 4 {
            let earlier: (WrappedRequestMetadata) -> Bool = { other in
                let parts = other.description.split(separator: " ")
                return parts.first == "chain" && (Int(parts.last ?? "") ?? Int.max) < index
            }
            disposables.append(session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in
                let _ = order.modify { $0 + [index] }
                return true
            }, dependsOn: index == 0 ? nil : earlier, label: "chain \(index)") { _ in }))
        }
        defer {
            for disposable in disposables {
                disposable.dispose()
            }
        }
        Thread.sleep(forTimeInterval: 0.5)
        var media = true
        for round in 1 ... 4 {
            media.toggle()
            self.setAddress(of: context, preferForMedia: media)
            XCTAssertTrue(self.eventually { order.with { $0.count } == 4 * round }, "round \(round): \(order.with { $0 })")
            let rotated = order.with { Array($0.suffix(4)) }
            XCTAssertEqual(rotated, [0, 1, 2, 3], "round \(round): each call goes again after the one it is chained to")
            Thread.sleep(forTimeInterval: 0.5)
        }
    }

    func testChainedCallsStayChainedToTheCallsSentAgainBeforeThem() {
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let context = self.pfsContext(permanentKey: true, preferForMedia: true)
        let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .worker(masterDatacenterId: datacenterId, isMedia: true, isCdn: false), usageCalculationInfo: nil, delegate: nil)
        session.setPaused(false)
        defer { session.stop() }
        guard self.completes(tag: 68, on: session) else {
            return
        }
        let rotations = Atomic<Int>(value: 0)
        let sameChain: (WrappedRequestMetadata) -> Bool = { other in
            return other.description.hasPrefix("chain ")
        }
        var disposables: [Disposable] = []
        for index in 0 ..< 4 {
            disposables.append(session.requestService.add(self.request(tag: tagNever, shouldContinueAfterError: { _ in
                let _ = rotations.modify { $0 + 1 }
                return true
            }, dependsOn: index == 0 ? nil : sameChain, label: "chain \(index)") { _ in }))
        }
        defer {
            for disposable in disposables {
                disposable.dispose()
            }
        }
        Thread.sleep(forTimeInterval: 0.5)
        var media = true
        for round in 1 ... 3 {
            let wrappers = self.server.invokeAfterWrappers()
            media.toggle()
            self.setAddress(of: context, preferForMedia: media)
            XCTAssertTrue(self.eventually { rotations.with { $0 } == 4 * round }, "round \(round)")
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertGreaterThanOrEqual(self.server.invokeAfterWrappers() - wrappers, 3, "round \(round): calls 1-3 went again chained to the call sent again before them")
        }
    }

    func testANetworkThatBlocksTcpIsStoredForTheNextRunAndForgottenWhenTcpWorks() throws {
        let network = RustNetworkIdentity.currentKey()
        if network.isEmpty {
            throw XCTSkip("no network to name")
        }
        let datacenterId = RustEngineEndToEndTests.datacenterId
        let remembered: () -> Bool = { UserDefaults.standard.data(forKey: RustNetworkIdentity.memoryKey)?.range(of: network) != nil }
        let context = self.pfsContext(permanentKey: true)
        let runs: [(blackhole: Bool, tag: UInt32, stored: Bool, message: String)] = [
            (false, 37, false, "TCP answering forgets whatever an earlier run left"),
            (true, 38, true, "the network was stored as one that blocks TCP"),
            (false, 39, false, "TCP answering there removed it")
        ]
        for run in runs {
            self.server.setTcpBlackhole(run.blackhole)
            let session = self.pfsEngine(context).makeSession(datacenterId: datacenterId, role: .main, usageCalculationInfo: nil, delegate: nil)
            session.setPaused(false)
            let completed = self.completes(tag: run.tag, on: session)
            session.stop()
            guard completed else {
                return
            }
            XCTAssertTrue(self.eventually { remembered() == run.stored }, run.message)
        }
    }
}
