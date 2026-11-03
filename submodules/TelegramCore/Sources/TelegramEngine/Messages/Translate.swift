import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit

public enum ComposedRichMessage: Equatable {
    /// Structured content → a rich message (`RichTextMessageAttribute(instantPage:)`, sent with `text: ""`).
    case rich(instantPage: InstantPage)
    /// Entity-expressible content → a normal message (`text` + `TextEntitiesMessageAttribute`).
    case plain(text: String, entities: [MessageTextEntity])
    /// Nothing worth sending (empty / whitespace-only document).
    case empty
}

public enum TranslationError {
    case generic
    case invalidMessageId
    case textIsEmpty
    case textTooLong
    case invalidLanguage
    case limitExceeded
    case tryAlternative
}

public enum TranslationTone: String {
    case neutral
    case casual
    case formal
}

func _internal_translate(network: Network, text: String, toLang: String, entities: [MessageTextEntity] = [], tone: TranslationTone = .neutral, peer: Api.InputPeer? = nil, messageId: Int32? = nil) -> Signal<(String, [MessageTextEntity])?, TranslationError> {
    var flags: Int32 = 0

    if tone != .neutral {
        flags |= (1 << 2)
    }

    let apiText: [Api.TextWithEntities]?
    if peer != nil && messageId != nil {
        flags |= (1 << 0)
        apiText = nil
    } else {
        flags |= (1 << 1)
        apiText = [.textWithEntities(.init(text: text, entities: apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary())))]
    }

    return network.request(Api.functions.messages.translateText(flags: flags, peer: peer, id: messageId.flatMap { [$0] }, text: apiText, toLang: toLang, tone: tone.rawValue))
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
        } else if error.errorDescription == "TRANSLATIONS_DISABLED_ALT" {
            return .tryAlternative
        } else {
            return .generic
        }
    }
    |> mapToSignal { result -> Signal<(String, [MessageTextEntity])?, TranslationError> in
        switch result {
        case let .translateResult(translateResultData):
            let results = translateResultData.result
            if case let .textWithEntities(textWithEntitiesData) = results.first {
                let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                return .single((text, messageTextEntitiesFromApiEntities(entities)))
            } else {
                return .single(nil)
            }
        }
    }
}

func _internal_composeMessageWithAI(account: Account, text: String, entities: [MessageTextEntity], proofread: Bool = false, translateToLang: String? = nil, changeStyle: TelegramComposeAIMessageMode.CloudStyle.Reference? = nil, emojify: Bool = false) -> Signal<(String, [MessageTextEntity]), TranslationError> {
    var flags: Int32 = 0
    if proofread {
        flags |= (1 << 0)
    }
    if translateToLang != nil {
        flags |= (1 << 1)
    }
    
    var changeTone: Api.InputAiComposeTone?
    if let changeStyle {
        flags |= (1 << 2)
        changeTone = changeStyle.apiInputStyle
    }
    if emojify {
        flags |= (1 << 3)
    }
    
    let apiText: Api.TextWithEntities = .textWithEntities(.init(text: text, entities: apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary())))

    return account.network.request(Api.functions.messages.composeMessageWithAI(flags: flags, text: apiText, translateToLang: translateToLang, tone: changeTone))
    |> mapError { error -> TranslationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription == "INPUT_TEXT_EMPTY" {
            return .textIsEmpty
        } else if error.errorDescription == "INPUT_TEXT_TOO_LONG" {
            return .textTooLong
        } else if error.errorDescription.hasPrefix("AICOMPOSE_FLOOD_PREMIUM ") {
            return .limitExceeded
        } else {
            return .generic
        }
    }
    |> map { result -> (String, [MessageTextEntity]) in
        switch result {
        case let .composedMessageWithAI(data):
            switch data.resultText {
            case let .textWithEntities(textData):
                return (textData.text, messageTextEntitiesFromApiEntities(textData.entities))
            }
        }
    }
}

func _internal_composeRichMessageWithAI(account: Account, instantPage: InstantPage?, proofread: Bool = false, translateToLang: String? = nil, changeStyle: TelegramComposeAIMessageMode.CloudStyle.Reference? = nil, customPrompt: String? = nil, emojify: Bool = false) -> Signal<InstantPage, TranslationError> {
    var flags: Int32 = 0
    if proofread {
        flags |= (1 << 0)
    }
    if translateToLang != nil {
        flags |= (1 << 1)
    }

    var changeTone: Api.InputAiComposeTone?
    if let customPrompt {
        flags |= (1 << 2)
        changeTone = .inputAiComposeToneSingleUse(Api.InputAiComposeTone.Cons_inputAiComposeToneSingleUse(customPrompt: customPrompt))
    } else if let changeStyle {
        flags |= (1 << 2)
        changeTone = changeStyle.apiInputStyle
    }
    if emojify {
        flags |= (1 << 3)
    }

    var inputRichMessage: Api.InputRichMessage?
    if let instantPage {
        flags |= (1 << 4)
        inputRichMessage = RichTextMessageAttribute(instantPage: instantPage, fullInstantPage: nil).apiInputRichMessage()
    }

    return account.network.request(Api.functions.messages.composeRichMessageWithAI(flags: flags, text: inputRichMessage, translateToLang: translateToLang, tone: changeTone))
    |> mapError { error -> TranslationError in
        if error.errorDescription.hasPrefix("FLOOD_WAIT") {
            return .limitExceeded
        } else if error.errorDescription == "INPUT_TEXT_EMPTY" {
            return .textIsEmpty
        } else if error.errorDescription == "INPUT_TEXT_TOO_LONG" {
            return .textTooLong
        } else if error.errorDescription.hasPrefix("AICOMPOSE_FLOOD_PREMIUM ") {
            return .limitExceeded
        } else {
            return .generic
        }
    }
    |> map { result -> InstantPage in
        switch result {
        case let .composedRichMessageWithAI(data):
            return RichTextMessageAttribute(apiRichMessage: data.result).instantPage
        }
    }
}

func _internal_translateTexts(network: Network, texts: [(String, [MessageTextEntity])], toLang: String, tone: TranslationTone = .neutral) -> Signal<[(String, [MessageTextEntity])], TranslationError> {
    var flags: Int32 = 0
    flags |= (1 << 1)
    
    if tone != .neutral {
        flags |= (1 << 2)
    }
    
    var apiTexts: [Api.TextWithEntities] = []
    for text in texts {
        apiTexts.append(.textWithEntities(.init(text: text.0, entities: apiEntitiesFromMessageTextEntities(text.1, associatedPeers: SimpleDictionary()))))
    }

    return network.request(Api.functions.messages.translateText(flags: flags, peer: nil, id: nil, text: apiTexts, toLang: toLang, tone: tone.rawValue))
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
    |> mapToSignal { result -> Signal<[(String, [MessageTextEntity])], TranslationError> in
        var texts: [(String, [MessageTextEntity])] = []
        switch result {
        case let .translateResult(translateResultData):
            let results = translateResultData.result
            for result in results {
                if case let .textWithEntities(textWithEntitiesData) = result {
                    let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                    texts.append((text, messageTextEntitiesFromApiEntities(entities)))
                }
            }
        }
        return .single(texts)
    }
}

func _internal_translateMessages(account: Account, messageIds: [EngineMessage.Id], fromLang: String?, toLang: String, enableLocalIfPossible: Bool, tone: TranslationTone = .neutral) -> Signal<Never, TranslationError> {
    var signals: [Signal<Void, TranslationError>] = []
    for (peerId, messageIds) in messagesIdsGroupedByPeerId(messageIds) {
        signals.append(_internal_translateMessagesByPeerId(account: account, peerId: peerId, messageIds: messageIds, fromLang: fromLang, toLang: toLang, enableLocalIfPossible: enableLocalIfPossible, tone: tone))
    }
    return combineLatest(signals)
    |> ignoreValues
}

public protocol ExperimentalInternalTranslationService: AnyObject {
    func translate(texts: [AnyHashable: String], fromLang: String, toLang: String) -> Signal<[AnyHashable: String]?, NoError>
}

public var engineExperimentalInternalTranslationService: ExperimentalInternalTranslationService?

/// Translates rich messages (those carrying a `RichTextMessageAttribute`) by id via
/// `messages.translateRichMessage`, stores each result as a `TranslationMessageAttribute` with the
/// translated `InstantPage`, and returns the pages keyed by message id.
func _internal_translateRichMessages(account: Account, inputPeer: Api.InputPeer, messageIds: [EngineMessage.Id], toLang: String, tone: TranslationTone = .neutral) -> Signal<[EngineMessage.Id: InstantPage], TranslationError> {
    var flags: Int32 = 0
    flags |= (1 << 0)
    if tone != .neutral {
        flags |= (1 << 2)
    }
    return account.network.request(Api.functions.messages.translateRichMessage(flags: flags, peer: inputPeer, id: messageIds.map { $0.id }, text: nil, toLang: toLang, tone: tone != .neutral ? tone.rawValue : nil))
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
    |> mapToSignal { result -> Signal<[EngineMessage.Id: InstantPage], TranslationError> in
        var pages: [EngineMessage.Id: InstantPage] = [:]
        switch result {
        case let .translatedRichMessage(data):
            for (i, richMessage) in data.result.enumerated() where i < messageIds.count {
                pages[messageIds[i]] = RichTextMessageAttribute(apiRichMessage: richMessage).instantPage
            }
        }
        return account.postbox.transaction { transaction -> [EngineMessage.Id: InstantPage] in
            for (messageId, page) in pages {
                let updatedAttribute = TranslationMessageAttribute(text: "", entities: [], toLang: toLang, instantPage: page)
                transaction.updateMessage(messageId, update: { currentMessage in
                    let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                    var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                    attributes.append(updatedAttribute)
                    return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                })
            }
            return pages
        }
        |> castError(TranslationError.self)
    }
}

private func _internal_translateMessagesByPeerId(account: Account, peerId: EnginePeer.Id, messageIds: [EngineMessage.Id], fromLang: String?, toLang: String, enableLocalIfPossible: Bool, tone: TranslationTone = .neutral) -> Signal<Void, TranslationError> {
    return account.postbox.transaction { transaction -> (Api.InputPeer?, [Message]) in
        return (transaction.getPeer(peerId).flatMap(apiInputPeer), messageIds.compactMap({ transaction.getMessage($0) }))
    }
    |> castError(TranslationError.self)
    |> mapToSignal { (inputPeer, messages) -> Signal<Void, TranslationError> in
        guard let inputPeer = inputPeer else {
            return .never()
        }
        
        let polls = messages.compactMap { message in
            if let poll = message.media.first as? TelegramMediaPoll {
                return (poll, message.id)
            } else {
                return nil
            }
        }
        let pollSignals = polls.map { (poll, id) in
            var texts: [(String, [MessageTextEntity])] = []
            texts.append((poll.text, poll.textEntities))
            for option in poll.options {
                texts.append((option.text, option.entities))
            }
            if let solution = poll.results.solution {
                texts.append((solution.text, solution.entities))
            }
            return _internal_translateTexts(network: account.network, texts: texts, toLang: toLang)
        }
        
        let audioTranscriptions = messages.compactMap { message in
            if let audioTranscription = message.attributes.first(where: { $0 is AudioTranscriptionMessageAttribute }) as? AudioTranscriptionMessageAttribute, !audioTranscription.text.isEmpty && !audioTranscription.isPending {
                return (audioTranscription.text, message.id)
            } else {
                return nil
            }
        }
        let audioTranscriptionsSignals = audioTranscriptions.map { (text, id) in
            return _internal_translate(network: account.network, text: text, toLang: toLang)
        }
        
        var flags: Int32 = 0
        flags |= (1 << 0)
        if tone != .neutral {
            flags |= (1 << 2)
        }

        // Rich messages (a `RichTextMessageAttribute`) translate through `messages.translateRichMessage`
        // (per the layer-228 contract: pick translateText vs translateRichMessage by message type).
        let richMessageIds = messages.filter { $0.attributes.contains(where: { $0 is RichTextMessageAttribute }) }.map { $0.id }
        let plainMessageIds = messageIds.filter { !richMessageIds.contains($0) }

        let richSignal: Signal<Void, TranslationError>
        if richMessageIds.isEmpty {
            richSignal = .single(Void())
        } else {
            richSignal = _internal_translateRichMessages(account: account, inputPeer: inputPeer, messageIds: richMessageIds, toLang: toLang, tone: tone)
            |> map { _ in Void() }
        }

        let id: [Int32] = plainMessageIds.map { $0.id }

        let msgs: Signal<Api.messages.TranslatedText?, TranslationError>
        if id.isEmpty {
            msgs = .single(nil)
        } else {
            if enableLocalIfPossible, let engineExperimentalInternalTranslationService, let fromLang {
                msgs = account.postbox.transaction { transaction -> [MessageId: String] in
                    var texts: [MessageId: String] = [:]
                    for messageId in plainMessageIds {
                        if let message = transaction.getMessage(messageId) {
                            texts[message.id] = message.text
                        }
                    }
                    return texts
                }
                |> castError(TranslationError.self)
                |> mapToSignal { messageTexts -> Signal<Api.messages.TranslatedText?, TranslationError> in
                    var mappedTexts: [AnyHashable: String] = [:]
                    for (id, text) in messageTexts {
                        mappedTexts[AnyHashable(id)] = text
                    }
                    return engineExperimentalInternalTranslationService.translate(texts: mappedTexts, fromLang: fromLang, toLang: toLang)
                    |> castError(TranslationError.self)
                    |> mapToSignal { resultTexts -> Signal<Api.messages.TranslatedText?, TranslationError> in
                        guard let resultTexts else {
                            return .fail(.generic)
                        }
                        var result: [Api.TextWithEntities] = []
                        for messageId in plainMessageIds {
                            if let text = resultTexts[AnyHashable(messageId)] {
                                result.append(.textWithEntities(.init(text: text, entities: [])))
                            } else if let text = messageTexts[messageId] {
                                result.append(.textWithEntities(.init(text: text, entities: [])))
                            } else {
                                result.append(.textWithEntities(.init(text: "", entities: [])))
                            }
                        }
                        return .single(.translateResult(.init(result: result)))
                    }
                }
            } else {
                msgs = account.network.request(Api.functions.messages.translateText(flags: flags, peer: inputPeer, id: id, text: nil, toLang: toLang, tone: tone != .neutral ? tone.rawValue : nil))
                |> map(Optional.init)
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
            }
        }
        
        return combineLatest(msgs, richSignal, combineLatest(pollSignals), combineLatest(audioTranscriptionsSignals))
        |> mapToSignal { (result, _, pollResults, audioTranscriptionsResults) -> Signal<Void, TranslationError> in
            return account.postbox.transaction { transaction in
                if case let .translateResult(translateResultData) = result {
                    let results = translateResultData.result
                    var index = 0
                    for result in results {
                        guard index < plainMessageIds.count else { break }
                        let messageId = plainMessageIds[index]
                        if case let .textWithEntities(textWithEntitiesData) = result {
                            let (text, entities) = (textWithEntitiesData.text, textWithEntitiesData.entities)
                            let updatedAttribute: TranslationMessageAttribute = TranslationMessageAttribute(text: text, entities: messageTextEntitiesFromApiEntities(entities), toLang: toLang)
                            transaction.updateMessage(messageId, update: { currentMessage in
                                let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                                
                                attributes.append(updatedAttribute)
                                
                                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                            })
                        }
                        index += 1
                    }
                }
                
                if !pollResults.isEmpty {
                    for (i, poll) in polls.enumerated() {
                        let result = pollResults[i]
                        if !result.isEmpty {
                            transaction.updateMessage(poll.1, update: { currentMessage in
                                let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                                var attrOptions: [TranslationMessageAttribute.Additional] = []
                                for (i, _) in poll.0.options.enumerated() {
                                    var translated = result.count > i + 1 ? result[i + 1] : (poll.0.options[i].text, poll.0.options[i].entities)
                                    if translated.0.isEmpty {
                                        translated = (poll.0.options[i].text, poll.0.options[i].entities)
                                    }
                                    attrOptions.append(TranslationMessageAttribute.Additional(text: translated.0, entities: translated.1))
                                }
                                
                                let solution: TranslationMessageAttribute.Additional?
                                if result.count > 1 + poll.0.options.count, !result[result.count - 1].0.isEmpty {
                                    solution = TranslationMessageAttribute.Additional(text: result[result.count - 1].0, entities: result[result.count - 1].1)
                                } else {
                                    solution = nil
                                }
                                
                                let title = result[0].0.isEmpty ? (poll.0.text, poll.0.textEntities) : result[0]
                                
                                let updatedAttribute: TranslationMessageAttribute = TranslationMessageAttribute(text: title.0, entities: title.1, additional: attrOptions, pollSolution: solution, toLang: toLang)
                                attributes.append(updatedAttribute)
                                
                                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                            })
                        }
                    }
                }
                
                if !audioTranscriptionsResults.isEmpty {
                    for (i, audioTranscription) in audioTranscriptions.enumerated() {
                        if let result = audioTranscriptionsResults[i] {
                            transaction.updateMessage(audioTranscription.1, update: { currentMessage in
                                let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
                                var attributes = currentMessage.attributes.filter { !($0 is TranslationMessageAttribute) }
                                
                                let updatedAttribute: TranslationMessageAttribute = TranslationMessageAttribute(text: result.0, entities: result.1, additional: [], pollSolution: nil, toLang: toLang)
                                attributes.append(updatedAttribute)
                                
                                return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
                            })
                        }
                    }
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

public enum TelegramComposeAIMessageMode {
    public final class CloudStyle: Equatable, Codable {
        public enum Id: Hashable {
            case standard(String)
            case custom(Int64)
        }
        
        public enum Reference: Hashable {
            case standard(String)
            case custom(id: Int64, accessHash: Int64)
            
            public var id: Id {
                switch self {
                case let .standard(type):
                    return .standard(type)
                case let .custom(id, _):
                    return .custom(id)
                }
            }
        }
        
        public final class Standard: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case type
                case title
                case emojiFileId
            }
            
            public let type: String
            public let title: String
            public let emojiFileId: Int64?
            
            public init(type: String, title: String, emojiFileId: Int64?) {
                self.type = type
                self.title = title
                self.emojiFileId = emojiFileId
            }
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.type = try container.decode(String.self, forKey: .type)
                self.title = try container.decode(String.self, forKey: .title)
                self.emojiFileId = try container.decodeIfPresent(Int64.self, forKey: .emojiFileId)
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(self.type, forKey: .type)
                try container.encode(self.title, forKey: .title)
                try container.encodeIfPresent(self.emojiFileId, forKey: .emojiFileId)
            }
            
            public static func ==(lhs: Standard, rhs: Standard) -> Bool {
                if lhs.type != rhs.type {
                    return false
                }
                if lhs.title != rhs.title {
                    return false
                }
                if lhs.emojiFileId != rhs.emojiFileId {
                    return false
                }
                return true
            }
        }
        
        public final class Custom: Codable, Equatable {
            private enum CodingKeys: String, CodingKey {
                case isCreator
                case id
                case accessHash
                case slug
                case emojiFileId
                case title
                case prompt
                case userCount
                case authorId
            }
            
            public let isCreator: Bool
            public let id: Int64
            public let accessHash: Int64
            public let slug: String
            public let emojiFileId: Int64?
            public let title: String
            public let prompt: String?
            public let userCount: Int?
            public let authorId: EnginePeer.Id?
            
            public init(isCreator: Bool, id: Int64, accessHash: Int64, slug: String, emojiFileId: Int64?, title: String, prompt: String?, userCount: Int?, authorId: EnginePeer.Id?) {
                self.isCreator = isCreator
                self.id = id
                self.accessHash = accessHash
                self.slug = slug
                self.emojiFileId = emojiFileId
                self.title = title
                self.prompt = prompt
                self.userCount = userCount
                self.authorId = authorId
            }
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                self.isCreator = try container.decode(Bool.self, forKey: .isCreator)
                self.id = try container.decode(Int64.self, forKey: .id)
                self.accessHash = try container.decode(Int64.self, forKey: .accessHash)
                self.slug = try container.decode(String.self, forKey: .slug)
                self.emojiFileId = try container.decodeIfPresent(Int64.self, forKey: .emojiFileId)
                self.title = try container.decode(String.self, forKey: .title)
                self.prompt = try container.decodeIfPresent(String.self, forKey: .prompt)
                self.userCount = try container.decodeIfPresent(Int32.self, forKey: .userCount).flatMap(Int.init)
                self.authorId = try container.decodeIfPresent(EnginePeer.Id.self, forKey: .authorId)
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                try container.encode(self.isCreator, forKey: .isCreator)
                try container.encode(self.id, forKey: .id)
                try container.encode(self.accessHash, forKey: .accessHash)
                try container.encode(self.slug, forKey: .slug)
                try container.encodeIfPresent(self.emojiFileId, forKey: .emojiFileId)
                try container.encode(self.title, forKey: .title)
                try container.encodeIfPresent(self.prompt, forKey: .prompt)
                try container.encodeIfPresent(self.userCount.flatMap(Int32.init(clamping:)), forKey: .userCount)
                try container.encodeIfPresent(self.authorId, forKey: .authorId)
            }
            
            public static func ==(lhs: Custom, rhs: Custom) -> Bool {
                if lhs.isCreator != rhs.isCreator {
                    return false
                }
                if lhs.id != rhs.id {
                    return false
                }
                if lhs.accessHash != rhs.accessHash {
                    return false
                }
                if lhs.slug != rhs.slug {
                    return false
                }
                if lhs.emojiFileId != rhs.emojiFileId {
                    return false
                }
                if lhs.title != rhs.title {
                    return false
                }
                if lhs.prompt != rhs.prompt {
                    return false
                }
                if lhs.userCount != rhs.userCount {
                    return false
                }
                if lhs.authorId != rhs.authorId {
                    return false
                }
                return true
            }
        }
        
        public enum Content: Equatable, Codable {
            private enum CodingKeys: String, CodingKey {
                case discriminator = "d"
                case value = "v"
            }
            
            case standard(Standard)
            case custom(Custom)
            
            public init(from decoder: any Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                switch try container.decode(Int32.self, forKey: .discriminator) {
                case 0:
                    self = .standard(try container.decode(Standard.self, forKey: .value))
                case 1:
                    self = .custom(try container.decode(Custom.self, forKey: .value))
                default:
                    throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: [], debugDescription: ""))
                }
            }
            
            public func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                
                switch self {
                case let .standard(standard):
                    try container.encode(0 as Int32, forKey: .discriminator)
                    try container.encode(standard, forKey: .value)
                case let .custom(custom):
                    try container.encode(1 as Int32, forKey: .discriminator)
                    try container.encode(custom, forKey: .value)
                }
            }
        }
        
        public let content: Content
        
        public var id: StyleId {
            switch self.content {
            case let .standard(standard):
                return .style(.standard(standard.type))
            case let .custom(custom):
                return .style(.custom(custom.id))
            }
        }
        
        public var reference: Reference {
            switch self.content {
            case let .standard(standard):
                return .standard(standard.type)
            case let .custom(custom):
                return .custom(id: custom.id, accessHash: custom.accessHash)
            }
        }
        
        public init(content: Content) {
            self.content = content
        }
        
        public static func ==(lhs: CloudStyle, rhs: CloudStyle) -> Bool {
            if lhs.content != rhs.content {
                return false
            }
            return true
        }
    }
    
    public enum StyleId: Hashable {
        case neutral
        case prompt
        case style(CloudStyle.Id)
    }
    
    public enum StyleReference: Hashable {
        case neutral
        case prompt(String)
        case style(CloudStyle.Reference)
        
        public var id: StyleId {
            switch self {
            case .neutral:
                return .neutral
            case .prompt:
                return .prompt
            case let .style(style):
                return .style(style.id)
            }
        }
    }
    
    case translate(toLanguage: String, emojify: Bool, style: StyleReference)
    case stylize(emojify: Bool, style: StyleReference)
    case proofread
    case generate(prompt: String)
}

extension TelegramComposeAIMessageMode.CloudStyle {
    convenience init(apiTone: Api.AiComposeTone) {
        switch apiTone {
        case let .aiComposeTone(aiComposeTone):
            self.init(content: .custom(Custom(
                isCreator: (aiComposeTone.flags & (1 << 0)) != 0,
                id: aiComposeTone.id,
                accessHash: aiComposeTone.accessHash,
                slug: aiComposeTone.slug,
                emojiFileId: aiComposeTone.emojiId,
                title: aiComposeTone.title,
                prompt: aiComposeTone.prompt,
                userCount: aiComposeTone.installsCount.flatMap(Int.init),
                authorId: aiComposeTone.authorId.flatMap { id -> EnginePeer.Id in
                    return EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(id))
                }
            )))
        case let .aiComposeToneDefault(aiComposeToneDefault):
            self.init(content: .standard(Standard(
                type: aiComposeToneDefault.tone,
                title: aiComposeToneDefault.title,
                emojiFileId: aiComposeToneDefault.emojiId
            )))
        }
    }
}

public final class TelegramAIComposeMessageResult {
    public let text: ComposedRichMessage
    public let diffRanges: [Range<Int>]
    
    public init(text: ComposedRichMessage, diffRanges: [Range<Int>]) {
        self.text = text
        self.diffRanges = diffRanges
    }
}

extension TextWithEntities {
    init(apiValue: Api.TextWithEntities) {
        switch apiValue {
        case let .textWithEntities(textWithEntities):
            self.init(text: textWithEntities.text, entities: messageTextEntitiesFromApiEntities(textWithEntities.entities))
        }
    }
}

extension TelegramComposeAIMessageMode.CloudStyle.Reference {
    var apiInputStyle: Api.InputAiComposeTone {
        switch self {
        case let .standard(type):
            return .inputAiComposeToneDefault(Api.InputAiComposeTone.Cons_inputAiComposeToneDefault(tone: type))
        case let .custom(id, accessHash):
            return .inputAiComposeToneID(Api.InputAiComposeTone.Cons_inputAiComposeToneID(id: id, accessHash: accessHash))
        }
    }
}

public enum TelegramAIComposeMessageError {
    case generic
    case nonPremiumFlood
}

func _internal_composeAIMessage(account: Account, text: ComposedRichMessage, mode: TelegramComposeAIMessageMode) -> Signal<TelegramAIComposeMessageResult, TelegramAIComposeMessageError> {
    var flags: Int32 = 0
    var translateToLang: String?
    var changeTone: Api.InputAiComposeTone?
    switch mode {
    case let .translate(toLanguage, emojify, style):
        translateToLang = toLanguage
        flags |= (1 << 1)
        
        if emojify {
            flags |= (1 << 3)
        }
        
        if case let .style(reference) = style {
            changeTone = reference.apiInputStyle
            flags |= (1 << 2)
        }
    case let .stylize(emojify, style):
        if emojify {
            flags |= (1 << 3)
        }
        
        if case let .style(reference) = style {
            changeTone = reference.apiInputStyle
            flags |= (1 << 2)
        } else if case let .prompt(prompt) = style {
            changeTone = .inputAiComposeToneSingleUse(Api.InputAiComposeTone.Cons_inputAiComposeToneSingleUse(customPrompt: prompt))
            flags |= (1 << 2)
        }
    case .proofread:
        flags |= (1 << 0)
    case let .generate(prompt):
        flags = 0
        flags |= (1 << 2)
        return account.network.request(Api.functions.messages.composeRichMessageWithAI(flags: flags, text: nil, translateToLang: nil, tone: .inputAiComposeToneSingleUse(Api.InputAiComposeTone.Cons_inputAiComposeToneSingleUse(customPrompt: prompt))))
        |> `catch` { error -> Signal<Api.messages.ComposedRichMessageWithAI, TelegramAIComposeMessageError> in
            if error.errorDescription == "AICOMPOSE_FLOOD_PREMIUM" {
                return .fail(.nonPremiumFlood)
            } else {
                return .fail(.generic)
            }
        }
        |> mapToSignal { result -> Signal<TelegramAIComposeMessageResult, TelegramAIComposeMessageError> in
            switch result {
            case let .composedRichMessageWithAI(composedMessageWithAI):
                let diffRanges: [Range<Int>] = []
                return .single(TelegramAIComposeMessageResult(
                    text: .rich(instantPage: RichTextMessageAttribute(apiRichMessage: composedMessageWithAI.result).instantPage),
                    diffRanges: diffRanges
                ))
            }
        }
    }
    
    switch text {
    case .empty, .plain:
        let inputText: Api.TextWithEntities
        if case let .plain(text, entities) = text {
            inputText = .textWithEntities(Api.TextWithEntities.Cons_textWithEntities(text: text, entities: apiEntitiesFromMessageTextEntities(entities, associatedPeers: SimpleDictionary())))
        } else {
            inputText = .textWithEntities(Api.TextWithEntities.Cons_textWithEntities(text: "", entities: []))
        }
        
        return account.network.request(Api.functions.messages.composeMessageWithAI(flags: flags, text: inputText, translateToLang: translateToLang, tone: changeTone))
        |> `catch` { error -> Signal<Api.messages.ComposedMessageWithAI, TelegramAIComposeMessageError> in
            if error.errorDescription == "AICOMPOSE_FLOOD_PREMIUM" {
                return .fail(.nonPremiumFlood)
            } else {
                return .fail(.generic)
            }
        }
        |> mapToSignal { result -> Signal<TelegramAIComposeMessageResult, TelegramAIComposeMessageError> in
            switch result {
            case let .composedMessageWithAI(composedMessageWithAI):
                var diffRanges: [Range<Int>] = []
                if let diffText = composedMessageWithAI.diffText {
                    switch diffText {
                    case let .textWithEntities(textWithEntities):
                        for entity in textWithEntities.entities {
                            switch entity {
                            case let .messageEntityDiffReplace(messageEntityDiffReplace):
                                if messageEntityDiffReplace.length >= 0 {
                                    diffRanges.append(Int(messageEntityDiffReplace.offset) ..< Int(messageEntityDiffReplace.offset + messageEntityDiffReplace.length))
                                }
                            case let .messageEntityDiffInsert(messageEntityDiffInsert):
                                if messageEntityDiffInsert.length >= 0 {
                                    diffRanges.append(Int(messageEntityDiffInsert.offset) ..< Int(messageEntityDiffInsert.offset + messageEntityDiffInsert.length))
                                }
                            default:
                                break
                            }
                        }
                    }
                }
                let resultText = TextWithEntities(apiValue: composedMessageWithAI.resultText)
                return .single(TelegramAIComposeMessageResult(
                    text: .plain(text: resultText.text, entities: resultText.entities),
                    diffRanges: diffRanges
                ))
            }
        }
    case let .rich(instantPage):
        flags |= (1 << 4)
        let inputText = RichTextMessageAttribute(instantPage: instantPage, fullInstantPage: nil).apiInputRichMessage()
        return account.network.request(Api.functions.messages.composeRichMessageWithAI(flags: flags, text: inputText, translateToLang: translateToLang, tone: changeTone))
        |> `catch` { error -> Signal<Api.messages.ComposedRichMessageWithAI, TelegramAIComposeMessageError> in
            if error.errorDescription == "AICOMPOSE_FLOOD_PREMIUM" {
                return .fail(.nonPremiumFlood)
            } else {
                return .fail(.generic)
            }
        }
        |> mapToSignal { result -> Signal<TelegramAIComposeMessageResult, TelegramAIComposeMessageError> in
            switch result {
            case let .composedRichMessageWithAI(composedMessageWithAI):
                let diffRanges: [Range<Int>] = []
                return .single(TelegramAIComposeMessageResult(
                    text: .rich(instantPage: RichTextMessageAttribute(apiRichMessage: composedMessageWithAI.result).instantPage),
                    diffRanges: diffRanges
                ))
            }
        }
    }
}

public final class AIMessageStylePreview {
    public let from: ComposedRichMessage
    public let to: ComposedRichMessage
    public let index: Int?
    
    public init(from: ComposedRichMessage, to: ComposedRichMessage, index: Int?) {
        self.from = from
        self.to = to
        self.index = index
    }
}

extension AIMessageStylePreview {
    convenience init(apiPreview: Api.AiComposeToneExample, index: Int) {
        switch apiPreview {
        case let .aiComposeToneExample(aiComposeToneExample):
            let fromText = TextWithEntities(apiValue: aiComposeToneExample.from)
            let toText = TextWithEntities(apiValue: aiComposeToneExample.to)
            self.init(from: .plain(text: fromText.text, entities: fromText.entities), to: .plain(text: toText.text, entities: toText.entities), index: index)
        }
    }
}

public func _internal_requestAIMessageStylePreview(account: Account, reference: TelegramComposeAIMessageMode.CloudStyle.Reference, index: Int) -> Signal<AIMessageStylePreview?, NoError> {
    return account.network.request(Api.functions.aicompose.getToneExample(tone: reference.apiInputStyle, num: Int32(index)))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.AiComposeToneExample?, NoError> in
        return .single(nil)
    }
    |> map { result -> AIMessageStylePreview? in
        guard let result else {
            return nil
        }
        return AIMessageStylePreview(
            apiPreview: result,
            index: index
        )
    }
}

public enum CreateAITextStyleError {
    case generic
    case premiumRequired
}

func _internal_createAITextStyle(account: Account, displayAuthor: Bool, emojiFileId: Int64, title: String, prompt: String) -> Signal<TelegramComposeAIMessageMode.CloudStyle, CreateAITextStyleError> {
    var flags: Int32 = 0
    if displayAuthor {
        flags |= (1 << 0)
    }
    return account.network.request(Api.functions.aicompose.createTone(
        flags: flags,
        emojiId: emojiFileId,
        title: title,
        prompt: prompt
    ))
    |> mapError { error -> CreateAITextStyleError in
        if error.errorDescription == "TONES_SAVED_TOO_MANY" {
            return .premiumRequired
        }
        return .generic
    }
    |> mapToSignal { result -> Signal<TelegramComposeAIMessageMode.CloudStyle, CreateAITextStyleError> in
        return account.postbox.transaction { transaction -> TelegramComposeAIMessageMode.CloudStyle in
            let style = TelegramComposeAIMessageMode.CloudStyle(apiTone: result)
            
            let styles = _internal_cachedCloudAITextStyles(transaction: transaction)
            var items = styles?.items ?? []
            items.insert(style, at: 0)
            _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(items: items, hash: 0))
            return style
        }
        |> castError(CreateAITextStyleError.self)
    }
}

public enum EditAITextStyleError {
    case generic
}

func _internal_editAITextStyle(account: Account, id: Int64, accessHash: Int64, displayAuthor: Bool, emojiFileId: Int64, title: String, prompt: String) -> Signal<TelegramComposeAIMessageMode.CloudStyle, EditAITextStyleError> {
    var flags: Int32 = 0
    flags |= (1 << 0)
    flags |= (1 << 1)
    flags |= (1 << 2)
    flags |= (1 << 3)
    return account.network.request(Api.functions.aicompose.updateTone(
        flags: flags,
        tone: .inputAiComposeToneID(Api.InputAiComposeTone.Cons_inputAiComposeToneID(id: id, accessHash: accessHash)),
        displayAuthor: displayAuthor ? .boolTrue : .boolFalse,
        emojiId: emojiFileId,
        title: title,
        prompt: prompt
    ))
    |> mapError { _ -> EditAITextStyleError in
        return .generic
    }
    |> mapToSignal { result -> Signal<TelegramComposeAIMessageMode.CloudStyle, EditAITextStyleError> in
        return account.postbox.transaction { transaction -> TelegramComposeAIMessageMode.CloudStyle in
            let style = TelegramComposeAIMessageMode.CloudStyle(apiTone: result)
            
            let styles = _internal_cachedCloudAITextStyles(transaction: transaction)
            var items = styles?.items ?? []
            if let index = items.firstIndex(where: { $0.id == .style(.custom(id)) }) {
                items[index] = style
            }
            _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(items: items, hash: 0))
            return style
        }
        |> castError(EditAITextStyleError.self)
    }
}

public struct TelegramAIComposeToneExample: Equatable {
    public let from: TextWithEntities
    public let to: TextWithEntities
    public init(from: TextWithEntities, to: TextWithEntities) {
        self.from = from
        self.to = to
    }
}

private func _internal_mapToneExample(_ apiExample: Api.AiComposeToneExample) -> TelegramAIComposeToneExample {
    switch apiExample {
    case let .aiComposeToneExample(data):
        return TelegramAIComposeToneExample(from: TextWithEntities(apiValue: data.from), to: TextWithEntities(apiValue: data.to))
    }
}

func _internal_getAIComposeToneExample(network: Network, tone: TelegramComposeAIMessageMode.CloudStyle.Reference, num: Int32) -> Signal<TelegramAIComposeToneExample?, NoError> {
    return network.request(Api.functions.aicompose.getToneExample(tone: tone.apiInputStyle, num: num))
    |> map { apiExample -> TelegramAIComposeToneExample? in
        return _internal_mapToneExample(apiExample)
    }
    |> `catch` { _ -> Signal<TelegramAIComposeToneExample?, NoError> in
        return .single(nil)
    }
}

func _internal_getAIComposeToneExample(network: Network, slug: String, num: Int32) -> Signal<TelegramAIComposeToneExample?, NoError> {
    return network.request(Api.functions.aicompose.getToneExample(tone: .inputAiComposeToneSlug(Api.InputAiComposeTone.Cons_inputAiComposeToneSlug(slug: slug)), num: num))
    |> map { apiExample -> TelegramAIComposeToneExample? in
        return _internal_mapToneExample(apiExample)
    }
    |> `catch` { _ -> Signal<TelegramAIComposeToneExample?, NoError> in
        return .single(nil)
    }
}

public enum DeleteAITextStyleError {
    case generic
}

func _internal_deleteAITextStyle(account: Account, id: Int64, accessHash: Int64) -> Signal<Never, DeleteAITextStyleError> {
    return account.network.request(Api.functions.aicompose.deleteTone(tone: .inputAiComposeToneID(Api.InputAiComposeTone.Cons_inputAiComposeToneID(id: id, accessHash: accessHash))))
    |> mapError { _ -> DeleteAITextStyleError in
        return .generic
    }
    |> mapToSignal { result -> Signal<Never, DeleteAITextStyleError> in
        return account.postbox.transaction { transaction -> Void in
            let styles = _internal_cachedCloudAITextStyles(transaction: transaction)
            var items = styles?.items ?? []
            items.removeAll(where: { $0.id == .style(.custom(id)) })
            _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(items: items, hash: 0))
        }
        |> castError(DeleteAITextStyleError.self)
        |> ignoreValues
    }
}

func _internal_unsaveAITextStyle(account: Account, id: Int64, accessHash: Int64) -> Signal<Never, DeleteAITextStyleError> {
    return account.network.request(Api.functions.aicompose.saveTone(tone: .inputAiComposeToneID(Api.InputAiComposeTone.Cons_inputAiComposeToneID(id: id, accessHash: accessHash)), unsave: .boolTrue))
    |> mapError { _ -> DeleteAITextStyleError in
        return .generic
    }
    |> mapToSignal { _ -> Signal<Never, DeleteAITextStyleError> in
        return account.postbox.transaction { transaction -> Void in
            let styles = _internal_cachedCloudAITextStyles(transaction: transaction)
            var items = styles?.items ?? []
            items.removeAll(where: { $0.id == .style(.custom(id)) })
            _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(items: items, hash: 0))
        }
        |> castError(DeleteAITextStyleError.self)
        |> ignoreValues
    }
}

final class CachedCloudAITextStyles: Codable {
    let items: [TelegramComposeAIMessageMode.CloudStyle]
    let hash: Int64
    
    init(items: [TelegramComposeAIMessageMode.CloudStyle], hash: Int64) {
        self.items = items
        self.hash = hash
    }
}

func _internal_cachedCloudAITextStyles(postbox: Postbox) -> Signal<CachedCloudAITextStyles?, NoError> {
    return postbox.transaction { transaction -> CachedCloudAITextStyles? in
        return _internal_cachedCloudAITextStyles(transaction: transaction)
    }
}

func _internal_cachedCloudAITextStyles(transaction: Transaction) -> CachedCloudAITextStyles? {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    let cached = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedCloudAITextStyles, key: key))?.get(CachedCloudAITextStyles.self)
    if let cached {
        return cached
    } else {
        return nil
    }
}

func _internal_setCachedCloudAITextStyles(transaction: Transaction, styles: CachedCloudAITextStyles) {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: 0)
    
    if let entry = CodableEntry(styles) {
        transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedCloudAITextStyles, key: key), entry: entry)
    }
}

func _internal_requestAIMessageStyle(account: Account, slug: String) -> Signal<(style: TelegramComposeAIMessageMode.CloudStyle, initialPreview: AIMessageStylePreview?)?, NoError> {
    return account.network.request(Api.functions.aicompose.getTone(tone: .inputAiComposeToneSlug(Api.InputAiComposeTone.Cons_inputAiComposeToneSlug(slug: slug))))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.aicompose.Tones?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<(style: TelegramComposeAIMessageMode.CloudStyle, initialPreview: AIMessageStylePreview?)?, NoError> in
        guard let result else {
            return .single(nil)
        }
        return account.postbox.transaction { transaction -> (style: TelegramComposeAIMessageMode.CloudStyle, initialPreview: AIMessageStylePreview?)? in
            switch result {
            case let .tones(tones):
                guard let tone = tones.tones.first else {
                    return nil
                }
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: AccumulatedPeers(users: tones.users))
                return (TelegramComposeAIMessageMode.CloudStyle(apiTone: tone), nil)
            case .tonesNotModified:
                return nil
            }
        }
    }
}

public enum InstallAIMessageStyleError {
    case generic
}

func _internal_installAIMessageStyle(account: Account, style: TelegramComposeAIMessageMode.CloudStyle.Custom) -> Signal<Never, InstallAIMessageStyleError> {
    return account.network.request(Api.functions.aicompose.saveTone(tone: .inputAiComposeToneID(Api.InputAiComposeTone.Cons_inputAiComposeToneID(id: style.id, accessHash: style.accessHash)), unsave: .boolFalse))
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.Bool?, NoError> in
        return .single(nil)
    }
    |> castError(InstallAIMessageStyleError.self)
    |> mapToSignal { result -> Signal<Never, InstallAIMessageStyleError> in
        if result != nil {
            return account.postbox.transaction { transaction -> Void in
                var items = _internal_cachedCloudAITextStyles(transaction: transaction)?.items ?? []
                if let index = items.firstIndex(where: { $0.id == .style(.custom(style.id)) }) {
                    items.remove(at: index)
                }
                items.insert(TelegramComposeAIMessageMode.CloudStyle(content: .custom(style)), at: 0)
                _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(items: items, hash: 0))
            }
            |> ignoreValues
            |> castError(InstallAIMessageStyleError.self)
        } else {
            return .fail(.generic)
        }
    }
}

func managedSynchronizeCloudAITextStyles(postbox: Postbox, network: Network) -> Signal<Never, NoError> {
    let poll = Signal<Never, NoError> { subscriber in
        let signal: Signal<Never, NoError> = _internal_cachedCloudAITextStyles(postbox: postbox)
        |> mapToSignal { current in
            return (network.request(Api.functions.aicompose.getTones(hash: current?.hash ?? 0))
            |> map(Optional.init)
            |> `catch` { _ -> Signal<Api.aicompose.Tones?, NoError> in
                return .single(nil)
            }
            |> mapToSignal { result -> Signal<Never, NoError> in
                return postbox.transaction { transaction -> Signal<Never, NoError> in
                    guard let result = result else {
                        return .complete()
                    }
                    
                    switch result {
                    case let .tones(tones):
                        _internal_setCachedCloudAITextStyles(transaction: transaction, styles: CachedCloudAITextStyles(
                            items: tones.tones.map(TelegramComposeAIMessageMode.CloudStyle.init(apiTone:)),
                            hash: tones.hash
                        ))
                    case .tonesNotModified:
                        break
                    }
                    
                    return .complete()
                }
                |> switchToLatest
            })
        }
                
        return signal.start(completed: {
            subscriber.putCompletion()
        })
    }
    
    return (
        poll
        |> then(
            .complete()
            |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue())
        )
    )
    |> restart
}
