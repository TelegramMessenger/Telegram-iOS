import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_requestStartBot(account: Account, botPeerId: PeerId, payload: String?) -> Signal<Void, NoError> {
    if let payload = payload, !payload.isEmpty {
        return account.postbox.loadedPeerWithId(botPeerId)
            |> mapToSignal { botPeer -> Signal<Void, NoError> in
                if let inputUser = apiInputUser(botPeer) {
                    let r = account.network.request(Api.functions.messages.startBot(bot: inputUser, peer: .inputPeerEmpty, randomId: Int64.random(in: Int64.min ... Int64.max), startParam: payload))
                        |> mapToSignal { result -> Signal<Void, MTRpcError> in
                            account.stateManager.addUpdates(result)
                            return .complete()
                        }
                        |> `catch` { _ -> Signal<Void, MTRpcError> in
                            return .complete()
                        }
                    return r
                        |> retryRequest
                } else {
                    return .complete()
                }
            }
    } else {
        return enqueueMessages(account: account, peerId: botPeerId, messages: [.message(text: "/start", attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)]) |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
}

public enum RequestStartBotInGroupError {
    case generic
}

public enum StartBotInGroupResult {
    case none
    case channelParticipant(RenderedChannelParticipant)
}

func _internal_requestStartBotInGroup(account: Account, botPeerId: PeerId, groupPeerId: PeerId, payload: String?) -> Signal<StartBotInGroupResult, RequestStartBotInGroupError> {
    return account.postbox.transaction { transaction -> (Peer?, Peer?) in
        return (transaction.getPeer(botPeerId), transaction.getPeer(groupPeerId))
    }
    |> mapError { _ -> RequestStartBotInGroupError in return .generic }
    |> mapToSignal { botPeer, groupPeer -> Signal<StartBotInGroupResult, RequestStartBotInGroupError> in
        if let botPeer = botPeer, let inputUser = apiInputUser(botPeer), let groupPeer = groupPeer, let inputGroup = apiInputPeer(groupPeer) {
            let request = account.network.request(Api.functions.messages.startBot(bot: inputUser, peer: inputGroup, randomId: Int64.random(in: Int64.min ... Int64.max), startParam: payload ?? ""))
            |> mapError { _ -> RequestStartBotInGroupError in
                return .generic
            }
            |> mapToSignal { result -> Signal<StartBotInGroupResult, RequestStartBotInGroupError> in
                account.stateManager.addUpdates(result)
                if groupPeerId.namespace == Namespaces.Peer.CloudChannel {
                    return _internal_fetchChannelParticipant(account: account, peerId: groupPeerId, participantId: botPeerId)
                    |> mapError { _ -> RequestStartBotInGroupError in return .generic
                    }
                    |> mapToSignal { participant -> Signal<StartBotInGroupResult, RequestStartBotInGroupError> in
                        return account.postbox.transaction { transaction -> StartBotInGroupResult in
                            if let participant = participant, let peer = transaction.getPeer(participant.peerId) {
                                var peers: [PeerId: Peer] = [:]
                                let presences: [PeerId: PeerPresence] = [:]
                                
                                peers[peer.id] = peer
                                return .channelParticipant(RenderedChannelParticipant(participant: participant, peer: peer, peers: peers, presences: presences))
                            } else {
                                return .none
                            }
                        }
                        |> mapError { _ -> RequestStartBotInGroupError in return .generic
                        }
                    }
                } else {
                    return .single(.none)
                }
            }
            
            return request
        } else {
            return .complete()
        }
    }
}
