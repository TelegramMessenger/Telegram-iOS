import Postbox
import SwiftSignalKit
import TelegramApi

public final class MessageReadStats {
    public let reactionCount: Int
    public let peers: [EnginePeer]

    public init(reactionCount: Int, peers: [EnginePeer]) {
        self.reactionCount = reactionCount
        self.peers = peers
    }
}

func _internal_messageReadStats(account: Account, id: MessageId) -> Signal<MessageReadStats?, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(id.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<MessageReadStats?, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(nil)
        }
        if id.namespace != Namespaces.Message.Cloud {
            return .single(nil)
        }

        let readPeers: Signal<[Int64]?, NoError> = account.network.request(Api.functions.messages.getMessageReadParticipants(peer: inputPeer, msgId: id.id))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<[Int64]?, NoError> in
            return .single(nil)
        }
        
        let reactionCount: Signal<Int, NoError> = account.network.request(Api.functions.messages.getMessageReactionsList(flags: 0, peer: inputPeer, id: id.id, reaction: nil, offset: nil, limit: 1))
        |> map { result -> Int in
            switch result {
            case let .messageReactionsList(_, count, _, _, _, _):
                return Int(count)
            }
        }
        |> `catch` { _ -> Signal<Int, NoError> in
            return .single(0)
        }
        
        return combineLatest(readPeers, reactionCount)
        |> mapToSignal { result, reactionCount -> Signal<MessageReadStats?, NoError> in
            return account.postbox.transaction { transaction -> (peerIds: [PeerId], missingPeerIds: [PeerId]) in
                var peerIds: [PeerId] = []
                var missingPeerIds: [PeerId] = []

                let authorId = transaction.getMessage(id)?.author?.id

                if let result = result {
                    for id in result {
                        let peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
                        if peerId == account.peerId {
                            continue
                        }
                        if peerId == authorId {
                            continue
                        }
                        peerIds.append(peerId)
                        if transaction.getPeer(peerId) == nil {
                            missingPeerIds.append(peerId)
                        }
                    }
                }

                return (peerIds: peerIds, missingPeerIds: missingPeerIds)
            }
            |> mapToSignal { peerIds, missingPeerIds -> Signal<MessageReadStats?, NoError> in
                if missingPeerIds.isEmpty || id.peerId.namespace != Namespaces.Peer.CloudChannel {
                    return account.postbox.transaction { transaction -> MessageReadStats? in
                        return MessageReadStats(reactionCount: reactionCount, peers: peerIds.compactMap { peerId -> EnginePeer? in
                            return transaction.getPeer(peerId).flatMap(EnginePeer.init)
                        })
                    }
                } else {
                    return _internal_channelMembers(postbox: account.postbox, network: account.network, accountPeerId: account.peerId, peerId: id.peerId, category: .recent(.all), offset: 0, limit: 50, hash: 0)
                    |> mapToSignal { _ -> Signal<MessageReadStats?, NoError> in
                        return account.postbox.transaction { transaction -> MessageReadStats? in
                            return MessageReadStats(reactionCount: reactionCount, peers: peerIds.compactMap { peerId -> EnginePeer? in
                                return transaction.getPeer(peerId).flatMap(EnginePeer.init)
                            })
                        }
                    }
                }
            }
        }
    }
}
