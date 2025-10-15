import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public func _internal_reportMessageDelivery(postbox: Postbox, network: Network, messageIds: [EngineMessage.Id], fromPushNotification: Bool) -> Signal<Bool, NoError> {
    var signals: [Signal<Void, NoError>] = []
    for (peerId, messageIds) in messagesIdsGroupedByPeerId(messageIds) {
        signals.append(_internal_reportMessageDeliveryByPeerId(postbox: postbox, network: network, peerId: peerId, messageIds: messageIds, fromPushNotification: fromPushNotification))
    }
    return combineLatest(signals)
    |> mapToSignal { _ in
        return .single(true)
    }
}

private func _internal_reportMessageDeliveryByPeerId(postbox: Postbox, network: Network, peerId: EnginePeer.Id, messageIds: [EngineMessage.Id], fromPushNotification: Bool) -> Signal<Void, NoError> {
    return postbox.transaction { transaction -> Signal<Void, NoError> in
        guard let peer = transaction.getPeer(peerId), let inputPeer = apiInputPeer(peer) else {
            return .complete()
        }
        var flags: Int32 = 0
        if fromPushNotification {
            flags |= (1 << 0)
        }
        return network.request(Api.functions.messages.reportMessagesDelivery(flags: flags, peer: inputPeer, id: messageIds.map { $0.id }))
        |> `catch` { error -> Signal<Api.Bool, NoError> in
            return .single(.boolFalse)
        }
        |> mapToSignal { _ in
            return .complete()
        }
    }
    |> switchToLatest
}
