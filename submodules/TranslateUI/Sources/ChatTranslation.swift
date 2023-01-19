import Foundation
import NaturalLanguage
import SwiftSignalKit
import TelegramCore
import Postbox
import AccountContext
import TelegramUIPreferences

public struct ChatTranslationState: Codable {
    enum CodingKeys: String, CodingKey {
        case baseLang
        case fromLang
        case toLang
        case isEnabled
    }
    
    public let baseLang: String
    public let fromLang: String
    public let toLang: String?
    public let isEnabled: Bool
    
    public init(
        baseLang: String,
        fromLang: String,
        toLang: String?,
        isEnabled: Bool
    ) {
        self.baseLang = baseLang
        self.fromLang = fromLang
        self.toLang = toLang
        self.isEnabled = isEnabled
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.baseLang = try container.decode(String.self, forKey: .baseLang)
        self.fromLang = try container.decode(String.self, forKey: .fromLang)
        self.toLang = try container.decodeIfPresent(String.self, forKey: .toLang)
        self.isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(self.baseLang, forKey: .baseLang)
        try container.encode(self.fromLang, forKey: .fromLang)
        try container.encodeIfPresent(self.toLang, forKey: .toLang)
        try container.encode(self.isEnabled, forKey: .isEnabled)
    }

    public func withToLang(_ toLang: String?) -> ChatTranslationState {
        return ChatTranslationState(
            baseLang: self.baseLang,
            fromLang: self.fromLang,
            toLang: toLang,
            isEnabled: self.isEnabled
        )
    }
    
    public func withIsEnabled(_ isEnabled: Bool) -> ChatTranslationState {
        return ChatTranslationState(
            baseLang: self.baseLang,
            fromLang: self.fromLang,
            toLang: self.toLang,
            isEnabled: isEnabled
        )
    }
}

private func cachedChatTranslationState(engine: TelegramEngine, peerId: EnginePeer.Id) -> Signal<ChatTranslationState?, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return engine.data.subscribe(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key))
    |> map { entry -> ChatTranslationState? in
        return entry?.get(ChatTranslationState.self)
    }
}

private func updateChatTranslationState(engine: TelegramEngine, peerId: EnginePeer.Id, state: ChatTranslationState?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    if let state {
        return engine.itemCache.put(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key, item: state)
    } else {
        return engine.itemCache.remove(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key)
    }
}

public func updateChatTranslationStateInteractively(engine: TelegramEngine, peerId: EnginePeer.Id, _ f: @escaping (ChatTranslationState?) -> ChatTranslationState?) -> Signal<Never, NoError> {
    let key = ValueBoxKey(length: 8)
    key.setInt64(0, value: peerId.id._internalGetInt64Value())
    
    return engine.data.get(TelegramEngine.EngineData.Item.ItemCache.Item(collectionId: ApplicationSpecificItemCacheCollectionId.translationState, id: key))
    |> map { entry -> ChatTranslationState? in
        return entry?.get(ChatTranslationState.self)
    }
    |> mapToSignal { current -> Signal<Never, NoError> in
        if let current {
            return updateChatTranslationState(engine: engine, peerId: peerId, state: f(current))
        } else {
            return .never()
        }
    }
}


@available(iOS 12.0, *)
private let languageRecognizer = NLLanguageRecognizer()

public func translateMessageIds(context: AccountContext, messageIds: [EngineMessage.Id], toLang: String) -> Signal<Void, NoError> {
    return context.account.postbox.transaction { transaction -> Signal<Void, NoError> in
        var messageIdsToTranslate: [EngineMessage.Id] = []
        for messageId in messageIds {
            if let message = transaction.getMessage(messageId), let translation = message.attributes.first(where: { $0 is TranslationMessageAttribute }) as? TranslationMessageAttribute, translation.toLang == toLang {
            } else {
                messageIdsToTranslate.append(messageId)
            }
        }
        return context.engine.messages.translateMessages(messageIds: messageIdsToTranslate, toLang: toLang)
    } |> switchToLatest
}

public func chatTranslationState(context: AccountContext, peerId: EnginePeer.Id) -> Signal<ChatTranslationState?, NoError> {
    if #available(iOS 12.0, *) {
        let baseLang = context.sharedContext.currentPresentationData.with { $0 }.strings.baseLanguageCode
        return cachedChatTranslationState(engine: context.engine, peerId: peerId)
        |> mapToSignal { cached in
            if let cached, cached.baseLang == baseLang {
                return .single(cached)
            } else {
                return .single(nil)
                |> then(
                    context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.translationSettings])
                    |> mapToSignal { sharedData in
                        let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.translationSettings]?.get(TranslationSettings.self) ?? TranslationSettings.defaultSettings
                        
                        var dontTranslateLanguages: [String] = []
                        if let ignoredLanguages = settings.ignoredLanguages {
                            dontTranslateLanguages = ignoredLanguages
                        } else {
                            dontTranslateLanguages = [baseLang]
                        }
                        
                        return context.account.viewTracker.aroundMessageHistoryViewForLocation(.peer(peerId: peerId, threadId: nil), index: .upperBound, anchorIndex: .upperBound, count: 10, fixedCombinedReadStates: nil)
                        |> filter { messageHistoryView -> Bool in
                            return messageHistoryView.0.entries.count > 1
                        }
                        |> take(1)
                        |> map { messageHistoryView, _, _ -> ChatTranslationState in
                            let messages = messageHistoryView.entries.map(\.message)
                            
                            var fromLangs: [String: Int] = [:]
                            var count = 0
                            for message in messages {
                                if message.text.count > 10 {
                                    let text = String(message.text.prefix(64))
                                    languageRecognizer.processString(text)
                                    let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 3)
                                    languageRecognizer.reset()
                                    
                                    let filteredLanguages = hypotheses.filter { supportedTranslationLanguages.contains($0.key.rawValue) }.sorted(by: { $0.value > $1.value })
                                    if let language = filteredLanguages.first(where: { supportedTranslationLanguages.contains($0.key.rawValue) }), !dontTranslateLanguages.contains(language.key.rawValue) {
                                        let fromLang = language.key.rawValue
                                        fromLangs[fromLang] = (fromLangs[fromLang] ?? 0) + 1
                                    }
                                    count += 1
                                }
                                
                                if count >= 5 {
                                    break
                                }
                            }
                            
                            var mostFrequent: (String, Int)?
                            for (lang, count) in fromLangs {
                                if let current = mostFrequent, count > current.1 {
                                    mostFrequent = (lang, count)
                                } else {
                                    mostFrequent = (lang, count)
                                }
                            }
                            let fromLang = mostFrequent?.0 ?? ""
                            let state = ChatTranslationState(baseLang: baseLang, fromLang: fromLang, toLang: nil, isEnabled: false)
                            let _ = updateChatTranslationState(engine: context.engine, peerId: peerId, state: state).start()
                            return state
                        }
                    }
                )
            }
        }
    } else {
        return .single(nil)
    }
}
