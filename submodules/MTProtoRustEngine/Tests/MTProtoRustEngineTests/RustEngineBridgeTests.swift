import XCTest
import SwiftSignalKit
import TelegramCore
import MTProtoEngineFFI
import MTProtoRustEngineMapping
@testable import MTProtoRustEngine

final class RustEngineBridgeTests: XCTestCase {
    private static let logger: Logger = {
        let path = NSTemporaryDirectory() + "mtproto-rust-tests-\(getpid())"
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        let logger = Logger(rootPath: path, basePath: path)
        logger.logToFile = false
        logger.logToConsole = false
        return logger
    }()

    override func setUp() {
        super.setUp()
        Logger.setSharedLogger(RustEngineBridgeTests.logger)
    }

    func testArenaStrings() {
        let arena = RustEngineArena()
        let value = arena.string("héllo, мир")
        XCTAssertEqual(value.length, "héllo, мир".utf8.count)
        XCTAssertEqual(rustEngineString(value), "héllo, мир")
        let empty = arena.string(nil)
        XCTAssertNil(empty.data)
        XCTAssertEqual(empty.length, 0)
        XCTAssertEqual(rustEngineString(empty), "")
        XCTAssertEqual(rustEngineString(arena.string("")), "")
    }

    func testArenaBytesAndArrays() {
        let arena = RustEngineArena()
        let bytes = arena.bytes(Data([1, 2, 3, 250]))
        XCTAssertEqual(bytes.length, 4)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: bytes.data, count: bytes.length)), [1, 2, 3, 250])
        XCTAssertNil(arena.bytes(Data()).data)
        XCTAssertNil(arena.bytes(nil).data)

        let salts = [MTSaltEntry(salt: 1, valid_since: 10, valid_until: 20), MTSaltEntry(salt: 2, valid_since: 20, valid_until: 30)]
        guard let pointer = arena.array(salts) else {
            XCTFail()
            return
        }
        XCTAssertEqual(pointer[1].salt, 2)
        XCTAssertEqual(pointer[1].valid_until, 30)
        XCTAssertNil(arena.array([MTSaltEntry]()))
    }

    func testEventCopy() {
        let arena = RustEngineArena()
        let salts = [MTSaltEntry(salt: 7, valid_since: 100, valid_until: 200), MTSaltEntry(salt: 8, valid_since: 200, valid_until: 300)]
        var event = MTEvent()
        event.kind = MTEventKindRetryDecisionRequired
        event.request_id = 42
        event.code = 420
        event.text = arena.string("FLOOD_WAIT_3")
        event.text2 = arena.string("FLOOD_WAIT_3")
        event.integer1 = 3
        event.integer2 = 1
        event.value1 = 1.5
        event.value2 = 2.5
        event.salts = arena.array(salts)
        event.salt_count = salts.count
        let copied = withExtendedLifetime(arena) {
            return withUnsafePointer(to: &event) { RustEngineEvent($0) }
        }
        XCTAssertEqual(copied.kind, .retryDecisionRequired)
        XCTAssertEqual(copied.requestId, 42)
        XCTAssertEqual(copied.code, 420)
        XCTAssertEqual(copied.text, "FLOOD_WAIT_3")
        XCTAssertEqual(copied.text2, "FLOOD_WAIT_3")
        XCTAssertEqual(copied.integer1, 3)
        XCTAssertEqual(copied.integer2, 1)
        XCTAssertEqual(copied.value1, 1.5)
        XCTAssertEqual(copied.value2, 2.5)
        XCTAssertNil(copied.payload)
        XCTAssertEqual(copied.salts, [RustEngineSalt(salt: 7, validSince: 100, validUntil: 200), RustEngineSalt(salt: 8, validSince: 200, validUntil: 300)])
    }

    func testEventKindsMatchHeader() {
        let pairs: [(RustEngineEventKind, MTEventKind)] = [
            (.completed, MTEventKindCompleted), (.failed, MTEventKindFailed), (.acknowledged, MTEventKindAcknowledged),
            (.progress, MTEventKindProgress), (.floodWaitReported, MTEventKindFloodWaitReported),
            (.authorizationRequired, MTEventKindAuthorizationRequired), (.softAuthReset, MTEventKindSoftAuthReset),
            (.authTokenRequired, MTEventKindAuthTokenRequired), (.temporaryKeyRejected, MTEventKindTemporaryKeyRejected),
            (.initHashStored, MTEventKindInitHashStored), (.initHashCleared, MTEventKindInitHashCleared),
            (.verificationRequired, MTEventKindVerificationRequired), (.updatesReset, MTEventKindUpdatesReset),
            (.update, MTEventKindUpdate), (.timeDifferenceUpdated, MTEventKindTimeDifferenceUpdated),
            (.saltsUpdated, MTEventKindSaltsUpdated), (.pong, MTEventKindPong), (.connectionState, MTEventKindConnectionState),
            (.authKeyRequired, MTEventKindAuthKeyRequired), (.authKeyInvalid, MTEventKindAuthKeyInvalid),
            (.authKeyCreated, MTEventKindAuthKeyCreated), (.authKeyCreationFailed, MTEventKindAuthKeyCreationFailed),
            (.transportFlood, MTEventKindTransportFlood), (.networkUsage, MTEventKindNetworkUsage),
            (.addressResult, MTEventKindAddressResult), (.closed, MTEventKindClosed),
            (.retryDecisionRequired, MTEventKindRetryDecisionRequired),
            (.connectionDropped, MTEventKindConnectionDropped),
            (.temporaryKeyBound, MTEventKindTemporaryKeyBound), (.temporaryKeyBindFailed, MTEventKindTemporaryKeyBindFailed),
            (.permanentKeyInvalid, MTEventKindPermanentKeyInvalid), (.temporaryKeyInUse, MTEventKindTemporaryKeyInUse),
            (.temporaryKeyDropped, MTEventKindTemporaryKeyDropped), (.routeMemoryChanged, MTEventKindRouteMemoryChanged),
        ]
        for (kind, raw) in pairs {
            XCTAssertEqual(kind.rawValue, raw.rawValue)
        }
    }

    func testFlagsMatchHeader() {
        XCTAssertEqual(RustEngineRequestFlags.automaticFloodWait, UInt32(MTRequestFlagAutomaticFloodWait))
        XCTAssertEqual(RustEngineRequestFlags.reportFloodWait, UInt32(MTRequestFlagReportFloodWait))
        XCTAssertEqual(RustEngineRequestFlags.retryServerErrors, UInt32(MTRequestFlagRetryServerErrors))
        XCTAssertEqual(RustEngineRequestFlags.quickAck, UInt32(MTRequestFlagQuickAck))
        XCTAssertEqual(RustEngineRequestFlags.progress, UInt32(MTRequestFlagProgress))
        XCTAssertEqual(RustEngineRequestFlags.timeoutTimer, UInt32(MTRequestFlagTimeoutTimer))
        XCTAssertEqual(RustEngineRequestFlags.withoutUpdates, UInt32(MTRequestFlagWithoutUpdates))
        XCTAssertEqual(RustEngineRequestFlags.delegateRetryDecisions, UInt32(MTRequestFlagDelegateRetryDecisions))
        XCTAssertEqual(RustEngineSessionRole.main.rawValue, UInt8(MTSessionRoleMain))
        XCTAssertEqual(RustEngineSessionRole.worker.rawValue, UInt8(MTSessionRoleWorker))
        XCTAssertEqual(RustEngineSessionRole.workerRequiringAuthToken.rawValue, UInt8(MTSessionRoleWorkerRequiringAuthToken))
        XCTAssertEqual(RustEngineSessionRole.cdn.rawValue, UInt8(MTSessionRoleCdn))
        XCTAssertEqual(RustEngineConnectionFlags(rawValue: UInt32(MTConnectionStateConnected)).isConnected, true)
        XCTAssertEqual(RustEngineConnectionFlags(rawValue: UInt32(MTConnectionStateProxyHasConnectionIssues)).proxyHasConnectionIssues, true)
    }

    func testContextListenerSelectors() {
        let expected = [
            "contextDatacenterAuthInfoUpdated:datacenterId:authInfo:selector:",
            "contextDatacenterAuthTokenUpdated:datacenterId:authToken:",
            "contextDatacenterAuthInfoRequestFailed:datacenterId:selector:",
            "contextDatacenterAuthTokenTransferFailed:datacenterId:",
            "contextDatacenterTransportSchemesUpdated:datacenterId:shouldReset:",
            "contextApiEnvironmentUpdated:apiEnvironment:",
        ]
        for name in expected {
            XCTAssertTrue(RustContextListener.instancesRespond(to: NSSelectorFromString(name)), name)
        }
        XCTAssertFalse(RustContextListener.instancesRespond(to: NSSelectorFromString("isContextNetworkAccessAllowed:")))
        XCTAssertFalse(RustContextListener.instancesRespond(to: NSSelectorFromString("fetchContextDatacenterPublicKeys:datacenterId:")))
        XCTAssertFalse(RustContextListener.instancesRespond(to: NSSelectorFromString("contextLoggedOut:")))
    }

    func testRuntimeStartsEngine() {
        guard let runtime = RustEngineRuntime.shared else {
            XCTFail("engine did not start")
            return
        }
        XCTAssertNotNil(runtime.engine)
        XCTAssertEqual(mt_engine_abi_version(), 3)
        let first = runtime.nextRequestId()
        let second = runtime.nextRequestId()
        XCTAssertNotEqual(first, 0)
        XCTAssertGreaterThan(second, first)
    }

    func testRawSessionEventsAreRoutedAndFreed() {
        guard let runtime = RustEngineRuntime.shared else {
            XCTFail("engine did not start")
            return
        }
        let mailbox = RustEngineMailbox(queue: Queue())
        var setup = MTSessionSetup()
        setup.datacenter_id = 2
        setup.obfuscation_dc_id = 2
        setup.role = RustEngineSessionRole.worker.rawValue
        setup.paused = 1
        setup.request_timeout = 5.0
        let handle = withUnsafePointer(to: &setup) { runtime.createSession(setup: $0, mailbox: mailbox) }
        XCTAssertNotEqual(handle, 0)
        runtime.destroySession(handle: handle)
        runtime.destroySession(handle: handle)
    }
}
