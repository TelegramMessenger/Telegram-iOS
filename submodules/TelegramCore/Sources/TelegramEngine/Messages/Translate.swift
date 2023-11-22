import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum TranslationError {
    case generic
    case invalidMessageId
    case textIsEmpty
    case textTooLong
    case invalidLanguage
    case limitExceeded
}

func _internal_translate(network: Network, text: String, toLang: String) -> Signal<String?, TranslationError> {
    var flags: Int32 = 0
    flags |= (1 << 1)

    return network.request(Api.functions.messages.translateText(flags: flags, peer: nil, id: nil, text: [.textWithEntities(text: text, entities: [])], toLang: toLang))
    |> mapError { error -> TranslationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription == "MSG_ID_INVALID" {
            return .invalidMessageId
        } else if error.errorDescription == "INPUT_TEXT_EMPTY" {
            return .textIsEmpty
        } else if error.errorDescription == "INPUT_TEXT_TOO_LONG" {
            return .textTooLong
        } else if error.errorDescription == "TO_LANG_INVALID" {
            return .invalidLanguage
        } else {
            return .generic
        }
    }
    |> mapToSignal { result -> Signal<String?, TranslationError> in
        switch result {
        case let .translateResult(results):
            if case let .textWithEntities(text, _) = results.first {
                return .single(text)
            } else {
                return .single(nil)
            }
        }
    }
}

func _internal_translateMessages(account: Account, messageIds: [EngineMessage.Id], toLang: String) -> Signal<Void, TranslationError> {
    guard let peerId = messageIds.first?.peerId else {
        return .never()
    }
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> castError(TranslationError.self)
    |> mapToSignal { inputPeer -> Signal<Void, TranslationError> in
        guard let inputPeer = inputPeer else {
            return .never()
        }
        
        var flags: Int32 = 0
        flags |= (1 << 0)
        
        let id: [Int32] = messageIds.map { $0.id }
        return account.network.request(Api.functions.messages.translateText(flags: flags, peer: inputPeer, id: id, text: nil, toLang: toLang))
        |> mapError { error -> TranslationError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else if error.errorDescription == "MSG_ID_INVALID" {
                return .invalidMessageId
            } else if error.errorDescription == "INPUT_TEXT_EMPTY" {
                return .textIsEmpty
            } else if error.errorDescription == "INPUT_TEXT_TOO_LONG" {
                return .textTooLong
            } else if error.errorDescription == "TO_LANG_INVALID" {
                return .invalidLanguage
            } else {
                return .generic
            }
        }
        |> mapToSignal { result -> Signal<Void, TranslationError> in
            guard case let .translateResult(results) = result else {
                return .complete()
            }
            return account.postbox.transaction { transaction in
                var index = 0
                for result in results {
                    let messageId = messageIds[index]
                    if case let .textWithEntities(text, entities) = result {
                        let updatedAttribute: TranslationMessageAttribute = TranslationMessageAttribute(text: text, entities: messageTextEntitiesFromApiEntities(entities), toLang: toLang)
                        transaction.updateMessage(messageId, update: { currentMessage in
                            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                            var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                            
                            attributes.append(updatedAttribute)
                            
                            return .update(StoreMessage(id: currentMessage.id, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                        })
                    }
                    index += 1
                }
            }
            |> castError(TranslationError.self)
        }
    }
}

func _internal_togglePeerMessagesTranslationHidden(account: Account, peerId: EnginePeer.Id, hidden: Bool) -> Signal<Never, NoError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, cachedData -> CachedPeerData? in
            if let cachedData = cachedData as? CachedUserData {
                var updatedFlags = cachedData.flags
                if hidden {
                    updatedFlags.insert(.translationHidden)
                } else {
                    updatedFlags.remove(.translationHidden)
                }
                return cachedData.withUpdatedFlags(updatedFlags)
            } else if let cachedData = cachedData as? CachedGroupData {
                var updatedFlags = cachedData.flags
                if hidden {
                    updatedFlags.insert(.translationHidden)
                } else {
                    updatedFlags.remove(.translationHidden)
                }
                return cachedData.withUpdatedFlags(updatedFlags)
            } else if let cachedData = cachedData as? CachedChannelData {
                var updatedFlags = cachedData.flags
                if hidden {
                    updatedFlags.insert(.translationHidden)
                } else {
                    updatedFlags.remove(.translationHidden)
                }
                return cachedData.withUpdatedFlags(updatedFlags)
            } else {
                return cachedData
            }
        })
        return transaction.getPeer(peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer = inputPeer else {
            return .never()
        }
        var flags: Int32 = 0
        if hidden {
            flags |= (1 << 0)
        }
        
        return account.network.request(Api.functions.messages.togglePeerTranslations(flags: flags, peer: inputPeer))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.Bool?, NoError> in
            return .single(nil)
        }
        |> ignoreValues
    }
}
