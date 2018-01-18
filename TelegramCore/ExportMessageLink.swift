
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif


public func exportMessageLink(account:Account, peerId:PeerId, messageId:MessageId) -> Signal<String?, Void> {
    return account.postbox.modify { modifier -> Peer? in
        return modifier.getPeer(peerId)
        } |> mapToSignal { peer -> Signal<String?, Void> in
            if let peer = peer, let input = apiInputChannel(peer) {
<<<<<<< HEAD
                return account.network.request(Api.functions.channels.exportMessageLink(channel: input, id: messageId.id, grouped: Api.Bool.boolTrue)) |> mapError {_ in return } |> map { res in
=======
                return account.network.request(Api.functions.channels.exportMessageLink(channel: input, id: messageId.id, grouped: .boolTrue)) |> mapError {_ in return } |> map { res in
>>>>>>> 50c01586839b0113730b0aaa9a4011b954868da2
                    switch res {
                        case let .exportedMessageLink(link, _):
                            return link
                    }
                    } |> `catch` { _ -> Signal<String?, NoError> in
                        return .single(nil)
                }
            } else {
                return .single(nil)
            }
    }
}
