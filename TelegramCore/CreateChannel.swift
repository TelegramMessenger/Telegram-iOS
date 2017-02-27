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

public func createChannel(account: Account, title: String, description: String?) -> Signal<PeerId?, NoError> {
    return account.postbox.modify { modifier -> Signal<PeerId?, NoError> in
        return account.network.request(Api.functions.channels.createChannel(flags: 1 << 0, title: title, about: description ?? ""))
            |> map { Optional($0) }
            |> `catch` { _ in
                return Signal<Api.Updates?, NoError>.single(nil)
            }
            |> mapToSignal { updates -> Signal<PeerId?, NoError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                    if let message = updates.messages.first, let peerId = message.peerId {
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
