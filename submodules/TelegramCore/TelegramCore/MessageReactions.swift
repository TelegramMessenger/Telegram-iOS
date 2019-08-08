import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
#endif


public enum RequestUpdateMessageReactionError {
    case generic
}

public func requestUpdateMessageReaction(account: Account, messageId: MessageId, reactions: [String]) -> Signal<Never, RequestUpdateMessageReactionError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> introduceError(RequestUpdateMessageReactionError.self)
    |> mapToSignal { peer in
        guard let inputPeer = apiInputPeer(peer) else {
            return .fail(.generic)
        }
        if messageId.namespace != Namespaces.Message.Cloud {
            return .fail(.generic)
        }
        return account.network.request(Api.functions.messages.sendReaction(peer: inputPeer, msgId: messageId.id, reaction: reactions))
        |> mapError { _ -> RequestUpdateMessageReactionError in
            return .generic
        }
        |> mapToSignal { result -> Signal<Never, RequestUpdateMessageReactionError> in
            account.stateManager.addUpdates(result)
            return .complete()
        }
    }
}
