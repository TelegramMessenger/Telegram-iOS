import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import TelegramApiMac
#else
    import Postbox
    import SwiftSignalKit
    import TelegramApi
#endif

public func sendScheduledMessageNow(account: Account, messageId: MessageId) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Signal<Void, NoError> in
        if let _ = transaction.getMessage(messageId), let peer = transaction.getPeer(messageId.peerId), let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.sendScheduledMessages(peer: inputPeer, id: [messageId.id]))
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
