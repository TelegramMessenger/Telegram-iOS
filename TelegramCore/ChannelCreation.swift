import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

private func createChannel(account: Account, title: String, description: String?, isSupergroup:Bool) -> Signal<PeerId?, NoError> {
    return account.postbox.transaction { transaction -> Signal<PeerId?, NoError> in
        return account.network.request(Api.functions.channels.createChannel(flags: isSupergroup ? 1 << 1 : 1 << 0, title: title, about: description ?? ""), automaticFloodWait: false)
        |> map(Optional.init)
        |> `catch` { _ in
            return Signal<Api.Updates?, NoError>.single(nil)
        }
        |> mapToSignal { updates -> Signal<PeerId?, NoError> in
            if let updates = updates {
                account.stateManager.addUpdates(updates)
                if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                    return account.postbox.multiplePeersView([peerId])
                    |> filter { view in
                        return view.peers[peerId] != nil
                    }
                    |> take(1)
                    |> map { _ in
                        return peerId
                    }
                    |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
                }
                return .single(nil)
            } else {
                return .single(nil)
            }
        }
    } |> switchToLatest
}

public func createChannel(account: Account, title: String, description: String?) -> Signal<PeerId?, NoError> {
    return createChannel(account: account, title: title, description: description, isSupergroup: false)
}

public func createSupergroup(account: Account, title: String, description: String?) -> Signal<PeerId?, NoError> {
    return createChannel(account: account, title: title, description: description, isSupergroup: true)
}

public enum DeleteChannelError {
    case generic
}

public func deleteChannel(account: Account, peerId: PeerId) -> Signal<Void, DeleteChannelError> {
    return account.postbox.transaction { transaction -> Api.InputChannel? in
        return transaction.getPeer(peerId).flatMap(apiInputChannel)
    }
    |> mapError { _ -> DeleteChannelError in return .generic }
    |> mapToSignal { inputChannel -> Signal<Void, DeleteChannelError> in
        if let inputChannel = inputChannel {
            return account.network.request(Api.functions.channels.deleteChannel(channel: inputChannel))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, DeleteChannelError> in
                return .fail(.generic)
            }
            |> mapToSignal { updates -> Signal<Void, DeleteChannelError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return .complete()
            }
        } else {
            return .fail(.generic)
        }
    }
}
