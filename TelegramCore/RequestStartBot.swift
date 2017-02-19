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

public func requestStartBot(account: Account, botPeerId: PeerId, payload: String?) -> Signal<Void, NoError> {
    if let payload = payload, !payload.isEmpty {
        return account.postbox.loadedPeerWithId(botPeerId)
            |> mapToSignal { botPeer -> Signal<Void, NoError> in
                if let inputUser = apiInputUser(botPeer) {
                    var randomId: Int64 = 0
                    arc4random_buf(&randomId, 8)
                    let r = account.network.request(Api.functions.messages.startBot(bot: inputUser, peer: .inputPeerEmpty, randomId: randomId, startParam: payload ?? ""))
                        |> mapToSignal { result -> Signal<Void, MTRpcError> in
                            account.stateManager.addUpdates(result)
                            return .complete()
                        }
                        |> `catch` { _ -> Signal<Void, MTRpcError> in
                            return .complete()
                        }
                    return r
                        |> retryRequest
                } else {
                    return .complete()
                }
            }
    } else {
        return enqueueMessages(account: account, peerId: botPeerId, messages: [.message(text: "/start", attributes: [], media: nil, replyToMessageId: nil)]) |> mapToSignal { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }
}
