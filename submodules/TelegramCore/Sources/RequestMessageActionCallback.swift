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

public enum MessageActionCallbackError {
    case generic
    case twoStepAuthMissing
    case twoStepAuthTooFresh(Int32)
    case authSessionTooFresh(Int32)
    case limitExceeded
    case requestPassword
    case invalidPassword
    case restricted
    case userBlocked
}

public func requestMessageActionCallbackPasswordCheck(account: Account, messageId: MessageId, isGame: Bool, data: MemoryBuffer?) -> Signal<Never, MessageActionCallbackError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
     |> castError(MessageActionCallbackError.self)
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
            
            return account.network.request(Api.functions.messages.getBotCallbackAnswer(flags: flags, peer: inputPeer, msgId: messageId.id, data: dataBuffer, password: .inputCheckPasswordEmpty))
            |> mapError { error -> MessageActionCallbackError in
                if error.errorDescription == "PASSWORD_HASH_INVALID" {
                    return .requestPassword
                } else if error.errorDescription == "PASSWORD_MISSING" {
                    return .twoStepAuthMissing
                } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .twoStepAuthTooFresh(value)
                    }
                } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                    let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                    if let value = Int32(timeout) {
                        return .authSessionTooFresh(value)
                    }
                } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                    return .restricted
                } else if error.errorDescription == "USER_BLOCKED" {
                    return .userBlocked
                }
                return .generic
            }
            |> mapToSignal { _ -> Signal<Never, MessageActionCallbackError> in
                return .complete()
            }
         } else {
            return .fail(.generic)
        }
    }
}

public func requestMessageActionCallback(account: Account, messageId: MessageId, isGame :Bool, password: String?, data: MemoryBuffer?) -> Signal<MessageActionCallbackResult, MessageActionCallbackError> {
    return account.postbox.loadedPeerWithId(messageId.peerId)
    |> castError(MessageActionCallbackError.self)
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
            
            let checkPassword: Signal<Api.InputCheckPasswordSRP?, MessageActionCallbackError>
            if let password = password, !password.isEmpty {
                flags |= Int32(1 << 2)
                
                checkPassword = twoStepAuthData(account.network)
                |> mapError { error -> MessageActionCallbackError in
                    if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                        return .limitExceeded
                    } else {
                        return .generic
                    }
                }
                |> mapToSignal { authData -> Signal<Api.InputCheckPasswordSRP?, MessageActionCallbackError> in
                    if let currentPasswordDerivation = authData.currentPasswordDerivation, let srpSessionData = authData.srpSessionData {
                        guard let kdfResult = passwordKDF(encryptionProvider: account.network.encryptionProvider, password: password, derivation: currentPasswordDerivation, srpSessionData: srpSessionData) else {
                            return .fail(.generic)
                        }
                        return .single(.inputCheckPasswordSRP(srpId: kdfResult.id, A: Buffer(data: kdfResult.A), M1: Buffer(data: kdfResult.M1)))
                    } else {
                        return .fail(.twoStepAuthMissing)
                    }
                }
            } else {
                checkPassword = .single(nil)
            }
        
            return checkPassword
            |> mapToSignal { password -> Signal<MessageActionCallbackResult, MessageActionCallbackError> in
                return account.network.request(Api.functions.messages.getBotCallbackAnswer(flags: flags, peer: inputPeer, msgId: messageId.id, data: dataBuffer, password: password))
                |> map(Optional.init)
                |> mapError { error -> MessageActionCallbackError in
                    if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                        return .limitExceeded
                    } else if error.errorDescription == "PASSWORD_HASH_INVALID" {
                        return .invalidPassword
                    } else if error.errorDescription == "PASSWORD_MISSING" {
                        return .twoStepAuthMissing
                    } else if error.errorDescription.hasPrefix("PASSWORD_TOO_FRESH_") {
                        let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "PASSWORD_TOO_FRESH_".count)...])
                        if let value = Int32(timeout) {
                            return .twoStepAuthTooFresh(value)
                        }
                    } else if error.errorDescription.hasPrefix("SESSION_TOO_FRESH_") {
                        let timeout = String(error.errorDescription[error.errorDescription.index(error.errorDescription.startIndex, offsetBy: "SESSION_TOO_FRESH_".count)...])
                        if let value = Int32(timeout) {
                            return .authSessionTooFresh(value)
                        }
                    } else if error.errorDescription == "USER_PRIVACY_RESTRICTED" {
                        return .restricted
                    } else if error.errorDescription == "USER_BLOCKED" {
                        return .userBlocked
                    }
                    return .generic
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
