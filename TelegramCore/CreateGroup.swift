import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func createGroup(account: Account, title: String, peerIds: [PeerId]) -> Signal<PeerId?, NoError> {
    return account.postbox.transaction { transaction -> Signal<PeerId?, NoError> in
        var inputUsers: [Api.InputUser] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return .single(nil)
            }
        }
        return account.network.request(Api.functions.messages.createChat(users: inputUsers, title: title))
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.Updates?, NoError>.single(nil)
        }
        |> mapToSignal { updates -> Signal<PeerId?, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
                if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                    return account.postbox.multiplePeersView([peerId])
                    |> filter { view in
                        return view.peers[peerId] != nil
                    }
                    |> take(1)
                    |> map { _ in
                        return peerId
                    }
                    |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
                }
                return .single(nil)
            } else {
                return .single(nil)
            }
        }
    }
    |> switchToLatest
}
