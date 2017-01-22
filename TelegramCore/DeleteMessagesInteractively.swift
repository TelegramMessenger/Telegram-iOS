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

public enum InteractiveMessagesDeletionType {
    case forLocalPeer
    case forEveryone
}

public func deleteMessagesInteractively(postbox: Postbox, messageIds: [MessageId], type: InteractiveMessagesDeletionType) -> Signal<Void, NoError> {
    return postbox.modify { modifier -> Void in
        var messageIdsByPeerId: [PeerId: [MessageId]] = [:]
        for id in messageIds {
            if messageIdsByPeerId[id.peerId] == nil {
                messageIdsByPeerId[id.peerId] = [id]
            } else {
                messageIdsByPeerId[id.peerId]!.append(id)
            }
        }
        for (peerId, peerMessageIds) in messageIdsByPeerId {
            if peerId.namespace == Namespaces.Peer.CloudChannel || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.CloudUser {
                cloudChatAddRemoveMessagesOperation(modifier: modifier, peerId: peerId, messageIds: peerMessageIds, type: CloudChatRemoveMessagesType(type))
            } else if peerId.namespace == Namespaces.Peer.SecretChat {
                if let state = modifier.getPeerChatState(peerId) as? SecretChatState {
                    var layer: SecretChatLayer?
                    switch state.embeddedState {
                        case .terminated, .handshake:
                            break
                        case .basicLayer:
                            layer = .layer8
                        case let .sequenceBasedLayer(sequenceState):
                            layer = SecretChatLayer(rawValue: sequenceState.layerNegotiationState.activeLayer)
                    }
                    if let layer = layer {
                        var globallyUniqueIds: [Int64] = []
                        for messageId in peerMessageIds {
                            if let message = modifier.getMessage(messageId), let globallyUniqueId = message.globallyUniqueId {
                                globallyUniqueIds.append(globallyUniqueId)
                            }
                        }
                        let updatedState = addSecretChatOutgoingOperation(modifier: modifier, peerId: peerId, operation: SecretChatOutgoingOperationContents.deleteMessages(layer: layer, actionGloballyUniqueId: arc4random64(), globallyUniqueIds: globallyUniqueIds), state: state)
                        if updatedState != state {
                            modifier.setPeerChatState(peerId, state: updatedState)
                        }
                    }
                }
            }
        }
        modifier.deleteMessages(messageIds)
    }
}

public func clearHistoryInteractively(peerId: PeerId) -> Signal<Void, NoError> {
    return .never()
}
