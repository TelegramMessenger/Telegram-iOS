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

public func requestMessageActionCallback(account: Account, messageId: MessageId, data: MemoryBuffer?) -> Signal<Void, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
        |> take(1)
        |> mapToSignal { peer in
            if let inputPeer = apiInputPeer(peer) {
                var flags: Int32 = 0
                var dataBuffer: Buffer?
                if let data = data {
                    flags |= Int32(1 << 0)
                    dataBuffer = Buffer(data: data.makeData())
                }
                return account.network.request(Api.functions.messages.getBotCallbackAnswer(flags: flags, peer: inputPeer, msgId: messageId.id, data: dataBuffer))
                    |> retryRequest
                    |> map { result in
                        return Void()
                    }
            } else {
                return .complete()
            }
        }
}
