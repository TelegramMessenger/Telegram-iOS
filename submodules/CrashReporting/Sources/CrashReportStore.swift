import CryptoKit
import Foundation

public struct CrashReportInput {
    public let diagnosticJSON: Data
    public let metadata: CrashReportMetadata

    public init(diagnosticJSON: Data, metadata: CrashReportMetadata) {
        self.diagnosticJSON = diagnosticJSON
        self.metadata = metadata
    }
}

public final class CrashReportStore {
    public static let shared = CrashReportStore(directory: URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true).appendingPathComponent("Library/Application Support/CrashReports", isDirectory: true))
    public static let didChange = Notification.Name("CrashReportStoreDidChange")

    private struct State: Codable {
        var reports: [CrashReport] = []
        var seenIds: Set<String> = []
    }

    private let directory: URL
    private let queue = DispatchQueue(label: "org.telegram.crash-reports")
    private let limit: Int

    public init(directory: URL, limit: Int = 10) {
        self.directory = directory
        self.limit = max(1, limit)
    }

    private var stateURL: URL {
        return self.directory.appendingPathComponent("reports.json")
    }

    private func readState() throws -> State {
        do {
            return try JSONDecoder().decode(State.self, from: Data(contentsOf: self.stateURL))
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return State()
        }
    }

    private func writeState(_ state: State) throws {
        try FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true, attributes: nil)
        var directory = self.directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        try data.write(to: self.stateURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: self.stateURL, options: .atomic)
        #endif
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: CrashReportStore.didChange, object: self)
        }
    }

    public func reports() throws -> [CrashReport] {
        return try self.queue.sync {
            try self.readState().reports.sorted {
                if $0.receivedAt != $1.receivedAt {
                    return $0.receivedAt > $1.receivedAt
                }
                return $0.id < $1.id
            }
        }
    }

    public func importDiagnostics(_ diagnostics: [CrashReportInput], intervalStart: Date, intervalEnd: Date, receivedAt: Date = Date()) throws {
        guard !diagnostics.isEmpty else {
            return
        }
        try self.queue.sync {
            var state = try self.readState()
            var occurrences: [String: Int] = [:]
            var changed = false
            for diagnostic in diagnostics {
                let object = try JSONSerialization.jsonObject(with: diagnostic.diagnosticJSON)
                guard object is [String: Any] else {
                    throw CocoaError(.coderInvalidValue)
                }
                var identity = Data("\(intervalStart.timeIntervalSince1970)|\(intervalEnd.timeIntervalSince1970)|".utf8)
                identity.append(try JSONSerialization.data(withJSONObject: object, options: .sortedKeys))
                let hash = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
                let occurrence = occurrences[hash, default: 0]
                occurrences[hash] = occurrence + 1
                let id = "\(hash)-\(occurrence)"
                guard state.seenIds.insert(id).inserted else {
                    continue
                }
                changed = true
                state.reports.append(CrashReport(id: id, diagnosticJSON: diagnostic.diagnosticJSON, metadata: diagnostic.metadata, intervalStart: intervalStart, intervalEnd: intervalEnd, receivedAt: receivedAt, wasPresented: false))
            }
            if changed {
                state.reports.sort {
                    if $0.intervalEnd != $1.intervalEnd {
                        return $0.intervalEnd > $1.intervalEnd
                    }
                    if $0.receivedAt != $1.receivedAt {
                        return $0.receivedAt > $1.receivedAt
                    }
                    return $0.id < $1.id
                }
                state.reports = Array(state.reports.prefix(self.limit))
                try self.writeState(state)
            }
        }
    }

    public func markPresented(ids: Set<String>) throws {
        try self.queue.sync {
            var state = try self.readState()
            var changed = false
            for index in state.reports.indices where ids.contains(state.reports[index].id) && !state.reports[index].wasPresented {
                state.reports[index].wasPresented = true
                changed = true
            }
            if changed {
                try self.writeState(state)
            }
        }
    }

    public func simulateCrash(metadata: CrashReportMetadata, callStackSymbols: [String] = Thread.callStackSymbols, date: Date = Date(), crash: () -> Void) throws {
        precondition(Thread.isMainThread)
        let object: [String: Any] = [
            "isTestReport": true,
            "testReportId": UUID().uuidString,
            "testCallStackSymbols": callStackSymbols,
            "diagnosticMetaData": [
                "exceptionType": "EXC_CRASH (SIGABRT)",
                "signal": 6,
                "terminationReason": "Intentional crash after saving a synthetic report from Debug Settings"
            ]
        ]
        let input = CrashReportInput(diagnosticJSON: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), metadata: metadata)
        try self.importDiagnostics([input], intervalStart: date, intervalEnd: date, receivedAt: date)
        crash()
    }

    public func remove(id: String) throws {
        try self.queue.sync {
            var state = try self.readState()
            state.reports.removeAll(where: { $0.id == id })
            try self.writeState(state)
        }
    }
}
