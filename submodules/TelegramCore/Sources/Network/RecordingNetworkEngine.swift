import Foundation
import SwiftSignalKit
import MtProtoKit

/// Wraps any `NetworkEngine` so that `NetworkTelemetry` sees every request, connection status and
/// session reset of every session it creates. Measures both engines with the same code, which is
/// what makes an A/B comparison between them meaningful.
final class RecordingNetworkEngine: NetworkEngine {
    let inner: NetworkEngine
    let telemetry: NetworkTelemetry

    init(engine: NetworkEngine, telemetry: NetworkTelemetry) {
        self.inner = engine
        self.telemetry = telemetry
    }

    var kind: NetworkEngineKind {
        return self.inner.kind
    }

    func makeSession(datacenterId: Int, role: NetworkEngineSessionRole, usageCalculationInfo: MTNetworkUsageCalculationInfo?, delegate: NetworkEngineSessionDelegate?) -> NetworkEngineSession {
        let recordingDelegate = delegate.map { RecordingSessionDelegate(delegate: $0, telemetry: self.telemetry) }
        let session = self.inner.makeSession(datacenterId: datacenterId, role: role, usageCalculationInfo: usageCalculationInfo, delegate: recordingDelegate)
        return RecordingNetworkEngineSession(session: session, engine: self.inner, role: NetworkTelemetryRole(role), telemetry: self.telemetry, delegate: recordingDelegate)
    }
}

private final class RecordingSessionDelegate: NetworkEngineSessionDelegate {
    private weak var delegate: NetworkEngineSessionDelegate?
    private let telemetry: NetworkTelemetry

    init(delegate: NetworkEngineSessionDelegate, telemetry: NetworkTelemetry) {
        self.delegate = delegate
        self.telemetry = telemetry
    }

    func networkSessionAuthorizationRequired() {
        self.delegate?.networkSessionAuthorizationRequired()
    }

    func networkSessionSoftAuthReset() {
        self.delegate?.networkSessionSoftAuthReset()
    }

    func networkSessionConnectionStateChanged(_ state: NetworkEngineConnectionState) {
        self.telemetry.connectionStateChanged(state)
        self.delegate?.networkSessionConnectionStateChanged(state)
    }
}

private final class RecordingUpdateSink: NetworkEngineUpdateSink {
    private let sink: NetworkEngineUpdateSink
    private let telemetry: NetworkTelemetry

    init(sink: NetworkEngineUpdateSink, telemetry: NetworkTelemetry) {
        self.sink = sink
        self.telemetry = telemetry
    }

    func networkSessionDidReset() {
        self.telemetry.sessionReset()
        self.sink.networkSessionDidReset()
    }

    func networkSessionDidReceive(message: Any) {
        self.sink.networkSessionDidReceive(message: message)
    }
}

private final class RecordingNetworkEngineSession: NetworkEngineSession {
    private let session: NetworkEngineSession
    private let service: RecordingRequestService
    private let role: NetworkTelemetryRole
    private let telemetry: NetworkTelemetry
    private let delegate: RecordingSessionDelegate?

    init(session: NetworkEngineSession, engine: NetworkEngine, role: NetworkTelemetryRole, telemetry: NetworkTelemetry, delegate: RecordingSessionDelegate?) {
        self.session = session
        self.role = role
        self.telemetry = telemetry
        session.observeConnectionDrops { [weak telemetry] drop in
            telemetry?.connectionDropped(role: role, drop)
        }
        self.delegate = delegate
        self.service = RecordingRequestService(service: session.requestService, engine: engine, role: role, datacenterId: session.datacenterId, telemetry: telemetry)
    }

    var datacenterId: Int {
        return self.session.datacenterId
    }

    var requestService: NetworkEngineRequestService {
        return self.service
    }

    func setPaused(_ paused: Bool) {
        if self.role == .main {
            self.telemetry.setSuspended(paused)
        }
        self.session.setPaused(paused)
    }

    func setOnline(_ online: Bool) {
        if self.role == .main {
            self.telemetry.setUserOnline(online)
        }
        self.session.setOnline(online)
    }

    func addUpdateSink(_ sink: NetworkEngineUpdateSink) {
        if self.role == .main {
            self.session.addUpdateSink(RecordingUpdateSink(sink: sink, telemetry: self.telemetry))
        } else {
            self.session.addUpdateSink(sink)
        }
    }

    func stop() {
        self.session.stop()
    }

    func movePendingRequests(to service: NetworkEngineRequestService, completion: @escaping () -> Void) {
        self.session.movePendingRequests(to: service, completion: completion)
    }

    func observeConnectionDrops(_ observer: @escaping (NetworkEngineConnectionDrop) -> Void) {
        self.session.observeConnectionDrops(observer)
    }
}

/// Keeps the inner service and never the session or the engine, so, as `NetworkEngineRequestService`
/// requires, it keeps neither a released session's connection nor its `MTContext` alive.
private final class RecordingRequestService: NetworkEngineRequestService {
    private let service: NetworkEngineRequestService
    private let fixedKind: NetworkEngineKind
    /// Set when the engine can switch, so that a request is attributed to the engine it starts on.
    private weak var switchingEngine: SwitchingNetworkEngine?
    private let role: NetworkTelemetryRole
    private let datacenterId: Int
    private let telemetry: NetworkTelemetry

    init(service: NetworkEngineRequestService, engine: NetworkEngine, role: NetworkTelemetryRole, datacenterId: Int, telemetry: NetworkTelemetry) {
        self.service = service
        self.fixedKind = engine.kind
        self.switchingEngine = engine as? SwitchingNetworkEngine
        self.role = role
        self.datacenterId = datacenterId
        self.telemetry = telemetry
    }

    func add(_ request: NetworkEngineRequest) -> Disposable {
        if request.telemetry != nil {
            return self.service.add(request)
        }
        self.telemetry.begin(request: request, engine: self.switchingEngine?.kind ?? self.fixedKind, role: self.role, datacenterId: self.datacenterId)
        let disposable = self.service.add(request)
        if (disposable as AnyObject) === (EmptyDisposable as AnyObject), let info = request.telemetryInfo {
            self.telemetry.dropped(request: request, info: info)
        }
        return disposable
    }
}
