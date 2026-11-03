import Foundation

public struct CrashReportMetadata: Codable, Equatable {
    public let applicationVersion: String
    public let buildVersion: String
    public let osVersion: String
    public let deviceType: String
    public let architecture: String

    public init(applicationVersion: String, buildVersion: String, osVersion: String, deviceType: String, architecture: String) {
        self.applicationVersion = applicationVersion
        self.buildVersion = buildVersion
        self.osVersion = osVersion
        self.deviceType = deviceType
        self.architecture = architecture
    }
}

public struct CrashReport: Codable, Equatable {
    public let id: String
    public let diagnosticJSON: Data
    public let metadata: CrashReportMetadata
    public let intervalStart: Date
    public let intervalEnd: Date
    public let receivedAt: Date
    public var wasPresented: Bool

    public var isTestReport: Bool {
        guard let object = try? JSONSerialization.jsonObject(with: self.diagnosticJSON) as? [String: Any] else {
            return false
        }
        return object["isTestReport"] as? Bool == true
    }

    public var formattedJSON: String {
        guard let object = try? JSONSerialization.jsonObject(with: self.diagnosticJSON),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else {
            return "The diagnostic could not be decoded."
        }
        return String(decoding: data, as: UTF8.self)
    }

    public var text: String {
        let formatter = ISO8601DateFormatter()
        var lines = [
            self.isTestReport ? "TEST Crash Report (synthetic)" : "MetricKit Crash Report",
            "Report ID: \(self.id)",
            "App: \(self.metadata.applicationVersion) (\(self.metadata.buildVersion))",
            "OS: \(self.metadata.osVersion)",
            "Device: \(self.metadata.deviceType)",
            "Architecture: \(self.metadata.architecture)",
            "Received: \(formatter.string(from: self.receivedAt))",
            "Diagnostic interval: \(formatter.string(from: self.intervalStart)) — \(formatter.string(from: self.intervalEnd))",
            "The diagnostic interval is not the exact time of the crash.",
            ""
        ]
        guard let object = try? JSONSerialization.jsonObject(with: self.diagnosticJSON) as? [String: Any] else {
            return (lines + ["The diagnostic could not be decoded."]).joined(separator: "\n")
        }
        if self.isTestReport {
            lines.append("Generated locally by Debug Settings before an intentional crash, not delivered by MetricKit.")
            if let symbols = object["testCallStackSymbols"] as? [String] {
                lines.append("\nStack captured before the intentional crash:")
                lines.append(contentsOf: symbols)
                lines.append("")
            }
        }
        let details = object["diagnosticMetaData"] as? [String: Any] ?? object
        for (key, title) in [("exceptionType", "Exception"), ("exceptionCode", "Exception code"), ("signal", "Signal"), ("terminationReason", "Termination reason"), ("exceptionReason", "Objective-C exception"), ("virtualMemoryRegionInfo", "Memory region")] {
            if let value = details[key] {
                if let value = value as? [String: Any], let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
                    lines.append("\(title): \(String(decoding: data, as: UTF8.self))")
                } else {
                    lines.append("\(title): \(value)")
                }
            }
        }
        if let tree = object["callStackTree"] as? [String: Any], let stacks = tree["callStacks"] as? [[String: Any]] {
            for (index, stack) in stacks.enumerated() {
                lines.append("")
                lines.append("Stack \(index)\((stack["threadAttributed"] as? Bool == true) ? " (crashed)" : "")")
                var pending = (stack["callStackRootFrames"] as? [[String: Any]] ?? []).reversed().map { ($0, 0) }
                while let (frame, depth) = pending.popLast() {
                    let name = frame["binaryName"] as? String ?? "Unknown binary"
                    let uuid = frame["binaryUUID"] as? String ?? "Unknown UUID"
                    let address = (frame["address"] as? NSNumber).map { String(format: "0x%llx", $0.uint64Value) } ?? "?"
                    let offset = (frame["offsetIntoBinaryTextSegment"] as? NSNumber)?.stringValue ?? "?"
                    lines.append("\(String(repeating: "  ", count: min(depth, 30)))\(name) \(address) +\(offset) [\(uuid)]")
                    for child in (frame["subFrames"] as? [[String: Any]] ?? []).reversed() {
                        pending.append((child, depth + 1))
                    }
                }
            }
        }
        lines.append("\nFunction names and source lines require the matching build's dSYM.")
        return lines.joined(separator: "\n")
    }

    public func exportMetadata() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(ExportMetadata(reportID: self.id, isTestReport: self.isTestReport, metadata: self.metadata, intervalStart: self.intervalStart, intervalEnd: self.intervalEnd, receivedAt: self.receivedAt))
    }
}

private struct ExportMetadata: Encodable {
    let reportID: String
    let isTestReport: Bool
    let metadata: CrashReportMetadata
    let intervalStart: Date
    let intervalEnd: Date
    let receivedAt: Date
}

public func crashReportAlertsEnabled(override: Bool?, isInternalBuild: Bool) -> Bool {
    return override ?? isInternalBuild
}
