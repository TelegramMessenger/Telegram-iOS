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
            
            return account.network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: text, replyMarkup: nil, entities: apiEntities, geoPoint: nil))
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

public func requestEditLiveLocation(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageId: MessageId, coordinate: (latitude: Double, longitude: Double)?) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Api.InputPeer? in
        return modifier.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Void, NoError> in
        if let inputPeer = inputPeer {
            var flags: Int32 = 0
            if coordinate != nil {
                flags |= 1 << 13
            } else {
                flags |= 1 << 12
            }
            return network.request(Api.functions.messages.editMessage(flags: flags, peer: inputPeer, id: messageId.id, message: nil, replyMarkup: nil, entities: nil, geoPoint:  coordinate.flatMap { Api.InputGeoPoint.inputGeoPoint(lat: $0.latitude, long: $0.longitude) }))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    stateManager.addUpdates(updates)
                }
                if coordinate == nil {
                    return postbox.modify { modifier -> Void in
                        modifier.updateMessage(messageId, update: { currentMessage in
                            var storeForwardInfo: StoreMessageForwardInfo?
                            if let forwardInfo = currentMessage.forwardInfo {
                                storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature)
                            }
                            var updatedLocalTags = currentMessage.localTags
                            updatedLocalTags.remove(.OutgoingLiveLocation)
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: updatedLocalTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: currentMessage.attributes, media: currentMessage.media))
                        })
                    }
                } else {
                    return .complete()
                }
            }
        } else {
            return .complete()
        }
    }
}
