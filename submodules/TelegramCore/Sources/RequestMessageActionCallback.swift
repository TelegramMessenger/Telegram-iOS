import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


import SyncCore

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
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.messages.BotCallbackAnswer?, NoError> in
                return .single(nil)
            }
            |> map { result -> MessageActionCallbackResult in
                guard let result = result else {
                    return .none
                }
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

public enum MessageActionUrlAuthResult {
    case `default`
    case accepted(String)
    case request(String, Peer, Bool)
}

public func requestMessageActionUrlAuth(account: Account, messageId: MessageId, buttonId: Int32) -> Signal<MessageActionUrlAuthResult, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            return account.network.request(Api.functions.messages.requestUrlAuth(peer: inputPeer, msgId: messageId.id, buttonId: buttonId))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.UrlAuthResult?, NoError> in
                return .single(nil)
            }
            |> map { result -> MessageActionUrlAuthResult in
                guard let result = result else {
                    return .default
                }
                switch result {
                    case .urlAuthResultDefault:
                        return .default
                    case let .urlAuthResultAccepted(url):
                        return .accepted(url)
                    case let .urlAuthResultRequest(flags, bot, domain):
                        return .request(domain, TelegramUser(user: bot), (flags & (1 << 0)) != 0)
                }
            }
        } else {
            return .single(.default)
        }
    }
}

public func acceptMessageActionUrlAuth(account: Account, messageId: MessageId, buttonId: Int32, allowWriteAccess: Bool) -> Signal<MessageActionUrlAuthResult, NoError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> take(1)
    |> mapToSignal { peer in
        if let inputPeer = apiInputPeer(peer) {
            var flags: Int32 = 0
            if allowWriteAccess {
                flags |= Int32(1 << 0)
            }
            return account.network.request(Api.functions.messages.acceptUrlAuth(flags: flags, peer: inputPeer, msgId: messageId.id, buttonId: buttonId))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.UrlAuthResult?, NoError> in
                return .single(nil)
            }
            |> map { result -> MessageActionUrlAuthResult in
                guard let result = result else {
                    return .default
                }
                switch result {
                    case let .urlAuthResultAccepted(url):
                        return .accepted(url)
                    default:
                        return .default
                }
            }
        } else {
            return .single(.default)
        }
    }
}
