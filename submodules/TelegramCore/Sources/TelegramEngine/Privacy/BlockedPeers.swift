import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func _internal_requestUpdatePeerIsBlocked(account: Account, peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let signal: Signal<Api.Bool, MTRpcError>
            if isBlocked {
                signal = account.network.request(Api.functions.contacts.block(flags: 0, id: inputPeer))
            } else {
                signal = account.network.request(Api.functions.contacts.unblock(flags: 0, id: inputPeer))
            }
            return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                return previous.withUpdatedIsBlocked(isBlocked)
                            })
                        }
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}

func _internal_requestUpdatePeerIsBlockedFromStories(account: Account, peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) {
            let flags: Int32 = 1 << 0
            let signal: Signal<Api.Bool, MTRpcError>
            if isBlocked {
                signal = account.network.request(Api.functions.contacts.block(flags: flags, id: inputPeer))
            } else {
                signal = account.network.request(Api.functions.contacts.unblock(flags: flags, id: inputPeer))
            }
            return signal
                |> map(Optional.init)
                |> `catch` { _ -> Signal<Api.Bool?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { result -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        if result != nil {
                            transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                                let previous: CachedUserData
                                if let current = current as? CachedUserData {
                                    previous = current
                                } else {
                                    previous = CachedUserData()
                                }
                                var userFlags = previous.flags
                                if isBlocked {
                                    userFlags.insert(.isBlockedFromStories)
                                } else {
                                    userFlags.remove(.isBlockedFromStories)
                                }
                                return previous.withUpdatedFlags(userFlags)
                            })
                        }
                    }
                }
        } else {
            return .complete()
        }
    } |> switchToLatest
}
