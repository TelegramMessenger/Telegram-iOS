import Foundation
import Postbox
import SwiftSignalKit

/// One `help.saveAppLog` event of a telemetry report.
struct NetworkTelemetryEvent: Equatable {
    static let summaryType = "network_telemetry_summary"
    static let failuresType = "network_telemetry_failures"

    let type: String
    let data: JSON
}

private let networkTelemetryEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()

/// Converts through Foundation's JSON so the keys match the files on disk. `JSON(data:)` is not used:
/// it rejects fractional numbers and nulls.
func networkTelemetryJSON<T: Encodable>(_ value: T) -> JSON? {
    guard let data = try? networkTelemetryEncoder.encode(value), let object = try? JSONSerialization.jsonObject(with: data, options: []) else {
        return nil
    }
    return networkTelemetryJSON(object: object)
}

private func networkTelemetryJSON(object: Any) -> JSON? {
    if object is NSNull {
        return .null
    } else if let value = object as? NSNumber {
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return .bool(value.boolValue)
        } else {
            return .number(value.doubleValue)
        }
    } else if let value = object as? String {
        return .string(value)
    } else if let value = object as? [Any] {
        var result: [JSON] = []
        for item in value {
            guard let item = networkTelemetryJSON(object: item) else {
                return nil
            }
            result.append(item)
        }
        return .array(result)
    } else if let value = object as? [String: Any] {
        var result: [String: JSON] = [:]
        for (key, item) in value {
            guard let item = networkTelemetryJSON(object: item) else {
                return nil
            }
            result[key] = item
        }
        return .dictionary(result)
    } else {
        return nil
    }
}

/// The events of one report: a summary per period, then the failure records in chunks. Every event
/// carries the same random `report_id`, which ties them together and to nothing else.
func networkTelemetryEvents(report: NetworkTelemetryReport, reportId: Int64, failuresPerEvent: Int) -> [NetworkTelemetryEvent] {
    var result: [NetworkTelemetryEvent] = []
    let reportIdString = String(UInt64(bitPattern: reportId), radix: 16)
    let summaries = report.summaries.filter { summary in
        return summary.requests != 0 || summary.connection.transitions != 0 || summary.connection.sessionResets != 0 || summary.connection.drops != nil || summary.droppedFailures != 0 || !summary.methods.isEmpty || !summary.connection.seconds.isEmpty
    }
    for (index, summary) in summaries.enumerated() {
        if case var .dictionary(data)? = networkTelemetryJSON(summary) {
            data["report_id"] = .string(reportIdString)
            data["part"] = .number(Double(index))
            data["parts"] = .number(Double(summaries.count))
            data["failure_count"] = .number(Double(report.failures.count))
            result.append(NetworkTelemetryEvent(type: NetworkTelemetryEvent.summaryType, data: .dictionary(data)))
        }
    }
    let chunkSize = max(1, failuresPerEvent)
    var index = 0
    while index < report.failures.count {
        let chunk = Array(report.failures[index ..< min(report.failures.count, index + chunkSize)])
        if let records = networkTelemetryJSON(chunk) {
            result.append(NetworkTelemetryEvent(type: NetworkTelemetryEvent.failuresType, data: .dictionary([
                "schema": .number(Double(NetworkTelemetry.schema)),
                "report_id": .string(reportIdString),
                "offset": .number(Double(index)),
                "records": records
            ])))
        }
        index += chunkSize
    }
    return result
}

/// A report is due once the reporting interval has passed, or, at most hourly, once half of the
/// failure buffer is filled so that nothing is dropped, or periods ended because a label changed.
func networkTelemetryReportIsDue(now: Double, periodStart: Double, pendingFailures: Int, endedPeriods: Int, configuration: NetworkTelemetryConfiguration) -> Bool {
    if !configuration.isEnabled {
        return false
    }
    let elapsed = now - periodStart
    if elapsed < 0.0 {
        return true
    }
    if elapsed >= configuration.reportInterval {
        return true
    }
    if elapsed < 60.0 * 60.0 {
        return false
    }
    return pendingFailures >= NetworkTelemetry.maxFailureRecords / 2 || endedPeriods != 0
}

final class NetworkTelemetryReporter {
    static let failuresPerEvent = 10

    private let telemetry: NetworkTelemetry
    private let wallClock: () -> Double
    private let enqueue: ([NetworkTelemetryEvent]) -> Signal<Never, NoError>

    /// `enqueue` must queue the events for durable storage as soon as it is started, and cannot be
    /// cancelled afterwards (a Postbox transaction): the report is committed right after it starts.
    init(telemetry: NetworkTelemetry, wallClock: @escaping () -> Double = { Date().timeIntervalSince1970 }, enqueue: @escaping ([NetworkTelemetryEvent]) -> Signal<Never, NoError>) {
        self.telemetry = telemetry
        self.wallClock = wallClock
        self.enqueue = enqueue
    }

    /// Sends a report when one is due. Completes after the report is committed, or right away.
    func reportIfDue(configuration: NetworkTelemetryConfiguration) -> Signal<Never, NoError> {
        let telemetry = self.telemetry
        let enqueue = self.enqueue
        let wallClock = self.wallClock
        return Signal<Never, NoError> { subscriber in
            telemetry.setVariant(configuration.variant)
            if !networkTelemetryReportIsDue(now: wallClock(), periodStart: telemetry.periodStart, pendingFailures: telemetry.pendingFailureCount, endedPeriods: telemetry.endedPeriodCount, configuration: configuration) {
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let report = telemetry.takeReport(maxFailures: NetworkTelemetry.maxFailureRecords)
            let events = networkTelemetryEvents(report: report, reportId: Int64.random(in: Int64.min ... Int64.max), failuresPerEvent: NetworkTelemetryReporter.failuresPerEvent)
            if events.isEmpty {
                telemetry.commit(report: report)
                subscriber.putCompletion()
                return EmptyDisposable
            }
            let disposable = enqueue(events).start(completed: {
                subscriber.putCompletion()
            })
            telemetry.commit(report: report)
            return disposable
        }
    }
}

func _internal_enqueueNetworkTelemetryEvents(postbox: Postbox, events: [NetworkTelemetryEvent]) -> Signal<Never, NoError> {
    let time = Date().timeIntervalSince1970
    return postbox.transaction { transaction -> Void in
        for event in events {
            _internal_addAppLogEvent(transaction: transaction, time: time, type: event.type, data: event.data)
        }
    }
    |> ignoreValues
}

/// Reports the account's network telemetry through `help.saveAppLog` while `network_telemetry_enabled`
/// is set. Checks a minute after start, which also sends what earlier launches left, then every 15 minutes.
func managedNetworkTelemetryReports(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    guard let telemetry = network.telemetry else {
        return .complete()
    }
    let reporter = NetworkTelemetryReporter(telemetry: telemetry, enqueue: { events in
        return _internal_enqueueNetworkTelemetryEvents(postbox: postbox, events: events)
    })
    return postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
    |> map { view -> NetworkTelemetryConfiguration in
        let appConfiguration = view.values[PreferencesKeys.appConfiguration]?.get(AppConfiguration.self) ?? .defaultValue
        return NetworkTelemetryConfiguration.with(appConfiguration: appConfiguration)
    }
    |> distinctUntilChanged
    |> mapToSignal { configuration -> Signal<Never, NoError> in
        telemetry.setVariant(configuration.variant)
        if !configuration.isEnabled {
            return .complete()
        }
        let queue = Queue.concurrentDefaultQueue()
        let check = reporter.reportIfDue(configuration: configuration)
        |> then(Signal<Never, NoError>.complete() |> delay(15.0 * 60.0, queue: queue))
        return Signal<Never, NoError>.complete()
        |> delay(60.0, queue: queue)
        |> then(check |> restart)
    }
}
