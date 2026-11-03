import XCTest
import SwiftSignalKit
import MtProtoKit
@testable import TelegramCore

private final class ActivationLog {
    var entries: [String] = []
}

private final class ActivationSession: NetworkEngineSession {
    let datacenterId: Int
    let requestService: NetworkEngineRequestService = ActivationRequestService()

    init(datacenterId: Int) {
        self.datacenterId = datacenterId
    }

    func setPaused(_ paused: Bool) {
    }

    func setOnline(_ online: Bool) {
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
    }

    func stop() {
    }

    func movePendingRequests(to service: NetworkEngineRequestService, deadline: Double, completion: @escaping () -> Void) {
        completion()
    }
}

private final class ActivationRequestService: NetworkEngineRequestService {
    func add(_ request: NetworkEngineRequest) -> Disposable {
        return EmptyDisposable
    }
}

private final class ActivationEngine: NetworkEngine {
    let kind: NetworkEngineKind
    private let log: ActivationLog

    init(kind: NetworkEngineKind, log: ActivationLog) {
        self.kind = kind
        self.log = log
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        return ActivationSession(datacenterId: datacenterId)
    }

    func activate() {
        self.log.entries.append("activate \(self.kind.rawValue)")
    }

    func deactivate() {
        self.log.entries.append("deactivate \(self.kind.rawValue)")
    }
}

/// An engine that takes over MTContext's key and transfer actions (`activate`) gives them back before the
/// next engine takes them, on every live switch, so the context never runs two engines' actions.
final class SwitchingNetworkEngineActivationTests: XCTestCase {
    func testASwitchHandsTheContextsActionsOverInOrder() {
        let log = ActivationLog()
        let rust = ActivationEngine(kind: .rust, log: log)
        let mtProtoKit = ActivationEngine(kind: .mtProtoKit, log: log)
        let switching = SwitchingNetworkEngine(engine: rust)
        let session = switching.makeSession(datacenterId: 2, role: .main, usageCalculationInfo: nil, delegate: nil)
        defer { session.stop() }
        XCTAssertTrue(log.entries.isEmpty, "the network activates the engine it starts on itself")

        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 0.0, makeEngine: { mtProtoKit }))
        XCTAssertEqual(log.entries, ["deactivate rust", "activate mtProtoKit"])

        XCTAssertTrue(switching.switchEngine(to: .mtProtoKit, drainTimeout: 0.0, makeEngine: { mtProtoKit }))
        XCTAssertEqual(log.entries.count, 2, "no switch, no hand-over")

        XCTAssertFalse(switching.switchEngine(to: .rust, drainTimeout: 0.0, makeEngine: { nil }))
        XCTAssertEqual(log.entries.count, 2, "a declined switch keeps the actions where they are")

        let again = ActivationEngine(kind: .rust, log: log)
        XCTAssertTrue(switching.switchEngine(to: .rust, drainTimeout: 0.0, makeEngine: { again }))
        XCTAssertEqual(Array(log.entries.suffix(2)), ["deactivate mtProtoKit", "activate rust"])
    }
}
