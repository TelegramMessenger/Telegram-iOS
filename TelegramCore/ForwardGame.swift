import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public func forwardGameWithScore(account: Account, messageId: MessageId, to peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.modify { modifier -> Signal<Void, NoError> in
        if let message = modifier.getMessage(messageId), let fromPeer = modifier.getPeer(messageId.peerId), let fromInputPeer = apiInputPeer(fromPeer), let toPeer = modifier.getPeer(peerId), let toInputPeer = apiInputPeer(toPeer) {
            return account.network.request(Api.functions.messages.forwardMessages(flags: 1 << 8, fromPeer: fromInputPeer, id: [messageId.id], randomId: [arc4random64()], toPeer: toInputPeer))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.Updates?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { updates -> Signal<Void, NoError> in
                if let updates = updates {
                    account.stateManager.addUpdates(updates)
                }
                return .complete()
            }
        }
        return .complete()
    } |> switchToLatest
}
