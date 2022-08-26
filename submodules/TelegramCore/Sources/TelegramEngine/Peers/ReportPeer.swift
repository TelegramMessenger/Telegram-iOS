import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


func _internal_reportPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId) {
            if let peer = peer as? TelegramSecretChat {
                return account.network.request(Api.functions.messages.reportEncryptedSpam(peer: Api.InputEncryptedChat.inputEncryptedChat(chatId: Int32(peer.id.id._internalGetInt64Value()), accessHash: peer.accessHash)))
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
                                    peerStatusSettings.flags = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedGroupData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings.flags = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedChannelData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings.flags = []
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
                                    peerStatusSettings.flags = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedGroupData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings.flags = []
                                    return current.withUpdatedPeerStatusSettings(peerStatusSettings)
                                } else if let current = current as? CachedChannelData {
                                    var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                                    peerStatusSettings.flags = []
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
    case fake
    case violence
    case porno
    case childAbuse
    case copyright
    case irrelevantLocation
    case illegalDrugs
    case personalDetails
    case custom
}

private extension ReportReason {
    var apiReason: Api.ReportReason {
        switch self {
            case .spam:
                return .inputReportReasonSpam
            case .fake:
                return .inputReportReasonFake
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
            case .illegalDrugs:
                return .inputReportReasonIllegalDrugs
            case .personalDetails:
                return .inputReportReasonPersonalDetails
            case .custom:
                return .inputReportReasonOther
        }
    }
}

func _internal_reportPeer(account: Account, peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.account.reportPeer(peer: inputPeer, reason: reason.apiReason, message: message))
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

func _internal_reportPeerPhoto(account: Account, peerId: PeerId, reason: ReportReason, message: String) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.account.reportProfilePhoto(peer: inputPeer, photoId: .inputPhotoEmpty, reason: reason.apiReason, message: message))
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

func _internal_reportPeerMessages(account: Account, messageIds: [MessageId], reason: ReportReason, message: String) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        let groupedIds = messagesIdsGroupedByPeerId(messageIds)
        let signals = groupedIds.values.compactMap { ids -> Signal<Void, NoError>? in
            guard let peerId = ids.first?.peerId, let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
                return nil
            }
            return account.network.request(Api.functions.messages.report(peer: inputPeer, id: ids.map { $0.id }, reason: reason.apiReason, message: message))
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

func _internal_reportPeerReaction(account: Account, authorId: PeerId, messageId: MessageId) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer, Api.InputPeer)? in
        guard let peer = transaction.getPeer(messageId.peerId).flatMap(apiInputPeer) else {
            return nil
        }
        guard let author = transaction.getPeer(authorId).flatMap(apiInputPeer) else {
            return nil
        }
        return (peer, author)
    }
    |> mapToSignal { inputData -> Signal<Never, NoError> in
        guard let (inputPeer, authorPeer) = inputData else {
            return .complete()
        }
        return account.network.request(Api.functions.messages.reportReaction(peer: inputPeer, id: messageId.id, reactionPeer: authorPeer))
        |> `catch` { _ -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> ignoreValues
    }
}

func _internal_dismissPeerStatusOptions(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            if let current = current as? CachedUserData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings.flags = []
                return current.withUpdatedPeerStatusSettings(PeerStatusSettings(flags: []))
            } else if let current = current as? CachedGroupData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings.flags = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if let current = current as? CachedChannelData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings.flags = []
                return current.withUpdatedPeerStatusSettings(peerStatusSettings)
            } else if let current = current as? CachedSecretChatData {
                var peerStatusSettings = current.peerStatusSettings ?? PeerStatusSettings()
                peerStatusSettings.flags = []
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

func _internal_reportRepliesMessage(account: Account, messageId: MessageId, deleteMessage: Bool, deleteHistory: Bool, reportSpam: Bool) -> Signal<Never, NoError> {
    if messageId.namespace != Namespaces.Message.Cloud {
        return .complete()
    }
    var flags: Int32 = 0
    if deleteMessage {
        flags |= 1 << 0
    }
    if deleteHistory {
        flags |= 1 << 1
    }
    if reportSpam {
        flags |= 1 << 2
    }
    return account.network.request(Api.functions.contacts.blockFromReplies(flags: flags, msgId: messageId.id))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Updates?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { updates -> Signal<Never, NoError> in
        if let updates = updates {
            account.stateManager.addUpdates(updates)
        }
        return .complete()
    }
}
