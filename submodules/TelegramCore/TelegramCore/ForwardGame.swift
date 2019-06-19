import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif
import TelegramApi

public func forwardGameWithScore(account: Account, messageId: MessageId, to peerId: PeerId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let message = transaction.getMessage(messageId), let fromPeer = transaction.getPeer(messageId.peerId), let fromInputPeer = apiInputPeer(fromPeer), let toPeer = transaction.getPeer(peerId), let toInputPeer = apiInputPeer(toPeer) {
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
