import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

import SyncCore

public func reportPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramSecretChat {
                return account.network.request(Api.functions.messages.reportEncryptedSpam(peer: Api.InputEncryptedChat.inputEncryptedChat(chatId: peer.id.id, accessHash: peer.accessHash)))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedUserData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedGroupData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedChannelData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else {
                                    return current
                                }
                            })
                        }
                    }
                }
            } else if let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.reportSpam(peer: inputPeer))
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                if let current = current as? CachedUserData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedGroupData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedChannelData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else {
                                    return current
                                }
                            })
                        }
                    }
                }
            } else {
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public enum ReportReason: Equatable {
    case spam
    case violence
    case porno
    case childAbuse
    case copyright
    case irrelevantLocation
    case custom(String)
}

private extension ReportReason {
    var apiReason: Api.ReportReason {
        switch self {
            case .spam:
                return .inputReportReasonSpam
            case .violence:
                return .inputReportReasonViolence
            case .porno:
                return .inputReportReasonPornography
            case .childAbuse:
                return .inputReportReasonChildAbuse
            case .copyright:
                return .inputReportReasonCopyright
            case .irrelevantLocation:
                return .inputReportReasonGeoIrrelevant
            case let .custom(text):
                return .inputReportReasonOther(text: text)
        }
    }
}

public func reportPeer(account: Account, peerId: PeerId, reason: ReportReason) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.account.reportPeer(peer: inputPeer, reason: reason.apiReason))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func reportPeerMessages(account: Account, messageIds: [MessageId], reason: ReportReason) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        let groupedIds = messagesIdsGroupedByPeerId(messageIds)
        let signals = groupedIds.values.compactMap { ids -> Signal<Void, NoError>? in
            guard let peerId = ids.first?.peerId, let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            return account.network.request(Api.functions.messages.report(peer: inputPeer, id: ids.map { $0.id }, reason: reason.apiReason))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        }
        
        return combineLatest(signals)
        |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    } |> switchToLatest
}

public func reportSupergroupPeer(account: Account, peerId: PeerId, memberId: PeerId, messageIds: [MessageId]) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputChannel(peer), let memberPeer = transaction.getPeer(memberId), let inputMember = apiInputUser(memberPeer) {
            return account.network.request(Api.functions.channels.reportSpam(channel: inputPeer, userId: inputMember, id: messageIds.map({$0.id})))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func dismissPeerStatusOptions(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            if let current = current as? CachedUserData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if let current = current as? CachedGroupData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if let current = current as? CachedChannelData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if let current = current as? CachedSecretChatData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else {
                return current
            }
        })
        
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.hidePeerSettingsBar(peer: inputPeer))
            |> `catch` { _ -> Signal<Api.Bool, NoError> in
                return .single(.boolFalse)
            }
            |> mapToSignal { _ -> Signal<Void, NoError> in
                return .complete()
            }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
