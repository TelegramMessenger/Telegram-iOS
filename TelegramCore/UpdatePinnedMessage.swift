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

public enum UpdatePinnedMessageError {
    case generic
}

public enum PinnedMessageUpdate {
    case pin(id: MessageId, silent: Bool)
    case clear
}

public func requestUpdatePinnedMessage(account: Account, peerId: PeerId, update: PinnedMessageUpdate) -> Signal<Void, UpdatePinnedMessageError> {
    return account.postbox.modify { modifier -> Peer? in
        return modifier.getPeer(peerId)
    } |> mapError { _ -> UpdatePinnedMessageError in
        return .generic
    } |> mapToSignal { peer -> Signal<Void, UpdatePinnedMessageError> in
        if let group = peer as? TelegramChannel {
            let canManage = group.hasAdminRights([.canPinMessages])
            
            if let inputChannel = apiInputChannel(group), canManage {
                var flags: Int32 = 0
                let messageId: Int32
                switch update {
                    case let .pin(id, silent):
                        messageId = id.id
                        if silent {
                            flags |= (1 << 0)
                        }
                    case .clear:
                        messageId = 0
                }
                
                let request = Api.functions.channels.updatePinnedMessage(flags: flags, channel: inputChannel, id: messageId)
                
                return account.network.request(request)
                    |> mapError { _ -> UpdatePinnedMessageError in
                        return .generic
                    }
                    |> mapToSignal { updates -> Signal<Void, UpdatePinnedMessageError> in
                        account.stateManager.addUpdates(updates)
                        return account.postbox.modify { modifier  in
                            modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedChannelData {
                                    let pinnedMessageId: MessageId?
                                    switch update {
                                        case let .pin(id, _):
                                            pinnedMessageId = id
                                        case .clear:
                                            pinnedMessageId = nil
                                    }
                                    return current.withUpdatedPinnedMessageId(pinnedMessageId)
                                } else {
                                    return current
                                }
                            })
                        } |> mapError {_ -> UpdatePinnedMessageError in return .generic}
                }
            }
        }
        return .fail(.generic)
    }
}
