import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public enum SummarizeError {
    case generic
    case invalidMessageId
    case limitExceeded
    case invalidLanguage
    case limitExceededPremium
}

func _internal_summarizeMessage(account: Account, messageId: EngineMessage.Id, translateToLang: String?) -> Signal<Never, SummarizeError> {
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(messageId.peerId).flatMap(apiInputPeer)
    }
    |> castError(SummarizeError.self)
    |> mapToSignal { inputPeer -> Signal<Never, SummarizeError> in
        guard let inputPeer else {
            return .never()
        }
                
        var flags: Int32 = 0
        if let _ = translateToLang {
            flags |= (1 << 0)
        }
        
        return account.network.request(Api.functions.messages.summarizeText(flags: flags, peer: inputPeer, id: messageId.id, toLang: translateToLang))
        |> map(Optional.init)
        |> mapError { error -> SummarizeError in
            if error.errorDescription.hasPrefix("FLOOD_WAIT") {
                return .limitExceeded
            } else if error.errorDescription == "MSG_ID_INVALID" {
                return .invalidMessageId
            } else if error.errorDescription == "TO_LANG_INVALID" {
                return .invalidLanguage
            } else if error.errorDescription == "SUMMARY_FLOOD_PREMIUM" {
                return .limitExceededPremium
            } else {
                return .generic
            }
        }
        |> mapToSignal { result -> Signal<Void, SummarizeError> in
            return account.postbox.transaction { transaction in
                switch result {
                case let .textWithEntities(textWithEntitiesData):
                    let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                    transaction.updateMessage(messageId, update: { currentMessage in
                        let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                        var attributes = currentMessage.attributes

                        let currentAttribute = attributes.first(where: { $0 is SummarizationMessageAttribute }) as? SummarizationMessageAttribute
                        let updatedAttribute: SummarizationMessageAttribute
                        if let translateToLang {
                            var translated = currentAttribute?.translated ?? [:]
                            translated[translateToLang] = SummarizationMessageAttribute.Summary(text: text, entities: messageTextEntitiesFromApiEntities(entities))
                            updatedAttribute = SummarizationMessageAttribute(
                                fromLang: currentAttribute?.fromLang ?? "",
                                summary: currentAttribute?.summary,
                                translated: translated
                            )
                        } else {
                            updatedAttribute = SummarizationMessageAttribute(
                                fromLang: currentAttribute?.fromLang ?? "",
                                summary: .init(text: text, entities: messageTextEntitiesFromApiEntities(entities)),
                                translated: currentAttribute?.translated ?? [:]
                            )
                        }
                        attributes = attributes.filter { !($0 is SummarizationMessageAttribute) }
                        attributes.append(updatedAttribute)
                        
                        return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                    })
                default:
                    break
                }
            }
            |> castError(SummarizeError.self)
        }
        |> ignoreValues
    }
}
