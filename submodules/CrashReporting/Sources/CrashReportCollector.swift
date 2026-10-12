import Foundation

#if os(iOS)
import MetricKit

public final class CrashReportCollector: NSObject, MXMetricManagerSubscriber {
    public static let shared = CrashReportCollector()
    private var started = false

    public func start() {
        precondition(Thread.isMainThread)
        guard !self.started else {
            return
        }
        self.started = true
        let manager = MXMetricManager.shared
        manager.add(self)
        let pastPayloads = manager.pastDiagnosticPayloads
        DispatchQueue.global(qos: .utility).async {
            self.didReceive(pastPayloads)
        }
    }

    public func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let inputs = (payload.crashDiagnostics ?? []).map { diagnostic in
                return CrashReportInput(diagnosticJSON: diagnostic.jsonRepresentation(), metadata: CrashReportMetadata(
                    applicationVersion: diagnostic.applicationVersion,
                    buildVersion: diagnostic.metaData.applicationBuildVersion,
                    osVersion: diagnostic.metaData.osVersion,
                    deviceType: diagnostic.metaData.deviceType,
                    architecture: diagnostic.metaData.platformArchitecture
                ))
            }
            do {
                try CrashReportStore.shared.importDiagnostics(inputs, intervalStart: payload.timeStampBegin, intervalEnd: payload.timeStampEnd)
            } catch {
                NSLog("MetricKit: could not persist crash diagnostics (%@)", String(describing: type(of: error)))
            }
        }
    }
}
#endif
