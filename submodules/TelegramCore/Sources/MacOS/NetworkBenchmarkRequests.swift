import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum NetworkBenchmarkDialogList {
    case main
    case archive
    case pinned
}

public struct NetworkBenchmarkHistoryMessage {
    public let id: Int32
    public let documentSize: Int64?
}

public func networkBenchmarkCanRequestHistory(peer: Peer) -> Bool {
    return apiInputPeer(peer) != nil
}

/// Requests the first 100 dialogs of a list straight from the server and returns how many came back.
public func networkBenchmarkRequestDialogs(network: Network, list: NetworkBenchmarkDialogList) -> Signal<Int, MTRpcError> {
    switch list {
    case .main, .archive:
        let isArchive = list == .archive
        return network.request(Api.functions.messages.getDialogs(flags: isArchive ? (1 << 1) : 0, folderId: isArchive ? 1 : nil, offsetDate: 0, offsetId: 0, offsetPeer: .inputPeerEmpty, limit: 100, hash: 0))
        |> map { result -> Int in
            switch result {
            case let .dialogs(data):
                return data.dialogs.count
            case let .dialogsSlice(data):
                return data.dialogs.count
            case .dialogsNotModified:
                return 0
            }
        }
    case .pinned:
        return network.request(Api.functions.messages.getPinnedDialogs(folderId: 0))
        |> map { result -> Int in
            switch result {
            case let .peerDialogs(data):
                return data.dialogs.count
            }
        }
    }
}

/// Requests a page of a chat's history straight from the server, without storing it. Fails with
/// `PEER_ID_INVALID` when the peer cannot be addressed (see `networkBenchmarkCanRequestHistory`).
public func networkBenchmarkRequestHistory(network: Network, peer: Peer, offsetId: Int32, limit: Int32, automaticFloodWait: Bool) -> Signal<[NetworkBenchmarkHistoryMessage], MTRpcError> {
    guard let inputPeer = apiInputPeer(peer) else {
        return .fail(MTRpcError(errorCode: 400, errorDescription: "PEER_ID_INVALID"))
    }
    return network.request(Api.functions.messages.getHistory(peer: inputPeer, offsetId: offsetId, offsetDate: 0, addOffset: 0, limit: limit, maxId: 0, minId: 0, hash: 0), automaticFloodWait: automaticFloodWait)
    |> map { result -> [NetworkBenchmarkHistoryMessage] in
        let messages: [Api.Message]
        switch result {
        case let .messages(data):
            messages = data.messages
        case let .messagesSlice(data):
            messages = data.messages
        case let .channelMessages(data):
            messages = data.messages
        case .messagesNotModified:
            messages = []
        }
        return messages.map { message -> NetworkBenchmarkHistoryMessage in
            switch message {
            case let .message(data):
                var documentSize: Int64?
                if case let .messageMediaDocument(mediaData)? = data.media, case let .document(document)? = mediaData.document {
                    documentSize = document.size
                }
                return NetworkBenchmarkHistoryMessage(id: data.id, documentSize: documentSize)
            case let .messageService(data):
                return NetworkBenchmarkHistoryMessage(id: data.id, documentSize: nil)
            case let .messageEmpty(data):
                return NetworkBenchmarkHistoryMessage(id: data.id, documentSize: nil)
            }
        }
    }
}
