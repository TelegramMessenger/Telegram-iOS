import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

func _internal_chatOnlineMembers(postbox: Postbox, network: Network, peerId: PeerId) -> Signal<Int32, NoError> {
    return postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Int32, NoError> in
        guard let inputPeer = inputPeer else {
            return .single(0)
        }
        return network.request(Api.functions.messages.getOnlines(peer: inputPeer))
        |> map { value -> Int32 in
            switch value {
                case let .chatOnlines(onlines):
                    return onlines
            }
        }
        |> `catch` { _ -> Signal<Int32, NoError> in
            return .single(0)
        }
    }
}
