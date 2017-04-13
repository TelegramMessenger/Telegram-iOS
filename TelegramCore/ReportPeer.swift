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

public func reportPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId) {
            if let _ = peer as? TelegramSecretChat {
                return .complete()
            } else if let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.reportSpam(peer: inputPeer))
                    |> map { Optional($0) }
                    |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                        return .single(nil)
                    }
                    |> mapToSignal { result -> Signal<Void, NoError> in
                        return account.postbox.modify { modifier -> Void in
                            if result != nil {
                                modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                    if let current = current as? CachedUserData {
                                        return current.withUpdatedReportStatus(.didReport)
                                    } else if let current = current as? CachedGroupData {
                                        return current.withUpdatedReportStatus(.didReport)
                                    } else if let current = current as? CachedChannelData {
                                        return current.withUpdatedReportStatus(.didReport)
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

public enum ReportPeerReason : Equatable {
    case spam
    case violence
    case porno
    case custom(String)
}

public func ==(lhs:ReportPeerReason, rhs: ReportPeerReason) -> Bool {
    switch lhs {
    case .spam:
        if case .spam = rhs {
            return true
        } else {
            return false
        }
    case .violence:
        if case .violence = rhs {
            return true
        } else {
            return false
        }
    case .porno:
        if case .porno = rhs {
            return true
        } else {
            return false
        }
    case let .custom(text):
        if case .custom(text) = rhs {
            return true
        } else {
            return false
        }
    }
}

private extension ReportPeerReason {
    var apiReason:Api.ReportReason {
        switch self {
        case .spam:
            return .inputReportReasonSpam
        case .violence:
            return .inputReportReasonViolence
        case .porno:
            return .inputReportReasonPornography
        case let .custom(text):
            return .inputReportReasonOther(text: text)
        }
    }
}

public func reportPeer(account: Account, peerId:PeerId, reason:ReportPeerReason) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.account.reportPeer(peer: inputPeer, reason: reason.apiReason)) |> mapError {_ in} |> map {_ in}
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func reportSupergroupPeer(account: Account, peerId:PeerId, memberId:PeerId, messageIds:[MessageId]) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputChannel(peer), let memberPeer = modifier.getPeer(memberId), let inputMember = apiInputUser(memberPeer) {
            return account.network.request(Api.functions.channels.reportSpam(channel: inputPeer, userId: inputMember, id: messageIds.map({$0.id}))) |> mapError {_ in} |> map {_ in}
        } else {
            return .complete()
        }
    } |> switchToLatest
}

public func dismissReportPeer(account: Account, peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        modifier.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
            if let current = current as? CachedUserData {
                return current.withUpdatedReportStatus(.none)
            } else if let current = current as? CachedGroupData {
                return current.withUpdatedReportStatus(.none)
            } else if let current = current as? CachedChannelData {
                return current.withUpdatedReportStatus(.none)
            } else {
                return current
            }
        })
        
        if let peer = modifier.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.hideReportSpam(peer: inputPeer))
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
