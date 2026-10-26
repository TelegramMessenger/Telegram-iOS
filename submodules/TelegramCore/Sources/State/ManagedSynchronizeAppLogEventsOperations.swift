import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

private let appLogEventsBatchLimit = 50
private let appLogEventsBatchDelay: Double = 30.0
private let appLogEventsBatchMaxBytes = 256 * 1024

func managedSynchronizeAppLogEventsOperations(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let tag: PeerOperationLogTag = OperationLogTags.SynchronizeAppLogEvents
    let queue = Queue()

    let pending: Signal<[PeerMergedOperationLogEntry], NoError> = postbox.mergedOperationLogView(tag: tag, limit: appLogEventsBatchLimit)
    |> map { view -> [PeerMergedOperationLogEntry] in
        return view.entries
    }
    |> filter { entries in
        return !entries.isEmpty
    }
    |> take(1)

    let batch: Signal<Void, NoError> = pending
    |> mapToSignal { entries -> Signal<Void, NoError> in
        let wait: Signal<Void, NoError>
        if entries.count >= appLogEventsBatchLimit {
            wait = .complete()
        } else {
            wait = Signal<Void, NoError>.complete() |> delay(appLogEventsBatchDelay, queue: queue)
        }
        return wait
        |> then(
            postbox.mergedOperationLogView(tag: tag, limit: appLogEventsBatchLimit)
            |> take(1)
            |> mapToSignal { view -> Signal<Void, NoError> in
                return sendAppLogEventsBatch(postbox: postbox, network: network, tag: tag, entries: view.entries)
            }
        )
    }

    return batch |> restart
}

private func sendAppLogEventsBatch(postbox: Postbox, network: Network, tag: PeerOperationLogTag, entries allEntries: [PeerMergedOperationLogEntry]) -> Signal<Void, NoError> {
    var events: [Api.InputAppEvent] = []
    var entries: [PeerMergedOperationLogEntry] = []
    var totalBytes = 0
    for entry in allEntries {
        guard let operation = entry.contents as? SynchronizeAppLogEventsOperation else {
            entries.append(entry)
            continue
        }
        if case let .add(time, type, peerId, data) = operation.content {
            let bytes = (data.string?.utf8.count ?? 0) + type.utf8.count
            if !events.isEmpty && totalBytes + bytes > appLogEventsBatchMaxBytes {
                break
            }
            entries.append(entry)
            if let data = apiJson(data) {
                totalBytes += bytes
                events.append(.inputAppEvent(.init(time: time, type: type, peer: peerId?.toInt64() ?? 0, data: data)))
            }
        } else {
            entries.append(entry)
        }
    }

    let request: Signal<Void, NoError>
    if events.isEmpty {
        request = .complete()
    } else {
        request = network.request(Api.functions.help.saveAppLog(events: events))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .complete()
        }
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }

    return request
    |> then(postbox.transaction { transaction -> Void in
        for entry in entries {
            let _ = transaction.operationLogRemoveEntry(peerId: entry.peerId, tag: tag, tagLocalIndex: entry.tagLocalIndex)
        }
    })
}
