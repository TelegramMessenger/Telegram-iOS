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

public func requestEditMessage(account: Account, messageId: MessageId, text: String, entities: TextEntitiesMessageAttribute? = nil, disableUrlPreview: Bool = false) -> Signal<Bool, NoError> {
    return account.postbox.modify { modifier -> (Peer?, SimpleDictionary<PeerId, Peer>) in
        guard let message = modifier.getMessage(messageId) else {
            return (nil, SimpleDictionary())
        }
    
        if text.isEmpty {
            for media in message.media {
                switch media {
                    case _ as TelegramMediaImage, _ as TelegramMediaFile:
                        break
                    default:
                        return (nil, SimpleDictionary())
                }
            }
        }
    
        var peers = SimpleDictionary<PeerId, Peer>()

        if let entities = entities {
            for peerId in entities.associatedPeerIds {
                if let peer = modifier.getPeer(peerId) {
                    peers[peer.id] = peer
                }
            }
        }
        return (modifier.getPeer(messageId.peerId), peers)
    }
    |> mapToSignal { peer, associatedPeers in
        if let peer = peer, let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 1 << 11
            
            var apiEntities: [Api.MessageEntity]?
            if let entities = entities {
                apiEntities = apiTextAttributeEntities(entities, associatedPeers: associatedPeers)
                flags |= Int32(1 << 3)
            }
            
            if disableUrlPreview {
                flags |= Int32(1 << 1)
            }
            
            return account.network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: text, replyMarkup: nil, entities: apiEntities))
                |> map { result -> Api.Updates? in
                    return result
                }
                |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                    if error.errorDescription == "MESSAGE_NOT_MODIFIED" {
                        return .single(nil)
                    } else {
                        return .fail(error)
                    }
                }
                |> mapError { _ -> NoError in
                    return NoError()
                }
                |> mapToSignal { result -> Signal<Bool, NoError> in
                    if let result = result {
                        account.stateManager.addUpdates(result)
                        return .single(true)
                    } else {
                        return .single(false)
                    }
                }
        } else {
            return .single(false)
        }
    }
}
