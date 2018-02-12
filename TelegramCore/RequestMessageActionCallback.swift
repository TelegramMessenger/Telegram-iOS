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

public enum MessageActionCallbackResult {
    case none
    case alert(String)
    case toast(String)
    case url(String)
}

public func requestMessageActionCallback(account: Account, messageId: MessageId, isGame:Bool, data: MemoryBuffer?) -> Signal<MessageActionCallbackResult, NoError> {
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
                if isGame {
                    flags |= Int32(1 << 1)
                }
                return account.network.request(Api.functions.messages.getBotCallbackAnswer(flags: flags, peer: inputPeer, msgId: messageId.id, data: dataBuffer))
                    |> retryRequest
                    |> map { result -> MessageActionCallbackResult in
                        //messages.botCallbackAnswer#36585ea4 flags:# alert:flags.1?true has_url:flags.3?true message:flags.0?string url:flags.2?string cache_time:int = messages.BotCallbackAnswer;

                        switch result {
                            case let .botCallbackAnswer(flags, message, url, cacheTime):
                                if let message = message {
                                    if (flags & (1 << 1)) != 0 {
                                        return .alert(message)
                                    } else {
                                        return .toast(message)
                                    }
                                } else if let url = url {
                                    return .url(url)
                                } else {
                                    return .none
                                }
                        }
                    }
            } else {
                return .single(.none)
            }
        }
}
