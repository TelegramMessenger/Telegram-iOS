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

public func updatePinnedMessage(_ pinnedMessageId:MessageId?, silent:Bool = false, for peerId:PeerId, account:Account) -> Signal<Void, UpdatePinnedMessageError> {
    return account.postbox.modify { modifier -> Peer? in
        return modifier.getPeer(peerId)
        } |> mapError { () -> UpdatePinnedMessageError in
            return .generic
        }  |> mapToSignal { peer -> Signal<Void, UpdatePinnedMessageError> in
            if let group = peer as? TelegramChannel {
                let canUpdate:Bool
                switch group.role {
                case .creator, .editor, .moderator:
                    canUpdate = true
                default:
                    canUpdate = false
                }
                
                if canUpdate, let inputChannel = apiInputChannel(group) {
                    
                    var flags:Int32 = 0
                    let messageId:Int32 = pinnedMessageId?.id ?? 0
                    if silent {
                        flags |= (1 << 0)
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
