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

public func requestEditMessage(account: Account, messageId: MessageId, text: String) -> Signal<Bool, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
        |> take(1)
        |> mapToSignal { peer in
            if let inputPeer = apiInputPeer(peer) {
                return account.network.request(Api.functions.messages.editMessage(flags: (1 << 11), peer: inputPeer, id: messageId.id, message: text, replyMarkup: nil, entities: nil))
                    |> map { result -> Api.Updates? in
                        return result
                    }
                    |> `catch` { error -> Signal<Api.Updates?, MTRpcError> in
                        if error.errorDescription == "MESSAGE_NOT_MODIFIED" {
                            return .single(nil)
                        } else {
                            return .fail(error)
                        }
                    }
                    |> mapError { _ -> NoError in
                        return NoError()
                    }
                    |> mapToSignal { result -> Signal<Bool, NoError> in
                        if let result = result {
                            return .single(true)
                            account.stateManager.addUpdates(result)
                        } else {
                            return .single(false)
                        }
                    }
            } else {
                return .single(false)
            }
    }
}
