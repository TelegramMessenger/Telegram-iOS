import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum CopyProtectionResult {
    case applied
    case requested
}

func _internal_toggleMessageCopyProtection(account: Account, peerId: PeerId, enabled: Bool, requestMessageId: EngineMessage.Id?) -> Signal<CopyProtectionResult, NoError> {
    return account.postbox.transaction { transaction -> Signal<CopyProtectionResult, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if let _ = requestMessageId {
                flags = (1 << 0)
            }
            return account.network.request(Api.functions.messages.toggleNoForwards(flags: flags, peer: inputPeer, enabled: enabled ? .boolTrue : .boolFalse, requestMsgId: requestMessageId?.id)) |> `catch` { _ in .complete() } |> mapToSignal { updates -> Signal<CopyProtectionResult, NoError> in
                account.stateManager.addUpdates(updates)

                var isRequest = false
                switch updates {
                case let .updates(data):
                    for update in data.updates {
                        if case let .updateNewMessage(msgData) = update, case let .messageService(serviceData) = msgData.message, case .messageActionNoForwardsRequest = serviceData.action {
                            isRequest = true
                        }
                    }
                default:
                    break
                }

                if !isRequest {
                    return account.postbox.transaction { transaction -> CopyProtectionResult in
                        transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current in
                            if let previous = current as? CachedUserData {
                                var updatedFlags = previous.flags
                                var updatedMyCopyProtectionEnableDate: Int32?
                                if enabled {
                                    updatedFlags.insert(.myCopyProtectionEnabled)
                                    updatedMyCopyProtectionEnableDate = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                                } else {
                                    updatedFlags.remove(.myCopyProtectionEnabled)
                                }
                                return previous.withUpdatedFlags(updatedFlags).withUpdatedMyCopyProtectionEnableDate(updatedMyCopyProtectionEnableDate)
                            }
                            return current
                        })
                        return .applied
                    }
                } else {
                    return .single(.requested)
                }
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
