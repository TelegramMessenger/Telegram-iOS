import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

let supportFolderChatsBatchSize = 100

func supportFolderNamedPeerIds(filters: [ChatListFilter]) -> [PeerId] {
    var result: [PeerId] = []
    var seen = Set<PeerId>()
    for filter in filters {
        guard case let .filter(_, _, _, data) = filter else {
            continue
        }
        for peerId in data.includePeers.pinnedPeers + data.includePeers.peers {
            if !isLocalOnlyChatListFilterPeer(peerId) && seen.insert(peerId).inserted {
                result.append(peerId)
            }
        }
    }
    return result
}

func supportFolderChatsToFetch(namedPeerIds: [PeerId], attempted: Set<PeerId>, hasChatListRow: (PeerId) -> Bool) -> [PeerId] {
    return namedPeerIds.filter { peerId in
        return !attempted.contains(peerId) && !hasChatListRow(peerId)
    }
}

func supportFolderChatBatches<T>(_ items: [T], size: Int) -> [[T]] {
    guard size > 0 else {
        return []
    }
    return stride(from: 0, to: items.count, by: size).map { start in
        return Array(items[start ..< min(start + size, items.count)])
    }
}

// TDesktop's loadNextExceptions: a folder's named chats get their dialogs whatever the loaded range.
func managedSupportFolderChats(postbox: Postbox, network: Network, accountPeerId: PeerId) -> Signal<Never, NoError> {
    let attempted = Atomic<Set<PeerId>>(value: Set())

    return postbox.preferencesView(keys: [PreferencesKeys.chatListFilters])
    |> map { view -> [PeerId] in
        let state = view.values[PreferencesKeys.chatListFilters]?.get(ChatListFiltersState.self) ?? ChatListFiltersState.default
        return supportFolderNamedPeerIds(filters: state.filters)
    }
    |> distinctUntilChanged
    |> mapToSignal { namedPeerIds -> Signal<Never, NoError> in
        return postbox.transaction { transaction -> [(PeerId, Api.InputPeer)] in
            let peerIds = supportFolderChatsToFetch(namedPeerIds: namedPeerIds, attempted: attempted.with { $0 }, hasChatListRow: { peerId in
                return transaction.getPeerChatListIndex(peerId) != nil
            })
            return peerIds.compactMap { peerId -> (PeerId, Api.InputPeer)? in
                guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                    return nil
                }
                return (peerId, inputPeer)
            }
        }
        |> mapToSignal { peers -> Signal<Never, NoError> in
            if peers.isEmpty {
                return .complete()
            }
            Logger.shared.log("SupportFolderChats", "fetching \(peers.count) folder chats")
            var signal: Signal<Never, NoError> = .complete()
            for batch in supportFolderChatBatches(peers, size: supportFolderChatsBatchSize) {
                signal = signal
                |> then(
                    loadAndStorePeerChatInfos(accountPeerId: accountPeerId, postbox: postbox, network: network, peers: batch.map { $0.1 })
                )
                |> then(
                    Signal<Never, NoError> { subscriber in
                        let _ = attempted.modify { current in
                            return current.union(batch.map { $0.0 })
                        }
                        subscriber.putCompletion()
                        return EmptyDisposable
                    }
                )
            }
            return signal
        }
    }
}
