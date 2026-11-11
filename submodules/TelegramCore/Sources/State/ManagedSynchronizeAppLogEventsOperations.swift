import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

private let appLogEventsBatchLimit = 50
private let appLogEventsBatchDelay: Double = 30.0
private let appLogEventsBatchMaxBytes = 256 * 1024

func readyAppLogEventsBatch(_ updates: Signal<[PeerMergedOperationLogEntry], NoError>, batchDelay: Double = appLogEventsBatchDelay, clock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) -> Signal<[PeerMergedOperationLogEntry], NoError> {
    return Signal { subscriber in
        let firstPendingTime = Atomic<TimeInterval?>(value: nil)
        let queue = Queue()
        return (updates
        |> mapToSignal { entries -> Signal<[PeerMergedOperationLogEntry], NoError> in
            guard !entries.isEmpty else {
                let _ = firstPendingTime.swap(nil)
                return .never()
            }
            let now = clock()
            let start = firstPendingTime.modify { $0 ?? now } ?? now
            let flush = entries.contains { entry in
                guard let operation = entry.contents as? SynchronizeAppLogEventsOperation else { return false }
                if case .sync = operation.content { return true }
                return false
            }
            let wait = entries.count >= appLogEventsBatchLimit || flush ? 0 : max(0, start + batchDelay - now)
            if wait == 0 { return .single(entries) }
            return Signal.single(entries) |> delay(wait, queue: queue)
        }
        |> take(1)).start(next: { subscriber.putNext($0) }, completed: { subscriber.putCompletion() })
    }
}

func managedSynchronizeAppLogEventsOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let tag = OperationLogTags.SynchronizeAppLogEvents
    let updates = postbox.mergedOperationLogView(tag: tag, limit: appLogEventsBatchLimit)
    |> map { $0.entries }
    let batch = readyAppLogEventsBatch(updates)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return postbox.mergedOperationLogView(tag: tag, limit: appLogEventsBatchLimit)
        |> take(1)
        |> mapToSignal { view -> Signal<Void, NoError> in
            return synchronizeAppLogEventsBatch(postbox: postbox, entries: view.entries, send: { events in
                return network.request(Api.functions.help.saveAppLog(events: events))
                |> `catch` { _ -> Signal<Api.Bool, NoError> in .complete() }
                |> mapToSignal { _ -> Signal<Void, NoError> in .complete() }
            })
        }
    }
    if AppLogEventCollection.allowsLegacyEvents {
        return batch |> restart
    }
    return purgeInvalidAppLogEvents(postbox: postbox) |> then(batch |> restart)
}

func synchronizeAppLogEventsBatch(postbox: Postbox, entries allEntries: [PeerMergedOperationLogEntry], clock: @escaping () -> Double = { Date().timeIntervalSince1970 }, requestTimeout: Double = AppLogEventLimits.requestTimeout, send: @escaping ([Api.InputAppEvent]) -> Signal<Void, NoError>) -> Signal<Void, NoError> {
    var events: [Api.InputAppEvent] = []
    var entries: [PeerMergedOperationLogEntry] = []
    var collectionIds: [String?] = []
    var validity: [(Double, Int)] = []
    var totalBytes = 0
    let now = clock()
    AppLogEventCollection.sync {
        for entry in allEntries {
            guard let operation = entry.contents as? SynchronizeAppLogEventsOperation,
                  case let .add(time, type, peerId, data) = operation.content,
                  AppLogEventCollection.allows(owner: postbox, identifier: operation.collectionId) else {
                entries.append(entry)
                continue
            }
            let bytes = appLogEventSize(operation) ?? 0
            if operation.collectionId != nil || !AppLogEventCollection.allowsLegacyEvents {
                guard AppLogEventLimits.accepts(time: time, now: now, bytes: bytes) else {
                    entries.append(entry)
                    continue
                }
            }
            if events.count >= appLogEventsBatchLimit || (!events.isEmpty && totalBytes + bytes > appLogEventsBatchMaxBytes) {
                break
            }
            entries.append(entry)
            if let data = apiJson(data) {
                totalBytes += bytes
                collectionIds.append(operation.collectionId)
                if operation.collectionId != nil || !AppLogEventCollection.allowsLegacyEvents {
                    validity.append((time, bytes))
                }
                events.append(.inputAppEvent(.init(time: time, type: type, peer: operation.collectionId == nil ? peerId?.toInt64() ?? 0 : 0, data: data)))
            }
        }
    }

    let request = Signal<Void, NoError> { subscriber in
        let now = clock()
        guard !events.isEmpty, validity.allSatisfy({ AppLogEventLimits.accepts(time: $0.0, now: now, bytes: $0.1) }) else {
            subscriber.putCompletion()
            return EmptyDisposable
        }
        let remaining = validity.map { $0.0 + AppLogEventLimits.lifetime - now }.min()
        let timeoutSeconds = remaining.map { min(requestTimeout, $0) }
        return AppLogEventCollection.request(owner: postbox, identifiers: collectionIds, timeoutSeconds: timeoutSeconds, produce: {
            send(events)
        }).start(next: { subscriber.putNext($0) }, completed: { subscriber.putCompletion() })
    }
    return request
    |> then(postbox.transaction { transaction -> Void in
        for entry in entries {
            let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: OperationLogTags.SynchronizeAppLogEvents, tagLocalIndex: entry.tagLocalIndex)
        }
    })
}
