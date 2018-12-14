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

public enum RequestMessageSelectPollOptionError {
    case generic
}

public func requestMessageSelectPollOption(account: Account, messageId: MessageId, opaqueIdentifier: Data) -> Signal<Never, RequestMessageSelectPollOptionError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> introduceError(RequestMessageSelectPollOptionError.self)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.sendVote(peer: inputPeer, msgId: messageId.id, options: [Buffer(data: opaqueIdentifier)]))
            |> mapError { _ -> RequestMessageSelectPollOptionError in
                return .generic
            }
            |> mapToSignal { result -> Signal<Never, RequestMessageSelectPollOptionError> in
                account.stateManager.addUpdates(result)
                return .complete()
            }
        } else {
            return .complete()
        }
    }
}
